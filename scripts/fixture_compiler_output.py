"""Compiler output predicate shared by legacy fixture runners.

Each runner keeps its own version, artifact and runtime policies.
"""
import re


def compiler_matches(text, returncode, version):
    return (returncode == 0 and
            re.search(r'^DM compiler version ' + re.escape(version) + r'\b', text, re.MULTILINE) is not None and
            re.search(r'\b0 errors,\s*0 warnings\b', text) is not None)
