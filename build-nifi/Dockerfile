ARG NIFI_VERSION=latest
FROM apache/nifi:${NIFI_VERSION}
USER root
RUN apt-get update
RUN apt-get install redis-tools -y
USER nifi
