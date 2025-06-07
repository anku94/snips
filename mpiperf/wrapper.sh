#!/usr/bin/env bash

echo "Rank: $PMI_RANK"
echo $MPI_LOCALNRANKS
echo $MPI_LOCALRANKID
echo $PMI_RANK
echo $PMI_FD
echo $PMI_SIZE

./mpihelloworld
