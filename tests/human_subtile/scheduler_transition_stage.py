"""Exact test-only native-call overlays. Not wired into any runtime selector."""
import re
import hashlib
import json
from pathlib import Path

ANIMAL='code/game/mob/living/simple_animal/simple_animal.dm'
AI='code/game/mob/living/simple_animal/simple_ai.dm'
CAT='code/game/mob/living/simple_animal/friendly/cat.dm'

# This mirrors the older scheduler fixture's narrow headless presence adapter.
# A real client, an anchored actor, and non-subject actors still use the normal gate.
CLIENT_GATE=(AI, '\tif (client || anchored || clients.len <= 0)\n',
    '\tif (client || anchored || (clients.len <= 0 && !(src in fixture_scheduler_test_subjects)))\n')

# Each marker runs only after the unchanged production call returns. The
# fixture's marker procedure ignores every actor except its test subject.
REPLACEMENTS=(
    (ANIMAL, '\t\t\t\t\t\twalk_to(src, following_mob, 1, 6)\n',
     '\t\t\t\t\t\twalk_to(src, following_mob, 1, 6)\n\t\t\t\t\t\tfixture_transition_command_return(src, "follow")\n'),
    (ANIMAL, '\t\t\twalk_to(src, movement_target, 0, 3)\n',
     '\t\t\twalk_to(src, movement_target, 0, 3)\n\t\t\tfixture_transition_command_return(src, "pet")\n'),
    (ANIMAL, '\t\t\twalk_away_od(src, flee_target, 7, 2)\n',
     '\t\t\twalk_away_od(src, flee_target, 7, 2)\n\t\t\tfixture_transition_command_return(src, "pet")\n'),
    (AI, '\t\t\t\t\twalk_away_od(src, H, 7, 2)\n\t\t\t\t\tspawn(50)\n\t\t\t\t\t\twalk(src, 0)\n',
     '\t\t\t\t\twalk_away_od(src, H, 7, 2)\n\t\t\t\t\tfixture_transition_command_return(src, "flee")\n\t\t\t\t\tspawn(50)\n\t\t\t\t\t\twalk(src, 0)\n\t\t\t\t\t\tfixture_transition_native_stop_return(src, "timer")\n'),
    (CAT, '\t\twalk(src,0)\n\t\tturns_since_scan = FALSE\n',
     '\t\twalk(src,0)\n\t\tfixture_transition_native_stop_return(src, "scan")\n\t\tturns_since_scan = FALSE\n'),
)

def instrument(sources):
    """Produce overlays only if all exact preimages are present once."""
    if set(sources)!={ANIMAL,AI,CAT}: raise ValueError('unexpected source inventory')
    staged=dict(sources)
    if any(type(text) is not str or 'fixture_transition_command_return' in text or
           'fixture_transition_native_stop_return' in text for text in staged.values()):
        raise ValueError('invalid or already instrumented source')
    for path,before,after in (CLIENT_GATE,)+REPLACEMENTS:
        if len(list(re.finditer('(?='+re.escape('\n'+before)+')',staged[path])))!=1:
            raise ValueError('ambiguous, misindented or missing preimage: '+path)
        staged[path]=staged[path].replace('\n'+before,'\n'+after,1)
    return staged


SCOPE='headless mob scheduler; native fallback only; no smooth/client parity'
PROBE='tests/human_subtile/probe.dm'
FIXTURE='tests/human_subtile/scheduler_core_draft.dm'
PROBE_REPLACEMENTS=(
    ('\t\t\thuman_subtile_fixture_headless()', '\t\t\tfixture_scheduler_transition_main()'),
    ('"checks" = human_subtile_fixture_checks,',
     '"checks" = human_subtile_fixture_checks, "transition_checks" = fixture_scheduler_checks, '
     '"transition_rows" = fixture_transition_rows, "transition_phase" = fixture_transition_phase, '
     '"transition_partial" = fixture_transition_events,'),
    ('"scope" = "actual human/codec; headless authority adapter"', '"scope" = "'+SCOPE+'"'),
)

def adapt_probe(source):
    for before,after in PROBE_REPLACEMENTS:
        if source.count(before)!=1: raise ValueError('probe preimage')
        source=source.replace(before,after,1)
    return source

def adapt(out,manifest,current):
    """Overlay only reviewed inputs inside an existing exact-Git stage."""
    out=Path(out);stage=out/'stage'
    paths=(ANIMAL,AI,CAT)
    original={p:(stage/p).read_text(encoding='utf-8') for p in paths}
    overlays=instrument(original)
    probe=(stage/PROBE).read_text(encoding='utf-8');changed_probe=adapt_probe(probe)
    fixture=stage/FIXTURE
    if not fixture.is_file(): raise ValueError('scheduler fixture absent')
    # Validate every preimage before making any stage mutation.
    dme=out/manifest['dme']
    if not dme.resolve().is_relative_to(stage.resolve()) or not dme.is_file():raise ValueError('fixture DME absent or outside stage')
    include='#include "tests\\human_subtile\\scheduler_core_draft.dm"'
    if include in dme.read_text(encoding='utf-8'):raise ValueError('fixture already included')
    if type(manifest.get('stage_files')) is not dict:raise ValueError('stage manifest missing')
    for path in paths:current.adapt(out,manifest,path,original[path],overlays[path])
    current.adapt(out,manifest,PROBE,probe,changed_probe)
    with dme.open('a',encoding='utf-8',newline='\n') as stream:
        stream.write('\n#include "tests\\human_subtile\\scheduler_core_draft.dm"\n')
    for path in (*paths,PROBE,dme.relative_to(stage).as_posix()):
        raw=(stage/path).read_bytes()
        manifest['stage_files'][path]={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    manifest['transition_scope']=SCOPE
    manifest['native_executed']=False
    (out/'transition-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
