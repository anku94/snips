#!/usr/bin/env bash

# . /users/ankushj/snips/scripts/workflows/rust_env.sh

# sudo apt install -y ninja-build

mon_root="/l0/orcahome/aj-exp"

mon_root="/l0/orcahome/build-again"
mon_srcdir="$mon_root/mon-umbrella"
mon_install="$mon_root/mon-install"

prepmon() {
  cd /
  rm -rf $mon_srcdir
  rm -rf $mon_install

  mkdir -p $mon_install

  cd $mon_root
  echo "Building umbrella in $mon_srcdir"
  git clone https://github.com/anku94/mon-umbrella.git $mon_srcdir
  mkdir -p $mon_srcdir/build

  # Disable in-umbrella mon for now
  cd $mon_srcdir
  git checkout exp

  cat CMakeLists.txt | sed 's/\(include (umbrella\/mon)\)/# \1/' > CMakeLists.txt.tmp
  mv CMakeLists.txt.tmp CMakeLists.txt

  cd $mon_srcdir/build

  export MPI_HOME=/users/ankushj/amr-workspace/mvapich-install-ub22
  export PATH=$MPI_HOME/bin:$PATH
}

buildmon_make() {
  mon_srcdir="$mon_root/mon-umbrella-gmake"
  mon_install="$mon_root/mon-install-gmake"

  prepmon

  cmake -DCMAKE_INSTALL_PREFIX=$mon_install ..
  make -j16
}

buildmon_ninja() {
  mon_srcdir="$mon_root/mon-umbrella-ninja"
  mon_install="$mon_root/mon-install-ninja"

  prepmon

  cmake -DCMAKE_INSTALL_PREFIX=$mon_install -G Ninja ..
  ninja -j16
}

buildmon_distcc() {
  mon_srcdir="$mon_root/mon-umbrella-distcc"
  mon_install="$mon_root/mon-install-distcc"

  prepmon

  mkdir -p $mon_srcdir/build
  cd $mon_srcdir/build

  export DISTCC_HOSTS="localhost h1"
  cmake \
    -DCMAKE_INSTALL_PREFIX=$mon_install -G Ninja \
    -DCMAKE_C_COMPILER_LAUNCHER=distcc \
    -DCMAKE_CXX_COMPILER_LAUNCHER=distcc \
    ..

  ninja -j32
}

buildmon_bench() {
  mon_root="/l0/orcahome/build-bench-exp"
  # rm -rf $mon_root
  # mkdir -p $mon_root

  echo "Building mon-umbrella with gmake" | tee -a $mon_root/build.log
  echo "Start time: $(date)" | tee -a $mon_root/build.log
  #
  echo "Building mon-umbrella with gmake" | tee -a $mon_root/build.log
  buildmon_make
  echo "End time: $(date)" | tee -a $mon_root/build.log
  #
  echo "Building mon-umbrella with ninja" | tee -a $mon_root/build.log
  echo "Start time: $(date)" | tee -a $mon_root/build.log
  buildmon_ninja
  echo "End time: $(date)" | tee -a $mon_root/build.log
  
  echo "Building mon-umbrella with distcc" | tee -a $mon_root/build.log
  echo "Start time: $(date)" | tee -a $mon_root/build.log
  buildmon_distcc
  echo "End time: $(date)" | tee -a $mon_root/build.log
}

buildmon_bench
# cd /
# mon_root="/l0/orcahome/build-bench"
# buildmon_distcc
