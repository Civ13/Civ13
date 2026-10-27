"""Extract production season procedures into an isolated native BYOND fixture.
Preparation never launches the compiler or daemon. Runtime is explicitly opt-in.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

BASELINE = 'e3c8d02f31f1a23c1320eaec949fb4af56e964f3'
META = 'code/game/objects/map_metadata/_map_metadata.dm'
HELPER = 'code/_helpers/areas.dm'

def digest(data):
    return hashlib.sha256(data.encode()).hexdigest()

def extract(text):
    start = re.search(r'^/obj/map_metadata/(?:Destroy|proc/(?:seasons|season_\w+))\(', text, re.M).start()
    end = text.index('//loads faction-specific recipes', start)
    return text[start:end]

def prepare(repo, mode, size, negative, requests_enabled=False, profile=False):
    def read(path):
        if mode == 'baseline':
            return subprocess.check_output(['git', 'show', BASELINE + ':' + path], cwd=repo, text=True)
        return (repo / path).read_text()
    meta = read(META)
    seasons = extract(meta)
    helper = re.search(r'^/proc/get_area_turfs\([\s\S]*?(?=^/proc/pick_area_turf)', read(HELPER), re.M).group()
    originals = seasons + helper
    asia = ''
    constructors = ''
    if mode == 'candidate':
        asia_source = (repo / 'code/game/objects/map_metadata/nomads/nomads_asia.dm').read_text()
        asia = asia_source[asia_source.index('/obj/map_metadata/nomads/asia/season_transition_complete('):]
        originals += asia
        if requests_enabled:
            for filename, typename in [('nomads.dm', 'nomads'), ('nomads_continental.dm', 'nomads/continental')]:
                text = (repo / 'code/game/objects/map_metadata/nomads' / filename).read_text()
                signature = '/obj/map_metadata/' + typename + '/New()'
                block = re.search(re.escape(signature) + r'[^\n]*\n[\s\S]*?(?=^/obj/|\Z)', text, re.M).group()
                constructors += block
            originals += constructors
    # Count delayed callbacks per owner, including nested baseline spawns.
    # Queued candidate callbacks remain covered by the busy/queue drain condition.
    def track_phases(source):
        lines = source.splitlines(keepends=True)
        endings = {}
        starts = {}
        returns = set()
        for i, line in enumerate(lines):
            match = re.match(r'^(\t*)spawn\(([^)]+)\)', line)
            if not match or match[2] == '18000':
                continue
            indent = len(match[1])
            end = i + 1
            while end < len(lines):
                item = lines[end]
                if item.strip() and not item.lstrip().startswith('//') and len(item) - len(item.lstrip('\t')) <= indent:
                    break
                if re.match(r'^\t+return(?:\s|$)', item):
                    returns.add(end)
                end += 1
            starts[i] = match[1] + 'probe_phase_pending++\n'
            endings.setdefault(end, []).append('\t' * (indent + 1) + 'probe_phase_pending--\n')
        output = []
        for i in range(len(lines) + 1):
            output.extend(reversed(endings.get(i, [])))
            if i == len(lines):
                break
            if i in starts:
                output.append(starts[i])
            if i in returns:
                indent = len(lines[i]) - len(lines[i].lstrip('\t'))
                output.append('\t' * indent + 'probe_phase_pending--\n')
            output.append(lines[i])
        return ''.join(output)
    seasons = track_phases(seasons)
    seasons = seasons.replace('world.tick_usage >= 20', '(probe_force_budget ? probe_budget_usage(work, discovery) : world.tick_usage) >= 20')
    if requests_enabled:
        seasons = re.sub(r'(^/obj/map_metadata/proc/season_work_pause[^\n]*\n)', r'\1\tprobe_checkpoint(src, epoch, work, discovery)\n', seasons, flags=re.M)
    seasons = seasons.replace('call(src, kind)(value)', 'probe_delayed_call(src, kind, value)')
    seasons = re.sub(r'^(\t*)spawn\(18000\)\n', lambda m: m[1] + 'probe_timer_armed(src, 18000)\n' + m[0] + m[1] + '\tprobe_timer_fired(src)\n', seasons, flags=re.M)
    helper = re.sub(r'^(\t+)return turfs$', lambda m: m[1] + 'probe_helper_peak_slots = max(probe_helper_peak_slots, turfs.len)\n' + m[0], helper, flags=re.M)
    # Only generated sources use deterministic RNG and accelerated delayed effects.
    seasons = re.sub(r'\bprob\(', 'probe_prob(', seasons)
    # Recurring timers keep the separate 210-ds adapter used by cadence assertions.
    # Phase delays retain ten times the former spacing: Fall's 900/100-ds
    # callbacks now have an 80-ds margin instead of 8 ds around yielded main work.
    phase_delay_divisor = 100 if requests_enabled else 10
    def generated_delay(delay):
        return 210 if delay == 18000 else 30 + delay // phase_delay_divisor
    seasons = re.sub(r'spawn\((\d+)\)', lambda m: 'spawn(' + str(generated_delay(int(m[1]))) + ')', seasons)
    seasons = re.sub(r'season_schedule_phase\((\d+),', lambda m: 'season_schedule_phase(' + str(generated_delay(int(m[1]))) + ',', seasons)
    if negative == 'yield':
        seasons = re.sub(r'\bsleep\([^\n]*?\)', 'sleep(0)', seasons)
        helper = re.sub(r'\bsleep\([^\n]*?\)', 'sleep(0)', helper)
    elif negative == 'clock':
        seasons, count = re.subn(r'record_abandonment_season_change\(advance_decay\)', 'record_abandonment_season_change(FALSE)', seasons)
        assert count, 'Clock negative control failed to patch production'
    seasons = re.sub(r'\bsleep\(([^\n]*?)\)', r'probe_pause(\1)', seasons)
    if requests_enabled:
        seasons = seasons.replace('\t\tprobe_pause(world.tick_lag)\n', '\t\tprobe_pause(world.tick_lag)\n\t\tprobe_after_pause(src, epoch, discovery)\n')
    def track_candidates(source):
        return re.sub(r'^(\t+)for\s*\(var/(?:turf|obj)/[^\n]*?/([A-Za-z_]\w*)\s+in [^\n]*\)[^\n]*\n', lambda m: m[0] + m[1] + '\tprobe_current_candidate = ' + m[2] + '\n', source, flags=re.M)
    if requests_enabled or size == 'small':
        seasons = track_candidates(seasons)
        asia = track_candidates(asia)
    helper = re.sub(r'\bsleep\(([^\n]*?)\)', r'probe_pause(\1)', helper)
    paths = set(re.findall(r'/(?:turf|area|obj)/[A-Za-z_][A-Za-z_0-9/]*', originals))
    callable_paths = set(re.findall(r'^(/obj/[A-Za-z_][A-Za-z_0-9/]*)\(', originals, re.M))
    paths = {p for p in paths if not p.startswith('/obj/map_metadata/proc/') and p not in callable_paths}
    types = '\n'.join(sorted(paths)) + '\n/obj/map_metadata/nomads/asia\n/obj/map_metadata/nomads/continental\n'
    # Extract production phase state declarations, never guess runtime defaults.
    metadata_type_block = re.search(r'^/obj/map_metadata[ \t]*\n([\s\S]*?)(?=^/[A-Za-z_]|\Z)', meta, re.M).group(1)
    declarations = '\n'.join(line for line in metadata_type_block.splitlines() if re.match(r'\tvar/(?:tmp/)?(?:list/)?season_', line))
    # Procedure locals such as season_work must remain local, never injected fields.
    field_names = re.findall(r'^\tvar/(?:tmp/)?(?:list/)?(season_\w+)', declarations, re.M)
    assert len(field_names) == len(set(field_names)), 'Duplicate extracted season fields'

    production = types + '\n/obj/map_metadata\n' + declarations + '\n' + seasons + helper + asia + constructors
    production += (repo / 'code/_helpers/functional.dm').read_text()
    probe = Path(__file__).with_name('probe.dm').read_text()
    requests = Path(__file__).with_name('requests.dm').read_text()
    if mode == 'baseline':
        # Baseline has no candidate request/worker APIs. Shared observers only.
        requests = """var/atom/probe_current_candidate
/proc/probe_timer_armed(obj/map_metadata/M, delay)
	return
/proc/probe_timer_fired(obj/map_metadata/M)
	return
"""

    width, height = (660, 550) if size == 'largest' else (64, 48)
    dme = f'''#define TRUE 1
#define FALSE 0
#define WEATHER_NONE 0
#define WEATHER_WET 1
#define WIDTH {width}
#define HEIGHT {height}
#define CANDIDATE {int(mode == 'candidate')}
#define OPTRACE {int(size == 'small')}
#define REQUESTCHECK {int(requests_enabled and mode == 'candidate' and negative == 'none')}
#define PROFILECHECK {int(profile)}
#define CRASH(message) throw new /exception(message)
#include "probe.dm"
#include "production.dm"
#include "requests.dm"
'''
    return {'probe.dm': probe, 'production.dm': production, 'requests.dm': requests, 'probe.dme': dme}, {'source_sha256': digest(originals), 'generated_sha256': digest(production), 'dimensions': [width, height, 1], 'mode': mode, 'request_scenarios': requests_enabled, 'negative_control': negative, 'baseline_sha': BASELINE, 'phase_delay_adapter': {'offset_ds': 30, 'divisor': phase_delay_divisor, 'recurring_delay_ds': 210}, 'daemon_timeout_seconds': 900, 'budget_adapter': 'actual tick usage during parity; forced 20 percent only post-parity direct service call and request batch checkpoints', 'process_metric_scope': 'whole child includes candidate post-parity service witness (up to two ticks); requests excluded from benchmark comparisons'}

DIAGNOSTICS = re.compile(r'runtime error|Bad ref|Bad loc|Cannot read null|Cannot execute null|Infinite loop suspected|switching proc to background|PORT_OPEN|ASSERTION', re.I)
LEGACY_GUARD = re.compile(
    r'Infinite loop suspected--switching proc to background\.\r?\n'
    r"If it is not an infinite loop, either do 'set background=1' or set world\.loop_checks=0\.\r?\n"
    r'proc name: seasons \(/obj/map_metadata/proc/seasons\)\r?\n'
    r'  usr: null\r?\n'
    r'  src: [^\r\n]+ \(/obj/map_metadata\)\r?\n'
    r'  src\.loc: [^\r\n]+\r?\n'
    r'  call stack:\r?\n'
    r'[^\r\n]+: seasons\(0, 0, 1\)\r?\n'
    r'world: New\(\)\r?\n')

def validate_legacy_scope(mode, size, negative, requests):
    if negative == 'legacy-loop' and (mode != 'baseline' or size != 'largest' or requests):
        raise ValueError('legacy-loop requires baseline + largest without request scenarios')

def classify_runtime(log, legacy_control=False):
    recognized = [match.group() for match in LEGACY_GUARD.finditer(log)]
    residual = LEGACY_GUARD.sub('', log) if legacy_control else log
    unexpected = DIAGNOSTICS.findall(residual)
    valid = not unexpected and (bool(recognized) if legacy_control else True)
    return {'valid': valid, 'state': ('legacy-guarded' if legacy_control else 'strict-clean') if valid else 'rejected',
            'recognized_legacy_guard_count': len(recognized), 'recognized_legacy_guards': recognized,
            'unexpected_diagnostics': unexpected, 'legacy_control_requested': legacy_control}

def self_test_diagnostics():
    guard = """Infinite loop suspected--switching proc to background.
If it is not an infinite loop, either do 'set background=1' or set world.loop_checks=0.
proc name: seasons (/obj/map_metadata/proc/seasons)
  usr: null
  src: the map metadata (/obj/map_metadata)
  src.loc: the drywater2 (1,1,1) (/turf/floor/beach/drywater2)
  call stack:
the map metadata (/obj/map_metadata): seasons(0, 0, 1)
world: New()
"""
    cases = {'recognized': (guard, True, True), 'strict-candidate': (guard, False, False),
             'unknown-proc': (guard.replace('proc name: seasons', 'proc name: unknown'), True, False),
             'mixed-error': (guard + 'runtime error: unrelated\n', True, False),
             'truncated': (guard.rsplit('world:', 1)[0], True, False),
             'missing': ('Welcome BYOND!\n', True, False), 'clean': ('Welcome BYOND!\n', False, True)}
    for name, (log, control, expected) in cases.items():
        assert classify_runtime(log, control)['valid'] == expected, name
    invalid_scopes = [('candidate', 'largest', False), ('baseline', 'small', False), ('baseline', 'largest', True)]
    for mode, size, requests in invalid_scopes:
        try:
            validate_legacy_scope(mode, size, 'legacy-loop', requests)
        except ValueError:
            continue
        raise AssertionError('Invalid legacy control scope accepted')
    validate_legacy_scope('baseline', 'largest', 'legacy-loop', False)
    print(json.dumps({'diagnostic_parser_cases': len(cases), 'invalid_scope_cases': len(invalid_scopes), 'passed': True}))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--self-test-diagnostics', action='store_true', help='Compiler-free native diagnostic parser and scope controls')
    parser.add_argument('--prepare-only', type=Path)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--mode', choices=('candidate', 'baseline'), default='candidate')
    parser.add_argument('--requests', action='store_true', help='Run additional candidate request scenarios separately from comparable parity benchmarks')
    parser.add_argument('--profile', action='store_true', help='Retain native proc profiling for the four parity cycles; compare only with equally profiled evidence')
    parser.add_argument('--size', choices=('small', 'largest'), default='small')
    parser.add_argument('--negative-control', choices=('none', 'yield', 'clock', 'legacy-loop'), default='none')
    args = parser.parse_args()
    if args.self_test_diagnostics:
        self_test_diagnostics()
        return
    try:
        validate_legacy_scope(args.mode, args.size, args.negative_control, args.requests)
    except ValueError as error:
        parser.error(str(error))
    repo = Path(__file__).resolve().parents[2]
    files, metadata = prepare(repo, args.mode, args.size, args.negative_control, args.requests, args.profile)
    metadata['profiling_enabled'] = args.profile
    metadata['profiling_scope'] = 'Four parity cycles including worker/phase waits, heartbeat and terrain snapshots; excludes setup, identity checks, service witness and request scenarios' if args.profile else None
    metadata['head_sha'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
    metadata['dirty_patch_sha256'] = hashlib.sha256(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=repo)).hexdigest()
    if args.prepare_only:
        args.prepare_only.mkdir(parents=True, exist_ok=False)
        for name, contents in files.items():
            (args.prepare_only / name).write_text(contents)
        (args.prepare_only / 'source-manifest.json').write_text(json.dumps(metadata, indent=2))
        print(json.dumps(metadata))
        return
    if not args.byond_bin or not args.output:
        parser.error('Runtime requires --byond-bin and --output; preparation uses --prepare-only')
    if args.output.exists():
        parser.error('Output must be fresh')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    logs = args.output.with_suffix('.logs')
    logs.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='civ13-season-transition-') as temp:
        root = Path(temp)
        for name, contents in files.items():
            (root / name).write_text(contents)
            (logs / name).write_text(contents)
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=root, capture_output=True, text=True, timeout=120, creationflags=flags)
        buildlog = build.stdout + build.stderr
        (logs / 'compile.log').write_text(buildlog)
        if build.returncode or '516.1681' not in buildlog or '0 errors, 0 warnings' not in buildlog:
            raise SystemExit(buildlog)
        start = time.monotonic()
        from telemetry import run_native
        returncode, stdout, stderr, telemetry = run_native([str(daemon), 'probe.dmb'] + (['-invisible'] if os.name == 'nt' else []) + ['-close', '-trusted', '-log', 'runtime.log'], root, flags, 900)
        log = (root / 'runtime.log').read_text(errors='replace') + (stdout + stderr).decode(errors='replace')
        (logs / 'runtime.log').write_text(log)
        diagnostics = classify_runtime(log, args.negative_control == 'legacy-loop')
        (logs / 'diagnostics.json').write_text(json.dumps(diagnostics, indent=2))
        metadata['runtime_diagnostics'] = diagnostics
        (logs / 'telemetry.json').write_text(json.dumps(telemetry, indent=2))
        if (root / 'result.json').exists():
            (logs / 'raw-result.json').write_text((root / 'result.json').read_text())
        metadata['reference_scope'] = 'immutable legacy guarded reference; no clean paired CPU/wall equivalence' if args.negative_control == 'legacy-loop' else 'strict clean native diagnostics'
        (logs / 'source-manifest.json').write_text(json.dumps(metadata, indent=2))
        # Retain profile evidence before rejecting a native diagnostic.
        if args.profile and (root / 'profile.json').exists():
            profile_text = (root / 'profile.json').read_text()
            (logs / 'profile.json').write_text(profile_text)
            profile_data = json.loads(profile_text)
            assert isinstance(profile_data, (dict, list)) and profile_data, 'Native proc profile is empty'
            metadata['profiling_artifact'] = str(logs / 'profile.json')
        if returncode or not diagnostics['valid']:
            raise SystemExit(log + '\nNative diagnostics rejected: ' + json.dumps(diagnostics))
        if args.profile:
            assert 'profiling_artifact' in metadata, 'Native profile artifact missing'
        result = json.loads((root / 'result.json').read_text())
        result.update(metadata, elapsed_seconds=time.monotonic() - start, **telemetry)
        args.output.write_text(json.dumps(result, indent=2))
        assert result['cycles'] == 4 and result['distractors'] == 20080
        assert result['identity_failures'] == 0
        assert len(result['samples']) == 4, 'Complete four-cycle evidence is required'
        if args.negative_control == 'legacy-loop':
            result['negative_control_detected'] = True
        if args.negative_control == 'clock':
            assert result['clock'] != 4, 'Clock negative control was not detected'
            result['negative_control_detected'] = True
        else:
            assert result['clock'] == 4, 'Natural transition clocks were lost'
        if args.mode == 'candidate':
            service = result['budget_service']
            assert service['seen'] > 0, 'Dedicated budget branch was not exercised'
            if args.negative_control == 'yield':
                assert not service['progress'] and not service['serviced'], 'Yield control did not fail the timed service witness'
                result['negative_control_detected'] = True
            else:
                assert service['progress'] and service['serviced'], 'Exhausted-budget wait failed tick progress or locked service'
                if args.negative_control == 'none' and args.requests:
                    assert result['requests']['failures'] == 0, 'Request ownership/flags/cancellation failed'
        args.output.write_text(json.dumps(result, indent=2))
        print(json.dumps({k: result[k] for k in ('cycles', 'clock', 'identity_failures', 'peak_gap_ticks', 'elapsed_seconds')}))

if __name__ == '__main__':
    main()
