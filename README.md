# My NiFi Cluster
Quick project to create a NiFi cluster in Docker

Inspired by article [Running a cluster with Apache Nifi and Docker](https://www.nifi.rocks/apache-nifi-docker-compose-cluster/) and shamelessly pinched their compose file, hence the Apache licence. Uses the [Apache NiFi Image](https://hub.docker.com/r/apache/nifi).

# Installation

Before starting you will need to create a new git repo to store the flows in. It is not a good idea to use this repo.

```
git init ../flow_storage
sudo chown -R 1000.1000 ../flow_storage
```

# Operation

## Quickstart

1. Start the cluster ``docker compose up -d``.
1. Create some topics ``bin/launch-script.sh``.
1. Get the cluster URL ``bin/get-nifi-url.sh``.
1. Post the URL in your browser.
1. Build some flows, process some data.

You might need to wait a minute from starting the cluster to using the URL, as it takes some time for all of the NiFi nodes to form a cluster.

See how to load flows from a [template](#template) or from the [NiFi registry](#registry). Then look at producing and consuming data with [Kafka](#process).

## Start

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

## Manage Kafka

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

## Stop

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

# Custom Processors

See the [NiFi Admin Guide](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#processor-locations) for details of where to put custom processor NARs. See the "Issues" section further down to see discussion of what has been done.

Use the docker copy command to put your custom processor NAR files into the automatic library directory, which is */opt/nifi/nifi-current/extensions/*. Make sure to use the *--all* flag to ensure the file is copied to all of the NiFi containers.

```
docker compose cp --all <path-to-nar-file> nifi:/opt/nifi/nifi-current/extensions/
```

Note that for these docker images the NAR must have been compiled under Java 1.8.0. Refresh the NiFi GUI in your browser before trying to use the new processor.

If you try to load the processor **again**, then you will need to restart the NiFi service, as the class loaders will not load an existing class.

```
docker compose restart nifi
```

## Text Approval Processor

There is a maven project included which creates a very simple processor which just add the phrase "APPROVED" to the end of any message it sees in the flow.

Build the project with ``mvn clean package`` and this produces a NAR file *archiver/target/nifi-hindmasj-processors-&lt;version&gt;.nar* which can then be loaded into the cluster as outlined above.

# Issues

## Update Sensitive Key

Need to create a random key and set it as the sensitive key. This is a new requirement for NiFi from 1.14.0.

```sh
echo $RANDOM|md5sum|head -c 20|tail -c 12;echo
3e38a10eb5fb
```

Add it to the compose file.

```yaml
environment:
  ...
  - NIFI_SENSITIVE_PROPS_KEY=3e38a10eb5fb
```

## Fix Scaling To Automatic

Original start command included ``--scale nifi=3`` but this is clumsy and I want 3 nodes by default. Added the deploy section to set this up.

```yaml
deploy:
  mode: replicated
  replicas: 3
```

## Adding Kafka Cluster

Use the [bitnami](https://bitnami.com/stack/kafka/containers) image, as we are already using their zookeeper image.

## Adding NiFi Registry

Use the [Apache](https://hub.docker.com/r/apache/nifi-registry) image. Tasks are as follows. Using the [guide](https://nifi.apache.org/docs/nifi-registry-docs/index.html).

1. Connect cluster to registry.
2. Connect registry to a git instance.

### <a name="cctr">Connect Cluster to Registry</a>

This seems to be manual from the NiFi desktop. Note you cannot register processors or the whole system, only processor groups.

### Connect to Git

There is a file called *providers.xml* in */opt/nifi-registry/nifi-registry-current/conf*. This has the settings for a Git provider commented out. Use the configs option to remount a local file.

This then needs to connect into a local git repo, not this one in case you do not want to share your work to GitHub. So create a parallel repo called "flow_storage". Which then means mounting that repo into the registry service container. The repo also needs permissions set for others to write. As the image causes all actions to be run by user 1000, just change the UID and GID.

```
git init flow_storage
chown -R 1000.1000 flow_storage
```

## Custom Processors

### Loading The Processor

As the NiFi process has already started by the time you get to copy a file to the lib directory, I needed to find a way to copy the NAR file in and have it picked up by the JVM without restarting the cluster.

Tried to create a custom processor directory by setting the property *nifi.nar.library.directory.&lt;label&gt;*.

First attempt was to set an environment variable "NIFI_NAR_LIBRARY_DIRECTORY_CUSTOM", and then create a volume to match the value. The volume was mounted but the ENV did not take affect, so the contents were never loaded.

Then looked at using a config setting to map a local copy of *nifi.properties* onto the one inside the container. But this failed because it seems NiFi rewrites the property file after gathering all the ENVs. This failed as the config method mounts the file read only.

So the next best option seems to be to copy any files to the autoload directory, *${NIFI_HOME}/extensions*, and have the nodes load the NAR in life.

The other option might be to use either config or volume options to load individual NAR files into the standard library directory, *${NIFI_HOME}/lib*. But this will involve changing the *docker-compose.yml* file.

BTW, the image seems to only have Java 1.8.0 installed, and the processors I had to hand would only compile under 11, so the test involves looking for the error message in nifi-app.log.

Late breaking brainwave: load the NAR into lib directory, then restart the NiFi service. The file will be preserved, as will any flows and the link to the registry.

No, it was because it was not being copied to all containers. You have to use ``--all``.

**Summary**

1. If you copy the file into the extensions directory it will get loaded into the live node, but you need to use the *--all* flag to ensure the file gets copied to all nodes.
1. If you need to overwrite the file then the class loaders will not load same classes again. In this case you need to restart the NiFi service, **after** the copy, with ``docker compose restart nifi``.
1. If you are going to do a restart anyway then you do other things, like load a new config file or push the NAR file to the lib directory.

### Indexing The Processor

As it first appeared in the index of processors, my custom processor did not have a domain name or version number when it appeared in the list.

Looking at this article in medium, [Creating Custom Processors and Controllers in Apache NiFi](https://medium.com/hashmapinc/creating-custom-processors-and-controllers-in-apache-nifi-e14148740ea) to see if there are any clues. It uses a Maven archetype to generate the application layout, so I can check the POM file for any clues. Also see this article: [NiFi NAR Files Explained](https://medium.com/hashmapinc/nifi-nar-files-explained-14113f7796fd).

Following the article I created the directory structure for the project *nifi-fred* and ran ``mvn package``, and the build almost completed, but failed packaging because of an enforcer error.

```
[INFO] --- maven-enforcer-plugin:3.0.0:enforce (enforce-no-snapshots) @ nifi-fred-nar ---
[WARNING] Rule 0: org.apache.maven.plugins.enforcer.RequireReleaseDeps failed with message:
Other than org apache nifi components themselves no snapshot dependencies are allowed
Found Banned Dependency: io.github.hindmasj:nifi-fred-processors:jar:0.0.1-SNAPSHOT
```

I have seen this before and can be solved by turning off enforcement in the archiver POM file, *nifi-fred-nar/pom.xml*.

```xml
<build>
  <pluginManagement>
    <plugins>

      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-enforcer-plugin</artifactId>
        <configuration>
          <skip>true</skip>
        </configuration>
      </plugin>

    </plugins>
  </pluginManagement>
</build>
```

So what are the differences? When I load both NARs into NiFi, the archetype one gets the right version and source group, but my local one is listed in the default source and shows up as "unversioned".

In the root POM, the archetype has a parent setting, as follows.

```xml
<parent>
    <groupId>org.apache.nifi</groupId>
    <artifactId>nifi-nar-bundles</artifactId>
    <version>1.15.3</version>
</parent>
```

The archiver POM does not refer to the *nifi-nar-maven-plugin* plugin, but inherits this plugin from the above parent.

So, step one, try this ... and that was the answer.

The archetype has some extra dependencies for the processor, and an example unit test class, so that will be adopted too.

## QueryRecord On Union Field

With a schema like this

```
{
  "type":"record",
  "namespace":"blah",
  "name":"SimpleTraffic",
  "fields":[
    {"name":"src_address","type":"string"},
    {"name":"flag_s","type":["int","boolean"]}
  ]
}
```

and a record like this ``[{"src_address":"192.168.0.1","flag_s":true}]``, I want to filter out only those records which are true. So I create a QueryRecord and use this query ``select * from flowfile where flag_s = true``.

But all I get is

```
org.apache.calcite.sql.validate.SqlValidatorException: Cannot apply '=' to arguments of type '<JAVATYPE(CLASS JAVA.LANG.OBJECT)> = <BOOLEAN>'.
```

Which looks to me like I cannot use a union type in a query. So I had to make a distinction between a raw and enriched schema and had to create new JSON reader and writer services.

# Flow Experiment - Standard Processors

In order to ensure this flow works as documented you may need to checkout the [Simple Traffic Example tag (v1.0.0)](https://github.com/hindmasj/my-nifi-cluster/tree/v1.0.0) as some of the supporting files change to accommodate the later experiments.

Created a little task to convert a CSV file to JSON, then manipulate it. Start with the "simple-traffic" sample files. If there is a "failure" relationship in any of the processors then connect it to the log on failure process.

## Services

Create the following services.

### Avro Schema Registry

Create new parameters called "raw-traffic" and "enriched-traffic". Copy the files "raw-traffic.schema" and "enriched-traffic.schema" respectively as the values.

### CSV Reader

Using the magic to enter a new line in record separator solved my initial problem.

* Schema Access Strategy = Use Schema Property Name
* Schema Registry = Avro Schema Registry
* Schema Name = ${schema.raw}
* Record Separator = Shift+Enter
* Value Separator = ,
* Treat First Line As Header = false

### Json Record Set Writer

Create two. Name one as "RawJsonRecordSetWriter" and the other "Enriched...".

* Schema Access Strategy = Use Schema Property Name
* Schema Registry = Avro Schema Registry
* Schema Name = ${schema.raw} or ${schema.enriched}

### JSON Tree Reader

Create two. Name one as "Raw..." and the other as "Enriched...".

* Schema Access Strategy = Use Schema Property Name
* Schema Registry = Avro Schema Registry
* Schema Name = ${schema.raw} or ${schema.enriched}

## Processors

Start with the Consume Kafka from the sample and end with the Publish Kafka and Log Message processors. In the Consume Kafka service set the "Message Demarcator" to a newline by entering 'Shift+Enter'. Then put these new processors in between.

### UpdateAttribute

Tell the flow which schemas we are using.

* schema.enriched = enriched-traffic
* schema.raw = raw-traffic

### Convert Record

Convert the CSV input records into the matching JSON schema.

* Record Reader = CSVReader
* Record Writer = RawJsonRecordSetWriter

### Update Record

Change those 0 and 1 values for the flags to false or true respectively. Note that each parameter is a path to a field in the record and must start with "/". The reader here uses the raw schema but the writer converts the data to the enriched schema.

* Record Reader = RawJsonTreeReader
* Record Writer = EnrichedJsonRecordSetWriter
* Replacement Value Strategy = Literal Value
* /flag_s = ${field.value:equals(1)}
* /flag_a = ${field.value:equals(1)}
* /flag_f = ${field.value:equals(1)}

### Query Record

Get rid of that useless record where TCP is set but there are no flags set. Create a QueryRecord processor, which allows queries written in [Calcite SQL](https://calcite.apache.org/docs/reference.html) to create new flows directed at new relationships.

* Record Reader = EnrichedJsonTreeReader
* Record Writer = EnrichedJsonRecordSetWriter
* Include Zero Record FlowFiles = false
* filtered = See below

Connect the relationship "filtered" to the Kafka publisher. Select the relationship "original" to be terminated in the processor. Route "failure" to the error logger as all above.

The query to use is

```
select *
from flowfile
where transport_protocol <> 6
or (flag_s or flag_a or flag_f)
```

# Flow Experiment - Convert To ECS

Prior to working on an enrichment flow, this flow solves the problems of mapping the raw fields to a schema that is more complex. The idea is to make space in the schema for transformations and additions further downstream. Here the enriched schema tries to follow the [Elastic Common Schema](https://www.elastic.co/guide/en/ecs/current/index.html) guidelines. The [CSV of fields](https://github.com/elastic/ecs/blob/8.1/generated/csv/fields.csv) file is a useful quick lookup source.

The enrichment process will seek to add more details about the transport protocol and the port services.

## Schema Changes

### Raw

The union type (int or boolean) for each of the flags is restored, so that the Update Record process can fix up the flag values before going through the Jolt process.

### Enriched

A new enrichment schema is created, specifically for ECS compatibility.

See the [Avro Specification](https://avro.apache.org/docs/current/spec.html) and this [stackoverflow article](https://stackoverflow.com/questions/43513140/avro-schema-format-exception-record-is-not-a-defined-name) for more information about nested schemas.

The following mappings are made. The ECS recommendation to capitalise custom fields is used here.

* src_address -> source.ip & source.address
* src_address -> source.port
* dst_address -> destination.ip & destination.address
* dst_port -> destination.port
* ip_version -> network.type & network.Type_id
* transport_protocol -> network.iana_number
* flag_s -> network.Flags.SYN
* flag_a -> network.Flags.ACK
* flag_f -> network.Flags.FIN

New fields that might be used later are also added, to see what the effect on processing is.

* source.Service
* destination.Service
* network.application
* network.protocol
* network.transport

This is captured in *ecs-enriched-traffic.schema*. Add it to the Avro Schema Registry as `ecs-enriched-traffic`. Change the Update Attribute processor to use the new schema by changing the value of *enriched.schema* to `ecs-enriched-traffic`.

## Field Mapping

### Update Record

Change the JSON Tree writer from the enriched one to the raw one. Schema transformations are now carried out in Jolt. The flag transformation properties stay the same.

### Jolt Transform

Insert a Jolt transform between the update and the query. This processor turns each record from the raw schema format to the ECS enriched one.

```
[{
	"operation": "shift",
	"spec": {
		"*": {
			"src_address": ["[&(1)].source.ip","[&(1)].source.address"],
			"src_port": "[&(1)].source.port",
			"dst_address": ["[&(1)].destination.ip","[&(1)].destination.address"],
			"dst_port": "[&(1)].destination.port",
			"ip_version": "[&(1)].network.Type_id",
			"transport_protocol": "[&(1)].network.iana_number",
          	"flag_s": "[&(1)].network.Flags.SYN",
          	"flag_a": "[&(1)].network.Flags.ACK",
          	"flag_f": "[&(1)].network.Flags.FIN"
		}
	}
},
{
   "operation":"modify-overwrite-beta",
   "spec": {
     "*": {
       "network": {
         "type": "=concat('ipv',@(1,Type_id))"
       }
     }
   }
 }]
```

Note the kludge to convert IP version number to the type string.

### Query Record

Change the query to reflect the new schema. Each field now needs to use an RPath to find each field. Booleans also need to be cast as RPath returns a string.

```
select *
from flowfile
where rpath(network,'/iana_number') <> 6
or cast(rpath(network,'/Flags/SYN') as boolean)
or cast(rpath(network,'/Flags/ACK') as boolean)
or cast(rpath(network,'/Flags/FIN') as boolean)
```

An alternative might have been to do the filter further up the flow when the content was still in the raw format, but then this would have hit upon the problem where the raw schema includes union types which Calcite cannot read. See in Issues section above.
