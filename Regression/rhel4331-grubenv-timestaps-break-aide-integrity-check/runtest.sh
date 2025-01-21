#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /Regression/rhel4331-grubenv-timestaps-break-aide-integrity-check
#   Description: Check /boot/grub2/grubenv's timestamp modification doesn't break aide integrity check
#   Author: Patrik Koncity <pkoncity@redhat.com>
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="aide"
AIDE_CONF="/etc/aide.conf"
GRUB_SYMLINK_PATH="/etc/systemd/system/grub-boot-success.service"

DBDIR=$(sed -n -e 's/@@define DBDIR \([a-z/]\+\)/\1/p' "$AIDE_CONF")
if rlIsRHELLike "=<9"; then
  DB=$(grep "^database=" "$AIDE_CONF" | cut -d/ -f2-)
else
  DB=$(grep "^database_in=" "$AIDE_CONF" | cut -d/ -f2-)
fi
DB="${DBDIR}/${DB}"

DBnew=$(grep "^database_out=" "$AIDE_CONF" | cut -d/ -f2-)
DBnew="${DBDIR}/${DBnew}"

aideInit() {
    rlRun -s "aide -i" 0 "AIDE database initialization"
    [ -f "$DBnew" ] || rlFail "New database is not initialized"
    [ -n "$DB" ] || rlFail "Database path is not set correctly"

    rlRun "mv ${DBnew} ${DB}" 0 "Move new AIDE initialed database to the place of the default one."
    rlRun "rm $rlRun_LOG"
}

aideCheck() {
    rlRun -s "aide" 0 "Checking default behaviour -- database check"
    rlAssertGrep "Looks okay!" $rlRun_LOG
    rlRun "rm $rlRun_LOG"
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
        rlAssertRpm $PACKAGE
        rlRun "rlFileBackup --clean ${AIDE_CONF}"
        if ! grep -q -e 'CONTENTEX' ${AIDE_CONF}; then
            rlRun "echo \"CONTENTEX = sha256+p+u+g+n+acl+selinux+xattrs\" >> ${AIDE_CONF}" 0 "Adding CONTENT_EX group"
        fi
        rlRun "echo '/boot/grub2/grubenv CONTENTEX' >> ${AIDE_CONF}" 0 "Add just one path aide the config"
        rlRun "ln -s /usr/lib/systemd/user/grub-boot-success.service ${GRUB_SYMLINK_PATH}"
        rlRun "systemctl enable grub-boot-success.service"
        #Provide initialization of database
        rlRun "aideInit"
    rlPhaseEnd

    rlPhaseStartTest "Check that grubenv parameter change doesnt break aide integrity check."
        rlRun "aideCheck"
        rlRun "systemctl start grub-boot-success.service"
        #rlRun "sleep 120"
        rlRun "aideCheck"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rlFileRestore" 0 "Restore backuped files"
        rlRun "rm ${GRUB_SYMLINK_PATH}"
        #set boot_success flag to default value
        rlRun "grub2-editenv /boot/grub2/grubenv set boot_success=0"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
