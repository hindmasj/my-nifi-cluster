### [Home (README.md)](../README.md)
---

# Working With Elasticsearch

This section works with the [my-elasticsearch-cluster](../../my-elasticsearch-cluster) project.

From here we assume both the NiFi and Elasticsearch clusters are up and running. If you are not interested in detail then just follow the quickstart guide.

* [Quickstart](#quickstart)
* [Build Connection](#build_connection)
* [Build Elasticsearch Flow](#build_flow)

## <a name="quickstart"></a>Quickstart

To get to a working cluster quickly then follow these steps. The detail of how it got here is explained further down.

1. Ensure both clusters have started.
1. Copy the Elasticsearch certificates to the NiFi cluster and test the connection, ``bin/connect-elasticsearch.sh``.
1. Build the certificates into a truststore, ``bin/build-truststore.sh``.

You can now create flows that connect to the Elasticsearch cluster and use the truststore to verify the SSL connections. The account details are as follows, and you will see them used in the example.

| Resource              | Name           | Password |
|-----------------------|----------------|----------|
| Truststore File       | conf/es_ca.jks | elastic  |
| Elasticsearch Account | elastic        | elastic  |

Now read on for detail, or skip to [Build Elasticsearch Flow](#build_flow) for an example flow.

## <a name="build_connection"></a>Building The Connection

This section describes some of the detail of how the connection scripts came about.

### Reverse Proxy

In an initial test of just connecting the NiFi containers to the elasticsearch network created by the Elasticsearch cluster project, the result was that the port bindings were destroyed, so the nodes could no longer be contacted to connect the GUI. So instead a standalone elasticsearch network is created which will be shared by both projects and the NiFI nodes will connect to that. All of the containers will connect to a default network too, only the NiFi nodes need to connect to the elasticsearch nodes.

That still makes connecting from the localhost to the exposed ports difficult. There seems to be a problem with the docker network exposing ports that are connected to more than one network. Instead a reverse proxy server has been set up which provides a connection to the main pages of both the NiFi cluster and the registry. See "conf/proxy.conf".

Once the service has launched, go to http://localhost:8080/. Then click on "NiFi Cluster". At first you will get a "Bad Gateway" error until the nodes are up. Notice in the proxy configuration you need to set headers to let NiFi know where the reverse proxy is, and you need to set locations for "nifi-api" and "nifi-content-viewer".

### Connect Via Docker Host

The proxy works fine when the "elasticsearch" network is not connected, but once it is the NiFi node gets confused as to which network it is on and makes reverse proxy requests to itself, but on the wrong network. Also had a look at the "[external_links](https://docs.docker.com/compose/compose-file/compose-file-v3/#external_links)" feature instead. I have abandoned to idea of using a connection over the elasticsearch network and instead will use the host machine to make the connection.

This is now documented in the elasticsearch project, and involved using a docker compose file specifically for a multi-node elasticsearch cluster, and building the host alias as a SAN into the primary node's certificate.

The quick command line test of this then is as follows.

```
docker compose cp ../my-elasticsearch-cluster/netrc nifi:/home/nifi/.netrc
docker compose cp ../my-elasticsearch-cluster/http_ca.crt nifi:/opt/nifi/nifi-current/es_ca.crt
docker compose exec nifi curl -n --cacert es_ca.crt https://host.docker.internal:9200/_cat/nodes
```

The script ``bin/connect-elasticsearch.sh`` now performs the required copying and setting up of the certificate data.

### Create Truststore

To get the ES node to be trusted by NiFi, create a truststore from the CA file. This script copies the CA file from es01, builds it into a truststore with the password "elastic", then adds it to NiFi conf.

```
bin/build-truststore.sh
```
#### Truststore Creation Issue

The first attempt at doing this with ``openssl`` to create a PKCS style truststore resulted in the following error.

```
java.io.IOException: java.security.InvalidAlgorithmParameterException: the trustAnchors parameter must be non-empty
```

So you need to use Java keystore to create the stores, as openssl does add the required tag to the certificate to indicate it is trusted. Examining the trustore shows this difference.

```
$ diff es_ca.txt-keystore es_ca.txt-openssl
1,3c1
< Bag Attributes
<     friendlyName: ca
<     2.16.840.1.113894.746875.1.1: <Unsupported tag 6>
    ---
    > Bag Attributes: <No Attributes>
```

Research continues. A reading of https://github.com/openssl/openssl/pull/19025 suggest a feature to support this will be available in Openssl 3.2. I am currently on 3.0.9.

So instead the script builds a truststore based on JKS using Java ``keytool``.

## <a name="build_flow"></a>Build An Elasticsearch Flow

This section describes the basics of adding an Elasticsearch connection to your flow. You will need a minimum of JSON readers and writers defined and some JSON data to play with.

### Set Up Parameters

Use a parameter context to record the values of the truststore filename and password, and the Elasticsearch URL, username and password.

### Create SSL Trust Service

Create an SSL trust service. Both JKS and PFX type truststores are created by the script so you can use either.

| Parameter           | Value                               |
|---------------------|-------------------------------------|
| Type                | StandardRestrictedSSLContextService |
| Truststore Filename | conf/es_ca.jks                      |
| Truststore Password | elastic                             |
| Truststore Type     | JKS                                 |

### Create A Client Connection Service

Create an Elasticsearch client implementation service.

| Parameter           | Value                               |
|---------------------|-------------------------------------|
| Type                | ElasticSearchClientServiceImpl      |
| HTTP Hosts          | https://host.docker.internal:9200/  |
| Username            | elastic                             |
| Password            | elastic                             |
| SSL Context Service | StandardRestrictedSSLContextService |

### Put Data

To put data you just need a "PutElasticsearchRecord" processor. If you have an index and/or template already defined then so much the better.

| Parameter                 | Value                                           |
|---------------------------|-------------------------------------------------|
| Class                     | PutElasticsearchRecord                          |
| Index Operation           | index                                           |
| Index                     | &lt;index name&gt;                              |
| Client Service            | ElasticSearchClientServiceImpl                  |
| Record Reader             | &lt;JSON reader service&gt;                     |
| ID Record Path (optional) | &lt;record path value&gt;                       |
| Retain ID                 | (set to true if you have set the above setting) |

### Lookup Data

You need to define an "ElasticsearchLookup" service then use a "LookupRecord" processor. The lookup requires the result to be unique, so it often makes sense to have used a key within the data put operation to give each record an index ID that relates to the data. Elasticsearch ensures IDs are unique, overwriting an old record with a new one in the case of an ID clash (although you can configure this).

**Lookup Service**

This defines a service to lookup data across a pattern, not just a single index.

| Parameter           | Value                               |
|---------------------|-------------------------------------|
| Type                | ElasticSearchLookupService          |
| Client Service      | ElasticSearchClientServiceImpl      |
| Index               | &lt;index pattern&;                 |

**Lookup Processor**

This defines a processor which, given a search key, will lookup the record with that index. As noted above you can lookup on any field, but you have to return a unique result. As with other lookups, unless you are using a schema oriented writer you need to ensure the stub of the result record path already exists in the input record.

| Parameter          | Value                          |
|--------------------|--------------------------------|
| Class              | LookupRecord                   |
| Lookup Service     | ElasticSearchLookupService     |
| Result Record Path | &lt;record path for result&gt; |
| key                | &lt;record path for key&gt;    |

## TODO

* Create a trust store for the NiFI nodes. DONE!
* Create some put and lookup services and flows. DONE!
* Create an API key for NiFi.

---
### [Home (README.md)](../README.md)
