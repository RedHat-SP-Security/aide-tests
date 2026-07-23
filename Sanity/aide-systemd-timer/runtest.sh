#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Sanity/aide-systemd-timer
#   Description: Verify aide-check.service and aide-check.timer are shipped
#                and behave correctly (RHEL-123520)
#   Author: Attila Lakatos <alakatos@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2026 Red Hat, Inc.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="aide"
AIDE_DROPIN="/etc/aide.d/timer-test.conf"
SERVICE_UNIT="aide-check.service"
TIMER_UNIT="aide-check.timer"
AIDE_TEST_DIR="/var/aide-timer-test-dir"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun 'rlImport "./aide-helpers"' || rlDie "cannot import aide-helpers library"
    rlAssertRpm $PACKAGE
    rlRun "mkdir -p /var/lib/aide"
    rlRun "rlFileBackup --clean /var/lib/aide"
    rlRun "rlFileBackup --clean /etc/aide.d"
    rlRun "mkdir -p $AIDE_TEST_DIR"
    rlRun "touch $AIDE_TEST_DIR/file1"

    rlRun "echo '$AIDE_TEST_DIR/ p+i+n+u+g+s+sha256' > ${AIDE_DROPIN}" 0 \
      "Drop test watch rule into /etc/aide.d"
    rlRun "aide --config-check" 0 "Config must be valid with drop-in present"
    aideInit
  rlPhaseEnd; }

  rlPhaseStartTest "Unit files are shipped" && {
    rlRun "systemctl cat $SERVICE_UNIT" 0 "aide-check.service must be known to systemd"
    rlRun "systemctl cat $TIMER_UNIT" 0 "aide-check.timer must be known to systemd"
  rlPhaseEnd; }

  rlPhaseStartTest "Timer is disabled by default" && {
    ENABLED=$(systemctl is-enabled $TIMER_UNIT 2>/dev/null)
    rlRun "[[ '$ENABLED' == 'disabled' ]]" 0 \
      "aide-check.timer must be disabled by default, got: $ENABLED"
    STATE=$(systemctl show $TIMER_UNIT --property=ActiveState --value 2>/dev/null)
    rlRun "[[ '$STATE' == 'inactive' ]]" 0 \
      "aide-check.timer ActiveState must be 'inactive' by default, got: $STATE"
  rlPhaseEnd; }

  rlPhaseStartTest "Service unit has required directives" && {
    rlRun -s "systemctl cat $SERVICE_UNIT" 0 "Read effective service unit"
    rlAssertGrep "Type=oneshot" $rlRun_LOG
    rlAssertGrep "ExecStart=.*aide.*--check" $rlRun_LOG -E
    rlAssertGrep "SuccessExitStatus=" $rlRun_LOG
    rlAssertGrep "Nice=19" $rlRun_LOG
    rlAssertGrep "IOSchedulingClass=idle" $rlRun_LOG
    rm -f $rlRun_LOG
  rlPhaseEnd; }

  rlPhaseStartTest "Timer unit has required scheduling directives" && {
    rlRun -s "systemctl cat $TIMER_UNIT" 0 "Read effective timer unit"
    rlAssertGrep "OnCalendar=daily" $rlRun_LOG
    rlAssertGrep "Persistent=true" $rlRun_LOG
    rlAssertGrep "WantedBy=timers.target" $rlRun_LOG
    rm -f $rlRun_LOG
  rlPhaseEnd; }

  rlPhaseStartTest "Service succeeds when aide detects changes" && {
    # Modify a tracked file so aide --check exits with a non-zero code.
    # Without SuccessExitStatus= covering aide's result codes, systemd would
    # mark the service as failed even though aide ran correctly.
    rlRun "echo 'changed' > $AIDE_TEST_DIR/file1" 0 \
      "Modify tracked file to trigger a non-zero aide exit code"

    rlRun "systemctl daemon-reload" 0
    rlRun "systemctl start aide-check.service" 0 \
      "Starting the service must succeed even when aide detects changes"

    RESULT=$(systemctl show aide-check.service --property=Result --value)
    rlRun "[[ '$RESULT' == 'success' ]]" 0 \
      "Service Result must be 'success' when aide detects changes, got: $RESULT"
  rlPhaseEnd; }

  rlPhaseStartTest "Timer fires and triggers aide-check.service" && {
    DROPIN_DIR="/etc/systemd/system/${TIMER_UNIT}.d"
    rlRun "mkdir -p ${DROPIN_DIR}" 0 "Create drop-in directory"
    rlRun "printf '[Timer]\nOnCalendar=\nOnCalendar=minutely\nAccuracySec=1s\n' \
      > ${DROPIN_DIR}/ci-test-override.conf" 0 \
      "Install minutely OnCalendar drop-in"
    rlRun "systemctl daemon-reload" 0 "Reload daemon after drop-in install"
    BEFORE=$(date '+%s')
    rlRun "systemctl enable --now $TIMER_UNIT" 0 "Enable and start the timer"
    rlLog "Waiting 90s for timer to fire at the next minute boundary"
    sleep 90
    rlRun -s "journalctl -u $SERVICE_UNIT --since @${BEFORE} --no-pager" 0 \
      "Collect journal entries since timer was enabled"
    rlAssertGrep "aide-check.service" $rlRun_LOG
    rm -f $rlRun_LOG
    rlRun "systemctl disable --now $TIMER_UNIT" 0 "Disable timer after check"
    rlRun "systemctl revert $TIMER_UNIT" 0 \
      "Remove drop-in and restore unit to package defaults"
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    rlRun "systemctl disable --now $TIMER_UNIT" 0,1 \
      "Disable timer (idempotent if never enabled)"
    rlRun "systemctl reset-failed $SERVICE_UNIT" 0,1
    rlRun "systemctl daemon-reload"
    rlRun "rlFileRestore"
    rlRun "rm -rf $AIDE_TEST_DIR"
  rlPhaseEnd; }

  rlJournalPrintText
rlJournalEnd; }
