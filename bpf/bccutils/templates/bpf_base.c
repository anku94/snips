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

// tracing_active: map[u32 cpu] -> u32 active_flag
// Used for enabling/disabling tracing per CPU in bpf_uprobe.c and bpf_base.c
BPF_HASH(tracing_active, u32, u32);

// func_time: map[u32 cpu] -> u64 timestamp
// Used for tracking function begin timestamps in bpf_base.c
BPF_HASH(func_time, u32, u64);

// events: ringbuf for outputting event data
// Used for submitting traced events to userspace in bpf_uprobe.c and bpf_base.c
BPF_RINGBUF_OUTPUT(events, 8);

int trace_begin(struct pt_regs *ctx) {
    u32 cpu = bpf_get_smp_processor_id();
    u32 one = 1;
    tracing_active.update(&cpu, &one);

    u64 ts = bpf_ktime_get_ns();
    func_time.update(&cpu, &ts);

    return 0;
}

int trace_end(struct pt_regs *ctx) {
    u32 cpu = bpf_get_smp_processor_id();
    u32 zero = 0;
    tracing_active.update(&cpu, &zero);

    u64* ts;
    ts = func_time.lookup(&cpu);
    if (!ts) {
        // weird but whatever
        return 0;
    }

    u64 dura = bpf_ktime_get_ns() - *ts;
    // if (dura < 2500) {
    //     // ignore calls < 2.5us
    //     return 0;
    // }

    struct event* e = events.ringbuf_reserve(sizeof(*e));
    if (!e) {
        return 0;
    }

    e->pid = bpf_get_current_pid_tgid();
    e->event_id = 20;
    e->tsbeg = *ts;
    e->dura = bpf_ktime_get_ns() - *ts;
    e->ret = 0;
    e->stack_id = -1;

    events.ringbuf_submit(e, 0);

    return 0;
}
