### [Home](../README.md) | [Up](experiments.md) | [Next (Tab Separation)](experiment-tab_separation.md)
---

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

---
### [Home](../README.md) | [Up](experiments.md) | [Next (Tab Separation)](experiment-tab_separation.md)
