"""Local two-world flight test (developer evidence, not CI).

Builds two full worlds from temporary copies of civ13.dme with
tests/orbit_flight/flight.dm appended: "gaia", the mainland on
maps/nomads/nomads_gaia.dmm, and "orbit", an ORBIT region on
maps/space/orbit.dmm. Each world runs in its own folder with its own
config/shard_region.json and config/transfer_agent.json, and talks to its own
transfer agent (tools/transfer_storage/agent.py, served in this process) that a
coordinator relays between, as the live region group does. Saving is off
(SKIP_PERSISTENCE_SAVING); character trips are journaled, so they need no save.

The mainland sends a crew of two up through a launch complex office that holds
a station plan; the orbit world checks the station was founded from the plan
and sends them home through the return hatch; the mainland checks they came
back to the office. See flight.dm for the exact checks.

    python3 tests/orbit_flight/native_flight.py --byond-bin ~/byond-516.1688/byond/bin \\
        --rust-g librust_g.so --output /fresh/dir

Linux needs the i686 librust_g.so of rust-g 3.0.0 (its SHA-256 is checked, as
tests/transfer_storage/pilot/run.py does). Nothing here downloads anything or
touches a server or save outside the output folder. Generated sources are
removed afterwards.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import subprocess
import sys
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.transfer_storage.agent import make_server  # noqa: E402
from tools.transfer_storage.coordinator import Coordinator  # noqa: E402
from tools.transfer_storage.region import IN, OUT, RegionStore  # noqa: E402

BEGIN, END = '// BEGIN_SELECTED_MAP', '// END_SELECTED_MAP'
GROUP = 'flighttest'
WORLDS = {
    'gaia': {'name': 'Gaia', 'kind': 'SURFACE', 'map': 'maps\\nomads\\nomads_gaia.dmm'},
    'orbit': {'name': 'Low Orbit', 'kind': 'ORBIT', 'map': 'maps\\space\\orbit.dmm'},
}
RUST_G_SHA256 = {'librust_g.so': 'b92f18e19667148628b3f45dbdf58765eab18daa14d1d28db8dfe83211165b45'}
RUNTIME = re.compile(r'runtime error: (.*)\nproc name: (.*)\n\s*source file: ([^,\n]+),(\d+)')
REQUIRED = {
    'gaia': ('bridge_reconciled', 'peer_up', 'pad_and_office', 'plan_taken', 'station_ready', 'launched', 'crew_home'),
    'orbit': ('bridge_reconciled', 'peer_up', 'crew_aboard', 'station_from_plan', 'left_for_home', 'station_kept'),
}


def free_port():
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        return probe.getsockname()[1]


def byond_env(bin_dir):
    env = dict(os.environ)
    env['LD_LIBRARY_PATH'] = os.pathsep.join(p for p in (str(bin_dir), env.get('LD_LIBRARY_PATH')) if p)
    return env


def generate(prefix, map_path):
    dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
    start, stop = dme.index(BEGIN), dme.index(END)
    dme = dme[:start] + BEGIN + '\n#include "' + map_path + '"\n' + dme[stop:]
    dme += '\n#include "tests\\orbit_flight\\flight.dm"\n'
    path = ROOT / (prefix + '.dme')
    path.write_text(dme, encoding='utf-8')
    return path


def compile_world(source, bin_dir, log):
    build = subprocess.run([str(bin_dir / 'DreamMaker'), '-max_errors', '0', source.name], cwd=ROOT,
                           capture_output=True, text=True, timeout=1800, env=byond_env(bin_dir))
    text = build.stdout + build.stderr
    log.write_text(text, encoding='utf-8')
    if build.returncode or '0 errors, 0 warnings' not in text:
        raise RuntimeError('%s did not compile; see %s' % (source.name, log))


def runtime_errors(folder):
    text = ''
    for path in sorted(folder.glob('*.log')):
        text += path.read_text(errors='replace') + '\n'
    rows = {}
    for message, proc, source, line in RUNTIME.findall(text):
        key = '%s:%s: %s (%s)' % (source.replace(chr(92), '/'), line, message.strip(), proc.strip())
        rows[key] = rows.get(key, 0) + 1
    return rows


def check_rust_g(path):
    expected = RUST_G_SHA256.get(path.name)
    if expected and hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        raise SystemExit('%s is not the pinned rust-g 3.0.0 build' % path)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--rust-g', type=Path, required=True, help='rust-g 3.0.0 librust_g.so')
    parser.add_argument('--output', type=Path, required=True, help='fresh evidence directory')
    parser.add_argument('--deadline', type=int, default=2400, help='seconds both worlds may run')
    args = parser.parse_args()
    bin_dir = args.byond_bin.expanduser().resolve()
    rust_g = check_rust_g(args.rust_g.expanduser().resolve())
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise SystemExit('Evidence directory is not empty: %s' % output)
    output.mkdir(parents=True, exist_ok=True)
    tag = uuid.uuid4().hex[:8]
    sources = {role: generate('orbit_flight_%s_%s' % (role, tag), info['map']) for role, info in WORLDS.items()}
    created = [p.with_suffix(s) for p in sources.values() for s in ('.dme', '.dmb', '.rsc', '.int', '.lk')]
    servers, stores, processes = [], {}, {}
    stop_relay = threading.Event()
    relay_thread = None
    started = time.monotonic()
    try:
        with concurrent.futures.ThreadPoolExecutor(len(sources)) as pool:
            for job in [pool.submit(compile_world, sources[r], bin_dir, output / ('compile-%s.log' % r)) for r in sources]:
                job.result()
        compiled = round(time.monotonic() - started)
        tracked = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '--', 'config'], text=True).splitlines()
        ports = {role: free_port() for role in WORLDS}
        regions = [{'id': r, 'name': i['name'], 'kind': i['kind'], 'address': '127.0.0.1:%d' % ports[r]} for r, i in WORLDS.items()]
        tokens, urls = {}, {}
        for role in WORLDS:
            tokens[role] = secrets.token_hex(24)
            store = RegionStore(str(output / ('%s.sqlite' % role)), role, GROUP)
            for other in WORLDS:
                if other != role:
                    store.enroll(other, OUT)
                    store.enroll(other, IN)
            server = make_server(store, tokens[role])
            threading.Thread(target=server.serve_forever, daemon=True).start()
            stores[role] = store
            servers.append(server)
            urls[role] = 'http://127.0.0.1:%d' % server.server_address[1]

        relay_errors = []

        def relay():
            coordinator = Coordinator(str(output / 'coordinator.sqlite'), GROUP)
            for name in urls:
                coordinator.enroll(name, urls[name], tokens[name])
            while not stop_relay.is_set():
                try:
                    coordinator.relay_once()
                except OSError as error:
                    relay_errors.append(str(error))
                stop_relay.wait(0.5)
            coordinator.close()

        relay_thread = threading.Thread(target=relay, daemon=True)
        relay_thread.start()
        for role, source in sources.items():
            folder = output / role
            folder.mkdir()
            shutil.copy2(source.with_suffix('.dmb'), folder / 'flight.dmb')
            shutil.copy2(source.with_suffix('.rsc'), folder / 'flight.rsc')
            for path in tracked:
                dest = folder / path
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / path, dest)
            with (folder / 'config' / 'config.txt').open('a', encoding='utf-8') as config:
                config.write('\nSKIP_PERSISTENCE_SAVING\n')
            shutil.copy2(rust_g, folder / rust_g.name)
            (folder / 'config' / 'transfer-token.txt').write_text(tokens[role] + '\n', encoding='utf-8')
            (folder / 'config' / 'transfer_agent.json').write_text(json.dumps(
                {'port': int(urls[role].rsplit(':', 1)[1]), 'token_file': 'config/transfer-token.txt', 'poll_seconds': 1,
                 'peers': [other for other in WORLDS if other != role]}), encoding='utf-8')
            (folder / 'config' / 'shard_region.json').write_text(json.dumps(
                {'group': GROUP, 'region': role, 'mainland': 'gaia', 'regions': regions}), encoding='utf-8')
            (folder / 'flight.json').write_text(json.dumps({'role': role}), encoding='utf-8')
            out = (folder / 'stdout.log').open('w')
            processes[role] = (subprocess.Popen(
                [str(bin_dir / 'DreamDaemon'), 'flight.dmb', str(ports[role]), '-trusted', '-invisible',
                 '-ip', '127.0.0.1', '-log', 'world.log'],
                cwd=folder, stdout=out, stderr=subprocess.STDOUT, env=byond_env(bin_dir)), out)
        while True:
            done = [r for r in WORLDS if (output / r / ('result-%s.json' % r)).exists()]
            failed = [r for r in done if not json.loads((output / r / ('result-%s.json' % r)).read_text())['passed']]
            exited = [r for r, (p, _) in processes.items() if p.poll() is not None and r not in done]
            if len(done) == len(WORLDS) or failed or exited:
                break
            if time.monotonic() - started > args.deadline:
                break
            time.sleep(2)
        time.sleep(3)
        results, failures = {}, []
        for role in WORLDS:
            path = output / role / ('result-%s.json' % role)
            if not path.exists():
                failures.append('%s wrote no result' % role)
                continue
            results[role] = json.loads(path.read_text())
            passed = [c['check'] for c in results[role]['checks'] if c.get('passed')]
            if not results[role]['passed']:
                failures.append('%s failed in %s: %s' % (role, results[role]['failed_phase'], results[role]['failure']))
            missing = [c for c in REQUIRED[role] if c not in passed]
            if missing and results[role]['passed']:
                failures.append('%s skipped %s' % (role, missing))
        errors = {role: runtime_errors(output / role) for role in WORLDS}
        flight_errors = {role: {k: v for k, v in rows.items() if re.search(r'space/|orbit|region_travel|transfer_bridge|party_train|flight', k)}
                         for role, rows in errors.items()}
        for role, rows in flight_errors.items():
            for key in rows:
                failures.append('%s runtime: %s' % (role, key))
        statuses = {}
        for role in WORLDS:
            try:
                statuses[role] = stores[role].status()
            except Exception as error:  # noqa: BLE001 - evidence only
                statuses[role] = {'error': str(error)}
        summary = {'passed': not failures, 'failures': failures, 'compile_seconds': compiled,
                   'wall_seconds': round(time.monotonic() - started),
                   'checks': {r: [(c['check'], c.get('at'), c.get('details')) for c in res['checks']] for r, res in results.items()},
                   'other_runtime_error_sites': {r: len(errors[r]) - len(flight_errors[r]) for r in WORLDS},
                   'relay_errors': relay_errors[-5:], 'agents': statuses, 'output': str(output)}
        (output / 'summary.json').write_text(json.dumps(summary, indent=2, default=str), encoding='utf-8')
        (output / 'runtime-errors.json').write_text(json.dumps(errors, indent=2), encoding='utf-8')
        print(json.dumps({k: summary[k] for k in ('passed', 'failures', 'compile_seconds', 'wall_seconds', 'checks', 'other_runtime_error_sites')}, indent=2, default=str))
        return 0 if not failures else 1
    finally:
        for process, out in processes.values():
            if process.poll() is None:
                process.kill()
                process.wait(timeout=20)
            out.close()
        stop_relay.set()
        if relay_thread:
            relay_thread.join(5)
        for server in servers:
            server.shutdown()
            server.server_close()
        for store in stores.values():
            store.close()
        for path in created:
            if path.exists():
                path.unlink()


if __name__ == '__main__':
    sys.exit(main())
