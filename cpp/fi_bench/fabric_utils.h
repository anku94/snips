#pragma once

#include <rdma/fabric.h>

#include <cstring>
#include <string>

#include "common.h"

namespace fi_bench {
class FabricUtils {
 public:
  static void LogFabricInfo() {
    fi_info *info, *hints;
    hints = fi_allocinfo();
    hints->ep_attr->type = FI_EP_DGRAM;

    char prov_name[256];
    strncpy(prov_name, "verbs", sizeof(prov_name));
    hints->mode = FI_LOCAL_MR | FI_MSG_PREFIX;

    int ret = fi_getinfo(FI_VERSION(FI_MAJOR_VERSION, FI_MINOR_VERSION), NULL,
                         NULL, 0, hints, &info);
    if (ret) {
      ABORT("fi_getinfo failed!");
    }

    for (fi_info *cur = info; cur; cur = cur->next) {
      flog(LOG_INFO, "Fabric info: %s", cur->fabric_attr->prov_name);
      flog(LOG_INFO, "Endpoint: %s",
           EndpointToString(cur->ep_attr->type).c_str());
    }

    fi_freeinfo(info);
  }

  static void LogInfo(fi_info *info) {
    flog(LOG_INFO, "Logging all fabrics in info ...");

    for (fi_info *cur = info; cur; cur = cur->next) {
      flog(LOG_INFO, "----------");
      flog(LOG_INFO, fi_tostr(&cur->caps, FI_TYPE_CAPS));
      flog(LOG_INFO, fi_tostr(cur->fabric_attr, FI_TYPE_FABRIC_ATTR));
      flog(LOG_INFO, fi_tostr(cur->tx_attr, FI_TYPE_TX_ATTR));
      flog(LOG_INFO, fi_tostr(cur->rx_attr, FI_TYPE_RX_ATTR));
      flog(LOG_INFO, fi_tostr(cur->ep_attr, FI_TYPE_EP_ATTR));
      flog(LOG_INFO, fi_tostr(&cur->mode, FI_TYPE_MODE));
      flog(LOG_INFO, fi_tostr(&cur->domain_attr, FI_TYPE_DOMAIN_ATTR));
    }
  }

  static std::string EndpointToString(fi_ep_type ep_type) {
    switch (ep_type) {
      case FI_EP_MSG:
        return "FI_EP_MSG";
      case FI_EP_DGRAM:
        return "FI_EP_DGRAM";
      case FI_EP_RDM:
        return "FI_EP_RDM";
      default:
        return "unknown";
    }
  }
};
}  // namespace fi_bench
