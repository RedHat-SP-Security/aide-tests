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

AIDE_CONFIG="/etc/aide.conf"

function checkUpdateAide {
    rlRun -s "su -c 'aide --update -c' - $testUser" $1 "Updating AIDE database as $testUser"
    rlRun "mv -f $TEST_DIR/db/aide.db.out.gz $TEST_DIR/db/aide.db.gz" 0 "Moving database with new data"
}

# sedom prepisat @@define DBDIR /var/lib/aide
# @@define LOGDIR /var/log/aide na testing dir(su v configu) a taktiez prekopirovat tie implicitne vytvorene subory do testing diru

rlJournalStart
    rlPhaseStartSetup
#    bash
#    rlRun "aide --init"
#    bash
   rlRun "chmod a=rwx /etc/aide.conf"
  rlRun "chmod a=rwx /var/lib/aide/*"
    rlRun "chmod a=rwx /var/log/aide/aide.log"
#             rlRun "chmod a=rwx /var/log/aide/aide.db.new.gz"
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlAssertRpm $PACKAGE || rlDie 'cannot continue'
        rlRun "mkdir -p $TEST_DIR/{,data,db,log}"
        # rlRun "mv $AIDE_CONFIG $TEST_DIR/aide.conf"
        rlRun "chmod a=rwx $TEST_DIR/*"
        rlRun "chmod a=rwx $testUserHomeDir/*"
        rlRun "testUserSetup"
        rlRun "echo 'Random text' > $TEST_DIR/data/random.txt"
        rlRun "chmod a=r $TEST_DIR/data/random.txt"
        echo 'int main(void) { return 0; }' > $TEST_DIR/main.c
        exe1="${TEST_DIR}/data/exe1"
        exe2="${TEST_DIR}/data/exe2"
        rlRun "su -c 'aide -i' - $testUser" 0 "Initializing AIDE database as $testUser"
        bash
        rlRun "mv -f $TEST_DIR/db/aide.db.out.gz $TEST_DIR/db/aide.db.gz" 0 "Moving database with new data"
    rlPhaseEnd

    rlPhaseStartTest "Testing running as a user (new files)"
        rlRun "gcc $TEST_DIR/main.c -o $exe1" 0 "Creating binary $exe1"
        rlRun "gcc $TEST_DIR/main.c -g -o $exe2" 0 "Creating binary $exe2"
        checkUpdateAide 1
    rlPhaseEnd

    rlPhaseStartTest "Testing running as a user (adding permissions)"
        rlRun "chmod a=rwx $exe1 $exe2 ${testUserHomeDir}" 0 "Adding permissions for binaries and home directory"
        checkUpdateAide 4
    rlPhaseEnd

    rlPhaseStartTest "Making changes and restoring them"
        #    rlRun "mv $TEST_DIR/aide.conf $AIDE_CONFIG "
        rlRun "mv $TEST_DIR/data/random.txt $TEST_DIR/"
        rlRun "mv $TEST_DIR/random.txt $TEST_DIR/data/random.txt"
        rlRun "chmod a=rwx $TEST_DIR/data/random.txt" 0 "Adding permissions for random.txt"
        rlRun "echo 'Different text' > $TEST_DIR/data/random.txt"
        rlRun -s "su -c 'aide --check -c $CONFIG_FILE' - $testUser" 4 "Checking changes"
        rlRun "echo 'Random text' > $TEST_DIR/data/random.txt"
        rlRun "chmod a=r $TEST_DIR/data/random.txt" 0 "Reverting permissions for random.txt"
        checkUpdateAide 0
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -r $testUserHomeDir" 0 "Removing testing directory"
        rlRun "testUserCleanup"
        rlRun "rm -r $TEST_DIR" 0 "Removing testing directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
