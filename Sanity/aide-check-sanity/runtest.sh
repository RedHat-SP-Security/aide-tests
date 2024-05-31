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
    [[ "${IN_PLACE_UPGRADE,,}" != "new" ]] && {
      rlRun "rlFileBackup --clean /root/aide/"
      rlRun "mkdir -p /root/aide/{,data,db,log}"
        if rlIsRHELLike "=<9"; then
            AIDE_CONF=aide_rhel_9.conf

        fi
      rlRun "mv $AIDE_CONF /root/aide/aide.conf"
      rlRun "touch /root/aide/data/empty_file"
      rlRun "echo 'x' > /root/aide/data/file1"
      rlRun "echo 'y' > /root/aide/data/file2"
      rlRun "echo 'z' > /root/aide/data/file3"
      rlRun "chmod a=rw /root/aide/data/*"
      rlRun "aide -i -c /root/aide/aide.conf"
      rlRun "mv -f /root/aide/db/aide.db.out.gz /root/aide/db/aide.db.gz"
      rlRun "echo 'A' > /root/aide/data/file4"
      rlRun "rm -f /root/aide/data/file1"
      rlRun "echo 'B' > /root/aide/data/file2"
      rlRun "chmod a+x /root/aide/data/file3"
    }
  rlPhaseEnd; }

  rlPhaseStartTest "aide check" && {
    rlRun -s "aide --check -c /root/aide/aide.conf" 0-255
    
    rlAssertGrep "file=/root/aide/data/file1; removed" $rlRun_LOG
    rlAssertGrep "file=/root/aide/data/file2;SHA256_old=O7Krtp67J/v+Y8djliTG7F4zG4QaW8jD68ELkoXpCHc=;SHA256_new=wM3nf6j++X1HbBCq09LVT8wvM2FA0HNlHC3Mzx43n9Y=" $rlRun_LOG
    rlAssertGrep "file=/root/aide/data/file3;Perm_old=-rw-rw-rw-;Perm_new=-rwxrwxrwx" $rlRun_LOG
    rlAssertGrep "file=/root/aide/data/file4; added" $rlRun_LOG
    rm -f $rlRun_LOG
  rlPhaseEnd; }

  [[ -z "$IN_PLACE_UPGRADE" ]] && rlPhaseStartCleanup && {
    rlRun "rlFileRestore"
  rlPhaseEnd; }
  
  rlJournalPrintText
rlJournalEnd; }
