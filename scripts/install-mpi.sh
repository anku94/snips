#!/bin/bash

set -euxo pipefail

OPENMPI_PACKAGES=( openmpi-common libopenmpi2 openmpi-bin )
MPICH_PACKAGES=( libmpich-dev libmpich12 mpich )

get_arr_str() {
  arr=("$@")

  for package in ${arr[@]};
  do
    echo -n "$package " 
  done
  echo
}

apt_install_pkglist() {
  sudo apt install -y $(echo $1)
}

apt_remove_pkglist() {
  sudo apt remove -y $(echo $1)
}

OPENMPI_STR=$(get_arr_str "${OPENMPI_PACKAGES[@]}")
MPICH_STR=$(get_arr_str "${MPICH_PACKAGES[@]}")

if [[ "$1" = "mpich" ]]; then
  REMOVE=$OPENMPI_STR
  INSTALL=$MPICH_STR
elif [[ "$1" = "openmpi" ]]; then
  echo openmpi
  REMOVE=$MPICH_STR
  INSTALL=$OPENMPI_STR
else
  echo "$0 [openmpi|mpich]"
  exit 0
fi

apt_remove_pkglist "$REMOVE"
apt_install_pkglist "$INSTALL"
