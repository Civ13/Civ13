"""Synthetic child: one marker, one bounded wait, no network or services."""
import os
from pathlib import Path
import sys
import time

if len(sys.argv)!=4 or sys.argv[1:3]!=['--catalog-only','--game-catalog']:
    raise SystemExit(11)
root=Path.cwd()
if Path(sys.argv[3])!=root/'unused-catalog.json':raise SystemExit(12)
with (root/'child-ready.marker').open('xb') as out:
    out.write(b'ready-v1');out.flush();os.fsync(out.fileno())
os.write(1,b'R')
deadline=time.monotonic()+8
while time.monotonic()<deadline:
    try:
        with (root/'release.marker').open('rb') as stream:value=stream.read(9)
    except FileNotFoundError:
        time.sleep(0.05)
        continue
    raise SystemExit(0 if value==b'release1' else 13)
raise SystemExit(14)
