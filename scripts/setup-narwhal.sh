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
  PACKAGES="$PACKAGES parallel"

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
  echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ $DISTRIB main" | sudo tee /etc/apt/sources.list.d/kitware.list > /dev/null
  sudo apt update
  install_pkg "cmake cmake-curses-gui"
  sudo rm /usr/share/keyrings/kitware-archive-keyring.gpg || /bin/true
  install_pkg kitware-archive-keyring

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
  wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | \
    gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
  sudo apt update

  # last Vtune version to support Sandy Bridge
  sudo apt install -y intel-oneapi-vtune=2021.9.0-545
  sudo usermod -aG vtune $(whoami)
}

install_x11_ub20() {
  PACKAGES="xauth libxshmfence1 libglu1 libnss3"
  PACKAGES="$PACKAGES libatk1.0-0 libatk-bridge2.0-0 libgtk-3-0 libgbm1"
  install_pkg "$PACKAGE
}

misc_config() {
  sudo /share/testbed/bin/localize-resolv

  # For core dumps
  echo 'core.%P' | sudo tee /proc/sys/kernel/core_pattern
  # For multiple things
  echo 0 | sudo dd of=/proc/sys/kernel/yama/ptrace_scope
  # For vtune
  echo 0 | sudo tee /proc/sys/kernel/kptr_restrict
}

mount_fses() {
  sudo /share/testbed/bin/network -ib connected
  NOCONFIG=0 ~/scripts/lustre-mount.sh 10.94.2.63
  NOCONFIG=1 ~/scripts/lustre-mount.sh 10.94.2.65 /mnt/lt20ad1
  NOCONFIG=1 ~/scripts/lustre-mount.sh 10.94.2.86 /mnt/lt20ad2
  NOCONFIG=1 ~/scripts/lustre-mount.sh 10.94.3.109 /mnt/ltio
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

    install_vtune_ub20
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

run() {
  DISTRIB=$(cat /etc/*release | grep DISTRIB_CODENAME | cut -d= -f 2)

  if [[ $DISTRIB == "bionic" ]]; then
    echo "Ubuntu 18.04 Bionic detected."
    run_ub18
  elif [[ $DISTRIB == "focal" ]]; then
    echo "Ubuntu 20.04 Focal detected."
    run_ub20
  else
    echo "We don't support this distribution sorry"
  fi
}

while getopts "r" opt; do
  case ${opt} in
    r )
      echo -e "\n[[ INFO ]] Restart mode... skipping one-time installs\n"
      RESTART_MODE=1
      ;;
  esac
done

run
