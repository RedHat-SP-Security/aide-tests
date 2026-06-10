#!/bin/bash
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup "Setup"
        rlAssertRpm "aide"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd \$TmpDir"
        rlRun "cp /etc/aide.conf ."
        rlRun "sed -i 's|^database=.*|database=file:aide.db.gz|' aide.conf"
        rlRun "sed -i 's|^database_out=.*|database_out=file:aide.db.new.gz|' aide.conf"
    rlPhaseEnd

    rlPhaseStartTest "Test AIDE performance with and without multi-threading"
        # Time the execution of "aide --init" with default multi-threading
        rlRun "SECONDS=0; aide --init -c aide.conf; multithread_time=\$SECONDS" "Running aide --init with multi-threading"
        rlLog "Multi-threaded execution time: \$multithread_time seconds"
        rlRun "rm -f aide.db.new.gz"

        # Time the execution of "aide --init" with multi-threading disabled
        rlRun "SECONDS=0; aide --init -c aide.conf -W 0; singlethread_time=\$SECONDS" "Running aide --init without multi-threading"
        rlLog "Single-threaded execution time: \$singlethread_time seconds"

        # Compare the execution times. Allow for a 20% tolerance.
        # The single-threaded time should be less than or equal to the multi-threaded time plus the tolerance.
        # In other words, the multi-threaded time should not be more than 20% slower than the single-threaded time.
        #
        # The bug report shows the multi-threaded version is slower, so we are checking that the fix
        # makes the multi-threaded version not significantly slower.
        #
        # Test should fail if: singlethread_time * 1.2 < multithread_time
        # Test should pass if: singlethread_time * 1.2 >= multithread_time
        #
        # Using integer arithmetic for the comparison.
        # We are checking if (singlethread_time * 120) / 100 < multithread_time
        allowed_time=\$((singlethread_time * 120 / 100))
        rlLog "Allowed time for multi-threaded execution (20% tolerance): \$allowed_time seconds"

        if [ "\$multithread_time" -gt "\$allowed_time" ]; then
            rlFail "AIDE with multi-threading is more than 20% slower than without."
        else
            rlPass "AIDE with multi-threading is not significantly slower than without."
        fi
    rlPhaseEnd

    rlPhaseStartCleanup "Cleanup"
        rlRun "popd"
        rlRun "rm -rf \$TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
