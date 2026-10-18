"""Offline normal-client packet/result checks; metadata is not UI/OS evidence."""
import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re

from client_gather_profile import IDENTITIES, MAP, ORACLE, verify_dme, verify_map, verify_oracle


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def read_json(path):
    path = Path(path)
    require(path.stat().st_size <= 2097152, 'JSON output bound exceeded')
    def duplicate(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'duplicate JSON key')
            result[key] = value
        return result
    def invalid(_):
        raise ValueError('non-finite JSON value')
    return json.loads(path.read_text(encoding='utf-8-sig'), object_pairs_hook=duplicate, parse_constant=invalid)


def verify_packet(packet, expected):
    packet = Path(packet).resolve()
    M = read_json(packet / 'manifest.json')
    require(M['schema'] == 1 and M['kind'] == 'ordinary_client_gather' and M['commit'] == expected,
            'packet schema/commit mismatch')
    require(M['runtime_ready'] is False and M['runtime'] == 'not_run' and M['native_grant'] is None
            and M['actual_native_geometry'] is None and M['desired_dimensions'] == [9, 9, 1],
            'prepared source must not imply runtime readiness')
    source = packet / 'source'
    require(not source.is_symlink(), 'source root must not be a link')
    hashes = M['source_sha256']
    require(1 <= len(hashes) <= 10000, 'source closure bound')
    require(not any(p.startswith('config/') or p == 'rust_g.dll' for p in hashes),
            'compile-only source packet must not stage runtime configuration/library')
    actual = set(p.relative_to(source).as_posix() for p in source.rglob('*') if p.is_file())
    require(actual == set(hashes), 'source closure extra/missing file')
    for relative, digest in hashes.items():
        rel = PurePosixPath(relative)
        require(not rel.is_absolute() and '..' not in rel.parts and '\\' not in relative,
                'unsafe source binding path')
        path = source.joinpath(*rel.parts)
        require(not path.is_symlink() and source.resolve() in path.resolve().parents, 'source escapes packet')
        require(re.fullmatch('[0-9a-f]{64}', digest) and hashlib.sha256(path.read_bytes()).hexdigest() == digest,
                'frozen source hash mismatch: ' + relative)
    require(set(M['normal_source_sha256']) == set(IDENTITIES), 'normal production identity set drift')
    require(all(hashes[p] == digest for p, digest in M['normal_source_sha256'].items()), 'normal source identity mismatch')
    text = lambda p: (source / p).read_text(encoding='utf-8-sig').replace('\r\n', '\n')
    verify_dme(text('civ13.dme'), text('client_gather.dme'))
    verify_map(text(MAP))
    verify_oracle(text(ORACLE))
    require(not (packet / 'runtime').exists(), 'source preparation must not stage private/runtime config')
    return M


def integer(value):
    return type(value) is int and 0 <= value <= 1000000000


def clock(value):
    return type(value) in (int, float) and math.isfinite(value) and 0 <= value <= 1000000000


def verify_result(R, expected, run_id, witness):
    """Check passive traces plus externally supplied fresh post-ACK status witness.

    The witness must come from a separately reviewed executor after actual cancel
    ACK receipt. This function cannot establish UI actions or its clock ordering.
    """
    require(isinstance(R, dict) and R.get('schema') == 1 and R.get('kind') == 'ordinary_client_gather'
            and R.get('commit') == expected and R.get('run_id') == run_id, 'result identity mismatch')
    require(re.fullmatch('[a-zA-Z0-9_-]{1,64}', run_id) is not None, 'bounded run ID required')
    require(R.get('final') == 1 and R.get('cleaned_refs') == 1 and R.get('phase') == 'observation_complete'
            and R.get('failure') == '' and R.get('dimensions') == [9, 9, 1], 'incomplete/failed passive result')
    require(all(clock(R.get(k)) for k in ('tick', 'bound_tick', 'cancel_tick', 'returned_tick')),
            'bounded finite world-time fields required')
    rows = R.get('samples')
    require(isinstance(rows, list) and 70 <= len(rows) <= 1201, 'bounded physical samples required')
    keys = {'sequence', 'tick', 'life_tick', 'same_tool', 'cuttings', 'left_grass', 'right_grass',
            'left_lit', 'right_lit', 'left_advertised', 'right_advertised', 'may_do_after',
            'survival_actions', 'worker', 'claimed', 'cancelled', 'request_index'}
    flags = keys - {'sequence', 'tick', 'life_tick', 'cuttings', 'survival_actions', 'request_index'}
    for index, row in enumerate(rows):
        require(isinstance(row, dict) and set(row) == keys and clock(row['tick'])
                and all(integer(v) for k, v in row.items() if k != 'tick'),
                'malformed passive sample')
        require(all(row[k] in (0, 1) for k in flags) and row['request_index'] in (0, 1, 2)
                and row['sequence'] == index + 1, 'sample sequence/flag mismatch')
        if index:
            previous = rows[index - 1]
            require(1 <= row['tick'] - previous['tick'] <= 2 and row['life_tick'] >= previous['life_tick']
                    and row['request_index'] >= previous['request_index'], 'sampling gap/clock/actor progression')
    require(rows[-1]['life_tick'] > rows[0]['life_tick'], 'natural Life progression missing')
    require(R['sequence'] == rows[-1]['sequence'] and 0 <= R['tick'] - rows[-1]['tick'] <= 2,
            'final sampling/cleanup horizon incomplete')
    require(rows[-1]['tick'] - R['bound_tick'] >= 1198, 'fixed observation deadline was shortened')
    ids = R.get('request_ids')
    require(isinstance(ids, list) and len(ids) == 2 and len(set(ids)) == 2
            and all(isinstance(v, str) and re.fullmatch('[a-zA-Z0-9_-]{1,64}', v) for v in ids),
            'two distinct bounded original requests required')
    receipts = R.get('receipts')
    require(isinstance(receipts, dict) and set(receipts) == set(ids)
            and receipts[ids[0]] == {'status': 'completed', 'reason': 'none'}
            and receipts[ids[1]] == {'status': 'cancelled', 'reason': 'cancelled'},
            'original completion/cancellation receipts required')
    ready = [r for r in rows if r['request_index'] == 0 and r['same_tool'] and r['cuttings'] == 0
             and all(r[k] for k in ('left_grass', 'right_grass', 'left_lit', 'right_lit', 'left_advertised', 'right_advertised'))]
    require(ready, 'natural pickup and normal advertised/lit grass precondition missing')
    paid = [r for r in rows if r['request_index'] == 1 and r['worker'] and r['claimed']
            and not r['may_do_after'] and r['survival_actions'] == 1 and not r['cancelled']]
    require(len(paid) >= 2 and paid[-1]['tick'] - paid[0]['tick'] >= 26,
            'canonical paid wait sampled interval missing')
    done = [r for r in rows if r['request_index'] == 1 and not r['worker'] and not r['left_grass']
            and r['right_grass'] and r['cuttings'] == 2 and r['may_do_after'] and not r['survival_actions'] and r['same_tool']]
    require(done and done[0]['tick'] > paid[-1]['tick'], 'two paid cuttings/turf replacement/balanced callbacks missing')
    second = [r for r in rows if r['request_index'] == 2 and r['worker'] and r['claimed']]
    cancelled = [r for r in rows if r['request_index'] == 2 and r['cancelled']]
    require(second and cancelled
            and R['cancel_tick'] == cancelled[0]['tick'] and R['returned_tick'] >= cancelled[0]['tick']
            and R['returned_tick'] > second[0]['tick'],
            'original cancelled worker/revocation and return not observed')
    require(isinstance(witness, dict) and witness.get('commit') == expected and witness.get('run_id') == run_id
            and witness.get('request_id') == ids[1] and witness.get('received_after_cancel_ack') is True
            and integer(witness.get('sequence')) and clock(witness.get('tick')),
            'separate executor post-ACK fresh status witness required')
    matching = [r for r in rows if r['sequence'] == witness['sequence'] and r['tick'] == witness['tick']]
    require(matching and witness['tick'] >= R['returned_tick'] and rows[-1]['tick'] - witness['tick'] >= 35,
            'physical horizon must extend at least 35 ticks beyond post-ACK witness')
    tail = [r for r in rows if r['tick'] >= R['returned_tick']]
    post_ack = [r for r in rows if r['tick'] >= witness['tick']]
    require(post_ack[-1]['life_tick'] > post_ack[0]['life_tick'],
            'natural Life must progress during the post-ACK physical horizon')
    require(tail and tail[-1]['life_tick'] > tail[0]['life_tick'] and all(
        r['right_grass'] and not r['left_grass'] and r['cuttings'] == 2 and r['same_tool']
        and not r['worker'] and r['may_do_after'] and r['survival_actions'] == 0 for r in tail),
        'late effect/new worker/unbalanced callback or missing Life after cancellation')
    return {'fixture_oracles_valid': True, 'sampled_paid_interval_ticks': paid[-1]['tick'] - paid[0]['tick'],
            'post_ack_horizon_ticks': rows[-1]['tick'] - witness['tick'],
            'ui_native_assignment_and_os_cleanup': 'separate evidence required',
            'natural_acquisition': 'unsupported'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packet', type=Path)
    parser.add_argument('--expected-commit', required=True)
    parser.add_argument('--result', type=Path)
    parser.add_argument('--post-ack-witness', type=Path)
    parser.add_argument('--run-id')
    args = parser.parse_args()
    verify_packet(args.packet, args.expected_commit)
    report = {'source_packet_valid': True, 'runtime': 'not_run'}
    if args.result:
        require(args.post_ack_witness is not None and args.run_id is not None, 'result requires run ID and external post-ACK witness')
        report = verify_result(read_json(args.result), args.expected_commit, args.run_id, read_json(args.post_ack_witness))
    print(json.dumps(report))


if __name__ == '__main__':
    main()
