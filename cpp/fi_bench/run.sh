#!/usr/bin/env bash

RDMA_CORE_PREFIX=/users/ankushj/snips/cpp/fi_bench/libfabric/rdma-core-50.0
FI_PREFIX=/users/ankushj/snips/cpp/fi_bench/libfabric/fab-prefix

# export LD_LIBRARY_PATH=$RDMA_CORE_PREFIX/build/lib:$FI_PREFIX/lib
# $FI_PREFIX/bin/fi_info
#
RDMA_CORE_PKGCONFIG_PATH=$RDMA_CORE_PREFIX/build/lib/pkgconfig
FI_PKGCONFIG_PATH=$FI_PREFIX/lib/pkgconfig

export PKG_CONFIG_PATH=$RDMA_CORE_PKGCONFIG_PATH:$FI_PKGCONFIG_PATH:$PKG_CONFIG_PATH
mkdir -p build
cd build
cmake ..
