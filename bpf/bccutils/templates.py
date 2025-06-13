"""
BPF Template Management

Provides template loading and management functionality for BPF code generation.
Templates are stored in the templates/ directory and loaded as needed.
"""

import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

# Auto-discover templates at package load time
_TEMPLATE_DIR = Path(__file__).parent / "templates"
_templates = {}

def _load_templates():
    """Load all template files from the templates directory"""
    global _templates
    
    if not _TEMPLATE_DIR.exists():
        logger.warning(f"Template directory not found: {_TEMPLATE_DIR}")
        return
    
    for template_file in _TEMPLATE_DIR.glob("*.c"):
        template_name = template_file.stem  # filename without extension
        try:
            with open(template_file, 'r') as f:
                _templates[template_name] = f.read()
            logger.debug(f"Loaded template: {template_name}")
        except Exception as e:
            logger.error(f"Failed to load template {template_file}: {e}")

# Load templates on import
_load_templates()

def get_template(name: str) -> str:
    """Get a template by name"""
    if name not in _templates:
        raise KeyError(f"Template '{name}' not found. Available: {list(_templates.keys())}")
    return _templates[name]

def list_templates() -> list[str]:
    """List all available template names"""
    return list(_templates.keys()) 