"""Compiler admission for the historical and current food fixtures."""
import re

VERSIONS = ('516.1681', '516.1688')
HISTORICAL_VERSION = '516.1681'


def compiler_is_clean(returncode, text, expected):
    if returncode or expected not in VERSIONS:
        return False
    lines = text.splitlines()
    banners = [line.strip() for line in lines if line.strip().startswith('DM compiler version ')]
    summaries = [line.strip() for line in lines if re.fullmatch(
        r'.+ - 0 errors, 0 warnings(?: \([^\r\n]*\))?', line.strip())]
    return banners == ['DM compiler version ' + expected] and len(summaries) == 1
