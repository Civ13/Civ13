"""Reviewable fixed native plan. Data and synthetic file operations only.

Preparation is the default. Explicit reviewed-native invokes the exact-checkout
backend; this module itself only defines data and synthetic file operations.
"""
from pathlib import Path
from prepare import bounded_file, digest, dump, safe_root

PHASES = (
    ('baseline-compile', 'compiler', 'baseline', None),
    ('baseline-writer', 'daemon', 'baseline', 'writer'),
    ('baseline-reader', 'daemon', 'baseline', 'reader'),
)
PROFILES = {
    'compiler': {'wall_seconds': 180, 'cpu_seconds': 150, 'address_space_bytes': 2 * 1024**3,
                 'file_bytes': 512 * 1024**2, 'file_descriptors': 256, 'stdout_bytes': 4 * 1024**2},
    'daemon': {'wall_seconds': 180, 'cpu_seconds': 30, 'address_space_bytes': 1024**3,
               'file_bytes': 16 * 1024**2, 'file_descriptors': 128, 'stdout_bytes': 4 * 1024**2},
}
TOTAL_WALL_SECONDS = 600
CLEANUP_RESERVE_SECONDS = 8
OUTPUT_LIMITS = {'individual_log_bytes': 4 * 1024**2, 'runtime_extra_files': 2048,
                 'runtime_extra_bytes': 128 * 1024**2, 'aggregate_evidence_bytes': 2 * 1024**3,
                 'compiled_pair_bytes': 512 * 1024**2}
RESTART_FILES = {'map_saves/1.sav': 16 * 1024**2, 'map_saves/map.txt': 16384,
                 'map_saves/round.json': 1024**2, 'map_saves/save_complete.txt': 4096,
                 'winter-growth-writer.json': 1024**2}
PRIVATE_HOME = {'files': 16, 'directories': 16, 'depth': 4,
                'file_bytes': 256 * 1024, 'total_bytes': 1024**2}


def proposed_plan(binding):
    return {'schema': 1, 'candidate_manifest_sha256': binding,
            'activation': 'explicit-reviewed-native-plus-actual-exact-checkout',
            'has_native_backend': True, 'disabled_backend_source_proposal': False, 'native_executed': False,
            'total_wall_seconds': TOTAL_WALL_SECONDS, 'cleanup_reserve_seconds': CLEANUP_RESERVE_SECONDS,
            'profiles': PROFILES, 'output_limits': OUTPUT_LIMITS, 'private_home_limits': PRIVATE_HOME,
            'phases': [{'id': p, 'role': role, 'variant': variant, 'mode': mode} for p, role, variant, mode in PHASES],
            'runtime_directory_policy': 'fresh per phase; no reuse; private HOME and TMPDIR per process',
            'restart_copy': {'from': 'baseline-writer', 'to': 'baseline-reader', 'only_files': RESTART_FILES,
                             'requires': 'validated writer and independently verified cleanup'},
            'source_policy': 'reverify candidate manifest, source overlay, controller seal and archive members before every phase',
            'closure_policy': 'readiness before fixture setup, owned-process listener census before fixed acknowledgement',
            'failure_policy': 'stop immediately; retain all logs, source seals and cleanup-error receipts; never retry consumed packets',
            'exclusions': ['desktop', 'Gaia', 'real saves', 'live server', 'connected client', 
                           'network sandbox claim', 'Windows receipt relabel', 'Git identity fabrication']}


def copy_restart(writer, reader, receipt, binding):
    """Copy only the five fixed synthetic save/observer files, never a path supplied by the save.

    The backend independently validates the writer before admitting this copy.
    Offline tests use invented bytes; the copy helper itself launches nothing.
    """
    required = {'candidate_manifest_sha256': binding, 'phase': 'baseline-writer',
                'started': True, 'process_completed': True, 'cleanup_verified': True, 'validated': True}
    if any(receipt.get(key) != value or (isinstance(value, bool) and type(receipt.get(key)) is not bool)
           for key, value in required.items()):
        raise ValueError('Writer is not bound, completed, validated and cleaned')
    writer = safe_root(writer)
    reader = reader.absolute()
    if reader.exists() or reader == writer or writer in reader.parents or reader in writer.parents:
        raise ValueError('Reader must be fresh and separate from writer')
    if any(parent.is_symlink() for parent in reader.parents):
        raise ValueError('Linked reader parent')
    expected_rows = receipt.get('restart_files')
    if not isinstance(expected_rows, dict) or set(expected_rows) != set(RESTART_FILES):
        raise ValueError('Writer must seal exactly the fixed restart files')
    data_rows = {}
    for name, limit in RESTART_FILES.items():
        data = bounded_file(writer / name, limit)
        if not data or expected_rows[name] != {'bytes': len(data), 'sha256': digest(data)}:
            raise ValueError('Writer restart file changed or empty: ' + name)
        data_rows[name] = data
    reader.mkdir(parents=True)
    copied = {}
    for name, data in data_rows.items():
        target = reader / name
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('xb') as stream:
            stream.write(data)
        copied[name] = {'bytes': len(data), 'sha256': digest(bounded_file(target, RESTART_FILES[name]))}
        if copied[name] != expected_rows[name] or bounded_file(writer / name, RESTART_FILES[name]) != data:
            raise ValueError('Restart source or destination changed during copy; retained')
    dump(reader / 'restart-copy.json', {'schema': 1, 'candidate_manifest_sha256': binding,
         'source_phase': 'baseline-writer', 'destination_phase': 'baseline-reader', 'files': copied,
         'paths_from_save_contents': False})
    return copied


def activation_gate(reviewed_native=False):
    if reviewed_native is not True:
        raise RuntimeError('Native activation blocked: explicit reviewed-native invocation required')
