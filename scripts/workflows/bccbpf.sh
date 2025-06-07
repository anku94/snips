#!/usr/bin/env bash

bash

build_bcc_repo() {
  local build_dir=$1
  local install_dir=$2

  echo "-INFO- Building at $1"
  echo "-INFO- Installing at $2"
  sleep 5

  rm -rf $build_dir
  rm -rf $install_dir
  mkdir -p $install_dir

  export PYTHONPATH=$install_dir/lib/python3.10/site-packages/:$PYTHONPATH

  cd /l0
  git clone https://github.com/iovisor/bcc.git $build_dir
  mkdir -p $build_dir/build; cd $build_dir/build

  cmake -DCMAKE_INSTALL_PREFIX=$install_dir ..
  make -j
  make install

  # Without the PY_SKIP_DEB_LAYOUT flag, a flag --install-layout deb
  # is passed to setup.py. This flag is not available in mamba setuptools
  # as it is a debian-specific patch.
  cmake -DPYTHON_CMD=python3 -DPY_SKIP_DEB_LAYOUT=1 .. # build python3 binding
  pushd src/python/
  make
  make install
  popd
}

setup_paths() {
  bcc_root=~/repos/bcc-root
  bcc_repo=$bcc_root/bcc-repo
  bcc_repo_build=/l0/bcc
  bcc_repo_install=$bcc_root/bcc-install
}

build() {
  setup_paths

  cd ~
  build_bcc_repo $bcc_repo_build $bcc_repo_install
}

run_new() {
  setup_paths

  tooldir=$bcc_repo_install/share/bcc/tools
  toolbin=$tooldir/offwaketime
  $toolbin
  echo $py_bin

  bpf_pypath=$(ls $bcc_repo_install/lib/python3.10/site-packages/*egg)
  echo $bpf_pypath

  bcc_lib=$bcc_repo_install/lib

  py_bin=$(which python)
  echo $py_bin

  pids=$(pidof phoebus | sed 's/ /,/g')
  echo "Phoebus PIDs: " $pids

  sudo env PYTHONPATH=$bpf_pypath LD_LIBRARY_PATH=$bcc_lib \
    $py_bin $tooldir/offwaketime -m 100 -p $pids --folded

  sudo env PYTHONPATH=$bpf_pypath LD_LIBRARY_PATH=$bcc_lib \
    $py_bin $tooldir/runqslower

  cd /tmp
  perf sched record -p $pids
}

run() {
  sudo apt install -y zip bison build-essential cmake flex git libedit-dev \
  libllvm14 llvm-14-dev libclang-14-dev python3 zlib1g-dev libelf-dev libfl-dev python3-setuptools \
  liblzma-dev libdebuginfod-dev arping iperf

  build_dir=/l0/bcc
  install_dir=/l0/bcc-install

  git clone https://github.com/iovisor/bcc.git $build_dir
  mkdir -p $build_dir/build; cd $build_dir/build
  cmake -DCMAKE_INSTALL_PREFIX=$install_dir ..
  make -j
  mkdir $install_dir
  make install
  cmake -DPYTHON_CMD=python3 .. # build python3 binding
  pushd src/python/
  make
  sudo make install
  popd

  bpf_pypath=$(ls $install_dir/lib/python3/dist-packages/*egg)
  install_lib=$install_dir/lib
  cd /l0/bcc/examples/tracing
  py_bin=/users/ankushj/mambaforge/bin/python

  sudo env PYTHONPATH=$bpf_pypath LD_LIBRARY_PATH=$install_lib $py_bin task_switch.py
  py_script=/l0/bcc/tools/cpudist.py
  py_args=-O


  echo $bpf_pypath

  phoebus_pids=$(pidof phoebus | sed 's/ /,/g')

  py_script=/l0/bcc/tools/offcputime.py
  py_args="-m 10000 -p $phoebus_pids"
  echo $py_args
  sudo env PYTHONPATH=$bpf_pypath LD_LIBRARY_PATH=$install_lib $py_bin $py_script $py_args

  bash

  phoebus_pids=$(pidof phoebus | sed 's/ /,/g')
  py_script=/l0/bcc/tools/offwaketime.py
  py_args="-m 1000 -p $phoebus_pids -U"
  echo $py_args
  sudo env PYTHONPATH=$bpf_pypath LD_LIBRARY_PATH=$install_lib $py_bin $py_script $py_args

  library
  psm_lib=/users/ankushj/amr-workspace/mvapich-install-ub22/lib/libpsm_infinipath.so.1.16
  ls /users/ankushj/amr-workspace/mvapich-install-ub22/lib/
  psm_func=mq_sq_append

  echo $psm_lib
  perf probe -x $psm_lib --funcs | grep mq_sq

  py_script=/l0/bcc/tools/funccount.py
  py_args='-i 1 qib_user*'
  py_args='-i 1 '$psm_lib':*'
  sudo env PYTHONPATH=$bpf_pypath LD_LIBRARY_PATH=$install_lib $py_bin $py_script $py_args

  py_script=/l0/bcc/tools/hardirqs.py
  py_args='3'
  sudo env PYTHONPATH=$bpf_pypath LD_LIBRARY_PATH=$install_lib $py_bin $py_script $py_args
}
