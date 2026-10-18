"""Pure bounded compiler/diagnostic evidence checks; no process execution."""
import re

DIAGNOSTIC = re.compile(r'runtime error:|bad ref|bad loc|BUG:|##\s*ERROR\s*:|RUNTIME:|assertion failed|infinite loop|segmentation|fatal error|unexpected runtime|\bOOM\b|out of memory|access violation|\bCRASH(?:ED)?\b', re.I)


MAX_COMPILE_LOG = 1024 * 1024


def validate_compile(exit_code, log, artifact="probe.dmb"):
    """Accept one exact pinned banner and one uncontaminated probe result."""
    if exit_code != 0 or len(log.encode('utf-8')) > MAX_COMPILE_LOG or DIAGNOSTIC.search(log):
        raise RuntimeError('Compiler exit, output bound or diagnostics invalidated evidence')
    lines = log.splitlines()
    banners = [line for line in lines if re.search(r'DM compiler version', line, re.I)]
    if banners != ['DM compiler version 516.1681']:
        raise RuntimeError('Exactly one full pinned compiler banner required')
    results = [line for line in lines if re.search(r'\berrors?\b|\bwarnings?\b', line, re.I)]
    # Native 516.1681 adds a local date/time to the result; synthetic logs may omit it.
    summary = re.escape(artifact) + r' - 0 errors, 0 warnings(?: \(\d{1,2}/\d{1,2}/\d{2,4} \d{1,2}:\d{2}(?::\d{2})? (?:am|pm)\))?'
    if len(results) != 1 or not re.fullmatch(summary, results[0]):
        raise RuntimeError('Exactly one bounded clean compiler result required')
    if lines.index(banners[0]) >= lines.index(results[0]):
        raise RuntimeError('Compiler result preceded its banner')

