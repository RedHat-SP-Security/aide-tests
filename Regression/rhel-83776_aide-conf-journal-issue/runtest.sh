#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /Regression/rhel-83776_aide-conf-journal-issue
#   Description: Journal logs shouldn't be logged in aide database
#   Author: Patrik Koncity <pkoncity@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2025 Red Hat, Inc.
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

COOKIE=/var/tmp/aide-dracut-prehook-enabled
AIDE_TEST_DIR=/var/aide-testing-dir/
PACKAGE="aide"

rlJournalStart

    if [ ! -e $COOKIE ]; then
        rlPhaseStartSetup "Initial setup"
            rlAssertRpm $PACKAGE
            rlRun "mkdir -p /var/aide-testing-dir"
            rlFileBackup --clean "/var/log/"
            pushd $AIDE_TEST_DIR
            rlRun "cp /etc/aide.conf ."
            rlRun "sed -i 's#^@@define DBDIR.*#@@define DBDIR /var/aide-testing-dir#' aide.conf"
            rlRun "sed -i 's#^@@define LOGDIR.*#@@define LOGDIR /var/aide-testing-dir#' aide.conf"
            rlRun "mkdir -p /var/log/journal"
        rlPhaseEnd

        rlPhaseStartTest "Check aide check after logrotate execution"
            rlRun "aide --config=aide.conf --init" 
            rlRun "logrotate -f /etc/logrotate.conf"
            rlRun "mv /var/aide-testing-dir/aide.db.new.gz /var/aide-testing-dir/aide.db.gz"
            rlRun -s "aide --config=aide.conf --check"
            rlAssertNotGrep "File: /var/log/wtmp" $rlRun_LOG
            rlRun "rm -rf /var/aide-testing-dir/aide.db.gz"
            rlRun "touch $COOKIE"
            popd
        rlPhaseEnd

        tmt-reboot

    else

        rlPhaseStartTest "Check issue after reboot and journalctl rotate"
            pushd $AIDE_TEST_DIR
            rlRun "rm $COOKIE"
            rlRun "aide --config=aide.conf --init"
            rlRun "journalctl --rotate"
            rlRun "mv /var/aide-testing-dir/aide.db.new.gz /var/aide-testing-dir/aide.db.gz"
            rlRun -s "aide --config=aide.conf --check"
            rlAssertNotGrep "/var/log/journal" $rlRun_LOG
        rlPhaseEnd

        rlPhaseStartCleanup
            rlLog "Cleaning up..."
            popd
            rlRun "rm -rf $AIDE_TEST_DIR" 0 "Removing temporary directory"
            rlFileRestore "/var/log/"
        rlPhaseEnd
    fi
rlJournalPrintText
rlJournalEnd

