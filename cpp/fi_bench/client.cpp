#include "client.h"

#include <rdma/fi_endpoint.h>

#include "common.h"

namespace fi_bench {
void Client::SetupFabric() {
  fi_info *hints = fi_allocinfo();
  if (!hints) {
    ABORT("Could not allocate fi_info");
  }

  hints->caps = FI_SEND;
  hints->ep_attr->type = FI_EP_DGRAM;
  hints->mode = FI_LOCAL_MR | FI_MSG_PREFIX;
  hints->fabric_attr->prov_name = strdup("verbs");

  int ret = fi_getinfo(FI_VERSION(FI_MAJOR_VERSION, FI_MINOR_VERSION), nullptr,
                       nullptr, 0, hints, &info_);
  if (ret) {
    ABORT("fi_getinfo failed");
  }

  info_->mode = FI_LOCAL_MR | FI_MSG_PREFIX;
  ret = fi_fabric(info_->fabric_attr, &fabric_, nullptr);
  if (ret) {
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

  fi_freeinfo(hints);
}

void Client::TeardownFabric() {
  if (domain_) {
    fi_close((fid_t)domain_);
    flog(LOG_INFO, "fi_close domain succeeded.");
    domain_ = nullptr;
  }

  if (fabric_) {
    fi_close((fid_t)fabric_);
    flog(LOG_INFO, "fi_close fabric succeeded.");
    fabric_ = nullptr;
  }

  if (info_) {
    fi_freeinfo(info_);
    flog(LOG_INFO, "fi_freeinfo succeeded.");
    info_ = nullptr;
  }
}

void Client::SetupEndpoint() {
  struct fi_cq_attr cq_attr = {0};
  cq_attr.format = FI_CQ_FORMAT_CONTEXT;
  cq_attr.size = 0;

  int rv = fi_cq_open(domain_, &cq_attr, &cq_, nullptr);
  if (rv) {
    TeardownFabric();
    ABORT("fi_cq_open failed");
  }

  flog(LOG_INFO, "fi_cq_open succeeded.");

  rv = fi_endpoint(domain_, info_, &ep_, nullptr);
  if (rv) {
    fi_close((fid_t)cq_);
    cq_ = nullptr;
    TeardownFabric();
    ABORT("fi_endpoint failed");
  }

  flog(LOG_INFO, "fi_endpoint succeeded.");

  rv = fi_mr_reg(domain_, buf_, kBufSize, FI_SEND, 0, 0, 0, &mr_, nullptr);
  if (rv) {
    fi_close((fid_t)ep_);
    ep_ = nullptr;
    fi_close((fid_t)cq_);
    cq_ = nullptr;
    TeardownFabric();
    ABORT("fi_mr_reg failed");
  }

  flog(LOG_INFO, "fi_mr_reg succeeded.");

  rv = fi_ep_bind(ep_, (fid_t)cq_, FI_SEND);
  if (rv) {
    fi_close((fid_t)mr_);
    mr_ = nullptr;
    fi_close((fid_t)ep_);
    ep_ = nullptr;
    fi_close((fid_t)cq_);
    cq_ = nullptr;
    TeardownFabric();

    ABORT("fi_ep_bind failed");
  }

  flog(LOG_INFO, "fi_ep_bind succeeded.");

  rv = fi_enable(ep_);
  if (rv) {
    ABORT("fi_enable failed");
  }

  flog(LOG_INFO, "fi_enable succeeded.");
}

void Client::TeardownEndpoint() {
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

void Client::SetupAV() {
  fi_av_attr av_attr;
  av_attr.type = FI_AV_TABLE;
  av_attr.count = 1;

  int rv = fi_av_open(domain_, &av_attr, &av_, nullptr);
  if (rv) {
    TeardownEndpoint();
    TeardownFabric();
    ABORT("fi_av_open failed");
  }

  flog(LOG_INFO, "fi_av_open succeeded.");

  rv = fi_ep_bind(ep_, (fid_t)av_, 0);
  if (rv) {
    TeardownAV();
    TeardownEndpoint();
    TeardownFabric();
    ABORT("fi_ep_bind failed");
  }

  flog(LOG_INFO, "fi_ep_bind with address vector succeeded.");
}

void Client::TeardownAV() {
  if (av_) {
    fi_close((fid_t)av_);
    av_ = nullptr;
  }
}

void Client::LoadAddress(const char* filename) {
  FILE* f = fopen(filename, "rb");
  if (!f) {
    ABORT("Could not open address file");
  }

  char address[256];
  size_t ret = fread(address, 1, 256, f);
  if (ret == 0) {
    ABORT("Could not read address from file");
  }

  if (!feof(f)) {
    ABORT("Address file too large");
  }

  InsertAddress(std::string(address, ret));
}

void Client::InsertAddress(const std::string &address) {
  flog(LOG_INFO, "Address Len: %zu", address.size());

  fi_addr_t addr;
  int rv = fi_av_insert(av_, address.c_str(), 1, &addr, 0, nullptr);
  if (rv != 1) {
    flog(LOG_ERRO, "fi_av_insert failed: %s", fi_strerror(-rv));
    ABORT("fi_av_insert failed");
  }

  addresses_.push_back(addr);
}

void Client::Run() {
  size_t msg_prefix = info_->ep_attr->msg_prefix_size;
  flog(LOG_INFO, "msg_prefix: %zu", msg_prefix);

  std::string msg = std::string(msg_prefix, 'a') + std::string(msg_prefix, 'b');
  flog(LOG_INFO, "Sending message: %s", msg.c_str());

  strncpy(buf_, msg.c_str(), msg.size());

  ssize_t bytes_sent =
      fi_send(ep_, buf_, msg.size(), mr_, addresses_[0], &ctx_);

  if (bytes_sent < 0) {
    flog(LOG_ERRO, "fi_send failed: %s", fi_strerror(-bytes_sent));
    ABORT("fi_send failed");
  }

  flog(LOG_INFO, "Sent %ld bytes", bytes_sent);

  // Wait for the send to complete
  fi_cq_data_entry entry;
  ssize_t ret = 0;
  while (ret == 0) {
    ret = fi_cq_read(cq_, &entry, 1);
  }

  flog(LOG_INFO, "Send completed");
}
}  // namespace fi_bench
