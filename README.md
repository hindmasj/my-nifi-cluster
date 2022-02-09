# my-nifi-cluster
Quick project to create a NiFi cluster in Docker

Inspired by article [Running a cluster with Apache Nifi and Docker](https://www.nifi.rocks/apache-nifi-docker-compose-cluster/) and shamelessly pinched their compose file, hence the Apache licence. Uses the [Apache NiFi Image](https://hub.docker.com/r/apache/nifi).

# Installation

Before starting you will need to create a new git repo to store the flows in. It is not a good idea to use this repo.

````
git init ../flow_storage
sudo chown -R 1000.1000 ../flow_storage
````

# Operation

## Quickstart

1. Start the cluster ``docker compose up -d``.
1. Create some topics ``./launch-script.sh``.
1. Get the cluster URL ``./get-nifi-url.sh``.
1. Post the URL in your browser.
1. Build some flows, process some data.

See how to load flows from a [template](#template) or from the [NiFi registry](#registry). Then look at producing and consuming data with [Kafka](#process).

## Start

To start the cluster up and connect to the NiFi desktop.

1. Start the cluster with ``docker compose up -d``. The cluster will start 3 NiFi nodes to hold a proper election for master.
1. Run ``./get-nifi-url.sh`` and note the URL that is returned. It will be something like *http\://localhost:\<port\>/nifi*.
1. Copy and paste that URL into your browser to connect to the NiFi desktop. On WSL you only need to hover over the URL and then *ctrl-click*.

What the "get" script does is run ``docker compose port nifi 8080`` to get one the port mappings for the NiFi service, then extracts the port part to create a URL.

````
$ docker compose port nifi 8080
0.0.0.0:62142

$ ./get-nifi-url.sh
http://localhost:62142/nifi
````

## <a name="template"></a>Create Flows

Once connected to the GUI you can create your flows. To get you started there is a simple one stored under the templates directory. Load it from the NiFi desktop.

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

## <a name="process"></a>Process Some Data

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

# <a name="registry"></a>Using the Registry

A NiFi registry service has been added to make persistence of flows easier than having to use the template method.

Connect to the registry GUI with http://localhost:18080/nifi-registry.

## First Time

The first time you use the registry you need to set up the bucket, and optionally put a flow into it. See [Connect Cluster to Registry](#cctr).

## Afterwards

Once the registry has been set up, any flows created will get stored in the local git repo, giving you persistence.

If you restart the cluster you will see in the registry that your flow definitions have been preserved.

On NiFi you need to create the registry client as described previously. Then import the flow onto the desktop.

1. Drag a process group from the design bar onto the desktop.
1. Click "Import from Registry".
1. Select the bucket, flow and version you want.
1. Click "Import".

# Custom Processors

See the [NiFi Admin Guide](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#processor-locations) for details of where to put custom processor NARs. See the "Issues" section further down to see discussion of what has been done.

Use the docker copy command to put your custom processor NAR files into the automatic library directory, which is */opt/nifi/nifi-current/extensions/*.

```
docker compose cp <path-to-nar-file> nifi:/opt/nifi/nifi-current/extensions/
```

Note that the NAR must have been compiled under Java 1.8.0.

## Text Approval Processor

There is a maven project included which creates a very simple processor which just add the phrase "APPROVED" to the end of any message it sees in the flow.

Build the project with ``mvn clean package`` and this produces a NAR file *target/nifi-&lt;version&gt;.nar* which can then be loaded into the cluster as outlined above. 

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

## Adding NiFi Registry

Use the [Apache](https://hub.docker.com/r/apache/nifi-registry) image. Tasks are as follows. Using the [guide](https://nifi.apache.org/docs/nifi-registry-docs/index.html).

1. Connect cluster to registry.
2. Connect registry to a git instance.

### <a name="cctr">Connect Cluster to Registry</a>

This seems to be manual from the NiFi desktop. Note you cannot register processors or the whole system, only processor groups.

1. In registry click the wrench then create a new bucket.
1. In NiFi use the menu "Controller Settings" -> "Registry Clients".
1. Add a new client with URL "http://registry:18080".
1. On the desktop create a processor group.
1. Inside the group, drag in the template for the test flow.
1. On the background, right click and select "Version" -> "Start version control".
1. In the dialogue give the flow a name and click save.

You will see that the test bucket and the flow snapshot have been created in the git repo.

### Connect to Git

There is a file called *providers.xml* in */opt/nifi-registry/nifi-registry-current/conf*. This has the settings for a Git provider commented out. Use the configs option to remount a local file.

This then needs to connect into a local git repo, not this one in case you do not want to share your work to GitHub. So create a parallel repo called "flow_storage". Which then means mounting that repo into the registry service container. The repo also needs permissions set for others to write. As the image causes all actions to be run by user 1000, just change the UID and GID.

```
git init flow_storage
chown -R 1000.1000 flow_storage
```

## Custom Processors

Tried to create a custom processor directory by setting the property *nifi.nar.library.directory.&lt;label&gt;*.

First attempt was to set an environment variable "NIFI_NAR_LIBRARY_DIRECTORY_CUSTOM", and then create a volume to match the value. The volume was mounted but the ENV did not take affect, so the contents were never loaded.

Then looked at using a config setting to map a local copy of *nifi.properties* onto the one inside the container. But this failed because it seems NiFi rewrites the property file after gathering all the ENVs. This failed as the config method mounts the file read only.

So the next best option seems to be to copy any files to the autoload directory, *${NIFI_HOME}/extensions*, and have the nodes load the NAR in life.

The other option might be to use either config or volume options to load individual NAR files into the standard library directory, *${NIFI_HOME}/lib*. But this will involve changing the *docker-compose.yml* file.

BTW, the image seems to only have Java 1.8.0 installed, and the processors I had to hand would only compile under 11, so the test involves looking for the error message in nifi-app.log.
