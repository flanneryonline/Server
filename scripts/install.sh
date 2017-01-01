#!/usr/bin/env bash
#
# This script assumes it was cloned from git repo to ~
#

set -o errexit
set -o nounset

fast_drive_list="ada0"
root_drive_list="da0 da1"
backup_nfs="server-nas.flanneryonline.com:/volume1/backup"
jail_list="download media web share"
delete_drive_list="${root_drive_list} ${fast_drive_list}"

release=${RELEASE:-"11.0-RELEASE"}
altroot=${ALTROOT:-"/mnt"}
jail_dir=${JAIL_DIR:-"${altroot}/usr/jails"}
gateway=${GATEWAY:-"10.0.0.1"}
subnet=${SUBNET:-"255.0.0.0"}
domain=${DOMAIN:-"flanneryonline.com"}
hostname=${HOSTNAME:-"hostserver${t:-}"}
temp_dir=${TEMP_DIR:-"/var/tmp/install"}
zcache=${ZCACHE:-"${temp_dir}/zpool.cache"}
fqdn="${hostname}.${domain}"
arch=${ARCH:-$(uname -m)}
root_pool=${ROOT_POOL:-"zroot"}
fast_pool=${FAST_POOL:-"zfast"}
storage_pool=${STORAGE_POOL:-"zstorage"}
media_zfs=${MEDIA_ZFS:-"${storage_pool}/media"}
download_zfs=${DOWNLOAD_ZFS:-"${storage_pool}/download"}
config_zfs=${CONFIG_ZFS:-"${storage_pool}/config"}
share_zfs=${SHARE_ZFS:-"${storage_pool}/share"}
host_ip=$(host "${fqdn}" | grep "has address" | awk '{print $4}')

if [[ "${TESTING:-"YES"}" == "NO" ]]
then
    t=""
else
    t="test"
fi

if [[ "${host_ip}" == "" ]]
then
    echo "Hostname ${fqdn} not found in DNS - setup DNS first."
    exit 1 
fi
if zpool list zfast >/dev/null 2>&1
then
    zpool destroy zfast >/dev/null 2>&1
fi
if zpool list zroot >/dev/null 2>&1
then
    zpool destroy zroot >/dev/null 2>&1
fi
if [[ -d "${temp_dir}" ]]
then
    rm -R "${temp_dir}"
fi
mkdir -p "${temp_dir}"

if [[ -d "${altroot}" ]]
then
    rm -R "${altroot}"
fi
mkdir -p "${altroot}"

source ~/server/scripts/setup/zfs/zroot_reset
source ~/server/scripts/setup/zfs/init
source ~/server/scripts/setup/system/install
source ~/server/scripts/setup/etc/fstab_init
source ~/server/scripts/setup/etc/jail_conf_init
source ~/server/scripts/setup/etc/loader_conf_init
source ~/server/scripts/setup/etc/make_conf_init
source ~/server/scripts/setup/etc/pkg_init
source ~/server/scripts/setup/etc/resolv_conf_init
source ~/server/scripts/setup/etc/user_init
source ~/server/scripts/setup/jail/create
source ~/server/scripts/setup/jail/init

#clears all disks, sets up partitions and zfs pools/datasets
zfs_init
system_install "${altroot}" 1 1

media_dir=$(zfs get all ${media_zfs} | grep mountpoint | awk '{print $3}')
download_dir=$(zfs get all ${download_zfs} | grep mountpoint | awk '{print $3}')
config_dir=$(zfs get all ${config_zfs} | grep mountpoint | awk '{print $3}')
share_dir=$(zfs get all ${share_zfs} | grep mountpoint | awk '{print $3}')

fstab_init
loader_conf_init
make_conf_init
pkg_init
resolv_conf_init
user_init
jail_conf_init
ssmtp_conf_init

echo "Configuring host software."
#chroot "${altroot}" python3 -m ensurepip >/dev/null 2>&1
#chroot "${altroot}" pip3 install jedi >/dev/null 2>&1
sysrc -R "${altroot}" zfs_enable="YES"
sysrc -R "${altroot}" defaultrouter="${gateway}"
sysrc -R "${altroot}" sendmail_enable="NO"
sysrc -R "${altroot}" sendmail_submit_enable="NO"
sysrc -R "${altroot}" sendmail_outbound_enable="NO"
sysrc -R "${altroot}" sendmail_msp_queue_enable="NO"
sysrc -R "${altroot}" hostname="${fqdn}"
sysrc -R "${altroot}" cloned_interfaces="lagg0"
for net in $(ifconfig | grep -v LOOPBACK | grep flags | cut -d: -f1)
do
    sysrc -R "${altroot}" "ifconfig_${net}=\"up\""
    lag_string="${lag_string:-"laggproto lacp"} laggport ${net}"
done
sysrc -R "${altroot}" ifconfig_lagg0="inet ${host_ip} netmask ${subnet} ${lag_string}"

#Jail Setup
echo "Creating jails."
jail_config
for jail in "${jail_list}"
do
    jail_create "${jail}" "${release}"
    jail_init_${jail}
    echo "${jail} {\$ip4.addr=$(host ${jail}server${t:-}.${domain} | grep "has address" | awk '{ print $4 }');}" >> "${altroot}/etc/jail.conf"
done

echo "Creating install snapshots and preping rolling snapshots"
zfs snapshot -r ${root_pool}/@install
zfs snapshot -r ${root_pool}/@today
zfs snapshot -r ${root_pool}/@yesterday
zfs snapshot -r ${root_pool}/@lastweek
zfs snapshot -r ${root_pool}/@thisweek
zfs snapshot -r ${root_pool}/@lastmonth
zfs snapshot -r ${root_pool}/@thismonth
zfs snapshot -r ${fast_pool}/@install
zfs snapshot -r ${fast_pool}/@today
zfs snapshot -r ${fast_pool}/@yesterday
zfs snapshot -r ${fast_pool}/@lastweek
zfs snapshot -r ${fast_pool}/@thisweek
zfs snapshot -r ${fast_pool}/@lastmonth
zfs snapshot -r ${fast_pool}/@thismonth
zfs snapshot -r ${storage_pool}/@install
zfs snapshot -r ${storage_pool}/@today
zfs snapshot -r ${storage_pool}/@yesterday
zfs snapshot -r ${storage_pool}/@lastweek
zfs snapshot -r ${storage_pool}/@thisweek
zfs snapshot -r ${storage_pool}/@lastmonth
zfs snapshot -r ${storage_pool}/@thismonth

echo "Almost done. Cleaning up..."
zroot_reset
cp "${zcache}" "${altroot}/boot/zfs/zpool.cache"
rm -R "${temp_dir}"
sync

exit 0

