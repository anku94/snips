#include <uapi/linux/ptrace.h>

struct p2pevt {
    u32 pid;
    int event_id;
    u64 tsbeg;
    u32 dest;
    u32 size;
    int tag;
    u64 reqptr;
};

BPF_HASH(mpiwaittime, u32, u64);

BPF_STACK_TRACE(stack_traces, 4096);

BPF_RINGBUF_OUTPUT(p2pevts, 8);

int trace_isend(struct pt_regs *ctx) {
    struct p2pevt *evt = p2pevts.ringbuf_reserve(sizeof(*evt));
    if (!evt) {
        return 0;
    }

    evt->pid = bpf_get_current_pid_tgid() >> 32;
    evt->event_id = 1;
    evt->tsbeg = bpf_ktime_get_ns();
    evt->dest = PT_REGS_PARM4(ctx);
    evt->size = PT_REGS_PARM2(ctx);
    evt->tag = PT_REGS_PARM5(ctx);

    bpf_probe_read(&evt->reqptr, sizeof(evt->reqptr), (void *)PT_REGS_SP(ctx) + 8);

    p2pevts.ringbuf_submit(evt, 0);
    return 0;
}

int trace_ips_isend(struct pt_regs *ctx) {
    struct p2pevt *evt = p2pevts.ringbuf_reserve(sizeof(*evt));
    if (!evt) {
        return 0;
    }

    evt->pid = bpf_get_current_pid_tgid() >> 32;
    evt->event_id = 100;
    evt->tsbeg = bpf_ktime_get_ns();
    evt->dest = 0;
    evt->size = PT_REGS_PARM6(ctx);
    evt->tag = PT_REGS_PARM5(ctx);
    evt->reqptr = 0;

    p2pevts.ringbuf_submit(evt, 0);
    return 0;
}

int trace_irecv(struct pt_regs *ctx) {
    struct p2pevt *evt = p2pevts.ringbuf_reserve(sizeof(*evt));
    if (!evt) {
        return 1;
    }

    evt->pid = bpf_get_current_pid_tgid() >> 32;
    evt->event_id = 2;
    evt->tsbeg = bpf_ktime_get_ns();
    evt->dest = PT_REGS_PARM4(ctx);
    evt->size = PT_REGS_PARM2(ctx);
    evt->tag = PT_REGS_PARM5(ctx);

    bpf_probe_read(&evt->reqptr, sizeof(evt->reqptr), (void *)PT_REGS_SP(ctx) + 8);

    p2pevts.ringbuf_submit(evt, 0);
    return 0;
}

int trace_test(struct pt_regs *ctx) {
    struct p2pevt *evt = p2pevts.ringbuf_reserve(sizeof(*evt));
    if (!evt) {
        return 1;
    }

    u64 arg2_ptr = PT_REGS_PARM2(ctx);
    u32 arg2;
    bpf_probe_read(&arg2, sizeof(arg2), (void *)arg2_ptr);

    evt->pid = bpf_get_current_pid_tgid() >> 32;
    evt->event_id = 0;
    evt->tsbeg = bpf_ktime_get_ns();
    evt->dest = 0;
    evt->size = PT_REGS_PARM3(ctx);
    evt->tag = arg2;
    evt->reqptr = PT_REGS_PARM1(ctx);

    p2pevts.ringbuf_submit(evt, 0);
    return 0;
}

int trace_unexpected(struct pt_regs *ctx) {
    // print k
    u32 mode = PT_REGS_PARM2(ctx);
    bpf_trace_printk("Unexpected event: mode %d\\n", mode);

    return 0;
}

int trace_mpiwaitbeg(struct pt_regs *ctx) {
    u32 pid = bpf_get_current_pid_tgid() >> 32;
    u64 ts = bpf_ktime_get_ns();
    mpiwaittime.update(&pid, &ts);

    return 0;
}

int trace_mpiwaitend(struct pt_regs *ctx) {
    u32 pid = bpf_get_current_pid_tgid() >> 32;
    u64 *ts;
    ts = mpiwaittime.lookup(&pid);
    if (!ts) {
        return 0;
    }

    // if ts > 10ms, print things
    u64 dura = bpf_ktime_get_ns() - *ts;
    if (dura > 10000000) {
        bpf_trace_printk("MPI_Wait took %d ns", dura);
    }
    return 0;
} 