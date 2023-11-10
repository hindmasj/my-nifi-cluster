### [Home (README.md)](../README.md)
---

# Working With Elasticsearch

This section works with the [my-elasticsearch-cluster](../../my-elasticsearch-cluster) project.

From here we assume both the NiFi and Elasticsearch clusters are up and running.

## Connection

Run the script ``bin/connect-elasticsearch`` which sets up the network, netrc file and collects the master certificate.

Note that the certificate uses the master hostname "es01", and does not define an alternative name. This can be solved by creating a client node with the service name matching the host name, and this will get resolved later as one of the Elasticsearch cluster TODO's.

Issue seems to be that connecting the nifi containers to the elastic network has destroyed the container port bindings.

---
### [Home (README.md)](../README.md)
