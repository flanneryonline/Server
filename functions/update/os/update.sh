#!/bin/bash

. "${INSTALL_ENVIRONMENT:-${SERVER_INSTALL:-~/server}/environment/install}"

os_update() {
    zpool export $docker_pool
    zpool export $data_pool
    [ -d "$root/var/lib/docker" ] && rm -r "$root/var/lib/docker"
    [ -d "$root/stoarge" ] && rm -r "$root/stoarge"
    eval "$chroot_eval zpool import $data_pool"
    eval "$chroot_eval zpool import $docker_pool"
    zfs snap $root_pool/ROOT/$dist/$release@install
    zfs clone -o canmount=noauto -o mountpoint=/ \
        $root_pool/ROOT/$dist/$release@install $root_pool/ROOT/default
    zpool set bootfs=$root_pool/ROOT/default $root_pool
    umount -lAR "$root"
    zfs mount $root_pool/ROOT/default
    zfs mount $root_pool/home/root
    zfs mount $root_pool/home
    zfs mount $root_pool/log
    mount --rbind /dev "$root/dev"
    mount --rbind /dev/pts "$root/dev/pts"
    mount --rbind /proc "$root/proc"
    mount --rbind /sys "$root/sys"
    efi_grub_setup
    networking_setup
    umount -lAR $root
    zpool export $root_pool
}
