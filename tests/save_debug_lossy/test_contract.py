"""Offline source contracts and injected state model; not native DM execution."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]

def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')

def body(source, declaration):
    tail = source.split(declaration, 1)[1]
    return tail.split('\n/', 1)[0]

class RecoveryModel:
    def __init__(self):
        self.owner = None
        self.attempt = 0
        self.retryable = False
        self.pending = None
        self.fault_id = None
        self.attempt_id = None
        self.generation = None
        self.quarantine = {}
        self.witnesses = {}
        self.incidents = []
        self.omissions = []
        self.history = []
        self.marker = 'previous'
        self.backup = 'previous'
        self.hold = False
    def bind(self, owner):
        if self.owner is not None or not 1 <= self.attempt <= 3:
            return False
        self.owner = owner
        self.pending = None
        self.retryable = False
        self.omissions = []
        self.marker = None
        return True
    def observe(self, parent, child, now):
        if not self.owner or not child or child['kind'] != 'animal' or child['client'] or child['contents'] or child['loc'] is parent or child['deleted']:
            return
        self.pending = (parent, child, child['loc'], child['identity'], now + 300)
        self.fault_id, self.attempt_id, self.generation = object(), object(), object()
    def failure(self, reason, cleanup=True, released=True):
        if not cleanup:
            self.hold = True
        self.retryable = bool(cleanup and released and reason == 'moved_child' and self.pending)
        self.history.append((self.attempt, reason, tuple(self.omissions)))
        self.owner = None if released else self.owner
    def admit_retry(self, now, backup_valid=True, expected=None):
        if self.owner or not self.retryable or self.attempt >= 3 or not backup_valid or not self.pending or self.hold:
            return False
        if expected is not None and expected != (self.fault_id, self.attempt_id, self.generation):
            return False
        parent, child, destination, identity, expiry = self.pending
        if now > expiry or child['deleted'] or child['client'] or child['contents'] or child['loc'] is not destination or child['loc'] is parent or child['identity'] != identity or identity in self.quarantine:
            return False
        self.quarantine[identity] = child
        self.witnesses[identity] = (child, destination, identity)
        self.incidents.append(identity)
        self.pending = None
        self.fault_id = None
        return True
    def encode(self, child):
        if child['identity'] in self.quarantine:
            if not self.witness_valid(child):
                raise ValueError('changed quarantined child')
            if len(self.omissions) >= 256:
                raise ValueError('audit budget')
            self.omissions.append(child['identity'])
            return {'kind': 'entry', 'ref': 0}
        return {'kind': 'entry', 'ref': child['identity']}
    def publish(self, durable_bound=True):
        if not self.owner or not durable_bound or len(self.witnesses) != len(self.quarantine) or any(not self.witness_valid(x) for x in self.children()):
            return False
        self.marker = 'new'
        return True
    def children(self):
        return list(self.quarantine.values())
    def witness_valid(self, child):
        witness = self.witnesses.get(child['identity'])
        return bool(witness and witness[0] is child and child['identity'] is witness[2] and child['loc'] is witness[1] and not child['deleted'] and not child['client'] and not child['contents'])

def animal(loc):
    return {'kind': 'animal', 'loc': loc, 'identity': object(), 'client': False, 'contents': [], 'deleted': False}

class DebugLossySourceContracts(unittest.TestCase):
    def setUp(self):
        self.policy = read('code/modules/persistence/debug_lossy.dm')
        self.functions = read('code/modules/persistence/functions.dm')
        self.saving = read('code/modules/persistence/saving.dm')
        self.admin = read('code/modules/persistence/admin.dm')
    def test_strict_default_and_explicit_admin_mode(self):
        self.assertIn('/datum/controller/gameticker/proc/savemap(datum/persistence_restart_transaction/transaction, datum/save_debug_recovery/debug_policy)', self.functions)
        self.assertIn('if(debug_policy)', body(self.functions, '/datum/controller/gameticker/proc/savemap('))
        self.assertIn('check_rights(R_SERVER, TRUE, requester)', self.admin)
        self.assertIn('Save Map (Debug Lossy)', self.admin)
        self.assertIn('The live animal is not deleted', self.admin)
    def test_admin_request_audited_after_revalidation_and_busy_reported(self):
        def check(source):
            action = body(source, '/datum/admins/proc/save_debug_lossy()')
            spawn = action.index('spawn(0)')
            resumed = action[spawn:]
            ownership = resumed.index('requester_client.holder != requester_holder')
            rights = resumed.index('check_rights(R_SERVER, TRUE, requester)')
            identity = resumed.index('var/requester_ckey = ckey(requester_client.key)')
            log = resumed.index('log_admin("[requester_ckey] requested a debug lossy save.")')
            world_log = resumed.index('world.log << "Debug lossy save requested by administrator [requester_ckey]."')
            busy = resumed.index('if(map_storage && map_storage.debug_recovery_session)')
            message = resumed.index('another debug recovery session is active')
            call = resumed.index('ticker.debug_lossy_save()')
            self.assertLess(max(ownership, rights), identity)
            self.assertLess(identity, min(log, world_log))
            self.assertLess(max(log, world_log), busy)
            self.assertLess(busy, message)
            self.assertLess(message, call)
            self.assertIn('\n\t\t\treturn\n', resumed[busy:call])
            self.assertNotIn('if(!ticker.debug_lossy_save())', resumed)
        check(self.admin)
        for removed in ('log_admin("[requester_ckey] requested a debug lossy save.")',
                        'if(map_storage && map_storage.debug_recovery_session)',
                        'requester_client.holder != requester_holder'):
            with self.subTest(removed=removed), self.assertRaises((AssertionError, ValueError)):
                check(self.admin.replace(removed, 'REMOVED_GUARD', 1 if removed != 'requester_client.holder != requester_holder' else 3))
    def test_bound_identity_and_no_arbitrary_mutation(self):
        for required in ('max_attempts = 3', 'pending_expires = world.time + 300',
	                     'A.loc == pending_destination', '!A.client && !A.contents.len',
                         'quarantine[pending_child_ref] = A', 'omissions.len >= 256',
                         'repeated_failure_signature', 'owner != operation'):
            self.assertIn(required, self.policy)
        for forbidden in ('qdel(', 'del(', '.vars[', 'call('):
            self.assertNotIn(forbidden, self.policy)
        self.assertIsNone(re.search(r'\.loc\s*=(?!=)', self.policy))
    def test_fresh_attempt_and_previous_backup_guard(self):
        driver = body(self.policy, '/datum/controller/gameticker/proc/debug_lossy_save()')
        self.assertLess(driver.index('policy.admit_retry(policy.pending_fault_id, policy.pending_operation_id, policy.pending_generation)'), driver.index('savemap(null, policy)'))
        self.assertIn('fexists("map_saves/save_complete.txt")', driver)
        self.assertIn('debug_backup_identity_valid()', self.policy)
        self.assertIn('length(file(round_path)) > 33554432', self.policy)
        save = body(self.saving, '/map_storage/proc/save_world_contents(')
        self.assertLess(save.index('fexists("map_saves/save_complete.txt") || !debug_backup_identity_valid()'), save.index('prepare_player_ownership()'))
        self.assertNotIn('fdel(', self.policy)
        self.assertNotIn('fcopy(', self.policy)
    def test_omissions_use_null_encoding_and_candidate_validation(self):
        build = body(self.saving, '/map_storage/proc/BuildVarDirectory(')
        self.assertIn('save_debug_omits(A, null)) return 0', build)
        link = body(self.saving, '/map_storage/proc/encode_level_link(')
        self.assertIn('save_debug_omits(target, "level_link")', link)
        self.assertIn('list("kind" = "entry", "ref" = 0)', link)
        save = body(self.saving, '/map_storage/proc/save_world_contents(')
        self.assertLess(save.index('debug_policy.audit(generation, operation)'), save.index('validate_captured_world_save(round_state)'))
        self.assertLess(save.index('validate_captured_world_save(round_state)'), save.index('text2file(generation,"map_saves/save_complete.txt")'))
    def test_audit_is_generation_bound_and_bounded(self):
        for required in ('"generation" = generation', '"attempt_history"', '"incidents"',
                         '"omissions"', 'target_ref', 'source_ref', 'replacement',
                         'generation != operation.diagnostic_generation', '131072'):
            self.assertIn(required, self.policy)
        self.assertIn('!!A.loc == !!pending_destination_ref', self.policy)
        self.assertIn('valid_debug_recovery_audit(result, generation)', self.policy)
        self.assertIn('valid_debug_recovery_audit(state["debug_recovery"], marker)', self.functions)
        self.assertIn('expected_fault_id != pending_fault_id', self.policy)
        self.assertIn('expected_attempt_id != pending_operation_id', self.policy)
        self.assertIn('expected_generation != pending_generation', self.policy)
        self.assertIn('world.time > policy.pending_expires', self.policy)
        self.assertIn('map_storage.debug_recovery_session == src', self.policy)
        retry = body(self.policy, '/datum/save_debug_recovery/proc/admit_retry(')
        backup = retry.index('debug_backup_identity_valid()')
        self.assertIn('!pending_valid()', retry[:backup])
        self.assertIn('!pending_valid()', retry[backup:])
        self.assertIn('persistence_active_operation', retry[backup:])
        self.assertIn('Debug nested omission lacks list context', self.policy)
        self.assertIn('"outcome" = "candidate_commit_intent"', self.policy)

    def test_admitted_location_witness_rechecked_before_omission_and_marker(self):
        retry = body(self.policy, '/datum/save_debug_recovery/proc/admit_retry(')
        self.assertIn('quarantine_witnesses[pending_child_ref] = list(', retry)
        witness = body(self.policy, '/datum/save_debug_recovery/proc/quarantine_witness_valid(')
        for guard in ('quarantine[ref] != value', 'witness["animal"] != value',
                      '"[value.type]" != witness["animal_type"]', 'destination != witness["destination"]',
                      '!!destination != !!witness["destination_ref"]', 'destination.gc_destroyed',
                      '"\\ref[destination]" != witness["destination_ref"]',
                      '"[destination.type]" != witness["destination_type"]'):
            self.assertIn(guard, witness)
        self.assertIn('quarantine_witness_valid(ref, value)', body(self.policy, '/datum/save_debug_recovery/proc/omits('))
        self.assertIn('quarantine_witness_valid(ref, A)', body(self.policy, '/datum/save_debug_recovery/proc/audit('))
        save = body(self.saving, '/map_storage/proc/save_world_contents(')
        final_audit = save.rindex('debug_policy.audit(generation, operation)')
        marker = save.index('text2file(generation,"map_saves/save_complete.txt")')
        self.assertLess(final_audit, marker)
        for yielding in ('sleep(', 'stoplag(', 'spawn('):
            self.assertNotIn(yielding, save[final_audit:marker])

    def test_nested_location_is_bounded_and_associative_key_fails_closed(self):
        encode = body(self.saving, '/map_storage/proc/encode_saved_value_contents(')
        self.assertIn('policy.is_quarantined(key) && !isnull(associated_value)', encode)
        self.assertIn('Debug omission of an associated list key is unsupported', encode)
        self.assertIn('policy.encode_list_member(src, F, id, i, "key", key)', encode)
        self.assertIn('policy.encode_list_member(src, F, id, i, "value", associated_value)', encode)
        member = body(self.policy, '/datum/save_debug_recovery/proc/encode_list_member(')
        self.assertIn('encoding_list_context.len >= 64', member)
        self.assertIn('"z" = storage.saving_z, "list_id" = list_id, "index" = index, "side" = side, "frame" = frame', member)
        self.assertIn('encoding_list_context[encoding_list_context.len] != context', member)
        self.assertIn('owner.current(storage, "save")', member)
        self.assertIn('storage.saving_z != context["z"]', member)
        self.assertIn('if(location["frame"] == frame)', self.policy)
        self.assertIn('row["list_location"] = list("z" = location["z"]', self.policy)
        strict = encode.split('\n\t\t\t\telse\n', 1)[1]
        self.assertLess(strict.index('encoded_key = encode_saved_value(F, key)'), strict.index('encoded_value = encode_saved_value(F, (isnum(key) || isnull(key)) ? null : snapshot[key])'))
    def test_cleanup_is_owned_and_failed_cleanup_holds_only_saves(self):
        cleanup = body(self.policy, '/map_storage/proc/debug_cleanup_owned(')
        self.assertGreaterEqual(cleanup.count('operation.current(src, "save")'), 5)
        self.assertIn('if(!ok) debug_recovery_hold = TRUE', cleanup)
        self.assertIn('if(kind == "save" && storage.debug_recovery_hold)', self.functions)
        self.assertNotIn('persistence_save_in_progress = TRUE', cleanup)

class DebugLossyModelContracts(unittest.TestCase):
    def test_moved_leaf_retried_as_null_without_live_mutation(self):
        p, q = object(), object(); child = animal(q); initial = dict(child)
        r = RecoveryModel();r.attempt=1;self.assertTrue(r.bind(object()));r.observe(p,child,20);r.failure('moved_child')
        self.assertTrue(r.admit_retry(21));r.attempt=2;self.assertTrue(r.bind(object()))
        self.assertEqual(r.encode(child), {'kind':'entry','ref':0});self.assertEqual(child,initial)
        self.assertTrue(r.publish());self.assertEqual(r.backup,'previous');self.assertEqual(r.marker,'new')
    def test_strict_save_never_omits_target(self):
        r=RecoveryModel();child=animal(object());self.assertEqual(r.encode(child)['ref'],child['identity'])

    def test_moved_or_detached_after_admission_refuses_encode_and_late_publish(self):
        for phase in ('before_encode', 'after_encode'):
            for destination in ('moved', 'detached'):
                with self.subTest(phase=phase, destination=destination):
                    parent, admitted = object(), object(); child = animal(admitted)
                    r=RecoveryModel(); r.attempt=1; r.bind(object()); r.observe(parent, child, 0); r.failure('moved_child')
                    self.assertTrue(r.admit_retry(1)); r.attempt=2; self.assertTrue(r.bind(object()))
                    if phase == 'after_encode': self.assertEqual(r.encode(child), {'kind':'entry','ref':0})
                    child['loc'] = object() if destination == 'moved' else None
                    if phase == 'before_encode':
                        with self.assertRaisesRegex(ValueError, 'changed quarantined child'): r.encode(child)
                    self.assertFalse(r.publish()); self.assertIsNone(r.marker); self.assertEqual(r.backup, 'previous')
    def test_expired_or_changed_failure_capability_refuses(self):
        for change in ('expired','moved','identity','contents','client','deleted'):
            with self.subTest(change=change):
                p,q=object(),object();child=animal(q);r=RecoveryModel();r.attempt=1;r.bind(object());r.observe(p,child,0);r.failure('moved_child')
                if change=='moved': child['loc']=object()
                elif change=='identity': child['identity']=object()
                elif change=='contents': child['contents'].append(object())
                elif change=='client': child['client']=True
                elif change=='deleted': child['deleted']=True
                self.assertFalse(r.admit_retry(301 if change=='expired' else 1))
                self.assertEqual(r.backup,'previous');self.assertIsNone(r.marker)
    def test_cleanup_or_backup_failure_prevents_retry(self):
        for cleanup,backup in ((False,True),(True,False)):
            p,q=object(),object();child=animal(q);r=RecoveryModel();r.attempt=1;r.bind(object());r.observe(p,child,0);r.failure('moved_child',cleanup=cleanup)
            self.assertFalse(r.admit_retry(1,backup));self.assertEqual(r.backup,'previous')
    def test_wrong_fault_attempt_or_generation_cannot_authorize_and_replay_fails(self):
        p,q=object(),object();child=animal(q);r=RecoveryModel();r.attempt=1;r.bind(object());r.observe(p,child,0);r.failure('moved_child')
        tokens=(r.fault_id,r.attempt_id,r.generation)
        for index in range(3):
            wrong=list(tokens);wrong[index]=object()
            self.assertFalse(r.admit_retry(1,expected=tuple(wrong)))
        self.assertTrue(r.admit_retry(1,expected=tokens))
        self.assertFalse(r.admit_retry(1,expected=tokens))
    def test_nonanimal_connected_or_contained_never_eligible(self):
        for field in ('kind','client','contents'):
            p,q=object(),object();child=animal(q);child[field]={'kind':'human','client':True,'contents':[object()]}[field]
            r=RecoveryModel();r.attempt=1;r.bind(object());r.observe(p,child,0);r.failure('moved_child');self.assertFalse(r.admit_retry(1))
    def test_repeated_target_and_audit_exhaustion_stop(self):
        p,q=object(),object();child=animal(q);r=RecoveryModel();r.attempt=1;r.bind(object());r.observe(p,child,0);r.failure('moved_child');self.assertTrue(r.admit_retry(1))
        r.attempt=2;r.bind(object());r.observe(p,child,2);r.failure('moved_child');self.assertFalse(r.admit_retry(3))
        r.owner=object();r.omissions=[None]*256
        with self.assertRaisesRegex(ValueError,'audit budget'):r.encode(child)
    def test_missing_durable_binding_cannot_publish(self):
        r=RecoveryModel();r.attempt=1;r.bind(object());self.assertFalse(r.publish(durable_bound=False));self.assertIsNone(r.marker)
    def test_quarantined_animal_gaining_a_child_prevents_publication(self):
        p,q=object(),object();child=animal(q);r=RecoveryModel();r.attempt=1;r.bind(object());r.observe(p,child,0);r.failure('moved_child');self.assertTrue(r.admit_retry(1))
        r.attempt=2;r.bind(object());child['contents'].append(object())
        self.assertFalse(r.publish());self.assertIsNone(r.marker);self.assertEqual(r.backup,'previous')

if __name__ == '__main__':
    unittest.main()
