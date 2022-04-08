# Custom Processors

See the [NiFi Admin Guide](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#processor-locations) for details of where to put custom processor NARs. See the "Issues" section further down to see discussion of what has been done.

Use the docker copy command to put your custom processor NAR files into the automatic library directory, which is */opt/nifi/nifi-current/extensions/*. Make sure to use the *--all* flag to ensure the file is copied to all of the NiFi containers.

```
docker compose cp --all <path-to-nar-file> nifi:/opt/nifi/nifi-current/extensions/
```

Note that for these docker images the NAR must have been compiled under Java 1.8.0. Refresh the NiFi GUI in your browser before trying to use the new processor.

If you try to load the processor **again**, then you will need to restart the NiFi service, as the class loaders will not load an existing class.

```
docker compose restart nifi
```

## Text Approval Processor

There is a maven project included which creates a very simple processor which just add the phrase "APPROVED" to the end of any message it sees in the flow.

Build the project with ``mvn clean package`` and this produces a NAR file *archiver/target/nifi-hindmasj-processors-&lt;version&gt;.nar* which can then be loaded into the cluster as outlined above.
