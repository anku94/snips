#include <iostream>

#include "benchmark.h"
#include "endpoint.h"
#include "fabric.h"

namespace fi_bench {

void RunServer() {
  FabricConfig fabric_config;
  fabric_config.provider = "sockets";  // Example provider

  EndpointConfig endpoint_config;
  // Set up endpoint_config for server, including listening address if needed

  Fabric fabric(fabric_config);
  Endpoint endpoint(endpoint_config);

  fabric.Init();
  endpoint.Init();

  ServerBenchmark benchmark(&fabric, &endpoint);
  benchmark.Run();
}

}  // namespace fi_bench

int main() {
  fi_bench::RunServer();
  return 0;
}
