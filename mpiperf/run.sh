#!/usr/bin/env bash

set -x

MPIBIN=/users/ankushj/repos/parthenon-vibe/amr-install/bin
export PATH=$MPIBIN:$PATH

# mpicc -o mpihelloworld mpihelloworld.c
# mpic++ -o mpiperfmon mpiperfmon.cc
# mpirun -np 2 ./wrapper.sh
# g++ -o mpiperfmon mpiperfmon.cc
FIFO_PREFIX=/tmp/perfctl

setup_paths() {
  local -i FDRANK=$1

  FIFO_CTL=${FIFO_PREFIX}.ctl.$FDRANK
  FIFO_ACK=${FIFO_PREFIX}.ack.$FDRANK
}


setup_ctlfds() {
  local -i FDRANK=$1

  mkfifo $FIFO_CTL
  mkfifo $FIFO_ACK

  exec {perf_ctl_fd}<>$FIFO_CTL
  exec {perf_ack_fd}<>$FIFO_ACK

  export PERF_CTL_FD=${perf_ctl_fd}
  export PERF_ACK_FD=${perf_ack_fd}
}

cleanup_ctlfd() {
  local -i FDRANK=$1

  # clean up fd's and delete the fifo's
  exec {perf_ctl_fd}>&-
  exec {perf_ack_fd}>&-

  rm -f $FIFO_CTL
  rm -f $FIFO_ACK
}

run_cmd() {
  perf record --control fd:${perf_ctl_fd},${perf_ack_fd} ./mpiperfmon
}

run_on_mvapich() {
  echo "Rank: $PMI_RANK"
}

run_regular() {
  local -i DEF_RANK=0

  setup_paths $DEF_RANK
  setup_ctlfds $DEF_RANK
  run_cmd
  cleanup_ctlfd $DEF_RANK
}

run_regular
