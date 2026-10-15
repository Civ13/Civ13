"""Compile production persistent round guards in a small offline world, with temporary storage."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=['vote', 'ticker', 'deferred'])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    prefix = '.persistence_round_ci'
    generated = [root / (prefix + suffix) for suffix in ('.dme', '_world.dm', '.dmb', '.rsc', '_vote.dm', '_ticker.dm')]
    if any(path.exists() for path in generated):
        raise RuntimeError('Preserve existing probe files')
    storage = root / 'data' / 'persistence-round-tests'
    storage.mkdir(parents=True, exist_ok=True)
    logs = Path(tempfile.mkdtemp(prefix='run-', dir=storage))
    print(f'Evidence: {logs}', flush=True)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_harvest_startup()', 1)
        generated[1].write_text(world, encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', prefix + '_world.dm')
        ticker_source = (root / 'code/game/gameticker.dm').read_text(encoding='utf-8')
        # Only external hook/reboot effects are adapted; real timing and guards run.
        assert ticker_source.count('callHook("roundend")') == 1
        assert ticker_source.count('world.Reboot()') == 1
        ticker_source = ticker_source.replace('callHook("roundend")', 'persistence_test_roundend()').replace('world.Reboot()', 'persistence_test_reboot()')
        if args.negative_control in ('ticker', 'deferred'):
            old = 'if (persistence_round_active() && current_state >= GAME_STATE_PLAYING)' if args.negative_control == 'ticker' else 'if (persistence_round_active())'
            expected_count = 1 if args.negative_control == 'ticker' else 2
            assert ticker_source.count(old) == expected_count, 'Mutation anchor drift'
            ticker_source = ticker_source.replace(old, 'if (FALSE)')
        generated[5].write_text(ticker_source, encoding='utf-8')
        source = source.replace('code\\game\\gameticker.dm', generated[5].name)
        if args.negative_control == 'vote':
            body = (root / 'code/datums/vote.dm').read_text(encoding='utf-8')
            old = 'if (persistence_blocks_vote(vote_type))'
            assert body.count(old) == 1, 'Mutation anchor drift'
            generated[4].write_text(body.replace(old, 'if (FALSE)', 1), encoding='utf-8')
            source = source.replace('code\\datums\\vote.dm', generated[4].name)
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "tests/persistence_round/probe.dm"\n', encoding='utf-8')
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        print(f'Commit: {commit}', flush=True)
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])],
                               cwd=root, capture_output=True, text=True, timeout=120,
                               creationflags=flags)
        output = build.stdout + build.stderr
        (logs / 'compile.log').write_text(output, encoding='utf-8')
        print(output, flush=True)
        if build.returncode or '0 errors, 0 warnings' not in output or '516.1681' not in output:
            raise RuntimeError('Pinned compilation failed')
        shutil.copy2(generated[2], logs / generated[2].name)
        shutil.copy2(generated[3], logs / generated[3].name)
        shutil.copytree(root / 'config/names', logs / 'config/names')
        (logs / 'config/config.txt').write_text('# Offline fixture\n', encoding='utf-8')
        runtime = subprocess.run([str(daemon), str(logs / generated[2].name),
                                  *(['-invisible', '-close'] if os.name == 'nt' else []),
                                  '-safe', '-params', f'tested_commit={commit}', '-log', 'runtime.log'],
                                 cwd=logs, capture_output=True, text=True, timeout=60,
                                 creationflags=flags)
        (logs / 'daemon.log').write_text(runtime.stdout + runtime.stderr, encoding='utf-8')
        result = (logs / 'result.txt').read_text(encoding='utf-8').strip()
        print(result, flush=True)
        log = (logs / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        errors = logs / 'errors.txt'
        diagnostic = re.search(r'runtime error:|BUG:|Bad ref|Unhandled exception', log + runtime.stdout + runtime.stderr, re.I) or (errors.exists() and errors.stat().st_size)
        if args.negative_control:
            expected = {'vote': 'vote creation blocked', 'ticker': 'finished flag cleared', 'deferred': 'deferred round end cancelled'}[args.negative_control]
            if runtime.returncode or diagnostic or not result.startswith('FAIL:') or expected not in result:
                raise RuntimeError('Negative control did not fail at its intended assertion')
            print('PASS: intended negative control detected', flush=True)
        elif runtime.returncode or not result.startswith('PASS:') or diagnostic:
            print(log, flush=True)
            raise RuntimeError('Persistence fixture failed')
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
