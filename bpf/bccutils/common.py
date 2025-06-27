"""
Common data structures and constants for BCC utilities
"""

import logging
from dataclasses import dataclass
from typing import TypedDict

# Set up logging
logger = logging.getLogger(__name__)


@dataclass
class ProbeSpec:
    name: str # library/binary path to attach to
    sym: str # symbol name to probe
    uprobe: bool  # whether to attach a uprobe
    uretprobe: bool  # whether to attach a uretprobe
    stack: bool  # whether to collect stack traces
    regex: bool  # whether to use regex for symbol matching
    prettyname: str = None  # pretty name for display (defaults to sym if None)
    is_trig: bool = False  # whether this is a trigger probe


class ProbeFuncs(TypedDict):
    """
    Generated BPF function names for a probe

    Keys:
        fn_name: Entry probe function name (uprobe)
        fn_name_ret: Exit probe function name (uretprobe)
    """
    fn_name: str
    fn_name_ret: str


# Software IRQ type mappings for kernel tracepoints
symbol_map_softirq: dict[str, int] = {
    "hi": 0,          # High priority tasklets
    "timer": 1,       # Timer interrupts
    "net_tx": 2,      # Network transmit
    "net_rx": 3,      # Network receive
    "block": 4,       # Block device I/O
    "irq_poll": 5,    # IRQ polling
    "tasklet": 6,     # Tasklets
    "sched": 7,       # Scheduler
    "hrtimer": 8,     # High-resolution timers
    "rcu": 9,         # RCU (Read-Copy-Update)
}

# Complete symbol mapping including application-specific events
symbol_map: dict[str, int] = {
    **symbol_map_softirq,
    "meshinit": 20,   # Custom application event
}
