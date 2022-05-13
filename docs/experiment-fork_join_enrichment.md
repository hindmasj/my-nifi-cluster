### [Home](../README.md) | [Up](experiments.md) | [Prev (Unpacking Lookups)](experiment-unpacking_lookups.md) | [Next (Grok Filtering)](experiment-grok_filtering.md)
---
# Fork / Join Enrichment
This flow follows on from the previous session, now trying to incorporate the use of record style results, unescaped and copied into the enriched record. The flow is complex show is broken down here into separate phases.

The completed flow, which serves both this experiment and the previous, has been saved as a template in "flow_templates/Unescape_JSON.xml".

# Set Up

## Schema
Add the contents of "schemas/lookup_results_input.schema" as a new schema in the AvroSchemaRegistry, and call it "results_input".

## GenerateFlowFile
This uses GenerateFlowFile to generate flow-files with the content taken from "samples/unescape-test-lookups.json"

# Person Enrichment
This transforms the person string into a person record. The enrichment branch is used to perform this to demonstrate the principle, but could be done without, as this update always succeeds.

## ForkEnrichment
This processor needs no configuration. The "original" relationship attaches to the JoinEnrichment. The "enrichment" relationship attaches to an UpdateRecord processor.

## UpdateRecord
This processor takes the person string and converts to the person record. The important point to note here is that performing the update would destroy anything already on the "Enrichment" path of the original record, so the fork has preserved that for later merging.

* Record Reader = SchemaJsonTreeReader
* Record Writer = InheritJsonRecordSetWriter
* Replacement Value Strategy = Record Path Value
* /Enrichment = unescapeJson(/Lookups/person_str)

In practice this branch could also be used to capture the lookup in the first place.

## JoinEnrichment
This processor has queued the original and waits for the enrichment to complete before joining both flow files. Each record is joined by putting each into an enclosing record, for example

```
{
  "original" : {
    ...
  },
  "enrichment" : {
    ...
  }
}
```

* Original Record Reader = SchemaJsonTreeReader
* Enrichment Record Reader = SchemaJsonTreeReader
* Record Writer = SchemaJsonRecordSetWriter
* Join Strategy = Wrapper

The failure and timeout relationships go to error handling. The original relationship is terminated and the joined relationship goes to the JoltTransformJSON.

## JoltTransformJSON
This transform uses a shift to copy the required pieces from each half of the record into a fresh record. In this case the original lookup strings and the enriched person record.

```
[{
	"operation": "shift",
	"spec": {
		"*": {
			"original": {
				"Lookups": "[&(2)].Lookups"
			},
			"enrichment": {
				"Enrichment": {
					"person": "[&(3)].Enrichment.person"
				}
			}
		}
	}
}]
```

# Role Enrichment
This leg now transforms the role string into a role record, and then adds this record to the person record. The point to note here is while the role record is created on the enrichment branch, the person record is preserved on the original branch.

## ForkEnrichment
As above, this processor needs no configuration. The "original" relationship attaches to the JoinEnrichment. The "enrichment" relationship attaches to an UpdateRecord processor.

## UpdateRecord
This processor takes the role string and converts to the role record. We no longer care about losing the person record as it has been preserved on the original branch.

* Record Reader = SchemaJsonTreeReader
* Record Writer = InheritJsonRecordSetWriter
* Replacement Value Strategy = Record Path Value
* /Enrichment = unescapeJson(/Lookups/role_str)

## JoinEnrichment
This processor is the same as above. The failure and timeout relationships go to error handling. The original relationship is terminated and the joined relationship goes to the JoltTransformJSON.

* Original Record Reader = SchemaJsonTreeReader
* Enrichment Record Reader = SchemaJsonTreeReader
* Record Writer = SchemaJsonRecordSetWriter
* Join Strategy = Wrapper

## JoltTransformJSON
In this case the transform uses a shift to copy the person record from the original and the enriched role record into the final record. The lookup strings are dropped.

```
[{
	"operation": "shift",
	"spec": {
		"*": {
			"original": {
        "Enrichment": {
					"person": "[&(3)].Enrichment.person"
				}
			},
			"enrichment": {
				"Enrichment": {
					"role": "[&(3)].Enrichment.role"
				}
			}
		}
	}
}]
```

The final record looks like this.

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

---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Unpacking Lookups)](experiment-unpacking_lookups.md) | [Next (Grok Filtering)](experiment-grok_filtering.md)
