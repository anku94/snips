/*
 * Dennis Lo, Ankush Jain
 */

#include <errno.h>
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

constexpr int READS_THRESHOLD = 1e5;
constexpr int NUM_ITERS = 20;
constexpr int FNAME_SZ = 1024;
constexpr int CHUNK_SZ = 4;

double cur_time() {
  timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec + 1e-9 * t.tv_nsec;
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <path_to_prefix>\n", argv[0]);
    return 0;
  }

  MPI_Init(&argc, &argv);

  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  /* Get number of procs */
  int world_sz = 0;
  if (rank == 0) {
    MPI_Comm_size(MPI_COMM_WORLD, &world_sz);
  }

  /* Open corresponding file to be read */
  char fname[FNAME_SZ];
  snprintf(fname, FNAME_SZ, "%s.%d", argv[1], rank);
  FILE *file = fopen(fname, "r");

  if (file == NULL) {
    fprintf(stderr, "Tried to open: %s\n", fname);
    perror("Unable to open file");
    return -1;
  }

  char buf[CHUNK_SZ];
  int tmp_xor = 0, reads = 0;
  double start = cur_time(), local_elapsed = 0, global_elapsed;
  double global_elapsed_aggr = 0;

  while (fread(buf, 4, 1, file) > 0) {
    tmp_xor ^= buf[0];
    /* Compute aggregate throughput */
    if ((++reads % READS_THRESHOLD) == 0) {
      double curr = cur_time();
      local_elapsed = curr - start;
      start = curr;
      MPI_Reduce(&local_elapsed, &global_elapsed, 1, MPI_DOUBLE, MPI_SUM, 0,
                 MPI_COMM_WORLD);

      /* mean time taken */
      global_elapsed /= world_sz;
      global_elapsed_aggr += global_elapsed;

      if (rank == 0) {
        printf("Throughput: %d %dB-reads / %.2fms = %.2fMiB/s\n",
               world_sz * READS_THRESHOLD, CHUNK_SZ, global_elapsed * 1000,
               world_sz * READS_THRESHOLD * CHUNK_SZ /
                   (1024 * 1024 * global_elapsed));
      }
    }

    if (reads / READS_THRESHOLD == NUM_ITERS) break;
  }

  if (rank == 0) {
    printf("---\nAggregate Throughput: %d %dB-reads / %.2fms = %.2fMiB/s\n",
           NUM_ITERS * world_sz * READS_THRESHOLD, CHUNK_SZ,
           global_elapsed_aggr * 1000,
           NUM_ITERS * world_sz * READS_THRESHOLD * CHUNK_SZ /
               (1024 * 1024 * global_elapsed_aggr));
  }

  MPI_Finalize();
}
