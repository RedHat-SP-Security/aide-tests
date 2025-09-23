#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh for /Regression/rhel-1569-aide-sigbus-on-truncate
#   Author: Patrik Koncity <pkoncity@redhat.com>
#   Description: Verify that AIDE handles files being truncated
#                during a scan without crashing with SIGBUS.
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
#   This program is distributed in the hope that it is
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

# --- Test Variables ---
AIDE_TEST_DIR=/var/aide-testing-dir
TEST_FILE="$AIDE_TEST_DIR/largefile"
AIDE_CONF="$AIDE_TEST_DIR/aide.conf"
AIDE_LOG="aide_output.log"

rlJournalStart
    rlPhaseStartSetup
        rlLog "Setting up the test environment..."
        rlRun "mkdir -p $AIDE_TEST_DIR"
        pushd $AIDE_TEST_DIR
        rlLog "Creating a large test file to be scanned..."
        # Create a 1000MB file to give us time to truncate it during the scan
        rlRun "dd if=/dev/zero of=$TEST_FILE bs=1M count=2000"
        rlLog "Creating a custom AIDE configuration..."
        rlRun "cp /etc/aide.conf $AIDE_CONF"
        rlRun "sed -i 's#^@@define DBDIR.*#@@define DBDIR $AIDE_TEST_DIR#' $AIDE_CONF"
        rlRun "sed -i 's#^@@define LOGDIR.*#@@define LOGDIR $AIDE_TEST_DIR#' $AIDE_CONF"
        # Remove all default rules
        rlRun "sed -i '/^# Next decide what directories\\/files you want in the database./,\$d' $AIDE_CONF"
        # Add a rule to scan only our large test file
        rlRun "echo '$TEST_FILE NORMAL' >> $AIDE_CONF"
    rlPhaseEnd

    rlPhaseStartTest "AIDE should handle file truncation gracefully"
        rlLog "Starting 'aide --init' in the background..."
        # Run aide in the background, redirecting all output to a log file
        aide --config=$AIDE_CONF --init &> $AIDE_LOG 2>&1 &
        AIDE_PID=$!
        rlLog "AIDE process started with PID: $AIDE_PID"
        # race condition
        sleep 2
        rlLog "Truncating the test file while AIDE is running..."
        rlRun "truncate -s 0 $TEST_FILE"
        rlLog "Waiting for the AIDE process to complete..."
        wait $AIDE_PID
        AIDE_EXIT_CODE=$?
        rlLog "AIDE process finished with exit code: $AIDE_EXIT_CODE"
        rlLog "--- AIDE Output ---"
        rlRun "cat $AIDE_LOG"
        rlLog "--- End AIDE Output ---"
        rlAssertEquals "AIDE should exit with code 0" 0 $AIDE_EXIT_CODE
        #rlAssertNotGrep "Caught SIGBUS" $AIDE_LOG
        rlAssertNotGrep "Caught SIGBUS/SEGV" $AIDE_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        rlLog "Cleaning up..."
        popd
        rlRun "rm -rf $AIDE_TEST_DIR" 0 "Removing temporary directory"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd

