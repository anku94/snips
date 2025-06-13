"""
BPF Program Preparation and Code Generation

The Prepper class handles dynamic BPF code generation by combining
base templates with dynamically generated uprobe functions.
"""

import logging
from typing import Dict
from .common import ProbeFuncs, symbol_map
from .templates import get_template

logger = logging.getLogger(__name__)

class Prepper:
    """
    Handles BPF program assembly and uprobe function generation
    
    Builds complete BPF programs by combining base templates with
    dynamically generated probe functions. Manages event ID allocation
    and symbol-to-ID mapping.
    """
    
    def __init__(self):
        """Initialize Prepper with base template and event ID tracking"""
        # Start with base BPF framework
        bpf_base = get_template("bpf_base")
        self._prog: list[str] = [bpf_base]
        
        # Event ID allocation (21+ for dynamic events, <21 reserved)
        self._evid_first = 21
        
        # Symbol to event ID mapping (start with predefined symbols)
        self._sym_evid_map: dict[str, int] = {**symbol_map}

    def _add_uprobe_event(self, evid: str, stack: bool = False):
        """
        Add a uprobe/uretprobe function pair to the BPF program
        
        Args:
            evid: Event ID string to substitute in template
            stack: Whether to enable stack trace collection
        """
        # Get the uprobe template
        uprobe_str = get_template("bpf_uprobe")
        
        # Configure stack tracing
        if stack:
            uprobe_stack = get_template("bpf_uprobe_stack")
        else:
            uprobe_stack = "-1"  # No stack tracing
        
        # Substitute template variables
        uprobe_prog = uprobe_str.replace("EVID", evid)
        uprobe_prog = uprobe_prog.replace("STACK_LOGIC", uprobe_stack)
        
        # Add to program
        self._prog.append(uprobe_prog)
        logger.debug(f"Added uprobe event for EVID {evid}, stack={stack}")

    def add_uprobe(self, sym_name: str, stack: bool, prettyname: str = None) -> ProbeFuncs:
        """
        Add uprobe functions for a symbol and return function names
        
        Args:
            sym_name: Symbol name to trace
            stack: Whether to collect stack traces
            prettyname: Pretty name for display (defaults to sym_name if None)
            
        Returns:
            ProbeFuncs with generated function names
        """
        evid = self._evid_first
        evid_str = str(evid)
        
        # Generate BPF functions
        self._add_uprobe_event(evid_str, stack)
        
        # Use prettyname if provided, otherwise use sym_name
        display_name = prettyname if prettyname is not None else sym_name
        
        # Update counters and mappings (use prettyname for display mapping)
        self._evid_first += 1
        self._sym_evid_map[display_name] = evid

        # Return function names for probe attachment
        probe_funcs: ProbeFuncs = {
            "fn_name": f"trace_beg_{evid}",
            "fn_name_ret": f"trace_end_{evid}",
        }

        logger.debug(f"Generated uprobe for symbol '{sym_name}' (prettyname: '{display_name}') -> EVID {evid}")
        return probe_funcs

    def gen_bpf(self) -> str:
        """
        Generate complete BPF program by joining all components
        
        Returns:
            Complete BPF C code as string
        """
        program = "\n".join(self._prog)
        logger.debug(f"Generated BPF program with {len(self._prog)} components")
        return program
    
    def get_sym_map(self) -> dict[int, str]:
        """
        Get reverse mapping from event ID to symbol name
        
        Returns:
            Dict mapping event IDs to symbol names
        """
        return {v: k for k, v in self._sym_evid_map.items()} 