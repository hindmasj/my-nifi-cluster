#!/usr/bin/env bash

SERVICE=kafka
PORT=9092
BOOTSTRAP=${SERVICE}:${PORT}

RETAIN=36000000
REPLIC=3

for topic in source sink enrichment
do
  kafka-topics.sh --bootstrap-server ${BOOTSTRAP} \
    --create --topic my.${topic}.topic \
    --replication-factor ${REPLIC} \
    --config retention.ms=${RETAIN}
done
