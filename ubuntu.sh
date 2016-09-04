#!/usr/bin/env bash

set -o errexit
set -o nounset

DISK=""
ssd=""
HOSTNAME=""
efi=0

apt-add-repository universe
apt-get update
apt-get install --yes debootstrap gdisk zfsutils-linux

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
      zroot ${DISK}-part1 

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
      zfast ${ssd}-part1 

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

chroot /mnt ln -s /proc/self/mounts /etc/mtab
chroot /mnt locale-gen en_US.UTF-8
chroot /mnt echo "America/Chicago" > /etc/timezone
chroot /mnt dpkg-reconfigure -f noninteractive tzdata
chroot /mnt rm /etc/apt/sources.list
chroot /mnt echo "deb http://archive.ubuntu.com/ubuntu/ xenial main universe" >> /etc/apt/sources.list
chroot /mnt echo "deb http://security.ubuntu.com/ubuntu/ xenial-security main universe" >> /etc/apt/sources.list
chroot /mnt echo "deb http://archive.ubuntu.com/ubuntu/ xenial-updates main universe" >> /etc/apt/sources.list
chroot /mnt apt update
chroot /mnt apt install --yes --no-install-recommends linux-image-generic ubuntu-minimal zfsutils-linux lxd

if [[ $efi -ne 1 ]]
then
    chroot /mnt apt-get install --yes grub-pc
    chroot /mnt update-initramfs -c -k all
    chroot /mnt update-grub
    chroot /mnt grub-install $DISK
else
    chroot /mnt apt-get install dosfstools
    chroot /mnt mkdosfs -F 32 -n EFI "${DISK}-part3"
    chroot /mnt mkdir /boot/efi
    chroot /mnt echo "PARTUUID=$(blkid -s PARTUUID -o value "${EFI_DISK}-part3") /boot/efi vfat defaults 0 1" >> /etc/fstab
    chroot /mnt mount /boot/efi
    chroot /mnt apt-get install --yes grub-efi-amd64
    chroot /mnt update-initramfs -c -k all
    chroot /mnt update-grub
    chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck --no-floppy
fi

mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export zroot
zpool export zfast
