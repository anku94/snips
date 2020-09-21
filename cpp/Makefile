CC=g++
MPICC=mpic++

all: iobench mutbench panfs_bench
	echo done

iobench: iobench.cpp
	$(CC) -o iobench iobench.cpp -lpthread

mutbench: mutex_bench.cpp
	$(CC) -o mutex_bench mutex_bench.cpp -lpthread

panfs_bench: panfs_bench.cc
	$(MPICC) -o panfs_bench panfs_bench.cc
