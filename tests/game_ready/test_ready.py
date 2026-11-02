"""All producer methods projected; clocks/Export/backend effects remain synthetic."""
import importlib.util
import json
from pathlib import Path
import unittest
from types import SimpleNamespace

SPEC=importlib.util.spec_from_file_location('game_ready_model',Path(__file__).with_name('model.py'))
M=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(M)


class ReadyContracts(unittest.TestCase):
    def fresh(self):
        h=M.Harness();self.assertIsNotNone(h.begin())
        self.assertFalse(h.fresh());self.assertTrue(h.initialized())
        return h

    def test_default_disabled_has_no_ticket_payload_or_transport(self):
        h=M.Harness(False)
        self.assertIsNone(h.begin())
        self.assertIsNone(h.dispatch('reserve_restore',h.context,None))
        h.fresh();h.initialized()
        self.assertFalse(h.obj.active);self.assertFalse(h.obj.committed)
        self.assertEqual((h.queue,h.requests),([],[]))

    def test_fresh_waits_for_both_latches_in_either_order(self):
        for init_first in (False,True):
            h=M.Harness();h.begin()
            if init_first:self.assertFalse(h.initialized())
            else:self.assertFalse(h.fresh())
            self.assertEqual(h.queue,[])
            self.assertTrue(h.fresh() if init_first else h.initialized())
            h.run_next()
            data=h.requests[0].data
            self.assertEqual(tuple(data),('schema','event','server','boot','round','generation_kind','generation'))
            self.assertEqual(data,dict(schema='game_ready.v1',event='game_ready',server='nomads',boot='a'*32,
                round='A1b-2_C',generation_kind='fresh',generation='fresh:'+'a'*32))
            self.assertNotIn('synthetic-key',h.obj.payload_json)
            self.assertEqual(h.obj.expected_ack,M.wire_ack(data))
            h.settle();self.assertIs(h.results[-1],True)

    def test_setup_context_is_the_exact_initial_area_token(self):
        h=M.Harness();h.begin()
        self.assertIs(h.dispatch('setup_context',h.area),h.context)
        self.assertIsNone(h.dispatch('setup_context',object()))
        h.fresh();h.initialized()
        self.assertIsNone(h.dispatch('setup_context',h.area))
        self.assertIsNone(h.obj.expected_area)

    def test_initialization_exception_or_negative_scheduler_result_never_sends(self):
        for fail_event in ('initialization_failed','initialization_complete'):
            h=M.Harness();h.begin();h.fresh()
            h.dispatch(fail_event,h.context,False)
            self.assertTrue(h.obj.failed);self.assertFalse(h.obj.committed)
            self.assertEqual(h.queue,[])

    def test_restore_waits_for_init_in_either_order_and_copies_identity(self):
        for init_first in (False,True):
            h=M.Harness();h.begin();ticket=h.reserve()
            if init_first:h.initialized()
            op=h.operation();h.restored(ticket,op)
            if not init_first:
                self.assertEqual(h.queue,[]);h.initialized()
            self.assertTrue(h.obj.committed);self.assertIsNone(ticket.operation)
            h.clock.marker='round-v2:'+'c'*32 # Never read by the producer.
            h.run_next();self.assertEqual(h.requests[0].data['generation'],'round-v2:'+'b'*32)
            self.assertEqual(h.requests[0].data['round'],'saved-round')

    def test_manual_load_without_the_reserved_ticket_cannot_emit(self):
        h=M.Harness();h.begin();h.initialized();op=h.operation()
        self.assertIsNone(h.dispatch('claim_load',None,op,h.storage,None))
        self.assertFalse(h.dispatch('loaded',None,op,h.storage,None,'saved-round','round-v2:'+'b'*32))
        self.assertFalse(h.obj.committed);self.assertEqual(h.queue,[])

    def test_unsupported_legacy_v1_or_noncanonical_round_is_suppressed(self):
        for identity,generation in (('saved-round',None),('saved-round','round-v1:'+'b'*32),
            ('saved-round','round-v2:'+'B'*32),('saved.round','round-v2:'+'b'*32),
            ('bad\nround','round-v2:'+'b'*32)):
            with self.subTest(identity=identity,generation=generation):
                h=M.Harness();h.begin();t=h.reserve();h.initialized()
                h.restored(t,h.operation(),round_id=identity,generation=generation)
                self.assertFalse(h.obj.committed);self.assertTrue(h.obj.failed)
                self.assertEqual(h.queue,[])

    def test_ticket_cannot_be_reused_or_stolen_by_other_operations(self):
        h=M.Harness();h.begin();t=h.reserve();op=h.operation()
        self.assertIs(h.dispatch('claim_load',t,op,h.storage,None),t)
        wrong=h.operation()
        self.assertFalse(h.dispatch('loaded',t,wrong,h.storage,None,'saved-round','round-v2:'+'b'*32))
        self.assertIs(t.operation,op)
        h.env['persistence_active_operation']=None
        h.env['game_id']='saved-round';h.env['persistence_player_restore_ready']=True
        self.assertFalse(h.dispatch('loaded',t,op,h.storage,None,'saved-round','round-v2:'+'b'*32))
        self.assertTrue(t.used)
        self.assertIsNone(h.dispatch('claim_load',t,h.operation(),h.storage,None))

    def test_changed_operation_storage_kind_or_transaction_rejects_completion(self):
        for field,value in (('storage',object()),('kind','save'),('restart_transaction',object())):
            h=M.Harness();h.begin();t=h.reserve();op=h.operation()
            h.dispatch('claim_load',t,op,h.storage,None)
            setattr(op,field,value);h.env['persistence_active_operation']=None
            h.env['game_id']='saved-round'
            h.dispatch('loaded',t,op,h.storage,None,'saved-round','round-v2:'+'b'*32)
            self.assertTrue(h.obj.failed);self.assertIsNone(t.operation)

    def test_preflight_retry_reuses_only_pending_restart_ticket(self):
        h=M.Harness();h.begin();t=h.reserve(True);op=h.operation();op.restart_transaction=h.restart
        h.dispatch('claim_load',t,op,h.storage,h.restart)
        h.dispatch('restart_failed',h.restart)
        self.assertFalse(h.obj.failed);self.assertIsNone(t.operation)
        self.assertIs(h.dispatch('restart_ticket',h.restart),t)
        self.assertIsNone(h.dispatch('restart_ticket',object()))
        newer=h.operation();newer.restart_transaction=h.restart
        self.assertIs(h.dispatch('claim_load',t,newer,h.storage,h.restart),t)

    def test_partial_restore_or_init_failure_releases_observer_reference_and_stops(self):
        for init_failure in (False,True):
            h=M.Harness();h.begin();t=h.reserve();op=h.operation()
            h.dispatch('claim_load',t,op,h.storage,None);op.mutation_started=True
            if init_failure:h.dispatch('initialization_failed',h.context)
            else:h.dispatch('load_failed',t,op)
            self.assertTrue(h.obj.failed);self.assertIsNone(t.operation)
            self.assertFalse(h.obj.committed)

    def test_restart_requires_consumed_intent_and_successful_player_return(self):
        h=M.Harness();h.begin();t=h.reserve(True);h.initialized()
        h.restored(t,h.operation(),True)
        self.assertFalse(h.obj.committed)
        h.restart.import_complete=True;h.restart.expected_generation='round-v2:'+'b'*32
        h.restart.players_ready=True # Flag alone precedes the real function return.
        self.assertFalse(h.dispatch('restart_completed',h.restart,False))
        self.assertFalse(h.dispatch('restart_completed',h.restart,True))
        h.restart.startup_hold=False;h.restart.busy=False;h.restart.intent=False
        self.assertTrue(h.dispatch('restart_completed',h.restart,True))
        self.assertEqual(len(h.queue),1)
        self.assertFalse(h.dispatch('restart_completed',h.restart,True))
        self.assertEqual(len(h.queue),1)

    def test_consumption_only_failure_retains_successful_import_for_same_startup_retry(self):
        h=M.Harness();h.begin();t=h.reserve(True);h.initialized()
        h.restored(t,h.operation(),True)
        self.assertFalse(h.dispatch('restart_failed',h.restart))
        self.assertFalse(h.obj.failed);self.assertTrue(t.used);self.assertIsNone(t.operation)
        h.restart.startup_hold=False;h.restart.busy=False;h.restart.intent=False
        h.restart.players_ready=True;h.restart.import_complete=True
        h.restart.expected_generation='round-v2:'+'b'*32
        self.assertTrue(h.dispatch('restart_completed',h.restart,True))

    def test_wrong_restart_owner_or_generation_cannot_complete(self):
        for wrong_owner in (False,True):
            h=M.Harness();h.begin();t=h.reserve(True);h.initialized();h.restored(t,h.operation(),True)
            h.restart.startup_hold=False;h.restart.busy=False;h.restart.intent=False
            h.restart.players_ready=True;h.restart.import_complete=True
            h.restart.expected_generation='round-v2:'+('c'*32 if not wrong_owner else 'b'*32)
            self.assertFalse(h.dispatch('restart_completed',object() if wrong_owner else h.restart,True))
            self.assertFalse(h.obj.committed)

    def test_recovery_holds_and_identity_changes_are_rechecked_before_dispatch(self):
        def cases(h):
            return [
                lambda:h.env.update(persistence_active_operation=object()),
                lambda:h.env.update(persistence_save_in_progress=True),
                lambda:h.env.update(persistence_load_recovery_required=True),
                lambda:h.env.update(persistence_startup_recovery_status='unresolved'),
                lambda:setattr(h.storage,'last_error','held'),
                lambda:setattr(h.storage,'dimension_recovery_required',True),
                lambda:setattr(h.storage,'dimension_budget_hold',True),
                lambda:setattr(h.env['world_z_budget'],'active',True),
                lambda:setattr(h.restart,'startup_hold',True),
                lambda:setattr(h.restart,'busy',True),
                lambda:setattr(h.restart,'intent',True),
                lambda:setattr(h.restart,'last_error','held'),
                lambda:setattr(h.lifecycle,'busy',True),
                lambda:setattr(h.lifecycle,'session','c'*32),
                lambda:h.env.update(map_storage=object()),
                lambda:h.env.update(game_id='different-round'),
                lambda:setattr(h.config,'webhook_game_ready_server','other'),
            ]
        for index in range(17):
            h=self.fresh();cases(h)[index]();h.run_next()
            self.assertTrue(h.obj.stopped);self.assertEqual(h.requests,[])

    def test_duplicate_completion_calls_reserve_one_payload_and_attempt(self):
        h=self.fresh()
        for _ in range(4):h.initialized();h.fresh()
        self.assertEqual(len(h.queue),1)
        h.run_next();h.start_attempt()
        self.assertEqual(len(h.requests),1);self.assertEqual(h.obj.attempts,1)
        self.assertTrue(h.obj.pending)

    def test_settled_failures_allow_only_three_attempts_with_fixed_backoff(self):
        h=self.fresh();times=[]
        for _ in range(3):
            h.run_next();times.append(h.clock.time);h.settle({'STATUS':'500 Error'})
        self.assertEqual(times,[0,50,200]);self.assertEqual(h.obj.attempts,3)
        self.assertTrue(h.obj.stopped);self.assertEqual(h.queue,[])
        self.assertEqual(len({request.data['generation'] for request in h.requests}),1)

    def test_unresolved_request_retains_ownership_and_never_overlaps(self):
        h=self.fresh();h.run_next();h.clock.time=1201
        for _ in range(4):h.start_attempt()
        self.assertEqual(len(h.requests),1);self.assertEqual(h.obj.attempts,1)
        self.assertTrue(h.obj.pending);self.assertEqual(h.queue,[])
        h.settle();self.assertFalse(h.obj.pending);self.assertTrue(h.obj.stopped)
        self.assertIs(h.results[-1],False);self.assertEqual(h.queue,[])

    def test_unavailable_destination_or_export_exception_settles_without_network(self):
        for failure in ('destination','exception'):
            h=self.fresh()
            if failure=='destination':h.config.webhook_address=None
            else:h.export_error=True
            for _ in range(3):h.run_next()
            self.assertEqual(h.obj.attempts,3);self.assertTrue(h.obj.stopped)
            self.assertEqual(h.requests,[]);self.assertEqual(h.queue,[])

    def test_identity_is_rechecked_after_export_yield(self):
        h=self.fresh();h.run_next();h.env['game_id']='new-round';h.settle()
        self.assertIs(h.results[-1],False);self.assertTrue(h.obj.stopped)
        self.assertEqual(len(h.requests),1);self.assertEqual(h.queue,[])

    def test_ack_requires_status_and_exact_hash_with_case_insensitive_unique_header(self):
        h=self.fresh();expected=h.obj.expected_ack
        for response,accepted in (
            ({'STATUS':'200 OK','x-civ13-game-ready':expected},True),
            ({'STATUS':'202','X-CIV13-GAME-READY':expected},True),
            ({'STATUS':'2000','X-Civ13-Game-Ready':expected},False),
            ({'STATUS':'204 No Content','X-Civ13-Game-Ready':expected},False),
            ({'STATUS':'200 OK'},False),({},False),
            ({'STATUS':'202','X-Civ13-Game-Ready':'0'*32},False),
            ({'STATUS':'202','X-Civ13-Game-Ready':expected,'x-civ13-game-ready':expected},False)):
            with self.subTest(response=response):
                self.assertEqual(h.obj.acknowledged(M.DMDict(response)),accepted)

    def test_ack_never_reads_response_content_and_repeated_begin_does_not_reset(self):
        h=self.fresh()
        class NoContent(M.DMDict):
            def __getitem__(self,key):
                if key=='CONTENT':raise AssertionError('response body read')
                return super().__getitem__(key)
        response=NoContent(STATUS='202',CONTENT=object())
        response['X-Civ13-Game-Ready']=h.obj.expected_ack
        self.assertTrue(h.obj.acknowledged(response))
        self.assertIsNone(h.dispatch('begin',h.area))
        self.assertEqual(len(h.queue),1)

    def test_shared_wire_vectors_match_production_payload_and_lf_ack(self):
        rows=json.loads((Path(__file__).parent/'fixtures/wire-vectors.json').read_text())
        for row in rows:
            h=M.Harness();h.begin()
            if row['data']['generation_kind']=='fresh':
                h.fresh();h.initialized()
            else:
                t=h.reserve();h.restored(t,h.operation());h.initialized()
            h.run_next()
            self.assertEqual(h.requests[0].data,row['data'])
            self.assertEqual(h.obj.expected_ack,row['ack'])
            self.assertEqual(M.wire_ack(row['data']),row['ack'])

    def test_source_validators_reject_noncanonical_ascii_length_and_boot(self):
        h=M.Harness();allowed=set('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-')
        for value in map(chr,range(128)):
            self.assertEqual(h.env['game_ready_identifier'](value,128),value in allowed)
        for value in ('','a'*129,'é','x\ny',None):
            self.assertFalse(h.env['game_ready_identifier'](value,128))
        for value in ('A'*32,'g'*32,'a'*31,'a'*33,None):
            self.assertFalse(h.env['game_ready_hex'](value))
        self.assertTrue(h.env['game_ready_hex']('0123456789abcdef'*2))


if __name__=='__main__':unittest.main()
