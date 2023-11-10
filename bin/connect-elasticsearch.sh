#!/usr/bin/env bash
# Connect the NiFi nodes to the Elasticsearch project

ES_PROJ="my-elasticsearch-cluster"
ES_NODE="master"
ES_HOST="es01"
ES_NET="elastic"
NF_PROJ="my-nifi-cluster"
NF_NODE="nifi"

for node in $(docker compose -p ${NF_PROJ} ps --format 'table {{.Name}}' ${NF_NODE}|grep -v NAME)
do
    docker network connect ${ES_PROJ}_${ES_NET} ${node}
done

NETRC=$(mktemp)
cat > ${NETRC} << EOF
machine ${ES_HOST}
login elastic
password elastic
EOF
docker compose -p ${NF_PROJ} cp ${NETRC} ${NF_NODE}:/opt/nifi/nifi-current/conf/netrc
rm ${NETRC}

CERT=$(mktemp)
docker compose -p ${ES_PROJ} cp ${ES_NODE}:/usr/share/elasticsearch/config/certs/http_ca.crt ${CERT}
#cat ${CERT}
docker compose -p ${NF_PROJ} cp ${CERT} ${NF_NODE}:/opt/nifi/nifi-current/conf/elasticsearch.crt
rm ${CERT}

docker compose -p ${NF_PROJ} exec nifi curl --cacert conf/elasticsearch.crt -n --netrc-file conf/netrc https://${ES_HOST}:9200/

