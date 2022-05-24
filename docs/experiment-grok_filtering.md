### [Home](../README.md) | [Up](experiments.md) | [Prev (Fork / Join Enrichment)](experiment-fork_join_enrichment.md)
---

# Grok Filtering

This covers using the [GrokReader](https://nifi.apache.org/docs/nifi-docs/components/org.apache.nifi/nifi-record-serialization-services-nar/1.16.1/org.apache.nifi.grok.GrokReader/index.html) service to parse, filter and transform a flow.

Using the GrokReader service allows you to define valid patterns for arbitrary records, extract the key fields and rewrite them as JSON. Use it inside a PartitionRecord to test the extracted records, label them, and split the matching and non-matching records into separate flow files. A RouteOnAttribute processor can then ensure the different flowfiles get sent to different treatment branches.

* [Simple Example](simple-example)
* [Adding a Maybe Field](maybe-field)
* [Multi-Way Partition](multi-way-partition)
* [Fixing the SYSLOG Timestamp](fix-syslog-timestamp)
* [More Advanced Grok Parsing and Routing](advanced)
* [Parsing The KVP Array](parsing)

## References

* The [Logstash Patterns project](https://github.com/logstash-plugins/logstash-patterns-core) defines what are regarded as the [Basic Patterns](https://github.com/logstash-plugins/logstash-patterns-core/blob/main/patterns/ecs-v1/grok-patterns).
* [Tester for all grok patterns](https://grokconstructor.appspot.com/do/match)

# <a name="simple-example"></a>Simple Example

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

* Record Reader = GrokReader
* Record Writer = InheritJsonRecordSetWriter
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

# <a name="maybe-field"></a>Adding a Maybe Field

Consider the fact you might get valid records, but with some fields not populated, or populated with a blank value. If we also want to accept these records

```
192.168.0.1,80,192.168.0.2,12348,,
192.168.0.1,80,192.168.0.2,12348,99,
```
## Grok Expression

Then change the Grok expression to
```
^%{IP:src_addr},%{POSINT:src_port},%{IP:dst_addr},%{POSINT:dst_port},%{POSINT:score}?,%{DATA:message}?$
```

where the "?" will allow the capture of empty fields, provided the space where they should be (in this case commas) is still present.

## Partition Expression

So now the message might be empty, but we are still interested in it. We only want to reject the record if the message is null, meaning the Grok failed.

* Is_Valid = ``matchesRegex(/message,'.*')``

So we now get some extra records in the "Valid" queue.

```
{
  "src_addr" : "192.168.0.1",
  "src_port" : "80",
  "dst_addr" : "192.168.0.2",
  "dst_port" : "12348",
  "score" : null,
  "message" : "",
  "stackTrace" : null,
  "_raw" : "192.168.0.1,80,192.168.0.2,12348,,"
}, {
  "src_addr" : "192.168.0.1",
  "src_port" : "80",
  "dst_addr" : "192.168.0.2",
  "dst_port" : "12348",
  "score" : "99",
  "message" : "",
  "stackTrace" : null,
  "_raw" : "192.168.0.1,80,192.168.0.2,12348,99,"
}
```

So we learn here that selecting which are and are not valid records, or choosing how to partition records depends on you knowing your data and your requirements.

# <a name="multi-way-partition"></a>Multi-Way Partition

Say we want more choices on how we want to partition and route the data. Maybe that score value is important.

## Partition Expressions

This time we want to partition by the score value. If the score is > 50 go one way, if <= 50 go another, and where the score is not set goes a 3rd way. We still want to filter out the invalid records.

* HighScore = ``not(isEmpty(/score[. > 50]))``
* LowScore = ``not(isEmpty(/score[. <= 50]))``
* NoScore = ``isEmpty(/score)``
* IsValid = ``matchesRegex(/message,'.*')``

## Route Expression

Here we have to distinguish between a valid and an invalid record when the score is not set.

* High = ``${HighScore:equals(true)}``
* Low = ``${LowScore:equals(true)}``
* NoScore = ``${NoScore:equals(true):and(${IsValid:equals(true)})}``
* Invalid = ``${IsValid:equals(false)}``

There are 4 relationships, as named above.

# <a name="fix-syslog-timestamp"></a>Fixing the SYSLOG Timestamp

The Grok pattern "SYSLOGTIMESTAMP" will capture a timestamp in the format "MMM dd HH:MM:SS", for example ``May 16 09:10:11``, which as you will note does not include the year. If you try to convert this into epoch-millis the conversion assumes the year is 0 (1970) and you will get the wrong result. There are number of ways in which you can correct this. This one uses an UpdateRecord rule written in RecordPath, making use of some Expression Language too. Here are two formulae which convert the original timestamp ("raw_ts") into either an epoch-millis or an ISO8601 timestamp.

* "epoch-millis" = ``toDate( concat( ${now(): format("yyyy")}, /raw_ts),
 'yyyyMMM dd HH:mm:ss','UTC')``
* "iso8601_ts" = ``format( toDate(  concat( ${now(): format("yyyy")}, /raw_ts),
  'yyyyMMM dd HH:mm:ss', 'UTC'),
 "yyyy-MM-dd'T'HH:mm:ss", "UTC")``

Note how the ``now()`` function is used to create the current year, then is prepended to the timestamp before conversion.

# <a name="advanced"></a>More Advanced Grok Parsing and Routing

## Input Text

Three different types of message, and two sub types. Parse them and send each one to a different way of processing.

```
<site1> Jan 01 09:10:11 192.168.0.1 host1.myco.co.uk ABCD - MESSAGE_TYPE_A [fred@home.my.co.uk.68513 key1="value 1" key2="value 2"]
<site1> Feb 01 10:10:11 192.168.0.2 host1.myco.co.uk ABCD - MESSAGE_TYPE_B this is just more comments
this is not a valid message
<site2> Mar 02 09:10:11 192.168.0.1 host1.myco.co.uk ABCD - MESSAGE_TYPE_FRED [fred@home.my.co.uk.68513 key1="value 1" key2="value 2"]
<site3> May 03 09:10:11 192.168.0.1 host1.myco.co.uk ABCD - MESSAGE_TYPE_BILL [fred@home.my.co.uk.68513 key1="value 1" key2="value 2"]
```

## Grok Patterns

```
HEADER <%{DATA:site_id}>\s%{SYSLOGTIMESTAMP:event_ts}\s%{IP:device_gen_addr_ipv4}\s%{DATA:device_gen_hostname}\s%{DATA:event_category_id}\s-\s%{DATA:event_category_name}
KVARRAY \[\w+@%{DATA}\s%{DATA:kv_array_tmp}\]
```

Copy this file to all nodes with

```
docker compose cp --all samples/custom-patterns.grok nifi:/opt/nifi/nifi-current/conf
```

## GrokReader Service

* Grok Expression = ``^%{HEADER}\s%{KVARRAY}?%{GREEDYDATA:event_tag}$``
* Grok Pattern File = "conf/custom-patterns.grok"
* No Match Behaviour = Raw Line

## PartitionRecord

* Record Reader = GrokReader
* Record Writer = InheritJsonRecordSetWriter
* IsValid = ``not(isEmpty(/site_id))``
* IsPlainMessage = ``not(isEmpty(/event_tag))``
* IsKVMessage = ``not(isEmpty(/kv_array_tmp))``
* IsMessageFred = ``/event_category_name[. = 'MESSAGE_TYPE_FRED']``
* IsMessageBill = ``/event_category_name[. = 'MESSAGE_TYPE_BILL']``

## Routing All Separately

So we could set up all sorts of routing by attribute based on the above truths. The first one is to send each one to its own relationship.

Set up a RouteOnAttribute. There will be four relationships for each type of message, and the invalid ones go to "unmatched".

* Routing Strategy = Route To Property Name
* PlainMessage = ``${IsPlainMessage:equals(true)}``
* KVMessage = ``${IsKVMessage:equals(true): and(${IsMessageFred:isEmpty()}): and(${IsMessageBill:isEmpty()})}``
* FredMessage = ``${IsMessageFred:isEmpty():not()}``
* BillMessage = ``${IsMessageBill:isEmpty():not()}``

# <a name="advanced"></a>Parsing The KVP Array

This section looks at some ways of cleaning up the KVP Array.

## Input
```
[
{"kv_array_tmp": "key1=\"value 1\" key2=\"value 2\""},
{"kv_array_tmp": "key3=\"value a\" key4=\"value b\""}
]
```

## Required Output

```
[
{"kv_array_tmp":{"key1":"value 1", "key2":"value 2"}},
{"kv_array_tmp":{"key3":"value a", "key4":"value b"}}
]
```

## Start With A Regex

In an UpdateAttribute, apply this regex.

* kv_array_tmp = ``replaceRegex( replaceRegex(/kv_array_tmp,'=\"',':'), '\" ?','|')``

which gives you

```
[ {
  "kv_array_tmp" : "key1:value 1|key2:value 2|"
}, {
  "kv_array_tmp" : "key3:value a|key4:value b|"
} ]
```

## Split

```
[{
	"operation": "modify-overwrite-beta",
	"spec": {
		"*": {
			"kv_array_tmp": "=split('\\|',@(0))"
		}
	}
}]
```
yields
```
[{
	"kv_array_tmp": ["key1:value 1", "key2:value 2"]
}, {
	"kv_array_tmp": ["key3:value a", "key4:value b"]
}]
```

## Arrange

Add this
```
, {
	"operation": "modify-overwrite-beta",
	"spec": {
		"*": {
			"kv_array_tmp": ["=split(':',@(0))"]
		}
	}
}
```
yields
```
[{
	"kv_array_tmp": [
		["key1", "value 1"],
		["key2", "value 2"]
	]
}, {
	"kv_array_tmp": [
		["key3", "value a"],
		["key4", "value b"]
	]
}]
```

## Split Keys From Pairs

This is step one of a two step process. See [Stack Overflow - Jolt - How to convert two arrays to key value](https://stackoverflow.com/questions/67952282/jolt-how-to-convert-two-arrays-to-key-value-and-keep-other-singles-properties). Separate the keys into one array and values into another.

```
, {
    "operation": "shift",
    "spec": {
      "*": {
        "kv_array_tmp": {
          "*": {
            "0": "[&3].&2.keys",
            "1": "[&3].&2.values"
          }
        }
      }
    }
  }
```
yields
```
[ {
  "kv_array_tmp" : {
    "keys" : [ "key1", "key2" ],
    "values" : [ "value 1", "value 2" ]
  }
}, {
  "kv_array_tmp" : {
    "keys" : [ "key3", "key4" ],
    "values" : [ "value a", "value b" ]
  }
} ]
```

## Pair Up Keys With Values

This is step 2, to match the keys and the values.

```
, {
    "operation": "shift",
    "spec": {
      "*": {
        "kv_array_tmp": {
          "values": {
            "*": {
              "@": "[&4].&3.@(3,keys[&1])"
            }
          }
        }
      }
    }
  }
```
yields
```
[ {
  "kv_array_tmp" : {
    "key1" : "value 1",
    "key2" : "value 2"
  }
}, {
  "kv_array_tmp" : {
    "key3" : "value a",
    "key4" : "value b"
  }
} ]
```

Which is what we want!

## Recap

The full transform is

```
[{
  "operation": "modify-overwrite-beta",
  "spec": {
    "*": {
      "kv_array_tmp": "=split('\\|',@(0))"
    }
  }
}, {
  "operation": "modify-overwrite-beta",
  "spec": {
    "*": {
      "kv_array_tmp": ["=split(':',@(0))"]
    }
  }
}, {
  "operation": "shift",
  "spec": {
    "*": {
      "kv_array_tmp": {
        "*": {
          "0": "[&3].&2.keys",
          "1": "[&3].&2.values"
        }
      }
    }
  }
}, {
  "operation": "shift",
  "spec": {
    "*": {
      "kv_array_tmp": {
        "values": {
          "*": {
            "@": "[&4].&3.@(3,keys[&1])"
          }
        }
      }
    }
  }
}]
```

---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Fork / Join Enrichment)](experiment-fork_join_enrichment.md)
