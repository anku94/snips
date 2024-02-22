#include "fabric.h"

#include <iostream>
#include <stdexcept>

namespace fi_bench {

Fabric::Fabric(const FabricConfig &config)
    : config_(config), fabric_(nullptr), domain_(nullptr), info_(nullptr) {
  // Initialize fabric here based on config
  fi_info *hints = fi_allocinfo();
  if (!hints) {
    throw std::runtime_error("Could not allocate fi_info");
  }

  hints->ep_attr->type = FI_EP_DGRAM;  // Use datagram endpoint
  hints->caps = FI_MSG;                // Messaging capabilities
  hints->mode = FI_LOCAL_MR;           // Memory region modes needed
  hints->addr_format = FI_SOCKADDR;    // Use socket addresses

  // Use the provider specified in config
  if (!config.provider.empty()) {
    hints->fabric_attr->prov_name = const_cast<char *>(config.provider.c_str());
  }

  int ret = fi_getinfo(FI_VERSION(FI_MAJOR_VERSION, FI_MINOR_VERSION), nullptr,
                       nullptr, 0, hints, &info_);
  if (ret) {
    fi_freeinfo(hints);
    throw std::runtime_error("fi_getinfo failed");
  }

  ret = fi_fabric(info_->fabric_attr, &fabric_, nullptr);
  if (ret) {
    fi_freeinfo(info_);
    fi_freeinfo(hints);
    throw std::runtime_error("fi_fabric failed");
  }

  ret = fi_domain(fabric_, info_, &domain_, nullptr);
  if (ret) {
    fi_close((fid_t)fabric_);
    fi_freeinfo(info_);
    fi_freeinfo(hints);
    throw std::runtime_error("fi_domain failed");
  }

  fi_freeinfo(hints);
}

Fabric::~Fabric() { Cleanup(); }

void Fabric::Init() {
  // Initialization logic, if any, that hasn't been covered in the constructor
}

void Fabric::Cleanup() {
  if (domain_) {
    fi_close((fid_t)domain_);
    domain_ = nullptr;
  }
  if (fabric_) {
    fi_close((fid_t)fabric_);
    fabric_ = nullptr;
  }
  if (info_) {
    fi_freeinfo(info_);
    info_ = nullptr;
  }
}

}  // namespace fi_bench