# my-nifi-cluster
Quick project to create a NiFi cluster in Docker

Inspired by article [Running a cluster with Apache Nifi and Docker](https://www.nifi.rocks/apache-nifi-docker-compose-cluster/) and shamelessly pinched their compose file, hence the Apache licence.

# Operation

## Start

1. Start the cluster with ``docker-compose up -d --scale nifi=3``. You need 3 NiFi nodes to hold a proper election for master.
1. Run ``docker ps`` to get the port mappings from network 0.0.0.0 to port 8080 to one of those nodes.
1. Connect to the web server at *http\://localhost:\<port\>/nifi*.

For example

````
$ docker ps
CONTAINER ID   IMAGE                      COMMAND                  CREATED          STATUS          PORTS                                                    NAMES
10d046c19e11   apache/nifi:latest         "../scripts/start.sh"    15 seconds ago   Up 13 seconds   8000/tcp, 8443/tcp, 10000/tcp, 0.0.0.0:61891->8080/tcp   my-nifi-cluster-nifi-3
4e9bfbaf9c64   apache/nifi:latest         "../scripts/start.sh"    15 seconds ago   Up 13 seconds   8000/tcp, 8443/tcp, 10000/tcp, 0.0.0.0:61890->8080/tcp   my-nifi-cluster-nifi-2
22e4836f12be   apache/nifi:latest         "../scripts/start.sh"    15 seconds ago   Up 13 seconds   8000/tcp, 8443/tcp, 10000/tcp, 0.0.0.0:61892->8080/tcp   my-nifi-cluster-nifi-1
de557e3b5323   bitnami/zookeeper:latest   "/opt/bitnami/script…"   15 seconds ago   Up 13 seconds   2181/tcp, 2888/tcp, 3888/tcp, 8080/tcp                   zookeeper
````

Then the bit you want is: ``0.0.0.0:61892->8080/tcp   my-nifi-cluster-nifi-1`` and you need port 61892.

## Create Flows

Once connected to the GUI you can create your flows. To get you started their is a simple stored under the templates directory. Load it from NiFi desktop.

*right click* -> Upload Template -> *browse* -> "Simple_Kafka_Flow.xml" -> Upload

Then add the template onto the desktop from the design bar.

*drag template icon* -> Choose Template: "Simple_Kafka_Flow" -> Add

## Stop

Simply ``docker-compose down`` to stop the cluster and destroy the containers. If you want to preserve the containers then use ``docker-compose stop``.

# Issues

## Update Sensitive Key

Need to create a random key and set it as the sensitive key. This is a new requirement for NiFi from 1.14.0.

````
echo $RANDOM|md5sum|head -c 20|tail -c 12;echo
3e38a10eb5fb
````

Add it to the compose file.

````
environment:
  ...
  - NIFI_SENSITIVE_PROPS_KEY=3e38a10eb5fb
````
