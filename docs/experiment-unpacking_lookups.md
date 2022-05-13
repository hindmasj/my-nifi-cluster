### [Home](../README.md) | [Up](experiments.md) | [Prev (Some Specific Transform Cases)](experiment-some_specific_transform_cases.md) | [Next (Fork / Join Enrichment)](experiment-fork_join_enrichment.md)
---

# Flow Experiment - Unpacking Lookups

Looking again at the lookup result strings from [Write To Redis](experiment-write_to_redis.md), there should be a way of unpacking them if there is a proper schema.

# Goal

## Input

The input sample in "samples/unescape-test-maps.json". Here is a the first record.

```
[
  {"Enrichment":
    {
      "person_str": "{\"name\":\"John\",\"age\":30}}",
      "role_str": "{\"name\":\"admin\",\"privs\":\"rw\"}}"
    }
  }
]
```

## Required Output

```
[ {
  "Enrichment" : {
    "person" : {
      "name" : "John",
      "age" : 30
    },
    "role" : {
      "name" : "admin",
      "privs" : "rw"
    }
  }
} ]
```

# Schemas

There needs to be two schemas, one which allows the input data through and provides the structure from the results, then one that just has the structure.

See [Avro Specification](https://avro.apache.org/docs/current/spec.html) for details of how these are put together.

## Input Schema

The input schema is in "schemas/enrich_input.schema". Notice that there has to be a full description of the output records embedded in the total record.

```
{
  "type": "record",
  "name": "enrichment",
  "fields": [
    {
      "name": "Enrichment",
      "type": {
        "type": "record",
        "name": "Enrichment_type",
        "fields":[
          {"name":"person_str", "type":"string"},
          {"name":"role_str", "type":"string"},
          {
            "type": "record",
            "name": "person",
            "type": {
              "type": "record",
              "name": "person_type",
              "fields":[
                { "name": "name", "type": "string" },
                { "name": "age", "type": "int" }
              ]
            }
          },
          {
            "type": "record",
            "name": "role",
            "type": {
              "type": "record",
              "name": "role_type",
              "fields":[
                { "name": "name", "type": "string" },
                { "name": "privs", "type": "string" }
              ]
            }
          }
        ]
      }
    }
  ]
}
```

## Output Schema

The output schema is in "schemas/enrich_output.schema". It is the same as the input schema with the difference that the "_str" fields have been removed. This schema is not strictly necessary, its function here is to remove those input fields which hold the raw lookup results. The same effect could be achieved by using a Jolt transform.

# Services

## AvroSchemaRegistry

Create a registry and use it to hold the two schemas, under the names "enrich_input" and "enrich_output".

## SchemaJsonRecordSetWriter

* Schema Access Strategy = Use "Schema Name" Property
* Schema Registry = AvroSchemaRegistry
* Schema Name = ${output.schema}

## SchemaJsonTreeReader

* Schema Access Strategy = Use "Schema Name" Property
* Schema Registry = AvroSchemaRegistry
* Schema Name = ${input.schema}

# Processors

## GenerateFlowFile

* Custom Text = <paste samples/unescape-test-maps.json>
* input.schema = enrich_input
* output.schema = enrich_output

## UpdateRecord

* Record Reader = SchemaJsonTreeReader
* Record Writer = SchemaJsonRecordSetWriter
* Replacement Value Strategy = Record Path Value
* /Enrichment/person = ``unescapeJson(/Enrichment/person_str)``
* /Enrichment/role = ``unescapeJson(/Enrichment/role_str)``

And that's it. Because of the schemas, the escaped strings are properly unpacked. Note that the input is in the form of a map, that is ``{"a":"foo","b":"bar"}`` which means the update processor has assigned a name for the map to create a record.

# Further Work

So the above resolves maps, which fits the requirement I had. But look at the [example in the NiFi documentation](https://nifi.apache.org/docs/nifi-docs/html/record-path-guide.html#unescapejson). There the escaped string is a record, that is ``{"my_record": {"a": "foo", "b": "bar"}}``. See "samples/unescape-test-input.json" for some input text. So if we were to unescape it, it already the path element "person" in it.

```
[
  {"Enrichment":
    {
      "person_str": "{\"person\":{\"name\":\"John\",\"age\":30}}",
      "role_str": "{\"role\":{\"name\":\"admin\",\"privs\":\"rw\"}}"
    }
  }
]
```

So you cannot have an update transform of "/Enrichment/person" as the result path will be "/Enrichment/person/person", which is not allowed by the schema. You can try

* /Enrichment = ``unescapeJson(/Enrichment/person_str)``

Which is great for the person record, but that transform rewrites the entire "Enrichment" record, losing the input strings. And you cannot have two rules with the same name in one update processor, so the role would have to be unescaped in a second processor. But now we have lost the input string for the role, and even if we could save it (see next paragraph), the act of writing the transformed role would wipe out the person record.

There is a schema in "schemas/lookup_results_input.schema" and an example input in "samples/unescape-test-lookups.json" which can be used to look for a solution. The input data is now in a separate record to the enrichment results, but how can both result records be saved?

One solution is to use the fork/join enrichment process. See [the next experiment](experiment-fork_join_enrichment.md).

---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Some Specific Transform Cases)](experiment-some_specific_transform_cases.md) | [Next (Fork / Join Enrichment)](experiment-fork_join_enrichment.md)
