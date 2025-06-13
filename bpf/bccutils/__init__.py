"""
BCC Utilities Package

A structured framework for BPF tracing using BCC with template-based code generation.
Provides classes for building and managing uprobe/uretprobe tracing programs.
"""

from .common import ProbeSpec, ProbeFuncs
from .prepper import Prepper  
from .tracer import Tracer
from .templates import get_template, list_templates
from .collector import EventCollector

# Export main classes and functions
__all__ = [
    'Tracer',
    'Prepper', 
    'ProbeSpec',
    'ProbeFuncs',
    'get_template',
    'list_templates',
    'EventCollector',
    'elfsym'
] 