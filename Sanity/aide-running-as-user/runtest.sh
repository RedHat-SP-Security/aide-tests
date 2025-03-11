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
        rlRun "touch $TEST_DIR/data/empty.txt"
        rlRun "echo 'a' > $TEST_DIR/data/a.txt"
        rlRun "echo 'b' > $TEST_DIR/data/b.txt"
        rlRun "chmod a=rw $TEST_DIR/data/*"
        rlRun "aide -i -c $TEST_DIR/aide.conf"

        # rlRun "pushd $TEST_DIR"
        echo 'int main(void) { return 0; }' > $TEST_DIR/main.c
        exe1="${testUserHomeDir}/exe1"
        exe2="${testUserHomeDir}/exe2"
        rlRun "gcc $TEST_DIR/main.c -o $exe1" 0 "Creating binary $exe1"
        rlRun "gcc $TEST_DIR/main.c -g -o $exe2" 0 "Creating binary $exe2"
        rlRun "chmod a+rx $exe1 $exe2 ${testUserHomeDir}"
        rlRun "testUserSetup"
    rlPhaseEnd


    rlPhaseStartTest "Checking axioms"
        rlRun "su -c '$exe1' - $testUser" 0 "cache trusted binary $exe1"
        rlRun "su -c '$exe2' - $testUser" 0 "check untrusted binary $exe2"
        rlRun "touch file.txt" 0 "Creating simple file" 
        rlRun "echo 'Random text' > file.txt" 0  "Filling the file with text"
        rlAssertGrep "Random text" "file.txt"
    rlPhaseEnd

    rlPhaseStartCleanup
        # rlRun "popd"
        rlRun "testUserCleanup"
        rlRun "rm -r $TEST_DIR" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
