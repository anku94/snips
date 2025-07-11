#ifndef BPF_UPROBE_C
#define BPF_UPROBE_C

// event_entry: struct for event tracking key
// Used for identifying events by pid+cpu+evid in bpf_uprobe.c
struct event_entry {
    u32 pid;
    u32 cpu;
    u32 evid;
};

// event_tsbeg: map[struct event_entry] -> u64 timestamp
// Used for tracking event begin timestamps in bpf_uprobe.c
BPF_HASH(event_tsbeg, struct event_entry, u64);

#endif

int trace_beg_EVID(struct pt_regs *ctx) {
    u32 cpu = bpf_get_smp_processor_id();

    u32 *is_active = tracing_active.lookup(&cpu);
    // if (!is_active || *is_active == 0) {
    //     return 0;
    // }

    struct event_entry key = {};
    key.pid = bpf_get_current_pid_tgid();
    key.cpu = cpu;
    key.evid = EVID;

    u64 ts = bpf_ktime_get_ns();
    event_tsbeg.update(&key, &ts);

    return 0;
}

int trace_end_EVID(struct pt_regs *ctx) {
    u32 cpu = bpf_get_smp_processor_id();
    u32 *is_active = tracing_active.lookup(&cpu);
    // if (!is_active || *is_active == 0) {
    //     return 0;
    // }

    u64 *ts;

    struct event_entry key = {};
    key.pid = bpf_get_current_pid_tgid();
    key.cpu = cpu;
    key.evid = EVID;

    ts = event_tsbeg.lookup(&key);
    if (!ts) {
        // disabled tracing or missed
        return 0;
    }

    struct event* e = events.ringbuf_reserve(sizeof(*e));
    if (!e) {
        return 0;
    }

    e->pid = key.pid;
    e->event_id = key.evid;
    e->tsbeg = *ts;
    e->dura = bpf_ktime_get_ns() - *ts;
    e->ret = PT_REGS_RC(ctx);
    e->stack_id = STACK_LOGIC;

    events.ringbuf_submit(e, 0);

    return 0;
} 