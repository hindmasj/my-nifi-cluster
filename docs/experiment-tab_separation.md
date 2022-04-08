### [Home](../README.md) | [Up](experiments.md) | [Prev (Standard Processors)](experiment-standard_processors.md) | [Next (Convert To ECS)](experiment-convert_to_ecs.md)
---

# Flow Experiment - Use Tab Separation

Using the file *samples/simple-traffic-array.tsv* to demonstrate that a TSV file can be handled just as easily as CSV.

Create a new CSVReader, but call it "TSVReader". Give it the following properties.

* Schema Access Strategy = Use Schema Property Name
* Schema Registry = Avro Schema Registry
* Schema Name = ${schema.raw}
* CSV Format = Tab-Delimited

Now configure the ConvertRecord processor to use this new reader and now tab-separated files will processed in the same manner as CSV.

---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Standard Processors)](experiment-standard_processors.md) | [Next (Convert To ECS)](experiment-convert_to_ecs.md)
