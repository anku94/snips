#include <atomic>
#include <emmintrin.h>
#include <thread>

#include "common.h"

class AtomicPollingRoundTrip2 : public RoundTrip {
public:
  void Run(int seconds) override {
    alignas(64) int count = 0;
    alignas(64) std::atomic<bool> flag{false};
    alignas(64) bool stop = false;

    auto thread1 = [&]() {
      while (!stop) {
        if (flag.load(std::memory_order::memory_order_relaxed)) {
          flag.store(false, std::memory_order::memory_order_relaxed);
          count++;
        }

        // __asm__ __volatile__("rep nop" ::: "memory");
         _mm_pause();
      }
    };

    auto thread2 = [&]() {
      while (!stop) {
        if (!flag.load(std::memory_order::memory_order_relaxed)) {
          flag.store(true, std::memory_order::memory_order_relaxed);
        }

        // __asm__ __volatile__("rep nop" ::: "memory");
         _mm_pause();
      }
    };

    std::thread t1(thread1);
    std::thread t2(thread2);

    std::this_thread::sleep_for(std::chrono::seconds(seconds));
    stop = true;

    t1.join();
    t2.join();

    Print("atomic2/polling", count, seconds);
  }
};
