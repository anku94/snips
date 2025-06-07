int trace_beg_EVID(struct pt_regs *ctx) {
    struct p2pevt *evt = p2pevts.ringbuf_reserve(sizeof(*evt));
    if (!evt) {
        return 0;
    }

    evt->pid = bpf_get_current_pid_tgid() >> 32;
    evt->event_id = EVID;
    evt->tsbeg = bpf_ktime_get_ns();
    evt->dest = 0;
    evt->size = 0;
    evt->tag = 0;
    evt->reqptr = 0;

    p2pevts.ringbuf_submit(evt, 0);
    return 0;
} 