#!/usr/bin/env bash

trim_double() {
  NUM_NODES=$(($1 - 1))
  sudo fstrim -v /mnt/mgtmdt

  count=0
  for i in `seq 1 $NUM_NODES`;
  do
    echo $i
    ssh h$i "sudo fstrim -v /mnt/ost$count"
    ssh h$i "sudo fstrim -v /mnt/ost$((count + 1))"
    count=$((count + 2))
  done
}

trim_single() {
  NUM_NODES=$(($1 - 1))
  sudo fstrim -v /mnt/mgtmdt

  count=0
  for i in `seq 1 $NUM_NODES`;
  do
    echo $i
    ssh h$i "sudo fstrim -v /mnt/ost$count"
    count=$((count + 1))
  done
}

get_host_ip() {
  mount_path=$1
  host_ip=$( cat /etc/mtab | grep ad1 | cut -d@ -f 1 )
  echo $host_ip
}

if [[ "$#" != "1" ]]; then
  echo "Usage: $1 <mount_point>"
  exit -1
fi

host_ip=$(get_host_ip $1)
echo "Trimming $host_ip for mount path: $1"
sleep 2
# trim_double $1
trim_single $host_ip
