"""Compare independent native baseline/candidate season evidence, failing closed."""
import argparse
import json
from pathlib import Path

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('baseline', type=Path, nargs='?')
    p.add_argument('--baseline', type=Path, dest='baseline_option')
    p.add_argument('candidate', type=Path, nargs='?')
    p.add_argument('--candidate', type=Path, dest='candidate_option')
    p.add_argument('--allow-legacy-loop-baseline', action='store_true', help='Compare correctness against explicitly guarded legacy reference; suppress performance ratios')
    p.add_argument('--max-gap-ds', type=int, required=True)
    a = p.parse_args()
    if (a.baseline and a.baseline_option) or (a.candidate and a.candidate_option):
        p.error('Use either positional paths or named paths, without duplicates')
    a.baseline = a.baseline or a.baseline_option
    a.candidate = a.candidate or a.candidate_option
    if not a.baseline or not a.candidate:
        p.error('Both baseline and candidate evidence paths are required')
    old, new = (json.loads(path.read_text()) for path in (a.baseline, a.candidate))
    assert old['mode'] == 'baseline' and new['mode'] == 'candidate'
    assert old.get('profiling_enabled', False) == new.get('profiling_enabled', False), 'Profiled and unprofiled benchmarks cannot be compared'
    assert old.get('profiling_scope') == new.get('profiling_scope'), 'Profiling scopes differ'
    assert not old['request_scenarios'] and not new['request_scenarios'], 'Benchmark workloads must be equal'
    assert old['dimensions'] == new['dimensions']
    assert old['baseline_sha'] == new['baseline_sha']
    assert old['phase_delay_adapter'] == new['phase_delay_adapter'], 'Phase adapters differ'
    assert old['daemon_timeout_seconds'] == new['daemon_timeout_seconds']
    assert old['budget_adapter'] == new['budget_adapter'], 'Budget adapter scopes differ'
    assert new['negative_control'] == 'none'
    assert new['runtime_diagnostics']['valid'] and new['runtime_diagnostics']['state'] == 'strict-clean'
    guarded = old['negative_control'] == 'legacy-loop'
    assert guarded == a.allow_legacy_loop_baseline, 'Guarded baseline requires explicit comparator opt-in'
    if guarded:
        assert old['dimensions'] == [660, 550, 1] and old['negative_control_detected']
        assert old['runtime_diagnostics']['valid'] and old['runtime_diagnostics']['state'] == 'legacy-guarded'
        assert old['runtime_diagnostics']['recognized_legacy_guard_count'] > 0
        assert not old['runtime_diagnostics']['unexpected_diagnostics']
    else:
        assert old['negative_control'] == 'none'
        assert old['runtime_diagnostics']['valid'] and old['runtime_diagnostics']['state'] == 'strict-clean'
    assert old['cycles'] == new['cycles'] == 4
    assert len(old['samples']) == len(new['samples']) == 4, 'Exactly four cycle samples are required'
    for result in (old, new):
        for metric in ('process_cpu_seconds', 'daemon_wall_seconds', 'process_peak_memory_bytes', 'peak_helper_slots'):
            assert isinstance(result.get(metric), (int, float)) and result[metric] > 0, f'Missing/empty telemetry: {metric}'
        assert result.get('memory_samples', 0) > 0, 'Process memory was not sampled'
        assert result['identity_failures'] == 0, 'Baseline/candidate distractor identities changed'
        assert all(row['all_phase_completion_ticks'] >= row['elapsed_ticks'] for row in result['samples']), 'Invalid all-phase completion time'
    assert bool(old['operation_trace']) == (old['dimensions'] == [64, 48, 1]), 'Small baseline ordered operation trace missing'
    assert bool(new['operation_trace']) == (new['dimensions'] == [64, 48, 1]), 'Small candidate ordered operation trace missing'
    assert old['clock'] == new['clock'] == 4
    assert old['rng_thresholds'] == new['rng_thresholds'], 'RNG call order changed'
    assert old['events'] == new['events'], 'Weather/tree/announcement order changed'
    assert old['operation_trace'] == new['operation_trace'], 'Ordered terrain/icon/RNG operations changed'
    for before, after in zip(old['samples'], new['samples'], strict=True):
        for field in ('cycle', 'season', 'terrain_md5', 'rng_calls', 'clock'):
            assert before[field] == after[field], f'Phase parity failed: {field}'
    assert new['identity_failures'] == 0
    assert new['budget_service']['seen'] > 0
    assert new['budget_service']['progress'] and new['budget_service']['serviced']
    assert new['peak_gap_ds'] <= a.max_gap_ds, 'Heartbeat gap exceeded explicit bound'
    metric_keys = ('process_cpu_seconds', 'daemon_wall_seconds', 'process_peak_memory_bytes', 'peak_helper_slots')
    ratios = None if guarded else {key: new[key] / old[key] for key in metric_keys}
    scopes = {name: {'scope': result['reference_scope'], 'metrics': {key: result[key] for key in metric_keys}, 'diagnostics': result['runtime_diagnostics']['state']} for name, result in (('baseline', old), ('candidate', new))}
    print(json.dumps({'candidate_baseline_ratios': ratios, 'clean_paired_performance_equivalence': not guarded, 'separate_measurements': scopes, 'measurement_scope': new['process_metric_scope'], 'dimensions': new['dimensions'], 'peak_gap_ds': new['peak_gap_ds'], 'peak_gap_ticks': new['peak_gap_ticks'], 'completion_ticks': [row['elapsed_ticks'] for row in new['samples']], 'all_phase_completion_ticks': [row['all_phase_completion_ticks'] for row in new['samples']], 'parity_positive_pause_calls': new['positive_pause_calls'], 'parity_zero_pause_calls': new['zero_pause_calls'], 'parity': True}))

if __name__ == '__main__':
    main()
