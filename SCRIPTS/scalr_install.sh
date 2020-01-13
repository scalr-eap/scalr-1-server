#!/bin/bash

# Runs as root via sudo

exec 1>/var/tmp/$(basename $0).log

exec 2>&1

abort () {
  echo "ERROR: Failed with $1 executing '$2' @ line $3"
  exit $1
}

trap 'abort $? "$STEP" $LINENO' ERR

TOKEN="${1}"
VOL="${2}"

VOL2=$(echo $VOL | sed 's/-//')
DEVICE=$(lsblk -o NAME,SERIAL | grep ${VOL2} | awk '{print $1}')


STEP="MKFS"
mkfs -t ext4 /dev/${DEVICE}

STEP="mkdir"
mkdir /opt/scalr-server

STEP="mount /opt/scalr-server"
mount /dev/${DEVICE} /opt/scalr-server
echo /dev/${DEVICE}  /opt/scalr-server ext4 defaults,nofail 0 2 >> /etc/fstab


STEP="curl to down load repo"
curl -s https://${TOKEN}:@packagecloud.io/install/repositories/scalr/scalr-server-ee/script.deb.sh | bash

STEP="apt-get install scalr-server"
apt-get install -y scalr-server

STEP="scalr-server-wizard"
scalr-server-wizard

STEP="Create License"
cp /var/tmp/license.json /etc/scalr-server/license.json
