#!/usr/bin/env bash

LOC=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
URL=$(${LOC}/get-nifi-url.sh)

JSON='{"revision":{"version":"0"},"component":{"uri":"http://registry:18080/","name":"Test"}}'
HEADER='Content-type: application/json'
ENDP="${URL}-api/controller/registry-clients"

curl -X POST ${ENDP} -H "${HEADER}" -d "${JSON}"
echo

curl -X GET ${ENDP} | jq
echo
