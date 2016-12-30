#!/usr/bin/env bash

set -o errexit
set -o nounset

zfs destroy -r zroot@lastmonth >/dev/null 2>&1
zfs destroy -r zfast@lastmonth >/dev/null 2>&1
zfs destroy -r zstorage@lastmonth >/dev/null 2>&1

zfs rename -r zroot@thismonth @lastmonth >/dev/null 2>&1
zfs rename -r zfast@thismonth @lastmonth >/dev/null 2>&1
zfs rename -r zstorage@thismonth @lastmonth >/dev/null 2>&1

zfs snapshot -r zroot@thismonth >/dev/null 2>&1
zfs snapshot -r zfast@thismonth >/dev/null 2>&1
zfs snapshot -r zstorage@thismonth >/dev/null 2>&1

exit 0

