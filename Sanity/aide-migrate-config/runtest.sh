#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /aide-tests/Sanity/aide-migrate-config
#   Description: tests aide-migrate-config migration tool
#   Author: Patrik Koncity <pkoncity@redhat.com>
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
TEST_DIR="/var/aide-migrate-test"
LEGACY_CONF="legacy-aide.conf"

rlJournalStart

    rlPhaseStartSetup "Prepare test environment"
        rlRun 'rlImport "./aide-helpers"' || rlDie "cannot import aide-helpers library"
        rlAssertRpm $PACKAGE
        rlRun "which aide-migrate-config" 0 "aide-migrate-config must be available"
        rlRun "mkdir -p $TEST_DIR/{data,db,log}"
        rlRun "echo 'test content' > $TEST_DIR/data/testfile.txt"
        rlRun "cp $LEGACY_CONF $TEST_DIR/aide.conf"
    rlPhaseEnd

    rlPhaseStartTest "Verify --dry-run reports changes without modifying"
        rlRun "cp $LEGACY_CONF $TEST_DIR/aide-dryrun.conf"
        rlRun -s "aide-migrate-config --dry-run --skip-init $TEST_DIR/aide-dryrun.conf 2>&1" 0 \
            "Dry-run must succeed"
        rlRun "cat $rlRun_LOG" 0 "Show dry-run output"
        rlAssertGrep "DRY-RUN mode" $rlRun_LOG
        rlAssertGrep "would rename" $rlRun_LOG
        rlAssertGrep "would remove hashsum" $rlRun_LOG
        rlAssertGrep "would replace S attribute" $rlRun_LOG
        rlAssertGrep "would replace deprecated @@ifdef" $rlRun_LOG
        rlRun "diff $LEGACY_CONF $TEST_DIR/aide-dryrun.conf" 0 \
            "Config must be unchanged after dry-run"
    rlPhaseEnd

    rlPhaseStartTest "aide --config-check fails with legacy config"
        rlRun -s "aide --config-check -c $TEST_DIR/aide.conf" 17 \
            "Legacy 0.16 config must fail config-check on aide 0.19+"
    rlPhaseEnd

    rlPhaseStartTest "aide --init fails with legacy config"
        rlRun "aide --init -c $TEST_DIR/aide.conf" 17 \
            "Legacy 0.16 config must fail init on aide 0.19+"
    rlPhaseEnd

    rlPhaseStartTest "Run aide-migrate-config"
        rlRun -s "aide-migrate-config --skip-init $TEST_DIR/aide.conf 2>&1" 0 \
            "Migration tool must succeed"
        rlAssertGrep "migration complete" $rlRun_LOG
        rlAssertGrep "aide --config-check passed" $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "Verify database= was renamed to database_in="
        rlAssertNotGrep '^database=' $TEST_DIR/aide.conf -E
        rlAssertGrep '^database_in=' $TEST_DIR/aide.conf -E
    rlPhaseEnd

    rlPhaseStartTest "Verify verbose= was replaced with log_level= and report_level="
        rlAssertNotGrep '^verbose=' $TEST_DIR/aide.conf -E
        rlAssertGrep '^log_level=' $TEST_DIR/aide.conf -E
        rlAssertGrep '^report_level=' $TEST_DIR/aide.conf -E
    rlPhaseEnd

    rlPhaseStartTest "Verify grouped= was renamed to report_grouped="
        rlAssertNotGrep '^grouped=' $TEST_DIR/aide.conf -E
        rlAssertGrep '^report_grouped=' $TEST_DIR/aide.conf -E
    rlPhaseEnd

    rlPhaseStartTest "Verify summarize_changes= was renamed to report_summarize_changes="
        rlAssertNotGrep '^summarize_changes=' $TEST_DIR/aide.conf -E
        rlAssertGrep '^report_summarize_changes=' $TEST_DIR/aide.conf -E
    rlPhaseEnd

    rlPhaseStartTest "Verify ignore_list= was renamed to report_ignore_changed_attrs="
        rlAssertNotGrep '^ignore_list=' $TEST_DIR/aide.conf -E
        rlAssertGrep '^report_ignore_changed_attrs=' $TEST_DIR/aide.conf -E
    rlPhaseEnd

    rlPhaseStartTest "Verify report_attributes= was renamed to report_force_attrs="
        rlAssertNotGrep '^report_attributes=' $TEST_DIR/aide.conf -E
        rlAssertGrep '^report_force_attrs=' $TEST_DIR/aide.conf -E
    rlPhaseEnd

    rlPhaseStartTest "Verify syslog_format is preserved after migration"
        rlAssertGrep '^syslog_format=yes' $TEST_DIR/aide.conf -E
    rlPhaseEnd

    rlPhaseStartTest "Verify e2fsattrs h was removed"
        rlRun -s "grep 'report_ignore_e2fsattrs' $TEST_DIR/aide.conf"
        rlAssertNotGrep 'h' $rlRun_LOG
        rlAssertGrep 'V' $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "Verify removed hashsums were stripped from non-comment lines"
        rlRun -s "grep -v '^#' $TEST_DIR/aide.conf"
        for hash in tiger haval crc32b crc32 whirlpool; do
            rlAssertNotGrep "$hash" $rlRun_LOG
        done
    rlPhaseEnd

    rlPhaseStartTest "Verify deprecated hashsums were stripped"
        rlRun -s "grep '^ALLXTRAHASHES' $TEST_DIR/aide.conf"
        rlAssertNotGrep 'sha1' $rlRun_LOG
        rlAssertNotGrep 'rmd160' $rlRun_LOG
        # sha256 and sha512 must remain
        rlAssertGrep 'sha256' $rlRun_LOG
        rlAssertGrep 'sha512' $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "Verify md5 and gost were stripped"
        rlRun -s "grep -v '^#' $TEST_DIR/aide.conf"
        rlAssertNotGrep 'md5' $rlRun_LOG
        rlAssertNotGrep 'gost' $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "Verify MHASHGROUP kept sha256 after removal of removed/deprecated hashes"
        rlRun -s "grep '^MHASHGROUP' $TEST_DIR/aide.conf"
        rlAssertGrep 'sha256' $rlRun_LOG
        rlAssertNotGrep 'haval' $rlRun_LOG
        rlAssertNotGrep 'crc32' $rlRun_LOG
        rlAssertNotGrep 'whirlpool' $rlRun_LOG
        rlAssertNotGrep 'gost' $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "Verify LEGACYCHECK md5 was replaced"
        rlRun -s "grep '^LEGACYCHECK' $TEST_DIR/aide.conf"
        rlAssertNotGrep 'md5' $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "Verify S attribute was replaced with growing+s"
        rlRun -s "grep '^LOG' $TEST_DIR/aide.conf"
        rlAssertGrep 'growing+s' $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "Verify deprecated macros were replaced"
        rlAssertNotGrep '@@ifdef' $TEST_DIR/aide.conf
        rlAssertNotGrep '@@ifndef' $TEST_DIR/aide.conf
        rlAssertNotGrep '@@ifhost' $TEST_DIR/aide.conf
        rlAssertNotGrep '@@ifnhost' $TEST_DIR/aide.conf
        rlAssertGrep '@@if defined' $TEST_DIR/aide.conf
        rlAssertGrep '@@if not defined' $TEST_DIR/aide.conf
        rlAssertGrep '@@if hostname' $TEST_DIR/aide.conf
        rlAssertGrep '@@if not hostname' $TEST_DIR/aide.conf
    rlPhaseEnd

    rlPhaseStartTest "Verify config-check passes after migration"
        rlRun "aide --config-check -c $TEST_DIR/aide.conf" 0 \
            "Migrated config must pass config-check"
    rlPhaseEnd

    rlPhaseStartTest "aide --init succeeds with migrated config"
        aideInit -c $TEST_DIR/aide.conf
    rlPhaseEnd

    rlPhaseStartTest "aide --check succeeds with migrated config"
        rlRun "aide --check -c $TEST_DIR/aide.conf" 0 \
            "aide --check must succeed with migrated config and fresh database"
    rlPhaseEnd

    rlPhaseStartTest "Migration is idempotent"
        rlRun -s "aide-migrate-config --skip-init $TEST_DIR/aide.conf 2>&1" 0 \
            "Second migration run must succeed"
        rlAssertGrep "no migration needed" $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "Verify backup was created"
        rlRun "ls $TEST_DIR/aide.conf.bak.*" 0 \
            "Backup file must exist"
    rlPhaseEnd

    rlPhaseStartCleanup "Clean up test environment"
        rlRun "rlFileSubmit $TEST_DIR/aide.conf migrated-aide.conf" 0-1 \
            "Submit migrated config for debugging"
        rlRun "rm -rf $TEST_DIR"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
