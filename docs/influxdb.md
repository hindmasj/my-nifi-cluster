### [Home (README.md)](../README.md)
---

# Working With InfluxDB And Telegraf

This work is motiviated by a client I am working with who uses InfluxDB and I want to add NiFi monitoring to their estate.

I am being guided by the steps at [Running InfluxDB 2.0 and Telegraf Using Docker](https://www.influxdata.com/blog/running-influxdb-2-0-and-telegraf-using-docker/).

## Set Up NiFi With Prometheus Reporting Task

1. Add the Prometheus port, 9092, to the NiFi service in *docker-compose.yml*.
2. Start the NiFi cluster as normal. ``docker compose up -d``
3. Create a new Prometheus reporting task on the NiFi cluster.
4. Change "Send JVM Metrics" to "true".
5. Start the task.

## Create InfluxDB and Telegraf Services

### Create Influx Startup Environment

A simple environment file called **influxv2.env** has been created in the repo which creates a default user, API token, organisation and bucket. The environment file is then shared between the InfluxDB and Telegraf containers so that they can communicate.

### Add InfluxDB Instance To Cluster

1. Pick a local directory for persistent storage. In this case I will pick a directory in my home directory. ``mkdir -p ~/volumes/influx``
2. Add an InfluxDB service to *docker-compose.yml*. This has already been done.
3. Start the InfluxDB service instance. ``docker compose up influxdb -d``
4. Connect to the [InfluxDB GUI](http://localhost:8086) and sign in with "admin/admin123".

### Create The Prometheus Configuration

1. Create a directory for Telegraf's persistent storage. ``mkdir -p ~/volumes/telegraf``
2. Create the file *~/volumes/telegraf/telegraf.conf*. Use the file **telegraf.conf** supplied in this repo. ``cp telegraf.conf ~/volumes/telegraf``

The configuration includes an output section, which defines the database and bucket to store the metrics, and an input section which points to the Prometheus end point being run by NiFi.

### Create The Telegraf Service

1. Add a Telegraf service to *docker-compose.yml*. This has already been done.
2. Start the Telegraf service instance. ``docker compose up telegraf -d``
3. Check the logs for the Telegraf service in Docker Desktop to ensure that there are no errors.

You can now view data for the NiFi cluster in your new bucket inside InfluxDB by using the GUI.

## Issues And Next Steps

* The initial value of the API token did not seem to match what was in the Env file. As a workaround I created a real token and copied it into the Env file before I started the Telegraf container. Will need to retest this.
* I should really put the Telegraf file under version control and access it from inside the working directory, not via a local volume.
* Document a worked example of creating a NiFi query.
* The bucket name should be NiFi specific.

---
### [Home (README.md)](../README.md)
