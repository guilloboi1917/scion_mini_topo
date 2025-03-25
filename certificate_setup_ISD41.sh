#!/bin/bash

set -euo pipefail

echo 'Starting certificate setup'

mkdir /tmp/tutorial-scion-certs && cd /tmp/tutorial-scion-certs
mkdir AS{4..6}

# Create voting and root keys and (self-signed) certificates for core ASes
pushd AS4
scion-pki certificate create --profile=sensitive-voting <(echo '{"isd_as": "41-ffaa:1:4", "common_name": "41-ffaa:1:4 sensitive voting cert"}') sensitive-voting.pem sensitive-voting.key
scion-pki certificate create --profile=regular-voting <(echo '{"isd_as": "41-ffaa:1:4", "common_name": "41-ffaa:1:4 regular voting cert"}') regular-voting.pem regular-voting.key
scion-pki certificate create --profile=cp-root <(echo '{"isd_as": "41-ffaa:1:4", "common_name": "41-ffaa:1:4 cp root cert"}') cp-root.pem cp-root.key
popd

# pushd AS2
# scion-pki certificate create --profile=cp-root <(echo '{"isd_as": "42-ffaa:1:2", "common_name": "42-ffaa:1:2 cp root cert"}') cp-root.pem cp-root.key
# popd

pushd AS6
scion-pki certificate create --profile=sensitive-voting <(echo '{"isd_as": "41-ffaa:1:6", "common_name": "41-ffaa:1:6 sensitive voting cert"}') sensitive-voting.pem sensitive-voting.key
scion-pki certificate create --profile=regular-voting <(echo '{"isd_as": "41-ffaa:1:6", "common_name": "41-ffaa:1:6 regular voting cert"}') regular-voting.pem regular-voting.key
scion-pki certificate create --profile=cp-root <(echo '{"isd_as": "41-ffaa:1:6", "common_name": "41-ffaa:1:6 cp root cert"}') cp-root.pem cp-root.key
popd

# Create the TRC
mkdir tmp
echo '
isd = 41
description = "Demo ISD 41"
serial_version = 1
base_version = 1
voting_quorum = 2

core_ases = ["ffaa:1:4", "ffaa:1:6"]
authoritative_ases = ["ffaa:1:4", "ffaa:1:6"]
cert_files = ["AS4/sensitive-voting.pem", "AS4/regular-voting.pem", "AS4/cp-root.pem", "AS6/cp-root.pem", "AS6/sensitive-voting.pem", "AS6/regular-voting.pem"]

[validity]
not_before = '$(date +%s)'
validity = "365d"' \
    >trc-B1-S1-pld.tmpl

scion-pki trc payload --out=tmp/ISD41-B1-S1.pld.der --template trc-B1-S1-pld.tmpl
rm trc-B1-S1-pld.tmpl

# Sign and bundle the TRC
scion-pki trc sign tmp/ISD41-B1-S1.pld.der AS4/sensitive-voting.{pem,key} --out tmp/ISD41-B1-S1.AS4-sensitive.trc
scion-pki trc sign tmp/ISD41-B1-S1.pld.der AS4/regular-voting.{pem,key} --out tmp/ISD41-B1-S1.AS4-regular.trc
scion-pki trc sign tmp/ISD41-B1-S1.pld.der AS6/sensitive-voting.{pem,key} --out tmp/ISD41-B1-S1.AS6-sensitive.trc
scion-pki trc sign tmp/ISD41-B1-S1.pld.der AS6/regular-voting.{pem,key} --out tmp/ISD41-B1-S1.AS6-regular.trc

scion-pki trc combine tmp/ISD41-B1-S1.AS{4,6}-{sensitive,regular}.trc --payload tmp/ISD41-B1-S1.pld.der --out ISD41-B1-S1.trc
rm tmp -r

# Create CA key and certificate for issuing ASes
pushd AS4
scion-pki certificate create --profile=cp-ca <(echo '{"isd_as": "41-ffaa:1:4", "common_name": "41-ffaa:1:4 CA cert"}') cp-ca.pem cp-ca.key --ca cp-root.pem --ca-key cp-root.key
popd

pushd AS6
scion-pki certificate create --profile=cp-ca <(echo '{"isd_as": "41-ffaa:1:6", "common_name": "41-ffaa:1:6 CA cert"}') cp-ca.pem cp-ca.key --ca cp-root.pem --ca-key cp-root.key
popd

# Create AS key and certificate chains
scion-pki certificate create --profile=cp-as <(echo '{"isd_as": "41-ffaa:1:4", "common_name": "41-ffaa:1:4 AS cert"}') AS4/cp-as.pem AS4/cp-as.key --ca AS4/cp-ca.pem --ca-key AS4/cp-ca.key --bundle
scion-pki certificate create --profile=cp-as <(echo '{"isd_as": "41-ffaa:1:5", "common_name": "41-ffaa:1:5 AS cert"}') AS5/cp-as.pem AS5/cp-as.key --ca AS4/cp-ca.pem --ca-key AS4/cp-ca.key --bundle
scion-pki certificate create --profile=cp-as <(echo '{"isd_as": "41-ffaa:1:6", "common_name": "41-ffaa:1:6 AS cert"}') AS6/cp-as.pem AS6/cp-as.key --ca AS6/cp-ca.pem --ca-key AS6/cp-ca.key --bundle

echo 'copying to shared folder'
mkdir -p /vagrant/tutorial-scion-certs
cp -r /tmp/tutorial-scion-certs /vagrant/

echo 'Certificates created'