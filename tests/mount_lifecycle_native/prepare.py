"""Prepare five exact-Git 516.1688 mount fixtures. No compiler/runtime CLI."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('mount_native_stager', ROOT / 'tests/human_subtile/run-npc.py')
stager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stager)

VARIANTS = {
    'none': (None, None),
    'omit-death': ('MOUNT_OMIT_DEATH', 'death.matching.state'),
    'omit-separation': ('MOUNT_OMIT_SEPARATION', 'separation.matching.state'),
    'omit-mount-destroy': ('MOUNT_OMIT_MOUNT_DESTROY', 'mount_qdel.matching.state'),
    'omit-rider-destroy': ('MOUNT_OMIT_RIDER_DESTROY', 'rider_qdel.matching.state'),
}
BLOCKS = {
    'code/game/mob/living/simple_animal/riding.dm': ('MOUNT_OMIT_DEATH',
        '\t\tif (rider.riding_mob == src)\n\t\t\trider.riding_mob = null\n'),
    'code/game/mob/living/simple_animal/simple_animal.dm': ('MOUNT_OMIT_MOUNT_DESTROY',
        '\tif (!QDELETED(rider) && rider.riding_mob == src)\n\t\trider.riding = FALSE\n\t\trider.riding_mob = null\n'),
    'code/game/mob/living/carbon/human/human.dm': ('MOUNT_OMIT_RIDER_DESTROY',
        '\tvar/mob/living/simple_animal/old_mount = riding_mob\n\triding = FALSE\n\triding_mob = null\n'
        '\tif (!QDELETED(old_mount) && old_mount.rider == src)\n\t\told_mount.ride = FALSE\n'
        '\t\told_mount.rider = null\n\t\told_mount.stop_automated_movement = FALSE\n\t\told_mount.update_icons()\n'),
}


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def cases():
    result = []
    for operation in ('death', 'separation', 'mount_qdel', 'rider_qdel'):
        result.extend(operation + '.' + state for state in ('matching', 'foreign', 'retiring', 'reassignment'))
        if operation == 'separation':
            result.append(operation + '.icon_reassignment')
        if operation in ('mount_qdel', 'rider_qdel'):
            result.append(operation + '.absent')
    return result


def labels():
    return ['startup.closed_port', 'startup.engine', 'startup.identity'] + [
        case + '.' + check for case in cases() for check in ('state', 'callbacks', 'ownership', 'cleanup')]


def validate_receipt(row, head, variant):
    require(variant in VARIANTS, 'Unknown variant')
    require(type(row) is dict and row.get('head') == head and row.get('variant') == variant,
            'Receipt source/variant mismatch')
    require((row.get('byond_version'), row.get('byond_build')) == (516, 1688) and row.get('port') == 0,
            'Wrong native engine or open application port')
    require('cleanup_error' in row and row['cleanup_error'] is None, 'Fixture-owned cleanup failed/missing')
    expected = labels()
    failure = VARIANTS[variant][1]
    if failure:
        expected = expected[:expected.index(failure) + 1]
    checks = row.get('checks')
    require(type(checks) is list and len(checks) == len(expected), 'Incomplete/unexpected assertion count')
    require([item.get('label') for item in checks] == expected, 'Wrong assertion order/identity')
    require(all(type(item.get('passed')) is int and item['passed'] in (0, 1) for item in checks),
            'Wrong assertion result type')
    require(all(item['passed'] == 1 for item in checks[:-1]), 'Failed before intended assertion')
    require(checks[-1]['passed'] == (0 if failure else 1) and row.get('error') == failure,
            'Wrong positive/control result')
    observations = row.get('observations')
    require(type(observations) is list and len(observations) <= 256, 'Observation bound/type')
    require(all(type(item) is dict and item.get('case') in cases() and
                type(item.get('phase')) is str and type(item.get('values')) is dict for item in observations),
            'Malformed observation')
    observed = {item['case'] for item in observations}
    expected_cases = {label.rsplit('.', 1)[0] for label in expected if not label.startswith('startup.')}
    require(observed == expected_cases, 'Missing/unexpected native case observations')
    for case in expected_cases:
        phases = [item for item in observations if item['case'] == case]
        operation, state = case.split('.')
        required = ('native_forceMove_return' if operation in ('death', 'separation') else
                    'native_mount_Destroy_entry' if operation == 'mount_qdel' else 'native_human_Destroy_entry')
        require(any(item['phase'] == required for item in phases), 'Missing native boundary: ' + case)
        if operation == 'rider_qdel' or (state == 'retiring' and operation in ('death', 'mount_qdel')):
            require(any(item['phase'] == 'native_teardown_forceMove_return' for item in phases),
                    'Missing actual human teardown forceMove: ' + case)
        if operation in ('mount_qdel', 'rider_qdel'):
            require(any(item['phase'] == 'native_destroyed_event' and item['values'].get('modern') == -2
                        for item in phases), 'Missing in-progress actual destroyed event: ' + case)
    return dict(head=head, variant=variant, expected_failure=failure, assertions=len(expected),
                scope='Native source fixture only; no client/visual/save acceptance')


def select_separation(text):
    anchor = '\tif (riding && riding_mob)\n'
    require(text.count(anchor) == 1, 'Separation selector anchor drift')
    lines = text[text.index(anchor):].splitlines(keepends=True)
    selected = [lines[0]]
    for line in lines[1:]:
        if line.strip() and not line.startswith('\t\t'):
            break
        selected.append(line)
    body = ''.join(selected).rstrip() + '\n'
    release = ('\t\t\tif (!QDELETED(old_mount) && old_mount.rider == src && riding_mob != old_mount)\n'
        '\t\t\t\told_mount.ride = FALSE\n\t\t\t\told_mount.rider = null\n'
        '\t\t\t\told_mount.update_icons()\n'
        '\t\t\t\tif (!QDELETED(old_mount) && !old_mount.ride && isnull(old_mount.rider) && riding_mob != old_mount)\n'
        '\t\t\t\t\told_mount.stop_automated_movement = FALSE\n')
    require(body.count(release) == 1, 'Separation release source drift')
    wrapped = wrap(body, release, 'MOUNT_OMIT_SEPARATION')
    return '/mob/living/human/proc/mount_native_separation()\n' + wrapped, body


def wrap(text, block, macro):
    require(text.count(block) == 1, 'Control anchor drift: ' + macro)
    return text.replace(block, '#ifndef ' + macro + '\n' + block + '#endif\n', 1)


def prepare(root, out, expected_head):
    require(re.fullmatch(r'[0-9a-f]{40}', expected_head), 'Expected immutable source commit')
    require(stager.current.legacy.git(root, 'rev-parse', 'HEAD').decode().strip() == expected_head,
            'Source head differs from reviewed request')
    require(not stager.current.legacy.git(root, 'status', '--porcelain').strip(), 'Source must be committed/clean')
    # Existing exact-Git, bounded tar, startup isolation and path-census policy.
    manifest = stager.prepare_source(root, out)
    require(manifest['head'] == expected_head, 'Source changed while staging')
    stage = out / 'stage'
    pin_raw = stager.current.legacy.git(root, 'show', expected_head + ':tools/byond/version.json')
    pin = json.loads(pin_raw)
    require(pin['version'] == '516.1688', 'Review the fixture after any canonical pin advance')
    adaptations = {}

    def replace(relative, transform):
        path = stage / relative
        before = path.read_bytes()
        after = transform(before.decode('utf-8')).encode('utf-8')
        path.write_bytes(after)
        adaptations[relative] = dict(before_sha256=digest(before), after_sha256=digest(after))

    def remove_old_entry(text):
        anchor = '/world/New()'
        require(text.count(anchor) == 1, 'Existing probe entry drift')
        return text.replace(anchor, '/world/proc/unused_mount_native_probe_entry()', 1)

    replace('tests/human_subtile/probe.dm', remove_old_entry)
    for relative, (macro, block) in BLOCKS.items():
        replace(relative, lambda text, b=block, m=macro: wrap(text, b, m))
    source_relative = 'code/game/mob/living/carbon/human/human_life.dm'
    source = (stage / source_relative).read_bytes()
    selector, selected = select_separation(source.decode('utf-8'))
    directory = stage / 'tests/mount_lifecycle_native'
    directory.mkdir()
    (directory / 'selected_separation.dm').write_text(selector, encoding='utf-8', newline='\n')
    fixture_relative = 'tests/mount_lifecycle_native/probe.dm'
    raw = stager.current.legacy.git(root, 'show', expected_head + ':' + fixture_relative)
    (stage / fixture_relative).write_bytes(raw)
    # One immutable asset/source stage; five small DME entrypoints, no duplicate
    # full-source trees and no source mutation between native variants.
    common = (out / manifest['dme']).read_text(encoding='utf-8')
    common += '\n#include "tests\\mount_lifecycle_native\\selected_separation.dm"\n'
    common += '#include "tests\\mount_lifecycle_native\\probe.dm"\n'
    variants = {}
    for variant, (macro, failure) in VARIANTS.items():
        entry = stage / ('human_subtile.dme' if variant == 'none' else
                         'mount_native_' + variant.replace('-', '_') + '.dme')
        defines = '#define MOUNT_NATIVE_HEAD "' + expected_head + '"\n'
        defines += '#define MOUNT_NATIVE_VARIANT "' + variant + '"\n'
        if macro:
            defines += '#define ' + macro + '\n'
        entry.write_text(defines + common, encoding='utf-8', newline='\n')
        variants[variant] = dict(dme=entry.relative_to(out).as_posix(), expected_failure=failure,
            expected_assertions=len(labels()) if not failure else labels().index(failure)+1,
            sha256=digest(entry.read_bytes()))
    manifest.update(fixture='mount_lifecycle', target_engine='516.1688', variants=variants,
        canonical_pin=dict(path='tools/byond/version.json', sha256=digest(pin_raw), data=pin),
        fixture_adaptations=adaptations, prepared_only=True, native_executed=False,
        selector=dict(source=source_relative, source_sha256=digest(source), selected_sha256=digest(selected.encode()),
                      generated_sha256=digest(selector.encode()), scope='Exact separation branch;not full human Life'),
        cases=cases(), positive_assertions=len(labels()),
        execution_admitted=False, publication_admitted=False,
        bounds=dict(map=[8, 8, 1], primary_mobs_per_case=4, cases=19, observations=256,
                    compile_seconds_per_variant=120, runtime_seconds_per_variant=30,
                    cleanup_seconds_per_variant=15, aggregate_seconds=900))
    manifest['stage_files'] = {p.relative_to(stage).as_posix(): dict(bytes=p.stat().st_size,
        sha256=stager.file_digest(p)) for p in stage.rglob('*') if p.is_file()}
    (out / 'mount-native-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path, help='New private output directory')
    parser.add_argument('--source-commit', required=True)
    args = parser.parse_args()
    result = prepare(ROOT, args.output.resolve(), args.source_commit)
    print(json.dumps({k:result[k] for k in ('head', 'target_engine', 'cases', 'positive_assertions', 'execution_admitted')}))
