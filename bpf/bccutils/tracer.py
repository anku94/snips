"""
BPF Tracing Management

The Tracer class provides high-level management of BPF probe attachments,
program compilation, and event collection. It coordinates between the
Prepper for code generation and BCC for runtime operations.
"""

import os
import logging
from bcc import BPF

from .common import ProbeSpec, ProbeFuncs, KprobeSpec
from typing import NamedTuple
from .prepper import Prepper
from .templates import get_template
from .sym_mapper import SymMapper

logger = logging.getLogger(__name__)


class ProbeId(NamedTuple):
    """Unique identifier for a probe instance"""
    pid: int
    addr: int
    evid: int


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
        self._kspec: list[tuple[KprobeSpec, ProbeFuncs]] = []
        self._aliases: dict[str, dict] = {}
        self._sym_mappers: dict[str, SymMapper] = {}
        self._evid_soname_map: dict[int, str] = {}
        self._sym_cache: dict[ProbeId, str] = {}
        # True if we want to use USE_TRIG to enable probes
        self._use_trig: bool = False
        logger.debug("Tracer initialized")

    def register_alias(self, alias: str, soname: str, uprobe: bool = True,
                       uretprobe: bool = True, stack: bool = False, regex: bool = False,
                       cache: bool = False, cache_prefixes: list[str] = None, is_trig: bool = False):
        """
        Register an alias with default probe specification arguments

        Args:
            alias: Name of the alias to register
            soname: Library/binary path to attach to
            uprobe: Whether to attach uprobe (function entry)
            uretprobe: Whether to attach uretprobe (function exit) 
            stack: Whether to collect stack traces
            regex: Whether to use regex for symbol matching
            cache: Whether to build symbol cache for this library
            cache_prefixes: List of prefixes to filter cached symbols
            is_trig: Whether to use IS_TRIG to enable probes (automatically enables USE_TRIG)
        """
        self._aliases[alias] = {
            "name": soname,
            "uprobe": uprobe,
            "uretprobe": uretprobe,
            "stack": stack,
            "regex": regex,
            "is_trig": is_trig
        }
        logger.info(f"Registered alias '{alias}' for {soname}")

        if is_trig:
            logger.info(f"Alias '{alias}' is a trigger probe")
            logger.info("Automatically enabling USE_TRIG globally")
            self._use_trig = True

        if cache:
            logger.info(f"Building symbol cache for alias '{alias}'")
            mapper = SymMapper()
            mapper.add_elf(soname, prefixes=cache_prefixes)
            self._sym_mappers[alias] = mapper
            logger.info(
                f"Symbol cache built for '{alias}' with {len(mapper._sym_to_elf)} symbols")

    def add_alias_probe(self, alias: str, sym: str, prettysym: str = None):
        """
        Add a probe using a registered alias

        Args:
            alias: Name of the registered alias to use
            sym: Symbol name to probe

        Raises:
            KeyError: If alias is not registered
            FileNotFoundError: If the library specified by the alias doesn't exist
        """
        if alias not in self._aliases:
            raise KeyError(
                f"Alias '{alias}' not registered. Use register_alias() first.")

        alias_args = self._aliases[alias]
        soname = alias_args["name"]

        # Check if library exists
        so_exists = os.path.exists(soname)
        logger.info(f"Library {soname} exists? {so_exists}")

        if not so_exists:
            raise FileNotFoundError(
                f"Library {soname} does not exist for alias '{alias}'")

        spec = ProbeSpec(sym=sym, prettyname=prettysym, **alias_args)
        self.add_probe(spec)
        logger.info(f"Added probe for {sym} using alias '{alias}' -> {soname}")

    def add_fuzzy_probe(self, alias: str, sym: list[str], prettysym: str = None):
        """
        Add a probe using fuzzy symbol lookup in the alias cache

        Args:
            alias: Name of the registered alias to use (must have cache enabled)
            sym: List of filter strings to match against cached symbols
        """
        logger.info(
            f"Adding fuzzy probe for alias '{alias}' with filters {sym}")

        if alias not in self._aliases:
            logger.error(f"Alias '{alias}' not registered")
            return

        if alias not in self._sym_mappers:
            logger.error(f"Alias '{alias}' does not have symbol cache enabled")
            return

        mapper = self._sym_mappers[alias]
        logger.info(
            f"Looking up symbol with filters {sym} in cache for '{alias}'")

        try:
            symbol, _ = mapper.get_sym(sym)
            logger.info(f"Found symbol '{symbol}' in cache, adding probe")
            self.add_alias_probe(alias, symbol, prettysym)
        except:
            logger.error(
                f"Symbol lookup failed for filters {sym} in alias '{alias}'")

    def add_probe(self, spec: ProbeSpec):
        """
        Add a general purpose probe with dynamically generated functions

        Args:
            spec: ProbeSpec with probe configuration
        """
        # If this probe is a trigger, enable USE_TRIG globally
        if spec.is_trig:
            logger.info(f"Adding trigger probe '{spec.sym}', enabling USE_TRIG globally")
            self._use_trig = True
            
        # Generate BPF functions via Prepper
        prettyname = spec.prettyname if spec.prettyname is not None else spec.sym
        evid, funcs = self._prepper.add_uprobe(
            spec.sym, spec.stack, prettyname, spec.is_trig, self._use_trig)
        self._spec.append((spec, funcs))
        self._evid_soname_map[evid] = spec.name
        logger.debug(f"Added probe for {spec.sym} -> evid {evid}, soname {spec.name}")

    def add_kprobe(self, spec: KprobeSpec):
        """
        Add a kprobe for tracing kernel functions

        Args:
            spec: KprobeSpec with kprobe configuration
        """
        # Generate BPF functions via Prepper
        evid, funcs = self._prepper.add_kprobe(spec.sym)
        self._kspec.append((spec, funcs))
        # For kprobes, store "kernel" as the "library" name
        self._evid_soname_map[evid] = "kernel"
        logger.debug(f"Added kprobe for {spec.sym} -> evid {evid}")

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
        logger.info(f"Attaching {len(self._spec)} uprobes and {len(self._kspec)} kprobes")
        for spec, funcs in self._spec:
            logger.debug(f"Attaching uprobe for {spec.sym}")
            self._attach_probe(b, spec, funcs)
        for spec, funcs in self._kspec:
            logger.debug(f"Attaching kprobe for {spec.sym}")
            self._attach_kprobe(b, spec, funcs)

    def _attach_probe(self, b: BPF, spec: ProbeSpec, funcs: ProbeFuncs):
        """
        Attach individual probe to BPF instance

        Args:
            b: BPF instance
            spec: Probe specification
            funcs: Generated function names
        """
        fn = funcs["fn_name"]
        fn_ret = funcs["fn_name_ret"]

        args_dict = {
            "name": spec.name,
            "fn_name": fn,
        }

        if spec.regex:
            args_dict["sym_re"] = spec.sym
        else:
            args_dict["sym"] = spec.sym

        if spec.uprobe:
            b.attach_uprobe(**args_dict)
            logger.debug(f"Attached uprobe: {spec.sym} -> {fn}")

        # Attach uretprobe (function exit) if requested
        if spec.uretprobe:
            args_dict["fn_name"] = fn_ret
            b.attach_uretprobe(**args_dict)
            logger.debug(f"Attached uretprobe: {spec.sym} -> {fn_ret}")

    def _attach_kprobe(self, b: BPF, spec: KprobeSpec, funcs: ProbeFuncs):
        """
        Attach individual kprobe to BPF instance

        Args:
            b: BPF instance
            spec: Kprobe specification
            funcs: Generated function names
        """
        fn = funcs["fn_name"]
        fn_ret = funcs["fn_name_ret"]

        # Attach kprobe (kernel function entry) if requested
        if spec.kprobe:
            b.attach_kprobe(event=spec.sym, fn_name=fn)
            logger.debug(f"Attached kprobe: {spec.sym} -> {fn}")

        # Attach kretprobe (kernel function exit) if requested
        if spec.kretprobe:
            b.attach_kretprobe(event=spec.sym, fn_name=fn_ret)
            logger.debug(f"Attached kretprobe: {spec.sym} -> {fn_ret}")

    def get_sym_map(self) -> dict[int, str]:
        """
        Get symbol to event ID mapping

        Returns:
            Dict mapping event IDs to symbol names
        """
        return self._prepper.get_sym_map()

    def get_evid_soname_map(self) -> dict[int, str]:
        """
        Get event ID to library/binary name mapping

        Returns:
            Dict mapping event IDs to library/binary paths
        """
        return self._evid_soname_map.copy()

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
            stack_syms = [b.sym(addr, pid, show_offset=True)
                          for addr in stack_list]
            stack_str: list[str] = [sym.decode("utf-8") for sym in stack_syms]
        except Exception as e:
            logger.warning(f"Failed to decode stack trace: {e}")
            stack_str = ["NA"]

        return stack_str

    def decode_sym(self, b: BPF, probe_id: ProbeId) -> str:
        """
        Decode symbol name from probe identifier

        Args:
            b: BPF instance for symbol resolution
            probe_id: ProbeId containing pid, addr, and evid

        Returns:
            Decoded symbol name, or hex address if resolution fails
        """
        # Check cache first
        if probe_id in self._sym_cache:
            return self._sym_cache[probe_id]

        # Get library/binary path from evid
        if probe_id.evid not in self._evid_soname_map:
            logger.warning(f"Unknown evid {probe_id.evid}, cannot resolve address {probe_id.addr:x}")
            sym_name = f"0x{probe_id.addr:x}"
        else:
            soname = self._evid_soname_map[probe_id.evid]

            # For kprobes (kernel functions), use the symbol name from evid mapping
            # Kprobes store addr=0, so address resolution won't work
            if soname == "kernel" and probe_id.addr == 0:
                sym_map = self.get_sym_map()
                sym_name = sym_map.get(probe_id.evid, f"evid_{probe_id.evid}")
            else:
                # For uprobes, resolve symbol from address
                try:
                    # Use the existing BPF instance for symbol resolution with correct PID
                    sym_bytes = b.sym(probe_id.addr, probe_id.pid, show_offset=True, demangle=True)
                    sym_name = sym_bytes.decode('utf-8')
                    # logger.debug(f"Resolved {probe_id} -> {sym_name}")
                except Exception as e:
                    logger.warning(f"Failed to resolve symbol for {probe_id} in {soname}: {e}")
                    sym_name = f"0x{probe_id.addr:x}"

        # Cache the result
        self._sym_cache[probe_id] = sym_name
        return sym_name
