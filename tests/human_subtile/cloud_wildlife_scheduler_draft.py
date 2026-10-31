"""Unwired source staging and paired receipt contracts for scheduler research.

This does not launch a process, change production code, or establish acceptance.
Predator, passive food/follow/flee, save/reload and inheritance coverage remain.
"""
import hashlib
import json
import math
from pathlib import Path

SCOPE='fixture-only mob scheduler, headless AI adapter and insect choice tape; no wildlife acceptance'

def require(ok,message):
    if not ok: raise RuntimeError(message)

def adapt_scheduler(out,manifest,current):
    stage=Path(out)/'stage'
    source='tests/human_subtile/probe.dm'
    require((stage/'tests/human_subtile/scheduler_core_draft.dm').is_file(),'Missing exact scheduler fixture')
    replacements=[
        ('code/game/mob/living/simple_animal/simple_ai.dm',
         'if (client || anchored || clients.len <= 0)',
         'if (client || anchored || (clients.len <= 0 && !(src in fixture_scheduler_test_subjects)))'),
        ('code/game/mob/living/simple_animal/hostile/mosquitoes.dm','if (prob(70))',
         'if (fixture_scheduler_prob(70, src, "mosquito_seek"))'),
        ('code/game/mob/living/simple_animal/hostile/mosquitoes.dm','else if (prob(15))',
         'else if (fixture_scheduler_prob(15, src, "mosquito_water"))'),
        ('code/game/mob/living/simple_animal/hostile/mosquitoes.dm',
         'if (prob(10))\n\t\t\tfor (var/mob/living/human/TG in range(1,src))',
         'if (fixture_scheduler_prob(10, src, "mosquito_bite"))\n\t\t\tfor (var/mob/living/human/TG in range(1,src))'),
        ('code/game/mob/living/simple_animal/hostile/vampirebat.dm','if (prob(80))',
         'if (fixture_scheduler_prob(80, src, "bat_seek"))'),
        ('code/game/mob/living/simple_animal/hostile/vampirebat.dm',
         'else if (prob(20))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/cow',
         'else if (fixture_scheduler_prob(20, src, "bat_cow"))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/cow'),
        ('code/game/mob/living/simple_animal/hostile/vampirebat.dm',
         'else if (prob(20))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/bull',
         'else if (fixture_scheduler_prob(20, src, "bat_bull"))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/bull'),
        ('code/game/mob/living/simple_animal/hostile/vampirebat.dm','if (prob(5))',
         'if (fixture_scheduler_prob(5, src, "bat_bite"))'),
        ('code/game/mob/living/simple_animal/simple_animal.dm','if (prob(base_chance * dmod))',
         'if (fixture_scheduler_infection_prob(base_chance * dmod, src, target, disease_name))'),
    ]
    for path in ('code/game/mob/living/simple_animal/hostile/mosquitoes.dm',
                 'code/game/mob/living/simple_animal/hostile/vampirebat.dm'):
        replacements.append((path,'TG.adjustBruteLoss(1,2)','fixture_scheduler_bite(TG, src)'))
    replacements.extend([
        ('code/game/mob/living/simple_animal/hostile/mosquitoes.dm','try_infect(TG, 20, "malaria")',
         'fixture_scheduler_infect(src, TG, 20, "malaria")'),
        ('code/game/mob/living/simple_animal/hostile/vampirebat.dm','try_infect(TG, 25, "malaria")',
         'fixture_scheduler_infect(src, TG, 25, "malaria")'),
    ])
    replacements.extend([
        (source,'\t\t\tnpc_subtile_fixture()','\t\t\tfixture_scheduler_main()'),
        (source,'"npc_checks" = npc_subtile_checks,',
         '"scheduler_checks" = fixture_scheduler_checks, "scheduler_rows" = fixture_scheduler_rows, '
         '"npc_checks" = npc_subtile_checks,'),
        (source,'"scope" = "actual human/codec; headless authority adapter"','"scope" = "'+SCOPE+'"'),
    ])
    for relative,before,after in replacements:
        current.adapt(out,manifest,relative,before,after)
    with (Path(out)/manifest['dme']).open('a',encoding='utf-8',newline='\n') as stream:
        stream.write('\n#include "tests\\human_subtile\\scheduler_core_draft.dm"\n')
    changed={item[0] for item in replacements}|{'human_subtile.dme'}
    for relative in changed:
        data=(stage/relative).read_bytes()
        manifest['stage_files'][relative]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
    manifest['scheduler_scope']=SCOPE
    (Path(out)/'scheduler-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')

def finite(n):return type(n) in (int,float) and math.isfinite(n)

def validate_run(receipt,head,mode):
    require(mode in ('legacy','smooth') and isinstance(receipt,dict) and receipt.get('head')==head and
            receipt.get('error') is None and receipt.get('port')==0 and
            (receipt.get('byond_version'),receipt.get('byond_build'))==(516,1688) and
            receipt.get('scope')==SCOPE and receipt.get('npc_checks')==0 and
            type(receipt.get('scheduler_checks')) is int and receipt['scheduler_checks']>0,'Invalid scheduler receipt')
    rows=receipt.get('scheduler_rows')
    require(isinstance(rows,list) and len(rows)==4,'Missing scheduler subjects and scenarios')
    by_kind={}
    for row in rows:
        require(isinstance(row,dict),'Invalid scheduler case')
        name=row.get('subject') or ''
        kind='mosquito' if '/mosquito/' in name else 'bat' if '/vampirebatblack/' in name else ''
        scenario=row.get('scenario');key=(kind,scenario)
        require(kind and scenario in ('chase','suppression') and key not in by_kind and row.get('enabled')==(mode=='smooth') and
                row.get('actual_clients')==0 and row.get('seed')==741239 and
                row.get('choice_tape')=='bite:10110110;secondary:0;infection:01' and
                row.get('life_interval_ds')==10 and row.get('initial_start_delay_ds')==6 and
                finite(row.get('tick_lag_ds')) and row['tick_lag_ds']>0 and
                finite(row.get('started')) and finite(row.get('ended')) and
                80<=row['ended']-row['started']<=90 and type(row.get('process_ticks')) is int and row['process_ticks']>0,
                'Scheduler configuration or timing differs')
        events=row.get('events')
        require(isinstance(events,list) and 0<len(events)<=4096 and all(isinstance(e,dict) for e in events),'Invalid scheduler events')
        for event in events:
            require(all(finite(event.get(k)) for k in ('at','x','y','z','sx','sy','target_x','target_y','target_z','target_sx','target_sy')) and
                    row['started']<=event['at']<=row['ended'] and event.get('settled') in (0,1) and
                    event.get('transaction') in (0,1) and event.get('target_in_range') in (0,1) and
                    not (event.get('transaction') and event.get('settled')) and
                    not (mode=='smooth' and event.get('settled') and (event['sx'] or event['sy'])),
                    'Invalid event position or authority')
        require(all(b['at']>=a['at'] for a,b in zip(events,events[1:])), 'Events are not time ordered')
        before=[e for e in events if e.get('event')==kind+'_life_before']
        after=[e for e in events if e.get('event')==kind+'_life_after']
        seek=[e for e in events if e.get('event')=='roll_'+kind+'_seek']
        bites=[e for e in events if e.get('event')=='roll_'+kind+'_bite']
        intents=[e for e in events if (e.get('event') or '').startswith(kind+'_intent_')]
        target_before=[e for e in events if e.get('event')=='target_step_before']
        target_after=[e for e in events if e.get('event')=='target_step_after']
        infections=[e for e in events if e.get('event')=='infection_roll']
        damage=[e for e in events if e.get('event')=='bite_before']
        damage_after=[e for e in events if e.get('event')=='bite_after']
        require(len(before)>=8 and len(before)==len(after)==len(seek)==len(bites) and row['process_ticks']>=len(before),
                'Missing scheduler Life/choice-tape observations')
        require(all(b['at']>=a['at'] and b['at']-a['at']>=10 for a,b in zip(before,before[1:])),
                'Life cadence shorter than real mob interval')
        require(len(target_before)==len(target_after)==(3 if scenario=='chase' else 0) and
                all(e.get('choice')==1 for e in target_after) and
                all(abs((e['at']-row['started'])-due)<=row['tick_lag_ds'] for e,due in zip(target_after,(20,40,60))) and
                all(finite(e.get('target_x')) and finite(e.get('target_y')) for e in target_before+target_after) and
                all((b['target_x']-a['target_x'])*32+b['target_sx']-a['target_sx']==32 and
                    b['target_y']==a['target_y'] and b['target_sy']==a['target_sy'] and b['target_z']==a['target_z'] and b['at']==a['at']
                    for a,b in zip(target_before,target_after)), 'Missing or failed target movement')
        require(all(e.get('choice')==(1 if scenario=='chase' else [1,1,0,1,1,0,1,1][i%8]) for i,e in enumerate(seek)) and
                all(e.get('choice')==[1,0,1,1,0,1,1,0][i%8] for i,e in enumerate(bites)) and
                all(e.get('native_choice') in (0,1) for e in seek+bites), 'Invalid choice tape')
        require(len(intents)==len(seek) and all(
                (e.get('event')==kind+'_intent_towards' and e.get('choice')==1 and e.get('chance')==3) if roll.get('choice') else
                (e.get('event')==kind+'_intent_random' and e.get('choice')==0 and e.get('chance')==4)
                for roll,e in zip(seek,intents)), 'Wrong target or movement producer intent')
        secondary_names=['mosquito_water'] if kind=='mosquito' else ['bat_cow','bat_bull']
        for name in secondary_names:
            secondary=[e for e in events if e.get('event')=='roll_'+name]
            require(len(secondary)==sum(e.get('choice')==0 for e in seek) and
                    all(e.get('choice')==0 and e.get('native_choice') in (0,1) for e in secondary),
                    'Missing suppressed secondary choice: '+name)
        require(len(damage)==len(damage_after) and len(damage)<=len(bites) and
                (scenario!='chase' or len(damage)>=3) and
                all(e.get('target_in_range')==1 and e.get('settled')==1 for e in damage),
                'Missing contact or unsettled/duplicate damage')
        require(all(finite(e.get('target_brute')) for e in damage+damage_after) and
                all(b['target_brute']>a['target_brute'] and b['at']==a['at'] for a,b in zip(damage,damage_after)) and
                finite(row.get('target_brute')) and (scenario!='chase' or row.get('target_disease')==1),'Missing actual damage or infection')
        require((len(infections)==2 if scenario=='chase' else len(infections)<=2) and
                [e.get('choice') for e in infections]==[0,1][:len(infections)] and
                all(e.get('native_choice') in (0,1) and e.get('chance')==(20 if kind=='mosquito' else 25) for e in infections),
                'Infection tape was not exercised')
        infection_before=[e for e in events if e.get('event')=='infection_before']
        infection_after=[e for e in events if e.get('event')=='infection_after']
        require(len(infection_before)==len(infection_after)==len(infections) and
                [e.get('choice') for e in infection_after]==[0,1][:len(infections)] and
                [e.get('target_disease') for e in infection_after]==[0,1][:len(infections)], 'Missing infection calls/results')
        active=False; bite_roll=False; bite_choice=False; bite_used=False; pending_damage=False
        infection_required=False;infection_pending=False;infection_rolled=False
        for event in events:
            label=event.get('event')
            if label==kind+'_life_before':
                require(not active,'Overlapping Life callback'); active=True; bite_roll=False; bite_used=False
            elif label=='roll_'+kind+'_bite':
                require(active and not bite_roll,'Duplicate or out-of-Life bite roll');bite_roll=True;bite_choice=event.get('choice')==1
            elif label=='bite_before':
                require(active and bite_roll and bite_choice and not bite_used and not pending_damage,'Suppressed, duplicate or unowned bite')
                bite_used=True;pending_damage=True;infection_required=event.get('target_disease')==0
            elif label=='bite_after':
                require(active and pending_damage,'Unpaired bite completion');pending_damage=False
            elif label=='infection_before':
                require(active and bite_used and not pending_damage and infection_required and not infection_pending,'Unexpected infection call')
                infection_pending=True;infection_rolled=False
            elif label=='infection_roll':
                require(infection_pending and not infection_rolled,'Unowned or duplicate infection roll');infection_rolled=True
            elif label=='infection_after':
                require(infection_pending and infection_rolled,'Unpaired infection result')
                infection_pending=False;infection_required=False
            elif label==kind+'_life_after':
                require(active and bite_roll and not pending_damage and not infection_required and not infection_pending,'Incomplete Life, bite or infection')
                active=False
        require(not active and not pending_damage and not infection_pending,'Unfinished scheduler observation')
        require(row['target_brute']==(damage_after[-1]['target_brute'] if damage_after else 0) and
                row.get('target_disease')==(infection_after[-1]['target_disease'] if infection_after else 0),
                'Final damage or infection is not explained by recorded calls')
        samples=[e for e in events if e.get('event')=='position_sample']
        require(len(samples)>=2 and samples[0]['at']-row['started']<=row['tick_lag_ds'] and
                0<=row['started']+80-samples[-1]['at']<=row['tick_lag_ds']+1e-7 and
                all(0<=b['at']-a['at']<=row['tick_lag_ds']+1e-7 for a,b in zip(samples,samples[1:])),
                'Missing bounded physical position samples')
        def actor_point(e): return (e['x']*32+e['sx'],e['y']*32+e['sy'],e['z'])
        def target_point(e): return (e['target_x']*32+e['target_sx'],e['target_y']*32+e['target_sy'],e['target_z'])
        require(actor_point(events[0])==(6*32,6*32,1) and target_point(events[0])==(9*32,6*32,1) and
                all(0<=e['sx']<32 and 0<=e['sy']<32 and 0<=e['target_sx']<32 and 0<=e['target_sy']<32 for e in events),
                'Invalid starting geometry or offsets')
        # Every actor relocation must be witnessed by its real Move wrapper;
        # target coordinates may change only at a witnessed target step.
        actor_now=actor_point(events[0]);target_now=target_point(events[0]);pending_move=None;move_pairs=[]
        for index,event in enumerate(events):
            label=event.get('event');p=actor_point(event);q=target_point(event)
            if label==kind+'_move_before':
                require(p==actor_now and pending_move is None,'Overlapping or inconsistent Move start')
                pending_move=event
            elif label==kind+'_move_after':
                require(pending_move is not None,'Unpaired Move completion')
                old=actor_point(pending_move);limit=2 if mode=='smooth' else 32
                require(p[2]==old[2] and abs(p[0]-old[0])<=limit and abs(p[1]-old[1])<=limit,
                        'Move displacement exceeds mode pulse/tile bound')
                move_pairs.append((index,pending_move,event));pending_move=None;actor_now=p
            else:
                require(p==actor_now,'Position sample does not match physical Move trace')
            if label=='target_step_after': target_now=q
            else: require(q==target_now,'Target position changed without recorded step')
            if label=='bite_before':
                require(event['z']==event['target_z'] and abs(p[0]-q[0])<64 and abs(p[1]-q[1])<64,
                        'Bite outside physical target range')
        require(pending_move is None,'Unfinished Move')
        travel=sum(abs(actor_point(b)[0]-actor_point(a)[0])+abs(actor_point(b)[1]-actor_point(a)[1]) for _,a,b in move_pairs)
        arrival_by_epoch=[];hold_by_epoch=[];travel_by_epoch=[]
        if scenario=='chase':
            require(move_pairs and travel>0,'No physical travel')
            step_indices=[i for i,e in enumerate(events) if e.get('event')=='target_step_after']
            boundaries=[0]+[i+1 for i in step_indices]+[len(events)]
            boundary_times=[row['started']]+[e['at'] for e in target_after]
            for epoch,(start,end) in enumerate(zip(boundaries,boundaries[1:])):
                segment=[e for e in events[start:end] if e.get('event')=='position_sample']
                distance=sum(abs(actor_point(b)[0]-actor_point(a)[0])+abs(actor_point(b)[1]-actor_point(a)[1])
                             for i,a,b in move_pairs if start<=i<end)
                travel_by_epoch.append(distance)
                arrived=[i for i,e in enumerate(segment) if actor_point(e)==target_point(e) and e['settled']==1]
                # Initial approach may still be in progress when the first target
                # step occurs. Every subsequent change must be reacquired.
                if epoch: require(distance>0 and arrived,'Target change lacked physical travel or settled arrival')
                if arrived:
                    first=arrived[0];arrival_by_epoch.append(segment[first]['at']-boundary_times[epoch])
                    departed=next((e['at'] for e in segment[first+1:] if actor_point(e)!=target_point(e) or e['settled']!=1),
                                  target_after[epoch]['at'] if epoch<len(target_after) else row['started']+80)
                    hold_by_epoch.append(departed-segment[first]['at'])
                else:
                    arrival_by_epoch.append(None);hold_by_epoch.append(None)
        by_kind[key]={'row':row,'first_bite':damage[0]['at']-row['started'] if damage else None,'life':len(before),
                       'rolls':len(bites),'damage':len(damage),'movement':len(move_pairs),'travel':travel,
                       'arrival_by_epoch':arrival_by_epoch,'hold_by_epoch':hold_by_epoch,'travel_by_epoch':travel_by_epoch,
                       'seek_choices':[e.get('choice') for e in seek], 'bite_choices':[e.get('choice') for e in bites],
                       'infection_choices':[e.get('choice') for e in infections]}
    require(set(by_kind)=={(k,s) for k in ('mosquito','bat') for s in ('chase','suppression')},'Missing scheduler species/scenario')
    return by_kind

def compare_pair(legacy,smooth,head):
    old=validate_run(legacy,head,'legacy');new=validate_run(smooth,head,'smooth')
    result={}
    for kind in ('mosquito','bat'):
        a,b=old[(kind,'chase')],new[(kind,'chase')]
        require(a['row']['tick_lag_ds']==b['row']['tick_lag_ds'] and a['life']==b['life'] and a['rolls']==b['rolls'],
                'Life or original roll count differs: '+kind)
        require(abs(a['first_bite']-b['first_bite'])<=a['row']['tick_lag_ds'],
                'Contact delay exceeds one world tick: '+kind)
        require(a['seek_choices']==b['seek_choices'] and a['bite_choices']==b['bite_choices'] and
                a['infection_choices']==b['infection_choices'] and
                all((x is None and y is None) or (x is not None and y is not None and abs(x-y)<=a['row']['tick_lag_ds'])
                    for x,y in zip(a['arrival_by_epoch'],b['arrival_by_epoch'])) and
                all((x is None and y is None) or (x is not None and y is not None and abs(x-y)<=a['row']['tick_lag_ds'])
                    for x,y in zip(a['hold_by_epoch'],b['hold_by_epoch'])) and
                all(abs(x-y)<=2 for x,y in zip(a['travel_by_epoch'],b['travel_by_epoch'])),
                'Sustained movement/contact cadence differs: '+kind)
        require(a['damage']==b['damage'] and a['row']['target_brute']==b['row']['target_brute'] and
                a['row']['target_disease']==b['row']['target_disease'],'Damage or infection differs: '+kind)
        result[kind]={'legacy_first_bite_ds':a['first_bite'],'smooth_first_bite_ds':b['first_bite'],
                      'life_calls':a['life'],'legacy_move_callbacks':a['movement'],'smooth_move_callbacks':b['movement'],
                      'bite_count':a['damage'],'legacy_travel_px':a['travel'],'smooth_travel_px':b['travel'],
                      'legacy_epoch_arrivals_ds':a['arrival_by_epoch'],'smooth_epoch_arrivals_ds':b['arrival_by_epoch'],
                      'legacy_epoch_hold_ds':a['hold_by_epoch'],'smooth_epoch_hold_ds':b['hold_by_epoch'],
                      'legacy_epoch_travel_px':a['travel_by_epoch'],'smooth_epoch_travel_px':b['travel_by_epoch']}
        # False seek triggers native random walking, whose direction and timing
        # are not controlled by this fixture. Validate each safety trace without
        # claiming that two random trajectories are equivalent.
        for run in (old[(kind,'suppression')],new[(kind,'suppression')]):
            require(0 in run['seek_choices'] and 0 in run['bite_choices'],'Missing suppressed choices: '+kind)
    return result
