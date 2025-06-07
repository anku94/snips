#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include <algorithm>

static constexpr int kNumTries = 3;

typedef struct {
  float f;
  char c[36];
} direct_t;

typedef struct {
  float f;
  int i;
} indirect_t;

class direct_comp {
 public:
  bool operator()(const direct_t& a, const direct_t& b) { return a.f < b.f; }
};

class indirect_comp {
 public:
  bool operator()(const indirect_t& a, const indirect_t& b) { return a.f < b.f; }
};

double cur_time() {
  timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  double tsec = t.tv_sec + 1e-9 * t.tv_nsec;
  return tsec;
}

void init_rand(float* f, int n) {
  for (int i = 0; i < n; i++) {
    f[i] = rand() * i;
  }
}

void init_rand(direct_t* d, int n) {
  for (int i = 0; i < n; i++) {
    d[i].f = rand() * i;
  }
}

void init_rand(indirect_t* d, int n) {
  for (int i = 0; i < n; i++) {
    d[i].f = rand() * i;
  }
}

void init_indirect(direct_t* d, indirect_t* id, int n) {
  for (int i = 0; i < n; i++) {
    d[i].f = rand() * i;
    id[i].f = d[i].f;
    id[i].i = i;
  }
}

void dump_direct(direct_t* d, int n) {
  FILE* f = fopen("/dev/shm/direct.bin", "wb+");
  fwrite(d, sizeof(direct_t), n, f);
  fclose(f);
}

void dump_indirect(direct_t* d, indirect_t* id, int n) {
  FILE* f = fopen("/dev/shm/indirect.bin", "wb+");
  for (int i = 0; i < n; i++) {
    fwrite(&d[id[i].i], sizeof(direct_t), 1, f);
  }
  fclose(f);
}

void sort_bench_indirect() {
  const size_t data_sz = 2621440;
  direct_t* data = new direct_t[data_sz];
  indirect_t* idata = new indirect_t[data_sz];

  double total_init = 0, total_sort = 0;

  for (int try_idx = 0; try_idx < kNumTries; try_idx++) {
    double iter_start = cur_time();
    init_indirect(data, idata, data_sz);
    double init_time = cur_time() - iter_start;
    std::sort(idata, idata + data_sz, indirect_comp());
    dump_indirect(data, idata, data_sz);
    double sort_time = cur_time() - iter_start - init_time;

    printf("Indirect[%d]: Init: %.3lfs, Sort: %.3lfs\n", try_idx, init_time,
           sort_time);
  }

  delete[] idata;
  delete[] data;
}

void sort_bench_direct() {
  const size_t data_sz = 2621440;
  direct_t* data = new direct_t[data_sz];

  double total_init = 0, total_sort = 0;

  for (int try_idx = 0; try_idx < kNumTries; try_idx++) {
    double iter_start = cur_time();
    init_rand(data, data_sz);
    double init_time = cur_time() - iter_start;
    std::sort(data, data + data_sz, direct_comp());
    dump_direct(data, data_sz);
    double sort_time = cur_time() - iter_start - init_time;

    printf("Direct[%d]: Init: %.3lfs, Sort: %.3lfs\n", try_idx, init_time,
           sort_time);
  }

  delete[] data;
}

int main() {
  sort_bench_direct();
  sort_bench_indirect();
}
