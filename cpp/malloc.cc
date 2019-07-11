#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <chrono>

int main(int argc, char *argv[]) {
  int iters = 1000 * 1000; // 1M
  int allocsize = 64;

  if (argc > 1) {
    iters = atoi(argv[1]);
  }

  if (argc > 2) {
    allocsize = atoi(argv[2]);
  }

  fprintf(stderr, "Malloc()ing for %d iters, with %d bytes\n", iters, allocsize);

  char a[64];
  memset(a, 'x', 64);

  int **ptrs = new int*[iters];
  auto qgenstart = std::chrono::high_resolution_clock::now();

  for (int idx = 0; idx < iters; idx++) {
    ptrs[idx] = (int *)malloc(allocsize);
    memcpy(ptrs[idx], a, (allocsize < 64 ? allocsize : 64));
  }

  auto qgenend = std::chrono::high_resolution_clock::now();
  uint64_t qgentime =
      std::chrono::duration_cast<std::chrono::nanoseconds>(qgenend - qgenstart)
          .count();

  int randprint = rand() % iters;
  for (int idx = 0; idx < iters; idx++) {
    if (idx == randprint) {
      fprintf(stdout, "random value: %s\n", (char *)ptrs[idx]);
    }
    free(ptrs[idx]);
  }

  fprintf(stderr, "Total time taken: %lu ns\n", qgentime);
  fprintf(stderr, "Per-op time taken: %lf ns\n", qgentime * 1.0 / iters);
  return 0;
}
