#!/usr/bin/env bash

LOC=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

PORT=8080
SERVICE=nifi

#port=$(docker compose ps | \
#  awk '/'${PREFIX}-${SERVICE}-1'/ {print gensub(".*:([[:digit:]]+)->.*","\\1","g",$5)}')

# port=$(docker compose port ${SERVICE} ${PORT} | cut -d: -f2)

echo "http://localhost:${PORT}/nifi"
