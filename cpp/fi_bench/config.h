#pragma once

#include <rdma/fabric.h>

#include <string>

namespace fi_bench {

struct FabricConfig {
  std::string provider;  // Libfabric provider name.
                         // Additional fabric-wide configuration options.
};

struct EndpointConfig {
  fi_info *info = nullptr;  // Detailed endpoint configuration.
                            // Additional endpoint-specific options.
};

}  // namespace fi_bench
