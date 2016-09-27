#!/usr/bin/env bash

set -o errexit
set -o nounset

RUN="$(pwd)/setup/"

#make sure scripts are executable
chmod -R +x ${RUN}*

${RUN}setup_clean_disk 
${RUN}setup_base_install $(uname -a) "10.3-RELEASE" "${ALTROOT}" 

exit 0

