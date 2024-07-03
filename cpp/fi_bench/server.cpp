#include "server.h"

#include <rdma/fi_cm.h>
#include <rdma/fi_endpoint.h>

#include "common.h"

namespace fi_bench {
std::string Server::GetAddress() {
  char addr_buf[256];
  size_t bufsz = 256;
  int rv = fi_getname((fid_t)ep_, addr_buf, &bufsz);
  if (rv) {
    ABORT("fi_getname failed");
  }

  // make a byte string out of bufsz chars in addr_buf
  return std::string(addr_buf, bufsz);
}

void Server::WriteAddress(const char *filename) {
  std::string addr = GetAddress();
  FILE *file = fopen(filename, "wb");
  if (!file) {
    ABORT("fopen failed");
  }

  fwrite(addr.c_str(), 1, addr.size(), file);
  fclose(file);
}

void Server::SetupFabric() {
  fi_info *hints = fi_allocinfo();
  if (!hints) {
    ABORT("Could not allocate fi_info");
  }

  hints->caps = FI_RECV;
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

void Server::TeardownFabric() {
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

void Server::SetupEndpoint() {
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

  rv = fi_mr_reg(domain_, buf_, kBufSize, FI_RECV, 0, 0, 0, &mr_, nullptr);
  if (rv) {
    fi_close((fid_t)ep_);
    ep_ = nullptr;
    fi_close((fid_t)cq_);
    cq_ = nullptr;
    TeardownFabric();
    ABORT("fi_mr_reg failed");
  }

  flog(LOG_INFO, "fi_mr_reg succeeded.");

  rv = fi_ep_bind(ep_, (fid_t)cq_, FI_RECV);
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

void Server::TeardownEndpoint() {
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

void Server::Run() {
  ssize_t ret = fi_recv(ep_, buf_, kBufSize, mr_, FI_ADDR_UNSPEC, &ctx_);
  flog(LOG_INFO, "Recv ret: %zu", ret);

  ret = 0;
  fi_cq_entry entry;
  while(ret == 0) {
    ret = fi_cq_read(cq_, &entry, 1);
    if (entry.op_context == &ctx_) {
      break;
    } else {
      flog(LOG_INFO, "Unexpected op_context");
      ret = 0;
    }
  }

  flog(LOG_INFO, "Recv %.40s", &buf_[40]);
  flog(LOG_INFO, "Recv %.40s", &buf_[80]);

  flog(LOG_INFO, "Recv completed");
}
}  // namespace fi_bench
