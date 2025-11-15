#!/usr/bin/env bash

for pid in $(pidof phoebus); do
  gdb --batch -p $pid -ex bt -ex q > ~/CRAP/debug/$(hostname -s).$pid.log
done
