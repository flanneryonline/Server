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
delete_drive_list="${root_drive_list} ${ssd}"

if [[ "${TESTING:-"YES"}" == "NO" ]]
then
    t=""
else
    t="test"
fi
release=${RELEASE:-"11.0-RELEASE"}
altroot=${ALTROOT:-"/mnt"}
jail_dir=${JAIL_DIR:-"${altroot}/usr/jails"}
gateway=${GATEWAY:-"10.0.0.1"}
subnet=${SUBNET:-"255.0.0.0"}
domain=${DOMAIN:-"flanneryonline.com"}
hostname=${HOSTNAME:-"hostserver${t:-}"}
zcache=${ZCACHE:-"${temp_dir}/zpool.cache"}
temp_dir=${TEMP_DIR:-"/var/tmp/install"}
fqdn="${hostname}.${domain}"
arch=${ARCH:-$(uname -m)}
host_ip=$(host "${fqdn}" | grep "has address" | awk '{print $4}')

if [[ "${host_ip}" == "" ]]
then
    echo "Hostname ${fqdn} not found in DNS - setup DNS first."
    exit 1 
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
source ~/server/scripts/setup/etc/jail_config_init
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

#host software install
echo "initializing pkg for host."
pkg_init ${altroot}

echo "Updating ports. Please wait..."
chroot "${altroot}" portsnap fetch update >/dev/null 2>&1

#setup portmaster
echo "Installing host software."
#chroot "${altroot}" portmaster \
chroot "${altroot}" \
    ASSUME_ALWAYS_YES=YES \
    pkg install \
        vim-lite \
        git-lite \
        sudo \
        zsh \
        tmux \
        bash \
        ssmtp \
    >/dev/null 2>&1
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
zfs snapshot -r zroot/@install
zfs snapshot -r zroot/@today
zfs snapshot -r zroot/@yesterday
zfs snapshot -r zroot/@lastweek
zfs snapshot -r zroot/@thisweek
zfs snapshot -r zroot/@lastmonth
zfs snapshot -r zroot/@thismonth
zfs snapshot -r zfast/@install
zfs snapshot -r zfast/@today
zfs snapshot -r zfast/@yesterday
zfs snapshot -r zfast/@lastweek
zfs snapshot -r zfast/@thisweek
zfs snapshot -r zfast/@lastmonth
zfs snapshot -r zfast/@thismonth
zfs snapshot -r zstorage/@install
zfs snapshot -r zstorage/@today
zfs snapshot -r zstorage/@yesterday
zfs snapshot -r zstorage/@lastweek
zfs snapshot -r zstorage/@thisweek
zfs snapshot -r zstorage/@lastmonth
zfs snapshot -r zstorage/@thismonth

echo "Almost done. Cleaning up..."
zroot_reset
cp "${zcache}" "${altroot}/boot/zfs/zpool.cache"
rm -R "${temp_dir}"
sync

exit 0

