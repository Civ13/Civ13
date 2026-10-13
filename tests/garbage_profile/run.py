"""Production GC profiling and unchanged collector budgets in offline native storage."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--negative-control', choices=('bound', 'cleanup', 'forced', 'clock'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = args.output or Path(tempfile.mkdtemp(prefix='civ13-gc-profile-'))
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise RuntimeError('Use fresh evidence storage')
    source = (root/'tests/memory_ownership/probe.dm').read_text().split('/world/New()')[0]
    source = source.replace('../../code/', root.as_posix()+'/code/')
    source += '\n' + (root/'tests/memory_ownership/collector.dm').read_text()
    source += '\n' + (root/'tests/garbage_profile/probe.dm').read_text()
    garbage = (root/'code/processes/garbage.dm').read_text()
    helper = (root/'code/processes/garbage_profile.dm').read_text()
    expected = None
    if args.negative_control:
        controls = {
            'bound': ('code/processes/garbage_profile.dm', '#define GC_PROFILE_TYPE_LIMIT 128', '#define GC_PROFILE_TYPE_LIMIT 10000', 'type rows stay bounded including overflow'),
            'cleanup': ('code/processes/garbage.dm', 'profile_cost(profile_type, FALSE, cleanup_started, cleanup_tick)', 'profile_discard(profile_type, FALSE, cleanup_started, cleanup_tick)', 'cleanup hook counts once across recursive and repeated qdel'),
            'forced': ('code/processes/garbage.dm', 'profile_cost(forced_type, TRUE, forced_started, forced_tick)', 'profile_discard(forced_type, TRUE, forced_started, forced_tick)', 'collector times actual forced deletion'),
            'clock': ('code/processes/garbage_profile.dm', 'elapsed += 864000', 'elapsed += 0', 'elapsed samples handle one midnight wrap'),
        }
        relative, before, after, expected = controls[args.negative_control]
        body = (root/relative).read_text()
        if before not in body:
            raise RuntimeError('Missing control anchor')
        if relative.endswith('garbage_profile.dm'):
            helper = body.replace(before, after, 1)
        else:
            garbage = body.replace(before, after, 1)
            # Preserve argument reads so missing-hook controls remain warning-free.
            helper += '\n/process/garbage/proc/profile_discard(type_name, forced, started, start_tick)\n\treturn list(type_name, forced, started, start_tick)\n'
    # Inject only the sampled clock in generated source. Ordinary lifecycle
    # checks retain the native clock; boundary arithmetic uses valid fixed times.
    clock_anchor = 'var/elapsed = world.timeofday - started'
    if helper.count(clock_anchor) != 1:
        raise RuntimeError('Missing unique profiling clock anchor')
    helper = helper.replace(clock_anchor, 'var/elapsed = profile_fixture_timeofday() - started', 1)
    helper += '\nvar/profile_fixture_clock = null\n/proc/profile_fixture_timeofday()\n\treturn isnull(profile_fixture_clock) ? world.timeofday : profile_fixture_clock\n'
    (out/'garbage_profile.dm').write_text(helper)
    garbage = re.sub(r'#include "([^"/\\]+\.dm)"',
                     lambda m: '#include "' + (root/'code/processes').joinpath(m[1]).as_posix() + '"' if m[1] != 'garbage_profile.dm' else m[0],
                     garbage)
    (out/'garbage.dm').write_text(garbage)
    source = source.replace((root/'code/processes/garbage.dm').as_posix(), (out/'garbage.dm').as_posix())
    (out/'probe.dme').write_text(source)
    (out/'metadata.json').write_text(json.dumps({
        'head_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True, timeout=30).strip(),
        'scope': 'isolated production cleanup/collector, no game startup',
        'negative_control': args.negative_control,
        'source_sha256': {name: hashlib.sha256((out/name).read_bytes()).hexdigest()
                          for name in ('probe.dme', 'garbage.dm', 'garbage_profile.dm')},
    }))
    (out/'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=root, timeout=30))
    win = os.name == 'nt'
    flags = subprocess.CREATE_NO_WINDOW if win else 0
    build = subprocess.run([str(args.byond_bin/('dm.exe' if win else 'DreamMaker')), '-max_errors', '0', 'probe.dme'], cwd=out, capture_output=True, text=True, timeout=60, creationflags=flags)
    log = build.stdout + build.stderr
    (out/'compile.log').write_text(log)
    print(log)
    if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log:
        raise RuntimeError('Pinned clean compile failed')
    cmd = [str(args.byond_bin/('dd.exe' if win else 'DreamDaemon')), 'probe.dmb', '-safe', '-log', 'runtime.log']
    if win:
        cmd += ['-invisible', '-close']
    with (out/'daemon.log').open('w') as stream:
        subprocess.run(cmd, cwd=out, stdout=stream, stderr=subprocess.STDOUT, timeout=60, creationflags=flags, check=True)
    result = (out/'result.txt').read_text()
    print(result.strip())
    if (out/'benchmark.txt').exists():
        print((out/'benchmark.txt').read_text().strip())
    runtime = (out/'runtime.log').read_text(errors='replace') + (out/'daemon.log').read_text(errors='replace')
    if any(marker in runtime.lower() for marker in ('runtime error', 'bad ref', 'infinite loop', 'error:')):
        raise RuntimeError('Runtime/engine diagnostics invalidate evidence')
    if expected:
        if result.strip() != 'FAIL: '+expected:
            raise RuntimeError('Negative control missed intended assertion')
        print('PASS: intentional defect detected')
    elif not result.startswith('PASS:'):
        raise RuntimeError(result)


if __name__ == '__main__':
    main()
