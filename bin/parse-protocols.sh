#!/usr/bin/env bash

echo 'code,name'

awk 'BEGIN {FS="\t"}; /^[^\#]/ {printf "%s,%s\n",$2,$1}' /etc/protocols | \
grep -v '0,ip' | grep -v '51,ipv6-auth'

echo '61,internal'
echo '63,local'
echo '68,distributed'
echo '99,private'
echo '114,0-hop'
