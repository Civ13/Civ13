"""Compile the complete AOTD map with production game types; never run a world."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid
from check_map import ROOT, MAP, validate


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def accepted(log, returncode, version, artifacts_complete):
    return (returncode == 0 and re.findall(r' - (\d+) errors?, (\d+) warnings?', log) == [('0', '0')]
        and bool(re.search(r'^DM compiler version ' + re.escape(version) + r'\s*$', log, re.M))
        and artifacts_complete)


def run(compiler, evidence):
    evidence.mkdir(parents=True, exist_ok=False)
    map_bytes = (ROOT / MAP).read_bytes()
    geometry = validate(map_bytes.decode('utf-8'))
    version = json.loads((ROOT / 'tools/byond/version.json').read_text())['version']
    original = (ROOT / 'civ13.dme').read_bytes()
    pattern = r'(?m)^\s*#include\s+"[^"\r\n]+\.dmm"\s*$'
    if len(re.findall(pattern, original.decode('utf-8'))) != 1:
        raise ValueError('Expected exactly one production map include')
    generated = re.sub(pattern, lambda _: '#include "' + MAP.as_posix() + '"', original.decode('utf-8'))
    dme = ROOT / ('aotd_compile_' + uuid.uuid4().hex + '.dme')
    metadata = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'tracked_source_dirty': subprocess.call(['git', 'diff', '--quiet', 'HEAD'], cwd=ROOT) != 0,
                'scope': 'full-game compilation only; no world, constructors or gameplay started',
                'map': MAP.as_posix(), 'map_sha256': digest(ROOT / MAP), 'geometry': geometry,
                'compiler': str(compiler), 'expected_version': version, 'accepted': False,
                'production_dme_sha256': digest(ROOT / 'civ13.dme')}
    (evidence / 'compile.dme.txt').write_bytes(generated.encode())
    try:
        dme.write_bytes(generated.encode())
        try:
            with (evidence / 'compile.log').open('wb') as output:
                result = subprocess.run([str(compiler), '-max_errors', '0', dme.name], cwd=ROOT,
                                        stdout=output, stderr=subprocess.STDOUT, timeout=180)
            metadata['returncode'] = result.returncode
        except subprocess.TimeoutExpired:
            metadata['returncode'] = None
            metadata['failure'] = 'owned compiler exceeded 180-second deadline'
        except OSError as error:
            metadata['returncode'] = None
            metadata['failure'] = str(error)
        log = (evidence / 'compile.log').read_text(errors='replace')
        summary = re.findall(r' - (\d+) errors?, (\d+) warnings?', log)
        metadata['compiler_summary'] = summary
        metadata['accepted'] = accepted(log, metadata['returncode'], version,
            all(dme.with_suffix(suffix).is_file() and dme.with_suffix(suffix).stat().st_size
                for suffix in ('.dmb', '.rsc')))
        metadata['artifacts'] = {}
        for suffix in ('.dmb', '.rsc', '.int'):
            artifact = dme.with_suffix(suffix)
            if artifact.exists():
                metadata['artifacts'][suffix] = digest(artifact)
                shutil.copyfile(artifact, evidence / ('compiled' + suffix))
        if (ROOT / 'civ13.dme').read_bytes() != original or (ROOT / MAP).read_bytes() != map_bytes:
            metadata['accepted'] = False
            metadata['failure'] = 'tracked compile input changed during compilation'
        (evidence / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
        print(log, end='')
        if not metadata['accepted']:
            raise RuntimeError('AOTD compiler did not return cleanly with the pinned version and complete artifacts; inspect retained diagnostics')
    finally:
        for suffix in ('.dme', '.dmb', '.rsc', '.rsc.lk', '.int'):
            dme.with_suffix(suffix).unlink(missing_ok=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    args = parser.parse_args()
    executable = args.byond_bin.resolve() / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    if not executable.is_file():
        parser.error('Compiler executable not found')
    run(executable, args.evidence_dir.resolve())
