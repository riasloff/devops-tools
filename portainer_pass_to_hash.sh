#!/usr/bin/env bash

if test -n "$1"; then
    htpasswd -nbB admin $1 | cut -d ":" -f 2 | sed 's/\$/\$\$/g'
else
    echo "usage: portainer_pas_to_hash.sh PASSWORD"
    exit 1
fi

