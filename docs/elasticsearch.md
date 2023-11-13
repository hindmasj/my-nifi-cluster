### [Home (README.md)](../README.md)
---

# Working With Elasticsearch

This section works with the [my-elasticsearch-cluster](../../my-elasticsearch-cluster) project.

From here we assume both the NiFi and Elasticsearch clusters are up and running.

## Reverse Proxy

In an initial test of just connecting the NiFi containers to the elasticsearch network created by the Elasticsearch cluster project, the result was that the port bindings were destroyed, so the nodes could no longer be contacted to connect the GUI. So instead a standalone elasticsearch network is created which will be shared by both projects and the NiFI nodes will connect to that. All of the containers will connect to a default network too, only the NiFi nodes need to connect to the elasticsearch nodes.

That still makes connecting from the localhost to the exposed ports difficult. There seems to be a problem with the docker network exposing ports that are connected to more than one network. Instead a reverse proxy server has been set up which provides a connection to the main pages of both the NiFi cluster and the registry. See "conf/proxy.conf".

Once the service has launched, go to http://localhost:8080/. Then click on "NiFi Cluster". At first you will get a "Bad Gateway" error until the nodes are up. Notice in the proxy configuration you need to set headers to let NiFi know where the reverse proxy is, and you need to set locations for "nifi-api" and "nifi-content-viewer".

The proxy works fine when the "elasticsearch" netwrok is not connected, but once it is the NiFi node gets confused as to which network it is on and makes reverse proxy requests to itself, but on the wrong network. Need to explore the "[external_links](https://docs.docker.com/compose/compose-file/compose-file-v3/#external_links)" feature instead.

## TODO - Connection

See notes above, this will need to change.

Run the script ``bin/connect-elasticsearch`` which sets up the network, netrc file and collects the master certificate.

Note that the certificate uses the master hostname "es01", and does not define an alternative name. This can be solved by creating a client node with the service name matching the host name, and this will get resolved later as one of the Elasticsearch cluster TODO's.

Issue seems to be that connecting the nifi containers to the elastic network has destroyed the container port bindings.

---
### [Home (README.md)](../README.md)
