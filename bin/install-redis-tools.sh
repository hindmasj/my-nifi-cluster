#!/usr/bin/env bash
# Install redis tools on all nifi hosts

for i in {1..3}
do
  docker compose exec -u root --index ${i} nifi apt-get install redis-tools -y
done
