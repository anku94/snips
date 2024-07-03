#pragma once

#include <string>
#include <vector>

#include <rdma/fabric.h>
#include <rdma/fi_domain.h>

namespace fi_bench {
class Server {
 public:
  Server() {
    SetupFabric();
    SetupEndpoint();
  }

  std::string GetAddress();

  void WriteAddress(const char* filename);

  void SetupFabric();

  void TeardownFabric();

  void SetupEndpoint();

  void TeardownEndpoint();

  void Run();

  ~Server() {
    TeardownEndpoint();
    TeardownFabric();
  }

 private:
  fid_fabric *fabric_ = nullptr;
  fid_domain *domain_ = nullptr;
  fi_info *info_ = nullptr;

  fid_cq *cq_ = nullptr;
  fid_mr *mr_ = nullptr;
  fid_ep *ep_ = nullptr;

  fid_av *av_ = nullptr;

  fi_context ctx_;

  static constexpr size_t kBufSize = 4096;
  char buf_[kBufSize];

  std::vector<fi_addr_t> addresses_;
};
}  // namespace fi_bench
