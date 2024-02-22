#include <iostream>
#include <string>

#include "benchmark.h"
#include "endpoint.h"
#include "fabric.h"

namespace fi_bench {

void RunClient(const std::string &server_address) {
  FabricConfig fabric_config;
  fabric_config.provider = "sockets";  // Example provider

  EndpointConfig endpoint_config;
  // Populate endpoint_config with server address and other required settings

  Fabric fabric(fabric_config);
  Endpoint endpoint(endpoint_config);

  fabric.Init();
  endpoint.Init();

  ClientBenchmark benchmark(&fabric, &endpoint);
  benchmark.Run();
}

}  // namespace fi_bench

int main(int argc, char *argv[]) {
  if (argc < 2) {
    std::cerr << "Usage: " << argv[0] << " <server_address>" << std::endl;
    return 1;
  }

  std::string server_address = argv[1];
  fi_bench::RunClient(server_address);

  return 0;
}
