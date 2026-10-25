"""Exact-checkout preparation by default; explicit reviewed Linux native execution."""
import argparse
import json
from pathlib import Path
from prepare import prepare, dump, bounded_file, HEAD, TREE
from plan import proposed_plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--inventory', type=Path, default=Path(__file__).with_name('source-manifest.json'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reviewed-native', action='store_true')
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--byond-archive', type=Path)
    args = parser.parse_args()
    if args.reviewed_native and (args.byond_bin is None or args.byond_archive is None):
        parser.error('Explicit native invocation requires both verified toolchain paths')
    source = args.source.absolute()
    output = args.output.absolute()
    if output.exists() or any(p.is_symlink() for p in output.parents):
        raise ValueError('Fresh unlinked output required')
    if output == source or source in output.parents or output in source.parents:
        raise ValueError('Evidence must be separate from source checkout')
    output.mkdir(parents=True)
    summary = {'status': 'preparing', 'head': HEAD, 'tree': TREE,
               'native_executed': False, 'compiler_attempted': False,
               'compiler_started': False, 'compiler_completed': False,
               'daemon_attempted': False, 'daemon_started': False, 'daemon_completed': False}
    dump(output / 'result.json', summary)
    try:
        receipt = prepare(source, output / 'prepared', args.inventory.absolute())
        dump(output / 'prepared/phase-plan.json', proposed_plan(receipt['candidate_manifest_sha256']))
        summary['candidate_manifest_sha256'] = receipt['candidate_manifest_sha256']
        summary['status'] = 'prepared-only'
        if args.reviewed_native:
            from backend_proposal import run_native
            run_native(source, args.inventory.absolute(), output / 'prepared', output / 'runs',
                       args.byond_bin.absolute(), args.byond_archive.absolute(), reviewed_native=True)
            summary = json.loads(bounded_file(output / 'runs/result.json', 4 * 1024**2))
            if summary['status'] != 'completed':
                raise ValueError('Native phase inventory did not complete')
            summary['status'] = 'passed'
        dump(output / 'result.json', summary)
        print('PASS: ' + summary['status'] + '; native_executed=' + str(summary['native_executed']))
    except BaseException as error:
        if (output / 'runs/result.json').exists():
            summary = json.loads(bounded_file(output / 'runs/result.json', 4 * 1024**2))
        summary['status'] = 'failed'
        summary['error'] = str(error)
        dump(output / 'result.json', summary)
        raise


if __name__ == '__main__':
    main()
