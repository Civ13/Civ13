"""Read-only native identity census and pure socket policy checks."""
import json
from pathlib import Path
import subprocess


def require(value, message):
    if not value:
        raise RuntimeError(message)


def validate_census(rows):
    require(type(rows) is list and len(rows) <= 32, 'Invalid native census size')
    seen = set()
    for row in rows:
        require(type(row) is dict and type(row.get('pid')) is int and row['pid'] > 0
                and type(row.get('creation_filetime')) is int and row['creation_filetime'] > 0
                and isinstance(row.get('image'), str) and bool(row['image'].strip())
                and row['pid'] not in seen, 'Invalid native census identity')
        seen.add(row['pid'])
    return rows


def census():
    command = "$ErrorActionPreference='Stop'; @{rows=@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -in @('dd','dm','DreamDaemon','DreamMaker') } | ForEach-Object { if ([string]::IsNullOrWhiteSpace($_.Path)) { throw 'Native image path unavailable' }; @{pid=$_.Id;creation_filetime=$_.StartTime.ToUniversalTime().ToFileTimeUtc();image=$_.Path.ToLowerInvariant()} })} | ConvertTo-Json -Depth 4 -Compress"
    return validate_census(json.loads(subprocess.check_output(
        ['powershell.exe', '-NoProfile', '-Command', command], text=True, timeout=20))['rows'])


def validate_baseline(rows, baseline, daemon):
    rows = validate_census(rows)
    require(len(rows) == 1 and rows[0]['pid'] == baseline['pid']
            and rows[0]['creation_filetime'] == baseline['creation_filetime']
            and Path(rows[0]['image']).resolve() == Path(daemon).resolve(),
            'Native census differs from sole pinned daemon')


def validate_sockets(rows, phase, closed):
    for sock in rows:
        require(phase == 'runtime' and sock.get('protocol') == 'tcp', 'Unexpected owned socket')
        if sock.get('state') == 'listen':
            require(not closed and sock.get('address') == '127.0.0.1'
                    and type(sock.get('port')) is int and sock['port'] == 59474,
                    'Unexpected owned listener')
        else:
            require(sock.get('state') in tuple(str(n) for n in range(5, 13))
                    and sock.get('address') == sock.get('remote_address') == '127.0.0.1'
                    and all(type(sock.get(key)) is int and 1 <= sock[key] <= 65535
                            for key in ('port', 'remote_port')), 'Unexpected owned connection')
