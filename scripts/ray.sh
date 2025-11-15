#!/usr/bin/env bash

set -euxo pipefail

hostid=$(hostname | cut -d. -f 1)
if [ "$hostid" == "h0" ]; then
  # ray start --head --num-cpus $1
  ray start --head --num-cpus 1
else
  echo nope
  sleep_time=$(( $RANDOM % 32 + 5 ))
  sleep $sleep_time
  ray start --address="h0:6379" --num-cpus $1
fi
