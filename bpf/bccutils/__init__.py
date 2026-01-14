"""
BCC Utilities Package

A structured framework for BPF tracing using BCC with template-based code generation.
Provides classes for building and managing uprobe/uretprobe tracing programs.
"""

from .common import ProbeSpec, ProbeFuncs, KprobeSpec
from .prepper import Prepper  
from .tracer import Tracer, ProbeId
from .templates import get_template, list_templates
from .collector import EventCollector
from .print_utils import PrettyPrint as pp
from .sym_mapper import SymMapper as sm

# Export main classes and functions
__all__ = [
    'Tracer',
    'Prepper',
    'ProbeId',
    'ProbeSpec',
    'KprobeSpec',
    'ProbeFuncs',
    'get_template',
    'list_templates',
    'EventCollector',
    'pp',
    'sm'
] 