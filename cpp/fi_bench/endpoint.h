#pragma once

#include <rdma/fabric.h>

#include "config.h"

namespace fi_bench {
class Endpoint {
 public:
  explicit Endpoint(const EndpointConfig &config);
  ~Endpoint();

  // Disallow copy and assign.
  Endpoint(const Endpoint &) = delete;
  Endpoint &operator=(const Endpoint &) = delete;

  // Initializes the endpoint.
  void Init();

  void GetName();

  // Finalizes the endpoint.
  void Finalize();

  // Sends a message.
  void Send(const void *data, size_t length);

  // Receives a message.
  void Recv(void *buffer, size_t length);

 private:
  EndpointConfig config_;
  fid_ep *ep_ = nullptr;
  fid_mr *mr_ = nullptr;  // Memory Region
  fid_cq *cq_ = nullptr;  // Completion Queue
  fi_context ctx_;        // Context for async operations

  char buf_[4096];
};
}  // namespace fi_bench
