#!/usr/bin/env bash

LOC=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

SERVICE=redis

docker compose exec ${SERVICE} redis-cli -a nifi_redis
