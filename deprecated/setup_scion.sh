#!/bin/bash

set -e

# Install basic requirements for scion
echo 'install and update system packages'
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
apt-get update >/dev/null
apt-get upgrade -y -qq
apt-get install -y -qq apt-transport-https ca-certificates unattended-upgrades

# Install openssh
apt-get update && apt-get install -y openssh-server
echo 'VM${i} setup complete.'

## Not required for freestanding afaik ##

# echo 'install SCIONLab'
# echo "deb [trusted=yes] https://packages.netsec.inf.ethz.ch/debian all main" > /etc/apt/sources.list.d/scionlab.list
# apt-get update > /dev/null
# apt-get install -y -qq scionlab

# Setup time sync, as required for scion
echo 'configure time sync'
printf '%s\n' \
    '[Time]' \
    'NTP=0.ubuntu.pool.ntp.org 1.ubuntu.pool.ntp.org 2.ubuntu.pool.ntp.org 3.ubuntu.pool.ntp.org' \
    'FallbackNTP=ntp.ubuntu.com' \
    >/etc/systemd/timesyncd.conf
systemctl restart systemd-timesyncd.service

# Appending to hosts
echo 'Appending to /etc/hosts'
echo -e "# additions to /etc/hosts\n192.168.56.11 scion01\n192.168.56.12 scion02\n192.168.56.13 scion03\n192.168.56.14 scion04\n192.168.56.15 scion05\n192.168.56.16 scion06" >>/etc/hosts

# This results in 404 no idea why
echo 'Downloading SCION...'
cd /tmp/
tar xfz /vagrant/scion_0.12.0_deb_amd64.tar.gz -C /tmp/
#     https://github.com/scionproto/scion/releases/download/v0.11.0/scion_v0.11.0_deb_amd64.tar.gz
# tar xfz scion_v0.11.0_deb_amd64.tar.gz


# For some reason, using the newer version leads to errors when starting the services due to some malconfigured cs. and br.toml files


sudo apt install ./scion*.deb

# echo 'configure unattended upgrades for all system and SCION package upgrades'
# printf '%s\n' \
#   'Unattended-Upgrade::Origins-Pattern { "origin=*"; };' \
#   'Unattended-Upgrade::Automatic-Reboot "true";' \
#   'Unattended-Upgrade::Automatic-Reboot-Time "02:00";' \
#   'APT::Periodic::Update-Package-Lists "always";' \
#   'APT::Periodic::Unattended-Upgrade "always";' \
# > /etc/apt/apt.conf.d/51unattended-upgrades-scionlab-tweaks
# mkdir /etc/systemd/system/apt-daily.timer.d/ || true
# printf '%s\n' \
#   '[Timer]' \
#   'OnCalendar=' \
#   'OnCalendar=07,19:00' \
#   'RandomizedDelaySec=0' \
# > /etc/systemd/system/apt-daily.timer.d/override.conf
# mkdir /etc/systemd/system/apt-daily-upgrade.timer.d/ || true
# printf '%s\n' \
#   '[Timer]' \
#   'OnCalendar=' \
#   'OnCalendar=07,19:15' \
#   'RandomizedDelaySec=0' \
# > /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf
# systemctl daemon-reload
# systemctl restart apt-daily.timer apt-daily-upgrade.timer

# Fetch configuration from coordinator and start SCION
# scionlab-config --host-id=0815baeb6fe940e88610daf51deeb056 --host-secret=24ca00960e754df1aaa3759c29ce1660 --url=https://www.scionlab.org

# Declare topology URLs for each VM
# TOPOLOGY_URLS=(
#     "https://docs.scion.org/en/latest/_downloads/c1ab66435c174ced233279cb1795c2d4/topology1.json",
#     "https://docs.scion.org/en/latest/_downloads/1f622520a8f76a6df8a62d35b629d6ad/topology2.json",
#     "https://docs.scion.org/en/latest/_downloads/a9a6e86fa6ae21f7c975484c3466d6ff/topology3.json",
#     "https://docs.scion.org/en/latest/_downloads/082e8083537c8a72e29ca3d174aac723/topology4.json",
#     "https://docs.scion.org/en/latest/_downloads/e6e3563fff83b0d8dbcee848a8a41779/topology5.json")

# Download the topology JSON for the current VM ## NOT WORKING 404 all the time???
# VM_ID=$((VM_INDEX - 1))
# echo "Downloading topology for VM${VM_INDEX} from ${TOPOLOGY_URLS[$VM_ID]}"
# sudo wget --tries=5 --retry-connrefused --no-http-keep-alive --waitretry=5 --retry-on-http-error=404,500,502,503,504 ${TOPOLOGY_URLS[$VM_ID]} -O /etc/scion/topology.json

# Generate Forwarding Secret Keys
echo 'Generating Forward Secret Keys'
mkdir -p /etc/scion/keys

head -c 16 /dev/urandom | base64 - >/etc/scion/keys/master0.key
head -c 16 /dev/urandom | base64 - >/etc/scion/keys/master1.key

# # Service Configuration Files
# echo 'Downloading Service Configuration Files'
# sudo wget --tries=5 --retry-connrefused --waitretry=5 --retry-on-http-error=404,500,502,503,504 https://docs.scion.org/en/latest/_downloads/86206dbd6188d9e62a19670f3926ea12/br.toml -O /etc/scion/br.toml
# sudo wget --tries=5 --retry-connrefused --waitretry=5 --retry-on-http-error=404,500,502,503,504 https://docs.scion.org/en/latest/_downloads/a336e7d8890995447b10e212eb56cd7f/cs.toml -O /etc/scion/cs.toml

echo 'Copying Service configuration Files'
sudo cp /vagrant/config/br.toml /etc/scion/br.toml
sudo cp /vagrant/config/cs.toml /etc/scion/cs.toml

echo "VM setup complete."
