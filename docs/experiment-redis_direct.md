### [Home](../README.md) | [Up](experiments.md) | [Prev (Grok Filtering)](experiment-grok_filtering.md)
---

# Running Redis Commands Within NiFi

Being able to set and retrieve values from a single is ok, but sometimes you need to get more out of Redis, like a list of keys that match a pattern. Here we get a list of all keys, then look them all up.

## Preparation - Install Redis Tools

You need to install the package *redis-tools*. The script ``bin/install-redis-tools.sh`` will do this for you.

## Services

### CSV Reader

* Schema Access Strategy = Use Schema Text Property
* Schema Text = ${avro.schema}

### Others

As previously described, you also need

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

* Command Arguments = ``-a nifi_redis -h redis keys *``
* Command Path = ``redis-cli``
* Ignore STDIN = true
* Argument Delimiter = <space>

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

Running the lookup will not only retrieve the values but will convert the whole flow file into JSON.

```
[ {
  "key" : "bar",
  "value" : "abc"
}, {
  "key" : "foo",
  "value" : "hello world"
} ]
```

---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Grok Filtering)](experiment-grok_filtering.md)
