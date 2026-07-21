#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Sanity/aide-conf-selection-lines
#   Description: Check the proper file verficaton accroding to the selectors in aide.conf
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
    rlPhaseStartSetup
        rlRun 'rlImport "./aide-helpers"' || rlDie "cannot import aide-helpers library"
        rlAssertRpm $PACKAGE
        AIDE_TEST_DIR="/var/aide-testing-dir"
        rlRun "mkdir -p $AIDE_TEST_DIR/"
        #rlRun "TmpDir=\$(mktemp -d --tmpdir=$AIDE_TEST_DIR/)" 0 "Creating tmp directory"
        rlRun "pushd $AIDE_TEST_DIR"
        rlRun "rlFileBackup --clean --namespace mainBackup ${AIDE_CONF}"
        aidePrepareConfig ${AIDE_CONF}
        rlAssertGrep 'CONTENTEX' ${AIDE_CONF}
        rlRun "aide --config-check" 0 "No harm on changing config - cleaning config"
    rlPhaseEnd

    rlPhaseStartTest "Checking selector '/' functionlity"
        [ "$(pwd)" == "${AIDE_TEST_DIR}" ] || rlFail
        rlRun "mkdir myRoot"

        rlRun "echo \"${AIDE_TEST_DIR}/myRoot/ CONTENTEX\" >> ${AIDE_CONF}" 0 "Adding regular selection line"
        rlRun "tail -1 ${AIDE_CONF}" 0 "Listing AIDE config"
        rlRun "aide --config-check" 0 "No harm on changing config - adding regular selection line"
        aideInit
        aideCheck

        rlRun "touch myRoot/untrackedFile"
        rlRun "aide" 1 "Finding untracked file"
        rlRun "rm myRoot/untrackedFile"
    rlPhaseEnd

    rlPhaseStartTest "Checking selector '!' functionlity"
        rlRun "mkdir myRoot/dirNotCheck"
        rlRun "echo \"!${AIDE_TEST_DIR}/myRoot/dirNotCheck/\" >> ${AIDE_CONF}" 0 "Adding negative selection line"
        rlRun "tail -2 ${AIDE_CONF}" 0 "Listing AIDE config"
        rlRun "aide --config-check" 0 "No harm on changing config - adding negative selection line"

        aideInit
        aideCheck

        rlRun "touch myRoot/dirNotCheck/fileNotToTrack"
        aideCheck
    rlPhaseEnd

    rlPhaseStartTest "Checking selector '=' functionlity"
        rlRun "mkdir dirCheckJustThis"
        rlRun "echo \"=${AIDE_TEST_DIR}/dirCheckJustThis CONTENTEX\" >> ${AIDE_CONF}" 0 "Adding equals selection line"
        rlRun "tail -3 ${AIDE_CONF}" 0 "Listing AIDE config"
        rlRun "aide --config-check" 0 "No harm on changing config - adding equals selection line"

        aideInit
        aideCheck

        rlRun "rlFileBackup --clean --namespace chmodChange dirCheckJustThis"
        rlRun "chmod 777 dirCheckJustThis" 0 "Make configuration change on tracked directory"
        rlRun "aide" 4 "Find changed file"
        rlRun "rlFileRestore --namespace chmodChange"

        aideCheck

        rlRun "touch dirCheckJustThis/fileNotToTrack2"
        aideCheck
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm ${DB}" 0 "Removing AIDE datbase after finish all tests"
        rlRun "rlFileRestore --namespace mainBackup" 0 "Restore aide config"
        rlRun "popd"
        rlRun "rm -r $AIDE_TEST_DIR" 0 "Removing aide tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

