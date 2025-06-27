#ifndef BPF_UPROBE_STACK_AGGR_C
#define BPF_UPROBE_STACK_AGGR_C

#define MAX_DEPTH 8

// frame_t: struct for a single stack frame
// Used for tracking individual function call entry points and timestamps
typedef struct {
    u64 addr;    // function address from PT_REGS_IP(ctx)
    u64 ts;      // entry timestamp from bpf_ktime_get_ns()
} frame_t;

// call_stack_t: struct for per-thread call stack
// Used for tracking nested function calls with proper LIFO behavior per PID
typedef struct {
    u32 depth;                    // current stack depth
    frame_t frames[MAX_DEPTH];    // array of stack frames
} call_stack_t;

// func_key: struct for aggregate statistics key
// Used for identifying unique PID+function+address combinations in bpf_uprobe_stack_aggr.c
typedef struct {
    u32 pid;
    u64 addr;   // function address for disambiguation
    u32 evid;
} func_key_t;

// func_stats: struct containing aggregate statistics per function per PID
// Used for storing totdurns, totcnt, maxdurns, mindurns in bpf_uprobe_stack_aggr.c
typedef struct {
    u64 totdurns;   // total duration across all calls (nanoseconds)
    u64 totcnt;     // total call count
    u64 maxdurns;   // maximum single call duration (nanoseconds)
    u64 mindurns;   // minimum single call duration (nanoseconds)
} func_stats_t;

// stacks: map[u32 pid] -> call_stack_t
// Used for tracking per-thread call stacks with nested function calls
BPF_HASH(stacks, u32, call_stack_t);

// func_aggr_stats: map[func_key_t] -> func_stats_t
// Used for storing aggregate statistics per PID+function+address in bpf_uprobe_stack_aggr.c
BPF_HASH(func_aggr_stats, func_key_t, func_stats_t);

// accumulate_func_stats: helper function to update aggregate statistics
// Call this with pid, addr, evid, and duration to update the aggregation map
static inline void accumulate_func_stats(u32 pid, u64 addr, u32 evid, u64 duration) {
    // Create key for aggregate stats
    func_key_t func_key = {0};
    func_key.pid = pid;
    func_key.addr = addr;
    func_key.evid = evid;

    // Lookup existing stats
    func_stats_t *stats = func_aggr_stats.lookup(&func_key);
    
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
        // First call for this pid+function+address - initialize stats
        func_stats_t new_stats = { duration, 1, duration, duration };
        func_aggr_stats.update(&func_key, &new_stats);
    }
}

// push_call: helper function to push a call onto the per-thread stack
// Records entry timestamp and function address for later duration calculation
static inline void push_call(u32 pid, u64 addr, u32 evid) {
    call_stack_t *stack = stacks.lookup(&pid);
    if (!stack) {
        // Initialize new stack for this PID
        call_stack_t init = {};
        stacks.update(&pid, &init);
        stack = stacks.lookup(&pid);
        if (!stack) return;
    }

    u32 index = stack->depth;
    // if (index >= MAX_DEPTH) return;
    
    // Check for stack overflow
    if (stack->depth >= MAX_DEPTH) return;
    
    // Push new frame onto stack
    frame_t *frame = &stack->frames[index];

    frame->addr = addr;
    frame->ts = bpf_ktime_get_ns();
    // stack->frames[stack->depth].addr = addr;
    // stack->frames[stack->depth].ts = bpf_ktime_get_ns();
    stack->depth++;
}

// pop_call: helper function to pop a call and record aggregate statistics
// Calculates duration and updates aggregation map, cleans up empty stacks
static inline void pop_call(u32 pid, u32 evid) {
    call_stack_t *stack = stacks.lookup(&pid);
    if (!stack || stack->depth == 0) return;

    stack->depth--;
    u32 index = stack->depth;

    // Gemini-generated slop, may not be reliable
    if (index >= MAX_DEPTH) {
        stacks.delete(&pid);
        return;
    }

    // Previous hacks to pass verifier
    // if (index == 0 || index >= MAX_DEPTH) return;
    // index %= MAX_DEPTH;
    
    // Pop frame from stack
    frame_t *frame = &stack->frames[index];
    
    // Calculate duration and accumulate stats
    u64 duration = bpf_ktime_get_ns() - frame->ts;
    accumulate_func_stats(pid, frame->addr, evid, duration);

    // Clean up empty stack
    if (stack->depth == 0) {
        stacks.delete(&pid);
    }
}

#endif

int trace_beg_EVID(struct pt_regs *ctx) {
    u64 pid_tgid = bpf_get_current_pid_tgid();
    u32 pid = pid_tgid >> 32;  // Extract actual PID, not TGID
    u32 one = 1;

    // this syntax is blocks that can be enabled by prepper
    //IS_TRIG: tracing_active.update(&pid, &one);

    //USE_TRIG: u32 *is_active = tracing_active.lookup(&pid);
    //USE_TRIG: if (!is_active || *is_active == 0) {
    //USE_TRIG:     return 0;
    //USE_TRIG: }

    // Record process name for current PID
    record_current_comm();

    // Get function address and push call onto per-thread stack
    u64 addr = PT_REGS_IP(ctx);
    push_call(pid, addr, EVID);

    return 0;
}

int trace_end_EVID(struct pt_regs *ctx) {
    u64 pid_tgid = bpf_get_current_pid_tgid();
    u32 pid = pid_tgid >> 32;  // Extract actual PID, not TGID
    u32 zero = 0;

    //IS_TRIG: tracing_active.update(&pid, &zero);

    //USE_TRIG: u32 *is_active = tracing_active.lookup(&pid);
    //USE_TRIG: if (!is_active || *is_active == 0) {
    //USE_TRIG:     return 0;
    //USE_TRIG: }

    // Pop call from per-thread stack and accumulate statistics
    pop_call(pid, EVID);

    return 0;
} 