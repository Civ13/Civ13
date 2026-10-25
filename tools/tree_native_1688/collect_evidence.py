"""Retain bounded fixed receipts and generated diagnostics, never binaries or saves."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from prepare import bounded_file, INPUTS
from plan import PHASES

MAX_FILE = 8 * 1024**2
MAX_TOTAL = 64 * 1024**2
MAX_FILES = 512
MAX_PATH = 512
TOP = ('result.json', 'prepared/preparation.json', 'prepared/phase-plan.json',
       'prepared/candidate-manifest.json', 'prepared/source-identity.json',
       'runs/result.json', 'runs/controller-binding.json', 'runs/runtime-binding.json', 'runs/phase-results.json')
PHASE_FILES = ('start.json', 'started.json', 'process.json', 'process.log', 'runtime.log',
               'input-hashes.json', 'compiled.json', 'tree-native-ready.json', 'tree-native-go.txt',
               'tree-native-result.json', 'listener-census.json', 'restart-receipt.json', 'restart-copy.json', 'retired-inputs.json')
SOURCES = ('tree1688-world.dm', 'tree1688-globals.dm', 'tree1688-probe.dm',
           'tree1688-control.dm', 'tree1688.dme')
TOOLING = ('run.py', 'prepare.py', 'plan.py', 'receipts.py', 'oracle.py', 'backend_proposal.py',
           'owned_process_1688.py', 'audit_offline.py', 'collect_evidence.py', 'expected-assertions.json',
           'test_backend.py', 'test_proposal.py', 'test_workflow.py', 'admission.py', 'test_admission.py',
           'README.md', 'source-manifest.json', 'test_retirement.py', 'test_orchestration.py')
ACQUISITION = ('source-identity.txt', 'controller-identity.txt', 'controller-paths.txt',
               'download.json', 'archive.sha256', 'tree-source-tests.log', 'atlas-source-freshness.log')


def collect(evidence, acquisition, tooling, output):
    output = output.absolute()
    if '..' in output.parts or output.exists() or any(p.is_symlink() for p in (output, *output.parents)):
        raise ValueError('Fresh unlinked retained output required')
    output.mkdir(parents=True)
    candidates = [(evidence / name, 'receipts/' + name) for name in TOP]
    candidates += [(acquisition / name, 'acquisition/' + name) for name in ACQUISITION]
    candidates += [(tooling / name, 'tooling/' + name) for name in TOOLING]
    for phase, role, variant, mode in PHASES:
        work = evidence / 'runs' / phase
        candidates += [(work / name, 'runs/' + phase + '/' + name) for name in PHASE_FILES]
        if role == 'compiler':
            candidates += [(work / name, 'runs/' + phase + '/' + name) for name in SOURCES]
    for variant in ('baseline', 'clock', 'duration', 'payment'):
        candidates += [(evidence / 'prepared/generated' / variant / name,
                        'generated/' + variant + '/' + name) for name in SOURCES]
    candidates += [(evidence / 'prepared/inputs' / name, 'inputs/' + name) for name in INPUTS]
    kept, missing, rejected = [], [], []
    # Fixed receipts get priority; optional daemon logs cannot crowd them out.
    for phase, role, variant, mode in PHASES:
        if role != 'daemon':
            continue
        root = evidence / 'runs' / phase
        if root.is_symlink() or any(p.is_symlink() for p in root.parents):
            rejected.append({'path': 'runs/' + phase, 'reason': 'Linked runtime directory'})
            continue
        visited = 0
        for folder, dirs, files in os.walk(root, followlinks=False):
            dirs[:] = sorted(d for d in dirs if not (Path(folder) == root and d == 'home'))
            linked = [d for d in dirs if (Path(folder) / d).is_symlink()]
            if linked:
                rejected.append({'path': 'runs/' + phase, 'reason': 'Linked diagnostic directory'})
                dirs[:] = [d for d in dirs if d not in linked]
            visited += len(dirs) + len(files)
            if visited > 4096:
                rejected.append({'path': 'runs/' + phase, 'reason': 'Diagnostic inventory bound exceeded'})
                break
            for name in sorted(files):
                if not name.endswith('.log') or (Path(folder) == root and name in PHASE_FILES):
                    continue
                path = Path(folder) / name
                relative = 'runs/' + phase + '/' + path.relative_to(root).as_posix()
                if len(candidates) >= MAX_FILES:
                    rejected.append({'path': 'runs/' + phase, 'reason': 'Diagnostic candidate bound exceeded'})
                    break
                candidates.append((path, relative))
            if len(candidates) >= MAX_FILES:
                break
    total = 0
    for source, relative in candidates:
        if not source.exists() and not source.is_symlink():
            missing.append(relative)
            continue
        try:
            if len(relative.encode()) > MAX_PATH:
                raise ValueError('Retained path exceeds bound')
            data = bounded_file(source, MAX_FILE)
            size = len(data)
            if total + size > MAX_TOTAL - 1024**2 or len(kept) >= MAX_FILES:
                raise ValueError('Retained evidence exceeds aggregate bound')
            target = output / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as stream:
                stream.write(data)
            total += size
            kept.append({'path': relative, 'bytes': size, 'sha256': hashlib.sha256(data).hexdigest()})
        except (OSError, ValueError) as error:
            rejected.append({'path': relative[:MAX_PATH], 'reason': str(error)[:200]})
    report = {'status': 'bounded-evidence-staged' if not rejected else 'partial-evidence-rejected',
              'bytes': total, 'files': kept, 'missing': missing, 'rejected': rejected,
              'native_execution_performed_by_collector': False,
              'limits': {'file': MAX_FILE, 'total': MAX_TOTAL, 'files': MAX_FILES, 'path': MAX_PATH}}
    (output / 'retention.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('evidence', 'acquisition', 'tooling', 'output'):
        parser.add_argument('--' + name, required=True, type=Path)
    args = parser.parse_args()
    if collect(args.evidence, args.acquisition, args.tooling, args.output)['rejected']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
