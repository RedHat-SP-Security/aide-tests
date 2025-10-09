#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /Regression/rhel-118491_lower_alpha_string_cant_be_used
#   Description: Scenario to check that lower alpha string can be used in AIDE configuration
#   Author: Patrik Koncity <pkoncity@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2025 Red Hat, Inc.
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

AIDE_TEST_DIR=/var/aide-testing-dir/
PACKAGE="aide"

rlJournalStart

        rlPhaseStartSetup "Initial setup"
            rlAssertRpm $PACKAGE
            rlRun "mkdir -p /var/aide-testing-dir"
            pushd $AIDE_TEST_DIR
            rlRun "cp /etc/aide.conf ."
            rlRun "sed -i 's#^@@define DBDIR.*#@@define DBDIR /var/aide-testing-dir#' aide.conf"
            rlRun "sed -i 's#^@@define LOGDIR.*#@@define LOGDIR /var/aide-testing-dir#' aide.conf"
            # Remove all default rules
            rlRun "sed -i '/^# Next decide what directories\\/files you want in the database./,\$d' aide.conf"
            rlRun "sed -i '\$acustomtest = sha256+p+u+g+n+acl+selinux+xattrs' aide.conf" 0 "Adding CONTENT_EX group"
            rlRun "sed -i '\$a/var/aide-testing-dir/ customtest' aide.conf" 0 "Add just one path aide the config"
        rlPhaseEnd

        rlPhaseStartTest "Check issue after reboot and journalctl rotate"
            rlRun "aide --config=aide.conf --init"
            rlRun "mv /var/aide-testing-dir/aide.db.new.gz /var/aide-testing-dir/aide.db.gz"
            rlRun -s "aide --config=aide.conf --check" 1-255 "Check AIDE database, should fail"
        rlPhaseEnd

        rlPhaseStartCleanup
            rlLog "Cleaning up..."
            popd
            rlRun "rm -rf $AIDE_TEST_DIR" 0 "Removing temporary directory"
        rlPhaseEnd
    
rlJournalPrintText
rlJournalEnd