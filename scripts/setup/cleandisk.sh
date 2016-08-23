#!/usr/local/env bash

set -o errexit
set -o nounset

#check if drive exists
if [[ ! -f /dev/${DRIVE} ]]
then 
    exit 1
fi

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
