#!/usr/bin/env bash

gen_hosts() {
  local host_file=$1
  echo "[myhosts]" > $host_file

  bin_file="/share/testbed/bin/emulab-listall" 
  $bin_file | tr ',' '\n' >> $host_file

  hosts_gen=$( wc -l $host_file | awk '{print $1}')
  hosts_gen=$(( hosts_gen - 1 ))

  echo "-INFO- Generated hosts file: $host_file"
  echo "-INFO- Num hosts: $hosts_gen"
}

gen_tags() {
  DISTRIB=$(cat /etc/*release | grep DISTRIB_CODENAME | cut -d= -f 2)

  ansible_tags=""

  if [[ $DISTRIB == "focal" ]]; then
    echo "Ubuntu 20.04 Focal detected."
    ansible_tags="deps,lustre"
  elif [[ $DISTRIB == "jammy" ]]; then
    echo "Ubuntu 22.04 Focal detected."
    ansible_tags="deps,lustre"
  else
    echo "We don't support this distribution sorry"
  fi

  echo "-INFO- Running tags: $ansible_tags"
}

run() {
  gen_hosts /tmp/hosts.txt
  gen_tags

  ansible-playbook \
    -i /tmp/hosts.txt \
    /users/ankushj/scripts/setup_narwhal.yaml \
    -f 64 --tags $ansible_tags
}

check() {
  gen_hosts /tmp/hosts.txt
  gen_tags

  ansible-playbook \
    -i /tmp/hosts.txt \
    /users/ankushj/scripts/check_narwhal.yaml \
    -f 64 --tags $ansible_tags
}

# if CLI argument is -a, call run(), if it is -c, call check, else print help

if [ "$1" == "-a" ]; then
  echo "-INFO- Running ansible playbook"
  run
elif [ "$1" == "-c" ]; then
  echo "-INFO- Checking ansible playbook"
  check
else
  echo "-INFO- Usage: $0 [-a|-c]"
  exit 1
fi
