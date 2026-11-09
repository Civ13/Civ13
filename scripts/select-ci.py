"""Fail-closed compilation selection and bounded reviewed offline impact selection."""
import argparse
import os
import json
import re
from pathlib import Path, PurePosixPath
import importlib.util
import subprocess

DOC_WORKFLOWS = {'.github/workflows/api-docs.yml', '.github/workflows/api-pages.yml'}
CI_BASES = {'master', 'help-markdown-byond-html'}
ORDINARY_PR_ACTIONS = {'opened', 'synchronize', 'reopened'}
# Reviewed source preparation, not native entry points. These exact files retain
# ci_baseline's named preparation suites; never exempt a whole directory.
SOURCE_PREPARATION_ONLY_TESTS = frozenset({
    'tests/world_save/character_return/fixture.dm',
    'tests/world_save/character_return/prepare.py',
    'tests/world_save/character_return/test_prepare.py',
    'tests/tree_refresh_native/d3dx_data.py',
    'tests/tree_refresh_native/d3dx-signature.ps1',
    'tests/tree_refresh_native/test_d3dx_data.py',
})

# Exact source-only suite runs in the reviewed bounded offline baseline.
AXE_ACTIVE_HAND_OFFLINE_TESTS = frozenset({'tests/axe_active_hand/test_axe_active_hand.py'})

# These exact tests run in their respective offline baseline suites.
PLAYER_HELP_OFFLINE_TESTS = frozenset({'tests/player_help/test_help_links.py',
                                      'tests/player_help/test_wiki_guides.py',
                                      'tests/player_help/test_toxin_context.py'})

# Exact stdlib-only production projections, registered in the offline baseline.
RESOURCE_WORK_OFFLINE_TESTS = frozenset({'tests/test_resource_work_animation.py'})

# This exact storage regression is a stdlib-only source projection, not a native fixture.
STORAGE_RUNTIME_OFFLINE_TESTS = frozenset({'tests/storage_runtime/test_storage_runtime.py'})

# This exact pouch HUD test is an offline source projection.
POUCH_HUD_OFFLINE_TESTS = frozenset({'tests/pouch_hud/test_pouch_hud.py'})

# Exact source-only suite runs in the reviewed bounded offline baseline.
STONE_BRAZIER_OFFLINE_TESTS = frozenset({'tests/stone_brazier/test_stone_brazier_disposal.py'})

# Exact source-only suite runs in the reviewed bounded offline baseline.
WELL_SMELL_OFFLINE_TESTS = frozenset({'tests/well_smell/test_well_smell.py'})

# Exact template/source-only suite runs in the reviewed bounded offline baseline.
SHOWCASE_ROOMS_OFFLINE_TESTS = frozenset({'tests/showcase_rooms/test_templates.py'})
DOOR_INTENTS_OFFLINE_TESTS = frozenset({'tests/door_intents/test_door_intents.py'})
FLINT_MINING_OFFLINE_TESTS = frozenset({'tests/flint_mining/test_flint_mining.py'})
# The extracted-proc probe needs BYOND; it is run by hand, not admitted to CI.
FLINT_MINING_MANUAL_NATIVE = frozenset({'tests/flint_mining/run.py', 'tests/flint_mining/probe.dm'})
RESEARCH_STAFF_OFFLINE_TESTS = frozenset({'tests/research_staff/test_research_staff.py'})
MAP_TOOLS_OFFLINE_TESTS = frozenset({'tests/map_tools/test_map_tools.py'})
SWEEP_LOOPS_OFFLINE_TESTS = frozenset({'tests/sweep_loops/test_sweep_loops.py'})
HELD_MOVEMENT_OFFLINE_TESTS = frozenset({'tests/held_movement/test_held_movement.py'})
INVENTORY_DRAG_OFFLINE_TESTS = frozenset({'tests/inventory_drag/test_inventory_drag.py'})
NOMADS_ADOPTION_OFFLINE_TESTS = frozenset({'tests/nomads_adoption/test_nomads_adoption.py'})
SAVESTREAM_OFFLINE_TESTS = frozenset({'tests/savestream/test_helper.py', 'tests/savestream/helper_client.py'})
# The native round trip needs gcc-multilib and BYOND; it is run by hand, not admitted to CI.
SAVESTREAM_MANUAL_NATIVE = frozenset({'tests/savestream/run_native.py', 'tests/savestream/roundtrip/fixture.dm'})
AGENT_CONTROL_OFFLINE_TESTS = frozenset({
    'tests/agent_control/test_agent_control.py',
    'tests/agent_control/test_perception_replay.py',
    'tests/agent_control/test_visibility.py',
    'tests/agent_control/test_action_contract.py',
    'tests/agent_control/test_navigation_replay.py',
})
# Explicitly opt-in source-bound fixture; do not admit its native runner to CI.
AGENT_CONTROL_MANUAL_NATIVE = frozenset({
    'tests/agent_control/visibility/prepare.py',
    'tests/agent_control/visibility/run.py',
    'tests/agent_control/visibility/adapters.dm',
    'tests/agent_control/visibility/probe.dm',
})
# Player-parity probes (docs/agent-player-parity.md), run by hand with
# tests/ecology_spawning/run_linux.py; never auto-run on addition.
AGENT_PARITY_MANUAL_NATIVE = frozenset({
    'tests/agent_control/windows_probe.dm',
    'tests/agent_control/prompts_probe.dm',
    'tests/agent_control/stance_probe.dm',
    'tests/agent_control/move_probe.dm',
    'tests/agent_control/vehicle_probe.dm',
})
# Included only by the existing opt-in observe fixture; never auto-run on addition.
AGENT_OBSERVE_MANUAL_NATIVE = frozenset({'tests/agent_observe/action_contract_probe.dm'})
AGENT_CI_DIGEST_OFFLINE_TESTS = frozenset({'tests/agent_ci_digest/test_ci_digest.py'})
LOCAL_CI_OFFLINE_TESTS = frozenset({'tests/local_ci/test_local_ci.py'})
FARMERS_ALMANAC_OFFLINE_TESTS = frozenset({'tests/farmers_almanac/test_farmers_almanac.py'})
CROSSROADS_MALL_OFFLINE_TESTS = frozenset({'tests/crossroads_mall/test_crossroads_mall.py',
                                           'tests/crossroads_mall/build.py'})
MAP_VARIATIONS_OFFLINE_TESTS = frozenset({'tests/map_variations/test_map_variations.py',
                                          'tests/map_variations/build_inserts.py',
                                          'tests/map_variations/native_probe.py',
                                          'tests/map_variations/native_probe.dm'})
TRAIN_RAID_OFFLINE_TESTS = frozenset({'tests/train_raid/test_train_raid.py', 'tests/train_raid/build.py',
                                      'tests/train_raid/native_probe.py', 'tests/train_raid/native_probe.dm'})
ZOMBIE_CITY_OFFLINE_TESTS = frozenset({'tests/zombie_city/test_zombie_city.py', 'tests/zombie_city/build_base.py',
                                       'tests/zombie_city/check.py', 'tests/zombie_city/native_probe.py',
                                       'tests/zombie_city/native_probe.dm', 'tests/zombie_city/horde_probe.py',
                                       'tests/zombie_city/horde_probe.dm'})
SAFEHOUSE_MAP_OFFLINE_TESTS = frozenset({'tests/safehouse_map/test_layout.py', 'tests/safehouse_map/build_map.py',
                                         'tests/safehouse_map/validate_map.py', 'tests/safehouse_map/compile_map.py',
                                         'tests/safehouse_map/preview.py'})
GAIA_HOST_OFFLINE_TESTS = frozenset({'tests/gaia_host/test_gaia_host.py', 'tests/gaia_host/test_shard_group.py',
                                     'tests/gaia_host/test_doorman.py', 'tests/gaia_host/test_wait_group.py',
                                     'tests/gaia_host/test_relay.py', 'tests/gaia_host/test_mobile_host.py'})
MEDICAL_CARE_OFFLINE_TESTS = frozenset({'tests/medical_care/test_source.py'})
# Offline source contract plus the opt-in native fixture (run by hand, not CI).
FIREMAN_CARRY_OFFLINE_TESTS = frozenset({'tests/fireman_carry/test_source.py', 'tests/fireman_carry/probe.dm',
                                         'tests/fireman_carry/run_native.py'})

# Exact stdlib-only mood projections, registered in the bounded offline baseline.
MOOD_SLEEP_OFFLINE_TESTS = frozenset({'tests/mood_sleep/test_mood_sleep.py'})

# These existing Atlas tests are reviewed exceptions to added-test selection.
# Exact paths keep unrelated edits from requesting costly native fixtures.
ATLAS_TEST_INPUTS = {
    'tests/test_crafting_atlas.py': 'tests/test_crafting_atlas.py',
    'tests/crafting_atlas/probe.dm': 'tests/crafting_atlas',
    'tests/crafting_atlas/resource-search.test.mjs': 'tests/crafting_atlas',
}


def starts_build(message):
    """The first line is literal data, with no case folding or whitespace trim."""
    return isinstance(message, str) and message.split('\n', 1)[0].startswith('build:')


def load_event(path):
    try:
        with open(path, encoding='utf-8') as event_file:
            event = json.load(event_file)
        return event if isinstance(event, dict) else {}
    except (OSError, ValueError, TypeError):
        return {}


def edited_change_kind(payload):
    """Recognize title/body edits and base retargets; ambiguous data is invalid."""
    pr = payload.get('pull_request')
    if not isinstance(pr, dict) or not isinstance(pr.get('title'), str) or not pr['title']:
        return 'invalid'
    if 'body' not in pr or not (pr['body'] is None or isinstance(pr['body'], str)):
        return 'invalid'
    for field in ('head', 'base'):
        row = pr.get(field)
        if not isinstance(row, dict) or not isinstance(row.get('sha'), str) or not re.fullmatch(r'[0-9a-f]{40}', row['sha']):
            return 'invalid'
    changes = payload.get('changes')
    if not isinstance(changes, dict) or not changes or not set(changes) <= {'title', 'body', 'base'}:
        return 'invalid'
    for field in ('title', 'body'):
        if field in changes:
            row = changes[field]
            if not isinstance(row, dict) or set(row) != {'from'}:
                return 'invalid'
            if not isinstance(row['from'], str) and not (field == 'body' and row['from'] is None):
                return 'invalid'
            if row['from'] == pr[field] or field == 'title' and not row['from']:
                return 'invalid'
    if 'base' in changes:
        base = changes['base']
        if not isinstance(base, dict) or not set(base) <= {'ref', 'sha'} or 'ref' not in base:
            return 'invalid'
        ref = base['ref']
        if not isinstance(ref, dict) or set(ref) != {'from'} or not isinstance(ref['from'], str) or not ref['from']:
            return 'invalid'
        if 'sha' in base:
            old_sha = base['sha']
            if not isinstance(old_sha, dict) or set(old_sha) != {'from'} or not isinstance(old_sha['from'], str):
                return 'invalid'
        return 'retarget'
    return 'text'


def build_policy(event, payload):
    """Return ordinary eligibility and a compile-only request.

    Expanded subscriptions must not expand introduced-test/native eligibility.
    Missing or capped push metadata conservatively requests only compilation.
    """
    if event == 'workflow_dispatch':
        return True, False
    if event == 'push':
        if payload.get('deleted') is True:
            return False, False
        ordinary = payload.get('ref') == 'refs/heads/master'
        commits = payload.get('commits')
        if not isinstance(commits, list) or not commits or len(commits) >= 2048:
            return ordinary, True
        if any(not isinstance(commit, dict) or not isinstance(commit.get('message'), str)
               for commit in commits):
            return ordinary, True
        # Some event producers also report a size; refuse to treat a partial
        # list as proof that no pushed commit requested a build.
        size = payload.get('size', len(commits))
        if not isinstance(size, int) or size > len(commits):
            return ordinary, True
        return ordinary, any(starts_build(commit['message']) for commit in commits)
    if event == 'pull_request':
        pr = payload.get('pull_request')
        if not isinstance(pr, dict) or not isinstance(pr.get('title'), str):
            return False, True
        base = pr.get('base', {})
        ordinary = (isinstance(base, dict)
                    and base.get('ref') in CI_BASES
                    and payload.get('action') in ORDINARY_PR_ACTIONS)
        return ordinary, starts_build(pr['title'])
    return False, False


def eligibility(event, payload, build_prefix):
    """Separate compiler work, unchanged native admission and check identity.

    A compile-only event cannot replace a full ordinary scope's native verdict.
    Missing scope metadata is not evidence for an informational classification.
    """
    ordinary, forced = build_policy(event, payload) if build_prefix else (True, False)
    action = payload.get('action')
    base_ref = None
    metadata_valid, supported_edit, gating, skip_duplicate = True, False, False, False
    scope_reason = 'Event outside full ordinary CI scope'
    if event == 'pull_request':
        pr = payload.get('pull_request')
        base = pr.get('base') if isinstance(pr, dict) else None
        base_ref = base.get('ref') if isinstance(base, dict) else None
        metadata_valid = (isinstance(pr, dict) and isinstance(pr.get('title'), str) and bool(pr['title'])
                          and isinstance(base, dict) and isinstance(base.get('ref'), str) and bool(base['ref'])
                          and isinstance(action, str) and bool(action))
        kind = edited_change_kind(payload) if action == 'edited' and build_prefix else None
        if kind == 'invalid':
            metadata_valid = False
        supported = metadata_valid and base['ref'] in CI_BASES
        if kind == 'retarget':
            # Existing native gates explicitly exclude edited events. Do not claim
            # a full retarget check until those gates can admit and verify it.
            metadata_valid = False
        supported_edit = supported and action == 'edited' and kind != 'retarget'
        gating = supported and action in ORDINARY_PR_ACTIONS
        skip_duplicate = bool(build_prefix and metadata_valid and kind == 'text' and not forced)
        scope_reason = ('Full ordinary PR admission' if gating else
                        'Edited PR omits introduced/native admission' if supported_edit else
                        'PR outside full ordinary base/action scope')
    elif event == 'push':
        metadata_valid = isinstance(payload.get('ref'), str) and bool(payload.get('ref'))
        gating = (metadata_valid and payload['ref'] == 'refs/heads/master'
                  and payload.get('deleted') is not True)
        scope_reason = 'Full ordinary master-push scope' if gating else 'Non-master/deleted push omits full PR coverage'
    elif event == 'workflow_dispatch':
        scope_reason = 'Manual opt-ins do not replace ordinary PR coverage'
    if not build_prefix:
        # Other reusable callers keep their pre-existing selection behavior.
        metadata_valid = True
    elif not metadata_valid:
        scope_reason = 'Missing event scope metadata; selection must fail closed'
    compile_eligible = (ordinary or supported_edit or forced) and not skip_duplicate
    compile_reason = ('Manual CI requires compilation and the native toolchain' if build_prefix and event == 'workflow_dispatch' else
                      'Validated title/body edit reuses existing required checks' if skip_duplicate else
                      'Explicit build: request or incomplete metadata requires compilation' if forced else
                      'Supported edited PR: evaluate exact base/head diff' if supported_edit else
                      'Ordinary/legacy event: evaluate exact base/head diff' if ordinary else
                      'Outside automatic compilation scope')
    native_reason = ('Legacy reusable caller retains its existing admission' if not build_prefix else
                     'Existing ordinary PR introduced-suite admission' if ordinary and event == 'pull_request' else
                     'Existing master-push policy; introduced PR suites remain off' if ordinary and event == 'push' else
                     'Manual extensive admission still requires its explicit input' if ordinary else
                     'No introduced/native or extensive admission for this event')
    return dict(action=action if isinstance(action, str) else None, skip_duplicate=skip_duplicate,
                base_ref=base_ref if isinstance(base_ref, str) else None,
                ref=payload.get('ref') if isinstance(payload.get('ref'), str) else None,
                metadata_valid=metadata_valid,
                compile=dict(eligible=compile_eligible, reason=compile_reason),
                native=dict(eligible=ordinary, reason=native_reason),
                gating=dict(eligible=bool(gating), reason=scope_reason), forced=forced)


def selections(base, head, event, opted_in, build_prefix=False, payload=None):
    policy = eligibility(event, payload or {}, build_prefix)
    if policy['skip_duplicate']:
        return False, False, [], 'Validated title/body edit; reuse existing required checks'
    game, reason = select(base, head) if policy['compile']['eligible'] else (False, 'Outside ordinary CI subscription')
    if build_prefix and event == 'workflow_dispatch':
        # Manual inputs can request native fixtures independently of the diff.
        # The build job also installs their BYOND toolchain.
        game, reason = True, 'Manual CI run; compile game and prepare native toolchain'
    elif policy['forced']:
        game, reason = True, 'build: request or incomplete event metadata; compile game'
    new_tests = (sorted(set(introduced_tests(base, head, event)) |
                        set(changed_atlas_tests(base, head, event)))
                 if policy['native']['eligible'] else [])
    extensive = policy['native']['eligible'] and game and needs_extensive(event, opted_in)
    return game, extensive, new_tests, reason

def skill_prose(path):
    parts = path.split('/')
    return (len(parts) >= 4 and parts[:2] == ['.agents', 'skills']
            and all(part not in ('', '.', '..') for part in parts)
            and (parts[-1] == 'SKILL.md'
                 or ('references' in parts[3:-1] and parts[-1].endswith('.md'))))


def needs_game(paths):
    # Compilation depends on shared includes. Unknown paths compile, but do
    # not implicitly authorize running existing regression suites.
    return any(PurePosixPath(path).suffix.lower() in {'.dm', '.dme', '.dmm', '.dmi', '.rsc'} or not (
        skill_prose(path) or path.startswith('docs/') or
        (len(PurePosixPath(path).parts) == 1 and path.endswith('.md')) or
        path == 'scripts/build-api-docs.py' or path in DOC_WORKFLOWS or non_game(path)
    ) for path in paths)


# Prose and repository metadata that DreamMaker never reads. Markdown under the
# game, map, config, UI and wiki trees keeps compiling in case runtime code reads
# it; skill files outside the reviewed prose keep their conservative selection.
NON_GAME_FILES = {'LICENSE', 'LICENSE.md', '.gitattributes', '.gitignore', '.editorconfig'}
NON_GAME_MARKDOWN_EXCLUDED_ROOTS = {'.agents', 'code', 'maps', 'config', 'wiki', 'html', 'UI', 'tgui'}


def non_game(path):
    parts = PurePosixPath(path).parts
    if not parts or any(part in ('', '.', '..') for part in parts):
        return False
    if path in NON_GAME_FILES or (parts[0] == '.claude' and path.endswith('.md')):
        return True
    return path.endswith('.md') and parts[0] not in NON_GAME_MARKDOWN_EXCLUDED_ROOTS

def select(base, head):
    if not base or not head or set(base) == {'0'}:
        return True, 'No reliable comparison; compile game'
    try:
        paths = subprocess.check_output(
            ['git', 'diff', '--name-only', '--no-renames', '-z', base, head],
            stderr=subprocess.PIPE, timeout=15).decode('utf-8').split('\0')
    except (subprocess.SubprocessError, UnicodeError):
        return True, 'Comparison unavailable; compile game'
    paths = [path for path in paths if path]
    game = needs_game(paths)
    return game, 'Game/shared/unknown changes' if game else 'Only documentation generation or prose changed'

def needs_extensive(event, opted_in):
    return event == 'workflow_dispatch' and opted_in


def atlas_comparison(base, head):
    spec = importlib.util.spec_from_file_location('atlas_checkout_refs', Path(__file__).with_name('ci_checkout_refs.py'))
    refs = importlib.util.module_from_spec(spec); spec.loader.exec_module(refs)
    try:
        return refs.atlas_pr_comparison(base, head)
    except (ValueError, RuntimeError, subprocess.SubprocessError, OSError, UnicodeError) as error:
        raise RuntimeError('Atlas test selection could not prove base and head ancestry') from error


def changed_atlas_tests(base, head, event):
    """Select only explicitly reviewed Atlas test edits on ordinary PRs."""
    if event != 'pull_request':
        return []
    if not base or not head or set(base) == {'0'}:
        raise RuntimeError('Atlas test selection requires a valid base and head comparison')
    proof = atlas_comparison(base, head)
    try:
        paths = subprocess.check_output(
            ['git', '--no-replace-objects', 'diff', '--name-only', '--no-renames', '--diff-filter=AM', '-z',
             proof['ancestor'], head, '--', *ATLAS_TEST_INPUTS],
            stderr=subprocess.PIPE, timeout=15).decode('utf-8').split('\0')
    except (subprocess.SubprocessError, OSError, UnicodeError) as exc:
        raise RuntimeError('Atlas test selection could not compare base and head; check Git and the refs') from exc
    return sorted({ATLAS_TEST_INPUTS[path] for path in paths if path in ATLAS_TEST_INPUTS})


def select_mcp(base, head, event):
    """Select the offline MCP workflow without expanding native suite admission."""
    if event == 'workflow_dispatch' or (event == 'push' and (not base or set(base) == {'0'})):
        return True
    if not base or not head or set(base) == {'0'}:
        raise RuntimeError('MCP selection requires a valid base and head comparison')
    try:
        paths = subprocess.check_output(
            ['git', 'diff', '--name-only', '--no-renames', '-z', base, head],
            stderr=subprocess.PIPE, timeout=15).decode('utf-8').split('\0')
    except (subprocess.SubprocessError, OSError, UnicodeError) as exc:
        raise RuntimeError('MCP selection could not compare base and head') from exc
    return any(path.startswith('tools/mcp/') or path in {
        '.github/workflows/mcp.yml', 'scripts/select-ci.py', 'tests/test_ci_selection.py',
        'scripts/ci_checkout_refs.py', 'tests/test_ci_checkout_refs.py',
        'scripts/nomads-lifecycle/agent_debug.py',
        'scripts/nomads-lifecycle/variable_observability.py',
        'scripts/nomads-lifecycle/read_blackout.py',
        'tests/nomads_lifecycle/test_agent_debug.py',
        'tests/nomads_lifecycle/test_variable_observability.py',
        # Fixed production readers and phase-contract inputs; no general DM glob.
        'code/modules/persistence/functions.dm', 'code/modules/persistence/saving.dm',
        'code/modules/persistence/restart_transaction.dm',
        'code/modules/persistence/nomads_lifecycle.dm',
        'code/modules/persistence/variable_observability.dm',
        'code/modules/persistence/zone_topology.dm'
    } for path in paths)


def introduced_tests(base, head, event):
    """Only added executable tests on a PR qualify, never edits or prose.

    Rename detection stays enabled so moving an existing test is not treated
    as introducing integration coverage. Missing comparisons select no suites.
    """
    if event != 'pull_request' or not base or not head or set(base) == {'0'}:
        return []
    try:
        paths = subprocess.check_output(
            ['git', 'diff', '--name-only', '--diff-filter=A', '-M', '-z', base, head],
            stderr=subprocess.PIPE, timeout=15).decode('utf-8').split('\0')
    except (subprocess.SubprocessError, UnicodeError):
        return []
    suites = set()
    for path in paths:
        if path in MOOD_SLEEP_OFFLINE_TESTS:
            continue
        if path.startswith('tests/mood_sleep/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered mood-sleep executable test requires explicit CI review')
        if path in WELL_SMELL_OFFLINE_TESTS:
            continue
        if path.startswith('tests/well_smell/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered well-smell executable test requires explicit CI review')
        if path in SHOWCASE_ROOMS_OFFLINE_TESTS:
            continue
        if path in GAIA_HOST_OFFLINE_TESTS:
            continue
        if path.startswith('tests/gaia_host/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered gaia-host executable test requires explicit CI review')
        if path.startswith('tests/showcase_rooms/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered showcase-room executable test requires explicit CI review')
        if path in FARMERS_ALMANAC_OFFLINE_TESTS:
            continue
        if path in CROSSROADS_MALL_OFFLINE_TESTS:
            continue
        if path in SAFEHOUSE_MAP_OFFLINE_TESTS:
            continue
        if path.startswith('tests/safehouse_map/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered safehouse-map executable test requires explicit CI review')
        if path.startswith('tests/crossroads_mall/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered crossroads-mall executable test requires explicit CI review')
        if path in TRAIN_RAID_OFFLINE_TESTS:
            continue
        if path in MAP_VARIATIONS_OFFLINE_TESTS:
            continue
        if path.startswith('tests/map_variations/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered map-variations executable test requires explicit CI review')
        if path.startswith('tests/train_raid/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered train-raid executable test requires explicit CI review')
        if path in ZOMBIE_CITY_OFFLINE_TESTS:
            continue
        if path.startswith('tests/zombie_city/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered zombie-city executable test requires explicit CI review')
        if path.startswith('tests/farmers_almanac/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered farmers-almanac executable test requires explicit CI review')
        if path in FLINT_MINING_OFFLINE_TESTS or path in FLINT_MINING_MANUAL_NATIVE:
            continue
        if path.startswith('tests/flint_mining/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered flint-mining executable test requires explicit CI review')
        if path in DOOR_INTENTS_OFFLINE_TESTS:
            continue
        if path in MAP_TOOLS_OFFLINE_TESTS:
            continue
        if path.startswith('tests/map_tools/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered map-tools executable test requires explicit CI review')
        if path in RESEARCH_STAFF_OFFLINE_TESTS:
            continue
        if path.startswith('tests/research_staff/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered research-staff executable test requires explicit CI review')
        if path in FIREMAN_CARRY_OFFLINE_TESTS:
            continue
        if path.startswith('tests/fireman_carry/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered fireman-carry executable test requires explicit CI review')
        if path in MEDICAL_CARE_OFFLINE_TESTS:
            continue
        if path.startswith('tests/medical_care/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered medical-care executable test requires explicit CI review')
        if path in SWEEP_LOOPS_OFFLINE_TESTS:
            continue
        if path.startswith('tests/sweep_loops/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered sweep-loop executable test requires explicit CI review')
        if path in HELD_MOVEMENT_OFFLINE_TESTS:
            continue
        if path.startswith('tests/held_movement/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered held-movement executable test requires explicit CI review')
        if path in INVENTORY_DRAG_OFFLINE_TESTS:
            continue
        if path.startswith('tests/inventory_drag/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered inventory-drag executable test requires explicit CI review')
        if path.startswith('tests/door_intents/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered door-intent executable test requires explicit CI review')
        if path in NOMADS_ADOPTION_OFFLINE_TESTS:
            continue
        if path in SAVESTREAM_OFFLINE_TESTS or path in SAVESTREAM_MANUAL_NATIVE:
            continue
        if path.startswith('tests/savestream/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered savestream executable test requires explicit CI review')
        if path in AGENT_CONTROL_OFFLINE_TESTS or path in AGENT_CONTROL_MANUAL_NATIVE or path in AGENT_OBSERVE_MANUAL_NATIVE or path in AGENT_PARITY_MANUAL_NATIVE:
            continue
        if path in AGENT_CI_DIGEST_OFFLINE_TESTS:
            continue
        if path in LOCAL_CI_OFFLINE_TESTS:
            continue
        if path.startswith('tests/local_ci/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered local-ci executable test requires explicit CI review')
        if path.startswith('tests/agent_ci_digest/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered agent-ci-digest executable test requires explicit CI review')
        if path.startswith('tests/agent_control/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered agent-control executable test requires explicit CI review')
        if path.startswith('tests/nomads_adoption/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered nomads-adoption executable test requires explicit CI review')
        if path in STONE_BRAZIER_OFFLINE_TESTS:
            continue
        if path.startswith('tests/stone_brazier/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered stone-brazier executable test requires explicit CI review')
        if path in SOURCE_PREPARATION_ONLY_TESTS or path in PLAYER_HELP_OFFLINE_TESTS or path in RESOURCE_WORK_OFFLINE_TESTS or path in STORAGE_RUNTIME_OFFLINE_TESTS or path in POUCH_HUD_OFFLINE_TESTS:
            continue
        if path in AXE_ACTIVE_HAND_OFFLINE_TESTS:
            continue
        if path.startswith('tests/axe_active_hand/') and PurePosixPath(path).suffix.lower() in {'.py', '.ps1', '.dm', '.sh'}:
            raise RuntimeError('Unregistered axe active-hand executable test requires explicit CI review')
        parts = PurePosixPath(path).parts
        suffix = PurePosixPath(path).suffix.lower()
        if len(parts) >= 2 and parts[0] == 'tests' and suffix in {'.py', '.ps1', '.dm', '.sh'}:
            suites.add('/'.join(parts[:2]))
        elif path in {'scripts/opendream/bounded_build/test_guard.py',
                      'scripts/opendream/bounded_build/test_windows.py'}:
            suites.add('scripts/opendream/bounded_build')
        elif path.startswith('tools/') and (path.endswith('.test.mjs') or path.endswith('.test.js')):
            suites.add('/'.join(parts[:2]))
    return sorted(suites)


def validate_manual_base(base, head, cwd=None):
    """Manual runs need explicit immutable, locally available distinct commits."""
    if not re.fullmatch(r'[0-9a-f]{40}', base or '') or not re.fullmatch(r'[0-9a-f]{40}', head or ''):
        raise ValueError('Manual CI requires comparison_base and head as full lowercase 40-character commit IDs')
    if base == head:
        raise ValueError('Manual comparison_base must differ from the head commit')
    try:
        for value in (base, head):
            resolved = subprocess.check_output(['git', 'rev-parse', '--verify', value + '^{commit}'],
                                               cwd=cwd, stderr=subprocess.PIPE, timeout=15).decode('utf-8').strip()
            if resolved != value:
                raise ValueError('Manual comparison commit identity mismatch')
    except (subprocess.SubprocessError, UnicodeError) as exc:
        raise ValueError('Manual comparison_base or head is unavailable in the local checkout') from exc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', default='')
    parser.add_argument('--head', default='')
    parser.add_argument('--output', required=True)
    parser.add_argument('--event', default='')
    parser.add_argument('--extensive', choices=('true', 'false'), default='false')
    parser.add_argument('--build-prefix', choices=('true', 'false'), default='false')
    parser.add_argument('--receipt', help='Exact-source machine-readable selection receipt')
    parser.add_argument('--mcp-only', action='store_true', help='Select the independent offline MCP workflow')
    args = parser.parse_args()
    if args.mcp_only:
        try:
            selected = select_mcp(args.base, args.head, args.event)
        except RuntimeError as error:
            parser.error(str(error))
        with open(args.output, 'a', encoding='utf-8') as output:
            output.write(f'mcp={str(selected).lower()}\n')
        return
    if args.event == 'workflow_dispatch' and args.build_prefix == 'true':
        try:
            validate_manual_base(args.base, args.head)
        except ValueError as error:
            parser.error(str(error))
    payload = load_event(os.environ.get('GITHUB_EVENT_PATH'))
    policy = eligibility(args.event, payload, args.build_prefix == 'true')
    if args.build_prefix == 'true' and args.event == 'pull_request' and payload.get('action') == 'edited':
        pr = payload.get('pull_request')
        if (not isinstance(pr, dict) or not isinstance(pr.get('head'), dict)
                or not isinstance(pr.get('base'), dict) or pr['head'].get('sha') != args.head
                or pr['base'].get('sha') != args.base):
            policy['metadata_valid'] = False
            policy['skip_duplicate'] = False
    atlas_proof = None
    if args.event == 'pull_request' and policy['native']['eligible']:
        pr = payload.get('pull_request', {})
        if pr.get('base', {}).get('sha') != args.base or pr.get('head', {}).get('sha') != args.head:
            raise RuntimeError('Atlas test selection requires matching event base and head')
        atlas_proof = atlas_comparison(args.base, args.head)
    game, extensive, new_tests, reason = selections(
        args.base, args.head, args.event, args.extensive == 'true',
        args.build_prefix == 'true', payload)
    if args.receipt:
        from ci_baseline import selection_receipt, write_json
        receipt = selection_receipt(args.base, args.head, game, extensive,
                                    new_tests, reason, args.event, policy, payload)
        if atlas_proof is not None:
            receipt['atlas_comparison'] = atlas_proof
        if not policy['metadata_valid']:
            receipt['status'] = 'failed'
        write_json(args.receipt, receipt)
    if not policy['metadata_valid']:
        parser.error('Missing event scope metadata; refusing to publish informational success')
    with open(args.output, 'a', encoding='utf-8') as output:
        if atlas_proof is not None:
            output.write('atlas_ancestor=' + atlas_proof['ancestor'] + '\n')
        output.write('new_tests=' + json.dumps(new_tests, separators=(',', ':')) + '\n')
        output.write(f'game={str(game).lower()}\nextensive={str(extensive).lower()}\n')
        output.write(f'gating={int(policy["gating"]["eligible"])}\n')
        output.write(f'skip_duplicate={str(policy["skip_duplicate"]).lower()}\n')
    print(f'game={str(game).lower()}, extensive={str(extensive).lower()}, introduced suites={new_tests}: {reason}')
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as output:
            output.write(f'Game compilation selected: **{game}**. Extensive regressions opted in: **{extensive}**. {reason}. New test suites selected: `{new_tests}`.\n')
            output.write(f'Gating context eligible: **{policy["gating"]["eligible"]}**. {policy["gating"]["reason"]}.\n')

if __name__ == '__main__':
    main()
