import json
import subprocess
import os
import sys
import logging
import hashlib
from pathlib import Path
from constants import CACHE_DIR

logger = logging.getLogger(__name__)


def extract_symbols_nm(elf_path: str, prefixes: list[str] = None) -> list[str]:
    """
    Extract symbols from an ELF file using nm.

    Args:
        elf_path: Path to the ELF file
        prefixes: List of prefixes to filter symbols by

    Returns:
        List of symbols that match the prefixes
    """
    result = subprocess.run(['nm', '-a', elf_path],
                            capture_output=True, text=True)
    if result.returncode != 0:
        logger.error(f"nm command failed for {elf_path}")
        sys.exit(-1)

    lines = result.stdout.splitlines()
    logger.info(f"nm found {len(lines)} total lines of output")

    filtered_symbols = []

    if prefixes is not None:
        logger.info(f"Filtering symbols with prefixes: {prefixes}")

    for line in lines:
        parts = line.strip().split()
        if len(parts) != 3:
            continue

        # output is: (addr, type, symbol)
        _, _, symbol = parts
        matches_prefix = prefixes is None or any(
            symbol.startswith(prefix) for prefix in prefixes)
        if matches_prefix:
            filtered_symbols.append(symbol)

    logger.info(f"nm extracted {len(filtered_symbols)} symbols")
    return filtered_symbols


class SymMapper:
    def __init__(self, cache_dir: Path = CACHE_DIR):
        self._sym_to_elf = {}
        self._cache_dir = cache_dir
        self._cache_dir.mkdir(parents=True, exist_ok=True)

    def _get_cached_symbols(self, elf_path: str) -> list[str]:
        path_hash = hashlib.md5(elf_path.encode()).hexdigest()
        cache_file = self._cache_dir / f"{path_hash}.json"

        if cache_file.exists():
            with open(cache_file, 'r') as f:
                symbols = json.load(f).get("symbols", [])
            logger.info(f"Loaded {len(symbols)} symbols from cache")
            return symbols

        return []

    def _save_cached_symbols(self, elf_path: str, symbols: list[str]):
        path_hash = hashlib.md5(elf_path.encode()).hexdigest()
        cache_file = self._cache_dir / f"{path_hash}.json"
        logger.info(f"Saving {len(symbols)} symbols to cache at {cache_file}")
        with open(cache_file, 'w') as f:
            json.dump({"elf_path": elf_path, "symbols": symbols}, f)

    def add_elf(self, elf_path: str, invalidate: bool = False, prefixes: list[str] = None):
        exists = os.path.exists(elf_path)
        logger.info(f"ELF file {elf_path} existence check: {exists}")

        symbols = [] if invalidate else self._get_cached_symbols(elf_path)

        if len(symbols) == 0:
            logger.info(f"Extracting symbols from {elf_path}")
            symbols = extract_symbols_nm(elf_path, prefixes)
            logger.info(f"Found {len(symbols)} symbols")
            self._save_cached_symbols(elf_path, symbols)

        for sym in symbols:
            self._sym_to_elf[sym] = elf_path

    def get_sym(self, filters: list[str]) -> tuple[str, str]:
        candidates = list(self._sym_to_elf.keys())

        for filter_str in filters:
            candidates = [sym for sym in candidates if filter_str in sym]

        if not candidates:
            logger.error(f"No symbol found matching filters: {filters}")
            sys.exit(-1)

        key = candidates[0]
        return (key, self._sym_to_elf[key])
