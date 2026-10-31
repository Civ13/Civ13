"""Offline tests of unwired paired scheduler staging and receipt contracts."""
import copy
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('scheduler',Path(__file__).with_name('cloud_wildlife_scheduler_draft.py'))
scheduler=importlib.util.module_from_spec(spec);spec.loader.exec_module(scheduler)

def receipt(enabled):
    rows=[]
    for scenario in ('chase','suppression'):
      for kind,path in [('mosquito','/mob/living/simple_animal/mosquito/scheduler_probe'),
                        ('bat','/mob/living/simple_animal/vampirebatblack/scheduler_probe')]:
        events=[];brute=0;disease=0;target_x=9;actor_px=6*32;infection_count=0;pulsing=False
        for tick in range(160):
            at=tick/2
            def event(label,**kwargs):
                return dict(event=label,at=at,x=actor_px//32,y=6,z=1,sx=actor_px%32,sy=0,settled=int(not pulsing),transaction=int(pulsing),
                            target_in_range=int(abs(target_x-actor_px//32)<=1),target_brute=brute,target_disease=disease,
                            target_x=target_x,target_y=6,target_z=1,target_sx=0,target_sy=0,**kwargs)
            if scenario=='chase' and at in (20,40,60):
                events.append(event('target_step_before'));target_x+=1;events.append(event('target_step_after',choice=1))
            if at in ((4,6,8,22,42,62) if scenario=='chase' else (4,6,8)):
                pulsing=enabled
                for _ in range(16 if enabled else 1):
                    events.append(event(kind+'_move_before'));actor_px+=2 if enabled else 32;events.append(event(kind+'_move_after'))
                pulsing=False
            if at in (4,14,24,34,44,54,64,74):
                index=int((at-4)/10);seek=1 if scenario=='chase' else [1,1,0,1,1,0,1,1][index]
                bite=[1,0,1,1,0,1,1,0][index]
                events.append(event(kind+'_life_before'))
                events.append(event('roll_'+kind+'_seek',choice=seek,native_choice=0))
                if not seek:
                    for site in (['mosquito_water'] if kind=='mosquito' else ['bat_cow','bat_bull']):
                        events.append(event('roll_'+site,choice=0,native_choice=0))
                events.append(event(kind+('_intent_towards' if seek else '_intent_random'),choice=int(bool(seek)),chance=3 if seek else 4))
                events.append(event('roll_'+kind+'_bite',choice=bite,native_choice=0))
                if bite and abs(target_x-actor_px//32)<=1:
                    events.append(event('bite_before'));brute+=1;events.append(event('bite_after'))
                    if infection_count<2:
                        events.append(event('infection_before'));result=infection_count
                        events.append(event('infection_roll',choice=result,native_choice=0,chance=20 if kind=='mosquito' else 25))
                        disease=result;events.append(event('infection_after',choice=result));infection_count+=1
                events.append(event(kind+'_life_after'))
            events.append(event('position_sample'))
        rows.append(dict(enabled=enabled,subject=path,started=0,ended=80,process_ticks=8,life_interval_ds=10,
                         initial_start_delay_ds=6,actual_clients=0,tick_lag_ds=.5,seed=741239,scenario=scenario,
                         choice_tape='bite:10110110;secondary:0;infection:01',
                         target_brute=brute,target_disease=disease,events=events))
    return dict(head='a'*40,error=None,port=0,byond_version=516,byond_build=1688,scope=scheduler.SCOPE,
                npc_checks=0,scheduler_checks=100,scheduler_rows=rows)

class SchedulerDraftContracts(unittest.TestCase):
    def test_pair_and_negative_contact_safety(self):
        legacy,smooth=receipt(False),receipt(True)
        comparison=scheduler.compare_pair(legacy,smooth,'a'*40)
        self.assertEqual(set(comparison),{'mosquito','bat'})
        self.assertEqual(comparison['mosquito']['legacy_first_bite_ds'],24)
        self.assertEqual(comparison['mosquito']['legacy_epoch_arrivals_ds'],[8,2,2,2])
        changed=copy.deepcopy(smooth)
        bite=next(e for e in changed['scheduler_rows'][0]['events'] if e['event']=='bite_before')
        bite['settled']=0
        with self.assertRaises(RuntimeError): scheduler.compare_pair(legacy,changed,'a'*40)
        changed=copy.deepcopy(smooth)
        for e in changed['scheduler_rows'][0]['events']:
            if e['event'] in ('bite_before','bite_after'):e['at']+=10
        with self.assertRaises(RuntimeError): scheduler.compare_pair(legacy,changed,'a'*40)
        changed=copy.deepcopy(smooth)
        changed['scheduler_rows'][0]['events'].append(copy.deepcopy(bite))
        with self.assertRaises(RuntimeError): scheduler.compare_pair(legacy,changed,'a'*40)

    def test_exact_staged_substitutions(self):
        class Adapter:
            @staticmethod
            def adapt(out,manifest,relative,before,after):
                path=Path(out)/'stage'/relative;text=path.read_text()
                if text.count(before)!=1: raise RuntimeError('Ambiguous source replacement')
                path.write_text(text.replace(before,after))
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp);stage=out/'stage'
            files={
                'tests/human_subtile/scheduler_core_draft.dm':'// fixture',
                'tests/human_subtile/probe.dm':'\t\t\tnpc_subtile_fixture()\n"npc_checks" = npc_subtile_checks,\n"scope" = "actual human/codec; headless authority adapter"',
                'code/game/mob/living/simple_animal/simple_ai.dm':'if (client || anchored || clients.len <= 0)',
                'code/game/mob/living/simple_animal/simple_animal.dm':'if (prob(base_chance * dmod))',
                'code/game/mob/living/simple_animal/hostile/mosquitoes.dm':'if (prob(70))\nelse if (prob(15))\nif (prob(10))\n\t\t\tfor (var/mob/living/human/TG in range(1,src))\nTG.adjustBruteLoss(1,2)\ntry_infect(TG, 20, "malaria")',
                'code/game/mob/living/simple_animal/hostile/vampirebat.dm':'if (prob(80))\nelse if (prob(20))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/cow\nelse if (prob(20))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/bull\nif (prob(5))\nTG.adjustBruteLoss(1,2)\ntry_infect(TG, 25, "malaria")',
                'human_subtile.dme':'// dme',
            }
            for name,value in files.items():
                path=stage/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(value)
            manifest=dict(dme='stage/human_subtile.dme',stage_files={},head='a'*40)
            scheduler.adapt_scheduler(out,manifest,Adapter())
            self.assertEqual(manifest['scheduler_scope'],scheduler.SCOPE)
            self.assertIn('fixture_scheduler_test_subjects',(stage/'code/game/mob/living/simple_animal/simple_ai.dm').read_text())
            self.assertIn('fixture_scheduler_bite(TG, src)',(stage/'code/game/mob/living/simple_animal/hostile/mosquitoes.dm').read_text())
            self.assertEqual(len(manifest['stage_files']),6)

    def test_rejects_missing_movement_damage_infection_and_suppressed_bites(self):
        legacy=receipt(False)
        for defect in ('no_moves','no_damage','no_infection','no_secondary','stationary_target','suppressed_bite','late_contact','missed_step','false_arrival','wrong_target','teleport','truncated_samples'):
            with self.subTest(defect=defect):
                candidate=receipt(True);row=candidate['scheduler_rows'][2 if defect=='no_secondary' else 0];events=row['events']
                if defect=='no_moves':
                    events[:]=[e for e in events if '_move_' not in e['event']]
                elif defect=='no_damage':
                    for e in events:
                        if e['event']=='bite_after': e['target_brute']-=1
                elif defect=='no_infection':
                    candidate['scheduler_rows'][0]['target_disease']=0
                elif defect=='no_secondary':
                    events[:]=[e for e in events if e['event']!='roll_mosquito_water']
                elif defect=='stationary_target':
                    next(e for e in events if e['event']=='target_step_after')['choice']=0
                elif defect=='suppressed_bite':
                    i=next(i for i,e in enumerate(events) if e['event']=='roll_mosquito_bite' and e['choice']==0)
                    events.insert(i+1,dict(events[i],event='bite_before'))
                elif defect=='missed_step':
                    events[:]=[e for e in events if not (e['at']==42 and e['event'] in ('mosquito_move_before','mosquito_move_after'))]
                    for e in events:
                        if e['at']>=42:
                            e['x']-=1;e['target_in_range']=int(abs(e['target_x']-e['x'])<=1)
                elif defect=='false_arrival':
                    sample=next(e for e in events if e['event']=='position_sample' and e['at']==20)
                    sample['x']=sample['target_x']
                elif defect=='wrong_target':
                    next(e for e in events if e['event']=='mosquito_intent_towards')['choice']=0
                elif defect=='teleport':
                    next(e for e in events if e['event']=='mosquito_move_after')['x']+=1
                elif defect=='truncated_samples':
                    events[:]=[e for e in events if not (e['event']=='position_sample' and e['at']>75)]
                else:
                    bite=next(e for e in events if e['event']=='bite_before' and e['at']==24)
                    bite['at']+=1
                expected={'missed_step':'Target change lacked physical travel or settled arrival',
                          'false_arrival':'Position sample does not match physical Move trace',
                          'wrong_target':'Wrong target or movement producer intent',
                          'teleport':'Move displacement exceeds mode pulse/tile bound',
                          'truncated_samples':'Missing bounded physical position samples'}.get(defect)
                if expected:
                    with self.assertRaisesRegex(RuntimeError,expected): scheduler.compare_pair(legacy,candidate,'a'*40)
                else:
                    with self.assertRaises(RuntimeError): scheduler.compare_pair(legacy,candidate,'a'*40)

    def test_staging_matches_current_source(self):
        class Adapter:
            @staticmethod
            def adapt(out,manifest,relative,before,after):
                path=Path(out)/'stage'/relative;text=path.read_text(encoding='utf-8')
                if text.count(before)!=1: raise RuntimeError('Ambiguous source replacement: '+relative)
                path.write_text(text.replace(before,after),encoding='utf-8')
        root=Path(__file__).resolve().parents[2]
        paths=['tests/human_subtile/scheduler_core_draft.dm','tests/human_subtile/probe.dm',
               'code/game/mob/living/simple_animal/simple_ai.dm',
               'code/game/mob/living/simple_animal/simple_animal.dm',
               'code/game/mob/living/simple_animal/hostile/mosquitoes.dm',
               'code/game/mob/living/simple_animal/hostile/vampirebat.dm']
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp);stage=out/'stage'
            for name in paths:
                destination=stage/name;destination.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(root/name,destination)
            manifest=dict(dme='stage/human_subtile.dme',stage_files={},head='a'*40)
            Adapter.adapt(out,manifest,'tests/human_subtile/probe.dm',
                          '\t\t\thuman_subtile_fixture_headless()','\t\t\tnpc_subtile_fixture()')
            Adapter.adapt(out,manifest,'tests/human_subtile/probe.dm',
                          '"checks" = human_subtile_fixture_checks,',
                          '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks,')
            (stage/'human_subtile.dme').write_text('// fixture DME',encoding='utf-8')
            scheduler.adapt_scheduler(out,manifest,Adapter())

if __name__=='__main__':unittest.main()
