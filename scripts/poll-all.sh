#!/bin/bash

get_numhosts() {
  count=$(/share/testbed/bin/emulab-listall | sed 's/,/\n/g' | wc -l)
  echo $count
}

poll-hostname() {
  numhosts=$(get_numhosts)

  echo "$numhosts hosts found." 1>&2

  for i in `seq $numhosts`;
  do
    host=h$(( i - 1 ))
    stat=$(ssh $host "ibstat | grep LinkUp")
    [[ -z $stat ]] || echo $host
  done
}

get-ip() {
  echo $(ssh $host "ifconfig ib0 | egrep -o '10.10.10.[0-9]+' | grep -v 255")
}

poll-ip() {
  numhosts=$(get_numhosts)

  echo "$numhosts hosts found." 1>&2

  for i in `seq $numhosts`;
  do
    host=h$(( i - 1 ))
    stat=$(ssh $host "ibstat | grep LinkUp")

    [[ -z $stat ]] || echo $(get-ip $host)
  done
}

#poll-hostname
poll-ip
