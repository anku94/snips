// irq_entry: struct for IRQ tracking key
// Used for identifying IRQ events by pid+cpu in bpf_softirq.c
struct irq_entry {
    u32 pid;
    u32 cpu;
};

// irq_beg_ts: map[struct irq_entry] -> u64 timestamp
// Used for tracking IRQ begin timestamps in bpf_softirq.c
BPF_HASH(irq_beg_ts, struct irq_entry);

TRACEPOINT_PROBE(irq, softirq_entry) {
    u32 cpu = bpf_get_smp_processor_id();

    u32 *is_active = tracing_active.lookup(&cpu);
    if (!is_active || *is_active == 0) {
        return 0;
    }

    struct irq_entry key = {};
    key.pid = bpf_get_current_pid_tgid();
    key.cpu = cpu;

    u64 val_ts = bpf_ktime_get_ns();
    irq_beg_ts.update(&key, &val_ts);

    return 0;
}

TRACEPOINT_PROBE(irq, softirq_exit) {
    u32 cpu = bpf_get_smp_processor_id();
    u32 *is_active = tracing_active.lookup(&cpu);
    if (!is_active || *is_active == 0) {
        return 0;
    }

    u64 *val_ts;

    struct irq_entry key = {};
    key.pid = bpf_get_current_pid_tgid();
    key.cpu = cpu;

    val_ts = irq_beg_ts.lookup(&key);
    if (!val_ts) {
        // disabled tracing or missed
        return 0;
    }

    struct event* e = events.ringbuf_reserve(sizeof(*e));
    if (!e) {
        return 0;
    }

    e->pid = key.pid;
    e->event_id = args->vec;
    e->tsbeg = *val_ts;
    e->dura = bpf_ktime_get_ns() - *val_ts;
    e->ret = 0;
    e->stack_id = -1;

    events.ringbuf_submit(e, 0);

    return 0;
} 