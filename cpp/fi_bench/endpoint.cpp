#include "endpoint.h"
#include "fabric_utils.h"

#include <rdma/fabric.h>
#include <rdma/fi_cm.h>
#include <rdma/fi_domain.h>
#include <rdma/fi_endpoint.h>

#include "common.h"

namespace fi_bench {

Endpoint::Endpoint(const EndpointConfig &config)
    : config_(config), ep_(nullptr), cq_(nullptr) {
  if (!config.info) {
    ABORT("EndpointConfig.info is null");
  }

  FabricUtils::LogInfo(config.info);

  flog(LOG_INFO, "Endpoint Caps: %s", fi_tostr(&config.info->caps, FI_TYPE_CAPS));
  // config.info->caps = FI_SEND;

  // Create a completion queue for the endpoint
  fi_cq_attr cq_attr = {};
  cq_attr.size = 0;  // Let the provider define the size
  cq_attr.format = FI_CQ_FORMAT_CONTEXT;
  cq_attr.wait_obj = FI_WAIT_UNSPEC;
  int ret = fi_cq_open(config.domain, &cq_attr, &cq_, nullptr);
  if (ret) {
    ABORT("fi_cq_open failed");
  }

  // Create the endpoint
  ret = fi_endpoint(config.domain, config.info, &ep_, nullptr);
  if (ret) {
    fi_close((fid_t)cq_);
    ABORT("fi_endpoint failed");
  }

  ret = fi_mr_reg(config_.domain, buf_, 4096, FI_SEND , 0, 0, 0, &mr_, nullptr);
  if (ret) {
    fi_close((fid_t)ep_);
    fi_close((fid_t)cq_);

    ABORT("fi_mr_reg failed");
  }
}

void Endpoint::GetName() {
  char name[4096];
  size_t name_len = 4096;
  int rv = fi_getname((fid_t)ep_, name, &name_len);
  if (rv) {
    ABORT("fi_getname failed");
  } else {
    flog(LOG_INFO, fi_tostr(name, FI_TYPE_ADDR_FORMAT));
  }
}

Endpoint::~Endpoint() { Finalize(); }

void Endpoint::Init() {
  // Endpoint initialization logic, such as binding the CQ and enabling the
  // endpoint
  int rv = fi_ep_bind(ep_, (fid_t)cq_, FI_TRANSMIT);
  if (rv) {
    ABORT("fi_ep_bind failed");
  }

  rv = fi_enable(ep_);
  if (rv) {
    ABORT("fi_enable failed");
  }
}

void Endpoint::Finalize() {
  if (mr_) {
    fi_close((fid_t)mr_);
    mr_ = nullptr;
  }

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
