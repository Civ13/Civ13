"""Compare independent native baseline/candidate season evidence, failing closed."""
import argparse
import json
from pathlib import Path

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('baseline', type=Path)
    p.add_argument('candidate', type=Path)
    p.add_argument('--max-gap-ds', type=int, required=True)
    a = p.parse_args()
    old, new = (json.loads(path.read_text()) for path in (a.baseline, a.candidate))
    assert old['mode'] == 'baseline' and new['mode'] == 'candidate'
    assert not old['request_scenarios'] and not new['request_scenarios'], 'Benchmark workloads must be equal'
    assert old['dimensions'] == new['dimensions']
    assert old['baseline_sha'] == new['baseline_sha']
    assert old['negative_control'] == new['negative_control'] == 'none'
    assert old['cycles'] == new['cycles'] == 4
    assert old['clock'] == new['clock'] == 4
    assert old['rng_thresholds'] == new['rng_thresholds'], 'RNG call order changed'
    assert old['events'] == new['events'], 'Weather/tree/announcement order changed'
    for before, after in zip(old['samples'], new['samples'], strict=True):
        for field in ('cycle', 'season', 'terrain_md5', 'rng_calls', 'clock'):
            assert before[field] == after[field], f'Phase parity failed: {field}'
    assert new['identity_failures'] == 0
    assert new['positive_pause_calls'] > 0
    assert new['peak_gap_ds'] <= a.max_gap_ds, 'Heartbeat gap exceeded explicit bound'
    assert min(row['elapsed_ticks'] for row in new['samples']) > 1, 'Season work did not span ticks'
    ratios = {key: new[key] / old[key] if old.get(key) else None for key in ('process_cpu_seconds', 'daemon_wall_seconds', 'process_peak_memory_bytes', 'peak_helper_slots')}
    print(json.dumps({'candidate_baseline_ratios': ratios, 'measurement_scope': 'synthetic fixture only', 'dimensions': new['dimensions'], 'peak_gap_ds': new['peak_gap_ds'], 'peak_gap_ticks': new['peak_gap_ticks'], 'completion_ticks': [row['elapsed_ticks'] for row in new['samples']], 'parity': True}))

if __name__ == '__main__':
    main()



