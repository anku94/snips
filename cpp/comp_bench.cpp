#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <algorithm>

#include "common.h"

/* bytewise comparator from themis_tritonsort */
static inline int compare(const uint8_t* data1, uint64_t len1,
                          const uint8_t* data2, uint32_t len2) {
  // Iterate byte by byte up to the length of the smaller datum, checking
  // ordering
  for (uint32_t minLength = std::min<uint32_t>(len1, len2); minLength != 0;
       ++data1, ++data2, --minLength) {
    if (*data1 != *data2) {
      return *data1 - *data2;
    }
  }

  // Both byte streams are equal up to minLength
  // Order the shorter one before the longer
  return len1 - len2;
}

class BytewiseComparator {
  public:
    bool operator()(const float& a, const float& b) {
      const uint8_t* aptr = reinterpret_cast<const uint8_t*>(&a);
      const uint8_t* bptr = reinterpret_cast<const uint8_t*>(&b);
      return compare(aptr, sizeof(float), bptr, sizeof(float)) < 0;
    }
};

void comp_bench_int() {
  const size_t data_sz = MB(100);
  const size_t data_cnt = data_sz / sizeof(int);

  int* keys = new int[data_cnt];

  const int kNumTries = 3;

  double total_sort_time = 0;

  for (int try_idx = 0; try_idx < kNumTries; try_idx++) {
    double iter_start = cur_time();
    init_rand(keys, data_cnt);
    double init_time = cur_time() - iter_start;
    std::sort(keys, keys + data_cnt);
    double sort_time = cur_time() - iter_start - init_time;

    printf("NOOPT: %d %d\n", keys[0], keys[data_cnt - 1]);
    printf("[INTCMP][%d]: Init: %.3lfs, Sort: %.3lfs\n", try_idx, init_time,
           sort_time);
    total_sort_time += sort_time;
  }

  printf("\n\t[INTCMP] Avg. Sort: %.3lfs\n\n", total_sort_time / kNumTries);

  delete[] keys;
}

void comp_bench_float() {
  const size_t data_sz = MB(100);
  const size_t data_cnt = data_sz / sizeof(float);

  float* keys = new float[data_cnt];

  const int kNumTries = 3;
  double total_sort_time = 0;

  for (int try_idx = 0; try_idx < kNumTries; try_idx++) {
    double iter_start = cur_time();
    init_rand(keys, data_cnt);
    double init_time = cur_time() - iter_start;
    std::sort(keys, keys + data_cnt);
    double sort_time = cur_time() - iter_start - init_time;

    printf("NOOPT: %.1f %.1f\n", keys[0], keys[data_cnt - 1]);
    printf("[FLTCMP][%d]: Init: %.3lfs, Sort: %.3lfs\n", try_idx, init_time,
           sort_time);

    total_sort_time += sort_time;
  }

  printf("\n\t[FLTCMP] Avg. Sort: %.3lfs\n\n", total_sort_time / kNumTries);
  delete[] keys;
}

void comp_bench_float_bytewise() {
  const size_t data_sz = MB(100);
  const size_t data_cnt = data_sz / sizeof(float);

  float* keys = new float[data_cnt];

  const int kNumTries = 3;
  double total_sort_time = 0;

  for (int try_idx = 0; try_idx < kNumTries; try_idx++) {
    double iter_start = cur_time();
    init_rand(keys, data_cnt);
    double init_time = cur_time() - iter_start;
    std::sort(keys, keys + data_cnt, BytewiseComparator());
    double sort_time = cur_time() - iter_start - init_time;

    printf("NOOPT: %.1f %.1f\n", keys[0], keys[data_cnt - 1]);
    printf("[BYTCMP][%d]: Init: %.3lfs, Sort: %.3lfs\n", try_idx, init_time,
           sort_time);

    total_sort_time += sort_time;
  }

  printf("\n\t[BYTCMP] Avg. Sort: %.3lfs\n\n", total_sort_time / kNumTries);

  delete[] keys;
}

int main() {
  comp_bench_int();
  comp_bench_float();
  comp_bench_float_bytewise();
  return 0;
}
