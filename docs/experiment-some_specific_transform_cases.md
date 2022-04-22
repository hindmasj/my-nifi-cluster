## [Home](../README.md) | [Up](experiments.md) | [Prev (Write To Redis)](experiment-write_to_redis.md)
---
# Flow Experiment - Some Specific Transform Cases

# Set Up

Create a new flow with just the following processors.

## GenerateFlowFile

Use this to generate the test flow file. Put your test input into the custom text field.

* Batch Size = 1
* Data Format = Text
* Unique Flow Files = false
* Custom Text = (see subsections)

## JoltTransformJSON

Use this to host your transform. Put it in the JOLT specification field. Use the advanced dialogue to help develop the flows.

* Jolt Transform DSL = Chain
* Jolt Specification = (see subsections)
* Pretty Print = true

Turn pretty printing on to make the output easier to read.

## LogMessage

Just create this to have somewhere for the messages to end up. Terminate its success relationship.

# Convert From Numeric To Boolean

Use this as starting test, as we have already done this for [Convert To ECS](experiment-convert_to_ecs.md). Requirement is to turn some flags with values in the range {0,1} into booleans.

## Input

```
[
{"flag_s":1,"flag_a":1,"flag_f":1,"is_frag":0},
{"flag_s":0,"flag_a":0,"flag_f":0,"is_frag":1},
{"flag_s":1,"flag_a":0,"flag_f":1,"is_frag":0}
]
```

## Required Output

```
[
{"flag_s":"true","flag_a":"true","flag_f":"true","is_frag":"false"},
{"flag_s":0,"flag_a":"false","flag_f":"false","is_frag":"true"},
{"flag_s":"true","flag_a":"false","flag_f":"true","is_frag":"false"}
]
```

## Transform

```
[{
	"operation": "modify-overwrite-beta",
	"spec": {
		"*": {
			"flag_*": "=elementAt(@(0),false,true)",
			"is_frag": "=elementAt(@(0),false,true)"
		}
	}
}]
```

# Create A Duration

Create a duration field from a pair of timestamps. Assume the timestamps are in epoch millis and the result needs to be milliseconds too.

## Input

```
[
{"time_start":1000,"time_end":2000},
{"time_start":1500,"time_end":1700},
{"time_start":2000,"time_end":2100}
]
```

## Required Output

```
[
{"time_start":1000,"time_end":2000,"duration":1000},
{"time_start":1500,"time_end":1700,"duration":200},
{"time_start":2000,"time_end":2100,"duration":100}
]
```

## Transform

```
[{
	"operation": "modify-overwrite-beta",
	"spec": {
		"*": {
			"duration": "=intSubtract(time_end,time_start)"
		}
	}
}]
```

# Split One Field Into Two

## Input

```
[
{"result":"hello@123"},
{"result":"world@456"}
]
```

## Required Output

```
[
{"result":"hello@123","answer":"hello","ttl":123},
{"result":"world@456","answer":"world","ttl":456}
]
```

## Transform

```
[{
  "operation": "modify-overwrite-beta",
  "spec": {
    "*": {
      "tmp_array": "=split('@',@(1,result))",
      "answer": "=elementAt(0,@(1,tmp_array))",
      "tmp_ttl": "=elementAt(1,@(1,tmp_array))",
      "ttl": "=toInteger(@(1,tmp_ttl))"
    }
  }
},{
    "operation": "remove",
    "spec": {
      "*": {
        "tmp_*":""
      }
    }
}]
```

# Enrich Transport Protocol From File

Here we want to use a simple file to do the transport protocol enrichment. Create the file and copy it to each of the NiFi nodes with this.

```
bin/parse-protocols.sh > transport_protocols.csv
docker compose cp --all transport_protocols.csv nifi:/opt/nifi/nifi-current/conf
```

## Input

```
[
{"ip_version":4,"network_transport":999},
{"ip_version":4,"network_transport":6},
{"ip_version":4,"network_transport":17},
{"ip_version":4,"network_transport":114}
]
```

## Expected Output

```
[
{"ip_version":4,"network_transport":999},
{"ip_version":4,"network_transport":"tcp"},
{"ip_version":4,"network_transport":"udp"},
{"ip_version":4,"network_transport":"0-hop"}
]
```

## Transform

### SimpleCsvFileLookupService

Rename as "TransportProtocolFileLookupService".

* CSV File = conf/transport_protocols.csv
* Lookup Key Column = code
* Lookup Value Column = name

### LookupRecord

* RecordReader =  = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Lookup Service = TransportProtocolFileLookupService
* Result RecordPath = /network_transport_tmp
* Routing Strategy = Route To Matched/Unmatched
* Record Result Contents = Insert Entire Record
* Record Update Strategy = Use Property
* key = /network_transport

Because of schema difficulties, you cannot write a string value back to a field that originally contained an integer. So we need a Jolt transform to copy the value across.

The routing to matched/unmatched is required to avoid cases where the lookup fails on the first record. Both relationships can connect to the Jolt transform.

### Jolt Transform

Note the use of a string function to copy the name value. This ignores any instances where the value is a literal "null", which will be the case where there is no match.

```
[{
	"operation": "modify-overwrite-beta",
	"spec": {
		"*": {
			"network_transport": "=trim(@(1,network_transport_tmp))"
		}
	}
},{
	"operation": "remove",
	"spec": {
		"*": {
			"network_transport_tmp": ""
		}
	}
}]
```

---
## [Home](../README.md) | [Up](experiments.md) | [Prev (Write To Redis)](experiment-write_to_redis.md)
