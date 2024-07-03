#!/bin/bash
set -u

get_numhosts() {
  count=$(/share/testbed/bin/emulab-listall | sed 's/,/\n/g' | wc -l)
  echo $count
}

poll-hostname() {
  numhosts=$(get_numhosts)
  # numhosts=4

  echo "$numhosts hosts found." 1>&2

  for i in `seq $numhosts`;
  do
    host=h$(( i - 1 ))
    stat=$(ssh $host "ibstat | grep LinkUp")
    node_name=$(ssh $host "hostname -f | cut -d. -f 1")
    if [[ -z $stat ]]; then
      flag=0
    else
      flag=1
    fi
    echo $flag,$node_name,$host

    # [[ -z $stat ]] || echo $host
  done
}

get-ip-wf() {
  stat=$(ssh $host "ibstat | grep LinkUp")

  # [[ -z $stat ]] || echo $(ssh $host "ifconfig ib0 | egrep -o '10.94.1.[0-9]+' | grep -v 255"):16
  [[ -z $stat ]] || echo $(ssh $host "ifconfig ibs2 | egrep -o '10.94.[0-9].[0-9]+' | grep -v 255"):16
  # [[ -z $stat ]] || echo $(ssh $host "ifconfig eno1 | egrep -o '10.111.4.[0-9]+' | grep -v 255"):16
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

get-ip() {
  nodeid=$(cat /var/emulab/boot/nodeid)

  if [[ $nodeid = sus* ]]; then
    echo "sus" 1>&2
    get-ip-sus-fge
  elif [[ $nodeid = wf* ]]; then
    #echo "wf"
    get-ip-wf
  fi
}

poll-ip() {
  numhosts=$(get_numhosts)
  # numhosts=4

  echo "$numhosts hosts found." 1>&2

  for i in `seq $numhosts`;
  do
    host=h$(( i - 1 ))
    # stat=$(ssh $host "ibstat | grep LinkUp")

    #[[ -z $stat ]] || 1
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

# poll-hostname
poll-ip
