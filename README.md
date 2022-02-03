# my-nifi-cluster
Quick project to create a NiFi cluster in Docker

Inspired by article [Running a cluster with Apache Nifi and Docker](https://www.nifi.rocks/apache-nifi-docker-compose-cluster/) and shamelessly pinched their compose file, hence the Apache licence.

# Operation

## Start

To simply start the cluster up and connect to the NiFi desktop.

1. Start the cluster with ``docker compose up -d``. The cluster will start 3 NiFi nodes to hold a proper election for master.
1. Run ``docker ps`` to get the port mappings from network 0.0.0.0 to port 8080 to one of those nodes.
1. Connect to the web server at *http\://localhost:\<port\>/nifi*.

For example

````
$ docker compose ps
NAME                     COMMAND                  SERVICE             STATUS              PORTS
my-nifi-cluster-nifi-1   "../scripts/start.sh"    nifi                running             0.0.0.0:64009->8080/tcp
my-nifi-cluster-nifi-2   "../scripts/start.sh"    nifi                running             0.0.0.0:64008->8080/tcp
my-nifi-cluster-nifi-3   "../scripts/start.sh"    nifi                running             0.0.0.0:64007->8080/tcp
zookeeper                "/opt/bitnami/script…"   zookeeper           running             8080/tcp
````

Then the bit you want is: ``my-nifi-cluster-nifi-1 ... 0.0.0.0:61892->8080/tcp`` and you need port 61892.

## Create Flows

Once connected to the GUI you can create your flows. To get you started their is a simple stored under the templates directory. Load it from NiFi desktop.

*right click* -> Upload Template -> *browse* -> "Simple_Kafka_Flow.xml" -> Upload

Then add the template onto the desktop from the design bar.

*drag template icon* -> Choose Template: "Simple_Kafka_Flow" -> Add

## Manage Kafka

### One Off Commands

You can run one-off Kafka commands by using the ``docker compose run <service> <...>`` command, which spins up a separate container using the same image but running the command. This however is quite slow as you need to spin up the container for each single command.

**Start a Client Console**
````
$ docker compose run kafka bash
[+] Running 1/0
 ⠿ Container zookeeper Running 0.0s
kafka 09:24:44.07
kafka 09:24:44.07 Welcome to the Bitnami kafka container
kafka 09:24:44.08 Subscribe to project updates by watching https://github.com/bitnami/bitnami-docker-kafka
kafka 09:24:44.08 Submit issues and feature requests at https://github.com/bitnami/bitnami-docker-kafka/issues
kafka 09:24:44.08

I have no name!@d2f135d230e4:/$ echo $PATH
/opt/bitnami/kafka/bin:/opt/bitnami/java/bin:/opt/bitnami/java/bin:/opt/bitnami/common/bin:/opt/bitnami/kafka/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

I have no name!@d2f135d230e4:/$ ls /opt/bitnami/kafka/bin
connect-distributed.sh        kafka-console-consumer.sh    ...

I have no name!@7e44e251ba32:/$ exit
exit
$
````

**Create a Topic**
````
$ docker compose run kafka kafka-topics.sh \
  --bootstrap-server my-nifi-cluster-kafka-1:9092 \
  --create --topic my.source.topic \
  --replication-factor 3 --config retention.ms=36000000

[+] Running 1/0
⠿ Container zookeeper Running 0.0s
kafka 09:43:21.17
kafka 09:43:21.18 Welcome to the Bitnami kafka container
kafka 09:43:21.18 Subscribe to project updates by watching https://github.com/bitnami/bitnami-docker-kafka
kafka 09:43:21.18 Submit issues and feature requests at https://github.com/bitnami/bitnami-docker-kafka/issues
kafka 09:43:21.19

WARNING: Due to limitations in metric names, topics with a period ('.') or underscore ('_') could collide. To avoid issues it is best to use either, but not both.
Created topic my.source.topic.
````

**Describe a Topic**
````
$ docker compose run kafka kafka-topics.sh \
  --bootstrap-server my-nifi-cluster-kafka-1:9092 \
  --describe --topic my.source.topic

[+] Running 1/0
⠿ Container zookeeper Running 0.0s
kafka 09:45:45.41
kafka 09:45:45.41 Welcome to the Bitnami kafka container
kafka 09:45:45.42 Subscribe to project updates by watching https://github.com/bitnami/bitnami-docker-kafka
kafka 09:45:45.42 Submit issues and feature requests at https://github.com/bitnami/bitnami-docker-kafka/issues
kafka 09:45:45.42

Topic: my.source.topic  TopicId: ou824ZiQRo-gELS07nh3mg PartitionCount: 1       ReplicationFactor: 3    Configs: segment.bytes=1073741824,retention.ms=36000000
        Topic: my.source.topic  Partition: 0    Leader: 1001    Replicas: 1001,1003,1002        Isr: 1001,1003,1002
````

### Running Scripts

You can use the run command to also mount a local directory and then run any scripts that might be in there. Note that the paths must be absolute.

````
docker compose run --volume <path-to-mount>:<mount-point> kafka <mount-point>/<script-name>
````

See the scripts *launch-script.sh* and *create-topics.sh* to see an example of how this is done.

## Stop

Simply ``docker compose down`` to stop the cluster and destroy the containers. If you want to preserve the containers then use ``docker compose stop``.

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

## Fix Scaling To Automatic

Original start command included ``--scale nifi=3`` but this is clumsy and I want 3 nodes by default. Added the deploy section to set this up.

````
deploy:
  mode: replicated
  replicas: 3
````

## Adding Kafka Cluster

Use the [bitnami](https://bitnami.com/stack/kafka/containers) image, as we are already using their zookeeper image.
