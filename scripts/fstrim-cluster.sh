#!/usr/bin/env bash

set -u

SCRIPT=$( readlink -m $( type -p ${0} ))
MPIRUNALL=/share/testbed/bin/emulab-mpirunall
LOG=/users/ankushj/fstrim.log

get_host_ip() {
  mount_path=$1
  host_ip=$( cat /etc/mtab | grep $mount_path | cut -d@ -f 1 )
  echo $host_ip
}

whereami() {
  echo $(hostname | cut -d. -f 1-3)
}

fstrim_node() {
  mntpt_totrim=$(ls -d /mnt/[mo]*)
  echo "[$(whereami)] fstrim_node: sudo fstrim $mntpt_totrim"
  sudo fstrim $mntpt_totrim
  return
}

fstrim_server() {
  echo "[$(whereami)] In fstrim_server"
  export PATH=$PATH:/usr/lib64/mpich/bin
  echo "Executing: $MPIRUNALL $SCRIPT"
  $MPIRUNALL $SCRIPT
}

fstrim_client() {
  mount_path=$1
  host_ip=$(get_host_ip $mount_path)
  echo "Trimming $host_ip for mount path: $1"

  echo "[$(whereami)] fstrim_client, trimming $1"

  CMD=$(echo $SCRIPT -s)
  echo -e "\nExecuting: ssh $host_ip \""$CMD"\"\n"
  ssh $host_ip "$CMD"
  return
}

usage() {
  cat<<EOF
Usage: 

On a lustre server:

fstrim-cluster -s, will call fstrim-cluster -n on all Lustre nodes

On a lustre client:

fstrim-cluster -c <lustre-root-note>
EOF
}

while getopts "sc:n" arg; do
  case $arg in
    s)
      fstrim_server
      exit
      ;;
    c)
      fstrim_client $OPTARG
      exit
      ;;
    *)
      usage
      ;;
  esac
done

fstrim_node
