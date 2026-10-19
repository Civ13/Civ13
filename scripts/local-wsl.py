"""PC-only game runtimes, invoked through local-wsl.ps1. No production scripts."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

BIN = Path('/opt/civ13-byond-516.1681/byond/bin')
PORTS = {'nomads': 1715, 'tdm': 1714}


def config(server, root):
    mode = 'PERSISTENCE' if server == 'nomads' else 'TDM'
    return (f'SERVER_NAME Local Civ13 {server}\nMASTER_DIRECTORY {root}\n'
            f'ALLOWED_GAMEMODES {mode}\nHUB NO\nTTS_ON 0\nSCRIPTS_DIRECTORY null\n'
            'LOG_ACCESS\nLOG_GAME\nLOG_VOTE\nLOG_ADMIN\nLOBBY_COUNTDOWN 90\n')


def process_matches(record, runtime):
    try:
        pid = int(record['pid'])
        fields = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
        args = Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
        return (fields[19] == record['started'] and
                str(runtime / 'civ13.dmb').encode() in args and
                args[0] == str(BIN / 'DreamDaemon').encode())
    except (OSError, ValueError, KeyError, IndexError):
        return False


def build(source, runtime, env):
    source = source.resolve(strict=True)
    sha = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    tracked = subprocess.check_output(['git', '-C', str(source), 'status', '--porcelain', '--untracked-files=no'], text=True)
    if tracked.strip():
        raise RuntimeError('Commit tracked changes before building an immutable local runtime')
    with tempfile.TemporaryDirectory(prefix='civ13-build-') as directory:
        stage = Path(directory)
        # The catalog generator requires HEAD and the tracked-file index. Fetch
        # only this local commit into an independent temporary repository;
        # source branches, index, worktrees and private untracked files stay put.
        subprocess.run(['git', 'init', '--quiet', str(stage)], env=env, check=True)
        subprocess.run(['git', '-C', str(stage), 'fetch', '--quiet', '--no-tags',
                        '--no-recurse-submodules', '--depth=1', str(source), sha], env=env, check=True)
        subprocess.run(['git', '-C', str(stage), '-c', 'core.hooksPath=' + str(stage / '.git/no-hooks'),
                        'checkout', '--quiet', '--detach', sha], env=env, check=True)
        subprocess.run(['python3', 'scripts/build-crafting-atlas.py', '--catalog-only', '--game-catalog', 'UI/crafting-atlas.json'], cwd=stage, check=True, env=env)
        result = subprocess.run([str(BIN / 'DreamMaker'), '-max_errors', '0', 'civ13.dme'], cwd=stage, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        print(result.stdout)
        if result.returncode or '0 errors, 0 warnings' not in result.stdout:
            raise RuntimeError('Build must report zero errors and warnings')
        import shutil
        for name in ('civ13.dmb', 'civ13.rsc'):
            shutil.copyfile(stage / name, runtime / name)
        for name in ('maps', 'UI', 'config'):
            # Only tracked public config is copied; private runtime SQL/data are untouched.
            if name == 'config':
                for filename in ('dictionary.txt', 'recipes_info.txt', 'tips.txt', 'admin_ranks.txt', 'motd.txt'):
                    if (stage / name / filename).is_file():
                        shutil.copyfile(stage / name / filename, runtime / name / filename)
                for directory in ('crafting', 'names'):
                    if (stage / name / directory).is_dir():
                        shutil.copytree(stage / name / directory, runtime / name / directory, dirs_exist_ok=True)
            else:
                shutil.copytree(stage / name, runtime / name, dirs_exist_ok=True)
        (runtime / 'source-sha.txt').write_text(sha + '\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['build', 'start', 'stop', 'status'])
    parser.add_argument('--server', choices=PORTS, required=True)
    parser.add_argument('--source', type=Path, required=True)
    args = parser.parse_args()
    runtime = Path.home() / '.local/share/civ13-local' / args.server
    runtime.mkdir(parents=True, exist_ok=True)
    for name in ('config', 'SQL', 'data', 'logs'):
        (runtime / name).mkdir(exist_ok=True)
    with (runtime / 'control.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = runtime / 'process.json'
        record = json.loads(state.read_text()) if state.exists() else {}
        alive = process_matches(record, runtime)
        env = os.environ.copy()
        env['LD_LIBRARY_PATH'] = str(BIN) + (':' + env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
        if args.action == 'status':
            print(json.dumps({'server': args.server, 'running': alive, 'port': PORTS[args.server], 'runtime': str(runtime)}))
        elif args.action == 'stop':
            if alive:
                os.kill(record['pid'], signal.SIGTERM)
                for _ in range(100):
                    if not process_matches(record, runtime):
                        break
                    time.sleep(.1)
                else:
                    raise RuntimeError('Still stopping; no forced kill or automatic restart')
            state.unlink(missing_ok=True)
        elif args.action == 'build':
            if alive:
                raise RuntimeError('Stop this local server before replacing its binaries')
            build(args.source, runtime, env)
            (runtime / 'config/config.txt').write_text(config(args.server, runtime))
        elif args.action == 'start':
            if alive:
                print('Already running')
                return
            if not (runtime / 'source-sha.txt').exists():
                raise RuntimeError('Run Build first')
            with (runtime / 'logs/daemon.log').open('ab') as log:
                process = subprocess.Popen([str(BIN / 'DreamDaemon'), str(runtime / 'civ13.dmb'), str(PORTS[args.server]), '-trusted', '-log', 'logs/world.log'], cwd=runtime, env=env, stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)
                try:
                    fields = Path(f'/proc/{process.pid}/stat').read_text().rsplit(')', 1)[1].split()
                    state.write_text(json.dumps({'pid': process.pid, 'started': fields[19]}))
                    time.sleep(2)
                    if process.poll() is not None:
                        raise RuntimeError('Daemon exited; inspect local logs')
                except BaseException:
                    try:
                        if process.poll() is None:
                            process.terminate()
                        process.wait(timeout=10)
                    except (OSError, subprocess.TimeoutExpired) as cleanup:
                        raise RuntimeError(f'Failed launch: owned daemon {process.pid} exit unconfirmed; retain any process.json and inspect local logs') from cleanup
                    state.unlink(missing_ok=True)
                    raise
            print('Daemon launched; client admission and runtime diagnostics still require verification')


if __name__ == '__main__':
    main()
