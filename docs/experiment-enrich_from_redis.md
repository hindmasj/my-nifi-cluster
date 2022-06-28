### [Home](../README.md) | [Up](experiments.md) | [Prev (Convert To ECS)](experiment-convert_to_ecs.md) | [Next (Write To Redis)](experiment-write_to_redis.md)
---
# Flow Experiment - Enrich From Redis

See project [Redis-Client](https://github.com/hindmasj/redis-client) for details of how to set a simple Redis server. A Redis server instance has been added to this docker cluster to make the networking easier.

Access the container CLI with ``docker compose exec redis redis-cli -a nifi_redis``.

## Load Indices

See the above project on how to create the files *protocols.output* and *services.output* which contain the required data. Upload these files with the following.

```
docker exec -i redis redis-cli -a nifi_redis --pipe < ../redis-client/services.output
docker exec -i redis redis-cli -a nifi_redis --pipe < ../redis-client/protocols.output
```

Then test them like this. (Note new command ``bin/redis-client.sh`` to launch a client.)

```
bin/redis-client.sh
> get service.53/udp
"{\"name\":\"domain\",\"code\":53,\"protocol\":\"udp\"}"

> get protocol.6
"{\"name\":\"tcp\",\"code\":6,\"alias\":\"TCP\",\"comment\":\"transmission control protocol\"}"

> exit
```

## Services

### RedisConnectionPoolService

Note you will have to insert the password every time you down/up the cluster.

* Redis Mode = Standalone
* Conection String = redis:6379
* Database Index = 0
* Password = nifi_redis

**Side Note**: Setting the Redis configuration in a Parameter Context.

To demonstrate the use of parameter contexts, create a new parameter context from the site hamburger menu -> Parameter Contexts, and give it a name like "RedisConfig".

Create a new parameter.

* Name = RedisPassword
* Value = nifi_redis
* Sensitive Value = Yes

Now open the "Configure" menu for the process group. On the "General" tab, select the "RedisConfig" parameter context from the drop down under "Process Group Parameter Context".

Now switch to the "Controller Services" tab. In the RedisConnectionPoolService, set the value of "Password" to "#{RedisPassword}".

Repeat for a parameter RedisConnectionString.

* Name = RedisConnectionString
* Value = redis:6379
* Sensitive Value = No

Note that now the parameter context is associated with the process group, whenever the group is imported from the registry it will be created in the NiFi instance with inherited values. However if the context already exists the values will be preserved if the group is imported later. This allows site specific environments to be created, while the correct structure for holding that environment and associating it with the correct process group can be version controlled.

### RedisDistributedMapCacheClientService

* Redis Connection Pool = RedisConnectionPoolService
* TTL = 300 secs

### DistributedMapCacheLookupService

* Distributed Cache Service  = RedisDistributedMapCacheClientService
* Character Encoding = UTF-8

## Processors

### JoltTransformJSON

Create space in the record to put the enriched data by adding this to the modify-overwrite spec.

```
[{
   "operation":"modify-overwrite-beta",
   "spec": {
     "*": {
       ...,
       "Enrichment": {
         "Network": {
           "Transport": null
         },
         "Source": {
           "Service": null
         },
         "Destination": {
           "Service": null
         }
       },
       "Source": {
         "service": null
       },
       "Destination": {
         "service": null
       }
     }
   }
 }]
```

### LookupRecord - Transport

* RecordReader = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Lookup Service = DistributedMapCacheLookupService
* Result RecordPath = /Enrichment/Network/Transport
* Routing Strategy = Route To Success
* Record Result Contents = Insert Entire Record
* Record Update Strategy = Use Property
* key = concat('protocol.',/network/iana_number)

### JoltTransformJSON

A second transform to make sense of the result.

```
[{
  "operation": "shift",
  "spec": {
    "*": {
      "Enrichment":{
        "Network": {
          "Transport": {
            "name": "[&(4)].network.transport"
          }
        }
      },
      "*": "[&(1)].&"
    }
  }
}]
```

Sadly this does not work. See issues above.

### UpdateRecord - Transport

Trying an update instead of a Jolt, to parse the result string with a regex.

* RecordReader = InferJsonTreeReader
* RecordWriter = InheritJsonRecordSetWriter
* Replacement Value Strategy = Record Path Value
* /network/transport =
```
replaceRegex(
  unescapeJson(/Enrichment/Network/Transport),
  '\{name=([^,]+),.*\}',
  '$1'
)
```

This works but it is a bit of a kludge, having to decode the result with a regex.

### LookupRecord - Service

Now we have the transport protocol name we can look up the service name.

This needs two LookupService processors, one for the source and one for the destination.

Copy the previous lookup and change the following, replacing source with destination as required:-

* Result RecordPath = /Enrichment/Source/Service
* key = concat('service.',/source/port,'/',/network/transport)


### UpdateRecord - Service

This can copy the service values to the right places. Copy the previous UpdateRecord, delete update config and add these two.

* /Source/service =
```
replaceRegex(
  unescapeJson(/Enrichment/Source/Service),
  '\{name=([^,]+),.*\}',
  '$1'
)
```
* /Destination/service =
```
replaceRegex(
  unescapeJson(/Enrichment/Destination/Service),
  '\{name=([^,]+),.*\}',
  '$1'
)
```

This places the enriched values in the places required, but has some rough edges and seems overly complex. This completed flow has been saved as a template "flow_templates/JSON_Redis_Enrichment.xml" together with the very simple error handling template "flow_templates/Error_Handling.xml".

---
### [Home](../README.md) | [Up](experiments.md) | [Prev (Convert To ECS)](experiment-convert_to_ecs.md) | [Next (Write To Redis)](experiment-write_to_redis.md)
