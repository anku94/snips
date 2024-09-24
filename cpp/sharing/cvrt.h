#include <mutex>
#include <thread>
#include <condition_variable>

#include "common.h"

class ConditionVarRoundTrip : public RoundTrip {
public:
  void Run(int seconds) override {
    int count = 0;
    std::mutex mtx;
    std::condition_variable cv;
    bool flag = false;
    bool stop = false;

    auto thread1 = [&]() {
      while (!stop) {
        std::unique_lock<std::mutex> lock(mtx);
        cv.wait(lock, [&] { return flag || stop; });
        if (stop)
          break;
        flag = false;
        count++;
        cv.notify_one();
      }
    };

    auto thread2 = [&]() {
      while (!stop) {
        std::unique_lock<std::mutex> lock(mtx);
        flag = true;
        cv.notify_one();
        cv.wait(lock, [&] { return !flag || stop; });
        if (stop)
          break;
      }
    };

    std::thread t1(thread1);
    std::thread t2(thread2);

    std::this_thread::sleep_for(std::chrono::seconds(seconds));
    stop = true;
    cv.notify_all();
    t1.join();
    t2.join();

    Print("reg/cv", count, seconds);
  }
};
