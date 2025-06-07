#include <uapi/linux/ptrace.h>

struct event {
    u32 pid;
    u32 event_id;
    u64 tsbeg;
    u64 dura;
    int ret;
    int stack_id;
};

struct irq_entry {
    u32 pid;
    u32 cpu;
};

struct event_entry {
    u32 pid;
    u32 cpu;
    u32 evid;
};

BPF_STACK_TRACE(stack_traces, 4096);

BPF_HASH(irq_beg_ts, struct irq_entry);
BPF_HASH(tracing_active, u32, u32);
BPF_HASH(func_time, u32, u64);
BPF_HASH(event_tsbeg, struct event_entry, u64);

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