#pragma once

#include <rdma/fabric.h>

#include "config.h"

namespace fi_bench {

class Fabric {
 public:
  explicit Fabric(const FabricConfig &config);
  ~Fabric();

  // Disallow copy and assign.
  Fabric(const Fabric &) = delete;
  Fabric &operator=(const Fabric &) = delete;

  // Initializes the fabric environment.
  void Init();

  // Tears down the fabric environment.
  void Cleanup();

 private:
  FabricConfig config_;
  fid_fabric *fabric_ = nullptr;
  fid_domain *domain_ = nullptr;
  fi_info *info_ = nullptr;
};

}  // namespace fi_bench
