#include "cvrt.h"
#include "atcvrt.h"
#include "atpollrt.h"
#include "sigrt.h"

int main() {
  int test_duration = 5; // Example, run each for 5 seconds

  ConditionVarRoundTrip condVarRT;
  condVarRT.Run(test_duration);

  AtomicConditionVarRoundTrip atomicCVRT;
  atomicCVRT.Run(test_duration);

  AtomicPollingRoundTrip atomicRT;
  atomicRT.Run(test_duration);

  SignalRoundTrip signalRT;
  signalRT.Run(test_duration);

  return 0;
}