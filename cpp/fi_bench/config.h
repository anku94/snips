#pragma once

#include <rdma/fabric.h>
#include <rdma/fi_domain.h>

#include <string>

namespace fi_bench {

struct FabricConfig {
  std::string provider;  // Libfabric provider name.
                         // Additional fabric-wide configuration options.
};

struct EndpointConfig {
  fi_info *info = nullptr;  // Detailed endpoint configuration.
  fid_domain* domain = nullptr;  // Domain to create the endpoint in.
};

}  // namespace fi_bench
