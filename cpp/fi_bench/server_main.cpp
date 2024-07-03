#include "server.h"

int main() {
  fi_bench::Server s;
  s.WriteAddress("server.addr");
  s.Run();
  return 0;
}
