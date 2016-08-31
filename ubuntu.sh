#!/usr/bin/env bash

set -o errexit
set -o nounset

DISK=""
EFI_DISK=""
ssd=""
HOSTNAME=""
efi=0

apt-add-repository universe
apt-get update
apt-get install --yes debootstrap gdisk zfs-initramfs

sgdisk -og $DISK
if [ $efi -eq 1 ]
then
    sgdisk -n 3:4096:413695 -c 3:"EFI Boot Partition" -t 3:ef00 $DISK
else
    sgdisk -n 2:2048:4095 -c 2:"BIOS Boot Partition" -t 2:ef02 $DISK
fi
sgdisk -n 1:0:-8M -c 1:"ZFS Partition" -t 1:BF01 $DISK

sgdisk -og $ssd
sgdisk -n 1:0:-8M -c 1:"ZFS Partition" -t 1:BF01 $ssd

zpool create -o ashift=12 \
      -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD \
      -O mountpoint=/ -R /mnt \
      -d -o feature@async_destroy=enabled \
         -o feature@empty_bpobj=enabled \
         -o feature@filesystem_limits=enabled \
         -o feature@lz4_compress=enabled \
         -o feature@spacemap_histogram=enabled \
         -o feature@extensible_dataset=enabled \
         -o feature@bookmarks=enabled \
         -o feature@enabled_txg=enabled \
         -o feature@embedded_data=enabled \
         -o feature@large_blocks=enabled \
      zroot $DISK 

zpool create -o ashift=12 \
      -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD \
      -O mountpoint=/ -R /mnt \
      -d -o feature@async_destroy=enabled \
         -o feature@empty_bpobj=enabled \
         -o feature@filesystem_limits=enabled \
         -o feature@lz4_compress=enabled \
         -o feature@spacemap_histogram=enabled \
         -o feature@extensible_dataset=enabled \
         -o feature@bookmarks=enabled \
         -o feature@enabled_txg=enabled \
         -o feature@embedded_data=enabled \
         -o feature@large_blocks=enabled \
      zfast $ssd 

zfs create -o canmount=off -o mountpoint=none zroot/root
zfs create -o canmount=noauto -o mountpoint=/ zroot/root/ubuntu
zfs mount zroot/root/ubuntu

zfs create -o setuid=off zfast/home
zfs create -o mountpoint=/root zfast/home/root
zfs create -o canmount=off -o setuid=off -o exec=off zfast/var
zfs create -o com.sun:auto-snapshot=false zfast/var/cache
zfs create zfast/var/log
zfs create zfast/var/spool
zfs create -o com.sun:auto-snapshot=false -o exec=on zfast/var/tmp
zfs create -o mountpoint=/var/lib/docker zfast/docker

chmod 1777 /mnt/var/tmp
debootstrap xenial /mnt

echo "${HOSTNAME}" > /mnt/etc/hostname

cat << --EOF-HOSTS | echo >> /mnt/etc/hosts
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME}

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
--EOF-HOSTS

mount --rbind /dev /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys /mnt/sys

cat << --EOF-CHROOT | sudo chroot /mnt
echo 'LANG="en_US.UTF-8"' > /etc/default/locale
dpkg-reconfigure tzdata
ln -s /proc/self/mounts /etc/mtab
apt-get update
apt-get install --yes ubuntu-minimal
apt-get install --yes --no-install-recommends linux-image-generic
apt-get install --yes zfs-initramfs

if [[ $efi -eq 1 ]]
then
    apt-get install --yes grub-pc
    update-initramfs -c -k all
    update-grub
    grub-install $DISK
else
    apt-get install dosfstools
    mkdosfs -F 32 -n EFI $EFI_DISK
    mkdir /boot/efi
    echo "PARTUUID=$(blkid -s PARTUUID -o value $EFI_DISK) /boot/efi vfat defaults 0 1" >> /etc/fstab
    mount /boot/efi
    apt-get install --yes grub-efi-amd64
    update-initramfs -c -k all
    update-grub
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck --no-floppy
fi
--EOF-CHROOT

mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export zroot

