#include <cassert>
#include <cmath>
#include <cstring>
#include <iostream>
#include <string>
#include <unistd.h>

// Class for managing perf monitoring
class PerfManager {

  // control and ack fifo from perf
  int ctl_fd = -1;
  int ack_fd = -1;

  // if perf is enabled
  bool enable = false;

  // commands and acks to/from perf
  static constexpr const char *enable_cmd = "enable";
  static constexpr const char *disable_cmd = "disable";
  static constexpr const char *ack_cmd = "ack\n";

  // send command to perf via fifo and confirm ack
  void send_command(const char *command) {
    if (enable) {
      write(ctl_fd, command, strlen(command));
      char ack[5];
      read(ack_fd, ack, 5);
      assert(strcmp(ack, ack_cmd) == 0);
    }
  }

public:
  PerfManager() {
    // setup fifo file descriptors
    char *ctl_fd_env = std::getenv("PERF_CTL_FD");
    char *ack_fd_env = std::getenv("PERF_ACK_FD");
    if (ctl_fd_env && ack_fd_env) {
      enable = true;
      ctl_fd = std::stoi(ctl_fd_env);
      ack_fd = std::stoi(ack_fd_env);
    }
  }

  // public apis

  void pause() { send_command(disable_cmd); }

  void resume() { send_command(enable_cmd); }
};

// Sample Application

void dummy_work(int factor) {
  const size_t num_iter = 30000000 * factor;
  volatile double result = 0;
  for (size_t i = 0; i < num_iter; ++i) {
    result += std::exp(1.1);
  }
}

void initialize() { dummy_work(5); }

void finalise() { dummy_work(8); }

void kernelA() {
  dummy_work(3);
  std::cout << "Working" << std::endl;
}

void kernelB() {
  dummy_work(2);
}

void simulate(PerfManager& pmon) {
  for (int i = 0; i < 10; ++i) {
    pmon.resume();
    kernelA();
    pmon.pause();
    kernelB();
  }
}

int main(int argc, char **argv) {

  // pause profiling at the beginning
  PerfManager pmon;
  pmon.pause();

  initialize();

  // resume profiling for a region of interest
  simulate(pmon);

  finalise();
  return 0;
}
