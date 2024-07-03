#include "common.h"

#include <dirent.h>
#include <fcntl.h>
#include <sched.h>
#include <stdarg.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <time.h>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>

uint64_t timeval_to_micros(const struct timeval* tv) {
  uint64_t t;
  t = static_cast<uint64_t>(tv->tv_sec) * 1000000;
  t += tv->tv_usec;
  return t;
}

#define PRELOAD_USE_CLOCK_GETTIME

uint64_t now_micros() {
  uint64_t t;

#if defined(__linux) && defined(PRELOAD_USE_CLOCK_GETTIME)
  struct timespec tp;

  clock_gettime(CLOCK_MONOTONIC, &tp);
  t = static_cast<uint64_t>(tp.tv_sec) * 1000000;
  t += tp.tv_nsec / 1000;
#else
  struct timeval tv;

  gettimeofday(&tv, NULL);
  t = timeval_to_micros(&tv);
#endif

  return t;
}

uint64_t now_micros_coarse() {
  uint64_t t;

#if defined(__linux) && defined(PRELOAD_USE_CLOCK_GETTIME)
  struct timespec tp;

  clock_gettime(CLOCK_MONOTONIC_COARSE, &tp);
  t = static_cast<uint64_t>(tp.tv_sec) * 1000000;
  t += tp.tv_nsec / 1000;
#else
  struct timeval tv;

  gettimeofday(&tv, NULL);
  t = timeval_to_micros(&tv);
#endif

  return t;
}

void check_clockres() {
  int n;
#if defined(__linux) && defined(PRELOAD_USE_CLOCK_GETTIME)
  struct timespec res;
  n = clock_getres(CLOCK_MONOTONIC_COARSE, &res);
  if (n == 0) {
    flog(LOG_INFO, "[clock] CLOCK_MONOTONIC_COARSE: %d us",
         int(res.tv_sec * 1000 * 1000 + res.tv_nsec / 1000));
  }
  n = clock_getres(CLOCK_MONOTONIC, &res);
  if (n == 0) {
    flog(LOG_INFO, "[clock] CLOCK_MONOTONIC: %d ns",
         int(res.tv_sec * 1000 * 1000 * 1000 + res.tv_nsec));
  }
#endif
}

int flog_io(int lvl, const char* fmt, ...) {
  /* flog() macro should have already filtered on LOG_LEVEL */

  const char* prefix;
  va_list ap;
  switch (lvl) {
    case LOG_ERRO:
      prefix = "!!! ERROR !!! ";
      break;
    case LOG_WARN:
      prefix = "-WARNING- ";
      break;
    case LOG_INFO:
      prefix = "-INFO- ";
      break;
    case LOG_DBUG:
      prefix = "-DEBUG- ";
      break;
    default:
      prefix = "";
      break;
  }
  fprintf(stderr, "%s", prefix);

  va_start(ap, fmt);
  vfprintf(stderr, fmt, ap);
  va_end(ap);

  fprintf(stderr, "\n");
  return 0;
}

int loge(const char* op, const char* path) {
  flog(LOG_ERRO, "!%s(%s): %s", strerror(errno), op, path);
  return 0;
}

void msg_abort(int err, const char* msg, const char* func, const char* file,
               int line) {
  fputs("*** ABORT *** ", stderr);
  fprintf(stderr, "@@ %s:%d @@ %s] ", file, line, func);
  fputs(msg, stderr);
  if (err != 0) fprintf(stderr, ": %s (errno=%d)", strerror(err), err);
  fputc('\n', stderr);
  abort();
}
