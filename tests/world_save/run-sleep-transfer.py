"""Stage or run protected-sleep helpers with real buckling and native persistence."""
import argparse
import importlib.util
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('cross_level_runner', Path(__file__).with_name('run-cross-level.py'))
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)

HELPERS = (
    '/mob/living/human/proc/release_protected_sleep_buckle',
    '/mob/living/human/proc/enter_protected_sleep',
    '/mob/living/human/proc/complete_protected_wakeup',
)
BUCKLING = ('/obj/proc/buckle_mob', '/obj/proc/unbuckle_mob', '/obj/proc/post_buckle_mob')
CASES = ('normal', 'legacy-wake', 'unrelated-occupant', 'refused-unbuckle', 'busy',
         'busy-recheck', 'moved-origin', 'refused-move', 'invalid-return',
         'inventory-busy', 'inventory-move', 'inventory-rebuckle', 'legacy-save', 'disk')
MINIMUM_CHECKS = dict(zip(CASES, (14, 7, 10, 10, 10, 9, 7, 9, 7, 7, 7, 8, 11, 16)))
CONTROLS = {
    'old-bed': ('disk', 'FAIL: protected sleeper/bed export rejected: Cross-level object reference cannot be represented in per-level save files: /obj/structure/bed/sleep_fixture saved_z=1 native_z=2 turf_z=2 source_type=/mob/living/human/sleep_fixture source_field=buckled'),
    'persistence-gate': ('busy', 'FAIL: entry moved during persistence'),
    'other-occupant': ('unrelated-occupant', 'FAIL: stale sleep pointer unbuckled a different occupant'),
    'wake-actor': ('normal', 'FAIL: wake helper moved the wrong actor'),
    'move-rollback': ('refused-move', 'FAIL: failed relocation committed sleep protection'),
    'inventory-gate': ('inventory-busy', 'FAIL: inventory callback bypassed transfer revalidation'),
}


def mutate(source, control):
    if not control:
        return source
    if control == 'old-bed':
        body = BASE.extract_proc(source, HELPERS[0])
        source = BASE.replace_once(source, body, HELPERS[0] + '()\n\treturn TRUE\n', 'old-bed release control')
        return BASE.replace_once(source, 'inducedSSD || buckled || !return_turf || !sleep_turf || get_turf(src) != return_turf',
                                 'inducedSSD || !return_turf || !sleep_turf || get_turf(src) != return_turf', 'old-bed revalidation control')
    if control == 'persistence-gate':
        # Both pre-hook and post-hook gates are removed, only in this projection.
        before = 'persistence_save_in_progress || '
        if source.count(before) != 5:
            raise RuntimeError('Persistence control requires all five exact source gates')
        return source.replace(before, '')
    before, after = {
        'other-occupant': ('\tif (seat.buckled_mob != src)\n\t\treturn FALSE\n', ''),
        'wake-actor': ('\tforceMove(return_turf)\n', '\tsleep_decoy.forceMove(return_turf)\n'),
        'move-rollback': ('\tif (!sleep_turf || get_turf(src) != sleep_turf)\n', '\tif (FALSE)\n'),
        'inventory-gate': ('\tif (persistence_save_in_progress || inducedSSD || buckled || !return_turf || !sleep_turf || get_turf(src) != return_turf)\n', '\tif (FALSE)\n'),
    }[control]
    return BASE.replace_once(source, before, after, 'sleep mutation control')


def prepare(output, control=None, root=ROOT):
    receipt = BASE.prepare(output, root=root)
    output = Path(output)
    receipt.update(scope=__doc__, negative_control=control,
                   actual_client_timing_verified=False, full_gameplay_verified=False)
    for relative, target, paths in (
        ('code/game/mob/living/carbon/human/human_helpers.dm', 'sleep_helpers.dm', HELPERS),
        ('code/game/objects/buckling.dm', 'buckling.dm', BUCKLING),
        ('code/game/atoms_movable.dm', 'force_move.dm', ('/atom/movable/proc/forceMove',)),
    ):
        raw = (root / relative).read_bytes()
        projected = '\n'.join(BASE.extract_proc(raw.decode('utf-8-sig'), path) for path in paths)
        receipt['source_sha256'][relative] = BASE.sha(raw)
        receipt['source_projections'][target] = {'source': relative, 'procedures': paths,
                                                 'unmodified_sha256': BASE.sha(projected.encode())}
        if target == 'sleep_helpers.dm':
            projected = mutate(projected, control)
        (output / target).write_text(projected, encoding='utf-8')
    cross = (output / 'cross_level_probe.dm').read_text(encoding='utf-8')
    if cross.count('/world/New()\n') != 1:
        raise RuntimeError('Expected one cross-level startup adapter')
    (output / 'cross_level_probe.dm').write_text(cross[:cross.index('/world/New()\n')], encoding='utf-8')
    raw = (root / 'tests/world_save/sleep_transfer_probe.dm').read_bytes()
    receipt['source_sha256']['tests/world_save/sleep_transfer_probe.dm'] = BASE.sha(raw)
    (output / 'sleep_transfer_probe.dm').write_bytes(raw)
    environment = (output / 'probe.dme').read_text(encoding='utf-8')
    environment += '\n' + '\n'.join(f'#include "{name}"' for name in (
        'sleep_helpers.dm', 'buckling.dm', 'force_move.dm', 'sleep_transfer_probe.dm')) + '\n'
    (output / 'probe.dme').write_text(environment, encoding='utf-8')
    BASE.refresh_receipt(output, receipt)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare-only', action='store_true')
    mode.add_argument('--compile-only', action='store_true')
    mode.add_argument('--run-native', action='store_true', help='Requires maintainer approval; launches trusted DreamDaemon')
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--case', choices=CASES, action='append')
    parser.add_argument('--negative-control', choices=tuple(CONTROLS))
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin is required for native compilation/execution')
    if args.negative_control and args.case:
        parser.error('Each control selects its exact intended assertion')
    output = Path(tempfile.mkdtemp(prefix='civ13-sleep-transfer-'))
    receipt = prepare(output, args.negative_control)
    cases, expected = args.case or CASES, {}
    if args.negative_control:
        case, result = CONTROLS[args.negative_control]
        cases, expected = (case,), {case: result}
    minimum = MINIMUM_CHECKS.copy()
    if args.negative_control:
        minimum[cases[0]] = {'old-bed': 6, 'persistence-gate': 5, 'other-occupant': 7,
                             'wake-actor': 12, 'move-rollback': 5, 'inventory-gate': 5}[args.negative_control]
    receipt.update(cases=list(cases), expected_results=expected, minimum_checks=minimum)
    BASE.refresh_receipt(output, receipt)
    print(f'Retained evidence: {output}', flush=True)
    if not args.prepare_only:
        BASE.native(output, args.byond_bin, cases, receipt, expected, args.compile_only)


if __name__ == '__main__':
    main()
