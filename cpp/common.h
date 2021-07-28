#pragma once

#define KB(x) (1024 * (x))
#define MB(x) KB(KB(x))
#define GB(x) MB(KB(x))

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

void init_rand(int* f, int n) {
  for (int i = 0; i < n; i++) {
    f[i] = rand() * i;
  }
}
