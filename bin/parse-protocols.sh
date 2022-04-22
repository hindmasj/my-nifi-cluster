#!/usr/bin/env bash

awk 'BEGIN {FS="\t"}; /^[^\#]/ {printf "%s,%s\n",$2,$1}' /etc/protocols | \
grep -v '0,ip'

echo '61,internal'
echo '63,local'
echo '68,distributed'
echo '99,private'
echo '114,0-hop'
