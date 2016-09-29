#!/usr/bin/env bash
#
# This script assumes it was cloned from git repo to ~
#

set -o errexit
set -o nounset

source ~/server/scripts/setup/setup_base_install

base_install $(uname -a) "10.3-RELEASE" "${ALTROOT}" 

exit 0

