"""Real-client network check for upper levels. Windows only.

Builds a temporary copy of civ13.dme with tests/open_air_view/bandwidth_probe.dm,
starts the daemon on a loopback port, puts a byte-counting TCP proxy in front of
it and connects one Dream Seeker client through the proxy. The probe walks the
client's body through stages (ground, one and two levels up, looking up); the
proxy counts what the server sends during each stage's measure window.

Prints and saves kilobits per second per stage. With --max-ratio the run fails
when a stage on an upper level sends more than that many times the ground stage
of the same kind (still or walking): the regression check.

Nothing here touches a live server: its own ports, its own folder, versioned
sample config plus DAYNIGHT_CLIENT_TINT as on live regions. Generated sources
are removed afterwards.
"""
import argparse
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time
import uuid

REQUIRED_CHECKS = ('body_ready', 'stages_measured')
PROBE_INCLUDE = '\n#include "tests\\open_air_view\\bandwidth_probe.dm"\n'


def free_port():
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        return probe.getsockname()[1]


class CountingProxy:
    """Forwards loopback TCP connections to the daemon and counts bytes by phase."""

    def __init__(self, listen_port, target_port):
        self.listen_port = listen_port
        self.target_port = target_port
        self.phase = 'startup'
        self.down = {}  # phase -> bytes server -> client
        self.up = {}  # phase -> bytes client -> server
        self.lock = threading.Lock()
        self.server = socket.socket()
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server.bind(('127.0.0.1', listen_port))
        self.server.listen(8)
        threading.Thread(target=self.accept, daemon=True).start()

    def count(self, table, n):
        with self.lock:
            table[self.phase] = table.get(self.phase, 0) + n

    def accept(self):
        while True:
            try:
                inbound, _ = self.server.accept()
            except OSError:
                return
            outbound = socket.create_connection(('127.0.0.1', self.target_port))
            for sock in (inbound, outbound):
                sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            threading.Thread(target=self.pump, args=(outbound, inbound, self.down), daemon=True).start()
            threading.Thread(target=self.pump, args=(inbound, outbound, self.up), daemon=True).start()

    def pump(self, source, sink, table):
        try:
            while True:
                data = source.recv(65536)
                if not data:
                    break
                self.count(table, len(data))
                sink.sendall(data)
        except OSError:
            pass
        for sock in (source, sink):
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass

    def close(self):
        self.server.close()


def read_json(path):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (FileNotFoundError, json.JSONDecodeError, PermissionError):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--config-line', action='append', default=None, help='extra line for the run copy of config/config.txt (default: DAYNIGHT_CLIENT_TINT, as on live)')
    parser.add_argument('--max-ratio', type=float, default=0, help='fail when an upper-level stage sends more than this many times the matching ground stage')
    parser.add_argument('--deadline', type=int, default=5400, help='seconds for the whole run')
    args = parser.parse_args()
    if sys.platform != 'win32':
        raise SystemExit('This check needs a Windows Dream Seeker client')
    config_lines = ['DAYNIGHT_CLIENT_TINT'] if args.config_line is None else args.config_line
    repo = Path(__file__).resolve().parents[2]
    output = (args.output or Path(tempfile.gettempdir()) / ('civ13-open-air-bandwidth-' + uuid.uuid4().hex)).resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError('Output evidence directory must be fresh')
    output.mkdir(parents=True, exist_ok=True)
    port = free_port()
    proxy_port = free_port()
    head = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
    status = subprocess.check_output(['git', '-C', str(repo), 'status', '--porcelain'], text=True)
    source = repo / ('.open_air_bandwidth_' + uuid.uuid4().hex + '.dme')
    created = [source.with_suffix(suffix) for suffix in ('.dme', '.dmb', '.rsc', '.int', '.lk')]
    daemon = client = proxy = None
    try:
        dme = (repo / 'civ13.dme').read_text(encoding='utf-8-sig')
        source.write_text(dme + PROBE_INCLUDE, encoding='utf-8')
        build = subprocess.run([str(args.byond_bin / 'dm.exe'), '-max_errors', '0', source.name], cwd=repo, capture_output=True, text=True, timeout=1200)
        log = build.stdout + build.stderr
        (output / 'compile.log').write_text(log, encoding='utf-8')
        if build.returncode or '0 errors, 0 warnings' not in log:
            raise RuntimeError('Probe compilation failed; see compile.log')
        source.with_suffix('.dmb').replace(output / 'probe.dmb')
        source.with_suffix('.rsc').replace(output / 'probe.rsc')
        for path in subprocess.check_output(['git', '-C', str(repo), 'ls-files', '--', 'config', 'maps/heights'], text=True).splitlines():
            target = output / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((repo / path).read_bytes())
        if config_lines:
            with (output / 'config' / 'config.txt').open('a', encoding='utf-8') as extra:
                extra.write('\n' + '\n'.join(config_lines) + '\n')
        (output / 'manifest.json').write_text(json.dumps({
            'tested_commit': head, 'working_tree_status': status, 'port': port, 'proxy_port': proxy_port, 'config_lines': config_lines,
            'adapters': ['probe appended to a temporary civ13.dme', 'webhooks/ToRban off', 'round started via admin_started',
                         'staged body fed and held warm', 'walkways staged by the probe', 'client connects through a counting proxy']}, indent=2), encoding='utf-8')
        with (output / 'daemon-output.log').open('w') as out:
            daemon = subprocess.Popen([str(args.byond_bin / 'dd.exe'), 'probe.dmb', str(port), '-trusted', '-ip', '127.0.0.1',
                                       '-params', 'tested_commit=' + head, '-log', 'startup.log'], cwd=output, stdout=out, stderr=subprocess.STDOUT)
        proxy = CountingProxy(proxy_port, port)
        print(f'Daemon PID {daemon.pid} on 127.0.0.1:{port}, proxy on {proxy_port}; evidence in {output}', flush=True)
        started = time.monotonic()
        last_phase = None
        phase_started = {}
        while not (output / 'result.json').exists():
            if time.monotonic() - started > args.deadline:
                raise RuntimeError(f'Whole-run {args.deadline}-second deadline')
            if daemon.poll() is not None:
                break
            phase = (read_json(output / 'phase.json') or {}).get('phase')
            if phase and phase != last_phase:
                proxy.phase = phase
                phase_started[phase] = time.monotonic()
                print(f'[{round(time.monotonic() - started)} s] {phase}', flush=True)
                last_phase = phase
            if phase == 'waiting_for_client' and client is None:
                client = subprocess.Popen([str(args.byond_bin / 'dreamseeker.exe'), f'byond://127.0.0.1:{proxy_port}'])
            time.sleep(0.1)
        time.sleep(3)
        result = read_json(output / 'result.json')
        if not result:
            raise RuntimeError(f'No result.json (daemon exit {daemon.poll()}); see {output}')
        stages = result.get('stages') or {}
        measured = {}
        for name, info in stages.items():
            seconds = info.get('seconds') or 1
            down = proxy.down.get('measure_' + name, 0)
            settle = proxy.down.get('settle_' + name, 0)
            measured[name] = dict(info, kbps_down=round(down * 8 / 1000 / seconds, 1), bytes_down=down,
                                  kbps_up=round(proxy.up.get('measure_' + name, 0) * 8 / 1000 / seconds, 1),
                                  settle_bytes_down=settle)
        ratios = {}
        for name, row in measured.items():
            if name.startswith('ground_'):
                continue
            ground = measured.get('ground_walk' if 'walk' in name else 'ground_still')
            if ground:
                ratios[name] = round(row['kbps_down'] / max(ground['kbps_down'], 1.0), 2)
        too_high = {name: ratio for name, ratio in ratios.items() if args.max_ratio and ratio > args.max_ratio}
        passed = [row['check'] for row in result.get('checks', []) if row.get('passed')]
        missing = [name for name in REQUIRED_CHECKS if name not in passed]
        summary = {'passed': bool(result.get('passed')) and not missing and not too_high, 'failure': result.get('failure'),
                   'failed_phase': result.get('failed_phase'), 'missing_checks': missing, 'stages': measured,
                   'ratio_to_ground': ratios, 'over_max_ratio': too_high, 'max_ratio': args.max_ratio,
                   'metrics': result.get('metrics'), 'tested_commit': head, 'output': str(output)}
        (output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
        print(json.dumps(summary, indent=2))
        if not summary['passed']:
            raise SystemExit(1)
    finally:
        for process in (client, daemon):
            if process and process.poll() is None:
                process.kill()
                process.wait(timeout=15)
        if proxy:
            proxy.close()
        for path in created:
            if path.exists():
                path.unlink()


if __name__ == '__main__':
    main()
