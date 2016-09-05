#!/usr/bin/env bash

set -o errexit
set -o nounset

DISK="/dev/sda"

zpool create -o ashift=12 \
      -O atime=off -O canmount=off -O compression=lz4 \
      -O mountpoint=none -R /target \
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
      zfast "${DISK}4"

zfs create -o setuid=off -o mountpoint=/home zfast/home
zfs create -o setuid=off -o mountpoint=/usr zfast/usr
zfs create -o setuid=off -o mountpoint=/srv zfast/srv
zfs create -o setuid=off -o mountpoint=/opt zfast/opt
zfs create -o setuid=off -o mountpoint=/var -o exec=off zfast/var
zfs create -o setuid=off -o mountpoint=/var/lib/lxd zfast/lxd

zfs create zfast/home/homeadmin
zfs create -o mountpoint=/root zfast/home/root

zfs create zfast/usr/local
zfs create zfast/usr/local/etc

zfs create -o com.sun:auto-snapshot=false zfast/var/cache
zfs create zfast/var/log
zfs create zfast/var/spool
zfs create -o com.sun:auto-snapshot=false -o exec=on zfast/var/tmp
