#!/usr/bin/env bash

set -eu

setup_paths() {
  bcc_root=~/repos/bcc-root
  bcc_repo=$bcc_root/bcc-repo
  bcc_repo_build=/l0/bcc
  bcc_repo_install=$bcc_root/bcc-install

  bpf_pypath=$(ls $bcc_repo_install/lib/python3.10/site-packages/*egg)
  py_bin=/users/ankushj/mambaforge/bin/python
  bcc_lib=$bcc_repo_install/lib
  tooldir=$bcc_repo_install/share/bcc/tools

  echo "-INFO- bpf_pypath: $bpf_pypath"
  echo "-INFO- py_bin: $py_bin"
  echo "-INFO- bcc_lib: $bcc_lib"

  my_hostname=$(hostname | cut -d. -f 1)
}

run() {
  setup_paths

  local outdir=$AMRMON_OUTPUT_DIR/feebtrace
  mkdir -p $outdir
  local outfile=$outdir/${my_hostname}.log

  echo "-INFO- Writing to $outfile"

  # sudo env PYTHONPATH=$bpf_pypath LD_LIBRARY_PATH=$bcc_lib \
  #   $py_bin $tooldir/runqslower 1000 | tee $outfile

  CMD_PRE="sudo env PYTHONPATH=$bpf_pypath LD_LIBRARY_PATH=$bcc_lib $py_bin"
  echo $CMD_PRE
  # $CMD_PRE $tooldir/runqslower 1000
  # bash
  # $CMD_PRE $tooldir/funccount -i 1 'sdma_sw_clean_up_task'
  # $CMD_PRE $tooldir/funccount -i 1 -d 500 -T '*sdma*' &> $outfile
  # $CMD_PRE $tooldir/funccount -i 1 'qib_sdma*'
  # $CMD_PRE $tooldir/funccount -i 1 'qib_sdma*'
  # $CMD_PRE $tooldir/funclatency -i 5 -m -F 'qib_sdma_intr'
  # $CMD_PRE $tooldir/funcslower 'qib_sdma_intr'
  # $CMD_PRE $tooldir/softirqs -T 4 80 &> $outfile
  # $CMD_PRE $tooldir/hardirqs -T 4 80 &> $outfile

  pids=$(pidof phoebus | sed 's/ /,/g')
  # while the pids var is empty; loop; sleep 1
  while [ -z "$pids" ]; do
    pids=$(pidof phoebus | sed 's/ /,/g')
    sleep 1
  done

  echo "-INFO- Phoebus PIDs: $pids"
  # $CMD_PRE $tooldir/myhardirqs -m 30 500 &> $outfile
  # $CMD_PRE $tooldir/myhardirqs -m 2 1

  # $CMD_PRE $tooldir/offcputime -f -m 2000 320 -p $pids &> $outfile
  # $CMD_PRE $tooldir/myoffcputime -m 2000 80 -p $pids &> $outfile
  # $CMD_PRE $tooldir/myoffcputime -m 5000 320 -p $pids &> $outfile
  # $CMD_PRE $tooldir/mypsmdist.py -i 1 -n 340 > $outfile
  # $CMD_PRE $tooldir/mytidflow.py -i 1 -n 340 > $outfile
  # $CMD_PRE $tooldir/mytidflow.py -i 1 -n 100
  # $CMD_PRE $tooldir/mypsmdist.py -i 2 -n 30
  # mvroot='/users/ankushj/amr-workspace/mvapich-install-ub22'
  # libpsm=$mvroot/lib/libpsm_infinipath.so.1.16
  # echo $libpsm
  #$CMD_PRE $tooldir/funccount ''
  # $CMD_PRE $tooldir/funccount -D $libpsm:'*tf*'
  #

  # $CMD_PRE $tooldir/myfeebtrace.py -d 450 &> $outfile
  # bash
  # setup_paths
  # export BPF_OUTFILE=/tmp/file.out
  export BPF_OUTFILE=$outfile
  # unset BPF_OUTFILE
  # $CMD_PRE $tooldir/myfeebtrace.py -d 600
  # unset BPF_OUTFILE

  $CMD_PRE $tooldir/myfeebp2p.py -d 60

  # mvroot=/users/ankushj/amr-workspace/mvapich-install-ub22
  # mpilib=$mvroot/lib/libmpi.so.12.1.1
  # perf probe -x $mpilib --funcs | grep end | less
}

terminate() {
  setup_paths

  ps aux | grep $tooldir

  for pid in $(ps aux | grep $tooldir | awk '{ print $2 }');
  do
    echo INT $pid
    sudo kill -INT $pid
    sleep 5
    # sudo kill -TERM $pid
  done
}

# if one arg, and is -r, run(), -t: terminate, else print help
if [ $# -eq 1 ]; then
  if [ $1 == "-r" ]; then
    run
  elif [ $1 == "-t" ]; then
    terminate
  else
    echo "Usage: $0 [-r|-t]"
  fi
else
  echo "Usage: $0 [-r|-t]"
fi
