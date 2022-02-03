#!/usr/bin/env bash

PREFIX=my-nifi-cluster
SERVICE=kafka
PORT=9092
BOOTSTRAP=${PREFIX}-${SERVICE}-1:${PORT}

RETAIN=36000000
REPLIC=3

for topic in source sink
do
  kafka-topics.sh --bootstrap-server ${BOOTSTRAP} \
    --create --topic my.${topic}.topic \
    --replication-factor ${REPLIC} \
    --config retention.ms=${RETAIN}
done
