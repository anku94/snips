#!/usr/bin/env bash

RUNDIR=/mnt/ltio/parthenon-topo/ub22perfdbg/blastw4096.38.rcv4k.hybrid25.cmx8192.norcv

gdbbyrank() {
  local -i rank=$1

  local logfile=$RUNDIR/log.txt
  [ ! -f $logfile ] && echo "Log file not found: $logfile" && return 1

  local hostname=$(cat $logfile | grep "|rank:$rank|" | egrep -o "host:[^|]+" | sed "s/host://g" | tail -1)

  echo "Rank: $rank"
  echo "Hostname: $hostname"

  local proc=phoebus

  all_pids=$(ssh $hostname "pidof $proc")

  # get rank modulo 16
  localrank=$((rank % 16))
  rank_pid=$(echo $all_pids | sed "s/\ /\\n/g" | sort -n | head -$(( localrank + 1 )) | tail -1)

  echo $rank_pid
  echo "Rank $rank localidx: $localrank, assumed PID: $rank_pid"
  echo "All PIDs for reference: "
  echo "------------------------"
  echo $all_pids
  echo "------------------------"

  ssh -t $hostname "gdb -p $rank_pid"
}
