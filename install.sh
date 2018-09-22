#!/usr/bin/env bash
# chmod +x install.sh && SYNC_DATA=1 ./install.sh |& tee /var/log/debootstrap.log

export DEBIAN_FRONTEND=noninteractive

. ${SERVER_INSTALL:-~/server}/include
. ${SERVER_INSTALL:-~/server}/environment

apt-get install -qq \
    --no-install-recommends \
    zfs-initramfs \
    gdisk \
    debootstrap \
    curl \
    nfs-common \
    apt-transport-https
errorcheck && exit 1

clear

root=/mnt/install
chroot_eval="chroot "$root" /usr/bin/env PATH=/usr/sbin:/usr/bin/:/bin:/sbin DEBIAN_FRONTEND=noninteractive"
packages="ubuntu-minimal,ubuntu-standard,linux-image-generic,smartmontools,git,"
packages="${packages}apt-transport-https,gnupg,openssh-server,nfs-common,"
packages="${packages}curl,bash-completion,zfs-initramfs,postfix,figlet"
SYNC_DATA=${SYNC_DATA:-0}
SSD_ENABLED=${SSD_ENABLED:-1}
STORAGE_ENABLED=${STORAGE_ENABLED:-1}
[ $SYNC_DATA -eq 0 ] && SSD_ENABLED=0 && STORAGE_ENABLED=0

admin_password=$(whiptail --title "Set $ADMIN_USERNAME password" --passwordbox "Please enter password for user $ADMIN_USERNAME:" 0 10 2>&1 >/dev/tty)
wt_boot='whiptail --title "Choose All boot Disks" --checklist "Boot disks will be ERASED!" 0 10 0 '
wt_ssd='whiptail --title "Choose All SSD Disks" --checklist "SSD disks will be ERASED!" 0 10 0 '
wt_storage='whiptail --title "Choose All Storage Disks" --checklist "Storage disks will be ERASED!" 0 10 0 '
boot_disks=$(filter_quotes "$(eval $wt_boot $(whiptail_disks) 2>&1 >/dev/tty)")
[ $SSD_ENABLED -eq 1 ] && ssd_disks=$(filter_quotes "$(eval $wt_ssd $(whiptail_disks $boot_disks) 2>&1 >/dev/tty)")
[ $STORAGE_ENABLED -eq 1 ] && storage_disks=$(filter_quotes "$(eval $wt_storage $(whiptail_disks $boot_disks $ssd_disks) 2>&1 >/dev/tty)")

[ x$boot_disks = x ] && echoerr "Must select a boot disk" && exit 1
[ x$ssd_disks = x ] && SSD_ENABLED=0 || SSD_ENABLED=1
[ x$storage_disks = x ] && STORAGE_ENABLED=0 || STORAGE_ENABLED=1

clear

clean_install
errorcheck && exit 1

echo "COMPLETE!"

exit 0
