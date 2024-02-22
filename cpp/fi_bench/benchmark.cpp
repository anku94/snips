#include "benchmark.h"

#include <iostream>
#include <stdexcept>

namespace fi_bench {

Benchmark::Benchmark(Fabric *fabric, Endpoint *endpoint)
    : fabric_(fabric), endpoint_(endpoint) {
  if (!fabric_ || !endpoint_) {
    throw std::invalid_argument("Fabric and Endpoint must not be null");
  }
}

double BenchmarkStats::MessagesPerSecond() const {
  auto seconds =
      std::chrono::duration_cast<std::chrono::seconds>(duration).count();
  return seconds > 0 ? static_cast<double>(messages_sent) / seconds : 0;
}

void ClientBenchmark::Run() {
  // Client benchmark logic to send messages and collect stats
  auto start = std::chrono::steady_clock::now();

  // Example: send loop
  for (uint64_t i = 0; i < stats_.messages_sent; ++i) {
    endpoint_->Send("message", 7);  // Example message
  }

  auto end = std::chrono::steady_clock::now();
  stats_.duration = end - start;
  std::cout << "Client sent " << stats_.messages_sent
            << " messages. Rate: " << stats_.MessagesPerSecond()
            << " messages/sec" << std::endl;
}

void ServerBenchmark::Run() {
  // Server benchmark logic to receive messages and optionally collect stats
  auto start = std::chrono::steady_clock::now();
  char buffer[256];  // Example buffer

  // Example: receive loop
  for (uint64_t i = 0; i < stats_.messages_received; ++i) {
    endpoint_->Recv(buffer, sizeof(buffer));
  }

  auto end = std::chrono::steady_clock::now();
  stats_.duration = end - start;
  std::cout << "Server received " << stats_.messages_received << " messages."
            << std::endl;
}

}  // namespace fi_bench
