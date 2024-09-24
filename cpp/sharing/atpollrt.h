#include <atomic>
#include <thread>

#include "common.h"

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
      }
    };

    auto thread2 = [&]() {
      while (!stop.load()) {
        if (!flag.load()) {
          flag.store(true);
        }
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

