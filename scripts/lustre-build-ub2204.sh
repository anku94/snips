#!/usr/bin/env bash

git_clone_thru_proxy() {
  echo '/usr/bin/corkscrew proxy.pdl.cmu.edu 3128 $1 $2' > ~/CRAP/gitproxy
  chmod +x ~/CRAP/gitproxy
  git -c core.gitproxy'~/CRAP/gitproxy' clone $1
}

list_kernels() {
  uname -a
  apt list | grep linux-image-5.15 | grep generic
  version=5.15.0-92-generic
  sudo apt install -y linux-image-$version linux-headers-$version

  grep menuentry /boot/grub/grub.cfg
  sudo grub-set-default "Ubuntu, with Linux $version"
  sudo update-grub
  sudo grub-editenv list
}

install_deps() {
  sudo apt install -y socat libyaml-dev \
    module-assistant dpatch libsnmp-dev mpi-default-dev \
    libreadline-dev quilt \
    libkeyutils-dev \
    libmount1 libmount-dev \
    libnl-genl-3-dev \
    swig
}

build_lustre() {
  cd /l0
  git_clone_thru_proxy https://git.whamcloud.com/fs/lustre-release.git
  cd lustre-release
  git checkout 2.15.5
  sh autogen.sh
  ./configure --disable-server --enable-client --with-o2ib=yes
  make -j debs
}
