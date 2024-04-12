# Windows Event Parsing Issues

Grabbing some notes for now.

## EVTX Event Parser

* [File Header Class](https://github.com/apache/nifi/blob/rel/nifi-1.0.0/nifi-nar-bundles/nifi-evtx-bundle/nifi-evtx-processors/src/main/java/org/apache/nifi/processors/evtx/parser/FileHeader.java)
* [LibEVTX Documentation](https://github.com/libyal/libevtx/blob/main/documentation/Windows%20XML%20Event%20Log%20(EVTX).asciidoc)
* [Sample EVTX File](https://github.com/apache/nifi/blob/rel/nifi-1.0.0/nifi-nar-bundles/nifi-evtx-bundle/nifi-evtx-processors/src/test/resources/application-logs.evtx)

Problem: Sample from own laptop (Win10) generates error "unexpected minor version". Looks like EVTX 3.1 is supported but version 3.2 is not supported. Version 3.2 is for Win 10 (2004) onwards.

## Windows Event Reader Service

* [Source Event](https://nifi.apache.org/docs/nifi-docs/components/org.apache.nifi/nifi-record-serialization-services-nar/1.25.0/org.apache.nifi.windowsevent.WindowsEventLogReader/additionalDetails.html)

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

Empty data and binary tags.

```
...
      </System>
      <EventData>
         <Data/>
         <Binary/>
      </EventData>
   </Event>
</Events>
```

### Expecting Event Data Tag

Removing event data tag altogether causes ``javax.xml.stream.XMLStreamException: Expecting <EventData> tag but found none``

```
...
      </System>
   </Event>
</Events>
```
