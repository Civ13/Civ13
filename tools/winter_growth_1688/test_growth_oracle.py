"""Invented records only; no native process, socket, /proc or live save access."""
import copy
import json
import unittest
from audit_offline import install
install()
from oracle import (ADAPTER,VERSION,HEAD,TREE,POPULATION,SAVE_NAMES,strict_json,
                    verify_result, verify_compile)

BINDING='a'*64


def snapshot(tick,origin,cycles=0,base=None,allzero=False):
    if base is None:
        plants=[]
        n=0
        for k,count in POPULATION.items():
            for i in range(count):
                n+=1
                plants.append(dict(id=k+':'+str(i+1),type='/obj/structure/farming/plant/'+k,
                    x=(n-1)%10+1,y=(n-1)//10+1,z=1,identity='plant-'+str(n),stage=1,
                    soil=147,water=90 if k=='turnip' else 60 if k=='potato' else 0,
                    plant_nutrition=147,vstatic=0))
        foods=[dict(id=k,type='/obj/item/weapon/reagent_containers/food/snacks/grown/'+k,
                    x=i+1,y=7,z=1,identity='food-'+k,nutriment=1,age=0,
                    decay=54000 if k=='turnip' else 36000) for i,k in enumerate(('turnip','plump_helmet'))]
        seeds=[dict(id=k,type='/obj/item/stack/farming/seeds/'+k,x=i+1,y=8,z=1,
                    identity='seed-'+k,amount=1) for i,k in enumerate(('turnip','plump_helmet'))]
    else:
        plants,foods,seeds=[copy.deepcopy(base[g]) for g in ('plants','foods','seeds')]
        for row in plants+foods+seeds: row['identity']='reader-'+row['identity']
    for row in plants:
        row['soil']-=3*cycles;row['plant_nutrition']=row['soil']
        if not (allzero and row['id'].startswith('plump_helmet:')):row['stage']+=cycles
    for row in foods: row['age']+=600*cycles
    return dict(tick=tick,elapsed=tick-origin,plants=plants,foods=foods,seeds=seeds)


def fixture(phase='writer',allzero=False):
    origin=100
    savedbase=None
    if phase=='reader':
        writer,_=fixture()
        savedbase=writer['writer_saved_snapshot']['after']
    times=list(range(0,1301,100))+[1350]
    rows=[snapshot(origin+t,origin,t//600,base=savedbase,allzero=allzero) for t in times]
    if phase=='writer':
        saved={'before':copy.deepcopy(rows[-1]),'after':copy.deepcopy(rows[-1])}
        saved['after']['tick']+=1;saved['after']['elapsed']+=1
    else:saved=writer['writer_saved_snapshot']
    result=dict(schema=1,adapter=ADAPTER,version=VERSION,head=HEAD,tree=TREE,
                candidate_manifest_sha256=BINDING,variant='baseline',phase=phase,port=0,
                status='observed',failure=None,tick_lag=1,fps=10,observations=rows,
                poll_max_gap=1,origin_tick=origin,setup_started_tick=origin,
                save_started_tick=origin+1350 if phase=='writer' else None,
                save_finished_tick=origin+1351 if phase=='writer' else None,
                load_started_tick=origin-1 if phase=='reader' else None,
                load_finished_tick=origin if phase=='reader' else None,
                writer_saved_snapshot=saved,map_type='/obj/map_metadata/nomads/winter_tester',map_id='NOMADS_PANGEA',round_version='round-v1')
    context=dict(process_receipt={'elapsed_seconds':136.0})
    if phase=='reader':
        context.update(expected_writer=copy.deepcopy(saved),expected_save_files={name:{'bytes':10,'sha256':'c'*64} for name in SAVE_NAMES})
    return result,context


def log_for(result):
    return '\n'.join('GROWTH1688_OBSERVATION '+json.dumps(s) for s in result['observations'])+'\nGROWTH1688_RESULT baseline:'+result['phase']+'\n'


def check(result,context):
    return verify_result(BINDING,'baseline',result['phase'],result,log_for(result),**context)


class GrowthOracleTests(unittest.TestCase):
    def test_synthetic_writer_and_fresh_reader(self):
        for phase in ('writer','reader'):
            r,c=fixture(phase);verdict=check(r,c)
            self.assertEqual(verdict['status'],'passed')
            self.assertEqual(verdict['crop_payments'],80)
            self.assertEqual(verdict['food_events'],4)

    def test_allzero_stochastic_is_inconclusive_never_pass(self):
        for phase in ('writer','reader'):
            r,c=fixture(phase,allzero=True)
            self.assertEqual(check(r,c)['status'],'inconclusive')

    def test_self_awarded_success_rejected(self):
        r,c=fixture(allzero=True);r['status']='passed'
        with self.assertRaisesRegex(ValueError,'self-awarded'):check(r,c)

    def test_missing_and_duplicate_payment_rejected(self):
        for delta in (-3,3):
            r,c=fixture();r['observations'][6]['plants'][0]['soil']+=delta
            with self.subTest(delta=delta),self.assertRaises(ValueError):check(r,c)

    def test_early_payment_rejected(self):
        r,c=fixture()
        for i in range(3,6):
            for key in ('soil','plant_nutrition','stage'):
                r['observations'][i]['plants'][0][key]=r['observations'][6]['plants'][0][key]
        with self.assertRaisesRegex(ValueError,'early/late'):check(r,c)

    def test_food_refill_seed_increase_identity_loss(self):
        for group,key,value in [('foods','nutriment',2),('seeds','amount',2),('plants','identity','replaced')]:
            r,c=fixture();r['observations'][4][group][0][key]=value
            with self.subTest(group=group),self.assertRaises(ValueError):check(r,c)

    def test_phase_source_bindings(self):
        for key,value in [('head','b'*40),('tree','b'*40),('version','516.1681'),('candidate_manifest_sha256','b'*64),('variant','other'),('schema',True),('port',False)]:
            r,c=fixture();r[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):check(r,c)

    def test_clock_and_missing_observations_rejected(self):
        for key,value in [('tick_lag',0.1),('fps',100),('poll_max_gap',6)]:
            r,c=fixture();r[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):check(r,c)
        r,c=fixture();c['process_receipt']['elapsed_seconds']=13.5
        with self.assertRaisesRegex(ValueError,'elapsed wall'):check(r,c)
        r,c=fixture();del r['observations'][2]
        with self.assertRaisesRegex(ValueError,'heartbeat'):check(r,c)

    def test_restart_requires_sealed_external_context(self):
        for field in ('expected_writer','expected_save_files'):
            r,c=fixture('reader');del c[field]
            with self.subTest(field=field),self.assertRaises(ValueError):check(r,c)
        r,c=fixture('reader');c['expected_save_files']['map_saves/1.sav']['sha256']='bad'
        with self.assertRaisesRegex(ValueError,'save-set seal'):check(r,c)
        r,c=fixture('reader');c['expected_writer']['after']['plants'][0]['soil']-=3
        with self.assertRaisesRegex(ValueError,'independently transferred'):check(r,c)

    def test_constructor_debit_not_excused_as_baseline(self):
        r,c=fixture('reader');r['observations'][0]['plants'][0]['soil']-=3
        with self.assertRaisesRegex(ValueError,'Save/load changed'):check(r,c)

    def test_failure_identifies_affected_new_or_control_type(self):
        for plant_index,identity in [(0,'turnip:1'),(4,'potato:1'),(8,'plump_helmet:1'),(24,'mushroom:1')]:
            r,c=fixture();r['observations'][6]['plants'][plant_index]['soil']-=3
            with self.subTest(identity=identity),self.assertRaisesRegex(ValueError,identity):check(r,c)
        r,c=fixture();r['observations'][6]['foods'][1]['age']+=600
        with self.assertRaisesRegex(ValueError,'plump_helmet'):check(r,c)
        r,c=fixture();self.assertEqual(check(r,c)['payments_by_type'],
            {'turnip':8,'potato':8,'plump_helmet':32,'mushroom':32})

    def test_strict_json_and_transcript(self):
        for raw in ('{"x":1,"x":2}','{"x":NaN}'):
            with self.assertRaises(ValueError):strict_json(raw)
        r,c=fixture();log=log_for(r)
        for text in (log+log,log.replace('GROWTH1688_OBSERVATION ','',1),log+'runtime error: test'):
            with self.assertRaises(ValueError):verify_result(BINDING,'baseline','writer',r,text,**c)
        with self.assertRaises(ValueError):verify_result(BINDING,'baseline','writer',r,log,{'extra':'runtime error: test'},**c)

    def test_compiler_and_listener_diagnostics(self):
        self.assertEqual(verify_compile('DM compiler version 516.1688\n0 errors, 0 warnings\n')['status'],'passed')
        for log in ('DM compiler version 516.1681\n0 errors, 0 warnings\n', 'DM compiler version 516.1688\n1 error, 0 warnings\n'):
            with self.assertRaises(ValueError):verify_compile(log)

if __name__=='__main__':unittest.main(verbosity=2)
