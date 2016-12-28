#!/usr/bin/env bash
#
# This script assumes it was cloned from git repo to ~
#

#server-nas.flanneryonline.com:/volume1/backup /mnt/backup nfs rw 0 0

set -o errexit
set -o nounset

t="test"
release="11.0-RELEASE"
altroot="/mnt"
jail_dir="${altroot}/usr/jails"
gateway="10.0.0.1"
domain="flanneryonline.com"
hostname="hostserver${t:-}"

fast_drive_list="ada0"
root_drive_list="da0 da1"
backup_nfs="server-nas.flanneryonline.com:/volume1/backup"
jail_list="download media web share"
temp_dir="/var/tmp/install"
zcache="${temp_dir}/zpool.cache"
delete_drive_list="${root_drive_list} ${ssd}"
arch=$(uname -m)
fqdn="${hostname}.${domain}"
host_ip=$(host "${fqdn}" | grep "has address" | awk '{print $4}')

if [[ "${host_ip}" == "" ]]
then
    echo "Hostname ${fqdn} not found in DNS - setup DNS first."
    exit 1 
fi

source ~/server/scripts/setup/setup_zfs_init
source ~/server/scripts/setup/setup_system_install
source ~/server/scripts/setup/setup_pkg_init
source ~/server/scripts/setup/setup_user_init
source ~/server/scripts/setup/setup_jail_base
source ~/server/scripts/setup/setup_jail_create
source ~/server/scripts/setup/setup_jail_config
source ~/server/scripts/setup/setup_jail_init

zfs_init
system_install "${altroot}" 1
curl -fLo "${temp_dir}/base.txz" "ftp://ftp.freebsd.org/pub/FreeBSD/releases/${arch}/${release}/ports.txz"
if command -v pv >/dev/null 2>&1
then
    pv "${temp_dir}/ports.txz" | tar -xf - -C "${altroot}"
else
    echo "Extracting ports. Please wait..."
    tar -xf "${temp_dir}/ports.txz" -C "${altroot}" >/dev/null 2>&1
fi
jail_base
jail_config

#host software install
echo "initializing pkg."
pkg_init
chroot "${altroot}" pkg update
chroot "${altroot}" pkg upgrade
echo "Updating ports. Please wait..."
chroot "${altroot}" portsnap fetch update >/dev/null 2>&1
echo "Installing portmaster."
chroot "${altroot}" make -C /usr/ports/ports-mgmt/portmaster \
    -DBATCH install clean \
    >/dev/null 2>&1
#setup portmaster
echo "Installing host software."
chroot "${altroot}" portmaster \
    python3 vim-lite git-lite sudo \
    >/dev/null 2>&1
echo "Configuring host software."
chroot "${altroot}" python3 -m ensurepip >/dev/null 2>&1
chroot "${altroot}" pip3 install jedi >/dev/null 2>&1
sysrc -r "${altroot}" zfs_enable="YES"
sysrc -r "${altroot}" defaultrouter="${gateway}"
sysrc -r "${altroot}" sendmail_enable="NO"
sysrc -r "${altroot}" sendmail_submit_enable="NO"
sysrc -r "${altroot}" sendmail_outbound_enable="NO"
sysrc -r "${altroot}" sendmail_msp_queue_enable="NO"
sysrc -r "${altroot}" hostname="${fqdn}"

#Jail Setup
echo "Creating jails."
for jail in "${jail_list}"
do
    jail_create "${jail}"
    jail_init_${jail}
done

#create sym links
cd "${altroot}"
ln -s usr/home home
ln -s root usr/home/root

exit 0

