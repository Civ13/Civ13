"""Export a held source proposal only. Never install, compile, launch or capture."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = 'ff67d89241336d55f456967ec596d5cd10358df6'
HERE = Path(__file__).resolve().parent
REQUIRED = ('occluded_oversize', 'clear_root', 'ordinary_lit', 'weather',
            'intentional_fullbright', 'dynamic_to_fullbright', 'fullbright_to_dynamic',
            'turf_replacement', 'save_import', 'sight_bypass', 'sight_restore', 'hud_lifecycle',
            'fully_covered_warm', 'view_edge', 'other_oversized_assets')
CRITICAL = ('code/_onclick/hud/plane_master.dm', 'code/_onclick/hud/hud.dm',
            'code/game/objects/structures/wild.dm', 'code/modules/lighting/lighting_composition.dm',
            'code/modules/lighting/lighting_overlay.dm', 'code/modules/lighting/lighting_turf.dm',
            'code/modules/lighting/lighting_system.dm', 'code/modules/persistence/loading.dm',
            'code/game/area/areas.dm', 'code/game/turfs/turf_changing.dm',
            'code/game/mob/living/life.dm', 'code/game/mob/observer/ghost/ghost.dm',
            'code/modules/1713/weather.dm', 'code/processes/time_of_day_change.dm',
            'code/__defines/_planes+layers.dm', 'code/__defines/time_of_day.dm',
            'icons/obj/flora/pinetrees.dmi', 'icons/obj/flora/bigtrees.dmi',
            'icons/obj/flora/palm.dmi', 'icons/effects/weather.dmi',
            'icons/effects/icon.png', 'tools/byond/version.json', 'civ13.dme')


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, timeout=20)


def authored_map():
    grid = [['a'] * 15 for _ in range(13)]
    for x, y, key in ((8, 6, 'p'), (8, 7, 'h'), (7, 5, 'v')):
        grid[13 - y][x - 1] = key
    definitions = ['"a" = (/turf/floor/grass,/area/caribbean/forest)',
                   '"p" = (/obj/structure/wild/tree/live_tree/pine/lighting_capture,/turf/floor/grass,/area/caribbean/forest)',
                   '"h" = (/obj/effect/lighting_capture_marker,/turf/floor/grass,/area/caribbean/forest)',
                   '"v" = (/obj/effect/lighting_capture_marker,/turf/floor/grass,/area/caribbean/forest)']
    return '\n'.join(definitions) + '\n\n(1,1,1) = {"\n' + '\n'.join(''.join(row) for row in grid) + '\n"}\n'


def prepare(output):
    output = Path(output).absolute()
    if output.exists() or any(p.is_symlink() or getattr(p, 'is_junction', lambda: False)() for p in (output, *output.parents)):
        raise ValueError('Fresh non-reparse source-preparation directory required')
    tree = git('rev-parse', SOURCE + '^{tree}').decode().strip()
    raw_inventory = git('ls-tree', '-rz', '--long', SOURCE, '--', 'civ13.dme', 'code', 'icons', 'sound', 'UI', 'interface', 'config/names')
    sources = {path: hashlib.sha256(git('show', SOURCE + ':' + path)).hexdigest() for path in CRITICAL}
    scene = (HERE / 'capture_scene.dm').read_text()
    release = re.findall(r'^#define LIGHTING_CAPTURE_SCENE_RELEASED ([^\r\n]+)$', scene, re.M)
    if release != ['FALSE'] or '/world/New' in scene or '/client/New' in scene:
        raise ValueError('Scene must remain held and contain no admission entry point')
    plan = {
        'schema': 1, 'native_execution_ready': False, 'complete_project_materialized': False,
        'source_revision': SOURCE, 'source_tree': tree,
        'critical_source_sha256': sources, 'inventory_sha256': hashlib.sha256(raw_inventory).hexdigest(),
        'reference_controllers': {'tree': 'bdd08103f791c8ea9ca5d0aa688076f5f684b2f9',
                                  'viewport': '209e852bb81c25aaba53fa06ecf125ea532c7bc4'},
        'reference_runs': [40223669267, 40228533562], 'reference_scope': 'Capture mechanics only; not lighting acceptance',
        'runtime': {'version': '516.1688', 'platform': 'windows',
                    'reference_package_bytes': 8602470,
                    'reference_package_sha256': '9079f29b0747719233715dfeff223641e6fb69bd16b8ba9676d5cd42cfcd0148',
                    'identity_scope': 'Keep the reference complete vendor manifest, notices and same-run DirectX receipts; no new acquisition route'},
        'required_scenes': list(REQUIRED), 'next_scene': 'occluded_oversize + clear_root',
        'first_pair': {'jobs': 2, 'modes': [0, 1], 'captures_per_job': ['opaque-root', 'clear-root'],
                       'source_difference': 'DME compile define LIGHTING_COMPOSITION_V2 only',
                       'time_of_day': 'Night', 'weather': 'WEATHER_NONE',
                       'map': [15, 13, 1], 'camera': [8, 5, 1], 'tree': [8, 6, 1],
                       'hidden_marker': [8, 7, 1], 'visible_marker': [7, 5, 1],
                       'asset': ['icons/obj/flora/pinetrees.dmi', 'new_pine_1', 64, 96, -16, 0],
                       'viewport': {'client': [480, 480], 'view': 3, 'zoom': 2, 'letterbox_border': 16},
                       'hud': 'actual datum/hud constructor and update_lighting_plane; no screen-clearing shortcut'},
        'preserve_per_job_limits': {'workflow_minutes': 15, 'shared_work_seconds': 165,
                                    'process_private_bytes': 536870912, 'watcher_private_bytes': 134217728,
                                    'owned_process_cpu_seconds': 60, 'attempt': 1},
        'must_preserve': ['exact package/member/DirectX identities and same-run setup receipt',
                          'genuine guest admission, zero arbitrary input and no production account/config/save',
                          'owned desktop/window/foreground/480x480/occlusion guards before and after BitBlt',
                          'socket policy, expiry/ancestry guards, retained process identity and cleanup',
                          'original weather/fullbright/sight/occlusion/import/HUD controls and rejected evidence'],
        'pending': ['successful supported transfer and visual inspection of the supplied live screenshot',
                    'fresh owner-reviewed controller SHA/branch/message/sole-parent/deadline/run/job bindings',
                    'raw-blob current-source full-project manifest and review of every isolation derivative',
                    'reviewed fixture integration replacing tanning actions/recording and its zero-HUD screen contract',
                    'native compile/startup of this proposed scene, with unchanged capture/security/resource guards',
                    'independently reviewed pixel ownership/ROI oracle from source geometry and baseline native view, not candidate pixels'],
        'not_accepted': ['current-source pixels', 'production Login/HUD/weather/save-import lifecycle',
                         'performance', 'deployment', 'activation'],
    }
    output.mkdir(parents=True)
    (output / 'canopy.dmm').write_text(authored_map(), encoding='utf-8', newline='\n')
    (output / 'scene.dm').write_text(scene, encoding='utf-8', newline='\n')
    (output / 'source-inventory.git-tree').write_bytes(raw_inventory)
    for mode in (0, 1):
        # A prefix for the reviewed full-project DME, not a standalone world.
        (output / ('mode-' + str(mode) + '.dme-prefix')).write_text('#define LIGHTING_COMPOSITION_V2 ' + str(mode) + '\n', encoding='ascii')
    plan['generated_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir() if p.is_file()}
    (output / 'plan.json').write_text(json.dumps(plan, indent=2) + '\n')
    return plan


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.output), indent=2))
