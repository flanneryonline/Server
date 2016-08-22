#!/usr/bin/env zsh

set -o errexit
set -o nounset

TEST="test"
RELEASE="10.3-RELEASE"
DOMAIN="flanneryonline.com"
GATEWAY="10.0.0.1"
SSD="ada0"
ROOT_DRIVE_LIST="da0 da1"
SSD_POOL="zfast"
BACKUP_NFS="server-nas.flanneryonline.com:/volume1/backup"
JAIL_LIST="nzbget tor sonarr cp plex www share"
TEMP_DIR="/var/tmp/install"
HOSTNAME="hostserver"
ZCACHE="${TEMP_DIR}/zpool.cache"
ALTROOT="/mnt/install"
DELETE_DRIVE_LIST="${ROOT_DRIVE_LIST} $SSD"
SCRIPTS="${CUR_DIR}/scripts"
ROOT_FILES="${CUR_DIR}/dotfiles/root"
USER_FILES="${CUR_DIR}/dotfiles/homeadmin"
JAIL_POOL="${SSD_POOL}"
JAIL_ROOT="jails"
JAIL_ZFS="${JAIL_POOL}/${JAIL_ROOT}"
JAIL_DIR="${ALTROOT}/usr/local/${JAIL_ROOT}"
PORTS_POOL="${SSD_POOL}"
PORTS_ZFS="${PORTS_POOL}/ports"
PORTS_DIR="/usr/ports"
MEDIA_ZFS="zstorage/media"
DOWNLOAD_ZFS="zstorage/download"
CONFIG_ZFS="zstorage/config"
SHARE_ZFS="zstorage/share"
ARCH=$(uname -m)
CUR_DIR=$(pwd)
HOST_IP=$(host "${HOSTNAME}${TEST}.${DOMAIN}" | grep "has address" | awk '{print $4}')

if [[ "${HOST_IP}" == "" ]]
then
    echo "Hostname ${HOSTNAME}${TEST}.${DOMAIN} not found in DNS - setup DNS first."
    exit 0 
fi

echo "Cleaning up install location (DATA BEING REMOVED)"
for DRIVE in ${DELETE_DRIVE_LIST}
do
    MAX=$(gpart show ${DRIVE} | awk '{if ($3>0 && $3<128){max=$3}} END{print max}')
    if [[ "${MAX}" =~ "[^0-9]+" ]]
    then
        MAX=0
    fi
    while [[ ${MAX} > 0 ]]
    do
        gpart delete -i ${MAX} "${DRIVE}"
        ((MAX--))
    done
    gpart destroy "${DRIVE}"
done

if [[ -d "${TEMP_DIR}" ]]
then
    rm -R "${TEMP_DIR}"
fi
mkdir -p "${TEMP_DIR}"

if [[ -d "${ALTROOT}" ]]
then
    rm -R "${ALTROOT}"
fi
mkdir -p "${ALTROOT}"

echo "Creating zfs boot (512k) and a zfs root partitions"
DRIVE_NUMBER=0
for ROOT_DRIVE in $ROOT_DRIVE_LIST
do
    gpart create -s gpt "${ROOT_DRIVE}"
    gpart add -a 4k -s 512k -t freebsd-boot "${ROOT_DRIVE}"
    gpart add -a 4k -t freebsd-zfs -l "boot${DRIVE_NUMBER}" "${ROOT_DRIVE}"
    gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 "${ROOT_DRIVE}"
    gnop create -S 4096 "/dev/gpt/boot${DRIVE_NUMBER}"
    ZPOOL_LIST="${ZPOOL_LIST:-}${SPACE:-}/dev/gpt/boot${DRIVE_NUMBER}.nop"
    SPACE=" "
    ((DRIVE_NUMBER++))
done

zpool create -f -m none -o altroot="${ALTROOT}" -o cachefile="${ZCACHE}" zroot mirror "${ZPOOL_LIST}"
zfs create -o mountpoint=none zroot/root
zfs create -o mountpoint=/ zroot/root/current
zfs set compression=lz4 zroot
zfs set atime=off zroot

echo "Creating zfs ssd partitions"
gpart create -s gpt "${SSD}"
gpart add -a 4k 0t freebsd-zfs -l "ssd0" "${SSD}"
gnop create -S 4096 /dev/gpt/ssd0
zpool create -f -m none -o altroot="${ALTROOT}" -o cachefile="${ZCACHE}" "${SSD_POOL}" /dev/gpt/ssd0.nop
zfs create -o mountpoint=/usr "${SSD_POOL}/usr"
zfs create "${SSD_POOL}/usr/local"
zfs create -o mountpoint=/var "${SSD_POOL}/var"
zfs create -o setuid=off "${SSD_POOL}/var/tmp"
chmod 1777 "${ALTROOT}/var/tmp"
zfs create -o mountpoint=/tmp "${SSD_POOL}/tmp"
chmod 1777 "${ALTROOT}/tmp"
zfs create -o mountpoint=/usr/home "${SSD_POOL}/home"
zfs create -o mountpoint=/usr/ports "${SSD_POOL}/ports"
zfs set compression=lz4 "${SSD_POOL}"
zfs set atime=off "${SSD_POOL}"

echo "Create jail zfs partitions"
zfs create -o mountpoint="${JAIL_DIR}" "${JAIL_ZFS}"
zfs create "${JAIL_ZFS}/config"
zfs create "${JAIL_ZFS}/releases"
zfs create "${JAIL_ZFS}/skeleton"
zfs create "${JAIL_ZFS}/thinjails"
zfs create "${JAIL_ZFS}/releases/${RELEASE}"
zfs create "${JAIL_ZFS}/skeleton/${RELEASE}"

echo "storage zfs initialization"
if [[ "${TEST}" == "test" ]]
then
    if [[ ! -d "${ALTROOT}/storage" ]]
        mkdir "${ALTROOT}/storage"
    fi
    zfs create -o mountpoint="${ALTROOT}/storage" "${SSD_POOL}/storage"
    zfs create "${SSD_POOL}/storage/download"
    zfs create "${SSD_POOL}/storage/media"
    zfs create "${SSD_POOL}/storage/config"
    zfs create "${SSD_POOL}/storage/share"
    DOWNLOAD_ZFS="${SSD_POOL}/storage/download"
    MEDIA_ZFS="${SSD_POOL}/storage/media"
    CONFIG_ZFS="${SSD_POOL}/storage/config"
    SHARE_ZFS="${SSD_POOL}/storage/share"
else
    zpool import zfs zstorage
    ########################################
    # set up old freenas into a better layout
    ########################################
fi

echo ""
echo "Install FreeBSD OS."
echo "This will take a few minutes..."
cd "${TEMP_DIR}"
for file in kernel.txz base.txz ports.txz
do
    fetch "ftp://ftp.freebsd.org/pub/FreeBSD/releases/${ARCH}/${RELEASE}/${file}"
    echo "installing ${file}..."
    if command -v pv >/dev/null 2>&1; 
    then 
        pv "${file}" | tar -xf - -C "${ALTROOT}"
        if [[ "${file}" == "base.txz" ]]
        then
            pv "${file}" | tar -xf - -C "${ALTROOT}${JAIL_DIR}/releases/${RELEASE}"
        fi
    else
        tar -xf "${file}" -C "${ALTROOT}"
        if [[ "${file}" == "base.txz" ]]
        then
            tar -xf "${file}" -C "${ALTROOT}${JAIL_DIR}/releases/${RELEASE}"
        fi
    fi
done

cd "${ALTROOT}"
ln -s usr/home home
ln -s root usr/home/root
mkdir mnt/backup mnt/storage
ln -s mnt/backup backup
ln -s mnt/storage storage

echo "Update files and copy scripts."

#resolv.conf
echo "search ${DOMAIN}" > "${ALTROOT}/etc/resolv.conf"
echo "nameserver ${GATEWAY}" >> "${ALTROOT}/etc/resolv.conf"
echo "nameserver 8.8.8.8" >> "${ALTROOT}/etc/resolv.conf"

#rc.conf
sysrc -R "${ALTROOT}" zfs_enable="YES"
sysrc -R "${ALTROOT}" defaultrouter="${GATEWAY}"
sysrc -R "${ALTROOT}" sendmail_submit_enable="NO"
sysrc -R "${ALTROOT}" sendmail_outbound_enable="NO"
sysrc -R "${ALTROOT}" sendmail_msp_queue_enable="NO"
sysrc -R "${ALTROOT}" hostname="${HOSTNAME}${TEST}.${DOMAIN}"
sysrc -R "${ALTROOT}" cloned_interfaces="lagg0"
sysrc -R "${ALTROOT}" zfs_enable="YES"
for NET in $(ifconfig | grep -v LOOPBACK | grep flags | cut -d: -f1)
do
    sysrc -R "${ALTROOT}" "ifconfig_${NET}=\"up\""
    LAG_STRING="${LAG_STRING:-"laggproto lacp"} laggport ${NET}"
done
sysrc -R "${ALTROOT}" ifconfig_lagg0="inet ${HOST_IP} netmask ${SUBNET} ${LAG_STRING}"

#loader.conf
echo 'vfs.root.mountfrom="zfs:zroot/root/current"' >> "${ALTROOT}/boot/loader.conf"
echo 'kern.geom.label.disk_ident.enable="0"' >> "${ALTROOT}/boot/loader.conf"
echo 'kern.geom.label.gpt.enable="1"' >> "${ALTROOT}/boot/loader.conf"
echo 'kern.geom.label.gptid.enable="0"' >> "${ALTROOT}/boot/loader.conf"
echo 'zfs_load="YES"' >> "${ALTROOT}/boot/loader.conf"

#make.conf
echo "OPTIONS_UNSET=CUPS NLS DOCS EXAMPLES X11" > "${ALTROOT}/etc/make.conf"
echo "OPTIONS_SET=OPTIMIZED_CFLAGS" >> "${ALTROOT}/etc/make.conf"
echo "DEFAULT_VERSIONS+=ssl=openssl" >> "${ALTROOT}/etc/make.conf"

#fstab
echo "${BACKUP_NFS} /mnt/backup nfs rw 0 0" > "${ALTROOT}/etc/fstab"

#copy files and scripts
cp -R "${SCRIPTS}" "${ALTROOT}/usr/local/scripts"
cp -R "${ROOT_FILES}" "${ALTROOT}/root"
cp -R "${USER_FILES}" "${ALTROOT}/home/homeadmin"

echo "jail configs and directory setup"
mkdir -p "${JAIL_DIR}/skeleton/${RELEASE}/home"
mkdir -p "${JAIL_DIR}/skeleton/${RELEASE}/portsbuild"
mkdir -p "${JAIL_DIR}/releases/${RELEASE}/skeleton"
zfs snapshot "${PORTS_ZFS}/@install"
zfs clone -o mountpoint="${JAIL_DIR}/releases/${RELEASE}/usr/ports" "${PORTS_ZFS}/@install" "${JAIL_DIR}/releases/${RELEASE}/ports"

MEDIA_DIR=$(zfs get all ${MEDIA_ZFS} | grep mountpoint | awk '{print $3}')
DOWNLOAD_DIR=$(zfs get all ${DOWNLOAD_ZFS} | grep mountpoint | awk '{print $3}')
CONFIG_DIR=$(zfs get all ${CONFIG_ZFS} | grep mountpoint | awk '{print $3}')
SHARE_DIR=$(zfs get all ${SHARE_ZFS} | grep mountpoint | awk '{print $3}')

cp "${ALTROOT}/usr/local/etc/portmaster.rc" "${JAIL_DIR}/releases/${RELEASE}/usr/local/etc/portmaster.rc"

echo 'sendmail_enable="NO"' >> "${JAIL_DIR}/releases/${RELEASE}/etc/rc.conf"
echo 'sendmail_submit_enable="NO"' >> "${JAIL_DIR}/releases/${RELEASE}/etc/rc.conf"
echo 'sendmail_outbound_enable="NO"' >> "${JAIL_DIR}/releases/${RELEASE}/etc/rc.conf"
echo 'sendmail_msp_queue_enable="NO"' >> "${JAIL_DIR}/releases/${RELEASE}/etc/rc.conf"

mv "${JAIL_DIR}/releases/${RELEASE}/etc" "${JAIL_DIR}/skeleton/${RELEASE}/etc"
mv "${JAIL_DIR}/releases/${RELEASE}/usr/local" "${JAIL_DIR}/skeleton/${RELEASE}/usr/local"
mv "${JAIL_DIR}/releases/${RELEASE}/tmp" "${JAIL_DIR}/skeleton/${RELEASE}/tmp"
mv "${JAIL_DIR}/releases/${RELEASE}/var" "${JAIL_DIR}/skeleton/${RELEASE}/var"
mv "${JAIL_DIR}/releases/${RELEASE}/root" "${JAIL_DIR}/skeleton/${RELEASE}/root"

cp "${ALTROOT}/etc/resolv.conf" "${JAIL_DIR}/releases/${RELEASE}/etc/resolv.conf"

cp "${ALTROOT}/etc/make.conf" "${JAIL_DIR}/skeleton/${RELEASE}/etc/make.conf"
echo "WRKDIRPREFIX?=/skeleton/portbuild" >> "${JAIL_DIR}/skeleton/${RELEASE}/etc/make.conf"

cd "${JAIL_DIR}/releases/${RELEASE}"
ln -s skeleton/etc etc
ln -s skeleton/home home
ln -s skeleton/root root
ln -s ../skeleton/usr/local usr/local
ln -s skeleton/tmp tmp
ln -s skeleton/var var
ln -s ../../skeleton/usr/ports/distfiles usr/ports/distfiles
echo "exec.start=\"/bin/sh /etc/rc\";" > "${JAIL_DIR}/config/jail.conf"
echo "exec.stop=\"/bin/sh /etc/rc.shutdown\";" >> "${JAIL_DIR}/config/jail.conf"
echo "exec.clean;" >> "${JAIL_DIR}/config/jail.conf"
echo "children.max=0;" >> "${JAIL_DIR}/config/jail.conf"
echo "allow.set_hostname=0;" >> "${JAIL_DIR}/config/jail.conf"
echo "mount.devfs;" >> "${JAIL_DIR}/config/jail.conf"
echo "allow.mount;" >> "${JAIL_DIR}/config/jail.conf"
echo "allow.raw_sockets;" >> "${JAIL_DIR}/config/jail.conf"
echo "interface=lagg0;" >> "${JAIL_DIR}/config/jail.conf"
echo "path=\"${JAIL_DIR}/mount/\${name}\";" >> "${JAIL_DIR}/config/jail.conf"
echo "host.hostname=\"\${name}server${TEST}.flanneryonline.com\";" >> "${JAIL_DIR}/config/jail.conf"
echo "mount.fstab=\"${JAIL_DIR}/config/\${name}.fstab\";" >> "${JAIL_DIR}/config/jail.conf"

echo "Creating and configuring jails."
zfs snapshot "${JAIL_ZFS}/skeleton/${RELEASE}@skeleton"
for JAIL_NAME in ${JAIL_LIST} ;
do
    zfs clone "${JAIL_ZFS}/skeleton/${RELEASE}@skeleton" "${JAIL_ZFS}/thinjails/${JAIL_NAME}"
    mkdir -p "${JAIL_DIR}/mount/${JAIL_NAME}"
    echo "${JAIL_DIR}/releases/${RELEASE} ${JAIL_DIR}/mount/${JAIL_NAME} nullfs ro 0 0" >> "${JAIL_DIR}/config/${JAIL_NAME}.fstab"
    echo "${JAIL_DIR}/thinjails/${JAIL_NAME} ${JAIL_DIR}/mount/${JAIL_NAME}/skeleton nullfs rw 0 0" >> "${JAIL_DIR}/config/${JAIL_NAME}.fstab"
    echo "${DATA_DIR} ${JAIL_DIR}/mount/${JAIL_NAME}/mnt/data nullfs rw 0 0" >> "${JAIL_DIR}/config/${JAIL_NAME}.fstab"
    if [[ "${JAIL_NAME}" == "plex" ]] || [[ "${JAIL_NAME}" == "tor" ]] || [[ "${JAIL_NAME}" == "nzbget" ]] || [[ "${JAIL_NAME}" == "cp" ]] || [[ "${JAIL_NAME}" == "sonarr" ]]
    then
        echo "${MEDIA_DIR} ${JAIL_DIR}/mount/${JAIL_NAME}/mnt/media nullfs rw 0 0" >> "${JAIL_DIR}/config/${JAIL_NAME}.fstab"
    fi
    if [[ "${JAIL_NAME}" == "tor" ]] || [[ "${JAIL_NAME}" == "nzbget" ]] || [[ "${JAIL_NAME}" == "cp" ]] || [[ "${JAIL_NAME}" == "sonarr" ]] ; then
        echo "${DOWNLOAD_DIR} ${JAIL_DIR}/mount/${JAIL_NAME}/mnt/downloads nullfs rw 0 0" >> "${JAIL_DIR}/config/${JAIL_NAME}.fstab"
    fi
    if [[ "${JAIL_NAME}" == "share" ]]
        echo "${SHARE_DIR} ${JAIL_DIR}/mount/${JAIL_NAME}/mnt/share nullfs rw 0 0" >> "${JAIL_DIR}/config/${JAIL_NAME}.fstab"
    fi
    echo "${CONFIG_DIR}/${JAIL_NAME} ${JAIL_DIR}/mount/${JAIL_NAME}/mnt/config/${JAIL_NAME} nullfs rw 0 0" >> "${JAIL_DIR}/config/${JAIL_NAME}.fstab"
    JAIL_IP=$(host ${JAIL_NAME}server${TEST}.${DOMAIN} | grep "has address" | awk '{ print $4 }')
    echo "${JAIL_NAME} {\$ip4.addr=${JAIL_IP};}" >> "${JAIL_DIR}/config/jail.conf"

    echo "Jail created: ${JAIL_NAME}"
done

ln -s "${JAIL_DIR}/config/jail.conf" "${ALTROOT}/etc/jail.conf"

###################################################
# UPDATE TO ADD share and www steps
###################################################
for JAIL_UPDATE in ${JAIL_LIST}
do
    mount -F "${JAIL_DIR}/config/${JAIL_UPDATE}.fstab"
    JAIL_ROOT="${JAIL_DIR}/mount/${JAIL_UPDATE}"
    chroot "${JAIL_ROOT}" make -C /usr/ports/ports-mgmt/portmaster -DBATCH install clean
    chroot "${JAIL_ROOT}" portmaster -a
    chroot "${JAIL_ROOT}" portmaster ports-mgmt/pkg
    chroot "${JAIL_ROOT}" pw useradd media -u 1001 -d /nonexistent -s /usr/sbin/nologin -w none
    if [[ "${JAIL_UPDATE}" == "nzbget" ]] || [[ "${JAIL_UPDATE}" == "sonarr" ]]
    then
        chroot "${JAIL_ROOT}" portmaster net-p2p/${JAIL_UPDATE}
        sysrc -R "${JAIL_ROOT}" ${JAIL_UPDATE}_enable="YES"
        sysrc -R "${JAIL_ROOT}" ${JAIL_UPDATE}_user="media"
        sysrc -R "${JAIL_ROOT}" ${JAIL_UPDATE}_data_dir="/mnt/config/${JAIL_UPDATE}"
    fi
    if [[ "${JAIL_UPDATE}" == "tor" ]]
    then
        chroot "${JAIL_ROOT}" portmaster net-p2p/deluge
        sysrc -R "${JAIL_ROOT}" transmission_enable="YES"
        sysrc -R "${JAIL_ROOT}" transmission_user="media"
        sysrc -R "${JAIL_ROOT}" transmission_config_dir="/mnt/config/${JAIL_UPDATE}"
    fi
    if [[ "${JAIL_UPDATE}" == "cp" ]]
    then
        chroot "${JAIL_ROOT}" portmaster lang/python databases/py27-sqlite3 ftp/fpc-libcurl textproc/docbook-xml devel/git-lite
        chroot "${JAIL_ROOT}" ln -s /usr/local/bin/python /usr/bin/python
        chroot "${JAIL_ROOT}" cd /usr/local && git clone https://github.com/CouchPotato/CouchPotatoServer.git
        chroot "${JAIL_ROOT}" cp /usr/local/CouchPotatoServer/init/freebsd /usr/local/etc/rc.d/couchpotato
        chroot "${JAIL_ROOT}" chmod 555 /usr/local/etc/rc.d/couchpotato
        sysrc -R "${JAIL_ROOT}" couchpotato_enable="YES"
        sysrc -R "${JAIL_ROOT}" couchpotato_user="media"
        sysrc -R "${JAIL_ROOT}" couchpotato_datadir="/mnt/config/${JAIL_UPDATE}"
    fi
    if [[ "${JAIL_UPDATE}" == "plex" ]]
    then
        chroot "${JAIL_ROOT}" portmaster multimedia/plexmediaserver-plexpass devel/git-lite lang/python2 databases/py-sqlite3 security/py-openssl
        chroot "${JAIL_ROOT}" cd /usr/local && git clone https://github.com/drzoidberg33/plexpy.git
        chroot "${JAIL_ROOT}" cp /usr/local/plexpy/init-scripts/init.freebsd /usr/local/etc/rc.d/plexpy
        chroot "${JAIL_ROOT}" chown -R media:media /usr/local/plexpy
        sysrc -R "${JAIL_ROOT}" plexpy_enable="YES"
        sysrc -R "${JAIL_ROOT}" plexpy_user="media"
        sysrc -R "${JAIL_ROOT}" plexpy_dir="/usr/local/plexpy"
        sysrc -R "${JAIL_ROOT}" plexpy_chdir="/mnt/config/${JAIL_UPDATE}/plexpy"
        sysrc -R "${JAIL_ROOT}" plexmediaserver_plexpass_enable="YES"
        sysrc -R "${JAIL_ROOT}" plexmediaserver_plexpass_user="media"
        sysrc -R "${JAIL_ROOT}" plexmediaserver_plexpass_group="media"
        sysrc -R "${JAIL_ROOT}" plexmediaserver_plexpass_support_path="/mnt/config/${JAIL_UPDATE}/pms"
    fi
    if [[ "${JAIL_UPDATE}" == "www" ]]
    then
        chroot "${JAIL_ROOT}" portmaster www/nginx
    fi
    if [[ "${JAIL_UPDATE}" == "share" ]]
    then
        chroot "${JAIL_ROOT}" portmaster net/samba44
    fi
    umount -F "${JAIL_DIR}/config/${JAIL_UPDATE}.fstab"
done

echo "install software to host system"
chroot "${ALTROOT}" make -C "${PORTS_DIR}/ports-mgmt/portmaster" -DBATCH install clean
echo "NO_BACKUP=Bopt" >> "${ALTROOT}/usr/local/etc/portmaster.rc"
echo "PM_NO_MAKE_CONFIG=Gopt" >> "${ALTROOT}/usr/local/etc/portmaster.rc"
echo "PM_NO_CONFIRM=pm_no_confirm" >> "${ALTROOT}/usr/local/etc/portmaster.rc"
echo "HIDE_BUILD=Hopt" >> "${ALTROOT}/usr/local/etc/portmaster.rc"
echo "PM_PACKAGES=first" >> "${ALTROOT}/usr/local/etc/portmaster.rc"
echo "PM_PACKAGES_BUILD=pmp_build" >> "${ALTROOT}/usr/local/etc/portmaster.rc"
echo "PM_LOG=/var/log/portmaster.log" >> "${ALTROOT}/usr/local/etc/portmaster.rc"

chroot "${ALTROOT}" portmaster  \
    mail/ssmpt                  \
    editors/vim-lite            \
    shells/zsh                  \
    security/sudo               \
###################################################
# ANYTHING ELSE?
###################################################

echo "root=pat@flanneryonline.com" >> "${ALTROOT}/usr/local/etc/ssmtp/ssmtp.conf"
echo "mailhub=smtp.mail.wowway.com" >> "${ALTROOT}/usr/local/etc/ssmtp/ssmtp.conf"
echo "AuthUser=pflannery" >> "${ALTROOT}/usr/local/etc/ssmtp/ssmtp.conf"
echo "AuthPass=hR0X2145nV4" >> "${ALTROOT}/usr/local/etc/ssmtp/ssmtp.conf"
chmod 640 "${ALTROOT}/usr/local/etc/ssmtp/ssmtp.conf"

###################################################
# TODO
# UTF-8
# 
# user files sym linked
#   does the skeleton carry over sym links?
# sudo setup
# 
# ports update script (system update)
# 
# jail upgrade script (system upgrade)
#
# snapshot script
#
###################################################

echo "host user/group setup"
chroot "${ALTROOT}" pw useradd -n "media" -u 1001 -s "/usr/sbin/nologin" -d "/nonexistent" -w no
chroot "${ALTROOT}" pw useradd -n "homeadmin" -u 5000 -s "/usr/local/bin/zsh" -G "wheel, media" -w no

chroot "${ALTROOT}" passwd "homeadmin"
chroot "${ALTROOT}" passwd "root"

echo "Creating install snapshots and preping rolling snapshots"
zfs snapshot -r zroot/@install
zfs snapshot -r zroot/@today
zfs snapshot -r zroot/@yesterday
zfs snapshot -r zroot/@lastweek
zfs snapshot -r zroot/@thisweek
zfs snapshot -r zroot/@lastmonth
zfs snapshot -r zroot/@thismonth
zfs snapshot -r zfast/@install
zfs snapshot -r zfast/@today
zfs snapshot -r zfast/@yesterday
zfs snapshot -r zfast/@lastweek
zfs snapshot -r zfast/@thisweek
zfs snapshot -r zfast/@lastmonth
zfs snapshot -r zfast/@thismonth
if [[ "${TEST}" == "" ]]
then
    zfs snapshot -r zstorage/@install
    zfs snapshot -r zstorage/@today
    zfs snapshot -r zstorage/@yesterday
    zfs snapshot -r zstorage/@lastweek
    zfs snapshot -r zstorage/@thisweek
    zfs snapshot -r zstorage/@lastmonth
    zfs snapshot -r zstorage/@thismonth
fi

echo "reset zpool"
cd /
zpool export zroot
gnop destroy /dev/gpt/boot0.nop
gnop destroy /dev/gpt/boot1.nop
zpool import -m none -o altroot="${ALTROOT}" -c "${ZCACHE}" zroot

echo "Set the bootfs property and set options"
zpool set bootfs=zroot/root/current zroot

echo "Copy zpool.cache to install disk."
cp "${ZCACHE}" "${ALTROOT}/boot/zfs/zpool.cache"

echo "Clear memory cache"
rm -R "${TEMP_DIR}"

echo "Syncing..."
sync
echo ""
echo "Install Done."
echo "Reboot now."

exit 0

#### EOF ####
