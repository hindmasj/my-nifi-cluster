### [Home (README.md)](../README.md)
---

# Working With Elasticsearch

This section works with the [my-elasticsearch-cluster](../../my-elasticsearch-cluster) project.

From here we assume both the NiFi and Elasticsearch clusters are up and running.

## Reverse Proxy

In an initial test of just connecting the NiFi containers to the elasticsearch network created by the Elasticsearch cluster project, the result was that the port bindings were destroyed, so the nodes could no longer be contacted to connect the GUI. So instead a standalone elasticsearch network is created which will be shared by both projects and the NiFI nodes will connect to that. All of the containers will connect to a default network too, only the NiFi nodes need to connect to the elasticsearch nodes.

That still makes connecting from the localhost to the exposed ports difficult. There seems to be a problem with the docker network exposing ports that are connected to more than one network. Instead a reverse proxy server has been set up which provides a connection to the main pages of both the NiFi cluster and the registry. See "conf/proxy.conf".

Once the service has launched, go to http://localhost:8080/. Then click on "NiFi Cluster". At first you will get a "Bad Gateway" error until the nodes are up. Notice in the proxy configuration you need to set headers to let NiFi know where the reverse proxy is, and you need to set locations for "nifi-api" and "nifi-content-viewer".

## Connect Via Docker Host

The proxy works fine when the "elasticsearch" network is not connected, but once it is the NiFi node gets confused as to which network it is on and makes reverse proxy requests to itself, but on the wrong network. Need to explore the "[external_links](https://docs.docker.com/compose/compose-file/compose-file-v3/#external_links)" feature instead. So I have abandoned to idea of using a connection over the elasticsearch network and instead will use the host maching to make the connection.

This is now documented in the elasticsearch project, and involved using a docker compose file specifically for a multi-node elasticsearch cluster, and building the host alias as a SAN into the primary node's certificate.

The quick test of this then is as follows.

```
docker compose cp ../my-elasticsearch-cluster/netrc nifi:/home/nifi/.netrc
docker compose cp ../my-elasticsearch-cluster/http_ca.crt nifi:/opt/nifi/nifi-current/es_ca.crt
docker compose exec nifi curl -n --cacert es_ca.crt https://host.docker.internal:9200/_cat/nodes
```

## Create Truststore

To get the ES node to be trusted by NiFi, create a truststore from the CA file. This script copies the CA file from es01, builds it into a truststore with an empty password, then adds it to NiFi conf.

```
bin/build-truststore.sh
```

Then create an SSL trust service.

| Parameter | Value |
|-- |-- |
| Type | StandardRestrictedSSLContextService |
| Truststore Filename | conf/es_ca.pfx |
| Truststore Password | Empty String |
| Truststore Type | PKCS12 |

## TODO

* Create a trust store for the NiFI nodes.
* Create an API key for NiFi.
* Create some put and lookup services and flows.

---
### [Home (README.md)](../README.md)
