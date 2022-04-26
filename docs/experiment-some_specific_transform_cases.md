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

# String Transformation

## Input

```
[
{
  "from":"Fred Bloggs <fred@notanaddress.com>",
  "to":"Bob Bobbins <bob@notanaddress.com>","tag":"-"
},{
  "from":"Mary MQ Contrary <mary@notanaddress.com>",
  "to":"LB Peep <bo@notanaddress.com>","tag":"10.0.0.1"
},{
  "from":"Charlie Smith <charlie@notanaddress.com>",
  "to":"Bill Green <bill@notanaddress.com>","tag":"10.0.0.1,192.168.0.1"
}
]
```

## Required Output

```
[
{
  "from":"Fred Bloggs fred@notanaddress.com",
  "to":"Bob Bobbins bob@notanaddress.com","tag":"-"
},{
  "from":"Mary MQ Contrary mary@notanaddress.com",
  "to":"LB Peep <bo@notanaddress.com>","tag":"Path: 10.0.0.1"
},{
  "from":"Charlie Smith charlie@notanaddress.com",
  "to":"Bill Green bill@notanaddress.com","tag":"Path: 10.0.0.1,192.168.0.1"
}
]
```

## Transform

Use an UpdateRecord.

* RecordReader = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Replacement Value Strategy = Record Path Value

The rules to use are

| Parameter | Value
|:--|:--
| /from | ``replace(replace(/from,'<',''),'>','')``
| /tag | ``replaceRegex(/tag,'([^-].*)','Path: $1')``
| /to | ``replace(replace(/to,'<',''),'>','')``

# Generate A Unique UUID

Note that you need to use the Expression Language function ``${UUID()}``. If by mistake you use ``${uuid}`` then you end up with the UUID of the enclosing flow file. If you try to use ``${UUID}`` or ``${uuid()}`` then you get an error.

## Input

```
[
{"name":"fred"},
{"name":"fred"},
{"name":"fred"}
]
```
## Expected Output
```
[
{"name":"fred","uuid":"<uuid0>"},
{"name":"fred","uuid":"<uuid1>"},
{"name":"fred","uuid":"<uuid2>"}
]
```
## Transform - UpdateRecord
Use an UpdateRecord. Note the careful use of quotes and having to use a string function that can take literal values as well as path values.

* RecordReader = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Replacement Value Strategy = Record Path Value
* /uuid = ``concat('','${UUID()}')``

## Transform - Jolt - Do Not Do This
You can also use the EL expression inside a Jolt transform. Let's see what happens.

```
[{
	"operation": "modify-overwrite-beta",
	"spec": {
		"*": {
			"uuid": "${UUID()}"
		}
	}
}]
```

Results

```
[ {
  "name" : "fred",
  "uuid" : "3a0fd5e4-f7c9-49a4-a33c-ea13031605a2"
}, {
  "name" : "fred",
  "uuid" : "3a0fd5e4-f7c9-49a4-a33c-ea13031605a2"
}, {
  "name" : "fred",
  "uuid" : "3a0fd5e4-f7c9-49a4-a33c-ea13031605a2"
} ]
```

D'oh! The EL expression is run once, before the Jolt transform is created, so when the Jolt processor gets the specification, the EL code has already run and all it gets is a fixed string.

It is useful to know how this works and some EL could be used in a transform in place of, for example, an attribute to JSON transform.


---
## [Home](../README.md) | [Up](experiments.md) | [Prev (Write To Redis)](experiment-write_to_redis.md)
