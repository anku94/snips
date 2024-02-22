#include "endpoint.h"

#include <stdexcept>

namespace fi_bench {

Endpoint::Endpoint(const EndpointConfig &config)
    : config_(config), ep_(nullptr), cq_(nullptr) {
  if (!config.info) {
    throw std::runtime_error("EndpointConfig.info is null");
  }

  // Create a completion queue for the endpoint
  fi_cq_attr cq_attr = {};
  cq_attr.size = 0;  // Let the provider define the size
  cq_attr.format = FI_CQ_FORMAT_CONTEXT;
  cq_attr.wait_obj = FI_WAIT_UNSPEC;
  int ret = fi_cq_open(config.info->domain, &cq_attr, &cq_, nullptr);
  if (ret) {
    throw std::runtime_error("Failed to open completion queue");
  }

  // Create the endpoint
  ret = fi_endpoint(config.info->domain, config.info, &ep_, nullptr);
  if (ret) {
    fi_close((fid_t)cq_);
    throw std::runtime_error("Failed to create endpoint");
  }
}

Endpoint::~Endpoint() { Finalize(); }

void Endpoint::Init() {
  // Endpoint initialization logic, such as binding the CQ and enabling the
  // endpoint
  fi_ep_bind(ep_, (fid_t)cq_, FI_TRANSMIT | FI_RECV);
  fi_enable(ep_);
}

void Endpoint::Finalize() {
  if (ep_) {
    fi_close((fid_t)ep_);
    ep_ = nullptr;
  }
  if (cq_) {
    fi_close((fid_t)cq_);
    cq_ = nullptr;
  }
}

void Endpoint::Send(const void *data, size_t length) {
  // Send data logic
  fi_send(ep_, data, length, fi_mr_desc(nullptr), 0, nullptr);
}

void Endpoint::Recv(void *buffer, size_t length) {
  // Receive data logic
  fi_recv(ep_, buffer, length, fi_mr_desc(nullptr), 0, nullptr);
}

}  // namespace fi_bench
