### [Home](../README.md) | [Up](experiments.md) | [Prev (Grok Filtering)](experiment-grok_filtering.md)
---

# Running Redis Commands Within NiFi

Being able to set and retrieve values from a single key is ok, but sometimes you need to get more out of Redis, like a list of keys that match a pattern. Here we get a list of all keys, then look them all up.

## Preparation - Install Redis Tools

You need to install the package *redis-tools* to obtain the *redis-cli* application.

In this cluster you can use the script ``bin/install-redis-tools.sh`` but in fact this package was added to the image. In order to rebuild the image do the following.

```
docker pull apache/nifi
docker compose build
```

You can register your copy of the image with the docker registry if you have a registry account. You can view your images from the Docker Desktop opening the "Images" menu and clicking the "Hub" tab.

```
docker login --username <username>
docker image tag my-nifi-cluster-nifi:latest <username>/nifi
docker push <username>/nifi
```

## Services

### CSV Reader

Use the CSV reader to parse the command response.

* Schema Access Strategy = Use Schema Text Property
* Schema Text = ${avro.schema}

### Others

As [previously described](experiment-enrich_from_redis.md), you also need these services to perform a Redis lookup.

* InheritJsonRecordSetWriter
* RedisConnectionPoolService
* RedisDistributedMapCacheClientService
* DistributedMapCacheLookupService

## Processors

### GenerateFlowFile

* Scheduling: Execution = Primary Node
* avro.schema =

```
{
  "type": "record",
  "name": "keys",
  "fields": [
    {"name":"key","type":"string"}
  ]
}
```

### ExecuteStreamCommand
Execute the *redis-cli* command. The *ExecuteStreamCommand* processor behave just as if you were working on the command line.

* Command Arguments = ``-a nifi_redis -h redis keys *``
* Command Path = ``redis-cli``
* Ignore STDIN = true
* Argument Delimiter = &lt;space&gt;

### Lookup Record

* Record Reader = CSVRecordReader
* Record Writer = InheritJsonRecordSetWriter
* Lookup Service = DistributedMapCacheLookupService
* Result Record Path = /value
* key = /key

## Execution

### Create Data

Use the redis command line to create some Redis values, e.g.

```
set foo "hello world"
set bar 'abc'
```

### Extract Keys

After running the Generate and Execute the flow file will contain the list of keys.

```
foo
bar
```

### Lookup Keys

Running the Lookup will not only retrieve the values but will convert the whole flow file into JSON.

```
[ {
  "key" : "bar",
  "value" : "abc"
}, {
  "key" : "foo",
  "value" : "hello world"
} ]
```

## Getting Input From The Flowfile

You can use the flow file to provide the Redis script, by making the following changes.

### GenerateFlowFile

* Custom Text = ``keys *``

### ExecuteStreamCommand

Here the command uses the flowfile contents as STDIN.

* Command Arguments = ``-a nifi_redis -h redis``
* Ignore STDIN = false

Then executing the command will give the same results as before. By using this method you could put any arbitrary script into the flowfile for processing.

---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Grok Filtering)](experiment-grok_filtering.md)
