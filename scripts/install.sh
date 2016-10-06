#!/usr/bin/env bash
#
# This script assumes it was cloned from git repo to ~
#

set -o errexit
set -o nounset

freebsd_version="11.0-RELEASE"
altroot="/mnt"
jail_dir="${altroot}/usr/jails"
gateway="10.0.0.1"
domain="flanneryonline.com"
hostname="hostserver"

source ~/server/scripts/setup/setup_zfs_init
source ~/server/scripts/setup/setup_system_base
source ~/server/scripts/setup/setup_jail_base
source ~/server/scripts/setup/setup_jail_create

zfs_init \
    "" \        #root disks
    "" \        #fast disks
    "${altroot}"
system_base "$(uname -a)" "${freebsd_version}" "${altroot}"
jail_base "${freebsd_version}" "${jail_dir}"

cd "${altroot}"
ln -s usr/home home
ln -s root usr/home/root

sysrc -R "${ALTROOT}" zfs_enable="YES"
sysrc -R "${ALTROOT}" defaultrouter="${gateway}"
sysrc -R "${ALTROOT}" sendmail_submit_enable="NO"
sysrc -R "${ALTROOT}" sendmail_outbound_enable="NO"
sysrc -R "${ALTROOT}" sendmail_msp_queue_enable="NO"
sysrc -R "${ALTROOT}" hostname="${hostname}${test}.${domain}"



exit 0

