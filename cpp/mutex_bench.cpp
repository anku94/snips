#include <pthread.h>
#include <stdio.h>
#include <time.h>

double cur_time() {
  timespec t;

  clock_gettime(CLOCK_MONOTONIC, &t);

  double tsec = t.tv_sec + 1e-9 * t.tv_nsec;
  return tsec;
}

int main() {
  pthread_mutex_t mtx = PTHREAD_MUTEX_INITIALIZER;

  long int idx, count = 16000000;

  double start_time = cur_time();

  int x = 0;

  for (idx = 0; idx < count; idx++) {
    pthread_mutex_lock(&mtx);
    x++;
    pthread_mutex_unlock(&mtx);
  }

  double end_time = cur_time();

  printf("Dummy print: %d\n", x);
  printf("Time taken for %ld lock/unlock cycles: %.2f s\n", count, end_time - start_time);

  return 0;
}
