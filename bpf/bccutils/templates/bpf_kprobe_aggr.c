#ifndef BPF_KPROBE_AGGR_C
#define BPF_KPROBE_AGGR_C

// kprobe_start: map[u64 pid_tgid] -> u64 timestamp
// Used for tracking kprobe entry timestamps (simpler than uprobe per-thread stack)
// Key is pid_tgid to handle concurrent calls from different threads
BPF_HASH(kprobe_start, u64, u64);

#endif

int trace_kprobe_beg_EVID(struct pt_regs *ctx) {
    u64 pid_tgid = bpf_get_current_pid_tgid();
    u32 pid = pid_tgid >> 32;  // Extract actual PID
    u32 one = 1;

    // Trigger block support (same as uprobes)
    //IS_TRIG: tracing_active.update(&pid, &one);

    //USE_TRIG: u32 *is_active = tracing_active.lookup(&pid);
    //USE_TRIG: if (!is_active || *is_active == 0) {
    //USE_TRIG:     return 0;
    //USE_TRIG: }

    // Record process name for current PID
    record_current_comm();

    // Store entry timestamp keyed by pid_tgid
    u64 ts = bpf_ktime_get_ns();
    kprobe_start.update(&pid_tgid, &ts);

    return 0;
}

int trace_kprobe_end_EVID(struct pt_regs *ctx) {
    u64 pid_tgid = bpf_get_current_pid_tgid();
    u32 pid = pid_tgid >> 32;  // Extract actual PID
    u32 zero = 0;

    //IS_TRIG: tracing_active.update(&pid, &zero);

    //USE_TRIG: u32 *is_active = tracing_active.lookup(&pid);
    //USE_TRIG: if (!is_active || *is_active == 0) {
    //USE_TRIG:     return 0;
    //USE_TRIG: }

    // Lookup entry timestamp
    u64 *start_ts = kprobe_start.lookup(&pid_tgid);
    if (!start_ts) {
        return 0;  // No matching entry probe
    }

    // Calculate duration
    u64 duration = bpf_ktime_get_ns() - *start_ts;

    // Use addr=0 for kprobes (kernel functions don't have varying addresses per PID)
    // The evid is sufficient to identify the function
    u64 addr = 0;

    // Accumulate stats using shared function from bpf_uprobe_stack_aggr.c
    accumulate_func_stats(pid, addr, EVID, duration);

    // Clean up entry timestamp
    kprobe_start.delete(&pid_tgid);

    return 0;
}
