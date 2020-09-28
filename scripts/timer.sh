#!/bin/bash

INTVL_MIN=10

echo -e "\n\tAlarm every $INTVL_MIN minutes\n"

while :
do
  afplay /System/Library/Sounds/Ping.aiff
  for CYCLE in $(seq $INTVL_MIN); do
    echo $CYCLE: $(date)
    sleep 60
  done
done
