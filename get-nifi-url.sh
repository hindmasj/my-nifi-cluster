#!/usr/bin/env bash

LOC=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

PREFIX=my-nifi-cluster
SERVICE=nifi

port=$(docker compose ps | \
  awk '/'${PREFIX}-${SERVICE}-1'/ {print gensub(".*:([[:digit:]]+)->.*","\\1","g",$5)}')

echo "http://localhost:${port}/nifi"
