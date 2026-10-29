"""Default-off owner-envelope finalization and smoke in one original budget."""
from entry_budget import Budget
_ENTRY_BUDGET = Budget() if __name__ == '__main__' else None
import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import re
import time

DYNAMIC = ['issued_unix', 'expires_unix', 'resources']
CONFLICTS = {'dm.exe', 'dd.exe', 'dreammaker.exe', 'dreamdaemon.exe',
             'dreamseeker.exe', 'ffmpeg.exe', 'godot.exe'}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def sample_resources(root, budget):
    """One read-only Windows sample. No quiet polling or native game launch."""
    measured_unix = time.time()
    def check_sample():
        budget.check()
        require(0 <= time.time() - measured_unix <= 5, 'Resource sample aged during collection')
    check_sample()
    import ctypes as c
    from ctypes import wintypes as w
    require(os.name == 'nt', 'Windows sample required')
    k, u = c.WinDLL('kernel32', use_last_error=True), c.WinDLL('user32', use_last_error=True)
    def checked(value):
        if not value:
            raise c.WinError(c.get_last_error())
        return value
    class Memory(c.Structure):
        _fields_ = [('length', w.DWORD), ('load', w.DWORD), ('values', c.c_ulonglong * 7)]
    class Input(c.Structure):
        _fields_ = [('size', w.UINT), ('tick', w.DWORD)]
    class Process(c.Structure):
        _fields_ = [('size', w.DWORD), ('usage', w.DWORD), ('pid', w.DWORD),
                    ('heap', c.c_size_t), ('module', w.DWORD), ('threads', w.DWORD),
                    ('parent', w.DWORD), ('priority', w.LONG), ('flags', w.DWORD),
                    ('exe', w.WCHAR * 260)]
    k.CreateToolhelp32Snapshot.argtypes = [w.DWORD, w.DWORD]
    k.CreateToolhelp32Snapshot.restype = w.HANDLE
    k.Process32FirstW.argtypes = k.Process32NextW.argtypes = [w.HANDLE, c.POINTER(Process)]
    k.Process32FirstW.restype = k.Process32NextW.restype = w.BOOL
    k.CloseHandle.argtypes, k.CloseHandle.restype = [w.HANDLE], w.BOOL
    u.OpenInputDesktop.argtypes, u.OpenInputDesktop.restype = [w.DWORD, w.BOOL, w.DWORD], w.HANDLE
    u.CloseDesktop.argtypes, u.CloseDesktop.restype = [w.HANDLE], w.BOOL
    u.GetForegroundWindow.restype = w.HWND
    def check_conflicts():
        check_sample()
        handle = k.CreateToolhelp32Snapshot(2, 0)
        require(handle and handle != c.c_void_p(-1).value, 'Process snapshot unavailable')
        primary = None
        try:
            entry = Process(); entry.size = c.sizeof(entry)
            ok = k.Process32FirstW(handle, c.byref(entry)); count = 0
            while ok:
                check_sample(); count += 1
                require(count <= 4096, 'Process snapshot bound exceeded')
                require(entry.exe.lower() not in CONFLICTS, 'Conflicting process observed')
                ok = k.Process32NextW(handle, c.byref(entry))
            require(count > 0 and c.get_last_error() == 18, 'Process snapshot incomplete')
        except BaseException as error:
            primary = error
            raise
        finally:
            try:
                checked(k.CloseHandle(handle))
                check_sample()
            except BaseException as cleanup_error:
                if primary is None:
                    raise
                primary.add_note('Process snapshot cleanup failure: ' + str(cleanup_error)[:1024])
    check_conflicts()
    desktop = checked(u.OpenInputDesktop(0, False, 1))
    checked(u.CloseDesktop(desktop)); check_sample()
    def counters():
        values = [c.c_ulonglong() for _ in range(3)]
        checked(k.GetSystemTimes(*[c.byref(v) for v in values]))
        entry = Input(c.sizeof(Input), 0); checked(u.GetLastInputInfo(c.byref(entry)))
        foreground = u.GetForegroundWindow()
        check_sample()
        return [v.value for v in values], entry.tick, foreground
    check_sample(); a, ia, fa = counters(); time.sleep(1); check_sample(); b, ib, fb = counters()
    total = b[1] - a[1] + b[2] - a[2]
    require(total > 0, 'CPU counters unavailable')
    memory = Memory(); memory.length = c.sizeof(memory)
    checked(k.GlobalMemoryStatusEx(c.byref(memory))); check_sample()
    import shutil
    disk = shutil.disk_usage(root).free
    check_sample()
    check_conflicts(); check_sample()
    return dict(measured_unix=measured_unix, free_ram_bytes=memory.values[1], free_disk_bytes=disk,
                cpu_busy_fraction=1 - (b[0] - a[0]) / total,
                input_unchanged=ia == ib, foreground_stable=fa == fb, input_desktop_access=True,
                conflicts_absent=True, host=os.environ.get('COMPUTERNAME'),
                account=os.environ.get('USERDOMAIN', '') + '\\' + os.environ.get('USERNAME', ''))


def _execute(envelope_path, reviewed_sha256, *, enabled, budget, sampler, state):
    # Construct before importing Pillow, runtime inspection or any preparation.
    require(type(budget) is Budget, 'Original entry Budget required')
    require(enabled is True, 'Same-command execution is OFF')
    import run
    budget.check()
    require(isinstance(reviewed_sha256, str) and re.fullmatch('[0-9a-f]{64}', reviewed_sha256),
            'Independent owner-envelope digest required')
    require(not envelope_path.is_symlink() and not (getattr(envelope_path.stat(), 'st_file_attributes', 0) & 0x400),
            'Linked owner envelope refused')
    envelope = run.read_json(envelope_path)
    def json_finite(value):
        if isinstance(value, dict):
            return all(json_finite(v) for v in value.values())
        if isinstance(value, list):
            return all(json_finite(v) for v in value)
        return not isinstance(value, float) or math.isfinite(value)
    require(json_finite(envelope), 'Nonfinite owner envelope')
    def unchanged():
        budget.check()
        require(run.digest(envelope_path) == reviewed_sha256, 'Owner envelope changed')
        require(envelope['admission']['source_sha256'] == run.source_identity(), 'Sealed source changed')
    unchanged()
    require(set(envelope) == {'schema', 'scope', 'enabled', 'authority_reference', 'not_before_unix',
                             'expires_unix', 'dynamic_fields', 'sampling_policy', 'admission'},
            'Unsupported owner-envelope fields')
    require(type(envelope['schema']) is int and envelope['schema'] == 1 and envelope['scope'] == 'dreamseeker-smoke-same-command-owner'
            and envelope['enabled'] is True, 'Owner policy is OFF or wrong scope')
    require(isinstance(envelope['authority_reference'], str) and envelope['authority_reference'].strip(),
            'External human authority reference required')
    require(envelope['dynamic_fields'] == DYNAMIC, 'Unsupported dynamic field delegation')
    start, end = envelope['not_before_unix'], envelope['expires_unix']
    require(finite(start) and finite(end) and 0 < end - start <= 300
            and start <= time.time() < end, 'Owner policy expired, future or overlong')
    budget.bind(end)
    policy = envelope['sampling_policy']
    require(set(policy) == {'sample_seconds', 'max_cpu_busy_fraction', 'min_free_ram_bytes',
                            'min_free_disk_bytes', 'max_sample_age_seconds'}
            and type(policy['sample_seconds']) is int and policy['sample_seconds'] == 1
            and type(policy['min_free_ram_bytes']) is int and policy['min_free_ram_bytes'] == 2 * 1024**3
            and type(policy['min_free_disk_bytes']) is int and policy['min_free_disk_bytes'] == 1024**3
            and type(policy['max_sample_age_seconds']) is int and policy['max_sample_age_seconds'] == 5,
            'Unsupported sealed sampling policy')
    threshold = policy['max_cpu_busy_fraction']
    require(finite(threshold) and 0 <= threshold <= .25, 'Unsupported sealed CPU threshold')
    packet = copy.deepcopy(envelope['admission'])
    require(set(packet) == {'host', 'account', 'python', 'pillow_version', 'pillow_sha256',
            'installed_manifest', 'limits', 'schema', 'scope', 'one_use_id', 'task_root', 'output',
            'ledger', 'source_sha256', 'issued_unix', 'expires_unix', 'resources', 'review',
            'profile', 'runtime', 'dependency_record'}, 'Unsupported admission template fields')
    require(all(packet.get(key, 'missing') is None for key in DYNAMIC), 'Dynamic placeholders required')
    require(type(packet['schema']) is int and packet['schema'] == 1 and packet['scope'] == 'dreamseeker-smoke-local-installed',
            'Wrong sealed admission scope')
    import uuid
    require(str(uuid.UUID(packet['one_use_id'])) == packet['one_use_id'], 'Noncanonical run ID')
    root = Path(packet['task_root']).resolve(strict=True)
    ledger = Path(packet['ledger']).resolve(strict=True)
    output = Path(packet['output'])
    require(ledger.is_dir() and ledger.is_relative_to(root) and not ledger.is_relative_to(output.resolve())
            and output.resolve().is_relative_to(root) and output.resolve() != root and not output.exists(),
            'Invalid sealed task paths')
    require(packet['host'] == os.environ.get('COMPUTERNAME')
            and packet['account'] == os.environ.get('USERDOMAIN', '') + '\\' + os.environ.get('USERNAME', ''),
            'Sealed host/account changed')
    for name, keys in {'python': {'path', 'sha256'}, 'runtime': {'manifest', 'sha256'},
            'dependency_record': {'path', 'sha256'},
            'profile': {'decision', 'accepted_effects', 'evidence_reference'}}.items():
        require(isinstance(packet[name], dict) and set(packet[name]) == keys, 'Invalid sealed ' + name)
    profile = packet['profile']
    require(isinstance(profile['evidence_reference'], str) and profile['evidence_reference'].strip()
            and ((profile['decision'] == 'isolated_verified' and profile['accepted_effects'] == [])
                 or (profile['decision'] == 'shared_effects_explicitly_accepted'
                     and profile['accepted_effects'] == run.SHARED_EFFECTS)), 'Sealed profile refusal')
    review = packet['review']
    require(set(review) == {'reference', 'reviewer', 'resource_owner', 'executor', 'desktop_owner',
            'native_execution_approved', 'exclusive_desktop_approved', 'socket_polling_limitation_accepted'},
            'Unsupported sealed review fields')
    require(all(isinstance(review.get(k), str) and review[k].strip() for k in
                ('reference', 'reviewer', 'resource_owner', 'executor', 'desktop_owner'))
            and all(review.get(k) is True for k in ('native_execution_approved',
                    'exclusive_desktop_approved', 'socket_polling_limitation_accepted')),
            'Sealed execution/ownership refusal')
    require(packet['limits'] == {'run_seconds': 150, 'cleanup_seconds_per_job': 5,
                               'cpu_seconds_per_process': 60, **run.LIMITS}, 'Sealed limits changed')
    state['root'] = root
    native_claim = ledger / (packet['one_use_id'] + '.json')
    final = root / 'same-command-admission.json'
    require(not native_claim.exists() and not final.exists(), 'Run already used/finalized')
    entry_claim = ledger / (packet['one_use_id'] + '.entry.json')
    def encode_record(value):
        return (json.dumps(value, indent=2) + '\n').encode('utf-8')
    def exclusive_write(path, value, *, encoded=None):
        data = encode_record(value) if encoded is None else encoded
        with path.open('xb') as stream:
            stream.write(data); stream.flush(); os.fsync(stream.fileno())
        budget.check()
    entry_record = dict(owner_envelope_sha256=reviewed_sha256,
                        owner_envelope_path=str(envelope_path.resolve()),
                        one_use_id=packet['one_use_id'], started_utc=budget.started_utc,
                        started_monotonic=budget.started_monotonic)
    expected_entry_bytes = encode_record(entry_record)
    expected_entry_hash = hashlib.sha256(expected_entry_bytes).hexdigest()
    exclusive_write(entry_claim, entry_record, encoded=expected_entry_bytes)
    state['claimed'] = True
    def entry_intact():
        budget.check()
        require(not entry_claim.is_symlink() and entry_claim.stat().st_size == len(expected_entry_bytes)
                and run.digest(entry_claim) == expected_entry_hash
                and entry_claim.read_bytes() == expected_entry_bytes, 'Entry claim changed')
        budget.check()
    entry_intact()
    unchanged()
    sample = (sampler if sampler is not None else sample_resources)(root, budget)
    entry_intact()
    unchanged()
    now = time.time()
    require(set(sample) == {'measured_unix', 'free_ram_bytes', 'free_disk_bytes', 'cpu_busy_fraction',
                           'input_unchanged', 'foreground_stable', 'input_desktop_access', 'conflicts_absent', 'host', 'account'}, 'Invalid sample fields')
    def sample_fresh():
        budget.check()
        now = time.time()
        require(start <= now < end and finite(sample['measured_unix'])
                and budget.started_utc <= sample['measured_unix'] <= now
                and now - sample['measured_unix'] <= policy['max_sample_age_seconds'],
                'Final sample stale or not from this entry')
    sample_fresh()
    require(sample['host'] == packet['host'] and sample['account'] == packet['account'],
            'Observed host/account changed')
    require(type(sample['free_ram_bytes']) is int and sample['free_ram_bytes'] >= 2 * 1024**3
            and type(sample['free_disk_bytes']) is int and sample['free_disk_bytes'] >= 1024**3
            and finite(sample['cpu_busy_fraction']) and 0 <= sample['cpu_busy_fraction'] <= threshold
            and all(sample[k] is True for k in ('input_unchanged', 'foreground_stable', 'input_desktop_access', 'conflicts_absent')),
            'Final resource/access/conflict refusal')
    packet.update(issued_unix=now, expires_unix=min(end, budget.utc_end), resources=dict(
        measured_unix=sample['measured_unix'], free_ram_bytes=sample['free_ram_bytes'],
        free_disk_bytes=sample['free_disk_bytes'], cpu_headroom_accepted=True))
    require(all(packet[k] == v for k, v in envelope['admission'].items() if k not in DYNAMIC),
            'Sealed admission mutated')
    exclusive_write(root / 'same-command-sample.json', sample)
    sample_fresh()
    # Establish the expected seal from the immutable reviewed projection, NEVER
    # by accepting a digest of a possibly rewritten filesystem object.
    expected_final_bytes = encode_record(packet)
    expected_final_hash = hashlib.sha256(expected_final_bytes).hexdigest()
    exclusive_write(final, packet, encoded=expected_final_bytes)
    sample_fresh()
    unchanged()
    entry_intact()
    def final_intact():
        sample_fresh()
        require(not final.is_symlink() and final.stat().st_size == len(expected_final_bytes)
                and run.digest(final) == expected_final_hash
                and final.read_bytes() == expected_final_bytes, 'Final admission changed')
        sample_fresh()
    final_intact()
    exclusive_write(root / 'same-command-finalization.json', dict(owner_envelope_path=str(envelope_path.resolve()),
                    owner_envelope_sha256=reviewed_sha256, admission_sha256=expected_final_hash,
                    one_use_id=packet['one_use_id'], dynamic_fields=DYNAMIC))
    unchanged(); sample_fresh()
    final_intact()
    entry_intact()
    final_intact()
    # No subprocess, message, second sample, or new clock between these steps.
    return run.run(output.resolve(), final, expected_final_hash, budget=budget)



def execute(envelope_path, reviewed_sha256, *, enabled=False, budget=None, sampler=None):
    budget = budget if budget is not None else Budget()
    state = {}
    try:
        result = _execute(envelope_path, reviewed_sha256, enabled=enabled, budget=budget,
                          sampler=sampler, state=state)
        budget.check(work=False)
        _result(state, budget, 'Harness returned; native result remains in harness receipt')
        budget.check(work=False)
        return result
    except BaseException as primary:
        if state.get('claimed'):
            try:
                _result(state, budget, 'FAIL: ' + str(primary)[:1024])
            except BaseException as secondary:
                primary.add_note('Wrapper receipt failure: ' + str(secondary)[:1024])
        raise


def _result(state, budget, outcome):
    # Never replace an uncertain prior receipt, retry execution, or reset time.
    with (state['root'] / 'same-command-result.json').open('x', encoding='utf-8') as stream:
        stream.write(json.dumps(dict(outcome=outcome, started_utc=budget.started_utc,
                                    finished_utc=time.time())) + '\n')
        stream.flush(); os.fsync(stream.fileno())


def main():
    budget = _ENTRY_BUDGET if _ENTRY_BUDGET is not None else Budget()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner-envelope', type=Path, required=True)
    parser.add_argument('--reviewed-envelope-sha256', required=True)
    parser.add_argument('--execute', action='store_true', help='OFF unless independently admitted')
    args = parser.parse_args()
    execute(args.owner_envelope, args.reviewed_envelope_sha256, enabled=args.execute, budget=budget)


if __name__ == '__main__':
    main()
