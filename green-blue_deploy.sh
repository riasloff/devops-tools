#!/bin/sh
set -xe

export VERSION="${VERSION}"
export LOG_PATH="${LOG_PATH}"
export REPORT_PATH="${REPORT_PATH}"
export SPRING_DATASOURCE_USERNAME="${SPRING_DATASOURCE_USERNAME}"
export SPRING_DATASOURCE_PASSWORD="${SPRING_DATASOURCE_PASSWORD}"
export SPRING_DATASOURCE_URL="${SPRING_DATASOURCE_URL}"
export SPRING_CLOUD_VAULT_TOKEN="${SPRING_CLOUD_VAULT_TOKEN}"

docker login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}

# means that both containers are up & healthy
if [ "$(docker ps -a --filter "name=sausage-backend-green" --filter "health=healthy" | wc -l)" -eq 2 ] \
  && [ "$(docker ps -a --filter "name=sausage-backend-blue" --filter "health=healthy" | wc -l)" -eq 2 ]; then
  echo "both containers are up & healthy"
  docker rm -f sausage-backend-green || true
  docker compose up -d backend-green
  until [ "$(docker ps -a --filter "name=sausage-backend-green" --filter "health=healthy" | wc -l)" -eq 2 ]; do sleep 10; done
  docker rm -f sausage-backend-blue || true

# means that only green container is up
elif [ "$(docker ps -a --filter "name=sausage-backend-green" --filter "health=healthy" | wc -l)" -eq 2 ]; then
  echo "only green container is up"
  docker rm -f sausage-backend-blue || true
  docker compose up -d backend-blue
  until [ "$(docker ps -a --filter "name=sausage-backend-blue" --filter "health=healthy" | wc -l)" -eq 2 ]; do sleep 10; done
  docker rm -f sausage-backend-green || true

elif [ "$(docker ps -a --filter "name=sausage-backend-blue" --filter "health=healthy" | wc -l)" -eq 2 ]; then
  echo "only blue container is up"
  docker rm -f sausage-backend-green || true
  docker compose up -d backend-green
  until [ "$(docker ps -a --filter "name=sausage-backend-green" --filter "health=healthy" | wc -l)" -eq 2 ]; do sleep 10; done
  docker rm -f sausage-backend-blue || true

# means that no up containers
else
    echo "no up containers - starting both"
    docker rm -f sausage-backend-green sausage-backend-blue || true
    docker compose up -d backend-blue
fi
