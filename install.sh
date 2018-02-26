#!/bin/bash

# SETUP_INSTALL_LOCATION=$(pwd) ./install.sh |& tee /var/log/debootstrap.log

. "${SERVER_INSTALL:-~/server}/functions/source_all"

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get upgrade -qq
apt-get install -qq zfs-initramfs zfs-dkms debootstrap whiptail sudo sgdisk

wt_boot='whiptail --title "Choose Boot Disk" --radiolist "Boot disk will be ERASED!" 0 10 0 '
wt_docker='whiptail --title "Choose Docker Disk" --radiolist "Docker disk will be ERASED!" 0 10 0 '
wt_storage='whiptail --title "Choose All Storage Disks" --checklist "Storage disks will be ERASED!" 0 10 0 '

clear

admin_username=$(whiptail --title "Admin Username" --inputbox "Please enter username:" 0 10 2>&1 >/dev/tty)
admin_password=$(whiptail --title "Set $admin_user password" --passwordbox "Please enter password for user $admin_user:" 0 10 2>&1 >/dev/tty)
boot_disk=$(filter_quotes "$(eval $wt_boot $(whiptail_disks) 2>&1 >/dev/tty)")
docker_disk=$(filter_quotes "$(eval $wt_docker $(whiptail_disks $boot_disk) 2>&1 >/dev/tty)")
storage_disks=$(filter_quotes "$(eval $wt_storage $(whiptail_disks $boot_disk $docker_disk) 2>&1 >/dev/tty)")

clear

initialize_networking
initialize_zfs
zfs_boot_setup
[ "${setup_storage:-no}" = "yes" ] && zfs_storage_setup
[ "${setup_docker:-no}" = "yes" ] && zfs_docker_setup
update_os
initialize_ssh
finalize

echo "COMPLETE!"
