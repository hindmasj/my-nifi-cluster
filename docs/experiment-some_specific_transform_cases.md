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


---
## [Home](../README.md) | [Up](experiments.md) | [Prev (Write To Redis)](experiment-write_to_redis.md)
