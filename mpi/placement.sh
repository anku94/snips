#!/usr/bin/env bash

# XXX: All prefixes must end with a trailing slash

MVAPICH_PREFIX="/users/ankushj/repos/amr-workspace/install/"
OMPI_PREFIX="/users/ankushj/repos/amr-workspace/ompi-root/install/"

MPITYPE="mvapich"
# MPITYPE="openmpi"

setup_mpi() {
  if [[ "$MPITYPE" == "mvapich" ]]; then
    MPI_PREFIX="$MVAPICH_PREFIX"
  elif [[ "$MPITYPE" == "openmpi" ]]; then
    MPI_PREFIX="$OMPI_PREFIX"
  else
    MPI_PREFIX=""
  fi

  MPICC="${MPI_PREFIX}/bin/mpicc"
  MPICXX="${MPI_PREFIX}/bin/mpicxx"
  MPIRUN="${MPI_PREFIX}/bin/mpirun"

  echo "[MPICC] $MPICC"
  echo "[MPICXX] $MPICC"
  echo "[MPIRUN] $MPIRUN"
}

add_env_var() {
  if [[ "$MPITYPE" == "openmpi" ]]; then
    env_flag="-x"
    env_sep="="
  else
    env_flag="-env"
    env_sep=" "
  fi

  ENV_STR="$ENV_STR $env_flag ${1}${env_sep}${2}"
}

add_common_env() {
  ENV_STR=""
  add_env_var OMP_NUM_THREADS 1
  add_env_var LD_LIBRARY_PATH /usr/lib64
}

run_cmd() {
  echo -e "\n[CMD] $cmd\n"
  $cmd
}

build_mvapich() {
  $MPICXX -o placement -fopenmp placement.cc
}

mapbystd_mvapich() {
  # setopt clobber
  echo -e "h0-dib:4\nh1-dib:4" > hosts.txt

  # mpirun -f hosts.txt -env OMP_NUM_THREADS 1 -np 8 ./placement
  cmd="$MPIRUN -f hosts.txt $ENV_STR -np 8 -map-by machine ./placement"
  # run_cmd

  cmd="$MPIRUN -f hosts.txt $ENV_STR -np 8 -bind-to rr -map-by socket ./placement"
  run_cmd

}

mapbyrr_mvapich() {
  # setopt clobber
  echo -e "h0-dib:2\nh1-dib:2\nh0-dib:2\nh1-dib:2" > hosts.txt

  cmd="$MPIRUN -f hosts.txt $ENV_STR -np 8 ./placement"
  run_cmd
}

run_mvapich() {
  build_mvapich
  # mapbystd_mvapich
  mapbyrr_mvapich
}

build_ompi() {
  $MPICXX -o placement -fopenmp placement.cc
}

mapbystd_ompi() {
  echo -e "h0-dib slots=4\nh1-dib slots=4" > hosts.txt

  $MPIRUN -hostfile hosts.txt $ENV_STR -np 8 ./placement
  $MPIRUN -hostfile hosts.txt $ENV_STR -np 8 ./placement
}

mapbyrr_ompi() {
  echo -e "h0-dib slots=4\nh1-dib slots=4" > hosts.txt

  cmd="$MPIRUN -hostfile hosts.txt $ENV_STR -np 8 -map-by node ./placement"
  run_cmd

  cmd="$MPIRUN -hostfile hosts.txt $ENV_STR -np 8 -map-by slot -rank-by node ./placement"
  run_cmd
}

run_ompi() {
  build_ompi
  # mapbystd_ompi
  mapbyrr_ompi
}

run() {
  setup_mpi
  add_common_env

  if [[ "$MPITYPE" == "mvapich" ]]; then
    run_mvapich
  elif [[ "$MPITYPE" == "openmpi" ]]; then
    run_ompi
  else
    echo "Unknown MPI type"
  fi
}

run
