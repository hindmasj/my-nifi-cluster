### [Home (README.md)](../README.md)
---

# Issues

# Installation

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

# Custom Processors

## Loading The Processor

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

## Indexing The Processor

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

# Flows

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

Tried a cast but I get this error.

```
org.apache.calcite.sql.validate.SqlValidatorException: Cast function cannot convert value of type JavaType(class java.lang.Object) to type BOOLEAN
```

**TIP**: To get at recent error messages have a look at the bulletin board API: ``http://<host>:<port>/nifi-api/flow/bulletin-board``.

**Solution**: See [Flow Experiment - Convert To ECS](experiment-convert_to_ecs.md). There are 2 processors: a QueryRecord to filter and convert from CSV to JSON, and a JoltTransformJSON to fix up the boolean flags and change the schema.

## <a name="redis-lookup-returns-string"></a>Redis Lookup Only Returns String

I can create a Redis record using the pipe protocol.

```
*3
$3
SET
$10
protocol.6
$79
{"name":"tcp","code":6,"alias":"TCP","comment":"transmission control protocol"}
```

which in Redis looks like this.

```
get protocol.6
"{\"name\":\"tcp\",\"code\":6,\"alias\":\"TCP\",\"comment\":\"transmission control protocol\"}"
```

When I retrieve the string, it gets treated like a string, not a record.

```
"Enrichment" : {
  "Network" : {
    "Transport" : "{\"name\":\"tcp\",\"code\":6,\"alias\":\"TCP\",\"comment\":\"transmission control protocol\"}"
  }
}
```

If I try to unencode it with an UpdateRecord it gets transformed into a string.

```
/Enrichment/Network/transport = unescapeJson(/Enrichment/Network/Transport)
```

```
"Enrichment" : {
  "Network" : {
    "iana_number" : 6,
    "Transport" : "{\"name\":\"tcp\",\"code\":6,\"alias\":\"TCP\",\"comment\":\"transmission control protocol\"}",
    "transport" : "{name=tcp, code=6, alias=TCP, comment=transmission control protocol}"
  }
}
```

So the issue is, how can this string be converted to JSON? Either it needs some complex regexes, or a custom processor beckons.

## <a name="lookup_ignores"></a>Lookup Ignores All If First Record Not Matched

See the flow setup in [Writing To Redis](experiment-write_to_redis.md).

Create a simple lookup record processor.

* Result RecordPath = /mood
* Routing Strategy = Route To Success
* key = concat('mood/',name)

Create a sample flow file.

```
[{"name":"fred"},{"name":"bill"},{"name":"charlie"}]
```

Create these keys.

```
set mood/fred happy
set mood/charlie sad
```

Result is

```
[{"name":"fred","mood":"happy"},{"name":"bill","mood":null},{"name":"charlie","mood":"sad"}]
```

Now try this flow.

```
[{"name":"bill"},{"name":"fred"},{"name":"charlie"}]
```

Result

```
[{"name":"bill"},{"name":"fred"},{"name":"charlie"}]
```

Oops, where did my lookups go?

Add this key.

```
set mood/bill neutral
```

Result is
```
[{"name":"bill","mood":"neutral"},{"name":"fred","mood":"happy"},{"name":"charlie","mood":"sad"}]
```

Change the routing strategy to "Route to matched or unmatched", unset that key for Bill, and try again.

```
matched queue -> [{"name":"fred","mood":"happy"},{"name":"charlie","mood":"sad"}]

unmatched queue -> [{"name":"bill"}]
```

---
### [Home (README.md)](../README.md)
