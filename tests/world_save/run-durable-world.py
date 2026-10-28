"""Run production world/metadata persistence on a tiny isolated native world."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "new_z_budget"))
from z_budget_evidence import DIAGNOSTIC, validate_compile


def selected_runtime(bin_dir, archive):
    if archive is None: return None  # Frozen historical fixtures keep 1681.
    spec = importlib.util.spec_from_file_location('lighting_current_runtime', Path(__file__).with_name('current_runtime.py'))
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module.select(bin_dir, archive)


def current_ci_case(args):
    if args.prepare_only or args.zone_topology or args.roof_areas or args.roof_control or args.persistence_year:
        return False
    if args.lighting: return True  # Preserve the already reviewed current lighting path.
    mode = next((name for name in ('wounds', 'dimension_bootstrap', 'recovery_reconnect',
                                  'lifecycle_shutdown', 'startup_only') if getattr(args, name)), 'roundtrip')
    cases = {(profile, name, None) for profile in ('gaia', 'europe')
             for name in ('roundtrip', 'dimension_bootstrap', 'recovery_reconnect', 'lifecycle_shutdown')}
    cases.update({('gaia', 'wounds', None), ('gaia', 'wounds', 'wound-restore'),
                  ('gaia', 'startup_only', None), ('gaia', 'recovery_reconnect', 'reclaim-order'),
                  ('europe', 'lifecycle_shutdown', 'shutdown-return')})
    cases.update(('gaia', 'roundtrip', control) for control in
                 ('season', 'preflight', 'reachability', 'callback', 'timer-restore'))
    return (args.profile, mode, args.negative_control) in cases


def historical_wound_roof_helpers(loading, existing):
    """Keep the historical defect sources intact; add explicit current dependencies."""
    start = ('// Only roof transformations backed by direct saved turf contents are projected.\n'
             '// No save bytes or world areas change during this preflight.\n/map_storage\n')
    end = '\n/map_storage/proc/Load_Entry('
    if not loading.startswith(start) or loading.count(start) != 1 or loading.count(end) != 1:
        raise RuntimeError('Historical wound roof compatibility anchors changed')
    roof = loading[:loading.index(end)]
    procedures = ('clear_saved_roof_areas', 'saved_roof_area_type', 'find_saved_roof_area',
                  'unique_saved_roof_area', 'prepare_saved_roof_areas',
                  'materialize_saved_roof_areas', 'restore_validated_roof',
                  'is_loaded_validated_roof', 'verify_restored_roof_areas')
    members = ('validated_roof_areas', 'validated_roof_entries', 'validated_roof_types',
               'validated_roof_instances', 'validated_roof_absent', 'restoring_roof_areas')
    if re.findall(r'^/map_storage/proc/(\w+)\(', roof, re.M) != list(procedures):
        raise RuntimeError('Historical wound roof compatibility procedures changed')
    declarations = roof.split('\n/map_storage/proc/', 1)[0]
    if re.findall(r'^\tvar/(?:list/)?(\w+) = ', declarations, re.M) != list(members):
        raise RuntimeError('Historical wound roof compatibility members changed')
    patterns = [r'^/map_storage/proc/' + name + r'\(' for name in procedures]
    patterns += [r'^\tvar/(?:list/)?' + name + r'\b' for name in members]
    if any(re.search(pattern, existing, re.M) for pattern in patterns):
        raise RuntimeError('Historical wound roof compatibility dependencies duplicated')
    return roof


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--byond-archive', type=Path, help='Exact current Linux identity for the selected persistence CI matrix')
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--zone-topology', action='store_true',
                        help='Prepare synthetic zone/spawn positive and negative fixtures; native execution is held')
    parser.add_argument('--roof-areas', action='store_true',
                        help='Prepare only the synthetic fresh-process roof-area fixture; native execution is held')
    parser.add_argument('--roof-control', choices=('projection', 'cleanup-namespace'),
                        help='Prepare a named immutable roof-source omission control; no native execution')
    parser.add_argument('--persistence-year', action='store_true',
                        help='Run native minimum-date activation and v1/v2 disk import checks')
    parser.add_argument('--lighting', action='store_true',
                        help='Run real lighting constructors and legacy runtime graph recovery')
    parser.add_argument('--wounds', action='store_true',
                        help='Run production lost-limb wound disk recovery and constructor checks')
    parser.add_argument('--dimension-bootstrap', action='store_true',
                        help='Run fresh expanded round-v2 writer and compiled-size reader processes')
    parser.add_argument('--recovery-reconnect', action='store_true',
                        help='Run production recovery and waiting-client reclaim with client IO adapted')
    parser.add_argument('--lifecycle-shutdown', action='store_true',
                        help='Run real Topic dispatch, production disk save and native graceful shutdown')
    parser.add_argument('--startup-only', action='store_true',
                        help='Diagnose production initialization without running any persistence assertions')
    parser.add_argument('--profile', choices=('gaia', 'europe'), default='gaia')
    parser.add_argument('--negative-control', choices=('season', 'preflight', 'reachability', 'callback', 'timer-restore', 'reclaim-order', 'lighting-export', 'lighting-legacy', 'lighting-rebuild', 'lighting-opacity', 'lighting-view', 'lighting-eager', 'lighting-shared', 'shutdown-return', 'wound-restore', 'year-helper', 'year-load', 'year-order'))
    args = parser.parse_args()
    if args.zone_topology:
        if not args.prepare_only:
            parser.error('zone native execution remains held; use --prepare-only')
        if any((args.roof_areas, args.roof_control, args.persistence_year, args.wounds,
                args.lighting, args.dimension_bootstrap, args.recovery_reconnect,
                args.lifecycle_shutdown, args.startup_only, args.negative_control)):
            parser.error('Zone preparation cannot combine with other fixture modes')
    if args.roof_control and not args.roof_areas:
        parser.error('Roof controls require --roof-areas')
    if args.roof_areas:
        if not args.prepare_only:
            parser.error('Roof-area native execution requires a separately reviewed bounded runner/admission')
        if any((args.persistence_year, args.wounds, args.lighting, args.dimension_bootstrap,
                args.recovery_reconnect, args.lifecycle_shutdown, args.startup_only, args.negative_control)):
            parser.error('Roof-area preparation cannot combine with other fixture modes')
    year_control = bool(args.negative_control and args.negative_control.startswith('year-'))
    if args.persistence_year and (args.wounds or args.lighting or args.dimension_bootstrap or args.recovery_reconnect or args.lifecycle_shutdown or args.startup_only or (args.negative_control and not year_control)):
        parser.error('Persistence date acceptance runs separately from other fixture modes')
    if year_control and not args.persistence_year:
        parser.error('Date controls require --persistence-year')
    if args.wounds and (args.lighting or args.dimension_bootstrap or args.recovery_reconnect or args.lifecycle_shutdown or args.startup_only or args.negative_control not in (None, 'wound-restore')):
        parser.error('Wound recovery runs separately from other fixture modes')
    if args.negative_control == 'wound-restore' and not args.wounds:
        parser.error('Wound control requires --wounds')
    lighting_control = bool(args.negative_control and args.negative_control.startswith('lighting-'))
    if args.lighting and (args.dimension_bootstrap or args.recovery_reconnect or args.lifecycle_shutdown or args.startup_only or (args.negative_control and not lighting_control)):
        parser.error('Lighting recovery runs separately from other fixture modes')
    if lighting_control and not args.lighting:
        parser.error('Lighting controls require --lighting')
    if args.lifecycle_shutdown and (args.recovery_reconnect or args.dimension_bootstrap or args.startup_only or args.negative_control not in (None, 'shutdown-return')):
        parser.error('Lifecycle shutdown runs separately from other fixture modes')
    if args.negative_control == 'shutdown-return' and not args.lifecycle_shutdown:
        parser.error('Shutdown return control requires --lifecycle-shutdown')
    if args.recovery_reconnect and (args.dimension_bootstrap or args.startup_only or args.negative_control not in (None, 'reclaim-order')):
        parser.error('Recovery reconnect checks run separately from other fixture modes')
    if args.negative_control == 'reclaim-order' and not args.recovery_reconnect:
        parser.error('Reclaim ordering control requires --recovery-reconnect')
    if args.dimension_bootstrap and (args.startup_only or args.negative_control):
        parser.error('Expanded fresh-process checks run separately from existing mutation/startup cases')
    if args.startup_only and args.negative_control:
        parser.error('Startup diagnostics cannot run persistence mutation controls')
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin is required for native execution')
    if args.byond_archive and not current_ci_case(args):
        parser.error('--byond-archive admits only the selected persistence CI matrix')
    root = Path(__file__).resolve().parents[2]
    runtime = selected_runtime(args.byond_bin, args.byond_archive)
    output = Path(tempfile.mkdtemp(prefix='civ13-durable-world-'))
    prefix = '.durable_world_' + uuid.uuid4().hex
    dme = root / (prefix + '.dme')
    generated = []
    receipt = {'zone_topology': args.zone_topology, 'roof_areas': args.roof_areas, 'roof_control': args.roof_control, 'persistence_year': args.persistence_year, 'profile': args.profile, 'negative_control': args.negative_control,
               'wounds': args.wounds,
               'lighting': args.lighting,
               'dimension_bootstrap': args.dimension_bootstrap, 'recovery_reconnect': args.recovery_reconnect,
               'lifecycle_shutdown': args.lifecycle_shutdown,
               'prepared_only': args.prepare_only, 'startup_only': args.startup_only,
               'production_hashes': {}}
    print(f'Retained evidence: {output}', flush=True)
    try:
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        replacements = {}
        for relative in ('code/world.dm', 'code/controllers/mc/globals.dm'):
            text = (root / relative).read_text(encoding='utf-8')
            if relative == 'code/world.dm':
                start = text.index('/world/New()')
                parent = text.index('\n\t..()', start)
                text = text[:parent] + text[parent:].replace('\n\t..()', '', 1)
                text = text.replace('/world/New()', '/world/proc/unused_durable_startup()', 1)
                marker = '/datum/global_init/New()\n'
            else:
                marker = '/datum/controller/global_vars/New()\n'
            if text.count(marker) != 1:
                raise RuntimeError('Startup isolation anchor changed')
            replacements[relative] = text.replace(marker, marker + '\treturn\n', 1)
        mutations = {
            'season': ('code/modules/persistence/durable_world.dm', '\tseason = E["season"]', '\tseason = "SPRING"'),
            'preflight': ('code/modules/persistence/durable_world.dm', '\tvar/list/fields = state["fields"]', '\tif(islist(state["fields"])) return TRUE\n\tvar/list/fields = state["fields"]'),
            'reachability': ('code/modules/persistence/durable_world.dm', '\tvalidate_durable_reachability(G)', '\tif(FALSE) validate_durable_reachability(G)'),
            'callback': ('code/modules/persistence/durable_timers.dm', '\t\tif(!owner || revision != expected_revision || pending[key] != row) return', '\t\tif(!owner) return'),
            'timer-restore': ('code/modules/persistence/durable_world.dm', '\tmap.durable_timer_queue().restore(timers)', '\t// Negative control: omit restoring persisted callbacks.'),
            'reclaim-order': ('code/modules/persistence/restart_transaction.dm', '\t\tplayers_ready = map_storage.finish_player_restoration()\n', ''),
            'lighting-export': ('code/modules/persistence/functions.dm', 'if ("appearance", "light", "light_sources")', 'if ("appearance")'),
            'lighting-legacy': ('code/modules/persistence/loading.dm', 'if(ispath(type, /datum/light_source) || ispath(type, /datum/lighting_corner) || ispath(type, /atom/movable/lighting_overlay))', 'if(FALSE)'),
            'lighting-rebuild': ('code/modules/persistence/loading.dm', '\t\t\t\tlight_owner.update_light()', '\t\t\t\tif(FALSE) light_owner.update_light()'),
            'lighting-opacity': ('code/modules/persistence/loading.dm', '\t\t\t\tlight_turf.recalc_atom_opacity()', '\t\t\t\tif(FALSE) light_turf.recalc_atom_opacity()'),
            'lighting-view': ('code/modules/persistence/functions.dm', '!istype(mob, /mob/new_player) && mob != dview_mob', '!istype(mob, /mob/new_player)'),
            'shutdown-return': ('code/modules/persistence/restart_transaction.dm', '\tdel(world)\n\t// Native deletion can return until the current execution yields. Give BYOND\n\t// that boundary before failure cleanup can consume the valid restart intent.\n\tsleep(1)\n', '\tdel(world)\n'),
        }
        if args.roof_control:
            relative = 'code/modules/persistence/loading.dm'
            text = (root / relative).read_text(encoding='utf-8')
            if args.roof_control == 'projection':
                before = '\t\tprepare_saved_roof_areas(round_state["generation"])\n'
                if text.count(before) != 1:
                    raise RuntimeError('Roof projection control anchor changed')
                text = text.replace(before, '\t\t// Old-defect control: validate against startup areas only.\n', 1)
            else:
                start = text.index('/map_storage/proc/is_loaded_validated_roof(')
                end = text.index('/map_storage/proc/verify_restored_roof_areas()', start)
                old_predicate = ('/map_storage/proc/is_loaded_validated_roof(atom/roof)\n'
                    '\tif(!restoring_roof_areas) return FALSE\n'
                    '\tvar/list/row = validated_roof_areas["[roof.x],[roof.y],[roof.z]"]\n'
                    '\treturn row && existing_references[row["entry"]] == roof\n\n')
                text = text[:start] + old_predicate + text[end:]
            replacements[relative] = text
        elif year_control:
            relative = 'code/modules/persistence/functions.dm'
            text = (root / relative).read_text(encoding='utf-8')
            before, after = {
                'year-helper': ('if (!persistence)\n', 'if (TRUE)\n'),
                'year-load': ('\t\tmap.apply_persistence_age_floor()\n', ''),
                'year-order': ('\t\tmap_storage.restore_durable_world()\n', '\t\tmap.apply_persistence_age_floor()\n\t\tmap_storage.restore_durable_world()\n'),
            }[args.negative_control]
            if text.count(before) != 1:
                raise RuntimeError('Date control anchor changed')
            if args.negative_control == 'year-order':
                text = text.replace('\t\tmap.apply_persistence_age_floor()\n', '', 1)
            replacements[relative] = text.replace(before, after, 1)
        elif args.negative_control == 'wound-restore':
            # Immutable source of the actual failed import, not an invented null model.
            baseline = 'd0ffbfb2335eb735756b998f3f2ff617c28f144b'
            for relative in ('code/modules/organs/wound.dm', 'code/modules/persistence/loading.dm'):
                replacements[relative] = subprocess.check_output(
                    ['git', 'show', baseline + ':' + relative], cwd=root, text=True)
            receipt['wound_control_commit'] = baseline
            # Historical defect control with explicit current dependencies,
            # not a reproduction of an entire historical game build. Keep both
            # historical files byte-for-byte; supply the current roof API and
            # content codec only in the fixture's functions copy.
            loading = (root / 'code/modules/persistence/loading.dm').read_text(encoding='utf-8')
            marker = '/map_storage/proc/saved_content_refs(value, version)\n'
            if loading.count(marker) != 1:
                raise RuntimeError('Historical wound compatibility helper anchor changed')
            start = loading.index(marker)
            end = loading.find('\n/map_storage/proc/', start + len(marker))
            helper = loading[start:end if end >= 0 else len(loading)]
            relative = 'code/modules/persistence/functions.dm'
            functions = (root / relative).read_text(encoding='utf-8')
            existing = '\n'.join([functions, *replacements.values()])
            if marker in existing:
                raise RuntimeError('Historical wound content compatibility helper duplicated')
            roof = historical_wound_roof_helpers(loading, existing)
            replacements[relative] = functions + '\n' + roof + '\n' + helper
            receipt['wound_control_compatibility_helper_sha256'] = hashlib.sha256(helper.encode()).hexdigest()
            receipt['wound_control_roof_helpers_sha256'] = hashlib.sha256(roof.encode()).hexdigest()
        elif args.negative_control == 'lighting-shared':
            relative = 'code/modules/lighting/lighting_source.dm'
            text = (root / relative).read_text(encoding='utf-8')
            if text.count('C.affecting = list()') != 2:
                raise RuntimeError('Shared-list control must cover both insertion paths')
            replacements[relative] = text.replace('C.affecting = list()', 'C.affecting = lighting_probe_shared_affecting')
        elif args.negative_control == 'lighting-eager':
            relative = 'code/modules/lighting/lighting_corner.dm'
            text = (root / relative).read_text(encoding='utf-8')
            before = 'var/list/datum/light_source/affecting //'
            if text.count(before) != 1:
                raise RuntimeError('Eager-list control anchor changed')
            replacements[relative] = text.replace(before, 'var/list/datum/light_source/affecting = list() //', 1)
        elif args.negative_control:
            relative, before, after = mutations[args.negative_control]
            text = (root / relative).read_text(encoding='utf-8')
            if text.count(before) != 1:
                raise RuntimeError('Negative-control anchor changed')
            replacements[relative] = text.replace(before, after, 1)
            if args.negative_control == 'reclaim-order':
                # Reproduce the observed old ordering: the one readiness sweep
                # occurs while the startup hold still rejects saved claims.
                anchor = '\t\tconsume(I)\n'
                if replacements[relative].count(anchor) != 1:
                    raise RuntimeError('Reclaim ordering mutation anchor changed')
                replacements[relative] = replacements[relative].replace(anchor, '\t\tmap_storage.finish_player_restoration()\n' + anchor, 1)
        if args.recovery_reconnect:
            relative = 'code/modules/persistence/player_reclaim.dm'
            text = (root / relative).read_text(encoding='utf-8')
            start = text.index('/map_storage/proc/reclaim_saved_player(')
            end = text.index('/map_storage/proc/validate_saved_player_owner(', start)
            body = text[start:end]
            for before, after in (('lobby.client', 'lobby.claim_client'),
                                  ('var/client/C', 'var/datum/recovery_fixture_client/C'),
                                  ('H.key = C.key', 'recovery_fixture_transfer(C, H)'),
                                  (' in clients)', ' in recovery_fixture_clients)')):
                expected = 2 if before == 'var/client/C' else (3 if before == 'lobby.client' else 1)
                if body.count(before) != expected:
                    raise RuntimeError('Reclaim client IO adapter anchor changed: ' + before)
                body = body.replace(before, after)
            replacements[relative] = text[:start] + body + text[end:]
        for index, (relative, text) in enumerate(replacements.items()):
            generated_path = root / (prefix + f'_{index}.dm')
            generated_path.write_text(text, encoding='utf-8', newline='\n')
            generated.append(generated_path)
            original_include = relative.replace('/', chr(92))
            if source.count(original_include) != 1:
                raise RuntimeError('Production include anchor changed')
            source = source.replace(original_include, generated_path.name)
            (output / generated_path.name).write_text(text, encoding='utf-8', newline='\n')
            if args.negative_control == 'wound-restore' and relative == 'code/modules/organs/wound.dm':
                receipt['wound_control_source'] = generated_path.name
        probe = (root / 'tests/world_save/durable_world_probe.dm').read_text(encoding='utf-8')
        if args.zone_topology:
            zone_probe = root / 'tests/zone_persistence/probe.dm'
            probe = probe[:probe.index('/world/New()')] + zone_probe.read_text(encoding='utf-8')
            receipt['zone_probe_hash'] = hashlib.sha256(zone_probe.read_bytes()).hexdigest()
        if args.roof_areas:
            roof_probe = root / 'tests/roof_area_recovery/probe.dm'
            probe = probe[:probe.index('/world/New()')] + roof_probe.read_text(encoding='utf-8')
            receipt['roof_probe_hash'] = hashlib.sha256(roof_probe.read_bytes()).hexdigest()
        if args.persistence_year:
            year_probe = root / 'tests/persistence_year/probe.dm'
            setup = (root / 'code/setup.dm').read_text(encoding='utf-8')
            start = setup.index('\tif (config.allowedgamemodes == "PERSISTENCE")')
            end = setup.index('\n\t\t// Resume from the last completed save', start)
            activation = '/proc/persistence_year_startup()\n' + setup[start:end] + '\n'
            probe = probe[:probe.index('/world/New()')] + activation + year_probe.read_text(encoding='utf-8')
            receipt['production_hashes']['code/setup.dm'] = hashlib.sha256(setup.encode()).hexdigest()
            receipt['year_probe_hash'] = hashlib.sha256(year_probe.read_bytes()).hexdigest()
        if args.wounds:
            wound_probe = root / 'tests/world_save/wound_restore_probe.dm'
            probe = probe[:probe.index('/world/New()')] + wound_probe.read_text(encoding='utf-8')
            receipt['wound_probe_hash'] = hashlib.sha256(wound_probe.read_bytes()).hexdigest()
            receipt['production_hashes']['code/modules/organs/wound.dm'] = hashlib.sha256((root / 'code/modules/organs/wound.dm').read_bytes()).hexdigest()
        if args.lighting:
            lighting_probe = root / 'tests/world_save/lighting_probe.dm'
            probe = probe[:probe.index('/world/New()')] + lighting_probe.read_text(encoding='utf-8')
            receipt['lighting_probe_hash'] = hashlib.sha256(lighting_probe.read_bytes()).hexdigest()
            if args.negative_control == 'lighting-shared':
                probe += '\nvar/list/lighting_probe_shared_affecting = list()\n'
            for name in ('lighting_corner.dm', 'lighting_source.dm'):
                path = root / 'code/modules/lighting' / name
                receipt['production_hashes'][path.relative_to(root).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
        if args.dimension_bootstrap:
            adapter = root / 'tests/new_z_budget/fixture_admission.dm'
            probe = adapter.read_text(encoding='utf-8') + '\n' + probe[:probe.index('/world/New()')] + (root / 'tests/world_save/durable_dimension_probe.dm').read_text(encoding='utf-8')
            receipt['fixture_admission_hash'] = hashlib.sha256(adapter.read_bytes()).hexdigest()
        if args.recovery_reconnect:
            probe = probe[:probe.index('/world/New()')] + (root / 'tests/world_save/recovery_reconnect_probe.dm').read_text(encoding='utf-8')
        if args.lifecycle_shutdown:
            probe = probe[:probe.index('/world/New()')] + (root / 'tests/world_save/lifecycle_disk_probe.dm').read_text(encoding='utf-8')
        if args.startup_only:
            marker = '/world/New()\n'
            if probe.count(marker) != 1:
                raise RuntimeError('Startup diagnostic probe anchor changed')
            probe = probe[:probe.index(marker)] + marker + (
                '\ttext2file("startup-only world-New entered", "probe-progress.log")\n'
                '\tworld.OpenPort(0)\n'
                '\ttext2file(json_encode(list("startup_only" = TRUE)), "startup-result.json")\n'
                '\tdel(world)\n')
        probe_path = root / (prefix + '_probe.dm')
        probe_path.write_text(probe, encoding='utf-8', newline='\n')
        generated.append(probe_path)
        (output / probe_path.name).write_text(probe, encoding='utf-8', newline='\n')
        source += '\n#include "' + probe_path.name + '"\n'
        dme.write_text(source, encoding='utf-8', newline='\n')
        for path in (root / 'code/modules/persistence').glob('*.dm'):
            receipt['production_hashes'][path.relative_to(root).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
        receipt['probe_hash'] = hashlib.sha256((root / 'tests/world_save/durable_world_probe.dm').read_bytes()).hexdigest()
        receipt['generated_probe_hash'] = hashlib.sha256(probe_path.read_bytes()).hexdigest()
        receipt['base_commit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        (output / 'tested.patch').write_bytes(subprocess.check_output(['git', 'diff'], cwd=root))
        (output / 'probe.dme').write_text(source, encoding='utf-8')
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
        if args.prepare_only:
            return
        byond = args.byond_bin.absolute() if runtime else args.byond_bin.resolve(strict=True)
        compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        if runtime: runtime.before_launch('compile', output)
        build = subprocess.run([str(compiler), '-max_errors', '0', dme.name], cwd=root,
                               capture_output=True, text=True, timeout=180, creationflags=flags)
        build_log = build.stdout + build.stderr
        (output / 'compile.log').write_text(build_log, encoding='utf-8')
        if runtime:
            runtime.validate_compile(build.returncode, build_log, dme.with_suffix('.dmb').name)
        else:
            validate_compile(build.returncode, build_log, dme.with_suffix('.dmb').name)
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(dme.with_suffix(suffix), output / dme.with_suffix(suffix).name)
        (output / 'config').mkdir()
        shutil.copy2(root / 'config/tips.txt', output / 'config/tips.txt')
        shutil.copytree(root / 'config/names', output / 'config/names')
        platform_flags = ['-invisible', '-close'] if os.name == 'nt' else []
        if args.dimension_bootstrap:
            # Both use the identical compiled two-level DMB. Only disk files
            # survive from the writer to the fresh reader process.
            # Include operation admission, nested-call rejection and release.
            for mode, minimum_checks in (('write', 6), ('unmeasured', 7), ('read', 15)):
                before_files = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (output / 'map_saves').iterdir() if p.is_file()} if mode == 'unmeasured' else {}
                if runtime: runtime.before_launch('daemon:'+mode, output)
                run = subprocess.run([str(daemon), dme.with_suffix('.dmb').name, *platform_flags, '-trusted',
                    '-params', f'profile={args.profile};dimension_mode={mode}', '-log', f'{mode}-runtime.log'],
                    cwd=output, capture_output=True, text=True, timeout=120, creationflags=flags)
                (output / f'{mode}-daemon.log').write_text(run.stdout + run.stderr, encoding='utf-8')
                log = (output / f'{mode}-runtime.log').read_text(encoding='utf-8', errors='replace')
                diagnostics = log + run.stdout + run.stderr
                if run.returncode or DIAGNOSTIC.search(diagnostics):
                    raise RuntimeError(f'Expanded {mode} native diagnostics invalidated evidence')
                if mode == 'unmeasured':
                    after_files = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (output / 'map_saves').iterdir() if p.is_file()}
                    if any(after_files.get(path) != digest for path, digest in before_files.items()):
                        raise RuntimeError('Unmeasured recovery modified original generation bytes')
                    # The next independent reader tests accepted fixture admission.
                    # Keep the refused intent as evidence and remove only this test copy.
                    shutil.copy2(output / 'map_saves/restart_intent.json', output / 'held-restart-intent.json')
                    (output / 'map_saves/restart_intent.json').unlink()
                result = json.loads((output / 'metadata-result.json').read_text(encoding='utf-8'))
                (output / f'{mode}-result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
                receipt[mode] = result
                (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
                if not result.get('done') or result.get('checks', 0) < minimum_checks:
                    raise RuntimeError(f'Expanded {mode} assertions incomplete: {result}')
                # A reader must write its own completion record.
                (output / 'metadata-result.json').unlink()
            print(json.dumps(receipt, indent=2))
            return
        command = [str(daemon), dme.with_suffix('.dmb').name, *platform_flags, '-trusted',
                   '-params', 'profile=' + args.profile, '-log', 'runtime.log']
        if runtime: runtime.before_launch('daemon', output)
        if args.lighting or args.persistence_year:
            run = run_lighting(command, output, flags)
        else:
            run = subprocess.run(command, cwd=output, capture_output=True, text=True,
                                 timeout=90, creationflags=flags)
        (output / 'daemon.log').write_text(run.stdout + run.stderr, encoding='utf-8')
        (output / 'daemon-exit.json').write_text(json.dumps({'exit_code': run.returncode}), encoding='utf-8')
        if run.returncode:
            raise RuntimeError(f'Native daemon exited with {run.returncode}; see daemon-exit.json')
        log = (output / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        diagnostics = (log + run.stdout + run.stderr).lower()
        if re.search(r'\bOOM\b|out of memory|access violation|\bCRASH(?:ED)?\b', diagnostics, re.I):
            raise RuntimeError('Fatal native diagnostic invalidated fixture')
        if (args.lighting or args.wounds or args.persistence_year) and re.search(r'\bbug:', diagnostics):
            raise RuntimeError('Native lighting/wound engine diagnostic invalidated fixture')
        if (re.search(r'##\s*error\s*:', diagnostics) or
                any(word in diagnostics for word in ('unexpected runtime', 'bad ref', 'runtime error:', 'infinite loop', 'fatal error', 'segmentation', 'assertion failed'))):
            raise RuntimeError('Native engine diagnostic invalidated fixture')
        if args.startup_only:
            startup = json.loads((output / 'startup-result.json').read_text(encoding='utf-8'))
            if startup != {'startup_only': 1}:
                raise RuntimeError('Startup diagnostic did not complete')
            receipt['startup_result'] = startup
            (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
            print('Startup diagnostic completed; no persistence assertions ran.')
            return
        result_path = output / 'metadata-result.json'
        if not result_path.is_file():
            raise RuntimeError('Native daemon exited without a result; see daemon-exit.json and probe-progress.log')
        result = json.loads(result_path.read_text(encoding='utf-8'))
        if args.wounds and not args.negative_control:
            if not result.get('done') or result.get('roundtrips') != 18 or result.get('checks') != 141:
                raise RuntimeError('Wound disk recovery assertions incomplete: ' + str(result))
        if args.lifecycle_shutdown:
            # The DM receipt is written before native deletion. Acceptance must
            # inspect disk after the process exits, including delayed cleanup.
            if not result.get('done') or result.get('checks', 0) < 7:
                raise RuntimeError('Native shutdown assertions incomplete: ' + str(result))
            intent_path = output / 'map_saves/restart_intent.json'
            if args.negative_control == 'shutdown-return':
                if intent_path.exists() or 'Native shutdown returned without closing the world' not in log:
                    raise RuntimeError('Shutdown return control did not reproduce intent cleanup')
                receipt['post_exit_intent_preserved'] = False
                receipt['expected_failure_caught'] = True
            else:
                intent_text = intent_path.read_text(encoding='utf-8-sig')
                intent = json.loads(intent_text)
                marker = (output / 'map_saves/save_complete.txt').read_text().strip()
                if (hashlib.md5(intent_text.encode('utf-8')).hexdigest() != result.get('intent_hash') or
                        intent.get('generation') != result.get('generation') or marker != intent['generation']):
                    raise RuntimeError('Native shutdown changed the published recovery intent')
                receipt['post_exit_intent_preserved'] = True
                receipt['expected_failure_caught'] = False
            receipt['result'] = result
            (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
            print(json.dumps(receipt, indent=2))
            return
        if args.persistence_year:
            expected_date_failure = {'year-helper': 'earlier date not raised', 'year-load': 'saved date floor lost', 'year-order': 'saved date floor lost'}
            if args.negative_control:
                if result.get('done') or result.get('error') != expected_date_failure[args.negative_control]:
                    raise RuntimeError('Date control did not reach its named assertion: ' + str(result))
            elif not result.get('done') or result.get('imports') != 24 or result.get('checks') != 333:
                raise RuntimeError('Native date/import coverage incomplete: ' + str(result))
            receipt['result'] = result
            receipt['expected_failure_caught'] = bool(args.negative_control)
            (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
            print(json.dumps(receipt, indent=2))
            return
        expected = {'season': 'environment phase reset', 'preflight': 'malformed artillery sentinel mutated world',
                    'reachability': 'orphan metadata reference accepted', 'callback': 'restored callback duplicated',
                    'timer-restore': 'persisted callback was not restored',
                    'reclaim-order': 'waiting authenticated client not reclaimed after recovery',
                    'lighting-export': 'runtime atom lighting fields exported',
                    'lighting-legacy': 'legacy lighting graph prevented import',
                    'lighting-rebuild': 'restored custom light not rebuilt',
                    'lighting-opacity': 'restored obstruction caches stale',
                    'lighting-view': 'map clearing retired runtime view helper',
                    'lighting-eager': 'untouched corners allocated affecting lists',
                    'lighting-shared': 'corners share mutable affecting list'}
        if args.negative_control:
            if args.negative_control == 'wound-restore':
                if result.get('done') or 'Cannot read null.max_damage' not in result.get('error', '') or not result.get('source', '').endswith(receipt['wound_control_source']) or result.get('line') != 394 or result.get('checks') != 4:
                    raise RuntimeError('Historical wound source did not reproduce the constructor failure: ' + str(result))
                receipt['result'] = result
                receipt['expected_failure_caught'] = True
                (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
                print(json.dumps(receipt, indent=2))
                return
            if result.get('done') or result.get('error') != expected[args.negative_control]:
                raise RuntimeError('Negative control failed outside its intended assertion: ' + str(result))
            # Four operation-admission checks precede the malformed-wire guard.
            if args.negative_control == 'preflight' and result.get('checks') != 11:
                raise RuntimeError('Preflight control did not reach its first malformed-wire assertion')
            # Includes the export operation-release assertion before recovery.
            if args.negative_control == 'reclaim-order' and result.get('checks') != 9:
                raise RuntimeError('Reclaim ordering control did not reach its intended first failure')
            if args.negative_control == 'lighting-legacy':
                import_error = result.get('import_error') or ''
                if 'Cannot read null.light_sources' not in import_error or 'lighting_source.dm:35' not in import_error:
                    raise RuntimeError('Legacy lighting control did not reproduce the ownerless source constructor: ' + import_error)
        elif not result.get('done') or result.get('checks', 0) < (7 if args.lifecycle_shutdown else 19):
            raise RuntimeError('Native integration fixture incomplete: ' + str(result))
        receipt['result'] = result
        receipt['expected_failure_caught'] = bool(args.negative_control)
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
        print(json.dumps(receipt, indent=2))
    finally:
        for path in [dme, dme.with_suffix('.dmb'), dme.with_suffix('.rsc'), *generated]:
            path.unlink(missing_ok=True)


def run_lighting(command, output, flags):
    """Check the live fixture's OS sockets during its deliberate entry hold."""
    child = subprocess.Popen(command, cwd=output, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, text=True, creationflags=flags)
    try:
        ready = output / 'lighting-port-ready.json'
        deadline = time.monotonic() + 30
        while not ready.is_file():
            if child.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Lighting fixture exited or timed out before closed-port census')
            time.sleep(0.02)
        state = json.loads(ready.read_text(encoding='utf-8'))
        if state.get('port'):
            raise RuntimeError('Lighting fixture reports an open native port')
        if os.name == 'nt':
            script = (f'$L=@(Get-NetTCPConnection -State Listen -ErrorAction Stop | '
                      f'Where-Object OwningProcess -eq {child.pid}); $L.Count')
            census = subprocess.run(['powershell', '-NoProfile', '-Command', script],
                                    capture_output=True, text=True, timeout=20, check=True)
            listeners = int(census.stdout.strip())
        else:
            sockets = set()
            for fd in Path(f'/proc/{child.pid}/fd').iterdir():
                try:
                    link = os.readlink(fd)
                except FileNotFoundError:
                    continue
                if link.startswith('socket:['):
                    sockets.add(link[8:-1])
            listeners = 0
            for table in ('tcp', 'tcp6'):
                for row in Path(f'/proc/{child.pid}/net/{table}').read_text().splitlines()[1:]:
                    fields = row.split()
                    if fields[3] == '0A' and fields[9] in sockets:
                        listeners += 1
        if child.poll() is not None or listeners:
            raise RuntimeError('Lighting fixture not alive with zero listeners at census')
        (output / 'listener-census.json').write_text(json.dumps(
            {'pid': child.pid, 'listeners': listeners, 'native_port': state['port']}), encoding='utf-8')
        stdout, stderr = child.communicate(timeout=90)
        return subprocess.CompletedProcess(command, child.returncode, stdout, stderr)
    finally:
        if child.poll() is None:
            child.kill()
            child.wait(timeout=10)
        (output / 'lighting-process-exit.json').write_text(json.dumps(
            {'pid': child.pid, 'exit_code': child.returncode}), encoding='utf-8')


if __name__ == '__main__':
    main()
