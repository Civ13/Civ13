"""Compile the inactive Dagger DMM with real game types; never start a world."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
MAP = Path('maps/WIP/dagger_train_home.dmm')
MISSING_TYPE = '/turf/dagger_compile_missing_type_control'
MAP_INCLUDE = re.compile(r'^\s*#include\s+"[^"\n]+\.dmm"\s*$', re.MULTILINE)


def fixture_dme(source, map_path):
    """Keep production declarations intact, replacing exactly one active map."""
    if len(MAP_INCLUDE.findall(source)) != 1:
        raise ValueError('Expected exactly one production DMM include')
    return MAP_INCLUDE.sub(lambda _: '#include "' + map_path.as_posix() + '"', source)


def missing_type_control(source):
    mutated, count = re.subn(r'/turf/[\w/]+', MISSING_TYPE, source, count=1)
    if count != 1 or MISSING_TYPE in source:
        raise ValueError('Cannot inject unique missing-type control')
    return mutated


def accepted(log, returncode, control=False):
    if not re.search(r'\b516\.1681\b', log):
        return False
    summaries = re.findall(r' - (\d+) errors?, (\d+) warnings?', log)
    if len(summaries) != 1:
        return False
    errors, warnings = map(int, summaries[0])
    if control:
        # BYOND emits both the named undefined type and a companion unknown-type
        # diagnostic for the same DMM cell. Require that exact pair, so unrelated
        # failures cannot make the mutation appear to pass.
        diagnostics = [line.strip() for line in log.splitlines()
                       if re.search(r'\b(?:error|warning):', line, re.I)]
        if errors != 2 or warnings != 0 or len(diagnostics) != 2:
            return False
        named = re.fullmatch(r'(.*/?missing-type\.dmm:\d+):error: undefined type: '
                             + re.escape(MISSING_TYPE), diagnostics[0])
        return bool(named and diagnostics[1] == named[1] + ':error: unknown type')
    return returncode == 0 and errors == 0 and warnings == 0


def run(root, compiler, evidence):
    evidence.mkdir(parents=True, exist_ok=False)
    source = (root / 'civ13.dme').read_text(encoding='utf-8')
    map_bytes = (root / MAP).read_bytes()
    metadata = {
        'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True),
        'map': MAP.as_posix(),
        'map_sha256': hashlib.sha256(map_bytes).hexdigest(),
        'production_dme_sha256': hashlib.sha256(source.encode()).hexdigest(),
        'scope': 'Native compile only; no constructors, world startup or gameplay executed',
        'results': {},
    }
    (evidence / 'metadata.json').write_text(json.dumps(metadata, indent=2))
    # Root-local DME preserves every relative include/resource path. A unique
    # prefix and finally block avoid overwriting production or parallel outputs.
    with tempfile.TemporaryDirectory(prefix='.dagger-native-', dir=root) as work:
        work = Path(work)
        for name, control in [('positive', False), ('missing-type', True)]:
            dme = root / (work.name + '-' + name + '.dme')
            map_path = MAP
            if control:
                mutated = work / 'missing-type.dmm'
                mutated.write_text(missing_type_control(map_bytes.decode('utf-8')), encoding='utf-8')
                map_path = mutated.relative_to(root)
            generated = fixture_dme(source, map_path)
            (evidence / (name + '.dme.txt')).write_text(generated, encoding='utf-8')
            try:
                dme.write_text(generated, encoding='utf-8')
                build = subprocess.run([str(compiler), '-max_errors', '0', dme.name], cwd=root,
                                       capture_output=True, text=True, timeout=600)
                log = build.stdout + build.stderr
                (evidence / (name + '.log')).write_text(log, encoding='utf-8')
                passed = accepted(log, build.returncode, control)
                # A zero-error banner without a produced executable is not proof.
                if not control:
                    passed = passed and dme.with_suffix('.dmb').is_file()
                metadata['results'][name] = {'accepted': passed, 'returncode': build.returncode}
                (evidence / 'metadata.json').write_text(json.dumps(metadata, indent=2))
                print(log, flush=True)
                if not passed:
                    raise RuntimeError(f'{name} compilation did not meet its expected contract')
            finally:
                for suffix in ('.dme', '.dmb', '.rsc', '.int'):
                    dme.with_suffix(suffix).unlink(missing_ok=True)
    print('PASS native Dagger map compilation and missing-type control; gameplay UNRUN')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    args = parser.parse_args()
    compiler = args.byond_bin.resolve() / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    if not compiler.is_file():
        parser.error('BYOND compiler not found')
    run(ROOT, compiler, args.evidence_dir.resolve())


if __name__ == '__main__':
    main()
