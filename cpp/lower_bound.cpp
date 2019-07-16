#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <algorithm>
#include <chrono>

#define NUMBINS 15000
#define NUMTESTS 1000000

float bins[NUMBINS];
float queries[NUMTESTS];

void gen_bins(float start, float max_width, int num) {
  int bidx = 0;
  float prev = start;
  while (bidx < num) {
    bins[bidx] = prev;
    prev += (rand() * 1.0f / RAND_MAX) * max_width;
    bidx += 1;
  }

#if DEBUG
  for (int i = 0; i < num; i++) {
    fprintf(stdout, "Bidx %d: %f\n", i, bins[i]);
  }
#endif
}

void gen_queries() {
  for (int i = 0; i < NUMTESTS; i++) {
    queries[i] = rand() * 1.0 / RAND_MAX * NUMBINS * 2;
  }
}

int lower_bound(int len, float key, int debug = 0) {
  int start = 0;
  int end = len - 1;

  int mid = -1;
  if (bins[0] > key) return mid;

  while (start <= end) {
    mid = start + (end - start) / 2;
    if (bins[mid] > key) {
      end = mid - 1;
    } else if (bins[mid] == key) {
      return mid - 1;
    } else {
      if (mid + 1 < len && bins[mid + 1] > key) {
        return mid;
      }
      start = mid + 1;
    }
  }

  return mid;
}

int main(int argc, char *argv[]) {
  gen_bins(0, 1, NUMBINS);
  gen_queries();

  int xt = 0;
  int yt = 0;

  auto astart = std::chrono::high_resolution_clock::now();

  for (int tidx = 0; tidx < NUMTESTS; tidx++) {
    int x = lower_bound(NUMBINS, queries[tidx]);
    xt += x;
  }

  auto aend = std::chrono::high_resolution_clock::now();
  uint64_t atime =
      std::chrono::duration_cast<std::chrono::nanoseconds>(aend - astart)
          .count();
  auto bstart = std::chrono::high_resolution_clock::now();

  for (int tidx = 0; tidx < NUMTESTS; tidx++) {
    int y = std::lower_bound(bins, bins + NUMBINS, queries[tidx]) - bins - 1;
    yt += y;
  }

  auto bend = std::chrono::high_resolution_clock::now();
  uint64_t btime =
      std::chrono::duration_cast<std::chrono::nanoseconds>(bend - bstart)
          .count();

  fprintf(stderr, "Result total (Assert equal): \t%d %d\n", xt, yt);

  fprintf(stderr,
          "Perop times: (%d iters, %d bins)\n"
          "\t Our lower bound: \t%.1lfns\n"
          "\t Stdlib lower bound: \t%.1lfns\n",
          NUMTESTS, NUMBINS, atime * 1.0 / NUMTESTS, btime * 1.0 / NUMTESTS);

  return 0;
}
