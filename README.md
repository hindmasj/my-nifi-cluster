# My NiFi Cluster

Quick project to create a NiFi cluster in Docker.

Inspired by article [Running a cluster with Apache Nifi and Docker](https://www.nifi.rocks/apache-nifi-docker-compose-cluster/) and shamelessly pinched their compose file, hence the Apache licence. Uses the [Apache NiFi Image](https://hub.docker.com/r/apache/nifi).

* [Installation](#installation)
* [Operation](#operation)
 * [Quickstart](#quickstart)
 * [Start](#start)
 * [Create Flows](#template)
 * [Manage Kafka](#kafka)
 * [Process Some Data](#process)
 * [Stop](#stop)
* [Registry](#registry)
* [Further Documents](#subdocs)

# <a name="installation"></a>Installation

Before starting you will need to create a new git repo to store the flows in. It is not a good idea to use this repo.

```
git init ../flow_storage
sudo chown -R 1000.1000 ../flow_storage
```

# <a name="operation"></a>Operation

## <a name="quickstart"></a>Quickstart

1. Start the cluster ``docker compose up -d``.
1. Create some topics ``bin/launch-script.sh``.
1. Get the cluster URL ``bin/get-nifi-url.sh``.
1. Post the URL in your browser.
1. Build some flows, process some data.

You might need to wait a minute from starting the cluster to using the URL, as it takes some time for all of the NiFi nodes to form a cluster.

See how to load flows from a [template](#template) or from the [NiFi registry](#registry). Then look at producing and consuming data with [Kafka](#process).

## <a name="start"></a>Start

To start the cluster up and connect to the NiFi desktop.

1. Start the cluster with ``docker compose up -d``. The cluster will start 3 NiFi nodes to hold a proper election for master.
1. Run ``bin/get-nifi-url.sh`` and note the URL that is returned. It will be something like *http\://localhost:\<port\>/nifi*.
1. Copy and paste that URL into your browser to connect to the NiFi desktop. On WSL you only need to hover over the URL and then *ctrl-click*.

What the "get" script does is run ``docker compose port nifi 8080`` to get one of the port mappings for the NiFi service, then extracts the port part to create a URL.

```
$ docker compose port nifi 8080
0.0.0.0:62142

$ bin/get-nifi-url.sh
http://localhost:62142/nifi
```

## <a name="template"></a>Create Flows

Once connected to the GUI you can create your flows. To get you started there is a simple one stored under the templates directory. Load it from the NiFi desktop.

&nbsp; &nbsp; *right click* -> Upload Template -> *browse* -> "Simple_Kafka_Flow.xml" -> Upload

Then add the template onto the desktop from the design bar.

&nbsp; &nbsp; *drag template icon* -> Choose Template: "Simple_Kafka_Flow" -> Add

## <a name="kafka"></a>Manage Kafka

### One Off Commands

You can run one-off Kafka commands by using the ``docker compose run <service> <...>`` command, which spins up a separate container using the same image but running the command. This however can be quite slow as you need to spin up the container for each single command.

After a while these containers accumulate, which you can see with ``docker compose ps -a``. If this becomes a problem then tidy them up with ``docker container prune``.

#### Start a Client Console

You can run ad hoc commands on a client container.

```
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
```

#### Run a Client Command

You can run specific scripts or commands that are already in container. Notice you can use the service alias "kafka" as shorthand for the first available kafka broker.

**Create a Topic**

```
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
```

**Describe a Topic**

```
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
```

### Running Scripts

You can use the run command to also mount a local directory and then run any scripts that might be in there. Note that the paths must be absolute.

```
docker compose run --volume <path-to-mount>:<mount-point> kafka <mount-point>/<script-name>
```

See the scripts *bin/launch-script.sh* and *bin/create-topics.sh* to see an example of how this is done.

## <a name="process"></a>Process Some Data

By now you should have loaded the flow into NiFi and set up the topics on Kafka. Now is the time to move data.

1. Start all of the processes in the flow by pressing the start button on the *Operate* dialogue.
1. Send a simple message to the source topic. (*ctrl-D* to end)
1. Observe the messages being processed in the flow.
1. Retrieve the message from the sink topic. (*ctrl-C* to end)

For a bit more fun you can run both Kafka commands in separate consoles and see each message flowing.

### Send Some Data

```
$ docker compose run kafka kafka-console-producer.sh \
 --bootstrap-server kafka:9092 --topic my.source.topic
>hello world
>now is the time
>one is the number
> ^D
```

As this is so useful you can launch it with ``bin/launch-script.sh producer``.

### Receive Some Data

```
$ docker compose run kafka kafka-console-consumer.sh \
 --bootstrap-server kafka:9092 --topic my.sink.topic --offset earliest --partition 0
hello world
now is the time
one is the number
^C
```
As this is so useful you can launch it with ``bin/launch-script.sh consumer``.

## <a name="stop"></a>Stop

Simply ``docker compose down`` to stop the cluster and destroy the containers. If you want to preserve the containers then use ``docker compose stop``.

# <a name="registry"></a>Using the Registry

A NiFi registry service has been added to make persistence of flows easier than having to use the template method.

Connect to the registry GUI with http://localhost:18080/nifi-registry.

## First Time

The first time you use the registry you need to set up the bucket, and optionally put a flow into it. This is a manual process.

1. In registry click the wrench then create a new bucket.
1. In NiFi use the menu "Controller Settings" -> "Registry Clients".
1. Add a new client with URL "`http://registry:18080/`".
1. On the desktop create a processor group.
1. Inside the group, drag in the template for the test flow.
1. On the background, right click and select "Version" -> "Start version control".
1. In the dialogue give the flow a name and click save.

You will see that the test bucket and the flow snapshot have been created in the git repo.

## Afterwards

Once the registry has been set up, any flows created will get stored in the local git repo, giving you persistence. If you restart the cluster you will see in the registry that your flow definitions have been preserved.

On NiFi you still need to create the registry client link as described above to "`http://registry:18080/`". Then import the flow onto the desktop.

1. Drag a process group from the design bar onto the desktop.
1. Click "Import from Registry".
1. Select the bucket, flow and version you want.
1. Click "Import".

# <a name="subdocs"></a>More

To simplify the documentation, further sections have been moved to separate documents under the "docs" directory.

* [Custom Processors](docs/custom_processors.md)
* [Issues](docs/issues.md)
* [Experiments](docs/experiments.md)
  * [Standard Processors](docs/experiment-standard_processors.md)
  * [Using Tab Separation](docs/experiment-tab_separation.md)
  * [Convert To ECS](docs/experiment-convert_to_ecs.md)
  * [Enrich From Redis](docs/experiment-enrich_from_redis.md)
  * [Write To Redis](experiment-write_to_redis.md)
  * [Some Specific Transform Cases](experiment-some_specific_transform_cases.md)
  * [Unpacking Lookups](experiment-unpacking_lookups.md)
  * [Fork / Join Enrichment](experiment-fork_join_enrichment.md)
  * [Grok Filtering](experiment-grok_filtering.md)
