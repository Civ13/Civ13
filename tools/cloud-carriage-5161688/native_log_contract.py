"""Reject observer-swallowed errors in bounded logs of this owned native server."""
from pathlib import Path

def check_server_logs(output, require_sentinel=False):
    found=[]; sentinel=False
    for name in ('server.stdout.log','server.stderr.log'):
        p=Path(output)/name
        if not p.exists():continue
        if p.is_symlink() or not p.is_file() or p.stat().st_size>1024**2:raise ValueError('Invalid owned server log')
        data=p.read_bytes()
        if len(data)>1024**2:raise ValueError('Owned server log grew beyond cap')
        if any(marker in data.lower() for marker in (b'## error:',b'runtime error:')):
            raise ValueError('Owned server reported native/observer error')
        sentinel |= b"CARRIAGE_LEASE_LOG_SOURCE=5260b60f0efef2c0af70fae204b1180106ef50b3" in data
        found.append(name)
    if require_sentinel and not sentinel:raise ValueError("Native world.log routing sentinel missing")
    return found
