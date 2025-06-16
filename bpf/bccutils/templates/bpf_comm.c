#ifndef BPF_COMM_C
#define BPF_COMM_C

// proc_name: struct containing process name
// Used for storing process names in bpf_comm.c
struct proc_name {
    char name[16];  // TASK_COMM_LEN
};

// pid_to_name: map[u32 pid] -> struct proc_name
// Used for storing process names by PID in bpf_comm.c
BPF_HASH(pid_to_name, u32, struct proc_name);

// record_comm: helper function to record process name for a PID
// Call this from any hook to ensure PID->name mapping exists
static inline int record_comm(u32 pid) {
    // Check if we already have this PID
    struct proc_name *existing = pid_to_name.lookup(&pid);
    if (existing) {
        // Already recorded, nothing to do
        return 0;
    }
    
    // First time seeing this PID - record the process name
    struct proc_name new_name = {};
    int ret = bpf_get_current_comm(new_name.name, sizeof(new_name.name));
    if (ret != 0) {
        // Failed to get comm, store placeholder
        __builtin_memcpy(new_name.name, "unknown", 8);
    }
    
    pid_to_name.update(&pid, &new_name);
    return 0;
}

// record_current_comm: convenience wrapper for current process
// Call this from any hook to record the current process name
static inline int record_current_comm() {
    u32 pid = bpf_get_current_pid_tgid();
    return record_comm(pid);
}

#endif 