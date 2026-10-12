"""Reuse the production GC fixture and its isolated native launcher."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
raise SystemExit(subprocess.call([
    sys.executable, str(root / 'tests/memory_ownership/run.py'),
    '--case', 'triage', *sys.argv[1:]
], cwd=root))
