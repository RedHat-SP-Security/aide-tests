#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Regression/Check-no-weird-lines-in-etc-aide-conf
#   Description: Check no weird lines in /etc/aide.conf
#   Author: Martin Zeleny <mzeleny@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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
CONFIG="/etc/aide.conf"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    rlPhaseStartTest "Check no weird lines in ${CONFIG}"
        rlLog "Files from tcpwrappers package, which is deprecated and removed"
        rlAssertNotGrep "/etc/hosts\\." "${CONFIG}"

        rlLog "Mysterious file. What is 'and-httpd'?"
        rlAssertNotGrep "and-" "${CONFIG}"

        rlLog "Check for duplicities in ${CONFIG}"
        rlRun "grep -e '^/' -e '^!' ${CONFIG} | cut -d ' ' -f 1 | sort | uniq -d | tee aide_conf_duplicities"
        if [ ! -s  aide_conf_duplicities ]; then
            rlLog "No duplicate lines in ${CONFIG}"
        else
            rlFail "Find duplicities in ${CONFIG}"
            rlRun "cat aide_conf_duplicities"
            rlFileSubmit "aide_conf_duplicities"
        fi
        rm "aide_conf_duplicities"
    rlPhaseEnd


    rlPhaseStartTest "Check that all paths in ${COFING} aim to existing system file (from the 'repoquery -al' command)"
        rlRun "grep -e '^/' -e '^!' ${CONFIG} | cut -d ' ' -f 1 > aide_config_paths" \
            0 "Get all paths from aide config file"
        rlRun "cat aide_config_paths \
            | tr -d '!$~*' \
            | grep -v \
                -e '/etc/tmux.conf' \
                -e '/etc/hosts.allow' \
                -e '/etc/hosts.deny' \
                -e '/etc/resolv.conf' \
                -e '/var/log/faillog' \
                -e '/var/log/aide.log' \
                -e '/var/run/utmp' \
                -e '/etc/ld.so.preload' \
                -e '/etc/at.allow' \
                -e '/etc/cron.allow' \
                -e '/var/spool/cron/root' \
                -e '/etc/aliases.db' \
                -e '/etc/named.iscdlv.key'\
                -e '/var/log/and-httpd' \
                -e '/root/.xauth' \
                -e '/etc/xinetd.conf' \
                -e '/etc/xinetd.d' \
                -e '/etc/securetty' \
                -e '/root/' \
                -e '/etc/.' \
                -e '/var/spool/at' \
            > aide_config_paths_2" \
            0 "Sanitaze aide config paths - remove paths that are not part of 'repoquery -al'"
            #/var/spool/at reported https://bugzilla.redhat.com/show_bug.cgi?id=2396330
        [[ $(rlGetArch) =~ "s390" ]] && rlRun "sed -i '\|/etc/grub.d|d' aide_config_paths_2" 0 \
            "Removing /etc/grub.d aide configured path: not present on s390x"
        [[ $(rlGetArch) =~ "s390" ]] || [[ $(rlGetArch) =~ "ppc64le" ]] && rlRun "sed -i '\|/boot/grub2/grubenv|d' aide_config_paths_2" 0 \
            "Removing /boot/grub2/grubenv aide configured path: not present on s390x"
        rlRun "mv aide_config_paths_2 aide_config_paths"
        rlRun "wc -l aide_config_paths" 0 "Count of paths in aide config"
        rlLog "Check presence of each line in aide_config_paths in system_files"
        COUNTER=0
        for path in $(cat aide_config_paths); do
            OUTPUT_REPOQUERY=$(repoquery -qf ${path})
            if [ -z "$OUTPUT_REPOQUERY" ]; then
                rlFail "$path from aide config  didn't match system files"
                ((COUNTER++))
            fi
        done
        # After checking all paths, use the counter to decide the final result.
        if [ "$COUNTER" -gt 0 ]; then
            # Use rlFail here to fail the test with a final summary.
            rlFail "${COUNTER} AIDE path(s) were not found in any system files."
        else
            rlLog "SUCCESS: All paths were found in system packages."
        fi
    rlPhaseEnd


    rlPhaseStartTest "Do not include /var/spool/anacron - it changes daily - bz1957656"
        rlAssertNotGrep "/var/spool/anacron CONTENT" "${CONFIG}"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
