#include <stdio.h>
#include <unistd.h>

void fun() {
  uint32_t ts = 0, ts2 = 0;

  asm __volatile__ (
      "rdtsc \n"
      : "=a" (ts2), "=d" (ts)
      );

  printf("EDX\t\t: %u\n", ts);
  printf("EAX\t\t: %u\n", ts2);

  uint64_t ts_concat  = ((ts * 1ull) << 32) | (ts2 * 1ull);

  printf("TS Concat\t: %llu\n", ts_concat);

  uint64_t msr;

  asm volatile( "rdtsc \n"
      "shl $32, %%rdx \n"
      "mov %%rdx, %0 \n"
      : "=a" (msr)
      :
      : "rdx");

  printf("TS2 \t\t: %llu\n", msr);
}

int main() {
  fun();
  return 0;
}
