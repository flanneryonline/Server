#!/usr/vin/env bash

set -o errexit
set -o nounset

# check variables and set...
# GATEWAY
# HOSTNAME
# TEST
# DOMAIN

sysrc -R "${ALTROOT}" zfs_enable="YES"
sysrc -R "${ALTROOT}" defaultrouter="${GATEWAY}"
sysrc -R "${ALTROOT}" sendmail_submit_enable="NO"
sysrc -R "${ALTROOT}" sendmail_outbound_enable="NO"
sysrc -R "${ALTROOT}" sendmail_msp_queue_enable="NO"
sysrc -R "${ALTROOT}" hostname="${HOSTNAME}${TEST}.${DOMAIN}"

