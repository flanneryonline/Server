#!/usr/bin/env bash

# [ -d /opt/server ] && rm -r /opt/server
# git clone https://github.com/flanneryonline/server.git /opt/server && cd /opt/server
# chmod +x install.sh && SYNC_DATA=0 LINK_BACKUP=1 ./install.sh |& tee /var/log/debootstrap.log

export DEBIAN_FRONTEND=noninteractive

SERVER_INSTALL=${SERVER_INSTALL:-/opt/server}
. "$SERVER_INSTALL/environment"
. "$SERVER_INSTALL/include"

root=/mnt/install
chroot_eval="chroot "$root" /usr/bin/env PATH=/usr/sbin:/usr/bin/:/bin:/sbin DEBIAN_FRONTEND=noninteractive"
SYNC_DATA=${SYNC_DATA:-1}
FAST_STORAGE_ENABLED=${FAST_STORAGE_ENABLED:-1}
SLOW_STORAGE_ENABLED=${SLOW_STORAGE_ENABLED:-1}
SERVICES_ENABLED=${SERVICES_ENABLED:-1}
BACKUP_ENABLED=${BACKUP_ENABLED:-1}
LINK_BACKUP=${LINK_BACKUP:-0}

[ $BACKUP_ENABLED -eq 0 ] && SYNC_DATA=0
[ $BACKUP_ENABLED -eq 0 ] && SERVICES_ENABLED=0
[ $BACKUP_ENABLED -eq 0 ] && LINK_BACKUP=0

admin_password=$(whiptail --title "Set $ADMIN_USERNAME password" --passwordbox "Please enter password for user $ADMIN_USERNAME:" 0 10 2>&1 >/dev/tty)
wt_boot='whiptail --title "Choose All Boot Disks" --checklist "Boot disks will be ERASED!" 0 10 0 '
wt_fast_storage='whiptail --title "Choose All Fast Disks" --checklist "FAST disks will be ERASED!" 0 10 0 '
wt_slow_storage='whiptail --title "Choose All Storage Disks" --checklist "Storage disks will be ERASED!" 0 10 0 '
boot_disks=$(filter_quotes "$(eval $wt_boot $(whiptail_disks) 2>&1 >/dev/tty)")
[ $FAST_STORAGE_ENABLED -eq 1 ] && fast_disks=$(filter_quotes "$(eval $wt_fast_storage $(whiptail_disks $boot_disks) 2>&1 >/dev/tty)")
[ $SLOW_STORAGE_ENABLED -eq 1 ] && slow_disks=$(filter_quotes "$(eval $wt_slow_storage $(whiptail_disks $boot_disks $fast_storage_disks) 2>&1 >/dev/tty)")

[ "x$boot_disks" = "x" ] && echoerr "Must select a boot disk" && exit 1
[ "x$fast_disks" = "x" ] && FAST_STORAGE_ENABLED=0
[ "x$slow_disks" = "x" ] && SLOW_STORAGE_ENABLED=0

#whiptail --yes-button "Confirm" --no-button "Cancel" --title "Confirm Info" --yesno "$(wt_confirm)" 0 10
#errorcheck && exit 1

chmod +x "$SERVER_INSTALL/patches/apt"
execute_patch "$SERVER_INSTALL/patches/apt"
wait_for_patch "apt" $(get_version "apt")
errorcheck && echoerr "apt patch failed" && exit 1

apt-get update
apt-get upgrade -y
apt-get install -y \
    --no-install-recommends \
    zfs-initramfs \
    gdisk \
    debootstrap \
    curl \
    apt-transport-https
errorcheck && exit 1

clean_install
errorcheck && exit 1

echo "COMPLETE!"

exit 0
