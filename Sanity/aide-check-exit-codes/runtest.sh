#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Regression/aide-check-exit-codes
#   Description: Check all possible exit codes according to the test coverage.
#   Author: Martin Zeleny <mzeleny@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="aide"
AIDE_CONF="/etc/aide.conf"

rlJournalStart
    rlPhaseStartSetup "Temp directory creation"
        rlRun 'rlImport "./aide-helpers"' || rlDie "cannot import aide-helpers library"
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun "rlFileBackup --clean ${AIDE_CONF}"
        rlRun "aidePrepareConfig ${AIDE_CONF}" 0 "Prepare aide config for testing"
        AIDE_TEST_DIR="/var/aide-testing-dir"
        rlRun "mkdir -p $AIDE_TEST_DIR"
        rlAssertGrep 'CONTENTEX' ${AIDE_CONF}
        rlRun "echo '$AIDE_TEST_DIR/ CONTENTEX' >> ${AIDE_CONF}" 0 "Add just one path aide the config"
        # aide called directly - config-check is a different command
        rlRun "aide --config-check" 0 "No harm on changing config"
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 1 (new files detected)"
        rlRun "aideInit" 0 "AIDE database initialization"
        rlRun "aideCheck" 0

        rlRun "testingFile=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add new temporary file - cannot be in /tmp"
        rlRun -s "aideCheck" 1 "Recheck consistency between database and filesystem"
        rlAssertGrep "found differences between database and filesystem" $rlRun_LOG
        rlAssertGrep ":\t*1" $rlRun_LOG -P
        rlRun "rm $rlRun_LOG"

        rlRun "rm ${testingFile}"
        rlRun "aideCheck" 0
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 2 (removed files detected)"
        rlRun "testingFile=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add new temporary file - cannot be in /tmp"
        rlRun "aideInit" 0 "AIDE database initialization"
        rlRun "aideCheck" 0

        rlRun "rm ${testingFile}"
        rlRun -s "aideCheck" 2 "Recheck consistency -- one file is missing"
        rlAssertGrep "found differences between database and filesystem" $rlRun_LOG
        rlAssertGrep ":\t*1" $rlRun_LOG -P
        rlRun "rm $rlRun_LOG"
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 4 (changed files detected)"
        rlRun "testingFile=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add new temporary file - cannot be in /tmp"
        rlRun "aideInit" 0 "AIDE database initialization"
        rlRun "aideCheck" 0

        rlRun "echo 'test data' > ${testingFile}" 0 "Overwriting testing file"
        rlRun -s "aideCheck" 4 "Recheck consistency -- one file is changed"
        rlAssertGrep "found differences between database and filesystem" $rlRun_LOG
        rlAssertGrep ":\t*1" $rlRun_LOG -P
        rlRun "rm $rlRun_LOG"

        rlRun "> ${testingFile}" 0 "Clearing testing file"
        rlRun "aideCheck" 0

        rlRun "rm ${testingFile}"
    rlPhaseEnd

    if ! rlIsFedora || rlIsFedora ">=45"; then
    rlPhaseStartTest "Checking exit code 3 (added + removed files detected)"
        rlRun "testingFileA=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add file A to watch dir"
        rlRun "aideInit" 0 "AIDE database initialization"
        rlRun "aideCheck" 0

        rlRun "testingFileB=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add file B - will be new since last init"
        rlRun "rm ${testingFileA}" 0 "Remove file A - was in database"
        rlRun -s "aideCheck" 3 "Recheck -- one added, one removed"
        rlAssertGrep "found differences between database and filesystem" $rlRun_LOG
        rlRun "rm $rlRun_LOG"

        rlRun "rm ${testingFileB}"
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 5 (added + changed files detected)"
        rlRun "testingFileA=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add file A to watch dir"
        rlRun "aideInit" 0 "AIDE database initialization"
        rlRun "aideCheck" 0

        rlRun "testingFileB=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add file B - will be new since last init"
        rlRun "echo 'test data' > ${testingFileA}" 0 "Modify file A - was in database"
        rlRun -s "aideCheck" 5 "Recheck -- one added, one changed"
        rlAssertGrep "found differences between database and filesystem" $rlRun_LOG
        rlRun "rm $rlRun_LOG"

        rlRun "rm ${testingFileA} ${testingFileB}"
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 6 (removed + changed files detected)"
        rlRun "testingFileA=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add file A to watch dir"
        rlRun "testingFileB=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add file B to watch dir"
        rlRun "aideInit" 0 "AIDE database initialization"
        rlRun "aideCheck" 0

        rlRun "rm ${testingFileA}" 0 "Remove file A - was in database"
        rlRun "echo 'test data' > ${testingFileB}" 0 "Modify file B - was in database"
        rlRun -s "aideCheck" 6 "Recheck -- one removed, one changed"
        rlAssertGrep "found differences between database and filesystem" $rlRun_LOG
        rlRun "rm $rlRun_LOG"

        rlRun "rm ${testingFileB}"
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 7 (added + removed + changed files detected)"
        rlRun "testingFileA=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add file A to watch dir"
        rlRun "testingFileB=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add file B to watch dir"
        rlRun "aideInit" 0 "AIDE database initialization"
        rlRun "aideCheck" 0

        rlRun "testingFileC=\$(mktemp --tmpdir=$AIDE_TEST_DIR)" 0 "Add file C - will be new since last init"
        rlRun "rm ${testingFileA}" 0 "Remove file A - was in database"
        rlRun "echo 'test data' > ${testingFileB}" 0 "Modify file B - was in database"
        rlRun -s "aideCheck" 7 "Recheck -- one added, one removed, one changed"
        rlAssertGrep "found differences between database and filesystem" $rlRun_LOG
        rlRun "rm $rlRun_LOG"

        rlRun "rm ${testingFileB} ${testingFileC}"
    rlPhaseEnd
    fi

    rlPhaseStartTest "Checking exit code 15 (Invalid argument error)"
        # aide called directly - testing invalid argument exit code
        rlRun "aide blahblah" 15
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 16 (Unimplemented function error)"
        rlLog "This exit code is not implemented in aide source code"
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 18 (IO error)"
        rlRun "rm ${DB}" 0 "Removing AIDE datbase for testing purpose"
        rlRun "aideCheck" 18
        rlRun "aideInit" 0 "AIDE database initialization"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm ${DB}" 0 "Removing AIDE datbase after finish all tests"
        rlRun "rlFileRestore" 0 "Restore aide config"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
        rm -rf $AIDE_TEST_DIR
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

