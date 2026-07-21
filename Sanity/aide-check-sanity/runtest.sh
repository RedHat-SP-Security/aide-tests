#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Sanity/aide-check-sanity
#   Description: basic check sanity
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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
AIDE_CONF=aide.conf

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun 'rlImport "./aide-helpers"' || rlDie "cannot import aide-helpers library"
    rlAssertRpm $PACKAGE
    AIDE_TEST_DIR="/var/aide-testing-dir"
    AIDE_CONF=$(aideGetRhelConfig aide.conf)
    if [[ "${IN_PLACE_UPGRADE,,}" == "new" ]]; then
        if rlIsRHELLike ">=10"; then
          rlRun "cp $AIDE_CONF $AIDE_TEST_DIR/aide.conf"
        fi
        if rlIsRHELLike "=<9"; then
            # Verify %post automatically migrated the default /etc/aide.conf
            if command -v aide-migrate-config &>/dev/null; then
                if [ -f /var/log/aide/aide-migrate.log ]; then
                    rlRun "cat /var/log/aide/aide-migrate.log" 0 \
                        "Show automatic migration log from %post"
                fi
                rlRun "aide --config-check -c /etc/aide.conf" 0 \
                    "Default config must be valid after package upgrade"
            fi
            rlRun "cp $AIDE_CONF $AIDE_TEST_DIR/aide.conf"
            rlLog "(adding @@end_db)"
            rlRun "zcat $AIDE_TEST_DIR/db/aide.db.gz > /tmp/aide.db.tmp"
            rlRun "echo '@@end_db' >> /tmp/aide.db.tmp"
            rlRun "gzip -c /tmp/aide.db.tmp > $AIDE_TEST_DIR/db/aide.db.gz"
            rlRun "rm -f /tmp/aide.db.tmp"
            # Migrate the test config to 0.19+ syntax
            if command -v aide-migrate-config &>/dev/null; then
                rlRun "aide-migrate-config --skip-init $AIDE_TEST_DIR/aide.conf" 0 \
                    "Migrate test config to 0.19+ syntax"
            fi
        fi
    fi
    [[ "${IN_PLACE_UPGRADE,,}" != "new" ]] && {
      rlRun "rlFileBackup --clean $AIDE_TEST_DIR"
      rlRun "mkdir -p $AIDE_TEST_DIR/{,data,db,log}"
      rlRun "cp $AIDE_CONF $AIDE_TEST_DIR/aide.conf"
      rlRun "touch $AIDE_TEST_DIR/data/empty_file"
      rlRun "echo 'x' > $AIDE_TEST_DIR/data/file1"
      rlRun "echo 'y' > $AIDE_TEST_DIR/data/file2"
      rlRun "echo 'z' > $AIDE_TEST_DIR/data/file3"
      rlRun "chmod a=rw $AIDE_TEST_DIR/data/*"
      aideInit -c $AIDE_TEST_DIR/aide.conf
      rlRun "echo 'A' > $AIDE_TEST_DIR/data/file4"
      rlRun "rm -f $AIDE_TEST_DIR/data/file1"
      rlRun "echo 'B' > $AIDE_TEST_DIR/data/file2"
      rlRun "chmod a+x $AIDE_TEST_DIR/data/file3"
    }
  rlPhaseEnd; }

  rlPhaseStartTest "aide check" && {
    rlRun -s "aide --check -c $AIDE_TEST_DIR/aide.conf" 0-255
    if rlIsRHELLike "<9.8" ; then
      rlAssertGrep "file=$AIDE_TEST_DIR/data/file1; removed" $rlRun_LOG
      rlAssertGrep "file=$AIDE_TEST_DIR/data/file2;SHA256_old=O7Krtp67J/v+Y8djliTG7F4zG4QaW8jD68ELkoXpCHc=;SHA256_new=wM3nf6j++X1HbBCq09LVT8wvM2FA0HNlHC3Mzx43n9Y=" $rlRun_LOG
      rlAssertGrep "file=$AIDE_TEST_DIR/data/file3;Perm_old=-rw-rw-rw-;Perm_new=-rwxrwxrwx" $rlRun_LOG
      rlAssertGrep "file=$AIDE_TEST_DIR/data/file4; added" $rlRun_LOG
    elif rlIsFedora ">41" || rpm -q aide | grep -q 'aide-0\.19'; then
      rlAssertGrep "f-----------------: /var/aide-testing-dir/data/file1" $rlRun_LOG
      rlAssertGrep "File: $AIDE_TEST_DIR/data/file2\n
 SHA256    : O7Krtp67J/v+Y8djliTG7F4zG4QaW8jD | wM3nf6j++X1HbBCq09LVT8wvM2FA0HNl\n
             68ELkoXpCHc=                     | HC3Mzx43n9Y=" $rlRun_LOG
      rlAssertGrep "File: $AIDE_TEST_DIR/data/file3\n
 Perm      : -rw-rw-rw-                       | -rwxrwxrwx" $rlRun_LOG
      rlAssertGrep "f+++++++++++++++++: $AIDE_TEST_DIR/data/file4" $rlRun_LOG
    else
      rlAssertGrep "f----------------: $AIDE_TEST_DIR/data/file1" $rlRun_LOG
      rlAssertGrep "File: $AIDE_TEST_DIR/data/file2\n
 SHA256    : O7Krtp67J/v+Y8djliTG7F4zG4QaW8jD | wM3nf6j++X1HbBCq09LVT8wvM2FA0HNl\n
             68ELkoXpCHc=                     | HC3Mzx43n9Y=" $rlRun_LOG
      rlAssertGrep "File: $AIDE_TEST_DIR/data/file3\n
 Perm      : -rw-rw-rw-                       | -rwxrwxrwx" $rlRun_LOG
      rlAssertGrep "f++++++++++++++++: $AIDE_TEST_DIR/data/file4" $rlRun_LOG
    fi
    rm -f $rlRun_LOG
  rlPhaseEnd; }

  # num_workers support: RHEL 9.9+ and 10.3+ only; 10.0-10.2 lack the implementation
  if { rlIsRHELLike ">=9.9" && ! rlIsRHELLike ">=10"; } || rlIsRHELLike ">=10.3" || rlIsFedora ">=45"; then
    rlPhaseStartTest "num_workers set in default /etc/aide.conf" && {
      rlRun "grep -E '^[[:space:]]*num_workers[[:space:]]*=' /etc/aide.conf" 0 \
        "num_workers must be present in /etc/aide.conf"
      NUM_W=$(grep -E '^[[:space:]]*num_workers[[:space:]]*=' /etc/aide.conf \
              | awk -F'=' '{print $2}' | tr -d '[:space:]')
      rlRun "[[ '$NUM_W' -ne 1 ]]" 0 \
        "num_workers must not be 1 in default config, got: $NUM_W"
    rlPhaseEnd; }

    rlPhaseStartTest "aide --init with 4 workers is faster than with 1 worker" && {
      T_START=$(date +%s%3N)
      rlRun "aide --init -W 1" 0 "aide --init with 1 worker"
      T1=$(( $(date +%s%3N) - T_START ))
      rlLog "Time with 1 worker: ${T1} ms"

      T_START=$(date +%s%3N)
      rlRun "aide --init -W 4" 0 "aide --init with 4 workers"
      T4=$(( $(date +%s%3N) - T_START ))
      rlLog "Time with 4 workers: ${T4} ms"

      rlRun "[[ $T4 -lt $T1 ]]" 0 \
        "4 workers (${T4}ms) must be faster than 1 worker (${T1}ms)"
    rlPhaseEnd; }
  fi

  [[ -z "$IN_PLACE_UPGRADE" ]] && rlPhaseStartCleanup && {
    rlRun "rlFileRestore"
    rlRun "rm -rf $AIDE_TEST_DIR"
  rlPhaseEnd; }
  
  rlJournalPrintText
rlJournalEnd; }
