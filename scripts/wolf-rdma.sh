#!/bin/bash

export HTTP_PROXY="http://ops:8888"
export HTTPS_PROXY="http://ops:8888"

#sudo apt install linux-modules-extra-4.15.0-88-generic

install_apt() {
  sudo apt install -y librdmacm-dev libibverbs-dev libmlx4-1 ibverbs-utils \
    infiniband-diags ibutils rdmacm-utils perftest silversearcher-ag opensm

  #sudo modprobe mlx4_ib # Mellanox cards
  sudo modprobe ib_uverbs # verbs API
  sudo modprobe rdma_ucm # ib_ucm also?
  sudo modprobe ib_umad # needed for ibstat
  sudo modprobe ib_qib
  sudo modprobe ib_ipoib

  sudo /etc/init.d/opensm stop
}

get_hostid() {
  echo $(hostname | egrep -o 'h([0-9]+)' | egrep -o '[0-9]+')
}

assign_ip() {
  host_id=$(get_hostid)
  ip_last=$(( $host_id + 2 ))
  sudo ifconfig ib0 10.10.84.$ip_last netmask 255.255.255.0
}

sleep 2

run() {
  install_apt
  # hostid=$(get_hostid)
  # if [ "$hostid" == "2" ]; then
    # echo "Master"
    # sudo opensm
  # fi

  #assign_ip
}

run


# sudo apt remove libibverbs libibverbs-utils libibverbs-devel libmthca libmlx4 libmlx5 libcxgb3 libcxgb4 libnes librdmacm librdmacm-utils libocrdma ofed-docs
# sudo apt remove librdmacm-dev libibverbs-dev libmlx4-1 ibverbs-utils infiniband-diags ibutils rdmacm-utils perftest silversearcher-ag
