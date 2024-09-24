#pragma once

#include <atomic>
#include <iostream>
#include <linux/unistd.h>
#include <pthread.h>
#include <signal.h>
#include <sys/syscall.h>
#include <thread>
#include <unistd.h>

#include "common.h"
#include <atomic>
#include <chrono>
#include <iostream>
#include <pthread.h>
#include <signal.h>
#include <sys/syscall.h>
#include <unistd.h>

class SignalRoundTrip : public RoundTrip {
public:
  std::atomic<int> count{0};
  std::atomic<bool> stop{false};
  pthread_t thread1, thread2;
  std::atomic<pid_t> tid1{0}, tid2{0};

  void Run(int seconds) override {
    // Block SIGUSR1 and SIGUSR2 in the main thread
    sigset_t sigset;
    sigemptyset(&sigset);
    sigaddset(&sigset, SIGUSR1);
    sigaddset(&sigset, SIGUSR2);
    pthread_sigmask(SIG_BLOCK, &sigset, nullptr);

    // Thread functions
    auto thread1_func = [](void *arg) -> void * {
      auto *self = static_cast<SignalRoundTrip *>(arg);

      // Get TID of this thread
      pid_t tid = syscall(SYS_gettid);
      self->tid1.store(tid, std::memory_order_relaxed);

      // Block SIGUSR1 and SIGUSR2 in this thread
      sigset_t sigset;
      sigemptyset(&sigset);
      sigaddset(&sigset, SIGUSR1);
      sigaddset(&sigset, SIGUSR2);
      pthread_sigmask(SIG_BLOCK, &sigset, nullptr);

      // Wait set for SIGUSR1
      sigset_t waitset;
      sigemptyset(&waitset);
      sigaddset(&waitset, SIGUSR1);

      // Start the loop
      while (!self->stop.load(std::memory_order_relaxed)) {
        int sig;
        sigwait(&waitset, &sig);
        if (self->stop.load(std::memory_order_relaxed))
          break;

        // Increment count
        self->count.fetch_add(1, std::memory_order_relaxed);

        // Send SIGUSR2 to thread2
        pid_t tid2 = self->tid2.load(std::memory_order_relaxed);
        if (tid2 != 0) {
          syscall(SYS_tgkill, getpid(), tid2, SIGUSR2);
        }
      }
      return nullptr;
    };

    auto thread2_func = [](void *arg) -> void * {
      auto *self = static_cast<SignalRoundTrip *>(arg);

      // Get TID of this thread
      pid_t tid = syscall(SYS_gettid);
      self->tid2.store(tid, std::memory_order_relaxed);

      // Block SIGUSR1 and SIGUSR2 in this thread
      sigset_t sigset;
      sigemptyset(&sigset);
      sigaddset(&sigset, SIGUSR1);
      sigaddset(&sigset, SIGUSR2);
      pthread_sigmask(SIG_BLOCK, &sigset, nullptr);

      // Wait set for SIGUSR2
      sigset_t waitset;
      sigemptyset(&waitset);
      sigaddset(&waitset, SIGUSR2);

      // Start the loop
      while (!self->stop.load(std::memory_order_relaxed)) {
        int sig;
        sigwait(&waitset, &sig);
        if (self->stop.load(std::memory_order_relaxed))
          break;

        // Send SIGUSR1 to thread1
        pid_t tid1 = self->tid1.load(std::memory_order_relaxed);
        if (tid1 != 0) {
          syscall(SYS_tgkill, getpid(), tid1, SIGUSR1);
        }
      }
      return nullptr;
    };

    // Create threads
    pthread_create(&thread1, nullptr, thread1_func, this);
    pthread_create(&thread2, nullptr, thread2_func, this);

    // Wait until tid1 and tid2 are set
    while (tid1.load(std::memory_order_relaxed) == 0 ||
           tid2.load(std::memory_order_relaxed) == 0) {
      std::this_thread::yield();
    }

    // Start the round-trip by sending SIGUSR1 to thread1
    syscall(SYS_tgkill, getpid(), tid1.load(std::memory_order_relaxed),
            SIGUSR1);

    // Run for the specified duration
    std::this_thread::sleep_for(std::chrono::seconds(seconds));
    stop.store(true, std::memory_order_relaxed);

    // Send signals to wake up threads so they can exit
    syscall(SYS_tgkill, getpid(), tid1.load(std::memory_order_relaxed),
            SIGUSR1);
    syscall(SYS_tgkill, getpid(), tid2.load(std::memory_order_relaxed),
            SIGUSR2);

    // Join threads
    pthread_join(thread1, nullptr);
    pthread_join(thread2, nullptr);

    Print("sig/tgkill", count, seconds);
  }
};
