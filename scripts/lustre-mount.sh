#!/bin/bash

set -euxo pipefail

identify-ib() {
  all_ifs=(ibs2 ib0)
  for ibif in "${all_ifs[@]}"; do
    echo $(ifconfig $ibif 2> /dev/null) |
      (
        read TMP
        if [ ! -z "$TMP" ]; then
          echo $ibif
        fi
      )
  done
}

if-is-up() {
  interface=$1
  cmdout=$(ifconfig $interface | grep inet)
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
  PROV=$3 # tcp or o2ib

  sudo mkdir -p $MPOINT
  sudo mount -t lustre $IP@$3:/lustre $MPOINT || /bin/true
  # sudo chown -R ankushj:TableFS $MPOINT
}

run() {
  MPOINT=/mnt/lustre
  IFACE=$(identify-ib)
  IP=$1

  if [[ -z $IP ]]; then
    term "No IP provided"
  fi
  if-is-up $IFACE && sudo /share/testbed/bin/network --ib connected
  if-is-up $IFACE && term "ib0 not up"

  sudo apt-get install -y libsnmp-dev libsnmp30
  #/share/testbed/lustre/add-ub18-client default

  mount-point-clean $MPOINT && /share/testbed/lustre/simple-lnet-config tcp=ib

  for try in $(seq 1 3); do
    mount-point-clean $MPOINT || break
    echo Mounting attempt: $try
    sleep $(($RANDOM % 20))
    attempt-mount $MPOINT $IP tcp
  done

  NID=$(cat /var/emulab/boot/nodeid)
  mount-point-clean $MPOINT || echo "$NID: successfully mounted"
  mount-point-clean $MPOINT && echo "[$(date)] $NID: mounting failed" | tee -a ~/.badnodes

  exit 0
}

run-o2ib() {
  if [[ "$#" == 2 ]]; then
    MPOINT=$2
  elif [[ "$#" == 1 ]]; then
    MPOINT=/mnt/lustre
  else
    return
  fi

  echo "Mounting to: " $MPOINT

  IFACE=$(identify-ib)
  echo $IFACE
  IP=$1

  if [[ -z $IP ]]; then
    term "No IP provided"
  fi

  if [[ x$NOCONFIG != "x1" ]]; then
    if-is-up $IFACE && sudo /share/testbed/bin/network --ib connected
    if-is-up $IFACE && term "ib0 not up"

    /share/testbed/lustre/add-ub18-client default
    mount-point-clean $MPOINT && /share/testbed/lustre/simple-lnet-config -i tcp= o2ib=ib
  fi

  for try in $(seq 1 3); do
    mount-point-clean $MPOINT || break
    echo Mounting attempt: $try
    sleep $(($RANDOM % 20))
    attempt-mount $MPOINT $IP o2ib
  done

  NID=$(cat /var/emulab/boot/nodeid)
  mount-point-clean $MPOINT || echo "$NID: successfully mounted"
  mount-point-clean $MPOINT && echo "[$(date)] $NID: mounting failed" | tee -a ~/.badnodes

  exit 0
}

#run-o2ib $1
if [[ "$#" == 2 ]]; then
  run-o2ib $1 $2
elif [[ "$#" == 1 ]]; then
  run-o2ib $1
else
  echo "./script.sh <IP> <MOUNT_POINT?>"
fi

# should be pre-installed, but just in case
#sudo apt-get install -y libsnmp-dev libsnmp30
