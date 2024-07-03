#pragma once

#include <cstdint>

/* get the current time in us. */
uint64_t now_micros();

/* get the current time in us with fast but coarse-grained timestamps. */
uint64_t now_micros_coarse();

/* convert posix timeval to micros */
uint64_t timeval_to_micros(const struct timeval* tv);

#define LOG_ERRO 5
#define LOG_WARN 4
#define LOG_INFO 3
#define LOG_DBUG 2
#define LOG_DBG2 1

/* only levels >= LOG_LEVEL are printed */
#ifndef LOG_LEVEL
#define LOG_LEVEL LOG_INFO
#endif

/* flog: macro to apply filtering before evaluating log args */
#define flog(LEVEL, ...) do {                                       \
    if ((LEVEL) >= LOG_LEVEL)                                       \
        flog_io((LEVEL), __VA_ARGS__);                              \
    } while (0)


int flog_io(int lvl, const char* fmt, ...);
int loge(const char* op, const char* path);

/*
 * logging facilities and helpers
 */
#define ABORT_FILENAME \
  (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
#define ABORT(msg) msg_abort(errno, msg, __func__, ABORT_FILENAME, __LINE__)

/* abort with an error message */
void msg_abort(int err, const char* msg, const char* func, const char* file,
               int line);
