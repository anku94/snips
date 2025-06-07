#include <atomic>
#include <emmintrin.h>
#include <thread>

#include "common.h"

inline void mysleep() {
  // nanosleep for 1 ns
  struct timespec req = {0, 1};
  struct timespec rem = {0, 0};
  while (nanosleep(&req, &rem) == -1) {
    req = rem;
  }
}

class AtomicPollingRoundTrip : public RoundTrip {
public:
  void Run(int seconds) override {
    std::atomic<int> count{0};
    std::atomic<bool> flag{false};
    std::atomic<bool> stop{false};

    auto thread1 = [&]() {
      while (!stop.load()) {
        if (flag.load()) {
          flag.store(false);
          count++;
        }

        _mm_pause();
      }
    };

    auto thread2 = [&]() {
      while (!stop.load()) {
        if (!flag.load()) {
          flag.store(true);
        }

        // mysleep();
        _mm_pause();
      }
    };

    std::thread t1(thread1);
    std::thread t2(thread2);

    std::this_thread::sleep_for(std::chrono::seconds(seconds));
    stop.store(true);
    t1.join();
    t2.join();

    Print("atomic/polling", count, seconds);
  }
};
