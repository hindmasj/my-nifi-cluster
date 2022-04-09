#!/usr/bin/env bash

LOC=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

SERVICE=kafka
MOUNT=/mnt/local
SCRIPT=${1:-create-topics.sh}
shift

docker compose run --volume ${LOC}:${MOUNT} ${SERVICE} \
  ${MOUNT}/${SCRIPT} ${@}
