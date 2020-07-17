CC=g++

all: iobench mutbench
	echo done

iobench: iobench.cpp
	$(CC) -o iobench iobench.cpp -lpthread

mutbench: mutex_bench.cpp
	$(CC) -o mutex_bench mutex_bench.cpp -lpthread
