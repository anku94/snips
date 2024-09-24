# Inter-thread Pingpong Benchmark

This benchmark measures the time it takes to send a message between two threads. The threads share a counter --- thread 0 increments the counter from 0 to 1, signals thread 1, which decrements it back to 0, and signals thread 0. This marks the end of a pingpong, and a round counter is incremented.

This benchmark implements 4 types of signalling mechanisms

1. Regular ints with `std::condition_variable` for signalling.
2. Atomic ints with `std::condition_variable` for signalling. This is really unnecessary (as mutexes imply memory fences), but we did it anyway.
3. `std::atomic<int>` with polling.
4. Inter-thread signalling using `SIGUSR` and `tgkill`.

## Results

Results from `Intel(R) Xeon(R) CPU E5-2670 0 @ 2.60GHz` with `g++ -O3`.

```
$ ./benchmark
              reg/cv: 103.28K/s
           atomic/cv: 95.85K/s
      atomic/polling: 6.69M/s # (best)
          sig/tgkill: 71.22K/s

$ ./benchmark
              reg/cv: 117.08K/s
           atomic/cv: 119.94K/s
      atomic/polling: 6.54M/s # (best)
          sig/tgkill: 93.84K/s

$ ./benchmark
              reg/cv: 99.75K/s
           atomic/cv: 83.68K/s
      atomic/polling: 7.57M/s # (best)
          sig/tgkill: 132.29K/s
```
