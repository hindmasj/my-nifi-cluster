# Windows Event Parsing Issues

Grabbing some notes for now.

## EVTX Event Parser

* [File Header Class](https://github.com/apache/nifi/blob/rel/nifi-1.0.0/nifi-nar-bundles/nifi-evtx-bundle/nifi-evtx-processors/src/main/java/org/apache/nifi/processors/evtx/parser/FileHeader.java)
* [LibEVTX Documentation](https://github.com/libyal/libevtx/blob/main/documentation/Windows%20XML%20Event%20Log%20(EVTX).asciidoc)
* [Sample EVTX File](https://github.com/apache/nifi/blob/rel/nifi-1.0.0/nifi-nar-bundles/nifi-evtx-bundle/nifi-evtx-processors/src/test/resources/application-logs.evtx)

Problem: Sample from own laptop (Win10) generates error "unexpected minor version". Looks like EVTX 3.1 is supported but version 3.2 is not supported. Version 3.2 is for Win 10 (2004) onwards.

Raised as [NIFI-13332](https://issues.apache.org/jira/browse/NIFI-13332).

Not passing failed file to failure queue raised as [NIFI-13333](https://issues.apache.org/jira/browse/NIFI-13333).

**Extract local EVTX file:**

1. Open Windows Event Viewer.
2. Select "Save All Events As ..."
3. Keep the format as EVTX and select a location to save the file.

**Copy sample files from *C:\\Downloads* to NiFi cluster:**

```
docker compose cp /mnt/c/Users/steve/Downloads/sample-event-file.evtx nifi:/tmp
docker compose cp /mnt/c/Users/steve/Downloads/application-logs.evtx nifi:/tmp
```

## Windows Event Log Reader Service

The WindowsEventLogReader service is designed to parse Windows events in XML. See [Source Event](https://nifi.apache.org/docs/nifi-docs/components/org.apache.nifi/nifi-record-serialization-services-nar/1.25.0/org.apache.nifi.windowsevent.WindowsEventLogReader/additionalDetails.html) for details of the basic event used for testing.

### Event With No Error

Empty event data tag.

```
<?xml version="1.0" encoding="UTF-8"?>
<Events>
   <Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
      <System>
         <Provider Name="ASP.NET 4.0.30319.0"/>
         <EventID Qualifiers="32768">1020</EventID>
         <Level>3</Level>
         <Task>1</Task>
         <Keywords>0x80000000000000</Keywords>
         <TimeCreated SystemTime="2016-01-07 23:15:06.000"/>
         <EventRecordID>231</EventRecordID>
         <Channel>Application</Channel>
         <Computer>win7-pro-vm</Computer>
         <Security UserID=""/>
      </System>
      <EventData>
      </EventData>
   </Event>
</Events>
```

### Null Pointer Exception

Raised as [NIFI-13330](https://issues.apache.org/jira/browse/NIFI-13330).

Event data tags may be empty. For example

```
...
      </System>
      <EventData>
         <Data Name="param1"></Data>
      </EventData>
   </Event>
</Events>
```

But when processed this fails with

```
ConvertRecord[id=7b99392f-2b54-139e-8791-349e930904cd] Failed to process FlowFile[filename=cdd10be3-9364-4458-bb89-69988b3e7a60]; will route to failure: java.lang.NullPointerException
```

and this partial stack trace shows where the NPE should be caught.

```
2024-05-31 12:55:15 2024-05-31 11:55:15,722 ERROR [Timer-Driven Process Thread-5] o.a.n.processors.standard.ConvertRecord ConvertRecord[id=7b99392f-2b54-139e-8791-349e930904cd] Failed to process StandardFlowFileRecord[uuid=cdd10be3-9364-4458-bb89-69988b3e7a60,claim=StandardContentClaim [resourceClaim=StandardResourceClaim[id=1717153302525-1, container=default, section=1], offset=6510, length=880],offset=0,name=cdd10be3-9364-4458-bb89-69988b3e7a60,size=880]; will route to failure
2024-05-31 12:55:15 java.lang.NullPointerException: null
2024-05-31 12:55:15     at java.base/java.util.Objects.requireNonNull(Unknown Source)
2024-05-31 12:55:15     at org.apache.nifi.serialization.record.RecordField.<init>(RecordField.java:70)
2024-05-31 12:55:15     at org.apache.nifi.serialization.record.RecordField.<init>(RecordField.java:40)
2024-05-31 12:55:15     at org.apache.nifi.windowsevent.WindowsEventLogRecordReader.getDataFieldsFrom(WindowsEventLogRecordReader.java:292)
```

If the tag is given the null then this is treated as a string, not a null.

```
    <Data Name="CertIssuer">null</Data>
```
parses to
```
    "CertIssuer" : "null"
```

### Expecting Event Data Tag

Removing event data tag altogether causes ``javax.xml.stream.XMLStreamException: Expecting <EventData> tag but found none``

```
...
      </System>
   </Event>
</Events>
```

Not sure if this is an actual issue. Found it when looking at mixed logs but the source of the erroring logs was WMI, not windows events, so they have a different schema.

### Not Parsing Rendering Info

Raised in [NIFI-13328](https://issues.apache.org/jira/browse/NIFI-13328).

Windows events collected from the [Windows Events Collector](https://learn.microsoft.com/en-us/windows/win32/wec/windows-event-collector) will contain a [RenderingInfo](https://learn.microsoft.com/en-us/windows/win32/wes/eventschema-renderingtype-complextype) tag. So it is an expected tag.

The event might look like

```
...
  </EventData>
  <RenderingInfo Culture="en-US">
    <Message>This is a message</Message>
  </RenderingInfo>
</Event>
```

But the reader will fail with this message in the bulletin.

```
ConvertRecord[id=7b99392f-2b54-139e-8791-349e930904cd] Failed to process FlowFile[filename=ffca2ea2-edd5-4ad1-8380-2bc4c8dae1ac]; will route to failure: org.apache.nifi.processor.exception.ProcessException: Could not parse incoming data
- Caused by: org.apache.nifi.serialization.MalformedRecordException: Error reading records to determine the FlowFile's RecordSchema
- Caused by: javax.xml.stream.XMLStreamException: Expecting <Event> tag but found unknown/invalid tag RenderingInfo
```

## XMLReader

The XMLReader is a generic XML reader. Here we are exploring some errors with records wrapped in array tags, and arrays of tags with the same element but using an attribute to name them.

### Event With No Errors

Ensure that the reader is configured with:

* Parse XML Attributes = true
* Expect Records as Arrays = true
* Field Name for Content = Value

(hint: set the value of "Expect Records as Arrays" to ``${xml.stream.is.array}`` then in the flow file generator set the attribute "xml.stream.is.array" to either "true" or "false" as required.)

This example event parses with no errors.

```
<Events>
  <Event Type="foo">
    <System>
      <EventID>0x0001</EventID>
    </System>
    <UserData>
      <Data Name="Param1">String1</Data>
      <Data Name="Param2">String2</Data>
      <Data Name="Param3">String3</Data>
    </UserData>
  </Event>
  <Event Type="bar">
    <System>
      <EventID>0x0002</EventID>
    </System>
    <UserData>
      <Data Name="Param1">String</Data>
      <Data Name="Param2">String</Data>
    </UserData>
  </Event>
</Events>
```

which will parse out to

```
[ {
  "Type" : "foo",
  "System" : {
   "EventID" : "0x0001"
  },
  "UserData" : {
   "Data" : [ {
      "Name" : "Param1",
      "Value" : "String1"
   }, {
      "Name" : "Param2",
      "Value" : "String2"
   }, {
      "Name" : "Param3",
      "Value" : "String3"
   } ]
  }
}, {
  "Type" : "bar",
  "System" : {
   "EventID" : "0x0002"
  },
  "UserData" : {
   "Data" : [ {
      "Name" : "Param1",
      "Value" : "String"
   }, {
      "Name" : "Param2",
      "Value" : "String"
   } ]
  }
} ]
```

### Dropping Data Elements

Raised as [NIFI-13334](https://issues.apache.org/jira/browse/NIFI-13334).

If the length of the second array is only then the first array loses all but its first element.

This
```
<Events>
  <Event Type="foo">
   <System>
      <EventID>0x0001</EventID>
   </System>
   <UserData>
      <Data Name="Param1">String1</Data>
      <Data Name="Param2">String2</Data>
      <Data Name="Param3">String3</Data>
   </UserData>
</Event>
<Event Type="bar">
   <System>
      <EventID>0x0002</EventID>
   </System>
   <UserData>
      <Data Name="Param1">String</Data>
   </UserData>
</Event>
</Events>
```
parses to
```
[ {
  "Type" : "foo",
  "System" : {
   "EventID" : "0x0001"
  },
  "UserData" : {
   "Data" : {
      "Name" : "Param3",
      "Value" : "String3"
   }
  }
}, {
  "Type" : "bar",
  "System" : {
   "EventID" : "0x0002"
  },
  "UserData" : {
   "Data" : {
      "Name" : "Param1",
      "Value" : "String"
   }
  }
} ]
```

Notice that the first event now only has one data field, and it is no longer in an array. The same result is seen if the first event is the one with only one data tag.

### Dropping Data Values With Mixed Types

Raised as [NIFI-13335](https://issues.apache.org/jira/browse/NIFI-13335).

This test does not require an array.

Parsing a single event record such as

```
<Event Type="foo">
  <System>
    <EventID>0x0001</EventID>
  </System>
  <UserData>
    <Data Name="Param1">String1</Data>
    <Data Name="Param2">String2</Data>
    <Data Name="Param3">String3</Data>
  </UserData>
</Event>
```
parses to this as expected
```
[ {
  "Type" : "foo",
  "System" : {
    "EventID" : "0x0001"
  },
  "UserData" : {
    "Data" : [ {
        "Name" : "Param1",
        "Value" : "String1"
    }, {
        "Name" : "Param2",
        "Value" : "String2"
    }, {
        "Name" : "Param3",
        "Value" : "String3"
    } ]
  }
} ]
```

But if one of the parameters has a numeric value then all of the values are parsed to null. For example

```
<Event Type="foo">
  <System>
    <EventID>0x0001</EventID>
  </System>
  <UserData>
    <Data Name="Param1">String1</Data>
    <Data Name="Param2">2</Data>
    <Data Name="Param3">String3</Data>
  </UserData>
</Event>
```
parses to
```
[ {
  "Type" : "foo",
  "System" : {
    "EventID" : "0x0001"
  },
  "UserData" : {
    "Data" : [ {
        "Name" : "Param1",
        "Value" : null
    }, {
        "Name" : "Param2",
        "Value" : null
    }, {
        "Name" : "Param3",
        "Value" : null
    } ]
  }
} ]
```
