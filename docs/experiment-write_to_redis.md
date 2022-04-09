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

Copy the consumer processor from previous experiments and make these changes.

* Topic Name(s) = my.enrichment.topic
* Message Demarcator = , (a comma)

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
* index-prefix = /enrichment-type
* index-key = /enrichment-key

### PutDistributedMapCache



## Enriching Flow

---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Enrich From Redis)](experiment-enrich_from_redis.md)
