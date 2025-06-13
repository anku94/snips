import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent
CACHE_DIR = Path("/tmp/bpf_cache")
LOG_DIR = PROJECT_ROOT / "logs"

CACHE_ENABLED = True
CACHE_MAX_AGE_DAYS = 30

DEFAULT_UPROBE = True
DEFAULT_URETPROBE = True
DEFAULT_STACK = False

 