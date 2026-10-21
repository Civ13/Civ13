"""Verify the actual seed OpenPort override on pinned native BYOND, offline."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

from prepare import instrument_world


def daemon_arguments(daemon):
    return [str(daemon), 'probe.dmb', '-close', '-invisible', '-trusted',
            '-params', 'gaia_intent_seed=1', '-log', 'native.log']


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--hold-seconds', type=int, default=5, help='Keep the closed fixture alive to observe delayed engine diagnostics (5-180 seconds)')
    p.add_argument('--compiled-hub', action='store_true', help='Include checkout hub metadata to compare native startup against the default fixture')
    a = p.parse_args()
    if not 5 <= a.hold_seconds <= 180:
        p.error('--hold-seconds must be between5 and180')
    root = Path(tempfile.mkdtemp(prefix='civ13-gaia-seed-port-'))
    print(f'Evidence: {root}', flush=True)
    control = Path(__file__).with_name('control.dm').read_text(encoding='utf-8-sig')
    start = control.index('/world/OpenPort(port)\n')
    end = control.index('/proc/gaia_probe_seed_intent()', start)
    guard = control[start:end]
    production = Path(__file__).resolve().parents[3] / 'code/world.dm'
    source = production.read_text(encoding='utf-8-sig')
    start_new = source.index('/world/New()\n')
    end_new = source.index('\tpersistence_restart.detect_startup()\n', start_new)
    startup = source[start_new:end_new] + '\ttext2file("unexpected ordinary startup", "ordinary-startup.txt")\n'
    startup += '/world/Topic(T, addr, master, key)\n\treturn\n'
    startup = instrument_world(startup)
    fixture = r'''
var/datum/probe_storage/map_storage = new
/datum/probe_storage/proc/record_compiled_dimensions()
    text2file("dimensions", "dimensions.txt")
/proc/gaia_probe_topic(T, addr)
    return
/proc/gaia_probe_seed_intent()
    var/list/R = list("passed" = FALSE, "initial_port" = world.port, "seed_param" = world.params["gaia_intent_seed"], "seed_param_is_text" = istext(world.params["gaia_intent_seed"]), "seed_param_is_number" = isnum(world.params["gaia_intent_seed"]))
    R["branch_selected"] = TRUE
    R["entry_marker"] = fexists("seed-entry.json")
    R["dimensions_recorded"] = fexists("dimensions.txt")
    R["ordinary_startup"] = fexists("ordinary-startup.txt")
    world.OpenPort("none")
    R["seed_entry_port"] = world.port
    var/any_result = world.OpenPort(0)
    R["any_result"] = any_result
    R["after_any_port"] = world.port
    var/fixed_result = world.OpenPort(18464)
    R["fixed_result"] = fixed_result
    R["after_fixed_port"] = world.port
    world.OpenPort("none")
    R["closed_port"] = world.port
    R["passed"] = R["seed_param"] == "1" && R["seed_param_is_text"] && R["entry_marker"] && R["dimensions_recorded"] && !R["ordinary_startup"] && !R["seed_entry_port"] && !any_result && !R["after_any_port"] && !fixed_result && !R["after_fixed_port"] && !world.port
    text2file(json_encode(R), "port-result.json")
    sleep(50)
    del(world)
'''
    (root / 'probe.dm').write_text('#define FALSE 0\n#define TRUE 1\n' + guard + startup + fixture.replace('sleep(50)', f'sleep({a.hold_seconds * 10})'), encoding='utf-8')
    includes = '#include "probe.dm"\n'
    if a.compiled_hub:
        (root / 'hub.dm').write_bytes((production.parents[1] / 'code/hub.dm').read_bytes())
        includes += '#include "hub.dm"\n'
    (root / 'probe.dme').write_text(includes, encoding='utf-8')
    compiler = a.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = a.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    built = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=root, capture_output=True, text=True, timeout=60)
    (root / 'compile.log').write_text(built.stdout + built.stderr, encoding='utf-8')
    if built.returncode or '516.1681' not in built.stdout or '0 errors, 0 warnings' not in built.stdout:
        raise RuntimeError('Port probe compile failed')
    with (root / 'stdout.log').open('w') as out, (root / 'stderr.log').open('w') as err:
        child = subprocess.Popen(daemon_arguments(daemon), cwd=root, stdout=out, stderr=err)
        try:
            deadline = time.monotonic() + 15
            while not (root / 'port-result.json').exists():
                if child.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('Production seed branch did not produce its receipt')
                time.sleep(0.05)
            if os.name == 'nt':
                command = f'$P=Get-Process -Id {child.pid} -ErrorAction Stop; $L=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object OwningProcess -eq {child.pid}); [ordered]@{{pid=$P.Id;listeners=$L.Count}} | ConvertTo-Json -Compress'
                observed = subprocess.run(['powershell', '-NoProfile', '-Command', command], capture_output=True, text=True, timeout=20, check=True)
                census = json.loads(observed.stdout)
                (root / 'listener.json').write_text(json.dumps(census), encoding='utf-8')
                if census['listeners'] or child.poll() is not None:
                    raise RuntimeError('Port probe not alive with zero listeners at census')
            code = child.wait(timeout=a.hold_seconds + 30)
        finally:
            if child.poll() is None:
                child.kill()
                child.wait(timeout=10)
    diagnostic = '\n'.join(p.read_text(encoding='utf-8', errors='replace') for p in root.glob('*.log'))
    result = json.loads((root / 'port-result.json').read_text(encoding='utf-8'))
    if code or not result['passed'] or re.search(r'BUG:|runtime error:|bad ref|##\s*ERROR\s*:', diagnostic, re.I):
        raise RuntimeError(f'Native port contract failed: {result}')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
