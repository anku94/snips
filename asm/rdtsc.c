#include <stdio.h>
#include <unistd.h>

void fun() {
  uint32_t ts = 0, ts2 = 0;

  asm __volatile__ (
      "rdtsc \n"
      : "=a" (ts2), "=d" (ts)
      );

  printf("Timestamp: %u\n", ts);
  printf("Timestamp: %u\n", ts2);

  uint64_t msr;
  msr = 1ull << 48;

  asm volatile( "rdtsc \n"
      "shl $32, %%rdx \n"
      "mov %%rdx, %0 \n"
      : "=a" (msr)
      :
      : "rdx");

  printf("Timestamp: %llu\n", msr);
}

int main() {
  fun();
  return 0;
}
