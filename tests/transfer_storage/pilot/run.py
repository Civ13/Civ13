"""Two-region transfer pilot: real DM bridge and trade post, forced restarts.

Starts two region agents and a relay in this process, and two DreamDaemon
worlds built from the real transfer_bridge.dm, transfer_trade_post.dm, http.dm
and the transfer hooks in functions.dm. The worlds ship wood to each other while
this driver kills and restarts them at random moments. It then drains every
transfer, stops both worlds after a final save, and checks that the committed
saves hold exactly the wood the run started with and that nothing is in flight.

Native execution needs a caller-supplied pinned BYOND directory and rust_g:

    python3 tests/transfer_storage/pilot/run.py --byond-bin ~/byond-516.1688/byond/bin \\
        --rust-g librust_g.so --seconds 120

On Windows the repository's rust_g.dll is used when --rust-g is omitted. On
Linux pass the i686 librust_g.so of rust-g 3.0.0 (the version of rust_g.dll);
its SHA-256 is checked. This program never downloads anything and touches no
server or save outside its own temporary directory.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from tools.transfer_storage.agent import make_server  # noqa: E402
from tools.transfer_storage.coordinator import Coordinator, call  # noqa: E402
from tools.transfer_storage.region import IN, OUT, RegionStore  # noqa: E402

RUST_G_SHA256 = {'librust_g.so': 'b92f18e19667148628b3f45dbdf58765eab18daa14d1d28db8dfe83211165b45'}
SOURCES = ('code/__defines/_rust_g.dm', 'code/datums/http.dm',
           'code/modules/persistence/transfer_bridge.dm', 'code/modules/persistence/transfer_trade_post.dm')
HOOKS_START = '// Transfer storage hooks (tools/transfer_storage).'
HOOKS_END = '/map_storage/proc/read_round_state()'
REGIONS = {
    'alpha': {'peer': 'beta', 'player': 'alice', 'peer_player': 'bob'},
    'beta': {'peer': 'alpha', 'player': 'bob', 'peer_player': 'alice'},
}
GROUP = 'pilot'


def byond_env(bin_dir):
    env = dict(os.environ)
    if os.name != 'nt':
        # What byondsetup does: DreamMaker and DreamDaemon load libbyond.so from here.
        env['LD_LIBRARY_PATH'] = os.pathsep.join(p for p in (str(bin_dir), env.get('LD_LIBRARY_PATH')) if p)
    return env


def transfer_hooks():
    """The transfer hooks and validator exactly as functions.dm defines them."""
    text = (ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8-sig')
    return text[text.index(HOOKS_START):text.index(HOOKS_END)]


def build(build_dir, dream_maker):
    build_dir.mkdir(parents=True)
    names = []
    for source in SOURCES:
        name = Path(source).name
        shutil.copy(ROOT / source, build_dir / name)
        names.append(name)
    shutil.copy(HERE / 'stubs.dm', build_dir / 'stubs.dm')
    shutil.copy(HERE / 'pilot_world.dm', build_dir / 'pilot_world.dm')
    (build_dir / 'hooks.dm').write_text(transfer_hooks(), encoding='utf-8')
    # The trade post names a game icon; the pilot draws nothing.
    post = (build_dir / 'transfer_trade_post.dm').read_text(encoding='utf-8')
    (build_dir / 'transfer_trade_post.dm').write_text(post.replace("\ticon = 'icons/obj/structures.dmi'\n", ''), encoding='utf-8')
    includes = ['stubs.dm', 'hooks.dm'] + names + ['pilot_world.dm']
    (build_dir / 'pilot.dme').write_text(''.join('#include "%s"\n' % n for n in includes), encoding='utf-8')
    result = subprocess.run([str(dream_maker), 'pilot.dme'], cwd=build_dir, capture_output=True, text=True,
                            env=byond_env(Path(dream_maker).parent))
    if '- 0 errors, 0 warnings' not in result.stdout:
        raise SystemExit('pilot build failed:\n' + result.stdout + result.stderr)
    return build_dir / 'pilot.dmb'


class World:
    def __init__(self, name, directory, dmb, daemon, rust_g, port, token):
        self.name, self.dir, self.daemon = name, directory, daemon
        (directory / 'saves').mkdir(parents=True)
        (directory / 'config').mkdir()
        shutil.copy(dmb, directory / 'pilot.dmb')
        shutil.copy(rust_g, directory / Path(rust_g).name)
        (directory / 'token.txt').write_text(token + '\n', encoding='utf-8')
        (directory / 'config' / 'transfer_agent.json').write_text(json.dumps(
            {'port': port, 'token_file': 'token.txt', 'peers': [REGIONS[name]['peer']], 'poll_seconds': 1}), encoding='utf-8')
        config = dict(REGIONS[name], region=name, stacks=20, stack_size=10)
        (directory / 'pilot.json').write_text(json.dumps(config), encoding='utf-8')
        self.process = None
        self.log = open(directory / 'world.log', 'a', encoding='utf-8')
        self.kills = 0

    def start(self):
        self.process = subprocess.Popen([str(self.daemon), 'pilot.dmb', '-trusted', '-invisible'],
                                        cwd=self.dir, stdout=self.log, stderr=subprocess.STDOUT,
                                        env=byond_env(Path(self.daemon).parent))

    def kill(self):
        if self.process and self.process.poll() is None:
            self.process.kill()
            self.process.wait()
            self.kills += 1

    def running(self):
        return self.process is not None and self.process.poll() is None

    def committed(self):
        stopped = self.dir / 'stopped.txt'
        n = int(stopped.read_text().strip()) if stopped.exists() else 0
        data = json.loads((self.dir / 'saves' / ('save-%d.json' % n)).read_text())
        holdings = data['holdings'] if isinstance(data['holdings'], dict) else {}
        return sum(data['stacks']) + sum(holdings.values())


def check_rust_g(path):
    path = Path(path)
    expected = RUST_G_SHA256.get(path.name)
    if expected and hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        raise SystemExit('%s is not the pinned rust-g 3.0.0 build' % path)
    return path


def idle(urls, tokens):
    for name in urls:
        status = call(urls[name], tokens[name], '/status')['result']
        if status['active'] or call(urls[name], tokens[name], '/outbox')['result']['envelopes']:
            return False
    return True


def run(args):
    bin_dir = Path(args.byond_bin).expanduser()
    exe = '.exe' if os.name == 'nt' else ''
    dream_maker = bin_dir / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = bin_dir / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    rust_g = check_rust_g(args.rust_g or (ROOT / ('rust_g.dll' if exe else 'librust_g.so')))
    rng = random.Random(args.seed)
    with tempfile.TemporaryDirectory(prefix='transfer-pilot-') as tmp:
        tmp = Path(args.workdir) if args.workdir else Path(tmp)
        dmb = build(tmp / 'build', dream_maker)
        tokens = {name: hashlib.sha256(('%s-%d' % (name, args.seed)).encode()).hexdigest() for name in REGIONS}
        stores, servers, urls = {}, [], {}
        for name, info in REGIONS.items():
            store = RegionStore(str(tmp / (name + '.sqlite')), name, GROUP)
            store.enroll(info['peer'], OUT)
            store.enroll(info['peer'], IN)
            server = make_server(store, tokens[name])
            threading.Thread(target=server.serve_forever, daemon=True).start()
            stores[name] = store
            servers.append(server)
            urls[name] = 'http://127.0.0.1:%d' % server.server_address[1]
        stop_relay = threading.Event()

        def relay():
            coordinator = Coordinator(str(tmp / 'coordinator.sqlite'), GROUP)
            for name in urls:
                coordinator.enroll(name, urls[name], tokens[name])
            while not stop_relay.is_set():
                try:
                    coordinator.relay_once()
                except OSError:
                    pass
                stop_relay.wait(0.5)
            coordinator.close()

        relay_thread = threading.Thread(target=relay, daemon=True)
        relay_thread.start()
        worlds = {name: World(name, tmp / name, dmb, daemon, rust_g, int(urls[name].rsplit(':', 1)[1]), tokens[name])
                  for name in REGIONS}
        initial = sum(c['stacks'] * c['stack_size'] for c in
                      (dict(stacks=20, stack_size=10) for _ in REGIONS))
        failures = []
        try:
            for world in worlds.values():
                world.start()
            deadline = time.monotonic() + args.seconds
            while time.monotonic() < deadline:
                time.sleep(rng.uniform(3, 12))
                victim = worlds[rng.choice(sorted(worlds))]
                victim.kill()
                time.sleep(rng.uniform(0, 2))
                victim.start()
            for world in worlds.values():
                (world.dir / 'drain.txt').write_text('1')
                if not world.running():
                    world.start()
            drain_deadline = time.monotonic() + args.drain_seconds
            while not idle(urls, tokens):
                if time.monotonic() > drain_deadline:
                    failures.append('transfers did not drain: ' + json.dumps(
                        {n: call(urls[n], tokens[n], '/status')['result'] for n in urls}))
                    break
                time.sleep(1)
            for world in worlds.values():
                (world.dir / 'stop.txt').write_text('1')
            stop_deadline = time.monotonic() + 60
            while any(w.running() for w in worlds.values()) and time.monotonic() < stop_deadline:
                time.sleep(0.5)
            for world in worlds.values():
                if world.running() or not (world.dir / 'stopped.txt').exists():
                    failures.append('%s did not stop after its final save' % world.name)
                    world.kill()
            totals = {name: w.committed() for name, w in worlds.items() if (w.dir / 'stopped.txt').exists()}
            statuses = {n: call(urls[n], tokens[n], '/status')['result'] for n in urls}
            settled = sum(f['settled_seq'] for s in statuses.values() for f in s['fences'] if f['direction'] == 'out')
            logs = {name: (w.dir / 'world.log').read_text(encoding='utf-8', errors='replace') for name, w in worlds.items()}
            for name, text in logs.items():
                for line in text.splitlines():
                    if 'runtime error' in line or 'FAIL' in line or 'TRACE:' in line:
                        failures.append('%s: %s' % (name, line))
            if len(totals) == len(worlds) and sum(totals.values()) != initial:
                failures.append('wood is not conserved: started with %d, committed saves hold %s' % (initial, totals))
            if any(s['hold_reason'] for s in statuses.values()):
                failures.append('a region is on hold: %s' % {n: s['hold_reason'] for n, s in statuses.items()})
            if settled < args.min_transfers:
                failures.append('only %d transfers settled; expected at least %d' % (settled, args.min_transfers))
            report = {'seed': args.seed, 'seconds': args.seconds, 'kills': {n: w.kills for n, w in worlds.items()},
                      'settled_transfers': settled, 'committed_wood': totals, 'initial_wood': initial,
                      'failures': failures}
            print(json.dumps(report, indent=2))
            if failures and args.keep_logs:
                for name, text in logs.items():
                    print('---- %s world.log (tail) ----\n%s' % (name, '\n'.join(text.splitlines()[-40:])))
        finally:
            for world in worlds.values():
                world.kill()
                world.log.close()
            stop_relay.set()
            relay_thread.join(5)
            for server in servers:
                server.shutdown()
                server.server_close()
            for store in stores.values():
                store.close()
        return 1 if failures else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--byond-bin', required=True, help='directory with DreamMaker and DreamDaemon (pinned 516.1688)')
    parser.add_argument('--rust-g', help='rust_g library (Linux: rust-g 3.0.0 librust_g.so)')
    parser.add_argument('--seconds', type=float, default=120, help='how long to ship goods while killing worlds')
    parser.add_argument('--drain-seconds', type=float, default=180)
    parser.add_argument('--seed', type=int, default=1)
    parser.add_argument('--min-transfers', type=int, default=3)
    parser.add_argument('--workdir', help='an empty directory to run in and keep afterwards')
    parser.add_argument('--keep-logs', action='store_true', help='print the world log tails on failure')
    return run(parser.parse_args(argv))


if __name__ == '__main__':
    sys.exit(main())
