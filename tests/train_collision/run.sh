#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 3 ]; then
  echo 'Usage: run.sh <canonical Linux byond-bin> <pinned.zip> <new evidence directory>' >&2
  exit 2
fi
repo="$(cd "$(dirname "$0")/../.." && pwd)"
byond_bin="$1"
byond_archive="$2"
work="$3"
# Caller-owned evidence survives failures; never reuse or remove an old packet.
test ! -e "$work"
mkdir -p "$work"
awk '/^\/obj\/structure\/trains$/ { active=1 } /^\/obj\/structure\/trains\/storage/ { exit } active { print }' "$repo/code/modules/1713/trains.dm" | sed -E "s@icon = 'icons/obj/vehicles/trains.dmi'@icon = null@; s@'sound/[^']+'@null@g" > "$work/production.dm"
cp "$repo/tests/train_collision/fixture.dm" "$work/fixture.dm"
printf '#include "fixture.dm"\n#include "production.dm"\n' > "$work/probe.dme"
# BEGIN canonical train driver
python3 - "$repo" "$work" "$byond_bin" "$byond_archive" <<'PY'
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys


def load_runtime(root, byond_bin, archive):
    spec = importlib.util.spec_from_file_location('train_current_runtime', root / 'tests/world_save/current_runtime.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    runtime = module.select(byond_bin, archive)
    if runtime is None:
        raise ValueError('Canonical Linux archive identity is required')
    return runtime


def daemon_limits():
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (256 * 1024**2, 256 * 1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (5, 5))


def execute(root, work, byond_bin, archive):
    paths = ('tests/train_collision/run.sh', 'tests/train_collision/fixture.dm',
             'code/modules/1713/trains.dm', 'tests/world_save/current_runtime.py',
             'scripts/byond_runtime.py', 'scripts/byond_toolchain.py',
             'tools/byond/version.json', 'tests/new_z_budget/z_budget_evidence.py')
    metadata = {'status': 'running', 'scope': 'Isolated canonical-pin train fixture',
                'inputs_sha256': {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths},
                'generated_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                     for p in work.iterdir() if p.suffix in ('.dm', '.dme')}}
    try:
        runtime = load_runtime(root, byond_bin, archive)
        runtime.before_launch('compiler', work)
        try:
            built = subprocess.run([str(byond_bin / 'DreamMaker'), '-max_errors', '0', str(work / 'probe.dme')],
                                   cwd=work, capture_output=True, text=True, timeout=60)
        except subprocess.TimeoutExpired as error:
            def decoded(value):
                return value.decode(errors='replace') if isinstance(value, bytes) else (value or '')
            output = decoded(error.stdout) + decoded(error.stderr)
            (work / 'compile.log').write_text(output, encoding='utf-8')
            raise
        (work / 'compile.log').write_text(built.stdout + built.stderr, encoding='utf-8')
        runtime.validate_compile(built.returncode, built.stdout + built.stderr, 'probe.dmb')
        runtime.before_launch('daemon', work)
        with (work / 'daemon.log').open('w', encoding='utf-8') as output:
            result = subprocess.run([str(byond_bin / 'DreamDaemon'), 'probe.dmb', '-invisible', '-trusted', '-log', 'runtime.log'],
                                    cwd=work, stdout=output, stderr=subprocess.STDOUT,
                                    timeout=15, preexec_fn=daemon_limits)
        log = '\n'.join(p.read_text(errors='replace') for p in (work / 'daemon.log', work / 'runtime.log') if p.exists())
        if result.returncode or 'RESULT failures=0' not in log or 'runtime error:' in log.lower() or 'FAIL ' in log:
            raise RuntimeError('Train fixture did not complete its clean assertion sequence')
        metadata['status'] = 'passed'
        print(log)
        return 0
    except BaseException as error:
        metadata.update(status='failed', error=str(error)[:4096])
        raise
    finally:
        try:
            (work / 'fixture-status.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
        except OSError:
            if metadata['status'] != 'failed':
                raise  # Missing successful evidence must still fail the run.


if __name__ == '__main__':
    raise SystemExit(execute(*(Path(p).absolute() for p in sys.argv[1:])))
PY
# END canonical train driver
