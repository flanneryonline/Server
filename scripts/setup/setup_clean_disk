#!/usr/bin/env bash

set -o errexit
set -o nounset

# No args? More than 1 arg?
if [[ $# -ne 1 ]]
then
    exit 1
fi

DRIVE=$1

# Check if arg is a drive
if [[ ! -e /dev/${DRIVE} ]]
then 
    exit 1
fi

# MAX is the number of partitions that need to be removed before we can destroy the disk
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

exit 0
