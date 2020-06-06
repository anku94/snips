#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#define CSV_FRIENDLY 1
#define IOBENCH_FAST 10
#define IO_DIRECT 1

/* Increase value for larger file sizes */
#define SIZE_FACTOR 10

pthread_barrier_t iobarrier;

double cur_time() {
  timespec t;

  clock_gettime(CLOCK_MONOTONIC, &t);

  double tsec = t.tv_sec + 1e-9 * t.tv_nsec;
  return tsec;
}

void _write_file_direct(const char *file, int block_size, int totalsz_mb) {
  struct stat fstat;
  stat(file, &fstat);

  // fprintf(stderr, "Bufptr: %p, blksize: %d\n", buf, (int) fstat.st_blksize);
  int align = fstat.st_blksize - 1;

  char buf[block_size + align];
  char *aligned_buf = (char *)(((uintptr_t)buf + align) & ~((uintptr_t)align));

  memset(buf, 0xAB, sizeof buf);

  int fd = open(file, O_CREAT | O_WRONLY | O_DIRECT, S_IRUSR | S_IWUSR);
  if (fd < 0) {
    perror("FAILED open");
    return;
  }

  uint64_t totalsz_bytes = totalsz_mb * 1024ull * 1024ull;
  uint64_t totalsz_blocks = totalsz_bytes / block_size;

  assert(totalsz_bytes % block_size == 0ull);

  for (uint64_t bidx = 0; bidx < totalsz_blocks; bidx++) {
    // int ret = write(fd, aligned_buf, block_size);
    int ret = write(fd, aligned_buf, block_size);
    if (ret < 0) {
      perror("FAILED write");
      return;
    }
  }

  close(fd);
}

void _write_file(const char *file, int block_size, int totalsz_mb) {
  char buf[block_size];

  memset(buf, 0xAB, sizeof buf);

  int fd = open(file, O_CREAT | O_WRONLY, S_IRUSR | S_IWUSR);

  if (fd < 0) {
    perror("FAILED open");
    return;
  }

  uint64_t totalsz_bytes = totalsz_mb * 1024ull * 1024ull;
  uint64_t totalsz_blocks = totalsz_bytes / block_size;

  assert(totalsz_bytes % block_size == 0ull);

  for (uint64_t bidx = 0; bidx < totalsz_blocks; bidx++) {
    int ret = write(fd, buf, block_size);
    if (ret < 0) {
      perror("FAILED write");
      return;
    }
  }

  fsync(fd);
  close(fd);
}

void write_file(const char *file, int block_size, int totalsz_mb) {
  double start = cur_time();
#ifdef IO_DIRECT
  _write_file_direct(file, block_size, totalsz_mb);
#else
  _write_file(file, block_size, totalsz_mb);
#endif
  double end = cur_time();

  double delta = end - start;

  double bw_mbps = totalsz_mb / delta;

#ifdef CSV_FRIENDLY
  fprintf(stdout, "%d,%0.2lf MB/s\n", block_size, bw_mbps);
#else
  fprintf(stdout, "Written %d MB (block size %d) @ %.2lf MB/s\n", totalsz_mb,
          block_size, bw_mbps);
#endif
}

void iobench(const char *path) {
  assert(path);

  char full_path[1024];
  snprintf(full_path, 1024, "%s/temp.txt", path);

  fprintf(stdout, "Benchmarking stuff @ %s\n", full_path);

#ifdef IOBENCH_SLOW
  int block_sizes[] = {1, 4, 16, 64, 256, 1024, 4096};
  int file_sizes_mb[] = {10, 40, 100, 100, 100, 100, 100};
#elif IOBENCH_FAST
  int block_sizes[] = {16 * 1024, 64 * 1024, 256 * 1024, 512 * 1024,
                       1024 * 1024};
  int file_sizes_mb[] = {100, 100, 200, 400, 400};
#endif

  int block_size_len = sizeof(block_sizes) / sizeof(block_sizes[0]);
  int file_size_len = sizeof(file_sizes_mb) / sizeof(file_sizes_mb[0]);

  assert(block_size_len == file_size_len);

  for (int bsidx = 0; bsidx < block_size_len; bsidx++) {
    int cur_block_size = block_sizes[bsidx];
    int cur_file_size = file_sizes_mb[bsidx] * SIZE_FACTOR;
    fprintf(stderr, "Benchmarking block size: %d, file size: %dMB\n",
            cur_block_size, cur_file_size);
    write_file(full_path, cur_block_size, cur_file_size);
  }

  return;
}

typedef struct thread_args {
  int thread_id;
  int num_threads;

  double *deltas;

  const char *path;
} thread_args_t;

void aggregate_deltas(double *deltas, int num_threads, int totalsz_mb,
                      int block_size) {
  double delta_min = 1e9;
  double delta_max = 0;

  for (int tidx = 0; tidx < num_threads; tidx++) {
    if (delta_max < deltas[tidx]) {
      delta_max = deltas[tidx];
    }
  }

  double bw_mbps = totalsz_mb * num_threads / delta_max;

#ifdef CSV_FRIENDLY
  fprintf(stdout, "%d,%0.2lf MB/s\n", block_size, bw_mbps);
#else
  fprintf(stdout, "Written %d MB (block size %d) @ %.2lf MB/s\n", totalsz_mb,
          block_size, bw_mbps);
#endif
  return;
}

void *_iobench_thread_worker(void *arg) {
  thread_args_t *targ = static_cast<thread_args_t *>(arg);
  int tid = targ->thread_id;

  // printf("Initializing thread: %d\n", targ->thread_id);

  char full_path[2048];
  snprintf(full_path, 2048, "%s/temp%d.txt", targ->path, rand());

  pthread_barrier_wait(&iobarrier);
  // printf("Opening file: %s\n", full_path);
  pthread_barrier_wait(&iobarrier);

#ifdef IOBENCH_SLOW
  int block_sizes[] = {1, 4, 16, 64, 256, 1024, 4096};
  int file_sizes_mb[] = {10, 40, 100, 100, 100, 100, 100};
#elif IOBENCH_FAST
  int block_sizes[] = {16 * 1024, 64 * 1024, 256 * 1024, 512 * 1024,
                       1024 * 1024};
  int file_sizes_mb[] = {100, 100, 200, 400, 400};
#endif

  int block_size_len = sizeof(block_sizes) / sizeof(block_sizes[0]);
  int file_size_len = sizeof(file_sizes_mb) / sizeof(file_sizes_mb[0]);

  assert(block_size_len == file_size_len);

  for (int bsidx = 0; bsidx < block_size_len; bsidx++) {
    int cur_block_size = block_sizes[bsidx];
    int cur_file_size = file_sizes_mb[bsidx] * SIZE_FACTOR;
    // fprintf(stderr, "Benchmarking block size: %d, file size: %dMB\n",
            // cur_block_size, cur_file_size);

    double start = cur_time();
    _write_file(full_path, cur_block_size, cur_file_size);
    double end = cur_time();

    double delta = end - start;
    targ->deltas[tid] = delta;

    pthread_barrier_wait(&iobarrier);

    if (tid == 0) {
      aggregate_deltas(targ->deltas, targ->num_threads, cur_file_size,
                       cur_block_size);
    }

    pthread_barrier_wait(&iobarrier);
  }

  // printf("Terminating thread: %d\n", targ->thread_id);
  return NULL;
}

void iobench_parallel(const char *path, int num_threads) {
  srand(time(NULL));

  pthread_barrier_init(&iobarrier, NULL, num_threads);

  pthread_t threads[num_threads];
  thread_args_t targs[num_threads];
  double deltas[num_threads];

  printf("Benchmarking with numthreads: %d\n", num_threads);

  for (int tidx = 0; tidx < num_threads; tidx++) {
    thread_args_t *targ = &(targs[tidx]);

    targ->thread_id = tidx;
    targ->num_threads = num_threads;
    targ->deltas = reinterpret_cast<double *>(&deltas);
    targ->path = path;

    pthread_create(&(threads[tidx]), NULL, _iobench_thread_worker, targ);
  }

  for (int tidx = 0; tidx < num_threads; tidx++) {
    pthread_join(threads[tidx], NULL);
  }
}

int main(int argc, char *argv[]) {
  int c;
  extern char *optarg;
  extern int optind;

  char *path = NULL;
  int num_threads = 1;

  while ((c = getopt(argc, argv, "p:t:")) != -1) {
    switch(c) {
      case 'p':
        path = optarg;
        break;
      case 't':
        num_threads = atoi(optarg);
        break;
    }
  }

  if (!path) {
    printf("\n\tUsage: %s -p <path> [-t num_threads]\n\n", argv[0]);
    return 0;
  }

  struct stat path_stat;
  int rv = stat(path, &path_stat);
  if (rv) {
    perror("Path Error");
    return -1;
  }

  if (!S_ISDIR(path_stat.st_mode)) {
    printf("Path %s is not a valid directory\n", path);
    return -1;
  }


  printf("Benchmarking path: %s, threads: %d\n", path, num_threads);

  if (num_threads == 1) {
    iobench(path);
  } else {
    iobench_parallel(path, num_threads);
  }

  return 0;
}
