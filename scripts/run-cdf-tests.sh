#!/bin/bash 

export DUMP=0

NUMKEYS=(1 2 4 8 16)
# NUMKEYS=1
# NUMKEYS=16
# NUMBITS_RANGE=(8 16 24 32)
NUMBITS_RANGE=(1 2 4 8)
# NUMBITS_RANGE=(12)
# NUMPROCS_RANGE=( 2 8 32 64 96 128 )
NUMPROCS_RANGE=(128 512 2048 4096 8192 16384)
NUMPROCS_RANGE=(128)
#NUMKEYS=

for NUMBITS in ${NUMBITS_RANGE[@]};
do
  for NUMPROCS in ${NUMPROCS_RANGE[@]};
  do
    echo ==========================================
    echo Running for $NUMPROCS nodes, $NUMBITS bits

    export KI_RANKS=$NUMPROCS
    export MI_KEYS=$NUMKEYS
    export BF_BITS_PER_KEY=$NUMBITS
    export QUERY_STEP=2

    dump_file=$1/bf_cdf_test.keys$NUMKEYS.bits$NUMBITS.ranks$NUMPROCS
    echo Writing output to $dump_file

    echo /users/ankushj/deltafs/build/src/libdeltafs/deltafs_api_test --bench=kv$NUMBITS
    /users/ankushj/deltafs/build/src/libdeltafs/deltafs_api_test --bench=kv$NUMBITS 2> $dump_file 1> $dump_file
  done
done
