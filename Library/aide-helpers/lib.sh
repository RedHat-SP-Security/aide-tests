#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Description: provides basic functions for aide testing
#   Author: Marek Safarik <msafarik@redhat.com>
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
#   library-prefix = aide
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

true <<'=cut'
=pod

=head1 NAME

aide-tests/aide-helpers - provides shell functions for aide testing

=head1 DESCRIPTION

The library provides shell functions to ease aide test implementation.

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Variables
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

export __INTERNAL_aideTmpDir
[ -n "$__INTERNAL_aideTmpDir" ] || __INTERNAL_aideTmpDir="/var/tmp/aideLib"

export __INTERNAL_aideConfDefault="/etc/aide.conf"
export __INTERNAL_aideDefaultDbDir="/var/lib/aide"
export __INTERNAL_aideDefaultLogDir="/var/log/aide"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 FUNCTIONS

=head2 aideGetDbPaths

Extract database paths from aide configuration file.
Sets variables: DBDIR, DB, DBnew

    aideGetDbPaths [AIDE_CONF]

=over

=item AIDE_CONF

Path to aide configuration file (/etc/aide.conf by default).

=back

Returns 0.

=cut

aideGetDbPaths() {
    local CONF="${1:-$__INTERNAL_aideConfDefault}"
    DBDIR=$(sed -n -e 's/@@define DBDIR \([a-z/]\+\)/\1/p' "$CONF")
    if rlIsRHELLike "=<9.7"; then
        DB=$(grep "^database=" "$CONF" | cut -d/ -f2-)
    else
        DB=$(grep "^database_in=" "$CONF" | cut -d/ -f2-)
    fi
    DB="${DBDIR}/${DB}"
    DBnew=$(grep "^database_out=" "$CONF" | cut -d/ -f2-)
    DBnew="${DBDIR}/${DBnew}"
}


true <<'=cut'
=pod

=head2 aideInit

Initialize aide database and move new database to active.

    aideInit [-c AIDE_CONF]

=over

=item -c AIDE_CONF

Path to aide configuration file (/etc/aide.conf by default).

=back

Returns 0 when the initialization was successful.

=cut

aideInit() {
    local CONF="$__INTERNAL_aideConfDefault"
    [ "$1" == "-c" ] && CONF="$2"
    aideGetDbPaths "$CONF"
    rlRun -s "aide -i -c $CONF" 0 "AIDE database initialization"
    [ -f "$DBnew" ] || rlFail "New database is not initialized"
    [ -n "$DB" ] || rlFail "Database path is not set correctly"
    rlRun "mv ${DBnew} ${DB}" 0 "Move new AIDE initialed database to the place of the default one."
    rlRun "rm $rlRun_LOG"
}


true <<'=cut'
=pod

=head2 aideCheck

Run aide database check.

    aideCheck [-c AIDE_CONF]

=over

=item -c AIDE_CONF

Path to aide configuration file (/etc/aide.conf by default).

=back

Returns 0 when the check was successful.

=cut

aideCheck() {
    local CONF="$__INTERNAL_aideConfDefault"
    [ "$1" == "-c" ] && CONF="$2"
    rlRun -s "aide --check -c $CONF" 0 "Checking default behaviour -- database check"
    rlAssertGrep "Looks okay!" $rlRun_LOG
    rlRun "rm $rlRun_LOG"
}


# ~~~~~~~~~~~~~~~~~~~~
#   Config management
# ~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head2 aideBackupConfig

Backup aide configuration files using rlFileBackup.

    aideBackupConfig

=over

=back

Returns 0 when the backup was successful.

=cut

aideBackupConfig() {
    rlFileBackup --clean --namespace aideConf /etc/aide.conf /etc/aide.d
}


true <<'=cut'
=pod

=head2 aideRestoreConfig

Restore previously backed up aide configuration files.

    aideRestoreConfig

=over

=back

Returns 0 when the restore was successful.

=cut

aideRestoreConfig() {
    rlFileRestore --namespace aideConf
}


true <<'=cut'
=pod

=head2 aideGetRhelConfig

Return the correct aide config file name for the current RHEL version.
If aide_rhel_9.conf exists alongside the base config and we are
on RHEL <=9.7, return aide_rhel_9.conf. Otherwise return the base config.

    aideGetRhelConfig [BASE_NAME]

=over

=item BASE_NAME

Path to the base aide config file (aide.conf by default).

=back

Prints the correct config file path to STDOUT.

=cut

aideGetRhelConfig() {
    local BASE="${1:-aide.conf}"
    local DIR=$(dirname "$BASE")
    if rlIsRHELLike "=<9.7" && [ -f "${DIR}/aide_rhel_9.conf" ]; then
        echo "${DIR}/aide_rhel_9.conf"
    else
        echo "$BASE"
    fi
}


# ~~~~~~~~~~~~~~~~~~~~
#   Config helpers
# ~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head2 aidePrepareConfig

Prepare aide configuration file for testing. Strips all paths
and comments, removes empty lines, and adds CONTENTEX group
if not already present.

    aidePrepareConfig [AIDE_CONF]

=over

=item AIDE_CONF

Path to aide configuration file (/etc/aide.conf by default).

=back

Returns 0.

=cut

aidePrepareConfig() {
    local CONF="${1:-$__INTERNAL_aideConfDefault}"
    rlRun "sed -i '/^[/!#]/d' $CONF" 0 "Delete all paths and comments in aide config"
    rlRun "sed -i '/^$/d' $CONF" 0 "Delete empty lines"
    if ! grep -q -e 'CONTENTEX' "$CONF"; then
        rlRun "echo 'CONTENTEX = sha256+ftype+p+u+g+n+acl+selinux+xattrs' >> $CONF" 0 "Adding CONTENTEX group"
    fi
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Initialization
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

mkdir -p $__INTERNAL_aideTmpDir


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a verification callback which will be called by
#   rlImport after sourcing the library to make sure everything is
#   all right. It makes sense to perform a basic sanity test and
#   check that all required packages are installed. The function
#   should return 0 only when the library is ready to serve.

aideLibraryLoaded() {

    echo -e "\nInstall aide package if missing."
    rpm -q aide || yum -y install aide

    if [ -n "$__INTERNAL_aideTmpDir" ]; then
        rlLogDebug "Library aide/aide-helpers loaded."
        echo -e "\nInstalled aide RPMs"
        rpm -qa \*aide\*
        return 0
    else
        rlLogError "Failed loading library aide/aide-helpers."
        return 1
    fi

}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Marek Safarik <msafarik@redhat.com>

=back

=cut
