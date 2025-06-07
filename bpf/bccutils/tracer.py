"""
BPF Tracing Management

The Tracer class provides high-level management of BPF probe attachments,
program compilation, and event collection. It coordinates between the
Prepper for code generation and BCC for runtime operations.
"""

from bcc import BPF

from .common import ProbeSpec, ProbeFuncs, logger
from .prepper import Prepper
from .templates import get_template


class Tracer:
    """
    High-level BPF tracing coordinator
    
    Manages probe specifications, BPF program generation, and probe attachments.
    Provides convenient methods for adding probes and interfacing with BCC.
    """
    
    def __init__(self):
        """Initialize Tracer with Prepper for code generation"""
        self._prepper = Prepper()
        self._spec: list[tuple[ProbeSpec, ProbeFuncs]] = []
        logger.debug("Tracer initialized")

    def add_meshinit_probe(self, spec: ProbeSpec):
        """
        Add a special mesh initialization probe with predefined functions
        
        This uses hardcoded function names for compatibility with existing
        infrastructure that expects 'trace_begin' and 'trace_end' functions.
        
        Args:
            spec: ProbeSpec with target library and symbol information
        """
        funcs: ProbeFuncs = {
            "fn_name": "trace_begin", 
            "fn_name_ret": "trace_end"
        }
        self._spec.append((spec, funcs))
        logger.debug(f"Added meshinit probe for {spec.sym}")

    def add_probe(self, spec: ProbeSpec):
        """
        Add a general purpose probe with dynamically generated functions
        
        Args:
            spec: ProbeSpec with probe configuration
        """
        # Generate BPF functions via Prepper
        funcs = self._prepper.add_uprobe(spec.sym, spec.stack)
        self._spec.append((spec, funcs))
        logger.debug(f"Added probe for {spec.sym}")

    def gen_bpf(self) -> str:
        """
        Generate complete BPF program
        
        Returns:
            Complete BPF C code ready for compilation
        """
        return self._prepper.gen_bpf()

    def get_template(self, name: str) -> str:
        """
        Get a template by name (convenience method)
        
        Args:
            name: Template name
            
        Returns:
            Template content as string
        """
        return get_template(name)

    def attach_all_probes(self, b: BPF):
        """
        Attach all configured probes to a BPF instance
        
        Args:
            b: Compiled BPF program instance
        """
        logger.info(f"Attaching {len(self._spec)} probes")
        for spec, funcs in self._spec:
            logger.debug(f"Attaching probe for {spec.sym}")
            self._attach_probe(b, spec, funcs)

    def _attach_probe(self, b: BPF, spec: ProbeSpec, funcs: ProbeFuncs):
        """
        Attach individual probe to BPF instance
        
        Args:
            b: BPF instance
            spec: Probe specification
            funcs: Generated function names
        """
        # Convert to bytes for BCC
        name = spec.name.encode("utf-8")
        sym = spec.sym.encode("utf-8")
        fn = funcs["fn_name"].encode("utf-8")
        fn_ret = funcs["fn_name_ret"].encode("utf-8")

        # Attach uprobe (function entry) if requested
        if spec.uprobe:
            b.attach_uprobe(name=name, sym=sym, fn_name=fn)
            logger.debug(f"Attached uprobe: {spec.sym} -> {funcs['fn_name']}")

        # Attach uretprobe (function exit) if requested  
        if spec.uretprobe:
            b.attach_uretprobe(name=name, sym=sym, fn_name=fn_ret)
            logger.debug(f"Attached uretprobe: {spec.sym} -> {funcs['fn_name_ret']}")

    def get_sym_map(self) -> dict[int, str]:
        """
        Get symbol to event ID mapping
        
        Returns:
            Dict mapping event IDs to symbol names
        """
        return self._prepper.get_sym_map()

    def decode_sid(self, b: BPF, sid: int, pid: int) -> list[str]:
        """
        Decode stack trace from stack ID
        
        Args:
            b: BPF instance with stack_traces table
            sid: Stack ID from event
            pid: Process ID for symbol resolution
            
        Returns:
            List of symbol names in stack trace
        """
        if sid < 0:
            return ["NA"]

        logger.debug(f"Decoding stack for sid {sid} and pid {pid}")

        try:
            stack_traces = b.get_table("stack_traces")
            stack_list = list(stack_traces.walk(sid))
            stack_syms = [b.sym(addr, pid, show_offset=True) for addr in stack_list]
            stack_str: list[str] = [sym.decode("utf-8") for sym in stack_syms]
        except Exception as e:
            logger.warning(f"Failed to decode stack trace: {e}")
            stack_str = ["NA"]

        return stack_str 