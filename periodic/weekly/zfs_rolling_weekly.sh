#!/usr/bin/env bash

set -o errexit
set -o nounset

zfs destroy -r zroot@lastweek >/dev/null 2>&1
zfs destroy -r zfast@lastweek >/dev/null 2>&1
zfs destroy -r zstorage@lastweek >/dev/null 2>&1

zfs rename -r zroot@thisweek @lastweek >/dev/null 2>&1
zfs rename -r zfast@thisweek @lastweek >/dev/null 2>&1
zfs rename -r zstorage@thisweek @lastweek >/dev/null 2>&1

zfs snapshot -r zroot@thisweek >/dev/null 2>&1
zfs snapshot -r zfast@thisweek >/dev/null 2>&1
zfs snapshot -r zstorage@thisweek >/dev/null 2>&1

exit 0

