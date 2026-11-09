"""Compiler admission for the food fixtures: the canonical compiler pin only."""
import json
from pathlib import Path
import re

PINNED_VERSION = json.loads((Path(__file__).resolve().parents[2] / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
VERSIONS = (PINNED_VERSION,)


def compiler_is_clean(returncode, text, expected):
    if returncode or expected not in VERSIONS:
        return False
    lines = text.splitlines()
    banners = [line.strip() for line in lines if line.strip().startswith('DM compiler version ')]
    summaries = [line.strip() for line in lines if re.fullmatch(
        r'.+ - 0 errors, 0 warnings(?: \([^\r\n]*\))?', line.strip())]
    return banners == ['DM compiler version ' + expected] and len(summaries) == 1
