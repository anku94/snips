#include "client.h"

int main(int argc, char *argv[]) {
  fi_bench::Client c;

  int x;
  scanf("%d", &x);

  c.LoadAddress("server.addr");
  c.Run();
  return 0;
}
