#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Sanity/aide-dropin-include-directive
#   Description: Test aide drop-in include directive and /etc/aide.d properties
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
DROPIN_CONF="/etc/aide.d/test-dropin.conf"
WATCH_DIR="/tmp/aide-dropin-test-dir"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlAssertRpm $PACKAGE
    rlRun "rlFileBackup --clean /etc/aide.d"
    rlRun "rlFileBackup --clean /var/lib/aide"
    rlRun "mkdir -p $WATCH_DIR"
    rlRun "echo 'original content' > $WATCH_DIR/testfile"
  rlPhaseEnd; }

  rlPhaseStartTest "/etc/aide.d directory properties" && {
    rlAssertExists /etc/aide.d
    rlRun "test -d /etc/aide.d" 0 "/etc/aide.d must be a directory"
    rlRun "[[ $(stat -c '%a' /etc/aide.d) == '700' ]]" 0 \
      "/etc/aide.d must have mode 0700"
    rlRun "[[ $(stat -c '%U:%G' /etc/aide.d) == 'root:root' ]]" 0 \
      "/etc/aide.d must be owned by root:root"
    rlRun "matchpathcon -V /etc/aide.d" 0 \
      "/etc/aide.d must have the correct SELinux context"
  rlPhaseEnd; }

  rlPhaseStartTest "/etc/aide.conf contains the @@include directive for /etc/aide.d" && {
    rlRun "grep -E '@@include[[:space:]]*/etc/aide\.d' /etc/aide.conf" 0 \
      "/etc/aide.conf must contain an @@include directive for /etc/aide.d"
    rlRun "grep -E '@@include[[:space:]]*/etc/aide\.d.*\\\.conf' /etc/aide.conf" 0 \
      "@@include directive must filter for .conf files only"
  rlPhaseEnd; }

  rlPhaseStartTest "Drop-in .conf file is loaded and its rules take effect" && {
    rlRun "echo '$WATCH_DIR p+i+n+u+g+s+sha256' > $DROPIN_CONF"
    rlRun "aide --config-check" 0 \
      "Config must be valid with the drop-in present"
    rlRun "aide --init" 0 "Initialize aide database with drop-in rule active"
    rlRun "mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz" 0 \
      "Promote newly initialized database"
    rlRun "echo 'modified content' > $WATCH_DIR/testfile"
    rlRun -s "aide --check" 4 \
      "aide must detect changes in the drop-in monitored directory"
    rlAssertGrep "$WATCH_DIR/testfile" $rlRun_LOG
    rm -f $rlRun_LOG
  rlPhaseEnd; }

  rlPhaseStartTest "Drop-in .conf file with improper permissions is rejected" && {
    rlRun "chmod 0666 $DROPIN_CONF" 0 \
      "Make drop-in world-writable (improper permissions)"
    rlRun "aide --config-check" 17 \
      "aide must reject a world-writable drop-in during config check"
    rlRun "aide --init" 17 \
      "aide --init must fail when drop-in is world-writable"
    rlRun "aide --check" 17 \
      "aide --check must fail when drop-in is world-writable"

    rlRun "chmod 0660 $DROPIN_CONF" 0 \
      "Make drop-in group-writable (improper permissions)"
    rlRun "aide --config-check" 17 \
      "aide must reject a group-writable drop-in during config check"
    rlRun "aide --init" 17 \
      "aide --init must fail when drop-in is group-writable"
    rlRun "aide --check" 17 \
      "aide --check must fail when drop-in is group-writable"

    rlRun "chmod 0600 $DROPIN_CONF" 0 "Restore proper permissions"
  rlPhaseEnd; }

  rlPhaseStartTest "Non-.conf files in /etc/aide.d/ are silently ignored" && {
    rlRun "echo 'THIS IS NOT VALID AIDE CONFIG' > /etc/aide.d/ignore-me.bak"
    rlRun "aide --config-check" 0 \
      "aide must not attempt to parse non-.conf files in /etc/aide.d"
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    rlRun "rlFileRestore"
    rlRun "rm -rf $WATCH_DIR"
  rlPhaseEnd; }

  rlJournalPrintText
rlJournalEnd; }
