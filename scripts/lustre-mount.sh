#!/bin/bash

set -euo pipefail

if-is-up() {
  interface=$1
  cmdout=$(ifconfig $interface)
  if [[ -z $cmdout ]]; then
    return 0
  else
    return 1
  fi
}

mount-point-clean() {
  mpoint=$1
  cmdout=$(cat /etc/mtab | grep $mpoint)
  if [[ -z $cmdout ]]; then
    return 0
  else
    return 1
  fi
}

term() {
  echo "Terminating: $1"
  exit 0
}

attempt-mount() {
  MPOINT=$1
  IP=$2

  sudo mkdir -p $MPOINT
  sudo mount -t lustre $IP@tcp:/lustre $MPOINT
  sudo chown -R ankushj:TableFS $MPOINT
}

run() {
  MPOINT=/mnt/lustre
  IFACE=ib0
  IP=$1

  if [[ -z $IP ]]; then
    term "No IP provided"
  fi

  if-is-up $IFACE && sudo /share/testbed/bin/network --ib connected
  if-is-up $IFACE && term "ib0 not up"

  sudo apt-get install -y libsnmp-dev libsnmp30
  /share/testbed/lustre/add-ub18-client default

  mount-point-clean $MPOINT && /share/testbed/lustre/simple-lnet-config tcp=ib

  for try in $(seq 1 3); do
    mount-point-clean $MPOINT || break
    echo Mounting attempt: $try
    attempt-mount $MPOINT $IP
    sleep 15
  done

  NID=$(cat /var/emulab/boot/nodeid)
  mount-point-clean $MPOINT || echo "$NID: successfully mounted"
  mount-point-clean $MPOINT && echo "$NID: mounting failed"

  exit 0
}

run $1

# should be pre-installed, but just in case
#sudo apt-get install -y libsnmp-dev libsnmp30
