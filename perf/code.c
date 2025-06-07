#include <stdio.h>
#include <unistd.h>

int add_with_sleep(int a, int b, int sleep_us) {
  usleep(sleep_us);
  return a + b;

}

int main() {
  int ret = 0;
  for (int i = 0; i < 100; i++) {
    ret += add_with_sleep(i, i*i, i * 100);
    printf("I: %d, Ret: %d\n", i, ret);
  }

  return 0;
}
