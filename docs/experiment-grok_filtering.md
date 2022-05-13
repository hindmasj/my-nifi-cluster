### [Home](../README.md) | [Up](experiments.md) | [Prev (Fork / Join Enrichment)](experiment-fork_join_enrichment.md)
---

# Grok Filtering

This covers using the [GrokReader](https://nifi.apache.org/docs/nifi-docs/components/org.apache.nifi/nifi-record-serialization-services-nar/1.16.1/org.apache.nifi.grok.GrokReader/index.html) service to parse, filter and transform a flow.

Using the GrokReader service allows you to define valid patterns for arbitrary records, extract the key fields and rewrite them as JSON. Use it inside a PartitionRecord to test the extracted records, label them, and split the matching and non-matching records into separate flow files. A RouteOnAttribute processor can then ensure the different flowfiles get sent to different treatment branches.

## References

* The [Logstash Patterns project](https://github.com/logstash-plugins/logstash-patterns-core) defines what are regarded as the [Basic Patterns](https://github.com/logstash-plugins/logstash-patterns-core/blob/main/patterns/ecs-v1/grok-patterns).
* [Tester for all grok patterns](https://grokconstructor.appspot.com/do/match)

# Simple Example

## Input Data

Consider this arbitrary input data, so of which is valid and interesting, some of which is not.

```
192.168.0.1,80,192.168.0.2,12345,100,hello
192.168.0.1,80,192.168.0.2,12346
192.168.0.1,80,192.168.0.2,12347,10,world
192.168.0.1,80,192.168.0.2,12348
```

Some of the messages contain a score and a message and we want to process those. The ones without we ignore.

Create a GenerateFlowFile processor that can create flowfiles with this content.

## GrokReader Service

Create a GrokReader service that uses a specific Grok expression to pick out the fields of interest, and very importantly, name them.

* Grok Expression = ``^%{IP:src_addr},%{POSINT:src_port},%{IP:dst_addr},%{POSINT:dst_port},%{POSINT:score},%{DATA:message}$``
* No Match Behaviour = Raw Line

Note the use of Grok patterns, which look like ``%{SYNTAX:SEMANTIC}``. The syntax is a regular expression to define structure of the pattern. So the syntax field might be standard regular expression operators, but there are a number of standard definitions already defined, such as "IP" (IP address) and "POSINT" (positive integer).

The semantic is simply a name for the group which can then be used in filtering and transforming.

## PartitionRecord

The generated files pass into a PartitionRecord processor. This uses the Grok reader to process each record within the flow file. Create a property to test if the "message" field has been parsed by the GrokReader. This will be set as an attribute on every flow file, and will be either true or false, depending on the state of the content.

* RecordReader = GrokReader
* Record Writer = InferJsonRecordSetWriter
* Is_Valid = ``not(isEmpty(/message))``

Terminate the original relationship and route success to the next processor.

You could at this point sent to the original flow through a different partition process using a different GrokReader to pick out other records of interest.

## RouteOnAttribute

Now route the flowfiles to the branches to deal with them. Create a specific property to detect the state of the content.

* Routing Strategy = Route to Property name
* Valid = ``${Is_Valid:equals(true)}``

This creates two relationships called "valid" and "unmatched".

## Results
Examining the output shows that the records of interest shows a full JSON record. The unmatched records are also JSON, and the original content has been preserved in the "_raw" field.
### Valid
```
[ {
  "src_addr" : "192.168.0.1",
  "src_port" : "80",
  "dst_addr" : "192.168.0.2",
  "dst_port" : "12345",
  "score" : "100",
  "message" : "hello",
  "stackTrace" : null,
  "_raw" : "192.168.0.1,80,192.168.0.2,12345,100,hello"
}, {
  "src_addr" : "192.168.0.1",
  "src_port" : "80",
  "dst_addr" : "192.168.0.2",
  "dst_port" : "12347",
  "score" : "10",
  "message" : "world",
  "stackTrace" : null,
  "_raw" : "192.168.0.1,80,192.168.0.2,12347,100,world"
} ]
```
### Unmatched
```
[ {
  "src_addr" : null,
  "src_port" : null,
  "dst_addr" : null,
  "dst_port" : null,
  "score" : null,
  "message" : null,
  "stackTrace" : null,
  "_raw" : "192.168.0.1,80,192.168.0.2,12346"
}, {
  "src_addr" : null,
  "src_port" : null,
  "dst_addr" : null,
  "dst_port" : null,
  "score" : null,
  "message" : null,
  "stackTrace" : null,
  "_raw" : "192.168.0.1,80,192.168.0.2,12348"
} ]
```

---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Fork / Join Enrichment)](experiment-fork_join_enrichment.md)
