#include <cassert>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <algorithm>
#include <vector>

#define DTYPE double

const DTYPE rstart = -100.0;
const DTYPE rend = 100.0;

volatile int CACHESUM = 0;
volatile int volglob = 0;

const int INTCACHESZ = 1024 * 1024 * 32;  // (32M ints, 128MB)

void flush_cache() {
  CACHESUM = 0;

  int bigcache = 16 * INTCACHESZ;
  int *p = new int[bigcache];
  memset(p, 0x1, sizeof p);

  for (int i = 0; i < bigcache; i++) {
    CACHESUM += p[i];
  }

  asm volatile("mfence \n"
      "lfence \n"
      :
      :
      : "memory");

  fprintf(stderr, "[Cache Flush %zu] Sinking result: %d\n", sizeof p, CACHESUM);

  delete p;

  return;
}

char print_buffer[256];
char *print_time(const uint64_t ns, int items) {
  char big_units[10];
  char small_units[10];

  double big_time;
  double small_time;

  if (ns > 1000 * 1000 * 1000) {
    sprintf(big_units, "s");
    big_time = ns * 1.0 / (1000 * 1000 * 1000);
  } else if (ns > 1000 * 1000) {
    sprintf(big_units, "ms");
    big_time = ns * 1.0 / (1000 * 1000);
  } else {
    sprintf(big_units, "us");
    big_time = ns * 1.0 / 1000;
  }

  small_time = ns * 1.0 / items;

  if (small_time > 1000 * 1000) {
    sprintf(small_units, "ms");
    small_time /= (1000 * 1000);
  } else if (small_time > 1000) {
    sprintf(small_units, "us");
    small_time /= 1000;
  } else {
    sprintf(small_units, "ns");
  }

  sprintf(print_buffer, "%0.1lf %s (%0.1lf %s/op)", big_time, big_units,
          small_time, small_units);

  return print_buffer;
}

template <typename FT>
FT arr_sum(FT *arr, int n) {
  FT temp = 0;
  for (int idx = 0; idx < n; idx++) {
    temp += arr[idx];
  }
  return temp;
}

template <typename FT>
FT arr_sum(std::vector<FT> &arr, int n) {
  FT temp = 0;
  for (int idx = 0; idx < n; idx++) {
    temp += arr[idx];
  }
  return temp;
}

template <typename FT>
FT randf_range(FT start, FT end) {
  FT rand01 = static_cast<FT>(rand()) / static_cast<FT>(RAND_MAX);

  return (end - start) * rand01 + start;
}

template <typename FT>
FT randf(FT bin_width, int percent_i) {
  FT rand01 = static_cast<FT>(rand()) / static_cast<FT>(RAND_MAX);

  double percent_d = percent_i / 100.0;

  return (bin_width * percent_d) + rand01 * bin_width * (1 - percent_d);
}

template <typename FT>
void run(int nbins, int nq) {
  // FT bins[nbins];
  // FT *bins = static_cast<FT *>(malloc(sizeof(FT) * nbins));
  std::vector<FT> bins;
  bins.resize(nbins);

  FT bin_width = (rend - rstart) / nbins;

  FT prev = rstart;
  for (int idx = 0; idx < nbins; idx++) {
    bins[idx] = prev;
    prev += randf<FT>(bin_width, 50);
#ifdef VERBOSE
    fprintf(stderr, "bin[%d]: %lf\n", idx, bins[idx]);
#endif
  }

  auto qgenstart = std::chrono::high_resolution_clock::now();

  FT qsum = 0;
  for (int idx = 0; idx < nq; idx++) {
    FT query = randf_range<FT>(rstart, rend);
#ifdef VERBOSE
    fprintf(stderr, "Query %d: %lf\n", idx, query);
#endif
    qsum += query;
  }

  auto qgenend = std::chrono::high_resolution_clock::now();
  uint64_t qgentime =
      std::chrono::duration_cast<std::chrono::nanoseconds>(qgenend - qgenstart)
          .count();

  fprintf(stderr, "Total query sum: %lf\n", qsum);
  fprintf(stderr, "Time taken to generate %d queries: %s\n", nq,
          print_time(qgentime, nq));

  double asum = 0;
  // cache bins
  bins[0] = bins[0] - bin_width;
  asum += arr_sum(bins, nbins);
  bins[0] = bins[0] - bin_width;
  asum += arr_sum(bins, nbins);
  bins[0] = bins[0] - bin_width;

  // flush_cache();

  auto memrstart = std::chrono::high_resolution_clock::now();
  asum += arr_sum<double>(bins, nbins);
  auto memrend = std::chrono::high_resolution_clock::now();
  uint64_t memrtime =
      std::chrono::duration_cast<std::chrono::nanoseconds>(memrend - memrstart)
          .count();

  fprintf(stderr, "Total bin sum: %lf\n", qsum);
  fprintf(stderr, "Time taken for %d cache reads: %s\n", nbins,
          print_time(memrtime, nbins));

  std::vector<double>::iterator bidx;

  auto lboundstart = std::chrono::high_resolution_clock::now();
  for (int idx = 0; idx < nbins; idx++) {
    FT q = randf_range(rstart, rend);
    bidx = std::lower_bound(bins.begin(), bins.end(), q);
    volglob += (bidx -bins.begin());

#ifdef VERBOSE
    fprintf(stderr, "Query %d: %lf, Bucket %ld\n", idx, q, bidx - bins.begin());
#endif
  }
  auto lboundend = std::chrono::high_resolution_clock::now();
  uint64_t lboundtime = 
      std::chrono::duration_cast<std::chrono::nanoseconds>(lboundend - lboundstart)
          .count();

  fprintf(stderr, "Time taken for %d lbound calls: %s\n", nbins,
          print_time(lboundtime, nbins));
}

int main(int argc, char *argv[]) {
  assert(argc == 3);

  int num_elems = atoi(argv[1]);
  int num_queries = atoi(argv[2]);

  fprintf(stderr, "Running std::lower_bound() tests on %d elems, %d queries\n",
          num_elems, num_queries);

  srand(time(NULL));
  run<DTYPE>(num_elems, num_queries);
  return 0;
}
