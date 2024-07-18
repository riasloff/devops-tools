#!/usr/bin/env bash

set -euo pipefail

echo "Checking that /opt/containers/docker-compose.yml available and move"
if test -f /opt/containers/docker-compose.yml; then
    mv /opt/containers/docker-compose.yml /opt/containers/docker-compose.yaml
fi

echo "Checking that /opt/containers/docker-compose.yaml available"
if [ ! -f "/opt/containers/docker-compose.yaml" ]; then
    systemctl disable --now container-starter.service
else
    systemctl enable --now container-starter.service
fi


if test -f /opt/gomplate/values/user-values.yml; then
    mv /opt/gomplate/values/user-values.yml /opt/gomplate/values/user-values.yaml
fi

if test -f /opt/gomplate/values/user-values.yaml; then
    portainer_password=$(cat /opt/gomplate/values/user-values.yaml | yq .portainer_password)
    if test -n "${portainer_password}"; then
        echo "Render /opt/portainer/docker-compose.yml"
        portainer_hashed_password=$(/opt/scripts/portainer_pass_to_hash.sh ${portainer_password})
        echo "portainer_hashed_password: ${portainer_hashed_password}" > /opt/gomplate/values/password_hash.yaml
        gomplate --missing-key zero --config /opt/gomplate/configs/portainer.yml -V
        docker compose -f /opt/portainer/docker-compose.yml up -d
        source /opt/portainer/portainer.env

        # generate le certificate
        if test "true" = "${PORTAINER_USE_LE}"; then
            echo "Generate LE certificates for ${PORTAINER_DOMAIN}"
            while ! ping -c 4 google.com > /dev/null; do
                echo "The network is not up yet"
                sleep 1
            done
            certbot certonly --standalone --noninteractive --agree-tos --email ${PORTAINER_LE_EMAIL} -d ${PORTAINER_DOMAIN}
            exit 0
        fi
        exit 0
    fi
fi
echo "Portainer password empty. Create /opt/gomplate/values/user-values.yaml with \"portainer_password: RANDOM_PASSWORD\""
exit 1
