#!/usr/bin/env bash

set -eux

RESTART_MODE=0

init() {
  export DEBIAN_FRONTEND=noninteractive
  export HTTP_PROXY="http://proxy.pdl.cmu.edu:3128"
  export HTTPS_PROXY="http://proxy.pdl.cmu.edu:3128"
}

rdma_unused() {
  # sudo apt install -y librdmacm-dev libibverbs-dev libmlx4-1 ibverbs-utils infiniband-diags ibutils rdmacm-utils perftest silversearcher-ag

  # sudo modprobe mlx4_ib # low level ahrdware
  # sudo modprobe ib_uverbs # verbs API
  # sudo modprobe rdma_ucm # ib_ucm also?
  # sudo modprobe ib_umad # needed for ibstat
  echo Not Implemented
}

setup_debug() {
  sudo mount -o remount,mode=755 /sys/kernel/debug
  sudo mount -o remount,mode=755 /sys/kernel/debug/tracing
  echo 0 | sudo tee /proc/sys/kernel/kptr_restrict
  echo -1 | sudo tee /proc/sys/kernel/perf_event_paranoid
  sudo chown root:TableFS /sys/kernel/debug/tracing/uprobe_events
  sudo chmod g+rw /sys/kernel/debug/tracing/uprobe_events
}

remove_pkg() {
  sudo apt remove -y $1
}

install_pkg() {
  sudo apt-get install -y $1
}

preinstall_ub18() {
  # for gcc-9
  sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
  install_pkg "libsnmp30 libsnmp-dev"
}

preinstall_ub20() {
  cd /users/ankushj/repos/amr-workspace/mvapich2-root/psm
  sudo make install
}

install_basics() {
  remove_pkg clang-format clang-format-10

  sudo apt-get update

  PACKAGES=infiniband-diags
  PACKAGES="$PACKAGES libgflags-dev libgtest-dev libblkid-dev"
  PACKAGES="$PACKAGES socat pkg-config fio"
  PACKAGES="$PACKAGES libpmem-dev libpapi-dev numactl g++-9 clang-format-10 htop tree"
  PACKAGES="$PACKAGES silversearcher-ag sysstat ctags libnuma-dev"
  PACKAGES="$PACKAGES linux-modules-extra-$(uname -r)"
  PACKAGES="$PACKAGES linux-tools-common linux-tools-$(uname -r) linux-cloud-tools-$(uname -r)"
  PACKAGES="$PACKAGES parallel ripgrep python3-venv"

  install_pkg "$PACKAGES"
  sudo ln -s /usr/bin/clang-format-10 /usr/bin/clang-format || /bin/true
  if [[ $DISTRIB == "bionic" ]]; then
    cd /usr/src/gtest && sudo cmake . && sudo make && sudo mv libg* /usr/lib/
  elif [[ $DISTRIB == "focal" ]]; then
    cd /usr/src/gtest && sudo cmake . && sudo make && sudo mv lib/libg* /usr/local/lib/
  else
    echo "We don't support this distribution sorry"
  fi

  sudo dpkg -i ~/downloads/fd_7.3.0_amd64.deb
  sudo dpkg -i ~/downloads/bat_0.10.0_amd64.deb
}

#
## Uninstall default qib, install Chuck's modded qib
#

setup_qib_ub22() {
  # do nothing if ib is up
  local is_ib_up=$(ifconfig | grep 10.94)
  if [[ -n "$is_ib_up" ]]; then
    echo "IB interface up. Skipping QIB setup."
    return
  fi

  local qib_loaded=$(lsmod | grep qib)
  # if loaded, unload it
  if [[ -n "$qib_loaded" ]]; then
    echo "QIB driver loaded. Unloading..."
    sudo rmmod ib_qib
  fi

  sudo insmod /users/ankushj/downloads/ib_qib.ko
  sudo /share/testbed/bin/network --ib connected
}

install_basics_ub22() {
  sudo apt-get update

  PACKAGES_INST=(infiniband-diags libgflags-dev libgtest-dev
    libblkid-dev socat pkg-config fio libpmem-dev libpapi-dev
    numactl clang-format htop tree silversearcher-ag
    sysstat exuberant-ctags libnuma-dev
    linux-modules-extra-$(uname -r)
    linux-tools-common linux-tools-$(uname -r)
    linux-cloud-tools-$(uname -r)
    parallel librdmacm-dev libibumad-dev ripgrep fd-find g++-12
    libmount-dev libkeyutils-dev
    ca-certificates gpg wget plocate
  )

  # ub22 has gcc-10/11/12, but no g++-12. clang tooling uses gcc-12
  # by default, and complains about missing g++ header files. I could
  # not find a simpler way to fix those issues

  echo "Installing packages: ${PACKAGES_INST[@]}"
  sudo apt install -y ${PACKAGES_INST[@]}

  PACKAGES_REM=(openmpi-bin libopenmpi-dev mpich libmpich-dev)
  sudo apt remove -y ${PACKAGES_REM[@]}

  cd /usr/src/gtest && sudo cmake . && sudo make && sudo mv lib/libg* /usr/local/lib/

  # sudo dpkg -i ~/downloads/fd_8.7.0_amd64.deb
  # sudo dpkg -i ~/downloads/bat_0.23.0_amd64.deb
}

install_mpich_ub18() {
  sudo apt remove -y openmpi-bin libopenmpi-dev
  sudo apt install -y mpich
}

install_mpich_ub20() {
  # current workflow is to use mvapich stored in a special location
  sudo apt remove -y openmpi-bin libopenmpi-dev
}

install_gitlfs() {
  curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
  install_pkg git-lfs
  git lfs install --skip-repo
}

install_cmake() {
  sudo apt purge -y --auto-remove cmake
  wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ $DISTRIB main" | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
  sudo apt update
  install_pkg "cmake cmake-curses-gui"
  sudo rm /usr/share/keyrings/kitware-archive-keyring.gpg || /bin/true
  install_pkg kitware-archive-keyring

}

install_cmake_ub22() {
  # to install cmake 4.0 or something -- don't want this now
  test -f /usr/share/doc/kitware-archive-keyring/copyright ||
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
  echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main' | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install cmake -y
}

install_psm_ub18() {
  cd /users/ankushj/repos/amr-workspace/mvapich2-root/psm-ub18
  sudo make install
}

install_psm_ub20() {
  cd /users/ankushj/repos/amr-workspace/mvapich2-root/psm
  sudo make install
}

install_vtune_ub20() {
  cd /tmp
  wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB |
    gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
  sudo apt update

  # last Vtune version to support Sandy Bridge
  sudo apt install -y intel-oneapi-vtune=2021.9.0-545
  sudo usermod -aG vtune $(whoami)
}

install_x11_ub20() {
  PACKAGES="xauth libxshmfence1 libglu1 libnss3"
  PACKAGES="$PACKAGES libatk1.0-0 libatk-bridge2.0-0 libgtk-3-0 libgbm1"
  install_pkg "$PACKAGES"
}

install_rust() {
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
}

misc_config() {
  sudo /share/testbed/bin/localize-resolv

  # For core dumps
  echo 'core.%P' | sudo tee /proc/sys/kernel/core_pattern
  # For multiple things
  echo 0 | sudo dd of=/proc/sys/kernel/yama/ptrace_scope
  # For vtune
  echo 0 | sudo tee /proc/sys/kernel/kptr_restrict

  # for apache arrow
  #mamba install -c conda-forge xsimd
}

mount_fses() {
  sudo /share/testbed/bin/network -ib connected
  # NOCONFIG=0 ~/scripts/lustre-mount.sh 10.94.2.63
  # NOCONFIG=1 ~/scripts/lustre-mount.sh 10.94.2.65 /mnt/lt20ad1
  # NOCONFIG=1 ~/scripts/lustre-mount.sh 10.94.2.86 /mnt/lt20ad2
  # NOCONFIG=0 ~/scripts/lustre-mount.sh 10.94.3.109 /mnt/ltio
}

run_ub18() {
  RESTART_MODE=${RESTART_MODE:-0}

  if [[ "$RESTART_MODE" != "0" ]]; then
    echo "Restart mode. Skipping installs."
  else
    echo "Initialization mode. Will also install packages."
  fi

  init

  if [[ "$RESTART_MODE" == "0" ]]; then
    preinstall_ub18
    install_basics
    install_mpich_ub18
    install_gitlfs
    install_cmake
    install_psm_ub18
  fi

  misc_config
  mount_fses
}

run_ub20() {
  RESTART_MODE=${RESTART_MODE:-0}

  if [[ "$RESTART_MODE" != "0" ]]; then
    echo "Restart mode. Skipping installs."
  else
    echo "Initialization mode. Will also install packages."
  fi

  init

  # ---- BEGIN INSTALL BLOCK ----
  # installs PSM
  if [[ "$RESTART_MODE" == "0" ]]; then
    preinstall_ub20

    # install_vtune_ub20
    # install_x11_ub20
    install_basics
    install_mpich_ub20
    install_gitlfs
    install_cmake
    install_psm_ub20
  fi
  # ---- end INSTALL BLOCK ----

  misc_config
  mount_fses
}

ensure_l0fs() {
  if [[ ! -d /l0 ]]; then
    echo "Formatting filesystem at /dev/sda4"

    sudo mkdir /l0
    sudo chown -R ankushj:TableFS /l0
    sudo chmod -R 755 /l0
    sudo mkfs.ext4 /dev/sda4
    sudo mount /dev/sda4 /l0
    sudo chown -R ankushj:TableFS /l0
    sudo chmod -R 755 /l0
  else
    echo "Filesystem already exists at /l0"
  fi

  mkdir -p /l0/coredumps
  echo '/l0/coredumps/core.%P' | sudo tee /proc/sys/kernel/core_pattern
}

run_ub22() {
  init
  setup_debug
  install_basics_ub22
  #install_cmake_ub22

  # to fix old cmake problems
  sudo apt remove -y cmake cmake-data
  sudo apt install -y cmake-data=3.22.1-1ubuntu1.22.04.2 cmake=3.22.1-1ubuntu1.22.04.2 cmake-curses-gui=3.22.1-1ubuntu1.22.04.2

  setup_qib_ub22
  #install_gitlfs
  #install_rust
  misc_config

  # if /l0 does not exist
  #ensure_l0fs
}

run() {
  DISTRIB=$(cat /etc/*release | grep DISTRIB_CODENAME | cut -d= -f 2)

  if [[ $DISTRIB == "bionic" ]]; then
    echo "Ubuntu 18.04 Bionic detected."
    run_ub18
  elif [[ $DISTRIB == "focal" ]]; then
    echo "Ubuntu 20.04 Focal detected."
    run_ub20
  elif [[ $DISTRIB == "jammy" ]]; then
    echo "Ubuntu 22.04 Focal detected."
    run_ub22
  else
    echo "We don't support this distribution sorry"
  fi
}

while getopts "rxd" opt; do
  case ${opt} in
  r)
    echo -e "\n[[ INFO ]] Restart mode... skipping one-time installs\n"
    RESTART_MODE=1
    ;;
  x)
    echo -e "\n[[ INFO ]] Installing X11 packages only."
    install_x11_ub20
    exit 0
    ;;
  d)
    echo -e "\n[[ INFO ]] Setting up debug flags!"
    setup_debug
    exit 0
    ;;
  esac
done

run
# install_vtune_ub20
