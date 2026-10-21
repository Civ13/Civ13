"""Prepare production-bound offline fixtures; never invokes BYOND or a host."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MODULE = 'code/modules/multiz/world_z_budget.dm'
CONTROLS = {
    'memory-admission': ('return "UNMEASURED: new levels are disabled until this map has a validated memory/headroom profile. Existing planes remain usable. Preserve saves and request a reviewed profile; no level was allocated."',
                         'return null', 'default unmeasured allocation preserves grid'),
    'cell-limit': ('if (exceeds_budget)',
                   'if (FALSE)', 'one-over total-cell ceiling blocked'),
    'roof-ceiling': ('#define NEW_Z_ROOF_CEILING 1',
                     '#define NEW_Z_ROOF_CEILING 8', 'raising roof allowance rejected'),
}


def unique_replace(text, old, new):
    if text.count(old) != 1:
        raise AssertionError(f'Production binding changed: {old!r}')
    return text.replace(old, new, 1)


def omit_headless_interface(source):
    # This server-only fixture makes no client/UI/rendering claim. Native DM
    # reports an absolute external DMF as "invalid file" despite a zero summary.
    return unique_replace(source, '#include "interface\\skin.dmf"', '')


def contracts():
    allocator = (ROOT / 'code/game/objects/building_levels.dm').read_text(encoding='utf-8')
    claim = allocator.index('world_z_budget.claim_level(reservation, target_z)')
    resize = allocator.index('world.maxz = target_z')
    assert claim < resize
    assert not re.search(r'\b(?:sleep|input|TICK_CHECK)\b', allocator[claim:resize])
    restore = (ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
    reserve = restore.index('dimension_reservation = world_z_budget.reserve(target_z, "restore")')
    validate = restore.index('var/valid = validate_world_save()', reserve)
    first = restore.index('for(var/z = world.maxz + 1', validate)
    assert reserve < validate < first
    admin = (ROOT / 'code/modules/admin/topic.dm').read_text(encoding='utf-8')
    branch = admin.index('else if (href_list["modify_world_var"])')
    assert admin.index('if (new_z_dimension_variable(somevar))', branch) < admin.index('if (world.vars.Find(somevar))', branch)
    builder = (ROOT / 'code/game/objects/roof_stuff.dm').read_text(encoding='utf-8')
    branch = builder.index('/obj/item/weapon/roofbuilder/attack_self')
    assert builder.index('building_construct_roof(', branch) < builder.index('qdel(src)', branch)
    config = (ROOT / 'code/datums/configuration.dm').read_text(encoding='utf-8')
    assert 'if (world_z_budget.configure(name, value))' in config
    assert 'fixture_admission' not in (ROOT / 'civ13.dme').read_text(encoding='utf-8')
    assert not any('fixture_admission' in p.read_text(encoding='utf-8', errors='replace') for p in (ROOT / 'code').rglob('*.dm'))
    assert 'return memory_admission_error(target_z, purpose)' in (ROOT / MODULE).read_text(encoding='utf-8')
    probe = (ROOT / 'tests/new_z_budget/probe.dm').read_text(encoding='utf-8')
    module = (ROOT / MODULE).read_text(encoding='utf-8')
    for old, new, assertion in CONTROLS.values():
        unique_replace(module, old, new)
        assert f'"{assertion}"' in probe
    return {'allocator_claim_before_resize': True, 'whole_restore_reservation_before_validation': True,
            'admin_guard_before_raw_writes': True, 'roof_debit_after_success': True,
            'production_config_parser_bound': True, 'production_memory_default_unmeasured': True,
            'fixture_adapter_absent_from_production': True, 'unique_mutations': list(CONTROLS)}


def prepare(output, control):
    output.mkdir(parents=True, exist_ok=False)
    world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
    start = world.index('/world/New()')
    parent = world.index('\n\t..()', start)
    world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
    world = unique_replace(world, '/world/New()', '/world/proc/unused_new_z_budget_startup()')
    world = unique_replace(world, '/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n')
    globals_source = (ROOT / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
    globals_source = unique_replace(globals_source, '/datum/controller/global_vars/New()\n',
                                    '/datum/controller/global_vars/New()\n\treturn\n')
    module = (ROOT / MODULE).read_text(encoding='utf-8')
    if control:
        old, new, _ = CONTROLS[control]
        module = unique_replace(module, old, new)
    generated = {'world.dm': world, 'globals.dm': globals_source, 'world_z_budget.dm': module}
    for name, text in generated.items():
        (output / name).write_text(text, encoding='utf-8', newline='\n')
    replacements = {'code/world.dm': output / 'world.dm',
                    'code/controllers/mc/globals.dm': output / 'globals.dm', MODULE: output / 'world_z_budget.dm'}
    source = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
    source = omit_headless_interface(source)
    source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
    source = unique_replace(source, '#define FILE_DIR .', f'#define FILE_DIR "{ROOT.as_posix()}"')
    def include(match):
        relative = match[1].replace('\\', '/')
        target = replacements.get(relative, ROOT / relative).resolve(strict=True)
        return f'#include "{target.as_posix()}"'
    source = re.sub(r'^#include "([^"]+)"', include, source, flags=re.M)
    source += f'\n#include "{(ROOT / "tests/new_z_budget/fixture_admission.dm").as_posix()}"\n'
    source += f'#include "{(ROOT / "tests/new_z_budget/probe.dm").as_posix()}"\n'
    (output / 'probe.dme').write_text(source, encoding='utf-8', newline='\n')
    paths = ['civ13.dme', MODULE, 'code/game/objects/building_levels.dm',
             'code/modules/persistence/functions.dm', 'code/modules/admin/topic.dm',
             'code/datums/configuration.dm', 'code/game/objects/roof_stuff.dm',
             'tests/new_z_budget/probe.dm', 'tests/new_z_budget/prepare.py',
             'tests/new_z_budget/fixture_admission.dm', 'code/world.dm', 'code/controllers/mc/globals.dm']
    receipt = {'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               'prepared_only': True, 'native_executed': False, 'control': control,
               'source_root': ROOT.as_posix(), 'fixture_admission': 'isolated test subclass, not calibrated',
               'interface': 'skin.dmf explicitly omitted from headless fixture', 'ui_rendering_verified': False,
               'expected_control_failure': CONTROLS[control][2] if control else None,
               'contracts': contracts(),
               'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
               'generated_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir()}}
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--output', type=Path, required=True, help='New retained preparation directory')
    parser.add_argument('--control', choices=CONTROLS)
    args = parser.parse_args()
    prepare(args.output.resolve(), args.control)
    print('PASS: source contracts and fixture preparation only; compiler/runtime untested')


if __name__ == '__main__':
    main()
