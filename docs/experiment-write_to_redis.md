### [Home](../README.md) | [Up](experiments.md) | [Prev (Enrich From Redis)](experiment-enrich_from_redis.md) | [Next (Some Specific Transform Cases)](experiment-some_specific_transform_cases.md)
---

# Flow Experiment - Write To Redis

This experiment develops a flow that can write JSON data to a Redis index.

The flow uses a new topic and some new sample data.

It will write two types of enrichment data to the index, and both the prefix and the key can be found in the data samples. There is some threat data that relates to some external IP addresses (in the 10.0.0.0 range), and some asset data for internal addresses (in the 192.168.0.0 range), and then later there will be a flow to enrich some network records and explore the results.

Create an error handling output port to connect any failure relationships to and send to the error handling process group.

Both of the flows created here have been saved as templates in "flow_templates/Write_To_Redis.xml" and "flow_templates/Redis_Enrichment.xml".

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

When you are ready to run the test, use the data in "samples/sample-redis-traffic.json", copy to the default producer and observe the results in the default consumer.

### Delete These

You can delete the AvroSchemaRegistry and CSVReader services.

Delete the first JoltTransformJSON, UpdateAttribute and QueryRecord processors. Delete all but the first LookupRecord and UpdateRecord processors.

### ConsumeKafka

The incoming samples this time are individual JSON records. Make sure the message demarcator is still ``<shift>+<enter>``.

### JoltTransformRecord

Use this transform to create the enrichment save point. It also converts the separate records in the payload into a single JSON array, which is what the other transforms are expecting.

* Record Reader = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Jolt Specification =
```
[{
  "operation":"modify-overwrite-beta",
  "spec": {
    "Enrichment": {}
  }
}]
```

### LookupRecord

There are now several lookup records to do each of the enrichment lookups. Create them with the following key and result path values. Create the first one by adapting the first LookupRecord from the template and then copy, paste and edit.

| Name | Key | Result RecordPath
|:--|:--|:--
| src asset | concat('asset_ip/',/src_address) | /Enrichment/src_asset
| dst asset | concat('asset_ip/',/dst_address) | /Enrichment/dst_asset
| src threat | concat('threat_ip/',/src_address) | /Enrichment/threat
| dst threat | concat('threat_ip/',/dst_address) | /Enrichment/threat

Notice there is only one landing point for threat data. This is to test an edge case I am interested in. The other configuration values are the same for each.

* RecordReader = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Lookup Service = DistributedMapCacheLookupService
* Result RecordPath = (see table)
* Routing Strategy = Route To Matched/Unmatched
* Record Result Contents = Insert Entire Record
* Record Update Strategy = Use Property
* key = (see table)

See the explanation under [Lookup Ignores All If First Record Not Matched](issues.md#lookup_ignores) for an explanation of why we need to use the "matched/unmatched" routing strategy. For each processor connect both the matched and unmatched relationships to the next processor.

Note during processing that the single input flow file gets fragmented as the individual records get filtered between the different matched and unmatched routes.

### MergeRecord

An attempt to defragment the flowfiles post lookup.

Auto terminate the "original" relationship.

* RecordReader = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Merge Strategy = Bin-Packing Algorithm
* Correlation Attribute = kafka.topic

By using this the number of flow files is reduced from 6 to 2. See [Defragment Records](experiment-some_specific_transform_cases.md#defragment-records) for more explanation.

### UpdateRecord

There is one UpdateRecord processor required to process the captured data into the correct fields.

It consists of a number of rules, each with a result path and source function. The source functions all take the form:

```
replaceRegex(
  unescapeJson(<source record>),
  '^.*<source field>=([^,}]+)[,}].*$',
  '$1'
)
```

The rules are

| Parameter (result path) | Source Record | Source Field
|:--|:--|:--
| /device_src_hostname | /Enrichment/src_asset | hostname
| /device_src_mac_addr | /Enrichment/src_asset | mac
| /device_src_location_location | /Enrichment/src_asset | location
| /device_dst_hostname | /Enrichment/dst_asset | hostname
| /device_dst_mac_addr | /Enrichment/dst_asset | mac
| /device_dst_location_location | /Enrichment/dst_asset | location
| /threat_type | /Enrichment/threat | threat
| /threat_risk_level | /Enrichment/threat | risk
| /threat_source | /Enrichment/threat | Source

For example, the value for the rule "/device_src_hostname" is

```
replaceRegex(
  unescapeJson(/Enrichment/src_asset),
  '^.*hostname=([^,}]+)[,}].*$',
  '$1'
)
```

The other configuration parameters are

* RecordReader = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Replacement Value Strategy = Record Path Value

### JoltTransformJSON

Delete the "Enrichment" temporary location.

Set "Pretty Print" to "True" get easier to read output.

```
[{
  "operation": "remove",
  "spec": {
    "*": {
      "Enrichment": ""
    }
  }
}]
```

## Results

So the things to note are:-

* By the time all the lookups have happened, our original one flow is now 5.
* When both ends are internal the asset information gets added and the threat information is null.
* When both ends are external, the threat information is added and the destination based information always wins as it is the second to be looked up.
* When only one end is external then that threat data is preserved.

# Alternative - Use Replace To Fix Up JSON

After the lookups, it is possible to transform the content as plain text to turn the results into correct JSON. This requires a ReplaceText processor to remove the escape characters, then a Jolt to move the results into the right place. While this is simpler and quicker, there is a risk in real operation that the text replacement may have unintended consequences.

## ReplaceText

* Replacement Strategy = Regex Replace
* Evaluation Mode = Entire Text
* Search Value = ``\"(\{)|(\})\"|\\``
* Replacement Text = ``$1$2``

## JoltTransformJSON

```
[{
	"operation": "shift",
	"spec": {
		"*": {
			"Enrichment": {
				"src_asset": {
					"hostname": "[&(3)].device_src_hostname",
					"mac": "[&(3)].device_src_mac_addr",
					"location": "[&(3)].device_src_location_location"
				},
				"dst_asset": {
					"hostname": "[&(3)].device_dst_hostname",
					"mac": "[&(3)].device_dst_mac_addr",
					"location": "[&(3)].device_dst_location_location"
				},
				"threat": {
					"threat": "[&(3)].threat_type",
					"risk": "[&(3)].threat_risk_level",
					"Source": "[&(3)].threat_source"
				}
			},
			"*": "[&(1)].&"
		}
	}
}]
```

The output of the JOLT can be sent straight to publish.

---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Enrich From Redis)](experiment-enrich_from_redis.md) | [Next (Some Specific Transform Cases)](experiment-some_specific_transform_cases.md)
