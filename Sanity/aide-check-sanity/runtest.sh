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
    rlAssertRpm $PACKAGE
    AIDE_TEST_DIR="/var/aide-testing-dir"
    if rlIsRHELLike "=<9.7"; then
      AIDE_CONF=aide_rhel_9.conf
    fi
    if [[ "${IN_PLACE_UPGRADE,,}" == "new" ]]; then
        if rlIsRHELLike ">=10"; then
          rlRun "mv $AIDE_CONF $AIDE_TEST_DIR/aide.conf"
        fi
        if rlIsRHELLike "=<9"; then
            rlRun "mv $AIDE_CONF $AIDE_TEST_DIR/aide.conf"
        fi
    fi
    [[ "${IN_PLACE_UPGRADE,,}" != "new" ]] && {
      rlRun "rlFileBackup --clean $AIDE_TEST_DIR"
      rlRun "mkdir -p $AIDE_TEST_DIR/{,data,db,log}"
      rlRun "mv $AIDE_CONF $AIDE_TEST_DIR/aide.conf"
      rlRun "touch $AIDE_TEST_DIR/data/empty_file"
      rlRun "echo 'x' > $AIDE_TEST_DIR/data/file1"
      rlRun "echo 'y' > $AIDE_TEST_DIR/data/file2"
      rlRun "echo 'z' > $AIDE_TEST_DIR/data/file3"
      rlRun "chmod a=rw $AIDE_TEST_DIR/data/*"
      rlRun "aide -i -c $AIDE_TEST_DIR/aide.conf"
      rlRun "mv -f $AIDE_TEST_DIR/db/aide.db.out.gz $AIDE_TEST_DIR/db/aide.db.gz"
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
    elif rlIsFedora ">41" || rlIsRHELLike '>=9.8'; then
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

  [[ -z "$IN_PLACE_UPGRADE" ]] && rlPhaseStartCleanup && {
    rlRun "rlFileRestore"
    rlRun "rm -rf $AIDE_TEST_DIR"
  rlPhaseEnd; }
  
  rlJournalPrintText
rlJournalEnd; }
