#!/bin/bash
# chmod +x install/install.sh && ./install/install.sh |& tee /var/log/debootstrap.log

export DEBIAN_FRONTEND=noninteractive

. ${SERVER_INSTALL:-~/server}/install/include
. ${SERVER_INSTALL:-~/server}/install/environment

root=
initialize_networking
errorcheck && exit 1
initialize_apt
errorcheck && exit 1

apt-get install -qq \
    --no-install-recommends \
    zfs-initramfs \
    gdisk \
    debootstrap \
    curl \
    apt-transport-https \
    systemd-container
errorcheck && exit 1

clear

root=/mnt/install
chroot_eval="chroot "$root" /usr/bin/env PATH=/usr/sbin:/usr/bin/:/bin:/sbin DEBIAN_FRONTEND=noninteractive"
packages="ubuntu-minimal,ubuntu-standard,linux-image-generic,"
packages="${packages}apt-transport-https,gnupg,openssh-server,"
packages="${packages}curl,bash-completion,zfs-initramfs,figlet"

admin_password=$(whiptail --title "Set $ADMIN_USERNAME password" --passwordbox "Please enter password for user $ADMIN_USERNAME:" 0 10 2>&1 >/dev/tty)
wt_boot='whiptail --title "Choose All boot Disks" --checklist "Boot disks will be ERASED!" 0 10 0 '
wt_ssd='whiptail --title "Choose All SSD Disks" --checklist "SSD disks will be ERASED!" 0 10 0 '
wt_storage='whiptail --title "Choose All Storage Disks" --checklist "Storage disks will be ERASED!" 0 10 0 '
boot_disks=$(filter_quotes "$(eval $wt_boot $(whiptail_disks) 2>&1 >/dev/tty)")
ssd_disks=$(filter_quotes "$(eval $wt_ssd $(whiptail_disks $boot_disks) 2>&1 >/dev/tty)")
storage_disks=$(filter_quotes "$(eval $wt_storage $(whiptail_disks $boot_disks $ssd_disks) 2>&1 >/dev/tty)")

clear

clean_install
errorcheck && exit 1

echo "COMPLETE!"

exit 0
