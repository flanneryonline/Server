#!/bin/bash

. "${INSTALL_ENVIRONMENT:-${SERVER_INSTALL:-~/server}/environment/install}"

version=$(curl -ILsS -w "%{url_effective}" "https://github.com/docker/compose/releases/latest" -o /dev/null)
version=${version##*/}
[ -f "$root/usr/bin/docker-compose" ] && rm "$root/usr/bin/docker-compose"
curl -fsSL "https://github.com/docker/compose/releases/download/$version/docker-compose-$(uname -s)-$(uname -m)" \
    -o "$root/usr/bin/docker-compose"
[ -f "$root/etc/bash_completion.d/docker-compose" ] && rm "$root/etc/bash_completion.d/docker-compose"
curl -fsSL "https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose" \
    -o "$root/etc/bash_completion.d/docker-compose"