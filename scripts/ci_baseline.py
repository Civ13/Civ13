"""Bounded offline CI registry and exact-source execution/aggregate receipts.

Only reviewed, explicitly named unittest files run here. This is neither a native
test launcher nor a claim that source projections establish gameplay acceptance.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
_toolchain_spec = importlib.util.spec_from_file_location('ci_byond_toolchain', ROOT / 'scripts/byond_toolchain.py')
toolchain = importlib.util.module_from_spec(_toolchain_spec)
_toolchain_spec.loader.exec_module(toolchain)
POLICY_FILES = tuple('tests/' + name for name in (
    'test_ci_selection.py', 'test_ci_regression_policy.py',
    'test_ci_build_prefix.py', 'test_ci_baseline.py', 'test_ci_checkout_refs.py'))
# Review the complete imports/call graph before adding files. No wildcard test
# discovery: test_native.py and newly added runners must never enter implicitly.
SUITES = {
    # Stdlib-only source projection and bounded RGBA8 PNG/DMI inspection.
    # No harvest preview helper, external package, native runner or network import.
    # Shared production/art inputs retain conservative all-suite fallback.
    'tanning_rack_appearance': {'files': ('tests/test_tanning_rack_appearance.py',),
        'paths': (), 'shared_paths': (
            'code/game/objects/structures/converters.dm',
            'code/game/objects/items/stacks/sheets/leather.dm',
            'icons/obj/structures.dmi', 'icons/obj/materials.dmi')},
    # Inert existing harvest/flax runner imports plus stdlib file/transport
    # adapters only. Tests replace every process boundary; no native execution.
    'harvest_inputs': {'files': ('tests/animal_harvest/test_input_accounting.py',),
        'paths': ('tests/animal_harvest/test_input_accounting.py',), 'shared_paths': (
            'tests/animal_harvest/run.py', 'tests/animal_harvest/hide_recipe_probe.dm',
            'tests/flax_processing/run.py', 'tests/flax_processing/required-inputs.json',
            'code/names.dm', 'config/names/', 'scripts/native_fixture.py',
            'scripts/byond_runtime.py', 'scripts/byond_toolchain.py',
            'tools/byond/version.json')},
    # Stdlib-only admission expressions and fixture wiring; never import a native
    # runner. Shared game/fixture inputs retain conservative all-suite fallback.
    'action_admission': {'files': ('tests/animal_harvest/test_action_admission.py',),
        'paths': ('tests/animal_harvest/test_action_admission.py',), 'shared_paths': (
            'code/game/objects/structures/wild.dm',
            'code/game/turfs/floor_attackby.dm',
            'code/game/objects/items/weapons/material/ooga_booga_weapons.dm',
            'code/game/objects/structures/rocks.dm',
            'code/game/objects/structures/repairing.dm',
            'tests/animal_harvest/probe.dm',
            'tests/animal_harvest/action_admission_probe.dm')},
    # Offline injected transport and temporary wiki fixtures. Shared production
    # inputs remain shared so they do not suppress other suites' fallback.
    'help_wiki_guides': {'files': ('tests/player_help/test_wiki_guides.py',),
        'paths': (), 'shared_paths': (
            'scripts/player_help_bridge.py', 'UI/player-help.json', 'UI/crafting-atlas.json',
            'code/game/objects/structures/blacksmithing/refining.dm',
            'code/game/objects/structures/blacksmithing/molds.dm',
            'code/game/objects/structures/blacksmithing/blacksmithing.dm',
            'code/game/objects/structures/kitchen/oven.dm',
            'code/modules/research_tree/research_node.dm',
            'code/game/objects/items/stacks/civ_recipes.dm',
            'code/modules/research_tree/research_bench.dm',
            'code/modules/materials/materials.dm',
            'code/game/objects/items/weapons/material/shards.dm',
            'code/predefines.dm', 'code/game/objects/items/clothing/clothing.dm',
            'code/modules/reagents/reagent_containers/food/sandwich.dm',
            'code/modules/1713/dew_collector.dm')},
    # Only stdlib source contracts; the shared DM inputs stay unmapped so their
    # existing all-suite fallback and other owners' coverage remain intact.
    'help_tab_links': {'files': ('tests/player_help/test_help_links.py',),
        'paths': (), 'shared_paths': ('code/modules/client/client_verbs.dm',
                                     'code/game/mob/crafting_atlas.dm')},
    # Full import graph: stdlib source/catalog checks plus the adjacent inert
    # test_foundations specification helper. No native runner or network import.
    # Shared production sources retain their conservative all-suite fallback.
    'character_traits': {'files': ('tests/character_traits/test_foundations.py',
                                   'tests/character_traits/test_random.py'),
        'paths': ('tests/character_traits/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/traits.dm',
            'code/modules/client/preferencesSQLite/preference_setup/general/01_basic.dm',
            'code/modules/client/preferencesSQLite/preferences.dm',
            'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'code/game/mob/living/carbon/human/human_stats.dm')},
    # Source-only pointer inventory/hooks and injected alert counter. Imports are
    # stdlib plus the existing inert save-movement projection, and the link test
    # imports the cross-level runner only to stage files; no native launch.
    'persistence_pointers': {'files': ('tests/persistence_pointers/test_contract.py',
                                    'tests/persistence_pointers/test_restore_dependents.py',
                                    'tests/persistence_pointers/test_action_reconnect.py',
                                    'tests/persistence_pointers/test_level_links.py'),
        'paths': ('tests/persistence_pointers/',),
        'shared_paths': ('code/modules/persistence/',
            'code/game/mob/living/simple_animal/',
            'code/game/mob/living/carbon/human/pull_pair_ownership.dm',
            'code/game/mob/grab.dm', 'code/game/mob/observer/ghost/ghost.dm',
            'code/game/objects/structures/optable.dm',
            'code/game/objects/items/weapons/explosives.dm',
            'code/modules/multiz/structures.dm', 'code/_onclick/hud/action.dm',
            'tests/world_save/full_game_probe.dm', 'tests/save_movement/source_adapter.py',
            'tests/world_save/run-cross-level.py', 'tests/world_save/stubs.dm',
            'tests/save_movement/test_guard.py', 'code/processes/abandoned_items.dm',
            'code/modules/1713/weapons/zoom.dm', 'code/modules/1713/weapons/attachment.dm',
            'code/modules/1713/gunsmithing/gun_configuration.dm',
            'code/modules/1713/machinery/modular_vehicles/wheels.dm',
            'code/game/mob/living/living_defense.dm',
            'code/game/mob/living/living_hud.dm',
            'code/game/mob/living/carbon/human/human_hud.dm',
            'code/game/objects/items/weapons/swords_axes_etc.dm')},
    # Inert stdlib-only source/model checks; no native runner or subprocesses.
    # Shared movement sources retain their conservative all-suite fallback.
    'destroyed_grab_preflight': {'files': ('tests/test_destroyed_grab_preflight.py',),
        'paths': (), 'shared_paths': ('code/game/mob/mob_movement.dm',
                                     'code/game/mob/living/carbon/human/subtile_movement.dm')},
    'policy': {'files': POLICY_FILES, 'always': True, 'paths': ()},
    'bootstrap': {'files': ('tests/test_byond_bootstrap.py', 'tests/test_byond_toolchain.py',
                            'tests/test_byond_runtime.py', 'tests/test_sprite_toolchain.py'), 'always': True, 'paths': ()},
    'progress': {'files': ('tests/world_save/test_progress_sources.py',), 'always': True, 'paths': ()},
    # Stdlib-only scalar/callback projections; no native runner or subprocesses.
    # Shared chemistry/stack sources retain their conservative all-suite fallback.
    'grinder': {'files': ('tests/grinder/test_transaction.py',),
        'paths': ('tests/grinder/',), 'shared_paths': (
            'code/modules/reagents/Chemistry-Machinery.dm',
            'code/modules/materials/material_sheets.dm',
            'code/game/objects/structures/kitchen/oven.dm',
            'code/modules/1713/wood_ash_compost.dm',
            'code/game/objects/structures.dm',
            'code/game/objects/items/stacks/civ_recipes.dm',
            'code/modules/research_tree/research_node.dm',
            'config/crafting/material_recipes_global.txt',
            'config/crafting/material_recipes_camp.txt',
            'config/crafting/material_recipes_carib.txt',
            'code/game/objects/items/stacks/stack.dm')},
    # Stdlib-only source projection; no native runner is imported or executed.
    # Keep shared farming.dm unmapped so its all-suite fallback stays intact.
    'crop_stage_step': {'files': ('tests/crop_stage_step/test_source.py',), 'paths': (
        'tests/crop_stage_step/', 'tests/plant_lifecycle/')},
    'research': {'files': ('tests/research_scheduler/test_resume.py',), 'paths': (
        'tests/research_scheduler/', 'code/processes/research_tree.dm',
        'code/processes/_process.dm', 'code/processes/___defines.dm',
        'code/processes/__processScheduler.dm')},
    'ping': {'files': ('tests/ping_scheduler/test_resume.py',), 'paths': (
        'tests/ping_scheduler/', 'code/processes/ping_track.dm', 'code/processes/_process.dm')},
    'year': {'files': ('tests/persistence_year/test_floor.py',), 'paths': (
        'tests/persistence_year/', 'tests/world_save/', 'code/modules/persistence/', 'code/setup.dm')},
    'evidence': {'files': ('tests/test_game_evidence.py',), 'paths': (
        'tests/test_game_evidence.py', 'scripts/check-game-evidence.py')},
    'ecology_heatmap': {'files': ('tests/ecology_heatmap/test_source_contract.py',), 'paths': (
        'tests/ecology_heatmap/', 'code/modules/ecology/activity_heatmap.dm',
        'docs/ecology-activity-heatmap-prototype.md',
        'code/modules/persistence/functions.dm')},
    'hub_status': {'files': ('tests/test_hub_status.py',), 'paths': (
        'tests/test_hub_status.py', 'code/world.dm', 'config/config.txt')},
    # Shared transport/persistence files retain their existing all-suite fallback.
    'carriage_glide': {'files': ('tests/carriage_glide/test_sources.py',), 'paths': (
        'tests/carriage_glide/',)},
    'throw_launch': {'files': ('tests/throw_launch_clearance/test_launch.py',
                              'tests/throw_launch_clearance/test_runtime_plan.py'), 'paths': (
        'tests/throw_launch_clearance/', 'tests/save_movement/source_adapter.py',
        'code/game/atoms_movable.dm', 'code/game/objects/items.dm',
        'code/processes/throwing.dm', 'code/modules/persistence/functions.dm')},
    'los_context': {'files': ('tests/los_context/test_offline.py',
                              'tests/los_context/test_production.py',
                              'tests/los_context/test_tile_motion.py',
                              'tests/test_geometric_presentation.py',
                              'tests/test_visibility_diagnostics.py'), 'paths': (
        'tests/los_context/', 'code/modules/visibility/', 'civ13.dme',
        'code/_onclick/hud/hover_name.dm', 'code/game/mob/mob.dm',
        'code/game/mob/logout.dm', 'code/modules/client/client_procs.dm'),
        'shared_paths': ('code/game/atoms_movable.dm', 'tests/save_movement/source_adapter.py')},
    # Inert source projections and file-only fixture preparation. Import graph:
    # stdlib + existing LOS/save-movement projections; no native runner is imported.
    # Keep shared movement/lighting files unmapped: they retain all-suite fallback.
    'root_tree_presentation': {'files': (
        'tests/root_tree_presentation/test_contract.py',
        'tests/root_tree_presentation/test_noop_refresh.py',
        'tests/root_tree_presentation/test_preparation.py',
        'tests/root_tree_presentation/test_protocol.py'), 'paths': (
        'tests/root_tree_presentation/', 'code/modules/visibility/',
        'code/__defines/_planes+layers.dm', 'civ13.dme',
        'tests/save_movement/source_adapter.py')},
    'character_return_preparation': {'files': ('tests/world_save/character_return/test_prepare.py',
        'tests/world_save/test_roundtrip_compat.py', 'tests/world_save/test_restart_sources.py'),
        'paths': ('tests/world_save/character_return/',),
        # Shared reads must select this suite without claiming exclusive impact
        # ownership and removing the existing all-suite unmapped fallback.
        'shared_paths': ('tests/world_save/', 'tests/new_z_budget/z_budget_evidence.py',
            'tests/floor_decal_tracking/prepare.py', 'code/predefines.dm', 'code/_macros.dm',
            'code/modules/persistence/', 'code/modules/multiz/world_z_budget.dm',
            'code/game/mob/living/carbon/human/human_helpers.dm', 'code/game/objects/buckling.dm',
            'code/game/atoms_movable.dm', 'code/_helpers/global_lists.dm',
            'code/modules/1713/snowfall_ground.dm', 'code/world.dm')},
    'character_return': {'files': ('tests/save_movement/test_character_return.py',), 'paths': (
        'tests/save_movement/', 'code/modules/persistence/player_reclaim.dm', 'code/modules/persistence/bed_return.dm',
        'code/game/mob/new_player/', 'code/game/mob/living/carbon/human/human_helpers.dm'),
        'shared_paths': ('code/game/gameticker.dm', 'code/modules/persistence/functions.dm',
            'code/game/mob/living/carbon/carbon_defines.dm',
            'code/game/mob/living/carbon/human/nomads_spawn.dm',
            'code/game/mob/living/carbon/human/human_life.dm')},
    # Keep mixed production static.dm unmapped: its existing all-suite fallback
    # must still cover changes to fish, piranhas and ants, not just fishing.
    'fishing_stock': {'files': ('tests/fishing_stock/test_source_contract.py',
                                'tests/fishing_stock/test_preparation.py',
                                'tests/fishing_stock/test_native_runner.py'), 'paths': (
        'tests/fishing_stock/',)},
    # Source and injected-help contracts only; this suite does not run DM.
    # Keep shared production and Atlas sources unmapped so their existing
    # conservative all-suite fallback remains intact.
    'sawmill': {'files': ('tests/sawmill/test_contract.py',
                           'tests/test_atlas_navigation.py',
                           'tests/player_help/test_recipe_context.py'), 'paths': (
        'tests/sawmill/',)},
    # Keep shared game sources unmapped where they previously selected the
    # all-suite fallback; persistence was already mapped by existing suites.
    'water_treatment': {'files': ('tests/stone_boiling/test_source.py',
                                  'tests/stone_kiln/test_source.py'), 'paths': (
        'tests/stone_boiling/', 'tests/stone_kiln/',
        'code/modules/persistence/functions.dm')},
    'save_movement': {'files': ('tests/save_movement/test_guard.py',), 'paths': (
        'tests/save_movement/', 'code/modules/persistence/functions.dm')},
    # Full import graph: stdlib source adapter, catalog-only Atlas builder/projector,
    # and inert Help imports. No native sprite export or engine launch.
    # Shared material/Atlas inputs retain their conservative all-suite fallback.
    'woodworking': {'files': ('tests/primitive_woodworking/test_source.py',
                              'tests/test_atlas_navigation.py'), 'paths': (
        'tests/primitive_woodworking/', 'code/modules/1713/primitive_woodworking.dm',
        'scripts/atlas/woodworking.py', 'scripts/atlas/woodworking-contract.json',
        'code/modules/persistence/functions.dm', 'civ13.dme')},
    # Offline only: reviewed guard projection, catalog generation, inert Help imports.
    # Shared crafting/Atlas files keep the conservative all-suite fallback.
    'furniture_joinery': {'files': ('tests/furniture_joinery/test_contract.py',
                                  'tests/furniture_joinery/test_wooden_shelf.py',
                                  'tests/furniture_joinery/test_bedroll.py',
                                  'tests/furniture_joinery/test_document_drawers.py',
                                  'tests/furniture_joinery/test_sofa_materials.py',
                                  'tests/furniture_joinery/test_canopy.py',
                                  'tests/furniture_joinery/test_cutting_board.py',
                                  'tests/furniture_joinery/test_barrel_ingredients.py',
                                  'tests/furniture_joinery/test_glass_extraction.py',
                                  'tests/furniture_joinery/test_glass_cotton.py'), 'paths': (
        'tests/furniture_joinery/', 'code/game/objects/items/stacks/furniture_joinery.dm',
        'config/crafting/furniture_joinery.json', 'scripts/audit-crafting-recipes.py',
        'code/modules/1713/cutting_board.dm', 'tests/primitive_woodworking/source_adapter.py',
        'code/modules/persistence/functions.dm', 'code/modules/reagents/reagent_containers/food.dm')},
    'dictionary': {'files': ('tests/dictionary_era/test_sources.py',
                             'tests/dictionary_era/test_slang_content.py',
                             'tests/dictionary_era/test_phrase_mode.py'), 'paths': (
        'tests/dictionary_era/', 'code/_helpers/dictionary.dm', 'code/_helpers/text.dm',
        'code/setup.dm', 'code/world.dm', 'code/__defines/__game.dm', 'civ13.dme',
        'code/game/mob/living/carbon/human/say.dm',
        'code/game/mob/living/carbon/human/whisper.dm',
        'config/dictionary.txt', 'tools/byond/version.json')},
}
CI_PATHS = ('scripts/select-ci.py', 'scripts/ci_baseline.py',
            '.github/workflows/ci-selection.yml', '.github/workflows/test.yml')
TIMEOUT = 30  # per reviewed suite; enclosing job also has a wall-clock limit
# Reviewed prose/presentation formats only. Script/config suffixes deliberately
# fall back even below docs/; compilation retains its separate existing policy.
DOC_SUFFIXES = {'.md', '.rst', '.html', '.css', '.png', '.jpg', '.jpeg', '.gif',
                '.webp', '.svg', '.ico', '.woff', '.woff2', '.ttf', '.pdf'}
DOC_ASSETS = {'docs/api/search.js', 'docs/api/baseline-diagnostics.txt'}


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, stderr=subprocess.PIPE,
                                   timeout=15).decode('utf-8').strip()


def revision(value):
    return git('rev-parse', '--verify', value + '^{commit}')


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n', encoding='utf-8')


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def provenance(head, base):
    actual = revision('HEAD')
    if revision(head) != actual:
        raise ValueError('Requested head differs from checked-out HEAD')
    resolved_base = None
    if base and set(base) != {'0'}:
        try:
            resolved_base = revision(base)
        except (subprocess.SubprocessError, UnicodeError):
            pass
    return dict(head=actual, base=resolved_base, requested_base=base,
                run_id=os.environ.get('GITHUB_RUN_ID'),
                run_attempt=os.environ.get('GITHUB_RUN_ATTEMPT'))


def documentation(path):
    relative = PurePosixPath(path)
    return (path in DOC_ASSETS or
            (path.startswith('docs/') and relative.suffix.lower() in DOC_SUFFIXES) or
            (len(relative.parts) == 1 and relative.suffix.lower() == '.md'))


def matches(path, pattern):
    return path.startswith(pattern) if pattern.endswith('/') else path == pattern


def impact(paths, comparison='available'):
    """Unknown executable/shared impact runs this small registry, never native work."""
    reasons = {name: ['Always-required offline baseline'] if spec.get('always') else []
               for name, spec in SUITES.items()}
    unknown = []
    if comparison != 'available':
        unknown = ['Comparison unavailable; all reviewed offline suites required']
    for path in paths:
        covered = False
        for name, spec in SUITES.items():
            owned = any(matches(path, pattern) for pattern in (*spec['paths'], *spec['files']))
            if owned:
                covered = True
            if owned or any(matches(path, pattern) for pattern in spec.get('shared_paths', ())):
                reasons[name].append('Affected input: ' + path)
        if path in CI_PATHS or path in POLICY_FILES:
            unknown.append('CI policy/dependency changed: ' + path)
        elif not covered and not documentation(path):
            unknown.append('Unmapped impact: ' + path)
    if unknown:
        for name in reasons:
            reasons[name].append('Conservative fallback: all reviewed offline suites')
    return {'suites': {name: {'selected': bool(why), 'reason': why or [
                'No mapped input changed; native/costly tests remain separately admitted']}
                       for name, why in reasons.items()}, 'fallback_reasons': unknown}


def selection_receipt(base, head, game, extensive, new_tests, reason, event, eligibility=None):
    receipt = dict(schema_version=1, kind='selection', status='passed',
                   **provenance(head, base), event=event)
    if eligibility is not None:
        receipt.update(action=eligibility['action'], eligibility=eligibility)
    paths = []
    comparison = 'unavailable'
    if receipt['base']:
        try:
            raw = subprocess.check_output(['git', 'diff', '--name-only', '--no-renames', '-z',
                                           receipt['base'], receipt['head']], cwd=ROOT,
                                          stderr=subprocess.PIPE, timeout=15)
            paths = sorted(p for p in raw.decode('utf-8').split('\0') if p)
            comparison = 'available'
        except (subprocess.SubprocessError, UnicodeError):
            pass
    receipt.update(comparison={'status': comparison, 'paths': paths,
                              'reason': 'Exact base/head comparison' if comparison == 'available'
                              else 'No reliable diff; compile policy and bounded offline fallback apply'},
                   compile={'selected': game, 'reason': reason}, extensive=extensive,
                   new_tests=new_tests, baseline=impact(paths, comparison))
    return receipt


def selection_eligibility(plan):
    policy = plan.get('eligibility', {})
    if policy.get('metadata_valid') is not True or plan.get('action') != policy.get('action'):
        raise ValueError('Missing/invalid event scope evidence')
    for name in ('compile', 'native', 'gating'):
        row = policy.get(name, {})
        if type(row.get('eligible')) is not bool or not row.get('reason'):
            raise ValueError('Missing/invalid eligibility: ' + name)
    if policy['gating']['eligible'] and not policy['native']['eligible']:
        raise ValueError('Incomplete native admission cannot publish a gating verdict')
    return policy


def attempt_number(value):
    if type(value) is not str or not re.fullmatch(r'[1-9][0-9]{0,5}', value):
        raise ValueError('Invalid run attempt: ' + repr(value))
    return int(value)


def load_selection(path, head, base, selection_attempt=None):
    """A re-run of failed jobs reuses earlier successful jobs and their artifacts,
    so the selection may come from an earlier attempt of this same run. The
    caller names that attempt from the selection job's own output."""
    plan = json.loads(Path(path).read_text(encoding='utf-8'))
    expected = provenance(head, base)
    for key in ('head', 'base', 'requested_base', 'run_id'):
        if plan.get(key) != expected[key]:
            raise ValueError('Selection provenance mismatch: ' + key)
    if selection_attempt is None:
        if plan.get('run_attempt') != expected['run_attempt']:
            raise ValueError('Selection provenance mismatch: run_attempt')
    elif (plan.get('run_attempt') != selection_attempt
          or attempt_number(selection_attempt) > attempt_number(expected['run_attempt'])):
        raise ValueError('Selection provenance mismatch: run_attempt')
    if plan.get('schema_version') != 1 or plan.get('kind') != 'selection' or plan.get('status') != 'passed':
        raise ValueError('Missing or failed selection receipt')
    suites = plan['baseline']['suites']
    if set(suites) != set(SUITES) or any(type(row['selected']) is not bool for row in suites.values()):
        raise ValueError('Invalid baseline selection')
    if any(not suites[name]['selected'] for name, spec in SUITES.items() if spec.get('always')):
        raise ValueError('Always-required suite omitted')
    if type(plan['compile']['selected']) is not bool:
        raise ValueError('Invalid compilation selection')
    selection_eligibility(plan)
    return plan


def run_unit(name, output):
    """Child interpreter emits counts so zero tests or unittest skips cannot pass."""
    suite = unittest.TestSuite()
    # These reviewed suites import adjacent, source-only specification helpers.
    if name in ('save_movement', 'character_traits'):
        sys.path.insert(0, str(ROOT / 'tests' / name))
    for index, relative in enumerate(SUITES[name]['files']):
        path = ROOT / relative
        spec = importlib.util.spec_from_file_location(f'baseline_{name}_{index}', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        suite.addTests(unittest.defaultTestLoader.loadTestsFromModule(module))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    passed = result.wasSuccessful() and result.testsRun > 0 and not result.skipped
    write_json(output, dict(tests=result.testsRun, failures=len(result.failures),
                            errors=len(result.errors), skipped=len(result.skipped),
                            status='passed' if passed else 'failed'))
    return 0 if passed else 1


def suite_environment(name, plan):
    environment = os.environ.copy()
    if name == 'los_context':
        environment['LOS_EVENT_BASE'] = plan['base'] or ''
        environment['LOS_EVENT_HEAD'] = plan['head'] or ''
    return environment


def execute(plan, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    receipt = dict(schema_version=1, kind='baseline', status='running',
                   **{key: plan[key] for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt')},
                   job_attempt=os.environ.get('GITHUB_RUN_ATTEMPT'),
                   selection_sha256=digest(plan), suites={})
    (output / 'source-tree.txt').write_text(git('ls-tree', '-r', 'HEAD') + '\n', encoding='utf-8')
    observed_head_before = revision('HEAD')
    tracked_patch = subprocess.check_output(['git', 'diff', '--binary', 'HEAD'], cwd=ROOT, timeout=15)
    (output / 'tested.patch').write_bytes(tracked_patch)
    receipt['tracked_dirty'] = bool(tracked_patch)
    receipt['observed_head_before'] = observed_head_before
    write_json(output / 'baseline.json', receipt)
    for name, selected in plan['baseline']['suites'].items():
        row = dict(selected, status='skipped')
        receipt['suites'][name] = row
        if selected['selected']:
            counts = output / (name + '.json')
            counts.unlink(missing_ok=True)
            command = [sys.executable, '-B', str(Path(__file__).resolve()), 'unit',
                       '--suite', name, '--output', str(counts.resolve())]
            row.update(command=command, timeout_seconds=TIMEOUT, files=list(SUITES[name]['files']))
            started = time.monotonic()
            with (output / (name + '.log')).open('wb') as log:
                try:
                    result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                            timeout=TIMEOUT, env=suite_environment(name, plan))
                    row['exit_code'] = result.returncode
                    row['status'] = 'failed'
                    if counts.is_file():
                        row['counts'] = json.loads(counts.read_text(encoding='utf-8'))
                        if result.returncode == 0 and row['counts']['status'] == 'passed':
                            row['status'] = 'passed'
                except subprocess.TimeoutExpired:
                    row.update(status='failed', reason=['Offline suite deadline exceeded'])
            row['duration_seconds'] = round(time.monotonic() - started, 3)
        write_json(output / 'baseline.json', receipt)
    observed_head_after = revision('HEAD')
    after_patch = subprocess.check_output(['git', 'diff', '--binary', 'HEAD'], cwd=ROOT, timeout=15)
    (output / 'tested-after.patch').write_bytes(after_patch)
    receipt.update(observed_head_after=observed_head_after, tracked_dirty_after=bool(after_patch),
                   source_unchanged=(observed_head_before == observed_head_after == plan['head']
                                     and tracked_patch == after_patch))
    source_ok = receipt['source_unchanged'] and not tracked_patch and not after_patch
    receipt['status'] = 'passed' if source_ok and all(
        row['status'] == ('passed' if row['selected'] else 'skipped')
        for row in receipt['suites'].values()) else 'failed'
    write_json(output / 'baseline.json', receipt)
    print(json.dumps(receipt, indent=2))
    return 0 if receipt['status'] == 'passed' else 1


def compile_receipt(plan, outcome, output):
    directory = Path(output).parent
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'source-tree.txt').write_text(git('ls-tree', '-r', 'HEAD') + '\n', encoding='utf-8')
    (directory / 'source-final.patch').write_bytes(subprocess.check_output(
        ['git', 'diff', '--binary', 'HEAD'], cwd=ROOT, timeout=15))
    selected = plan['compile']['selected']
    status = 'passed' if outcome == 'success' and selected else 'failed' if selected else 'skipped'
    if not selected and outcome != 'skipped':
        status = 'failed'
    requirement = None
    toolchain_error = None
    acquisition = None
    try:
        requirement = toolchain.load()
        if selected and outcome == 'success':
            if (directory / 'byond-version.txt').read_text().strip() != requirement['version']:
                raise ValueError('Installed compiler version receipt differs from active requirement')
            toolchain.compiler_log((directory / 'compiler.log').read_text(), requirement['version'])
            acquisition = toolchain.read_download_receipt(directory / 'byond-download.json', requirement, 'linux')
    except (OSError, ValueError) as error:
        status = 'failed'
        toolchain_error = str(error)[:300]
    receipt = dict(schema_version=1, kind='compile', status=status, selected=selected,
                   **{key: plan[key] for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt')},
                   job_attempt=os.environ.get('GITHUB_RUN_ATTEMPT'),
                   selection_sha256=digest(plan), step_outcome=outcome,
                   reason=plan['compile']['reason'],
                   toolchain='BYOND ' + requirement['version'] if requirement else None,
                   toolchain_error=toolchain_error,
                   acquisition=acquisition,
                   archive_authenticity=requirement['integritySource'] if requirement else 'Unavailable')
    write_json(output, receipt)
    return 1 if status == 'failed' else 0


def aggregate(plan, baseline, compile_run, jobs, extraction_selected, attempts=None):
    """attempts names the attempt each reused or re-run job actually executed in,
    plus the aggregate's own current attempt; by default all equal the selection's."""
    errors = []
    if attempts is None:
        attempts = dict.fromkeys(('baseline', 'compile', 'current'), plan.get('run_attempt'))
    try:
        selection_eligibility(plan)
    except ValueError as error:
        errors.append(str(error))
    if plan['compile']['selected']:
        requirement = toolchain.load()
        if compile_run.get('toolchain') != 'BYOND ' + requirement['version'] or compile_run.get('toolchain_error') is not None:
            errors.append('Compiler receipt differs from active BYOND requirement')
        try:
            toolchain.validate_download_receipt(compile_run.get('acquisition'), requirement, 'linux')
        except ValueError:
            errors.append('Missing/invalid exact-source BYOND acquisition receipt')
    required = {'changes', 'baseline', 'evidence-checker', 'build'}
    if extraction_selected:
        required.add('extraction-instances')
    for name in required:
        if jobs.get(name, {}).get('result') != 'success':
            errors.append('Required job did not succeed: ' + name)
    if not extraction_selected and jobs.get('extraction-instances', {}).get('result') not in {'success', 'skipped'}:
        errors.append('Unexpected extraction job failure or missing outcome')
    for receipt, kind in ((baseline, 'baseline'), (compile_run, 'compile')):
        if receipt.get('schema_version') != 1 or receipt.get('kind') != kind:
            errors.append('Missing/invalid ' + kind + ' receipt')
        for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt'):
            if receipt.get(key) != plan.get(key):
                errors.append(kind + ' provenance mismatch: ' + key)
        if receipt.get('selection_sha256') != digest(plan):
            errors.append(kind + ' selection digest mismatch')
        try:
            if receipt.get('job_attempt') != attempts[kind] or not (
                    attempt_number(plan.get('run_attempt')) <= attempt_number(attempts[kind])
                    <= attempt_number(attempts['current'])):
                raise ValueError('order')
        except ValueError:
            errors.append(kind + ' job attempt mismatch')
    if baseline.get('status') != 'passed':
        errors.append('Baseline did not pass')
    if baseline.get('tracked_dirty') is not False:
        errors.append('Baseline is not evidence from a clean committed head')
    if (baseline.get('tracked_dirty_after') is not False or baseline.get('source_unchanged') is not True
            or baseline.get('observed_head_before') != plan['head']
            or baseline.get('observed_head_after') != plan['head']):
        errors.append('Baseline source changed during tests or post-test source evidence is missing')
    actual = baseline.get('suites', {})
    if set(actual) != set(SUITES):
        errors.append('Baseline suite set differs from selection')
    for name, selection in plan['baseline']['suites'].items():
        row = actual.get(name, {})
        if row.get('selected') != selection['selected'] or row.get('status') != (
                'passed' if selection['selected'] else 'skipped'):
            errors.append('Missing, failed or unexpectedly skipped suite: ' + name)
        if selection['selected']:
            counts = row.get('counts', {})
            if row.get('exit_code') != 0 or counts.get('status') != 'passed' or not counts.get('tests') or any(
                    counts.get(key) != 0 for key in ('errors', 'failures', 'skipped')):
                errors.append('Incomplete test execution: ' + name)
        elif not row.get('reason'):
            errors.append('Unexplained suite skip: ' + name)
    selected = plan['compile']['selected']
    if compile_run.get('selected') != selected or compile_run.get('status') != ('passed' if selected else 'skipped'):
        errors.append('Required compilation missing/failed/skipped, or invalid skip')
    if compile_run.get('step_outcome') != ('success' if selected else 'skipped') or not compile_run.get('reason'):
        errors.append('Incomplete compilation outcome/reason')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('unit', 'run', 'compile', 'aggregate'))
    parser.add_argument('--suite', choices=SUITES)
    parser.add_argument('--selection')
    parser.add_argument('--head')
    parser.add_argument('--base', default='')
    parser.add_argument('--output', required=True)
    parser.add_argument('--outcome')
    parser.add_argument('--baseline')
    parser.add_argument('--compile-receipt')
    parser.add_argument('--selection-attempt')
    parser.add_argument('--baseline-attempt')
    parser.add_argument('--compile-attempt')
    args = parser.parse_args()
    if args.mode == 'unit':
        return run_unit(args.suite, args.output)
    plan = load_selection(args.selection, args.head, args.base, args.selection_attempt)
    if args.mode == 'run':
        return execute(plan, args.output)
    if args.mode == 'compile':
        return compile_receipt(plan, args.outcome, args.output)
    jobs = json.loads(os.environ['CI_NEEDS'])
    gating = os.environ['GATING_SELECTION']
    if gating not in {'1', '0'} or (gating == '1') != plan['eligibility']['gating']['eligible']:
        raise ValueError('Gating output differs from selection receipt')
    extraction = os.environ['EXTRACTION_SELECTED']
    if extraction not in {'true', 'false'}:
        raise ValueError('Missing extraction selection')
    attempts = dict(baseline=args.baseline_attempt, compile=args.compile_attempt,
                    current=os.environ.get('GITHUB_RUN_ATTEMPT'))
    errors = aggregate(plan, json.loads(Path(args.baseline).read_text(encoding='utf-8')),
                       json.loads(Path(args.compile_receipt).read_text(encoding='utf-8')),
                       jobs, extraction == 'true', attempts)
    receipt = dict(schema_version=1, kind='aggregate', status='failed' if errors else 'passed',
                   **{key: plan[key] for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt')},
                   job_attempt=attempts['current'], receipt_attempts=attempts,
                   selection_sha256=digest(plan), jobs=jobs, errors=errors,
                   action=plan['action'], eligibility=plan['eligibility'],
                   coverage='gating' if gating == '1' else 'informational')
    write_json(args.output, receipt)
    print(json.dumps(receipt, indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())

