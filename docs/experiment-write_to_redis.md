### [Home](../README.md) | [Up](experiments.md) | [Prev (Enrich From Redis)](experiment-enrich_from_redis.md)
---

# Flow Experiment - Write To Redis

This experiment develops a flow that can write JSON data to a Redis index.

The flow uses a new topic and some new sample data.

It will write two types of enrichment data to the index, and both the prefix and the key can be found in the data samples. There is some threat data that relates to some external IP addresses (in the 10.0.0.0 range), and some asset data for internal addresses (in the 192.168.0.0 range), and then later there will be a flow to enrich some network records and explore the results.

Create an error handling output port to connect any failure relationships to and send to the error handling process group.

## Services

Create the following services, based on guides from [Enrich From Redis](experiment-enrich_from_redis.md).

* "Infer" JsonTreeReader
* "Inherit" JsonRecordSetWriter
* RedisConnectionPoolService
* RedisDistributedMapCacheClientService
* DistributedMapCacheLookupService

## Writing Flow

Create this flow to write the JSON messages to Redis

### ConsumeKafka

Copy the consumer processor from previous experiments and make these changes. In this case as the messages are whole JSON arrays then there is no message demarcator.

* Topic Name(s) = my.enrichment.topic
* Message Demarcator = (Tick "Set Empty String")

### SplitRecord

Auto terminate "original" relationship. In practice this should have a proper handler.

* Record Reader = InferJsonTreeReader
* Record Writer = InheritJsonRecordSetWriter
* Records Per Split = 1

### EvaluateJsonPath

Terminate the "splits" relationship from the splitter.

Auto terminate the "unmatched" relationship. Again, should be properly handled in practice.

* Destination = flowfile-attribute
* Return Type = auto-detect
* Path Not Found Behaviour = warn
* index-prefix = enrichment-type
* index-key = enrichment-key

### PutDistributedMapCache

* Cache Entry Identifier = ${index-prefix:append('/'):append(${index-key})}
* Distributed Cache Service = RedisDistributedMapCacheClientService
* Cache Update Strategy = Replace If Present

### LogAttribute

Finish off the flow by logging each write. Auto terminate "success".

* Log Level = Info
* Log Payload = false
* Attributes To Log by Regular Expression = index-.*
* Log prefix = Enrichment data written to Redis

## Test The Write Flow

1. Start the processors you wish to observe.
1. Open a new producer for the enrichment topic with ``bin/launch-script.sh producer my.enrichment.topic``.
1. Paste the samples files "samples/asset-source.json" and "samples/threat-source.json" into the producer.
1. Start a redis console with ``bin/redis-client.sh ``.
1. Check that the expected keys have been written with ``keys *``.
1. Observe the written values, eg ``get  threat_ip/10.2.1.1``.

## Enriching Flow

A simple flow to observe how the enrichment data might work. Start with the JSON test bed flow and fork it.

1. Copy and paste the test bed flow.
1. Right click "Version" > "Stop Version Control".
1. Open configuration and change the name to "Redis Enrichment Test Bed".
1. Start version control again under a new name.

### Delete These

You can delete the AvroSchemaRegistry and CSVReader services.

Delete the first UpdateAttribute and QueryRecord processors


---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Enrich From Redis)](experiment-enrich_from_redis.md)
