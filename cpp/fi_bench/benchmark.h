#pragma once

#include <chrono>

#include "endpoint.h"
#include "fabric.h"

namespace fi_bench {

struct BenchmarkStats {
  uint64_t messages_sent = 0;
  uint64_t messages_received = 0;
  std::chrono::steady_clock::duration duration =
      std::chrono::steady_clock::duration::zero();

  // Calculates and returns messages per second.
  double MessagesPerSecond() const;
};

class Benchmark {
 public:
  Benchmark(Fabric *fabric, Endpoint *endpoint);
  virtual ~Benchmark() = default;

  // Disallow copy and assign.
  Benchmark(const Benchmark &) = delete;
  Benchmark &operator=(const Benchmark &) = delete;

  // Runs the benchmark.
  virtual void Run() = 0;

 protected:
  Fabric *fabric_ = nullptr;
  Endpoint *endpoint_ = nullptr;
  BenchmarkStats stats_;
};

class ClientBenchmark : public Benchmark {
 public:
  using Benchmark::Benchmark;  // Inherit constructors.

  void Run() override;
};

class ServerBenchmark : public Benchmark {
 public:
  using Benchmark::Benchmark;  // Inherit constructors.

  void Run() override;
};

}  // namespace fi_bench
