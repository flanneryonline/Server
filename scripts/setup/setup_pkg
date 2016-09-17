#!/usr/bin/env sh

#copied from man page
if \
    TMPDIR=/dev/null \
    ASSUME_ALWAYS_YES=yes \
    PACKAGESITE=file:///nonexistent \
    pkg info -x 'pkg(-devel)?$' >/dev/null 2>&1
then
    env ASSUME_ALWAYS_YES=YES pkg bootstrap
fi

#make sure bootstrap worked
if \
    TMPDIR=/dev/null \
    ASSUME_ALWAYS_YES=yes \
    PACKAGESITE=file:///nonexistent \
    pkg info -x 'pkg(-devel)?$' >/dev/null 2>&1
then
    return 1
fi

return 0

