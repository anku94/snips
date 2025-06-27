#include <uapi/linux/ptrace.h>

// event: struct containing event data for ringbuf output
// Used for submitting traced events in bpf_uprobe.c and bpf_base.c
struct event {
    u32 pid;
    u32 event_id;
    u64 tsbeg;
    u64 dura;
    int ret;
    int stack_id;
};

// stack_traces: map[stack_id] -> stack trace
// Used for storing stack traces referenced by events
BPF_STACK_TRACE(stack_traces, 4096);

// tracing_active: map[u32 pid] -> u32 active_flag
// Used for enabling/disabling tracing per PID in bpf_uprobe.c and bpf_base.c
BPF_HASH(tracing_active, u32, u32);

// func_time: map[u32 cpu] -> u64 timestamp
// Used for tracking function begin timestamps in bpf_base.c
BPF_HASH(func_time, u32, u64);

// events: ringbuf for outputting event data
// Used for submitting traced events to userspace in bpf_uprobe.c and bpf_base.c
BPF_RINGBUF_OUTPUT(events, 8);