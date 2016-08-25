#!/usr/bin/env bash
# 
# This script assumes the list of drives provided have been wiped already.
#

set -o errexit
set -o nounset

if [[ $# -eq 0 ]]
then
    echo "No drive list provided. Nothing changed."
    exit 1
fi

# More than 1 arg?
if [[ $# -ne 1 ]]
then
    echo "Must provide drive list in a single argument. Did you forget to quote the list?"
    exit 1
fi

ROOT_DRIVE_LIST=$1

# Should there be a check of the drives to make sure they are blank?

echo "Creating zfs boot (512k) and a zfs root partitions on drive list: ${ROOT_DRIVE_LIST}"
DRIVE_NUMBER=0
for ROOT_DRIVE in $ROOT_DRIVE_LIST
do
    gpart create -s gpt "${ROOT_DRIVE}"
    gpart add -a 4k -s 512k -t freebsd-boot "${ROOT_DRIVE}"
    gpart add -a 4k -t freebsd-zfs -l "boot${DRIVE_NUMBER}" "${ROOT_DRIVE}"
    gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 "${ROOT_DRIVE}"
    gnop create -S 4096 "/dev/gpt/boot${DRIVE_NUMBER}"
    ZPOOL_LIST="${ZPOOL_LIST:-}${SPACE:-}/dev/gpt/boot${DRIVE_NUMBER}.nop"
    SPACE=" "
    ((DRIVE_NUMBER++))
done

zpool create -f -m none -o altroot="${ALTROOT}" -o cachefile="${ZCACHE}" zroot mirror "${ZPOOL_LIST}"
zfs create -o mountpoint=none zroot/root
zfs create -o mountpoint=/ zroot/root/current
zfs set compression=lz4 zroot
zfs set atime=off zroot

exit 0
