#ifndef BPF_UPROBE_AGGR_C
#define BPF_UPROBE_AGGR_C

// event_entry: struct for event tracking key
// Used for identifying events by pid+cpu+evid in bpf_uprobe_aggr.c
struct event_entry {
    u32 pid;
    u32 cpu;
    u32 evid;
};

// func_key: struct for aggregate statistics key
// Used for identifying unique PID+function combinations in bpf_uprobe_aggr.c
struct func_key {
    u32 pid;
    u32 evid;
};

// func_stats: struct containing aggregate statistics per function per PID
// Used for storing totdur, totcnt, maxdur, mindur in bpf_uprobe_aggr.c
struct func_stats {
    u64 totdurns;   // total duration across all calls
    u64 totcnt;   // total call count
    u64 maxdurns;   // maximum single call duration
    u64 mindurns;   // minimum single call duration
};

// func_aggr_stats: map[struct func_key] -> struct func_stats
// Used for storing aggregate statistics per PID+function in bpf_uprobe_aggr.c
BPF_HASH(func_aggr_stats, struct func_key, struct func_stats);

// event_tsbeg: map[struct event_entry] -> u64 timestamp
// Used for tracking event begin timestamps
BPF_HASH(event_tsbeg, struct event_entry, u64);

// accumulate_func_stats: helper function to update aggregate statistics
// Call this with pid, evid, and duration to update the aggregation map
static inline int accumulate_func_stats(u32 pid, u32 evid, u64 duration) {
    // Create key for aggregate stats
    struct func_key func_key = {};
    func_key.pid = pid;
    func_key.evid = evid;

    // Lookup existing stats
    struct func_stats *stats = func_aggr_stats.lookup(&func_key);
    
    if (stats) {
        // Update existing stats
        stats->totdurns += duration;
        stats->totcnt++;
        if (duration > stats->maxdurns) {
            stats->maxdurns = duration;
        }
        if (duration < stats->mindurns) {
            stats->mindurns = duration;
        }
    } else {
        // First call for this pid+function - initialize stats
        struct func_stats new_stats = {};
        new_stats.totdurns = duration;
        new_stats.totcnt = 1;
        new_stats.maxdurns = duration;
        new_stats.mindurns = duration;
        func_aggr_stats.update(&func_key, &new_stats);
    }
    
    return 0;
}

#endif

int trace_beg_EVID(struct pt_regs *ctx) {
    u32 pid = bpf_get_current_pid_tgid();
    u32 one = 1;

    // this syntax is blocks that can be enabled by prepper
    //IS_TRIG: tracing_active.update(&pid, &one);

    //USE_TRIG: u32 *is_active = tracing_active.lookup(&pid);
    //USE_TRIG: if (!is_active || *is_active == 0) {
    //USE_TRIG:     return 0;
    //USE_TRIG: }

    // Record process name for current PID
    record_current_comm();

    struct event_entry key = {};
    key.pid = bpf_get_current_pid_tgid();
    key.cpu = bpf_get_smp_processor_id();
    key.evid = EVID;

    u64 ts = bpf_ktime_get_ns();
    event_tsbeg.update(&key, &ts);

    return 0;
}

int trace_end_EVID(struct pt_regs *ctx) {
    u32 pid = bpf_get_current_pid_tgid();
    u32 zero = 0;

    //IS_TRIG: tracing_active.update(&pid, &zero);

    //USE_TRIG: u32 *is_active = tracing_active.lookup(&pid);
    //USE_TRIG: if (!is_active || *is_active == 0) {
    //USE_TRIG:     return 0;
    //USE_TRIG: }

    u64 *ts;

    struct event_entry key = {};
    key.pid = bpf_get_current_pid_tgid();
    key.cpu = bpf_get_smp_processor_id();
    key.evid = EVID;

    ts = event_tsbeg.lookup(&key);
    if (!ts) {
        // disabled tracing or missed
        return 0;
    }

    u64 duration = bpf_ktime_get_ns() - *ts;

    // Accumulate statistics for this function call
    accumulate_func_stats(key.pid, key.evid, duration);

    return 0;
} 