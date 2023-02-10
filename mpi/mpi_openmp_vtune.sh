#!/usr/bin/env bash

MPI_MVAPICH=/users/ankushj/repos/amr-workspace/install/bin
MPI_ROOT=$MPI_MVAPICH
MPICC=$MPI_ROOT/mpicc
MPICXX=$MPI_ROOT/mpicxx
MPIRUN=$MPI_ROOT/mpirun

build() {
  $MPICXX ../heart_demo.cpp ../luo_rudy_1991.cpp ../rcm.cpp ../mesh.cpp -g -o heart_demo -O3 -std=c++11 -fopenmp -lm
}

add_env_var() {
  envstr="$envstr -env $1=$2"
}

run_vtune() {
  source /opt/intel/oneapi/vtune/2021.9.0/amplxe-vars.sh

  NNODES=4
  NTHREADS=4 # thread/rank for OpenMP

  NCORES=16
  PPN=$(( NCORES / NTHREADS ))

  envstr=""
  add_env_var LD_LIBRARY_PATH /usr/lib64
  add_env_var OMP_NUM_THREADS $NTHREADS
  add_env_var MV2_CPU_BINDING_POLICY hybrid
  add_env_var MV2_THREADS_PER_PROCESS $NTHREADS
  add_env_var MV2_HYBRID_BINDING_POLICY spread

  JOBDIR=vtune_mpi_1
  rm -rf $JOBDIR* && /bin/true

  MPISTR="$MPIRUN -f hosts.txt -np $(( NNODES * PPN )) -ppn $PPN $envstr"
  PROFSTR="vtune -collect hpc-performance -r $JOBDIR --"
  APPSTR="./heart_demo -m ../mesh_mid -s ../setup_mid.txt -t 100"

  CMD="$MPISTR $PROFSTR $APPSTR"
  echo $CMD
  $CMD
}

run_aps() {
  source /opt/intel/oneapi/vtune/2021.9.0/amplxe-vars.sh
  export OMP_NUM_THREADS=4
  # $MPIRUN -np 16 -ppn 4 -env LD_LIBRARY_PATH=/usr/lib64 aps vtune_mpi -- ./heart_demo -m ../mesh_mid -s ../setup_mid.txt -t 100
}

analyze_1() {
  # vtune -report top-down -r $VTUNE_OUT
  vtune -report callstacks -r $VTUNE_OUT
}

main() {
  VTUNE_OUT=vtune_mpi.h0.amrib34.tablefs.narwhal.pdl.cmu.edu
  # build
  run_vtune
  # run_aps
  # analyze_1
}

main
