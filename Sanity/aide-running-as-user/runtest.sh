#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Sanity/aide-running-as-user
#   Description: tests aide running as a user
#   Author: Marek Šafařík <msafarik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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
TEST_DIR="/var/aide-testing-dir"
AIDE_CONFIG=aide.conf

rlJournalStart
    rlPhaseStartSetup
        if rlIsRHELLike "=<9"; then
            AIDE_CONFIG=aide_rhel_9.conf
        fi
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlAssertRpm $PACKAGE || rlDie 'cannot continue'
        rlRun "mkdir -p $TEST_DIR/{,data,db,log}"
        rlRun "mv $AIDE_CONFIG $TEST_DIR/aide.conf"
        rlRun "chmod a=rwx $TEST_DIR/*"
        rlRun "chmod a=rwx $testUserHomeDir/*"

        rlRun "testUserSetup"
        echo 'int main(void) { return 0; }' > $TEST_DIR/main.c
        # rlRun "chmod a+rw $TEST_DIR/main.c" 0
        # exe1="${testUserHomeDir}/exe1"
        # exe2="${testUserHomeDir}/exe2"
        exe1="${TEST_DIR}/data/exe1"
        exe2="${TEST_DIR}/data/exe2"
        rlRun "su -c 'aide -i -c $TEST_DIR/aide.conf' - $testUser" 0 "Initializing AIDE database as $testUser"
        rlRun "mv -f $TEST_DIR/db/aide.db.out.gz $TEST_DIR/db/aide.db.gz"
        rlRun "gcc $TEST_DIR/main.c -o $exe1" 0 "Creating binary $exe1"
        rlRun "gcc $TEST_DIR/main.c -g -o $exe2" 0 "Creating binary $exe2"
        rlRun "chmod a=rx $exe1 $exe2 ${testUserHomeDir}"

    rlPhaseEnd


    rlPhaseStartTest "Testing running as a user"
        rlRun -s "su -c 'aide --check -c $TEST_DIR/aide.conf' - $testUser" 1 "Checking changes as $testUser"
        rlRun "su -c 'aide --update -c $TEST_DIR/aide.conf' - $testUser" 1 "Updating AIDE database as $testUser"
        rlRun "mv -f $TEST_DIR/db/aide.db.out.gz $TEST_DIR/db/aide.db.gz"


        rlRun "su -c '$exe1' - $testUser" 0 "cache trusted binary $exe1"
        rlRun "su -c '$exe2' - $testUser" 0 "check untrusted binary $exe2"

        rlRun -s "su -c 'aide --check -c $TEST_DIR/aide.conf' - $testUser" 0 "Checking changes as $testUser"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -r $testUserHomeDir" 0 "Removing testing directory"
        rlRun "testUserCleanup"
        rlRun "rm -r $TEST_DIR" 0 "Removing testing directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
