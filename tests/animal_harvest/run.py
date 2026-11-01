"""Compile production harvesting in a small offline world, with temporary storage."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'scripts'))
from native_fixture import Session, no_port_args, read_bounded, run_native
import byond_runtime
import byond_toolchain

_retention_spec = importlib.util.spec_from_file_location('harvest_retained_evidence', ROOT/'tests/flax_processing/run.py')
evidence = importlib.util.module_from_spec(_retention_spec)
_retention_spec.loader.exec_module(evidence)


def prepare_world_source(world):
    """Defer the same production global bootstrap until fixture world entry.

    Global constructors precede world/New; replacing world/New alone does not
    isolate them. Keep the initializer body intact, rather than suppressing its
    failures or reproducing its catalog/config/chemistry effects in test code.
    """
    startup = '/world/New()\n'
    initializer = '/datum/global_init/New()\n'
    if world.count(startup) != 1 or world.count(initializer) != 1:
        raise RuntimeError('Harvest startup isolation markers changed')
    start = world.index(startup)
    next_proc = re.search(r'\n/[^/]', world[start+len(startup):])
    end = start+len(startup)+next_proc.start() if next_proc else len(world)
    body = world[start:end]
    if body.count('\n\t..()') != 1:
        raise RuntimeError('Harvest world startup parent marker changed')
    world = world[:start]+body.replace('\n\t..()', '', 1)+world[end:]
    world = world.replace(startup, '/world/proc/unused_harvest_startup()\n', 1)
    return world.replace(initializer, '/datum/global_init/proc/initialize_harvest_globals()\n', 1)
OFFLINE_CONFIG = b'# Offline fixture\n'
RUNTIME_INPUT_FILES = 147
# Pinned names: 134930 LF bytes + at most 18317 CRLF expansion bytes; config: 18.
RUNTIME_INPUT_BYTE_LIMIT = 153265


def required_name_plan():
    # Validate only the eager name dependency, not flax's separate loose recipe.
    plan = json.loads(evidence.bounded_text(ROOT/'tests/flax_processing/required-inputs.json', evidence.INPUT_LIMIT))
    names = (ROOT/'code/names.dm').read_bytes().replace(b'\r\n', b'\n')
    declarations = re.findall(rb'^var/list/\w+\s*=\s*file2list\s*\(\s*"(config/names/[^"\n]+)"\s*\)\s*(?://[^\n]*)?$', names, re.M)
    paths = {path.decode() for path in declarations}
    if (plan['schema_version'] != 1 or plan['names_source'] != 'code/names.dm'
            or hashlib.sha256(names).hexdigest() != plan['names_source_sha256']
            or len(declarations) != plan['global_name_declarations']
            or len(paths) != plan['required_name_files'] or len(paths) != 146):
        raise RuntimeError('Harvest eager name source changed; review staging')
    records = [row for row in plan['inputs'] if row['path'].startswith('config/names/')]
    if len(records) != len(paths) or {row['path'] for row in records} != paths:
        raise RuntimeError('Harvest name manifest does not match exact eager reads')
    bound = []
    for row in records:
        path = Path(row['path'])
        source = ROOT/path
        if (path.is_absolute() or '..' in path.parts or source.is_symlink() or not source.is_file()
                or not 0 < row['bytes'] <= evidence.INPUT_LIMIT
                or source.stat().st_size > evidence.INPUT_LIMIT):
            raise RuntimeError('Invalid harvest required name input: '+row['path'])
        data = source.read_bytes()
        fingerprint = data.replace(b'\r\n', b'\n')
        if len(fingerprint) != row['bytes'] or hashlib.sha256(fingerprint).hexdigest() != row['sha256']:
            raise RuntimeError('Harvest name fingerprint changed: '+row['path'])
        bound.append(dict(path=row['path'], bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                          fingerprint_sha256=row['sha256']))
    return bound


def input_allowance(required):
    input_bytes = sum(row['bytes'] for row in required.values())
    if len(required) != RUNTIME_INPUT_FILES or input_bytes > RUNTIME_INPUT_BYTE_LIMIT:
        raise RuntimeError('Harvest required-input allowance exceeded')
    return {'required_input_files': len(required), 'required_input_bytes': input_bytes,
            'required_input_byte_limit': RUNTIME_INPUT_BYTE_LIMIT,
            'non_required_file_limit': evidence.FILE_LIMIT,
            'derived_total_files': evidence.FILE_LIMIT+len(required),
            'total_byte_limit': evidence.OUTPUT_LIMIT}


def stage_runtime_inputs(logs, manifest=None):
    # The recipe is a compiled resource in hide_recipe_probe.dm, not a loose input.
    probe = (ROOT/'tests/animal_harvest/hide_recipe_probe.dm').read_text(encoding='utf-8')
    if (not re.search(r"^var/global/tanning_recipe_config = 'config/crafting/material_recipes_global.txt'$", probe, re.M)
            or 'file2list(tanning_recipe_config, "\\n")' not in probe):
        raise RuntimeError('Harvest recipe resource changed; review loose runtime inputs')
    names = required_name_plan()
    config = 'runtime/config/config.txt'
    required = {'runtime/'+row['path']: dict(row) for row in names}
    required[config] = {'path': 'generated minimal config', 'bytes': len(OFFLINE_CONFIG),
                        'sha256': hashlib.sha256(OFFLINE_CONFIG).hexdigest()}
    limits = input_allowance(required)
    if manifest is not None:
        # Persist the bounded plan before copying; partial staging must not fall
        # back to the obsolete 128-all-files final inventory and hide inputs.
        manifest.update(required_inputs=required, limits=limits)
        evidence.write_json(logs/'evidence-manifest.json', manifest)
    evidence.stage_required_inputs(logs, names)
    with (logs/config).open('xb') as stream:
        stream.write(OFFLINE_CONFIG)
    return required


def validate_runtime_inputs(logs, required):
    limits = input_allowance(required)
    count, total = evidence.check_output_budget(logs, required)
    for relative, row in required.items():
        if evidence.bounded_digest(logs/relative, evidence.INPUT_LIMIT) != (row['bytes'], row['sha256']):
            raise RuntimeError('Harvest required input fingerprint changed: '+relative)
    return dict(limits, non_required_present=count, observed_bytes=total)


def run_retained(session, command, *, logs, cwd, phase, timeout, required_inputs=None, **kwargs):
    if sys.platform == 'linux':
        return evidence.run_phase(command, cwd=cwd, output=logs, phase=phase, timeout=timeout,
                                  required_inputs=required_inputs)
    return run_native(session, command, cwd=cwd, phase=phase, timeout=timeout, **kwargs)


def verify_external_cleanup(path, logs, commit, run_id):
    """Validate a separately produced attestation; never manufacture cleanup.

    The admitted observer and its actual OS evidence still need independent
    review. A structurally valid JSON assertion alone is not that review.
    """
    raw = evidence.bounded_text(path, 65536)
    receipt = json.loads(raw)
    phases = [json.loads(evidence.bounded_text(logs/(name+'-phase.json'), 65536))
              for name in ('harvest-compile', 'harvest-runtime')]
    expected_pids = sorted(p['pid'] for p in phases)
    relative = Path(receipt.get('os_evidence_path', ''))
    if relative.is_absolute() or '..' in relative.parts or not relative.parts:
        raise RuntimeError('External harvest OS evidence must name an owned relative file')
    if not (logs/relative).resolve().is_relative_to(logs.resolve()):
        raise RuntimeError('External harvest OS evidence escapes the owned output')
    os_evidence = evidence.bounded_text(logs/relative)
    if (receipt.get('head_sha') != commit or receipt.get('run_id') != run_id
            or receipt.get('evidence_directory') != str(logs.resolve())
            or receipt.get('phase_pids') != expected_pids
            or receipt.get('descendants_exited') is not True
            or receipt.get('sockets_closed') is not True
            or not receipt.get('external_verifier') or receipt.get('external_verifier') == 'runner'
            or receipt.get('os_evidence_sha256') != hashlib.sha256(os_evidence.encode()).hexdigest()
            or not all(p.get('direct_child_exited') and p.get('stream_writers_closed')
                       and p.get('retention_complete') is True and p.get('returncode') == 0 for p in phases)):
        raise RuntimeError('External harvest cleanup receipt does not bind this completed run')
    return {'path': str(path), 'sha256': hashlib.sha256(raw.encode()).hexdigest(),
            'attestation': receipt, 'requires_independent_os_evidence_review': True}


def runtime_identity(binary, archive):
    if sys.platform == 'linux':
        if archive is None:
            raise ValueError('--byond-archive is required for Linux harvest identity')
        return byond_runtime.verify_linux(binary, archive)
    return None  # Windows containment stays with the existing Session.


def check_compile(build, expected):
    if build.returncode:
        raise RuntimeError('Harvest fixture compiler exited nonzero')
    byond_toolchain.compiler_log(build.stdout + build.stderr, expected)


def main(argv=None, session=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--evidence-dir', type=Path)
    parser.add_argument('--byond-archive', type=Path)
    parser.add_argument('--acceptance-scope', choices=('limited', 'full'), default='limited',
                        help='Limited preserves existing fixture checks; full Linux scope additionally requires external cleanup evidence')
    parser.add_argument('--external-cleanup-receipt', type=Path)
    parser.add_argument('--cleanup-receipt-wait', type=float, default=5)
    args = parser.parse_args(argv)
    if sys.platform == 'linux' and args.byond_archive is None:
        parser.error('--byond-archive is required for Linux harvest identity')
    if not 0 <= args.cleanup_receipt_wait <= 5:
        parser.error('Cleanup receipt wait must be between zero and five seconds')
    if args.acceptance_scope == 'full':
        if sys.platform != 'linux':
            parser.error('The external-cleanup full scope is prepared only for Linux')
        if args.external_cleanup_receipt is None:
            parser.error('Full scope requires --external-cleanup-receipt from the admitted external observer')
    elif args.external_cleanup_receipt is not None:
        parser.error('--external-cleanup-receipt requires explicit --acceptance-scope full')
    root = ROOT
    requirement = byond_toolchain.load()
    binary = args.byond_bin.absolute()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    prefix = '.animal_harvest_ci_' + uuid.uuid4().hex
    generated = [root / (prefix + suffix) for suffix in ('.dme', '_world.dm', '.dmb', '.rsc')]
    if any(path.exists() for path in generated):
        raise RuntimeError('Preserve existing probe files')
    storage = root / 'data' / 'animal-harvest-tests'
    storage.mkdir(parents=True, exist_ok=True)
    logs = args.evidence_dir.resolve() if args.evidence_dir else Path(tempfile.mkdtemp(prefix='run-', dir=storage))
    if args.evidence_dir:
        logs.mkdir(parents=True, exist_ok=False)
    print(f'Evidence: {logs}', flush=True)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True, timeout=10).strip()
    if sys.platform != 'linux' and os.name == 'nt' and session is None:
        session = Session(logs/'supervisor', commit)
    manifest = {'schema_version': 1, 'head_sha': commit, 'run_id': prefix,
                'status': 'preparing', 'automatic_deletion': False,
                'acceptance_scope': args.acceptance_scope, 'full_acceptance_complete': False,
                'external_cleanup_required': args.acceptance_scope == 'full',
                'external_descendant_cleanup': 'pending_external_verification',
                'expected_diagnostics': ['harvest-compile.stdout.log', 'harvest-compile.stderr.log',
                                         'harvest-compile-phase.json', 'harvest-runtime.stdout.log',
                                         'harvest-runtime.stderr.log', 'harvest-runtime-phase.json',
                                         'runtime/runtime.log', 'runtime/errors.txt',
                                         'runtime/result.txt', 'runtime/port-closed.txt']}
    manifest['retention_source_sha256'] = hashlib.sha256((root/'tests/flax_processing/run.py').read_bytes()).hexdigest()
    evidence.write_json(logs/'evidence-manifest.json', manifest)
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        generated[1].write_text(prepare_world_source(world), encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', prefix + '_world.dm')
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "tests/animal_harvest/probe.dm"\n', encoding='utf-8')
        snapshots = logs/'generated-inputs'
        snapshots.mkdir()
        for path in generated[:2]:
            if path.stat().st_size > evidence.INPUT_LIMIT:
                raise RuntimeError('Harvest generated input exceeds retention bound')
            shutil.copy2(path, snapshots/path.name)
        required = stage_runtime_inputs(logs, manifest)
        manifest['limits'] = validate_runtime_inputs(logs, required)
        evidence.retain_manifest(logs, generated, manifest)
        print(f'Commit: {commit}', flush=True)
        identity = runtime_identity(binary, args.byond_archive)
        (logs / 'compiler-runtime.json').write_text(json.dumps(identity, indent=2), encoding='utf-8')
        build = run_retained(session, [str(compiler), '-max_errors', '0', str(generated[0])], logs=logs,
                             cwd=root, phase='harvest-compile', timeout=120, artifacts=generated[2:],
                             required_inputs=required)
        output = build.stdout + build.stderr
        evidence.write_log(logs/'compile.log', output)
        print(output, flush=True)
        check_compile(build, requirement['version'])
        if any(path.stat().st_size > evidence.ARTIFACT_LIMIT for path in generated[2:]):
            raise RuntimeError('Harvest compiled artifact exceeds retention bound')
        work = logs/'runtime'
        shutil.copy2(generated[2], work/generated[2].name)
        shutil.copy2(generated[3], work/generated[3].name)
        manifest['staging_before_runtime'] = validate_runtime_inputs(logs, required)
        evidence.retain_manifest(logs, generated, manifest)
        identity = runtime_identity(binary, args.byond_archive)
        (logs / 'daemon-runtime.json').write_text(json.dumps(identity, indent=2), encoding='utf-8')
        runtime = run_retained(session, [str(daemon), str(work / generated[2].name),
                                  *(['-invisible', '-close'] if os.name == 'nt' else []),
                                  *no_port_args(), '-trusted', '-params', f'tested_commit={commit}', '-log', 'runtime.log'],
                                logs=logs, cwd=work, phase='harvest-runtime', timeout=60,
                                state_directory=work, required_inputs=required)
        evidence.write_log(logs/'daemon.log', runtime.stdout + runtime.stderr)
        manifest['staging_after_runtime'] = validate_runtime_inputs(logs, required)
        result = read_bounded(work/'result.txt', 4096).strip()
        log = read_bounded(work/'runtime.log')
        if read_bounded(work/'port-closed.txt', 16).strip() != 'closed':
            raise RuntimeError('Native no-port assertion did not complete')
        errors = work / 'errors.txt'
        if runtime.returncode or not result.startswith('PASS:') or 'runtime error:' in log.lower() or (errors.exists() and errors.stat().st_size):
            print(log, flush=True)
            raise RuntimeError('Harvest fixture failed')
        manifest['status'] = 'functional_pass_cleanup_pending'
        if sys.platform == 'linux' and args.acceptance_scope == 'full':
            deadline = time.monotonic() + args.cleanup_receipt_wait
            while not args.external_cleanup_receipt.exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            manifest['external_cleanup_receipt'] = verify_external_cleanup(args.external_cleanup_receipt, logs, commit, prefix)
            manifest['external_descendant_cleanup'] = 'external_attestation_requires_independent_review'
        elif sys.platform == 'linux':
            manifest['external_descendant_cleanup'] = 'unverified_limited_scope'
        elif session is None or not all(p.get('owned_exit_evidence_complete') for p in session.phases):
            raise RuntimeError('Harvest owned native cleanup remains unconfirmed; files retained')
        manifest['status'] = ('fixture_pass_with_cleanup_evidence' if args.acceptance_scope == 'full'
                              else 'limited_fixture_pass_cleanup_unverified' if sys.platform == 'linux'
                              else 'limited_fixture_pass_with_owned_exit_evidence')
        print(result, flush=True)
        if args.acceptance_scope == 'limited':
            note = ('Linux descendant/socket cleanup is unverified.' if sys.platform == 'linux'
                    else 'Existing owned-exit checks do not establish full gameplay acceptance.')
            print('LIMITED fixture checks only; full acceptance is incomplete. '+note, flush=True)
    except BaseException as error:
        manifest.update(status='failed', error_type=type(error).__name__, error=repr(error))
        raise
    finally:
        original = sys.exc_info()[1]
        try:
            evidence.retain_manifest(logs, generated, manifest, finalized=True)
        except BaseException as retention_error:
            if original is None:
                raise
            print('Harvest evidence finalization failed: '+repr(retention_error), file=sys.stderr)


if __name__ == '__main__':
    main()
