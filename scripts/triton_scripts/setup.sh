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

get-ip-wf() {
  host=$1
  if [[ -z $1 ]]; then
    host=$(cat /var/emulab/boot/nickname | cut -d. -f1)
    >&2 echo "Getting local IP for $host"
  else
    >&2 echo "Getting IP for host $host"
  fi

  ips=$(get-ip-gen $host)
  num_ips=$(get-ip-gen $host | wc -l)

  if [[ $num_ips -gt 1 ]]; then
    >&2 echo "$num_ips IPs found. " $(echo $ips | paste -sd, -)
  else
    echo $ips
    return 0
  fi

  final_ip=$(echo $ips | egrep -o 10\.94\[^\ \]\*)
  if [[ -z $final_ip ]]; then
    final_ip=$(echo $ips | egrep -o 10\.111\[^\ \]\*)
  fi

  echo $final_ip
  return 0

}

get-ip-sus-fge() {
  ip=$(ssh $host "ifconfig | egrep -o '10.53.1.[0-9]+' | grep -v 255")

  mpi_type_str=$(mpi-type)

  if [ "$mpi_type_str" = "openmpi" ]; then
    echo $ip slots=64
  elif [ "$mpi_type_str" == "mpich" ]; then
    echo $ip:64
  fi
}

get-ip-gen() {
  host=$1
  ssh $host "ifconfig | egrep -o '10\.[0-9.]+' | grep -v 255"
}

get-ip-loc() {
  ifconfig | egrep -o '10\.[0-9.]+' | grep -v 255
}

get-ip() {
  nodeid=$(cat /var/emulab/boot/nodeid)

  if [[ $nodeid = sus* ]]; then
    echo "sus" 1>&2
    get-ip-sus-fge
  elif [[ $nodeid = wf* ]]; then
    echo "wf"
    get-ip-wf
  fi
}

poll-ip() {
  numhosts=$(get_numhosts)

  echo "$numhosts hosts found." 1>&2

  for i in `seq $numhosts`;
  do
    host=h$(( i - 1 ))
    # stat=$(ssh $host "ibstat | grep LinkUp")

    [[ -z $stat ]] || 1
    echo $(get-ip $host)
  done
}

mpi-type() {
  MPI_OMPI=$(mpirun --version | grep "Open MPI")
  MPI_MPICH=$(mpirun --version | grep "HYDRA")

  if [ ! -z "$MPI_OMPI" ]; then
    echo openmpi
  elif [ ! -z "$MPI_MPICH" ]; then
    echo mpich
  else
    echo unknown
  fi
}

triton-dep() {
  sudo apt-get update
  sudo apt install -y libaio-dev
  sudo apt install -y libboost-system-dev libboost-filesystem-dev
  sudo apt install -y libhiredis-dev fping
  sudo apt install -y sysstat vnstat
}

triton-src() {
  PREF=$HOME/triton

  cd $PREF/yaml-cpp-yaml-cpp-0.5.3
  rm -rf build; mkdir build; cd build
  cmake -DBUILD_SHARED_LIBS=ON YAML_CPP_BUILD_CONTRIB=ON ..
  make -j
  sudo make install

  cd $PREF/jsoncpp-1.9.4
  rm -rf build; mkdir build; cd build
  cmake ..
  make -j
  sudo make install

  cd $PREF/libunwind-1.5.0
  make -j
  sudo make install

  cd $PREF/jemalloc-5.2.1
  ./configure --enable-prof-libunwind
  make -j
  sudo make install

  cd $PREF/re2
  make -j
  sudo make install

  cd $PREF/gperftools-2.8
  ./configure
  make -j
  sudo make install

  cd $PREF/themis_tritonsort/src
  rm -rf build build_old CMakeFiles CMakeCache.txt cmake_install.cmake Makefile
  mkdir build
  cd build
  cmake -DMEMORY_MANAGER=jemalloc -DMEMORY_MANAGER_PHASE_TWO=jemalloc ..
  # some targets fail to build with jemalloc, we don't need them
  make -j || /bin/true
}

local-mount() {
  part=$(sudo fdisk -l | egrep sd[a-z]4 | awk '{ print $1 }')
  echo $part, $HOME
  mkdir -p $HOME/mnt

  sudo mkfs.ext4 $part
  sudo mount $part $HOME/mnt
  sudo chown -R $(whoami):$(whoami) $HOME/mnt
  mkdir -p $HOME/mnt/disk_1
  mkdir -p $HOME/mnt/disk_2
}

ssh-setup() {
  rm -rf ~/.ssh
  sudo cp -r /users/ankushj/.ssh ~
  sudo chown -R $(whoami) ~/.ssh
}

triton-setup() {
  mkdir -p ~/logs/themis
  mkdir -p ~/logs/aggr

  mastip=$(get-ip-wf h0)
  echo $mastip

  ourip=$(get-ip-wf)
  echo $ourip

  cat cluster.conf.in | sed 's/MASTIP/'$mastip'/g' > ~/cluster.conf
  cat themisrc.in | sed 's/MASTIP/'$mastip'/g' > ~/.themisrc
  cat node.conf.in | sed 's/NODEIP/'$ourip'/g' > ~/node.conf
  rm -rf ~/triton
  cp -r /users/ankushj/repos/triton ~/triton

  triton-dep
  triton-src
  local-mount
  ssh-setup

  sudo apt install -y python-pip python-tk
  pip install -r $HOME/triton/themis_tritonsort/src/scripts/requirements.txt
  pip install plumbum paramiko matplotlib
}

triton-setup
