"""Bounded fixture-only transition substitutions; never changes source checkout."""
import hashlib
from pathlib import Path

MOVEMENT='code/game/mob/living/simple_animal/subtile_movement.dm'
PROBE='tests/human_subtile/probe.dm'
RANDOM='tests/human_subtile/random_cadence_fixture.dm'
CORE='tests/human_subtile/scheduler_core_draft.dm'
FIXTURE='tests/human_subtile/transition_probe.dm'
MOVEMENT_BLOB='c658aa260cd486f5c8a82dc796e048c321362d54'
SPECIES={
    'code/game/mob/living/simple_animal/hostile/mosquitoes.dm':'9bea59584d822537d5fbeb446d95d7f9fb6b12d4',
    'code/game/mob/living/simple_animal/hostile/vampirebat.dm':'5cb84fe68311d5095a8369feabccdb00f7c745d8',
}


def git_blob(raw):
    return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()


def adapt(out, manifest, current, random, scope):
    out=Path(out); stage=out/'stage'
    for path,expected in {MOVEMENT:MOVEMENT_BLOB,**SPECIES}.items():
        if git_blob((stage/path).read_bytes()) != expected:
            raise ValueError('transition production blob mismatch: '+path)
    if not (stage/FIXTURE).is_file(): raise ValueError('missing transition fixture')
    changes=[
        (PROBE,'\tmaxx = 18\n\tmaxy = 14','\tmaxx = 65\n\tmaxy = 65'),
        (PROBE,'\t\t\tnpc_subtile_fixture()','\t\t\tfixture_transition_main()'),
        (PROBE,'"scope" = "actual human/codec; headless authority adapter"',
         '"scope" = "'+scope+'", "movement_blob" = "'+MOVEMENT_BLOB+'", '
         '"setup" = fixture_transition_setup, "transition_rows" = fixture_transition_rows, '
         '"transition_case" = fixture_transition_case, "transition_checks" = fixture_scheduler_checks, '
         '"transition_partial" = fixture_random_events, "overflow" = fixture_random_overflow'),
    ]
    changes += [(MOVEMENT,old,new) for old,new in random.movement_replacements('candidate')]
    old='list("mode" = mode, "lag" = lag, "speed_argument" = 0)'
    new='list("mode" = mode, "lag" = lag, "speed_argument" = 0, "direction" = direction)'
    identity_old='"pending" = P ? "\\ref[P]" : null,\n\t\t"active_tx"'
    identity_new=('"pending" = P ? "\\ref[P]" : null,\n'
                  '\t\t"recovery" = A.npc_subtile_recovery ? "\\ref[A.npc_subtile_recovery]" : null,\n'
                  '\t\t"tx_intent" = T && T.intent_owner ? "\\ref[T.intent_owner]" : null,\n\t\t"active_tx"')
    random_path=stage/RANDOM
    text=random_path.read_text(encoding='utf-8')
    if text.count(old)!=2 or text.count(identity_old)!=1: raise ValueError('transition observation preimage')
    for relative,old_value,new_value in changes:
        current.adapt(out,manifest,relative,old_value,new_value)
    random_path.write_text(text.replace(old,new).replace(identity_old,identity_new),encoding='utf-8',newline='\n')
    dme=out/manifest['dme']
    with dme.open('a',encoding='utf-8',newline='\n') as stream:
        for path in (CORE,RANDOM,FIXTURE): stream.write('\n#include "'+path.replace('/','\\')+'"')
        stream.write('\n')
    touched={x[0] for x in changes}|{RANDOM,dme.relative_to(stage).as_posix()}
    for path in touched:
        raw=(stage/path).read_bytes()
        manifest['stage_files'][path]={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    manifest['transition_scope']=scope
    manifest['transition_movement_blob']=MOVEMENT_BLOB
