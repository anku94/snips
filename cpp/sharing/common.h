#pragma once

#include <string>
#include <cstdio>

class RoundTrip {
public:
  virtual void Run(int seconds) = 0;
  virtual ~RoundTrip() = default;

  std::string GetHumRdStr(double count) {
    std::string unit = "";
    double val = count;

    if (count > 1e6) {
      val /= 1e6;
      unit = "M";
    } else if (count > 1e3) {
      val /= 1e3;
      unit = "K";
    }

    char buf[64];
    snprintf(buf, sizeof(buf), "%.2f%s", val, unit.c_str());
    return std::string(buf);
  }

  void Print(const char *name, int count, int seconds) {
    std::string rate_str = GetHumRdStr(count * 1.0 / seconds) + "/s";

    fprintf(stderr, "%20s: %s\n", name, rate_str.c_str());
  }
};

