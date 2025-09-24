#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /Regression/rhel-1382_rhel-59170
#   Author: Patrik Koncity <pkoncity@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2025 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1


rlJournalStart
    rlPhaseStartSetup
        AIDE_TEST_DIR=/var/aide-testing-dir/
        rlRun "mkdir -p /var/aide-testing-dir"
        pushd $AIDE_TEST_DIR
        rlLog "Test directory created and working inside: $AIDE_TEST_DIR"
        rlLog "Copying and adjusting /etc/aide.conf"
        rlRun "cp /etc/aide.conf ."
        rlRun "sed -i 's#^@@define DBDIR.*#@@define DBDIR /var/aide-testing-dir#' aide.conf"
        rlRun "sed -i 's#^@@define LOGDIR.*#@@define LOGDIR /var/aide-testing-dir#' aide.conf"
        rlRun "sed -i '/^# Next decide what directories\/files you want in the database./,\$d' aide.conf"
        rlRun "echo -e '!/run d\n/run R' | tee -a aide.conf"
    rlPhaseEnd

    rlPhaseStartTest "Check aide --init correctly measure files and not containing any warnings"
        rlLog "Initializing AIDE database locally..."
        rlRun -s "aide --config=aide.conf --init" 0 "AIDE initialization"
        if rlIsRHELLike ">10.1" ; then
            rlAssertNotGrep "WARNING: /var/aide-testing-dir/aide.db.new.gz: gnutls_hash_init (stribog256) failed for '/var/aide-testing-dir/aide.db.new.gz'" $rlRun_LOG
            rlAssertNotGrep "WARNING: /var/aide-testing-dir/aide.db.new.gz: gnutls_hash_init (stribog512) failed for '/var/aide-testing-dir/aide.db.new.gz'" $rlRun_LOG
        fi
        rlAssertNotGrep "Number of entries:	0" $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        rlLog "Cleaning up..."
        popd
        rlRun "rm -rf $AIDE_TEST_DIR" 0 "Removing temporary directory"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
