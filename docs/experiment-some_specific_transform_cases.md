## [Home](../README.md) | [Up](experiments.md) | [Prev (Write To Redis)](experiment-write_to_redis.md) | [Next (Unpacking Lookups)](experiment-unpacking_lookups.md)
---
# Flow Experiment - Some Specific Transform Cases

* [Set Up](#set-up)
* [Convert From Numeric To Boolean](#numeric-to-boolean)
* [Create A Duration](#create-duration)
* [Round Down Date](#round-down-date)
* [String Transformation](#string-transformation)
* [Split One Field Into Two](#split-field-in-two)
* [Split Fields From A String](#split-fields-from-string)
* [Enrich Transport Protocol From File](#file-based-lookup)
* [Two Stage Lookup](#two-stage-lookup)
* [Defragment Records](#defragment-records)
* [Generate A Unique UUID](#generate-uuid)
* [Change Comma Separated String To Newlines](#csv-to-nl)

# <a name="set-up"></a>Set Up

Create a new flow with just the following processors. Add more processors as needed.

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

# <a name="numeric-to-boolean"></a>Convert From Numeric To Boolean
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

# <a name="create-duration"></a>Create A Duration
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

# <a name="round-down-date"></a>Round Down Date

Round down an ISO8601 data-time value with milliseconds to the nearest second. Most dates are normalised to Zulu time but added cases here with other offsets.

## Input
```
[
{"name":"fred","timestamp":"2022-04-28T12:13:14Z"},
{"name":"bill","timestamp":"2022-04-28T21:19:17.987Z"},
{"name":"charlie","timestamp":"2022-04-28T00:00:00.000Z"},
{"name":"betty","timestamp":"2022-04-28T21:19:17.987+0100"},
{"name":"wilma","timestamp":"2022-04-28T11:12:13.456-0100"}
]
```
## Expected Output
```
[
{"name":"fred","timestamp":"2022-04-28T12:13:14Z"},
{"name":"bill","timestamp":"2022-04-28T21:19:17.000Z"},
{"name":"charlie","timestamp":"2022-04-28T00:00:00.000Z"},
{"name":"betty","timestamp":"2022-04-28T21:19:17.000+0100"},
{"name":"wilma","timestamp":"2022-04-28T11:12:13.000-0100"}
]
```
## With UpdateRecord
* RecordReader = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Replacement Value Strategy = Record Path Value
* /timestamp = ``replaceRegex(/timestamp,'\....([Z+-])','.000$1')``

# <a name="string-transformation"></a>String Transformation
Two more transformations I am interested in.
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

# <a name="split-field-in-two"></a>Split One Field Into Two
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

# <a name="split-fields-from-string"></a>Split Fields From A String
Treat a string as a special character delimited array and pick out specific fields.
## Input
```
[
{"name":"fred","values":"aa:bbb:cc"}
]
```
## Expected Output
```
[
{"name":"fred","inner_tag":"aa","middle_tag":"bbb","outer_tag":"cc"}
]
```
## With UpdateRecord
Tried to use the EL function "getDelimitedField()" which would be ideal, but cannot reference record field paths in EL. So can try a regex or a substring in RecordPath. In either case the transform will need to be followed by a Jolt to remove the original field.

### Substrings
The substrings get very complex as the number of terms increase, so a regex is more compact.

* /inner_tag = ``substringBefore(/values,':')``
* /middle_tag = ``substringBefore(substringAfter(/values,':'),':')``
* /outer_tag = ``substringBefore(substringAfter(substringAfter(/values,':'),':'),':')``

### Regexes
* /inner_tag = ``replaceRegex(/values,'^([^:]+):.*','$1')``
* /middle_tag = ``replaceRegex(/values,'^([^:]+):([^:]+):.*','$2')``
* /outer_tag = ``replaceRegex(/values,'^([^:]+):([^:]+):(.*)$','$3')``

## With JoltTransformJSON
The Jolt transform is much neater.
```
[{
  "operation": "modify-overwrite-beta",
  "spec": {
    "*": {
      "values": "=split(':',@(1,values))",
      "inner_tag": "=elementAt(0,@(1,values))",
      "middle_tag": "=elementAt(1,@(1,values))",
      "outer_tag": "=elementAt(2,@(1,values))"
    }
  }
},{
    "operation": "remove",
    "spec": {
      "*": {
        "values":""
      }
    }
}]
```

# <a name="file-based-lookup"></a>Enrich Transport Protocol From File

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

# <a name="two-stage-lookup"></a>Two Stage Lookup

This complex transform has to consider two fields as keys. Only the first 2 digits of the first tag are used as the key. The second key does apply in all circumstances. The mapping looks like this.

| Key A | Key B | Output
|:-- |:-- |:--
| 11?? | - | X
| 12?? | 3100 | Y/A
| 12?? | 3101 | Y/B
| 12?? | <anything else> | Y
| 13?? | - | Z

The solution is to use two lookups on one file service.

## Input
```
[
{"source":"alpha","tag_a":"1100","tag_b":"2300"},
{"source":"beta","tag_a":"1201","tag_b":"3100"},
{"source":"charlie","tag_a":"1202","tag_b":"3101"},
{"source":"delta","tag_a":"1203","tag_b":"3102"},
{"source":"echo","tag_a":"1304","tag_b":"3100"},
{"source":"foxtrot","tag_a":"1305","tag_b":"2300"}
]
```
## Expected Output
```
[
{"source":"alpha","tag_a":"1100","tag_b":"2300","name":"X"},
{"source":"beta","tag_a":"1201","tag_b":"3100","name":"Y/A"},
{"source":"charlie","tag_a":"1202","tag_b":"3101","name":"Y/B"},
{"source":"delta","tag_a":"1203","tag_b":"3102","name":"Y"},
{"source":"echo","tag_a":"1304","tag_b":"3100","name":"Z"},
{"source":"foxtrot","tag_a":"1305","tag_b":"2300","name":"Z"}
]
```
## Lookup Files
```
id,value
11,X
12,Y
13,Z
Y3100,Y/A
Y3101,Y/B
```

``docker compose cp --all samples/name_mapping.csv nifi:/opt/nifi/nifi-current/conf``

## Lookup Service
Rename as "NameMappingFileLookupService".

* CSV File = conf/name_mapping.csv
* Lookup Key Column = id
* Lookup Value Column = value

## First Lookup
The unmatched relationship will go to the failure route.

* RecordReader =  = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Lookup Service = TransportProtocolFileLookupService
* Result RecordPath = /name
* Routing Strategy = Route To Matched/Unmatched
* Record Result Contents = Insert Entire Record
* Record Update Strategy = Use Property
* key = ``substring(/tag_a,0,2)``
## Second Lookup
The matched and unmatched relationships will go to the success route.

* RecordReader =  = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Lookup Service = TransportProtocolFileLookupService
* Result RecordPath = /name
* Routing Strategy = Route To Matched/Unmatched
* Record Result Contents = Insert Entire Record
* Record Update Strategy = Use Property
* key = ``concat(/name,/tag_b)``

# <a name="defragment-records"></a>Defragment Records
Just for fun, let's merge these records back together. So we know the merge does not mix records of different types, copy and paste the "GenerateFlowFile" processor at the top. Change the value of "topic" and make some change to source file so you see what is happening.

## Merge Record
Strangely we do not use the "defragment" merge strategy. That involves counting fragments and is much more complex. We just want to pack bins.

* RecordReader =  = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Merge Strategy = Bin Packing Algorithm
* Correlation Attribute Name = topic

Terminate the original relationship and send merged to the success route.

Now start both generators and run for about 10s. Then look at the final queue and you will see the original files have been merged together, so the matched and unmatched fragments have been rejoined.

But there still a lot of files, as these is no waiting to accumulate more files between merges. Change the scheduling to 1 sec and try again. Now you will see fewer, fatter files.

# <a name="generate-uuid"></a>Generate A Unique UUID

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

**Results**

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

# <a name="csv-to-nl"></a>Change Comma Separated String To Newlines - Still Seeking Solution

A string of comma separated values change to newline separated.

## Input
```
[
{"name":"fred","values":"a,b,c"}
]
```
## Expected Output
```
[
{"name":"fred","values":"a
b
c"}
]
```

## With UpdateRecord - Did Not Work

* /values = ``replace(/values,',','\n')``
**Result**
```
[ {
  "name" : "fred",
  "values" : "a\nb\nc"
} ]
```

## With JoltTransformJSON - Did Not Work
```
[{
	"operation": "modify-overwrite-beta",
	"spec": {
		"*": {
			"values": "=split(',',@(1,values))"
		}
	}
},{
	"operation": "modify-overwrite-beta",
	"spec": {
		"*": {
			"values": "=join('\n',@(1,values))"
		}
	}
}]
```
**Result**
```
[{
	"name": "fred",
	"values": "a\nb\nc"
}]
```

So result in both cases is that the escaping character '\' is taken literally, so the 'n' cannot be interpreted as a newline. Also tried using multiple escapes and literal new lines (shift+enter) but neither worked, the latter causing an error.

Watch this space to see if there is an answer.

---
## [Home](../README.md) | [Up](experiments.md) | [Prev (Write To Redis)](experiment-write_to_redis.md) | [Next (Unpacking Lookups)](experiment-unpacking_lookups.md)
