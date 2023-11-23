#!/usr/bin/env bash

LOC=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

ES_CLUSTER=my-elasticsearch-cluster
ES_NODE=es01
ES_HOME=/usr/share/elasticsearch
NIFI_CONF=/opt/nifi/nifi-current/conf
ES_CA_PATH=${ES_HOME}/config/certs/ca/ca.crt

docker compose -p ${ES_CLUSTER} cp ${ES_NODE}:${ES_CA_PATH} es_ca.crt

openssl pkcs12 -export -nokeys -name ca -in es_ca.crt -out es_ca.pfx -password pass:elastic
docker compose cp es_ca.pfx nifi:${NIFI_CONF}

rm -f es_ca.jks
keytool -keystore es_ca.jks -storepass elastic -storetype jks -alias ca -import -file es_ca.crt -trustcacerts -noprompt
docker compose cp es_ca.jks nifi:${NIFI_CONF}


