#!/usr/bin/env bash

set -e
set -o

DISK=""
ssd=""
HOSTNAME=""
efi=0

apt-add-repository universe
apt-get update
apt-get install --yes debootstrap gdisk zfs-initramfs

sgdisk -og $1
if [[ $efi -eq 1 ]]
then
    sgdisk -n 3:4096:413695 -c 3:"EFI Boot Partition" -t 3:ef00 $DISK
else
    sgdisk -n 2:2048:4095 -c 2:"BIOS Boot Partition" -t 2:ef02 $DISK
fi
sgdisk -n 1:0:0 -c 1:"ZFS Partition" -t 1:BF01 $DISK

sgdisk -og $ssd
sgdisk -n 1:0:0 -c 1:"ZFS Partition" -t 1:BF01 $ssd


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

chmod 1777 /mnt/var/tmp
debootstrap xenial /mnt

echo "${HOSTNAME}" > /mnt/etc/hostname
mount --rbind /dev  /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys  /mnt/sys

chroot /mnt echo 'LANG="en_US.UTF-8"' > /etc/default/locale

chroot /mnt dpkg-reconfigure tzdata
chroot /mnt ln -s /proc/self/mounts /etc/mtab
chroot /mnt apt-get update
chroot /mnt apt-get install --yes ubuntu-minimal
chroot /mnt apt-get install --yes --no-install-recommends linux-image-generic
chroot /mnt apt-get install --yes zfs-initramfs

if [[ $efi -eq 1 ]]
then
    chroot /mnt apt-get install --yes grub-pc
    chroot /mnt update-initramfs -c -k all
    chroot /mnt update-grub
    chroot /mnt grub-install $DISK
else
    apt-get install dosfstools
    mkdosfs -F 32 -n EFI $EFI_DISK
    mkdir /mnt/boot/efi
    echo PARTUUID=$(blkid -s PARTUUID -o value \
      $EFI_DISK) \
      /boot/efi vfat defaults 0 1 >> /mnt/etc/fstab
    chroot /mnt mount /boot/efi
    chroot /mnt apt-get install --yes grub-efi-amd64
    chroot /mnt update-initramfs -c -k all
    chroot /mnt update-grub
    chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi \
      --bootloader-id=ubuntu --recheck --no-floppy
fi

mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export zroot

