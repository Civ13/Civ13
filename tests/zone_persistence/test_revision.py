"""Offline design models and source omission controls; no DM execution."""
from copy import deepcopy
from pathlib import Path
from types import SimpleNamespace as NS
import importlib.util
import unittest
from test_contract import (NAMESPACE, counter_valid, namespace_valid, validate,
                           successive_generations, registry_points)

ROOT = Path(__file__).resolve().parents[2]
CODE = (ROOT/'code/modules/persistence/zone_topology.dm').read_text()
SAVING = (ROOT/'code/modules/persistence/saving.dm').read_text()


class Allocator:
    """Independent lineage contract, not an interpreter of the production DM."""
    def __init__(self, namespace=NAMESPACE, next_counter='1', owners=None):
        if not namespace_valid(namespace) or not counter_valid(next_counter): raise ValueError('allocator')
        self.namespace, self.next = namespace, next_counter
        self.owners = dict(owners or {})
        self.high_water = next_counter

    def reserve(self, identity, owner):
        if identity in self.owners and self.owners[identity] != owner: raise ValueError('duplicate ID')
        self.owners[identity] = owner

    def allocate(self, owner):
        for _ in range(32):
            identity = f'zone:{self.namespace}:{self.next}'
            successor = str(int(self.next)+1)
            if not counter_valid(successor): raise ValueError('exhausted')
            self.next = self.high_water = successor
            if identity in self.owners: continue
            self.reserve(identity, owner)
            return identity
        raise ValueError('retry budget')

    def restore_older(self, saved_next):
        if not counter_valid(saved_next): raise ValueError('counter')
        self.next = str(max(int(saved_next), int(self.high_water)))


class Staging:
    def __init__(self):
        self.owner = object()
        self.expected = {'kept','new'}
        self.published = ['old']
        self.pending = {}
        self.surprise = False
        self.retired = []

    def register(self, token, identity, requested=None):
        if token is not self.owner: raise ValueError('owner')
        if identity != requested or identity not in self.expected or identity in self.pending:
            self.surprise = True
            raise ValueError('surprise')
        self.pending[identity] = object()

    def commit(self, retire):
        if self.surprise or set(self.pending) != self.expected: raise ValueError('inventory')
        retire('old')  # A throw here cannot publish the new index.
        if self.surprise: raise ValueError('constructor during retirement')
        self.retired.append('old')
        self.published = list(self.pending)


def production_contract(zone=CODE, saving=SAVING):
    assert 'rand(' not in zone and 'md5(' not in zone
    assert 'length(value) > 12' in zone
    assert 'attempt <= 32' in zone
    assert 'id in zone_id_reservations' in zone
    assert 'Captured zone membership differs' in zone
    assert 'Unexpected staged area constructor' in zone
    assert 'context.require_owner()' in zone.split('/proc/require_persistence_area_registry(',1)[1].split('/proc/',1)[0]
    assert 'Area registry unavailable during load/recovery' in zone
    publish = zone.split('/map_storage/proc/restore_zone_spawns()',1)[1].split('/map_storage/proc/',1)[0]
    assert 'qdel(A)' in publish
    assert publish.index('qdel(A)') < publish.index('area_list = index')
    assert 'qdel(' not in publish.split('area_list = index',1)[1]
    assert 'TICK_CHECK' not in publish.split('// No yields or callbacks',1)[1]
    assert 'capture_zone_turf(savefile, frame)' in saving
    assert saving.index('A.before_save_context(src, frame)') < saving.index('capture_zone_turf(savefile, frame)') < saving.index('for(var/obj/content in parent.contents)')
    assert saving.index('validate_captured_world_save(round_state)') < saving.index('text2file(generation,"map_saves/save_complete.txt")')
    assert 'capture_zone_topology(FALSE)' not in saving


class RevisionTests(unittest.TestCase):
    def test_custom_graph_adapters_keep_return_driven_v2_and_skip_topology(self):
        self.assertIn('var/prefix = world_state ? "round-v2" : "round-v1"', SAVING)
        self.assertIn('if(zone_export_state) finalize_zone_export(world_state)', SAVING)
        self.assertEqual(SAVING.count('rand(1, 1000000000)'),1)
        for file in ('cross_level_probe.dm','sleep_transfer_probe.dm'):
            fixture=(ROOT/'tests/world_save'/file).read_text()
            self.assertIn('capture_durable_world()',fixture)
            self.assertIn('return list("root"',fixture)

    def test_actual_load_recovery_predicate_with_injected_process_state(self):
        spec=importlib.util.spec_from_file_location('zone_source_adapter',ROOT/'tests/save_movement/source_adapter.py')
        adapter=importlib.util.module_from_spec(spec); spec.loader.exec_module(adapter)
        env=dict(persistence_active_operation=None,persistence_load_recovery_required=False,
                 map_storage=NS(dimension_recovery_required=False,dimension_budget_hold=False),
                 persistence_restart=NS(startup_hold=False))
        blocked=adapter.project(CODE,'/proc/persistence_area_registry_blocked','',env)
        self.assertFalse(blocked())
        env['persistence_active_operation']=NS(kind='save',restoring_players=False,zone_restore=None)
        self.assertFalse(blocked())
        env['persistence_active_operation']=NS(kind='load',restoring_players=False,zone_restore=None)
        self.assertTrue(blocked())
        env['persistence_active_operation'].restoring_players=True
        self.assertFalse(blocked())
        env['persistence_active_operation'].zone_restore=NS(committed=False)
        self.assertTrue(blocked())
        env['persistence_active_operation']=None
        for holder,name in ((env,'persistence_load_recovery_required'),
                            (env['map_storage'],'dimension_recovery_required'),
                            (env['map_storage'],'dimension_budget_hold'),
                            (env['persistence_restart'],'startup_hold')):
            if isinstance(holder,dict): holder[name]=True
            else: setattr(holder,name,True)
            self.assertTrue(blocked())
            if isinstance(holder,dict): holder[name]=False
            else: setattr(holder,name,False)

    def test_actual_allocator_control_flow_with_scalar_engine_adapters(self):
        spec=importlib.util.spec_from_file_location('zone_allocator_adapter',ROOT/'tests/save_movement/source_adapter.py')
        adapter=importlib.util.module_from_spec(spec); spec.loader.exec_module(adapter)
        # Project the complete production control flow. Adapt only numeric loop
        # syntax, string interpolation and native list construction; decimal
        # arithmetic remains a separately labelled scalar model boundary.
        body=adapter.extract(CODE,'/map_storage/proc/allocate_zone_id')
        body=body.replace('for(var/attempt = 1, attempt <= 32, attempt++)','for(var/attempt in attempts())')
        body=body.replace('"zone:[zone_namespace]:[zone_next_counter]"','format_id(zone_namespace, zone_next_counter)')
        body=body.replace('list("owner" = A)','reservation(A)')
        body=body.replace('throw EXCEPTION(', 'return fail(')
        projected='/map_storage/proc/allocate_zone_id(area/A)\n'+body
        adapter.FIELDS += ('zone_namespace','zone_next_counter','zone_high_water','zone_id_reservations')
        def increment(value):
            result=str(int(value)+1)
            if not counter_valid(result): raise ValueError('exhausted')
            return result
        def fail(message): raise ValueError(message)
        env=dict(zone_namespace_valid=namespace_valid,zone_counter_valid=counter_valid,
                 zone_counter_increment=increment,attempts=lambda:range(1,33),
                 format_id=lambda ns,counter:f'zone:{ns}:{counter}',reservation=lambda owner:{'owner':owner},
                 EXCEPTION=ValueError,fail=fail)
        allocate=adapter.project(projected,'/map_storage/proc/allocate_zone_id','src,A',env,True)
        state=NS(zone_namespace=NAMESPACE,zone_next_counter='1',zone_high_water={},
                 zone_id_reservations={f'zone:{NAMESPACE}:1':{'owner':None}})
        target=NS(persistence_zone_id=None)
        self.assertEqual(allocate(state,target),f'zone:{NAMESPACE}:2')
        self.assertEqual(target.persistence_zone_id,f'zone:{NAMESPACE}:2')
        state.zone_next_counter='1'
        state.zone_id_reservations={f'zone:{NAMESPACE}:{i}':{'owner':None} for i in range(1,33)}
        with self.assertRaisesRegex(ValueError,'retry budget'): allocate(state,NS(persistence_zone_id=None))

    def test_counter_bounds_and_canonical_form(self):
        for value in ('1','9','10','999999999999'): self.assertTrue(counter_valid(value))
        for value in ('0','01','-1','1.0','1e3','',None,1,'1000000000000'):
            with self.subTest(value=value): self.assertFalse(counter_valid(value))
        a = Allocator(next_counter='9')
        self.assertTrue(a.allocate('first').endswith(':9'))
        self.assertTrue(a.allocate('second').endswith(':10'))
        a = Allocator(next_counter='999999999999')
        with self.assertRaisesRegex(ValueError,'exhausted'): a.allocate('last')
        self.assertEqual(a.owners,{})

    def test_collision_reservations_skip_but_never_rename_imported_ids(self):
        identity = f'zone:{NAMESPACE}:1'
        a = Allocator(owners={identity:'imported'})
        with self.assertRaisesRegex(ValueError,'duplicate'): a.reserve(identity,'other')
        self.assertTrue(a.allocate('new').endswith(':2'))
        self.assertEqual(a.owners[identity],'imported')
        a = Allocator(owners={f'zone:{NAMESPACE}:{i}':'reserved' for i in range(1,33)})
        with self.assertRaisesRegex(ValueError,'retry budget'): a.allocate('new')
        self.assertEqual(len(a.owners),32)

    def test_older_restore_preserves_known_high_water_but_fresh_branches_can_diverge(self):
        a = Allocator(next_counter='20')
        a.restore_older('5')
        self.assertTrue(a.allocate('after rollback').endswith(':20'))
        b, c = Allocator(next_counter='5'), Allocator(next_counter='5')
        self.assertEqual(b.allocate('branch B'),c.allocate('branch C'))
        # The equality is an explicit limit, not cross-branch/global identity.

    def test_saved_counter_cannot_precede_an_imported_issued_identity(self):
        packet = successive_generations()['changed']
        packet['zones'].append(dict(id=f'zone:{NAMESPACE}:9',type='/area',fields={}))
        with self.assertRaisesRegex(ValueError,'high-water'): validate(packet,(8,8,2))
        packet['allocator']['next'] = '10'
        validate(packet,(8,8,2))

    def test_constructor_surprise_and_wrong_owner_never_publish(self):
        s = Staging()
        with self.assertRaisesRegex(ValueError,'owner'): s.register(object(),'new','new')
        with self.assertRaisesRegex(ValueError,'surprise'): s.register(s.owner,'unplanned')
        self.assertEqual(s.published,['old'])
        with self.assertRaises(ValueError): s.commit(lambda old: None)
        self.assertEqual(s.published,['old'])

    def test_retirement_failure_precedes_commit_without_claiming_world_rollback(self):
        s = Staging()
        for identity in ('kept','new'): s.register(s.owner,identity,identity)
        changed_world = ['membership already replaced']
        def fail(old): raise ValueError('retirement failed')
        with self.assertRaisesRegex(ValueError,'retirement'): s.commit(fail)
        self.assertEqual(s.published,['old'])
        self.assertEqual(changed_world,['membership already replaced'])
        s.commit(lambda old: None)
        self.assertEqual(set(s.published),{'kept','new'})

    def test_registry_unavailable_is_distinct_from_missing_and_does_not_block_saves(self):
        def lookup(kind=None,recovery=False,committed=False):
            if recovery or (kind=='load' and not committed): raise ValueError('unavailable')
            return None  # Ordinary absence, only after admission.
        for args in ({'kind':'load'},{'recovery':True}):
            with self.assertRaisesRegex(ValueError,'unavailable'): lookup(**args)
        self.assertIsNone(lookup(kind='save'))
        self.assertIsNone(lookup(kind='load',committed=True))

    def test_captured_membership_ignores_later_live_edits_but_rejects_saved_disagreement(self):
        packet = successive_generations()['changed']
        captured = deepcopy(packet)
        live_membership = ['unrelated later live change']
        validate(captured,(8,8,2))
        self.assertNotEqual(live_membership,[r['zone'] for r in captured['membership']])
        # A spawn copied before a conflicting turf capture must abort.
        captured['membership'][81]['zone'] = 'base'
        with self.assertRaisesRegex(ValueError,'spawn identity'): validate(captured,(8,8,2))
        self.assertEqual(packet['membership'][81]['zone'],'existing')

    def test_duplicate_swapped_and_missing_turf_capture_controls(self):
        for mode in ('duplicate','swapped','missing'):
            p = successive_generations()['changed']
            if mode=='duplicate': p['membership'][1]['entry'] = p['membership'][0]['entry']
            elif mode=='swapped': p['membership'][1]['index'] = 1
            else: p['membership'].pop()
            with self.subTest(mode=mode),self.assertRaises(ValueError): validate(p,(8,8,2))

    def test_production_source_contract_and_omission_controls(self):
        production_contract()
        mutants = [CODE.replace('length(value) > 12','FALSE',1),
                   CODE.replace('id in zone_id_reservations','FALSE',1),
                   CODE.replace('context.require_owner()','context.owner = null',1),
                   CODE.replace('qdel(A)','// retirement omitted',1)]
        for mutant in mutants:
            with self.subTest(mutant=mutants.index(mutant)),self.assertRaises(AssertionError): production_contract(zone=mutant)
        with self.assertRaises(AssertionError): production_contract(saving=SAVING.replace('capture_zone_turf(savefile, frame)','// capture omitted',1))

    def test_native_preparation_keeps_gates_and_membership_metadata(self):
        dme = (ROOT/'civ13.dme').read_text()
        self.assertTrue(dme.startswith('#define CIV13_ZONE_PERSISTENCE\n'))
        for file in ('code/_helpers/areas.dm','code/_helpers/game.dm','code/_helpers/unsorted.dm',
                     'code/modules/admin/verbs/adminjump.dm','code/modules/multiz/open_space.dm','code/setup.dm'):
            source=(ROOT/file).read_text()
            self.assertIn('#ifdef CIV13_ZONE_PERSISTENCE',source)
            self.assertTrue('require_persistence_area_registry' in source or 'persistence_area_registry_blocked' in source or 'startup.initialize_areas()' in source)
        self.assertIn('"/zone_capture/[frame.entry]"',CODE)
        self.assertIn('if(!("index" in F.dir)',CODE.replace('F.dir.len != 2 || ',''))


if __name__=='__main__': unittest.main()
