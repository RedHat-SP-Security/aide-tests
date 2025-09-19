#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /aide-tests/Regression/rhel-76014-http-link-as-database
#   Description: Test for RHEL-76014 (Aide crash when it's used http link as database)
#   Author: Patrik Koncity <pkoncity@redhat.com>
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

rlJournalStart
    rlPhaseStartSetup
        AIDE_TEST_DIR=/var/aide-testing-dir/
        rlRun "mkdir -p /var/aide-testing-dir"
        pushd $AIDE_TEST_DIR
        rlLog "Test directory created and working inside: $AIDE_TEST_DIR"
        rlLog "Copying and adjusting /etc/aide.conf"
        rlRun "cp /etc/aide.conf ."
        rlRun "sed -i 's#^@@define DBDIR.*#@@define DBDIR /var/aide-testing-dir#' aide.conf"
        rlRun "sed -i 's#^@@define LOGDIR.*#@@define LOGDIR /var/aide-testing-dir#' aide.conf"
        rlRun "sed -i 's/gzip_dbout=yes/gzip_dbout=no/' aide.conf"
        rlRun "sed -i 's#^database_out.*#database_out=file:@@{DBDIR}/aide.db.new.txt#' aide.conf"
        rlRun "sed -i -e '\#^/#d; \#^!/#d; \#^=/#d' -e '\$a /var/aide-testing-dir NORMAL' aide.conf"
        rlLog "Generating self-signed SSL certificate..."
        rlRun "openssl req -new -x509 -keyout server.pem -out server.pem -days 1 -nodes -subj '/CN=localhost'"
        rlLog "Adding temporary certificate to the system trust store"
        rlRun "cp server.pem /etc/pki/ca-trust/source/anchors/"
        rlRun "update-ca-trust"
        rlLog "Creating start_https-server.py helper script"
        cat <<'EOF' > start_https-server.py
import http.server
import ssl
import sys
port = int(sys.argv[1])
certfile = sys.argv[2]
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(certfile=certfile)
httpd = http.server.HTTPServer(('0.0.0.0', port), http.server.SimpleHTTPRequestHandler)
httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
print(f"Serving HTTPS on port {port}...", flush=True)
httpd.serve_forever()
EOF
        rlLog "Starting HTTPS server on port 8443..."
        python3 start_https-server.py 8443 server.pem &
        SERVER_PID=$!
        sleep 2
        rlRun -s "ss -ltn" 0 "Check for listening ports"
        rlAssertGrep "0.0.0.0:8443" "$rlRun_LOG"
    rlPhaseEnd

    rlPhaseStartTest
        rlLog "Initializing AIDE database locally..."
        rlRun "aide --config=aide.conf --init" 0 "AIDE initialization"    
        rlRun "mv aide.db.new.txt aide.db.txt"
        HTTPS_URL="https:\/\/localhost:8443\/aide.db.txt"
        rlLog "Using sed to adjust aide.conf to use URL: $HTTPS_URL"
        rlRun "sed -i 's/^database_in=.*/database_in=$HTTPS_URL/' aide.conf"
        rlLog "Running AIDE check against HTTPS URL..."
        rlRun "aide --config=aide.conf --check" 0 "Verify AIDE does not crash with HTTPS database"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlLog "Cleaning up..."
        rlRun "kill $SERVER_PID" 0 "Stopping HTTPS server"
        rlLog "Removing temporary certificate from the system trust store"
        rlRun "rm -f /etc/pki/ca-trust/source/anchors/server.pem"
        rlRun "update-ca-trust"
        popd
        rlRun "rm -rf $AIDE_TEST_DIR" 0 "Removing temporary directory"
    rlPhaseEnd
rlJournalEnd