#!/usr/bin/env bash

set -o errexit
set -o nounset

fast_drive_list="ada0"
root_drive_list="da0 da1"
backup_nfs="server-nas.flanneryonline.com:/volume1/backup"
jail_list="download media web share"
delete_drive_list="${root_drive_list} ${fast_drive_list}"

release=${RELEASE:-"11.0-RELEASE"}
altroot=${ALTROOT:-"/mnt"}
base_jail_dir=${BASE_JAIL_DIR:-"/usr/jails"}
jail_dir=${JAIL_DIR:-"${altroot}${base_jail_dir}"}
gateway=${GATEWAY:-"10.0.0.1"}
subnet=${SUBNET:-"255.0.0.0"}
domain=${DOMAIN:-"flanneryonline.com"}
temp_dir=${TEMP_DIR:-"/var/tmp/install"}
zcache=${ZCACHE:-"${temp_dir}/zpool.cache"}
arch=${ARCH:-$(uname -m)}
root_pool=${ROOT_POOL:-"zroot"}
fast_pool=${FAST_POOL:-"zfast"}
storage_pool=${STORAGE_POOL:-"zstorage"}
media_zfs=${MEDIA_ZFS:-"${storage_pool}/media"}
media_dir=${MEDIA_DIR:-"/mnt/media"}
download_zfs=${DOWNLOAD_ZFS:-"${storage_pool}/download"}
download_dir=${DOWNLOAD_DIR:-"/mnt/download"}
config_zfs=${CONFIG_ZFS:-"${storage_pool}/config"}
config_dir=${CONFIG_DIR:-"/mnt/config"}
share_zfs=${SHARE_ZFS:-"${storage_pool}/share"}
share_dir=${SHARE_DIR:-"/mnt/share"}
hostname=${SERVER_HOSTNAME:-"hostserver${t:-}"}
fqdn="${hostname}.${domain}"
host_ip=$(host "${fqdn}" | grep "has address" | awk '{print $4}')

if [[ "${TESTING:-"YES"}" = "NO" ]] ; then t=""; else t="test"; fi

if [[ -z ${host_ip// } ]]
then
    echo "Hostname ${fqdn} not found in DNS - setup DNS first."
    exit 1 
fi

#dialog box here?

if [[ -d "${temp_dir}" ]] ; then rm -R "${temp_dir}"; fi
mkdir -p "${temp_dir}"

source ~/server/scripts/setup/zfs/init

source ~/server/scripts/setup/system/install

source ~/server/scripts/setup/etc/cron_init
source ~/server/scripts/setup/etc/fstab_init
source ~/server/scripts/setup/etc/jail_conf_init
source ~/server/scripts/setup/etc/loader_conf_init
source ~/server/scripts/setup/etc/make_conf_init
source ~/server/scripts/setup/etc/periodic_conf_init
source ~/server/scripts/setup/etc/rc_conf_init
source ~/server/scripts/setup/etc/resolv_conf_init
source ~/server/scripts/setup/etc/sshd_config_init
source ~/server/scripts/setup/etc/ssmtp_conf_init
source ~/server/scripts/setup/etc/user_init

echo "Setting up ZFS."
zfs_init

echo "Installing system."
system_install "${altroot}" 1 1

echo "Configuring system."
cron_init
fstab_init
loader_conf_init
make_conf_init
periodic_conf_init
resolv_conf_init
sshd_config_init
ssmtp_conf_init
jail_conf_init
user_init
sysrc_init

echo "Cleaning up..."
cp "${zcache}" "${altroot}/boot/zfs/zpool.cache"
rm -R "${temp_dir}"

echo "Syncing."
sync

echo "Done!"
exit 0

