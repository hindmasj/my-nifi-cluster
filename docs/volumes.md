### [Home (README.md)](../README.md)
---

# Managing Volumes

It is noted that this project creates a lot of temporary volumes. This should be managed and give the user the chance to retain the volumes so that there can be continuity between instances of the cluster running. In particular these should be retained.

* NiFi flow definitions
* NiFi content repository
* Kafka topic content

The volumes created by default are all for the NiFi containers. 

| Mounts | Purpose
|-- |--
| "/opt/nifi/nifi-current/conf" | 
| "/opt/nifi/nifi-current/content_repository" | 
| "/opt/nifi/nifi-current/database_repository" | 
| "/opt/nifi/nifi-current/flowfile_repository" | 
| "/opt/nifi/nifi-current/logs" | 
| "/opt/nifi/nifi-current/provenance_repository" | 
| "/opt/nifi/nifi-current/state" |

It is easy enough to define a volume for the containers to use, but all will try to use the same at the same time. This is fine for logs, although you do see the logs of all 3 containers mixed together, but will not work for the other mounts as each container needs its own distinct volume.

So googling around tells me that what I want to do is not possible as decribed in [docker issue 4579](https://github.com/docker/compose/issues/4579).

## Shared Logging

What I could do is add the container hostname to the log file so I can see the different containers using different files, at least for nifi-app.log.

Do this by defining a custom "logback.xml" file outside of the container and mount it using the configs resource.

By adding "${HOSTNAME}" to the name and rollover name of the app appender, each logfile now has the form "nifi-app-d17262ae57f6.log", so a unique name for each log file. Of course the names are quite opaque, but at least they are unique. 


---
### [Home (README.md)](../README.md)
