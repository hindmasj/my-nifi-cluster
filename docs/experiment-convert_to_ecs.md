### [Home](../README.md) | [Up](experiments.md) | [Prev (Using Tab Separation)](experiment-tab_separation.md) | [Next (Enrich From Redis)](experiment-enrich_from_redis.md)
---

# <a name="flow-experiment-convert-to-ecs"></a>Flow Experiment - Convert To ECS

Prior to working on an enrichment flow, this flow solves the problems of mapping the raw fields to a schema that is more complex. The idea is to make space in the schema for transformations and additions further downstream. Here the enriched schema tries to follow the [Elastic Common Schema](https://www.elastic.co/guide/en/ecs/current/index.html) guidelines. The [CSV of fields](https://github.com/elastic/ecs/blob/8.1/generated/csv/fields.csv) file is a useful quick lookup source.

The [enrichment process](experiment-enrich_from_redis.md) seeks to add more details about the transport protocol and the port services.

## Schema Changes

### Raw

Each of the *int* fields were converted to *long* in line with ECS recommendations.

### Enriched

A new enrichment schema is created, specifically for ECS compatibility.

See the [Avro Specification](https://avro.apache.org/docs/current/spec.html) and this [stackoverflow article](https://stackoverflow.com/questions/43513140/avro-schema-format-exception-record-is-not-a-defined-name) for more information about nested schemas.

The following mappings are made. The ECS recommendation to separate custom fields into their own field set, and capitalise the set name is used here.

* src_address -> source.ip & source.address
* src_address -> source.port
* dst_address -> destination.ip & destination.address
* dst_port -> destination.port
* ip_version -> network.type & Network.type_id
* transport_protocol -> network.iana_number
* flag_s -> Network.flags.syn
* flag_a -> Network.flags.ack
* flag_f -> Network.flags.fin

New fields that might be used later are also added, to see what the effect on processing is.

* Source.service
* Destination.service
* network.application
* network.protocol
* network.transport

This is captured in *ecs-enriched-traffic.schema*. Add it to the Avro Schema Registry as `enriched-traffic`, replacing the old schema.

## Field Mapping

### Query Record

After discussion on the user forum it was tried to combine the format conversion (from CSV to JSON) and the filtering within a single QueryRecord processor.

* RecordReader = CSVReader
* RecordWriter = InheritJsonRecordSetWriter
* Include Zero Record FlowFiles = false
* filtered = See below

```
select *
from flowfile
where transport_protocol <> 6
or flag_s = 1 or flag_a = 1 or flag_f =1
```

### Jolt Transform

Insert a Jolt transform after the query. This processor turns each record from the raw schema format to the ECS enriched one.

```
[{
  "operation": "shift",
  "spec": {
    "*": {
      "src_address": ["[&(1)].source.ip","[&(1)].source.address"],
      "src_port": "[&(1)].source.port",
      "dst_address": ["[&(1)].destination.ip","[&(1)].destination.address"],
      "dst_port": "[&(1)].destination.port",
      "ip_version": ["[&(1)].network.type","[&(1)].Network.type_id"],
      "transport_protocol": "[&(1)].network.iana_number",
      "flag_s": "[&(1)].Network.flags.syn",
      "flag_a": "[&(1)].Network.flags.ack",
      "flag_f": "[&(1)].Network.flags.fin"
    }
  }
}, {
   "operation":"modify-overwrite-beta",
   "spec": {
     "*": {
       "network": {
         "type": "=concat('ipv',@(0))"
       },
       "Network": {
         "flags": {
           "*": "=elementAt(@(0),false,true)"
         }
       }
     }
   }
 }]
```

Note the kludge to convert IP version number to the type string.

*Historical Note*

The filtering of the flags was at one time done after the Jolt in a query. The query is preserved here as a working example of using RPath in a query.

```
select *
from flowfile
where rpath(network,'/iana_number') <> 6
or cast(rpath(network,'/Flags/SYN') as boolean)
or cast(rpath(network,'/Flags/ACK') as boolean)
or cast(rpath(network,'/Flags/FIN') as boolean)
```
---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Using Tab Separation)](experiment-tab_separation.md) | [Next (Enrich From Redis)](experiment-enrich_from_redis.md)
