#!/bin/sh

zfs destroy -r zroot@yesterday >/dev/null 2>&1
zfs destroy -r zfast@yesterday >/dev/null 2>&1
zfs destroy -r zstorage@yesterday >/dev/null 2>&1

zfs rename -r zfast@today @yesterday >/dev/null 2>&1
zfs rename -r zroot@today @yesterday >/dev/null 2>&1
zfs rename -r zstorage@today @yesterday >/dev/null 2>&1

zfs snapshot -r zroot@today >/dev/null 2>&1
zfs snapshot -r zfast@today >/dev/null 2>&1
zfs snapshot -r zstorage@today >/dev/null 2>&1

exit 0

