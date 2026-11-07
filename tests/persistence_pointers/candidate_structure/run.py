"""Native fixture for the stream-save candidate check, staged from the production saver.

Reuses the world_save cross-level packet (production functions/saving/loading,
graph and adapted stubs) and replaces only its probe. A pin the collector
force-deleted after capture must pass; an area entry must still be refused.
--prepare-only and --compile-only never launch DreamDaemon; --run-native
launches the isolated trusted daemon with no network port and a private save
directory per case.
"""
import argparse
import importlib.util
from pathlib import Path
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
_spec = importlib.util.spec_from_file_location('candidate_structure_cross_runner', ROOT / 'tests/world_save/run-cross-level.py')
CROSS = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(CROSS)

CASES = ('live', 'deleted', 'area')
PROBE = ('probe.dme', 'candidate_structure_probe.dm')
# The control restores the strict null check and must reach its assertion.
CONTROLS = {
    'null-pin': ('saving.dm', '\t\tif(isnull(A))\n', '\t\tif(FALSE)\n', 'deleted', 2,
                 {'pattern': r'FAIL: an entry deleted after capture was rejected: Unsupported saved entry 3 on z=1'}),
}


def prepare(output, control=None, root=ROOT):
    output = Path(output)
    receipt = CROSS.prepare(output, None, root)
    receipt['scope'] = __doc__
    receipt['negative_control'] = control
    if control:
        name, before, after = CONTROLS[control][:3]
        staged = output / name
        staged.write_text(CROSS.replace_once(staged.read_text(encoding='utf-8'), before, after, 'negative control'), encoding='utf-8')
    (output / 'cross_level_probe.dm').unlink()
    for name in PROBE:
        raw = (HERE / name).read_bytes()
        receipt['source_sha256']['tests/persistence_pointers/candidate_structure/' + name] = CROSS.sha(raw)
        (output / name).write_bytes(raw)
    receipt['source_sha256'].pop('tests/world_save/cross_level_probe.dm', None)
    receipt['source_sha256'].pop('tests/world_save/cross_level.dme', None)
    CROSS.refresh_receipt(output, receipt)
    return receipt


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare-only', action='store_true')
    mode.add_argument('--compile-only', action='store_true')
    mode.add_argument('--run-native', action='store_true', help='Launches the isolated trusted DreamDaemon')
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--byond-archive', type=Path)
    parser.add_argument('--case', choices=CASES, action='append')
    parser.add_argument('--negative-control', choices=tuple(CONTROLS))
    args = parser.parse_args(argv)
    if args.negative_control and args.case:
        parser.error('Mutation controls select one exact case')
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin is required for native compilation/execution')
    runtime = CROSS.selected_runtime(args.byond_bin, args.byond_archive)
    output = Path(tempfile.mkdtemp(prefix='civ13-candidate-structure-'))
    receipt = prepare(output, args.negative_control)
    cases = tuple(args.case or CASES)
    expected = {}
    if args.negative_control:
        _, _, _, case, minimum, result = CONTROLS[args.negative_control]
        cases, expected = (case,), {case: result}
        receipt['minimum_checks'] = {case: minimum}
    receipt.update(cases=list(cases), expected_results=expected, characterization_only=False)
    CROSS.refresh_receipt(output, receipt)
    print(f'Retained evidence: {output}', flush=True)
    if not args.prepare_only:
        if runtime: CROSS.native(output, args.byond_bin, cases, receipt, expected, args.compile_only, runtime=runtime)
        else: CROSS.native(output, args.byond_bin, cases, receipt, expected, args.compile_only)
    return 0


if __name__ == '__main__':
    sys.exit(main())
