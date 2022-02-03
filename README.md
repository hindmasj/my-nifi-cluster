# my-nifi-cluster
Quick project to create a NiFi cluster in Docker

Inspired by article [Running a cluster with Apache Nifi and Docker](https://www.nifi.rocks/apache-nifi-docker-compose-cluster/) and shamelessly pinched their compose file, hence the Apache licence.

# Operation

## Start

To simply start the cluster up and connect to the NiFi desktop.

1. Start the cluster with ``docker compose up -d``. The cluster will start 3 NiFi nodes to hold a proper election for master.
1. Run ``./get-nifi-url.sh`` and note the URL that is returned. It will be something like *http\://localhost:\<port\>/nifi*.
1. Copy and paste that URL into your browser to connect to the NiFi desktop. On WSL you only need to hover over the URL and then *ctrl-click*.

What the "get" script does is run ``docker ps`` to get the port mappings from network 0.0.0.0 to port 8080 to one of those nodes. For example

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

Once connected to the GUI you can create your flows. To get you started their is a simple one stored under the templates directory. Load it from the NiFi desktop.

*right click* -> Upload Template -> *browse* -> "Simple_Kafka_Flow.xml" -> Upload

Then add the template onto the desktop from the design bar.

*drag template icon* -> Choose Template: "Simple_Kafka_Flow" -> Add

## Manage Kafka

### One Off Commands

You can run one-off Kafka commands by using the ``docker compose run <service> <...>`` command, which spins up a separate container using the same image but running the command. This however can be quite slow as you need to spin up the container for each single command.

After a while these containers accumulate, which you can see with ``docker compose ps -a``. If this becomes a problem then tidy them up with ``docker container prune``.

#### Start a Client Console

You can run ad hoc commands on a client container.

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

I have no name!@d2f135d230e4:/$ exit
exit
$
````

#### Run a Client Command

You can run specific scripts or commands that are already in container. Notice you can use the service alias "kafka" as shorthand for the first available kafka broker.

**Create a Topic**

````
$ docker compose run kafka kafka-topics.sh \
  --bootstrap-server kafka:9092 \
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
  --bootstrap-server kafka:9092 \
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

## Process Some Data

By now you should have loaded the flow into NiFi and set up the topics on Kafka. Now is the time to move data.

1. Start all of the processes in the flow by pressing the start button on the *Operate* dialogue.
1. Send a simple message to the source topic. (*ctrl-D* to end)
1. Observe the messages being processed in the flow.
1. Retrieve the message from the sink topic. (*ctrl-C* to end)

For a bit more fun you can run both Kafka commands in separate consoles and see each message flowing.

### Send Some Data

````
$ docker compose run kafka kafka-console-producer.sh \
 --bootstrap-server kafka:9092 --topic my.source.topic
>hello world
>now is the time
>one is the number
> ^D
````

### Receive Some Data

````
$ docker compose run kafka kafka-console-consumer.sh \
 --bootstrap-server kafka:9092 --topic my.sink.topic --offset earliest --partition 0
hello world
now is the time
one is the number
^C
````

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
