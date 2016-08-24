#!/usr/bin/env bash
# 
# ARGS
# $1 = ARCH
# $2 = RELEASE
# $3 = ROOT
# $4 = KERNEL FLAG
#

set -o errexit
set -o nounset

CUR_DIR=$(pwd)

# make sure args are passed
if [[ $# -eq 0 ]]
then
    exit 1
fi

ARCH=$1
RELEASE=$2
ROOT=$3
KERNEL=$4

# Check variables
# This would changeover time based on what is supported
VALID_ARCH="amd64 arm i386 ia64 powerpc sparc64"
VALID_RELEASE_NUM="9.3 10.1 10.2 10.3 11.0"
ARCH_VALID=0
RELEASE_VALID=0
for ARCH_CHECK in $VALID_ARCH
do
    if [[ ${ARCH} == ${ARCH_CHECK} ]]
    then
        ARCH_VALID=1
    fi
done
for RELEASE_CHECK_NUM in $VALID_RELEASE_NUM
do
    if [[ ${RELEASE} == ${RELEASE_CHECK_NUM}-RELEASE ]]
    then
        RELEASE_VALID=1
    fi
done
if [[ $RELEASE_VALID -ne 1 ]] || [[ $ARCH_VALID -ne 1 ]] || [[ ! -d "${ROOT}" ]]
then
    echo "Invalid variable supplied."
    exit 1
fi
if [[ ${KERNEL} -ne 1 ]]
    KERNEL=0
fi

if [[ -d /tmp ]]
then
    cd /tmp
elif [[ -d /var/tmp ]]
    cd /var/tmp
else 
    cd "${ROOT}" # Checked above already
fi

fetch "ftp://ftp.freebsd.org/pub/FreeBSD/releases/${ARCH}/${RELEASE}/base.txz"
if [[ ${KERNEL} -eq 1 ]]
then
    fetch "ftp://ftp.freebsd.org/pub/FreeBSD/releases/${ARCH}/${RELEASE}/kernel.txz"
fi
if command -v pv >/dev/null 2>&1
then
    pv base.txz | tar -xf - -C "${ROOT}"
    if [[ ${KERNEL} -eq 1 ]]
    then
        pv kernel.txz | tar -xf - -C "${ROOT}"
    fi
else
    echo "Installing base. Please wait..."
    tar -xf base.txz -C "${ROOT}" >/dev/null 2>&1
    if [[ ${KERNEL} -eq 1 ]]
    then
        echo "Installing kernel. Please wait..."
        tar -xf kernel.txz -C "${ROOT}" >/dev/null 2>&1
    fi
fi

rm base.txz
if [[ ${KERNEL} -eq 1 ]]
then
    rm kernel.txz
fi

cd "${CUR_DIR}"

echo "Install successful."
exit 0
