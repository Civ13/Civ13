"""Stage disabled connected fixture source only. Never compiles or launches it."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[2]
HOOK_PATHS = ('code/world.dm', 'code/controllers/mc/globals.dm',
              'code/modules/1713/flax_processing.dm', 'code/game/objects/structures/table.dm',
              'code/game/objects/items/weapons/defib.dm', 'code/modules/chat/chat.dm')


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError('Scene staging source marker missing or ambiguous: ' + old[:100])
    return source.replace(old, new, 1)


def prepared_sources(root, prefix):
    sources = {path: (root/path).read_text(encoding='utf-8') for path in HOOK_PATHS}
    world = sources[HOOK_PATHS[0]]
    start = world.index('/world/New()')
    parent = world.index('\n\t..()', start)
    world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
    world = replace_once(world, '/world/New()', '/world/proc/unused_flax_connected_startup()')
    sources[HOOK_PATHS[0]] = replace_once(world, '/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n')
    sources[HOOK_PATHS[1]] = replace_once(sources[HOOK_PATHS[1]], '/datum/controller/global_vars/New()\n', '/datum/controller/global_vars/New()\n\treturn\n')
    flax = sources[HOOK_PATHS[2]]
    flax = replace_once(flax, '/mob/proc/flax_processing_wait(delay, atom/target)\n\treturn do_after(src, delay, target)',
        '/mob/proc/flax_processing_wait(delay, atom/target)\n'
        '\tif (flax_scene)\n\t\tflax_scene.wait_event(src, target, delay, FALSE, FALSE)\n'
        '\tvar/scene_wait_result = do_after(src, delay, target)\n'
        '\tif (flax_scene)\n\t\tflax_scene.wait_event(src, target, delay, TRUE, scene_wait_result)\n'
        '\treturn scene_wait_result')
    flax = replace_once(flax, '\tvar/obj/item/flax_bundle/B = new(T)\n',
        '\tvar/obj/item/flax_bundle/B = new(T)\n\tif (flax_scene)\n\t\tflax_scene.bound_bundle(B, user)\n')
    marker = '/obj/item/flax_bundle/afterattack(atom/target, mob/user, proximity)\n'
    sources[HOOK_PATHS[2]] = replace_once(flax, marker, marker+'\tif (flax_scene)\n\t\tflax_scene.dispatch("afterattack", user, src, target)\n')
    marker = '/obj/structure/table/MouseDrop_T(atom/movable/O, mob/user)\n'
    sources[HOOK_PATHS[3]] = replace_once(sources[HOOK_PATHS[3]], marker,
        marker+'\tif (flax_scene)\n\t\tflax_scene.dispatch("table", user, O, src)\n')
    marker = '/obj/item/weapon/defibrillator/proc/reattach_paddles(mob/user)\n'
    sources[HOOK_PATHS[4]] = replace_once(sources[HOOK_PATHS[4]], marker,
        marker+'\tif (flax_scene)\n\t\tflax_scene.dispatch("paddles", user, paddles, src)\n')
    chat = replace_once(sources[HOOK_PATHS[5]], '/proc/to_chat_wrapper(target, message)\n',
        '/proc/to_chat_wrapper(target, message)\n\tif (flax_scene)\n\t\tflax_scene.notice_sent(target, message)\n')
    sources[HOOK_PATHS[5]] = replace_once(chat, "'interface/chat/chat.html'", "'"+prefix+'_chat.html' + "'")
    return sources


def stage(root, output, head, prefix):
    if not re.fullmatch(r'\.flax_connected_[a-zA-Z0-9_]+', prefix):
        raise ValueError('Scene prefix must be task-owned')
    planned = [root/(prefix+'_'+str(index)+'.dm') for index in range(len(HOOK_PATHS))]
    planned += [root/(prefix+'_chat.html'), root/(prefix+'.dme')]
    if any(path.exists() for path in planned): raise ValueError('Preserve existing scene source')
    output.mkdir(parents=True, exist_ok=False)
    initial = {'head_sha': head, 'status':'preparing_source_only', 'native_launch_authorized':False,
               'acceptance_complete':False, 'automatic_deletion':False,
               'planned_paths':[str(path) for path in planned]}
    manifest_path = output/'scene-source-manifest.json'
    manifest_path.write_text(json.dumps(initial,indent=2)+'\n')
    try:
        return _stage(root, output, head, prefix)
    except BaseException as error:
        initial.update(status='source_preparation_failed', error_type=type(error).__name__, error=repr(error),
                       retained_paths=[str(path) for path in planned if path.exists()])
        manifest_path.write_text(json.dumps(initial,indent=2)+'\n')
        raise


def _stage(root, output, head, prefix):
    sources = prepared_sources(root, prefix)
    dme = (root/'civ13.dme').read_text(encoding='utf-8')
    generated = []
    for index, (relative, source) in enumerate(sources.items()):
        destination = root/(prefix+'_'+str(index)+'.dm')
        if destination.exists(): raise ValueError('Preserve existing scene source')
        destination.write_text(source, encoding='utf-8')
        generated.append(destination)
        include = '#include "'+relative.replace('/', '\\')+'"'
        dme = replace_once(dme, include, '#include "'+destination.name+'"')
    html = (root/'interface/chat/chat.html').read_text(encoding='utf-8')
    observer = (root/'tests/flax_processing/connected_notice_observer.js').read_text(encoding='utf-8')
    html = replace_once(html, '</body>', '<script>\n'+observer+'\n</script>\n</body>')
    html_path = root/(prefix+'_chat.html')
    html_path.write_text(html, encoding='utf-8')
    generated.append(html_path)
    dme = re.sub(r'^#include ".*\.dmm".*$', '', dme, flags=re.M)
    dme = '#define CIV13_FLAX_CONNECTED_SCENE\n#define FLAX_SCENE_REVIEWED_HEAD "'+head+'"\n'+dme
    dme += '\n#include "tests/flax_processing/connected_scene.dm"\n'
    entry = root/(prefix+'.dme')
    entry.write_text(dme, encoding='utf-8')
    generated.append(entry)
    snapshots = output/'generated-source'
    snapshots.mkdir()
    for path in generated: (snapshots/path.name).write_bytes(path.read_bytes())
    manifest = {'head_sha': head, 'status':'prepared_source_only', 'native_launch_authorized':False,
        'acceptance_complete':False, 'enabled_by_default':False, 'entry_point':str(entry),
        'activation_preconditions':['separately admitted exact-head isolated native execution',
            'flax_scene_enabled=1 and tested_commit='+head, 'one pinned 516.1688 native loopback client'],
        'native_or_graphical_validation':'unrun', 'expected_outputs':['connected-events.jsonl','connected-state.jsonl'],
        'generated':[{'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()} for path in generated],
        'source_sha256':{relative:hashlib.sha256((root/relative).read_bytes()).hexdigest() for relative in
            (*HOOK_PATHS,'civ13.dme','interface/chat/chat.html','tests/flax_processing/connected_scene.dm',
             'tests/flax_processing/connected_notice_observer.js')},
        'startup_adapters':['world/global-controller startup disabled','local-only fixture preferences/client Login/Topic/Del',
            'nomads_spawn suppressed; real base-human New/organs/inventory/drop/HUD/click/wait retained'],
        'observer_limits':'DOM report is client-reported; independent source/log/capture review is required',
        'automatic_deletion':False}
    (output/'scene-source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expected-head', required=True)
    args = parser.parse_args()
    head = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    if args.expected_head != head or subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=ROOT,text=True).strip():
        raise ValueError('Scene preparation requires exact clean reviewed tracked source')
    if not re.fullmatch('[0-9a-f]{40}',head): raise ValueError('Expected full reviewed commit')
    stage(ROOT,args.output.resolve(),head,'.flax_connected_'+uuid.uuid4().hex)
    print('Prepared disabled source only; no compiler, daemon, client or graphical launch')


if __name__ == '__main__': main()
