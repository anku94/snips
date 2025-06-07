#!/usr/bin/env bash

MPIRUNALL=/share/testbed/bin/emulab-mpirunall
SCRIPT=$(realpath "$0")

nodename() {
  echo $(hostname -f | cut -d. -f 1)
}

log_throttlers() {
  throttle_cnt=$(sudo dmesg | grep throttled | wc -l)
  nodecsvstr=""
  if [[ "$throttle_cnt" -gt "10" ]]; then
    echo $(nodename),$throttle_cnt | tee -a ~/CRAP/throttle.log
    nodecsvstr=$nodecsvstr,$nodename
  fi
}

log_tmp() {
  echo $0
  echo $1
}

run() {
  # Non-portable way to detect if script is invoked by an MPI app
  if [[ "${PMI_RANK:-"-1"}" == "-1" ]]; then
    throttle_log=$($MPIRUNALL $SCRIPT | tail -n+2 | paste -sd,)
    echo $throttle_log
    echo $throttle_log | sed 's/,[0-9]\+//g'
  else
    log_throttlers
  fi
}

run
