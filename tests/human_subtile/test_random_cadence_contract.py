"""Offline validator/adaptation tests; no BYOND processes or third-party modules."""
import copy
import hashlib
import importlib.util
import io
import inspect
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('random_contract', HERE / 'random_cadence_contract.py')
contract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contract)
controller_spec = importlib.util.spec_from_file_location('random_controller', HERE / 'cloud_npc_controller.py')
controller = importlib.util.module_from_spec(controller_spec)
controller_spec.loader.exec_module(controller)
worker_spec = importlib.util.spec_from_file_location('random_worker', HERE / 'cloud_npc_smoke.py')
worker = importlib.util.module_from_spec(worker_spec)
worker_spec.loader.exec_module(worker)
job_spec = importlib.util.spec_from_file_location('random_job', HERE / 'cloud_npc_job.py')
job = importlib.util.module_from_spec(job_spec)
job_spec.loader.exec_module(job)


def event(label, at, x=33, sx=0, **fields):
    result = {'event': label, 'at': at, 'tick_usage': 5,
              'life_depth': int(label.startswith('contact_') or label.startswith('command_')),
              'x': x, 'y': 33, 'z': 1, 'sx': sx, 'sy': 0,
              'dir': 4, 'step_size': 32, 'enabled': 1, 'settled': 1, 'transaction': 0, 'pulse': 0,
              'range': 1, 'owner': 'w', 'generation': 1, 'revision': 1, 'due': 8,
              'pending': None, 'active_tx': None, 'tx': None, 'arrived': None, 'tx_dir': None,
              'tx_finished': None, 'tx_actor_present': None, 'tx_target_present': None,
              'tx_combat_present': None, 'tx_following_present': None, 'tx_intent_present': None,
              'remaining_x': None, 'remaining_y': None, 'target_brute': 0,
              'target_disease': 0, 'target_disease_type': None, 'target_x': 33, 'target_y': 34, 'target_z': 1,
              'target_sx': 0, 'target_sy': 0, 'detail': None}
    result.update(fields)
    return result


def make_row(kind, policy, phase, mode, tick):
    animal = '/mob/living/simple_animal/' + ('mosquito' if kind == 'mosquito' else 'vampirebatblack') + '/scheduler_probe/random_probe'
    enabled = mode != 'legacy'
    events = [event('phase_start', 0, owner=None, enabled=int(enabled))]
    for i, at in enumerate((4, 14, 24)):
        x = 33 + 2*i
        owner_before = None if i == 0 else 'w'
        events += [event('contact_' + kind + '_life_before', at, x=x, owner=owner_before),
                   event('contact_roll_' + kind + '_seek', at, x=x,
                         detail={'choice':0,'raw':0,'chance':70 if kind=='mosquito' else 80})]
        for site in (('mosquito_water',) if kind=='mosquito' else ('bat_cow','bat_bull')):
            events.append(event('contact_roll_'+site,at,x=x,
                                detail={'choice':0,'raw':0,'chance':15 if kind=='mosquito' else 20}))
        events.append(event('command_before', at, x=x, owner=owner_before,
                            detail={'mode': 'random', 'lag': 4, 'speed_argument': 0}))
        if not (policy == 'held' and i):
            events.append(event('contact_'+kind+'_intent_random',at,x=x,detail={'choice':0,'raw':None,'chance':4}))
        events += [event('command_suppressed' if policy == 'held' and i else 'command_after', at, x=x,
                         owner='w', detail=None if mode == 'legacy' else 1),
                   event('contact_roll_' + kind + '_bite', at, x=x,
                         detail={'choice': (1,0,1)[i], 'raw': 0, 'chance': 10 if kind=='mosquito' else 5})]
        if i==0:
            events += [event('contact_bite_before',at,x=x,target_brute=0),
                       event('contact_bite_after',at,x=x,target_brute=1),
                       event('contact_infection_before',at,x=x,target_brute=1),
                       event('contact_infection_roll',at,x=x,target_brute=1,
                             detail={'choice':0,'raw':0,'chance':20 if kind=='mosquito' else 25}),
                       event('contact_infection_after',at,x=x,target_brute=1,detail={'choice':0,'raw':None,'chance':None})]
        events.append(event('contact_' + kind + '_life_after', at, x=x))
        if i == 2:
            break
        for step in range(2):
            pos=x+step;begin=at+1+4*step
            if enabled:
                tx = 't' + str(i) + str(step)
                events.append(event('tx_admitted', begin, x=pos, tx=tx, tx_dir=4, remaining_x=32, remaining_y=0,
                                    arrived=0, transaction=1, settled=0, active_tx=tx))
                for pulse in range(16):
                    timestamp = begin+(pulse//4)*.5
                    before = pulse*2
                    after = before+2
                    events.append(event('move_enter', timestamp, x=pos, sx=before, detail=4, transaction=1, settled=0, active_tx=tx))
                    events.append(event('move_exit', timestamp, x=pos+(after//32), sx=after%32, detail=1,
                                        transaction=1, settled=0, active_tx=tx))
                events += [event('final_pulse', begin+1.5, x=pos+1, tx=tx, tx_dir=4, remaining_x=0, remaining_y=0,
                                 arrived=0, transaction=1, settled=0, active_tx=tx),
                           event('tx_actor_released', begin+2, x=pos+1, tx=tx, tx_dir=4, remaining_x=0, remaining_y=0,
                                 arrived=1,tx_finished=0,tx_actor_present=1),
                           event('tx_finished', begin+2, x=pos+1, tx=tx, tx_dir=4, remaining_x=0, remaining_y=0,
                                 arrived=1,tx_finished=1,tx_actor_present=0,tx_target_present=0,tx_combat_present=0,
                                 tx_following_present=0,tx_intent_present=1)]
            else:
                events += [event('move_enter', begin, x=pos, detail=4), event('move_exit', begin, x=pos+1, detail=1)]
    events.append(event('phase_end', 28, x=37,owner=None))
    for item in events:
        item['enabled']=int(enabled)
        item['at'] += 1
    return {'case': animal + ':' + policy + ':' + str(phase), 'subject': animal, 'policy': policy, 'phase_ticks': phase, 'started': 1,
            'ended': 29, 'tick_lag_ds': tick, 'observation_ds':28, 'enabled': enabled, 'step_size': 32, 'speed_argument': 0,
            'process_ticks': 3, 'life_interval_ds': 10, 'initial_start_delay_ds': 6, 'actual_clients': 0,
            'seed': 741239, 'event_count':len(events), 'life_count':3, 'tx_count':4 if enabled else 0,
            'move_enter_count':sum(e['event']=='move_enter' for e in events),
            'move_exit_count':sum(e['event']=='move_exit' for e in events), 'events': events}


def receipt(mode='candidate', tick=.5):
    rows = [make_row(kind, policy, phase, mode, tick) for kind in contract.KINDS
            for policy in contract.POLICIES for phase in contract.PHASES]
    return {'head': 'a'*40, 'error': None, 'port': 0, 'byond_version': 516, 'byond_build': 1688,
            'scope': contract.SCOPE, 'npc_checks': 0, 'random_rows': rows, 'random_overflow': 0,
            'random_setup': {'stage':'ready', 'mode':mode, 'mode_is_text':1, 'raw_tick':str(tick),
                             'tick_is_text':1, 'requested_tick':tick, 'initial_tick':1,
                             'actual_tick':tick, 'mode_valid':1, 'tick_valid':1, 'original_combined':0,
                             'startup_time':0, 'ready_time':tick, 'startup_usage':26876100000000.0, 'ready_usage':1},
            'random_partial':rows[-1]['events'], 'random_case':rows[-1]['case'],
            'random_phase_count':len(rows[-1]['events']), 'random_count': sum(len(row['events']) for row in rows)}


class ContractTests(unittest.TestCase):
    def test_setup_diagnostics_are_required_and_input_specific(self):
        for mode in contract.MODES:
            for tick in contract.TICKS:
                good = receipt(mode, tick)
                contract.validate(good, 'a'*40, mode, tick)
                for key, value in (('stage', 'before_validation'), ('mode', 'wrong'), ('mode_is_text', 0),
                                   ('raw_tick', 'wrong'), ('tick_is_text', 0), ('requested_tick', 2),
                                   ('actual_tick', 2), ('mode_valid', 0), ('tick_valid', 0),
                                   ('original_combined', None)):
                    bad = receipt(mode, tick); bad['random_setup'][key] = value
                    with self.subTest(mode=mode, tick=tick, field=key), self.assertRaises(ValueError):
                        contract.validate(bad, 'a'*40, mode, tick)

    def test_startup_readiness_fails_closed_and_keeps_raw_initial_usage(self):
        for mode in contract.MODES:
            for tick in contract.TICKS:
                good = receipt(mode, tick)
                contract.validate(good, 'a'*40, mode, tick)
                for field, value in (('startup_time', -1), ('ready_time', 0), ('ready_usage', 100),
                                     ('ready_usage', -1), ('startup_usage', float('nan'))):
                    bad = receipt(mode, tick); bad['random_setup'][field] = value
                    with self.subTest(mode=mode, tick=tick, field=field), self.assertRaises(ValueError):
                        contract.validate(bad, 'a'*40, mode, tick)
                bad = receipt(mode, tick); bad['random_setup']['ready_time'] = 2
                with self.assertRaises(ValueError):
                    contract.validate(bad, 'a'*40, mode, tick)

    def test_startup_yield_precedes_every_phase_and_actor_construction(self):
        source = (HERE/'random_cadence_fixture.dm').read_text()
        main = source.split('/proc/fixture_random_main()',1)[1]
        self.assertLess(main.index('fixture_scheduler_assert(world.tick_lag == requested_tick'), main.index('sleep(world.tick_lag)'))
        self.assertLess(main.index('sleep(world.tick_lag)'), main.index('for (var/policy in list('))
        self.assertIn('world.time > startup_time && world.tick_lag == requested_tick', main)
        self.assertIn('world.tick_usage >= 0 && world.tick_usage < 100', main)
        self.assertEqual(main.count('sleep(world.tick_lag)'), 1)

    def test_membership_checks_are_grouped_and_diagnostics_reach_receipt(self):
        source = (HERE/'random_cadence_fixture.dm').read_text()
        self.assertIn('var/mode_valid = (mode in list("legacy", "parent", "candidate"))', source)
        self.assertIn('var/tick_valid = (requested_tick in list(0.5, 1))', source)
        self.assertIn('fixture_scheduler_assert(mode_valid && tick_valid, "random_mode_tick")', source)
        self.assertIn('(policy in list("held", "reissue")) && (phase_ticks in list(0, 2))', source)
        adapter = (HERE/'random_cadence_contract.py').read_text()
        self.assertIn('"random_setup" = fixture_random_setup', adapter)
        for field in ('mode_is_text', 'tick_is_text', 'requested_tick', 'initial_tick',
                      'actual_tick', 'mode_valid', 'tick_valid', 'original_combined'):
            self.assertIn('"' + field + '"', source)

    def test_selector_is_explicit_and_exclusive(self):
        self.assertEqual(contract.selection('random05'), .5)
        self.assertEqual(contract.selection('random10'), 1)
        for value in ('', 'smoke', 'random05,random10', None, 1, ['random05']):
            with self.assertRaises(ValueError): contract.selection(value)

    def test_work_budget_includes_every_phase(self):
        b = contract.budget()
        self.assertEqual(b['compiles']*b['compile_seconds'] + b['daemons']*b['daemon_seconds'] + b['setup_seconds'], 420)
        self.assertLessEqual(b['maximum_accounted_work_seconds'], b['work_seconds'])
        self.assertEqual((b['whole_seconds'], b['reserved_seconds']), (600, 110))
        self.assertEqual(controller.WORK_SECONDS, b['work_seconds'])
        self.assertEqual(controller.MAX_SECONDS, b['whole_seconds'])
        self.assertEqual(controller.MAX_LOG_PACKAGE, b['max_compressed_bytes'])
        self.assertEqual(worker.EVIDENCE_LIMIT, b['max_expanded_bytes'])
        self.assertEqual(b['max_events_per_phase'] * b['phases_per_daemon'], b['max_events_per_daemon'])
        self.assertEqual(2*b['max_move_enters'] + b['max_transactions']*b['max_events_per_transaction'] +
                         b['max_lives']*b['max_events_per_life'] + b['phase_boundary_events'],512)
        self.assertEqual(b['max_move_enters'] - b['max_transactions']*16,18)
        self.assertEqual(b['observation_ds'],28)
        self.assertEqual(contract.setup_used(10, 5), 5)
        with self.assertRaises(ValueError): contract.setup_used(61, 0)
        with self.assertRaises(ValueError): contract.setup_used(1, 2)

    def test_worker_rejects_insufficient_shared_deadline_before_git_or_native(self):
        args=SimpleNamespace(work_deadline=time.monotonic()+419, suite='random05')
        with mock.patch.object(worker,'load_module',return_value=contract), \
             mock.patch.object(worker.subprocess,'run',side_effect=AssertionError('must not launch')):
            with self.assertRaisesRegex(RuntimeError,'Insufficient shared deadline'):
                worker.run_random_cadence(args,None,None,None,None,None,None,None,0,None,None,None)
        source=inspect.getsource(worker.run_random_cadence)
        self.assertIn('contract.COMPILE_SECONDS',source)
        self.assertIn('timeout=contract.DAEMON_SECONDS',source)
        self.assertIn('contract.setup_used(',source)
        self.assertIn('time.monotonic()+settings[\'maximum_accounted_work_seconds\'] <= args.work_deadline',source)

    def test_actual_controller_command_retains_isolation_and_deadline(self):
        args = controller.create_args('name','a'*32,'b'*40,Path('/source'),Path('/binary'),Path('/archive'),
                                      '1000:1000','random05',500.0)
        for pair in (('--network','none'),('--pids-limit','64'),('--memory','3g'),('--memory-swap','3g'),
                     ('--cpus','2'),('--cap-drop','ALL'),('--suite','random05'),('--work-deadline','500.0')):
            index=args.index(pair[0]);self.assertEqual(args[index+1],pair[1])
        self.assertIn('--read-only', args)
        self.assertIn('/work:rw,noexec,nosuid,nodev,size=1073741824,mode=1777', args)
        with self.assertRaises(RuntimeError):
            controller.create_args('name','a'*32,'b'*40,Path('/source'),Path('/binary'),Path('/archive'),
                                   '1000:1000','random05')

    def test_host_scratch_estimate_accounts_for_second_stage_metadata(self):
        tree=b'100644 blob abc 100\tcode/test.dm\0'
        single=job.selected_estimate(tree,'smoke')
        paired=job.selected_estimate(tree,'random05')
        self.assertEqual(paired['archive_and_stage_estimate_bytes'] - single['archive_and_stage_estimate_bytes'],16384)
        self.assertIn('not compiled artifacts',paired['limitation'])

    def test_manual_workflow_has_exclusive_rate_guard_and_no_pr_trigger(self):
        text=(ROOT/'.github/workflows/wildlife-random-cadence.yml').read_text(encoding='utf-8')
        self.assertIn('workflow_dispatch:',text)
        self.assertNotIn('pull_request:',text)
        self.assertIn('suite: [random05, random10]',text)
        self.assertIn('max-parallel: 1',text)
        self.assertIn('fail-fast: true',text)
        self.assertIn('group: civ13-wildlife-random-cadence-exclusive',text)
        self.assertIn('cancel-in-progress: false',text)
        self.assertNotIn('queue:',text)
        self.assertIn('fetch-depth: 0',text)
        self.assertIn('persist-credentials: false',text)
        self.assertIn('test "$EXPECTED_HEAD" = "$GITHUB_SHA"',text)
        self.assertIn('--suite "$WILDLIFE_SUITE"',text)
        shim=(HERE/'random_cadence_registration.yml').read_text(encoding='utf-8')
        self.assertIn('workflow_dispatch:',shim)
        self.assertNotIn('pull_request:',shim)
        self.assertIn('exit 1',shim)
        self.assertNotIn('cloud_npc_job.py',shim)
        self.assertIn('group: civ13-wildlife-random-cadence-exclusive',shim)
        self.assertNotIn('queue:',shim)

    def test_complete_synthetic_matrix_for_each_mode_and_rate(self):
        for mode in contract.MODES:
            for tick in contract.TICKS:
                result = contract.validate(receipt(mode, tick), 'a'*40, mode, tick)
                self.assertEqual(len(result), 8)
                held = result[('mosquito', 'held', 0)]['analysis']['commands']
                self.assertEqual([c['result'] for c in held[1:]], ['fixture_suppressed']*2)
                reissued = result[('bat', 'reissue', 0)]['analysis']['commands']
                self.assertEqual(reissued[1]['result'], 'native_issued' if mode == 'legacy' else 'reaffirmed')

    def test_missing_or_stale_evidence_fails(self):
        r = receipt(); r['random_rows'].pop()
        with self.assertRaises(ValueError): contract.validate(r, 'a'*40, 'candidate', .5)

    def test_comparison_is_observational_and_preserves_distinct_paths(self):
        rows = {mode: receipt(mode) for mode in contract.MODES}
        result = contract.compare(rows, 'a'*40, .5)
        self.assertFalse(result['parity_established'])
        self.assertEqual(len(result['cases']), 8)
        case = result['cases']['bat:reissue:0']
        self.assertNotEqual(case['legacy']['physical_moves'][0]['dx'], case['parent']['physical_moves'][0]['dx'])
        self.assertEqual(case['legacy']['commands'][1]['result'], 'native_issued')
        self.assertEqual(case['parent']['commands'][1]['result'], 'reaffirmed')
        r = receipt(); r['random_rows'][0]['tick_lag_ds'] = 1
        with self.assertRaises(ValueError): contract.validate(r, 'a'*40, 'candidate', .5)
        r = receipt(); r['random_rows'][0]['events'][-1]['x'] += 1
        with self.assertRaises(ValueError): contract.validate(r, 'a'*40, 'candidate', .5)

    def test_forged_cleanup_arrival_and_unsettled_bite_fail(self):
        r = receipt(); row = r['random_rows'][0]
        next(e for e in row['events'] if e['event'] == 'tx_finished')['tx'] = 'wrong'
        with self.assertRaises(ValueError): contract.validate(r, 'a'*40, 'candidate', .5)
        r = receipt(); row = r['random_rows'][0]
        next(e for e in row['events'] if e['event'] == 'tx_finished')['tx_actor_present'] = 1
        with self.assertRaisesRegex(ValueError,'transaction finished state'):
            contract.validate(r, 'a'*40, 'candidate', .5)
        r = receipt(); row = r['random_rows'][0]
        next(e for e in row['events'] if e['event'] == 'final_pulse')['remaining_x'] = 2
        with self.assertRaises(ValueError): contract.validate(r, 'a'*40, 'candidate', .5)
        r = receipt(); row = r['random_rows'][0]; roll = next(i for i,e in enumerate(row['events']) if e['event']=='contact_roll_mosquito_bite')
        row['events'][roll]['detail']['choice'] = 1
        row['events'].insert(roll+1, event('contact_bite_before', 4, transaction=1, settled=0))
        r['random_count'] += 1
        row['event_count'] += 1
        with self.assertRaises(ValueError): contract.validate(r, 'a'*40, 'candidate', .5)

    def test_overflow_and_untethered_movement_fail(self):
        r = receipt(); r['random_overflow'] = 1
        with self.assertRaises(ValueError): contract.validate(r, 'a'*40, 'candidate', .5)
        r = receipt(); first = next(e for e in r['random_rows'][0]['events'] if e['event']=='move_enter')
        first['active_tx'] = None
        with self.assertRaisesRegex(ValueError, 'unowned competing Move'):
            contract.validate(r, 'a'*40, 'candidate', .5)
        r=receipt();row=r['random_rows'][0]
        row['events'].extend(copy.deepcopy([row['events'][-1]] * (contract.MAX_PHASE_EVENTS+1-len(row['events']))))
        row['event_count']=len(row['events']);r['random_count']=sum(len(x['events']) for x in r['random_rows'])
        with self.assertRaisesRegex(ValueError,'events'): contract.validate(r,'a'*40,'candidate',.5)

    def test_infection_lifecycle_requires_order_and_actual_result(self):
        r=receipt();row=r['random_rows'][0]
        roll=next(e for e in row['events'] if e['event']=='contact_infection_roll')
        roll['detail']['choice']=1
        with self.assertRaisesRegex(ValueError,'invalid infection roll'):
            contract.validate(r,'a'*40,'candidate',.5)
        r=receipt();row=r['random_rows'][0]
        after=next(e for e in row['events'] if e['event']=='contact_infection_after')
        after['target_disease']=1;after['target_disease_type']='malaria'
        with self.assertRaisesRegex(ValueError,'invalid infection result'):
            contract.validate(r,'a'*40,'candidate',.5)
        r=receipt();row=r['random_rows'][0]
        ix=next(i for i,e in enumerate(row['events']) if e['event']=='contact_infection_after')
        row['events'].pop(ix);row['event_count']-=1;r['random_count']-=1
        with self.assertRaisesRegex(ValueError,'incomplete Life'):
            contract.validate(r,'a'*40,'candidate',.5)
        r=receipt();row=r['random_rows'][0]
        at=row['started']+24
        ix=next(i for i,e in enumerate(row['events']) if e['event']=='contact_mosquito_life_after' and e['at']==at)
        positive=[event('contact_bite_before',at,x=37,target_brute=0),event('contact_bite_after',at,x=37,target_brute=1),
                  event('contact_infection_before',at,x=37,target_brute=1),
                  event('contact_infection_roll',at,x=37,target_brute=1,detail={'choice':1,'raw':1,'chance':20}),
                  event('contact_infection_after',at,x=37,target_brute=1,target_disease=1,target_disease_type='malaria',
                        detail={'choice':1,'raw':None,'chance':None})]
        row['events'][ix:ix]=positive;row['event_count']+=len(positive);r['random_count']+=len(positive)
        result=contract.validate(r,'a'*40,'candidate',.5)
        self.assertEqual([e['choice'] for e in result[('mosquito','held',0)]['analysis']['infections']],[0,1])

    def test_adapter_anchors_against_exact_staged_source(self):
        out = Path(tempfile.mkdtemp(prefix='civ13-random-adapter-'))
        stage = out / 'stage'
        for f in ('tests/human_subtile/probe.dm', 'tests/human_subtile/scheduler_core_draft.dm',
                  'tests/human_subtile/random_cadence_fixture.dm',
                  'code/game/mob/living/simple_animal/simple_ai.dm',
                  'code/game/mob/living/simple_animal/simple_animal.dm',
                  'code/game/mob/living/simple_animal/subtile_movement.dm',
                  'code/game/mob/living/simple_animal/hostile/mosquitoes.dm',
                  'code/game/mob/living/simple_animal/hostile/vampirebat.dm'):
            dest = stage / f; dest.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(ROOT / f, dest)
        probe=stage/'tests/human_subtile/probe.dm'
        probe.write_text(probe.read_text(encoding='utf-8').replace('\t\t\thuman_subtile_fixture_headless()',
                         '\t\t\tnpc_subtile_fixture()'),encoding='utf-8',newline='\n')
        (stage / 'human_subtile.dme').write_text('// fixture\n', encoding='utf-8')
        class Current:
            @staticmethod
            def adapt(out, manifest, relative, old, new):
                path = out / 'stage' / relative
                text = path.read_text(encoding='utf-8')
                if text.count(old) != 1: raise ValueError('anchor drift: ' + relative)
                path.write_text(text.replace(old, new), encoding='utf-8', newline='\n')
        manifest = {'dme': 'stage/human_subtile.dme', 'stage_files': {}}
        contract.adapt(out, manifest, Current())
        self.assertEqual(manifest['random_scope'], contract.SCOPE)
        self.assertIn('fixture_random_main()', (stage/'tests/human_subtile/probe.dm').read_text())
        self.assertEqual(len(manifest['stage_files']), 8)
        core=(stage/'tests/human_subtile/scheduler_core_draft.dm').read_text(encoding='utf-8')
        for label in ('mosquito_move_before','mosquito_move_after','bat_move_before','bat_move_after'):
            self.assertIn('"'+label+'"',core.split('/proc/fixture_scheduler_prob',1)[0])
        self.assertIn('if (!(label in list("mosquito_move_before", "mosquito_move_after", "bat_move_before", "bat_move_after")))\n'
                      '\t\tfixture_random_observe("contact_[label]", A,',core)
        fixture=(stage/'tests/human_subtile/random_cadence_fixture.dm').read_text(encoding='utf-8')
        self.assertEqual(fixture.count('fixture_random_observe("move_enter"'),2)
        self.assertEqual(fixture.count('fixture_random_observe("move_exit"'),2)
        filtered={'mosquito_move_before','mosquito_move_after','bat_move_before','bat_move_after'}
        # Actual subclass entry/exit plus inherited before/after for each pulse:
        emitted=['move_enter','mosquito_move_before','mosquito_move_after','move_exit']*16
        self.assertEqual(len([x for x in emitted if x not in filtered]),32)
        movement=(stage/'code/game/mob/living/simple_animal/subtile_movement.dm').read_text(encoding='utf-8')
        finish=movement.split('/datum/npc_subtile_transaction/proc/finish()',1)[1].split('/mob/living/simple_animal/proc/npc_subtile_take_pulse',1)[0]
        self.assertLess(finish.index('tx_actor_released'),finish.index('actor = null'))
        self.assertLess(finish.index('finished = TRUE'),finish.index('tx_finished'))

    def test_observer_does_not_schedule_move_or_take_ownership(self):
        text = (HERE/'random_cadence_fixture.dm').read_text(encoding='utf-8')
        observer = text.split('/proc/fixture_random_observe(', 1)[1].split('/mob/living/', 1)[0]
        for forbidden in ('sleep(', 'prob(', 'rand(', 'Move(', 'step(', 'walk(', 'spawn(', 'qdel('):
            self.assertNotIn(forbidden, observer)
        self.assertNotIn('npc_subtile_transaction =', observer)
        self.assertIn('fixture_random_phase_count >= 512 || fixture_random_count >= 4096', observer)
        for quota in ('fixture_random_life_count >= 3','fixture_random_tx_count >= 12',
                      'fixture_random_move_enter_count >= 210','fixture_random_move_exit_count >= 210'):
            self.assertIn(quota,observer)
        self.assertIn('fixture_random_overflow = TRUE',observer)
        self.assertIn('world.time < started + 28 && !fixture_random_overflow',text)

    def test_paired_staging_checks_preimages_and_breaks_mutable_links(self):
        workspace = Path(tempfile.mkdtemp(prefix='civ13-random-paired-'))
        out = workspace/'npc-smoke'; stage = out/'stage'
        files = ('tests/human_subtile/probe.dm', 'tests/human_subtile/scheduler_core_draft.dm',
                 'tests/human_subtile/random_cadence_fixture.dm',
                 'code/game/mob/living/simple_animal/simple_ai.dm',
                 'code/game/mob/living/simple_animal/simple_animal.dm',
                 'code/game/mob/living/simple_animal/subtile_movement.dm', *contract.SPECIES)
        for rel in files:
            dest=stage/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/rel,dest)
        probe=stage/'tests/human_subtile/probe.dm'
        probe.write_text(probe.read_text(encoding='utf-8').replace('\t\t\thuman_subtile_fixture_headless()',
                         '\t\t\tnpc_subtile_fixture()'),encoding='utf-8',newline='\n')
        (stage/'human_subtile.dme').write_text('// fixture\n', encoding='utf-8')
        candidates={p:(stage/p).read_bytes() for p in contract.SPECIES}
        parents={p:data.replace(contract.RANDOM_OVERRIDE,b'') for p,data in candidates.items()}
        class Current:
            @staticmethod
            def adapt(out, manifest, relative, old, new):
                path=out/'stage'/relative;text=path.read_text(encoding='utf-8')
                if text.count(old)!=1: raise ValueError('anchor drift: '+relative)
                path.write_text(text.replace(old,new),encoding='utf-8',newline='\n')
        manifest={'dme':'stage/human_subtile.dme','stage_files':{}}
        with self.assertRaises(ValueError):
            contract.prepare_pair(out, manifest, Current(), {**parents, contract.SPECIES[0]:b'bad'}, candidates)
        parent, parent_manifest=contract.prepare_pair(out, manifest, Current(), parents, candidates)
        for rel in contract.SPECIES:
            p=(parent/'stage'/rel).read_bytes();c=(stage/rel).read_bytes()
            self.assertEqual(c.replace(contract.RANDOM_OVERRIDE,b''),p)
            self.assertEqual(p,contract.species_fixture_bytes(rel,parents[rel]))
            self.assertEqual(c,contract.species_fixture_bytes(rel,candidates[rel]))
            self.assertFalse((parent/'stage'/rel).samefile(stage/rel))
        self.assertEqual(parent_manifest['random_scope'], contract.SCOPE)

    def test_independent_host_verifier_rejects_tampered_evidence(self):
        head='a'*40;parent=contract.PUBLISHED_PARENT
        candidates={p:(ROOT/p).read_bytes() for p in contract.SPECIES}
        parents={p:data.replace(contract.RANDOM_OVERRIDE,b'') for p,data in candidates.items()}
        blobs={parent:parents,head:candidates}
        resource={'bytes':100,'sha256':'f'*64,'mode':0o600}
        states={mode:{'before':resource,'after':resource,'changed':False,'integrity_verified':True} for mode in contract.MODES}
        receipts={mode:receipt(mode) for mode in contract.MODES}
        raw={mode:json.dumps(value).encode() for mode,value in receipts.items()}
        phase=lambda deadline:{'returncode':0,'timed_out':False,'oversized_log':False,'deadline':deadline,'seconds':1}
        summary={'head':head,'suite':'random05','tick':.5,'fixture_dme_only':True,'observation_complete':True,
                 'parity_established':False,'scope':contract.SCOPE,'budget':contract.budget(),
                 'resource_states':states,'artifacts':{'parent':{'human_subtile.rsc':resource},
                                                        'candidate':{'human_subtile.rsc':resource}},
                 'compiles':{'parent':phase(90),'candidate':phase(90)},
                 'results':{mode:{'daemon':phase(60),'receipt_sha256':hashlib.sha256(raw[mode]).hexdigest()}
                            for mode in contract.MODES},'child_elapsed':5,'comparison_elapsed':10,'setup_seconds':5,
                 'comparison':contract.compare(receipts,head,.5)}
        status={'head':head,'suite':'random05','outcome':'passed','phase':'complete','fixture_dme_only':True,
                'runtime_resources':states}
        entries={'harness-status.json':json.dumps(status).encode(),'smoke-summary.json':json.dumps(summary).encode()}
        for label,folder,version in (('parent','npc-parent',parent),('candidate','npc-smoke',head)):
            src=blobs[version]
            stages={p:{'bytes':len(contract.species_fixture_bytes(p,v)),
                       'sha256':hashlib.sha256(contract.species_fixture_bytes(p,v)).hexdigest()} for p,v in src.items()}
            stages['shared']={'bytes':1,'sha256':'e'*64}
            m={'head':head,'random_source_variant':label,'random_scope':contract.SCOPE,'parent_commit':parent,
               'candidate_local_commit':contract.LOCAL_CANDIDATE,'candidate_blobs':contract.CANDIDATE_BLOBS,
               'paired_preimages':{p:hashlib.sha256(v).hexdigest() for p,v in src.items()},
               'stage_files':stages}
            entries[folder+'/cloud-manifest.json']=json.dumps(m).encode()
            entries[folder+'/stage/compile-stdout.log']=b'DM OK human_subtile.dmb'
            entries[folder+'/stage/compile-stderr.log']=b''
        for mode,prefix in (('legacy','npc-parent/runtime/'),('parent','npc-parent/runtime-wildlife/'),
                            ('candidate','npc-smoke/runtime/')):
            entries[prefix+'receipt.json']=raw[mode];entries[prefix+'result.txt']=b'PASS\n';entries[prefix+'port-closed.txt']=b'closed\n'
        stub=Path(tempfile.mkdtemp(prefix='civ13-random-npc-stub-'))/'npc_stub.py'
        stub.write_text('class Legacy:\n def validate_compile(self, log, name):\n  assert log == "DM OK human_subtile.dmb" and name == "human_subtile.dmb"\nclass Current:\n legacy=Legacy()\ncurrent=Current()\n',encoding='utf-8')
        original_spec=controller.importlib.util.spec_from_file_location
        def get_spec(name,path):
            return original_spec(name,stub if name=='random_npc' else path)
        def git_output(args,**kwargs):
            if args[-2]=='rev-parse':
                if args[-1].endswith('^{tree}'):
                    return (contract.PARENT_TREE+'\n').encode()
                _,path=args[-1].split(':',1)
                return ((contract.CANDIDATE_BLOBS | {contract.CANDIDATE_TEST:contract.CANDIDATE_TEST_BLOB})[path]+'\n').encode()
            if 'diff' in args:
                return ('\n'.join(sorted(contract.FIXTURE_FILES|set(contract.SPECIES)|{contract.CANDIDATE_TEST}))+'\n').encode()
            version,path=args[-1].split(':',1)
            return blobs[version][path]
        def archive_bytes(data):
            buffer=io.BytesIO()
            with tarfile.open(fileobj=buffer,mode='w:') as tar:
                for name,content in data.items():
                    item=tarfile.TarInfo(name);item.size=len(content);tar.addfile(item,io.BytesIO(content))
            return buffer.getvalue()
        with mock.patch.object(controller.importlib.util,'spec_from_file_location',side_effect=get_spec), \
             mock.patch.object(controller.subprocess,'check_output',side_effect=git_output), \
             mock.patch.object(controller.subprocess,'run',return_value=SimpleNamespace(returncode=0)):
            controller.validate_random_evidence(archive_bytes(entries),head,'random05',['git'],{})
            altered=copy.deepcopy(summary);altered['parity_established']=True
            bad=dict(entries);bad['smoke-summary.json']=json.dumps(altered).encode()
            with self.assertRaises(RuntimeError):
                controller.validate_random_evidence(archive_bytes(bad),head,'random05',['git'],{})
            bad=dict(entries);bad['npc-parent/runtime/port-closed.txt']=b'open\n'
            with self.assertRaises(RuntimeError):
                controller.validate_random_evidence(archive_bytes(bad),head,'random05',['git'],{})


if __name__ == '__main__': unittest.main()
