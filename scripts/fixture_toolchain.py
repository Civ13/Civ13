"""Exact current-toolchain checks for active extraction/admission fixtures.

Historical fixture runners keep their own pins. This module neither provisions
an engine nor changes any process, socket, timeout or assertion policy.
"""
import importlib.util
from pathlib import Path
import re
import subprocess

_spec = importlib.util.spec_from_file_location('fixture_runtime_identity', Path(__file__).with_name('byond_runtime.py'))
runtime = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(runtime)
VERSION = runtime.pin.load()['version']
DIAGNOSTIC = re.compile(r'runtime error:|bad ref|BUG:|##\s*ERROR\s*:|RUNTIME:|assertion failed|infinite loop|segmentation|fatal error', re.I)


def verify(binary):
    """Re-read installed members before each launch; no cached acceptance."""
    binary = Path(binary).absolute()
    identity = runtime.verify_linux(binary.parent, binary.parent.parents[1] / 'pinned.zip')
    if identity['version'] != VERSION:
        raise RuntimeError('Fixture runtime differs from the current manifest')
    return identity


def validate_compiler(result):
    output = result.stdout + '\n' + result.stderr
    lines = output.splitlines()
    banners = [line for line in lines if re.search(r'DM compiler version', line, re.I)]
    summaries = [line for line in output.splitlines() if re.search(r'\berrors?\b|\bwarnings?\b', line, re.I)]
    if (result.returncode or len(output.encode('utf-8')) > 1024 * 1024 or DIAGNOSTIC.search(output)
            or banners != ['DM compiler version ' + VERSION]
            or len(summaries) != 1
            or not re.fullmatch(r'(?:.* - )?0 errors, 0 warnings(?: \([^\r\n]+\))?', summaries[0])):
        raise RuntimeError('One exact current compiler banner and clean result required:\n' + output[:4096])
    if lines.index(banners[0]) >= lines.index(summaries[0]):
        raise RuntimeError('Compiler result preceded its exact version banner')


def run_compiler(command, **kwargs):
    verify(command[0])
    result = subprocess.run(command, **kwargs)
    validate_compiler(result)
    return result


def run_daemon(command, **kwargs):
    verify(command[0])
    return subprocess.run(command, **kwargs)
