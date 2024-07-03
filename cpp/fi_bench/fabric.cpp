#include "fabric.h"
#include "fabric_utils.h"

#include <rdma/fi_domain.h>

#include <iostream>
#include <stdexcept>

#include "common.h"
namespace fi_bench {

Fabric::Fabric(const FabricConfig &config)
    : config_(config), fabric_(nullptr), domain_(nullptr), info_(nullptr) {
  fi_info *hints = fi_allocinfo();
  if (!hints) {
    ABORT("Could not allocate fi_info");
  }

  hints->caps = FI_SEND | FI_RECV;
  hints->ep_attr->type = FI_EP_DGRAM;         // Use datagram endpoint
  hints->mode = FI_LOCAL_MR | FI_MSG_PREFIX;  // Memory region modes needed

  if (!config.provider.empty()) {
    const char *provider = config.provider.c_str();
    hints->fabric_attr->prov_name = const_cast<char *>(provider);
    flog(LOG_INFO, "Using provider: %s", provider);
  }

  int ret = fi_getinfo(FI_VERSION(FI_MAJOR_VERSION, FI_MINOR_VERSION), nullptr,
                       nullptr, 0, hints, &info_);
  if (ret) {
    fi_freeinfo(hints);

    ABORT("fi_getinfo failed");
  }

  FabricUtils::LogInfo(info_);

  flog(LOG_INFO, "fi_getinfo succeeded. provider: %s",
       info_->fabric_attr->prov_name);

  info_->mode = FI_LOCAL_MR | FI_MSG_PREFIX;

  flog(LOG_INFO, fi_tostr(&info_->mode, FI_TYPE_MODE));

  ret = fi_fabric(info_->fabric_attr, &fabric_, nullptr);
  if (ret) {
    fi_freeinfo(info_);
    fi_freeinfo(hints);

    ABORT("fi_fabric failed");
  }

  flog(LOG_INFO, "fi_fabric succeeded.");

  ret = fi_domain(fabric_, info_, &domain_, nullptr);
  if (ret) {
    flog(LOG_ERRO, "fi_domain failed: %s", fi_strerror(-ret));

    fi_close((fid_t)fabric_);
    fi_freeinfo(info_);
    fi_freeinfo(hints);

    ABORT("fi_domain failed");
  }

  flog(LOG_INFO, "fi_domain succeeded.");

  // fi_freeinfo(hints);
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
