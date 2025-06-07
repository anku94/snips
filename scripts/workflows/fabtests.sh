#!/usr/bin/env bash

set -eu

FAB_UMBRELLA=/l0/fab-umbrella
FAB_INSTALL=/users/ankushj/install-trees/fab-umbrella

gen_cmakelists() {
  cat <<EOF >CMakeLists.txt
cmake_minimum_required(VERSION 3.10)

list (APPEND CMAKE_MODULE_PATH "\${CMAKE_CURRENT_SOURCE_DIR}/umbrella")
include (umbrella-init)

set (MPI_CXX_SKIP_MPICXX ON CACHE BOOL "True if MPICXX should be skipped")
project (fab-umbrella C CXX)

set (UMBRELLA_MPI 0)
set (UMBRELLA_HAS_GNULIBDIRS 1)

include (umbrella-main)

list(APPEND UMBRELLA_CMAKECACHE -DMPI_CXX_SKIP_MPICXX:BOOL=${MPI_CXX_SKIP_MPICXX})

include (umbrella/fabtests)
EOF
}

build() {
  local umbrella_path=$FAB_UMBRELLA
  local install_path=$FAB_INSTALL

  mkdir -p $umbrella_path/build
  mkdir -p $install_path

  git clone https://github.com/pdlfs/umbrella $umbrella_path/umbrella
  cd /l0/fab-umbrella
  # rm -rf /l0/fab-umbrella
  ls $umbrella_path
  gen_cmakelists

  cd $umbrella_path/build
  cmake -DCMAKE_INSTALL_PREFIX=$install_path ..
  make -j
  
}

run() {
  local install_path=$FAB_INSTALL
  FI_INFO=$install_path/bin/fi_info

  $FI_INFO -p verbs -t FI_EP_DGRAM -v
  $FI_INFO
}

run_server() {
  echo "On server, running $SERVER_CMD"
  local log_file=$LOG_DIR/$TEST_NAME-server.log
  echo "Logging to $log_file"
  echo

  echo -e "[CMD] $SERVER_CMD\n" > $log_file
  echo

  $SERVER_CMD | tee -a $log_file
}

run_client() {
  echo "On client, running $CLIENT_CMD"
  local log_file=$LOG_DIR/$TEST_NAME-client.log
  echo "Logging to $log_file"
  echo

  echo -e "[CMD] $CLIENT_CMD\n" > $log_file
  echo

  sleep 1

  $CLIENT_CMD | tee -a $log_file
}

run_main() {
  hostname=$(hostname | cut -d. -f 1)
  if [ $hostname == "h0" ]; then
    run_server
  else
    run_client
  fi
}

get_size_list_bytes() {
  local size_list=(1k 16k 64k 256k 1m 4m 16m)
  # local size_list=(1k 16k 64k)
  # if it ends in k, multiply by 1024, else by 1048576
  # collect as colon-separated list
  local size_list_out=""

  for size in ${size_list[@]}; do
    if [[ $size == *k ]]; then
      size_list_out+=$(( ${size%k} * 1024 )),
    else
      size_list_out+=$(( ${size%m} * 1048576 )),
    fi
  done

  echo ${size_list_out%,}
}

SIZE_LIST=$(get_size_list_bytes)

# the key is the benchmark name
# the log file is stored as $bin_$key-server.log and $bin_$key-client.log
# array fields:
#  1. binary name (e.g., fi_pingpong, assumed to be in $FAB_INSTALL/bin)
#  2. common server + client flags
#  3. client-specific flags
declare -A BENCHMARKS=(
  ["tcp_ctl"]="fi_msg_pingpong|-p sockets|h0"
  ["tcp_fab"]="fi_msg_pingpong|-p sockets -Sl:$SIZE_LIST|h0-dib"
  ["tcp_tcp"]="fi_msg_pingpong|-p tcp -Sl:$SIZE_LIST|h0-dib"
  ["tcp_msg"]="fi_msg_pingpong|-p tcp -e msg -Sl:$SIZE_LIST|h0-dib"

  ["verbs_msg"]="fi_msg_pingpong|-p verbs -e msg -Sl:$SIZE_LIST|h0-dib"
  ["verbs_dgram"]="fi_msg_pingpong|-p verbs -e dgram -Sl:$SIZE_LIST|h0-dib"
  ["verbs_bw_msg"]="fi_msg_bw|-p verbs -e msg -Sl:$SIZE_LIST|h0-dib"
  # does fi_msg_bw even use dgram? Results are identical
  ["verbs_bw_dgram"]="fi_msg_bw|-p verbs -e msg -Sl:$SIZE_LIST|h0-dib"
)

BENCH_RUN=verbs_bw_msg

run_benchmark() {
  local benchmark=$1
  local test_suite=${BENCHMARKS[$benchmark]}

  if [ -z "$test_suite" ]; then
    echo "Unknown benchmark: $benchmark"
    exit 1
  fi

  IFS="|" read -r bench_bin srvflags clflags <<< $test_suite

  local common_cmd="$FAB_INSTALL/bin/$bench_bin"
  TEST_NAME="${bench_bin}_$benchmark"

  SERVER_CMD="$common_cmd $srvflags"
  CLIENT_CMD="$common_cmd $srvflags $clflags"

  echo "Running benchmark: $benchmark ($TEST_NAME)"
  echo "Server command: $SERVER_CMD"
  echo "Client command: $CLIENT_CMD"

  run_main
}

build_bear() {
  bear_path=/l0/bear
  bear_build=/l0/bear/build
  bear_install=/l0/bear/install

  git clone https://github.com/rizsotto/Bear $bear_path
  cd $bear_path

  mkdir -p $bear_build $bear_install
  cd $bear_build
  cmake -DCMAKE_INSTALL_PREFIX=$bear_install ..
  make -j
}

LOG_DIR=/users/ankushj/scripts/workflows/fabtests/logs
run_benchmark $BENCH_RUN
