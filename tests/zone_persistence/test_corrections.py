"""Offline source projections/omission controls; no native DM execution."""
from pathlib import Path
from types import SimpleNamespace as NS
import importlib.util
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
def read(path): return (ROOT/path).read_text(encoding='utf-8-sig')
ZONE=read('code/modules/persistence/zone_topology.dm')
AREAS=read('code/_helpers/areas.dm')
WORLD=read('code/world.dm')
SETUP=read('code/setup.dm')
INIT=read('code/game/turfs/initialization/init.dm')
spec=importlib.util.spec_from_file_location('correction_adapter',ROOT/'tests/save_movement/source_adapter.py')
adapter=importlib.util.module_from_spec(spec); spec.loader.exec_module(adapter)


def correction_contract(zone=ZONE, areas=AREAS, world=WORLD, setup=SETUP, init=INIT):
    public=adapter.extract(zone,'/proc/require_persistence_area_registry')
    assert 'bootstrap' not in public
    assert 'if(persistence_area_registry_blocked()) throw' in public
    assert 'startup.initialize_areas()' in setup
    assert 'require_persistence_area_registry(null, TRUE)' not in setup
    assert 'persistence_area_startup_token = area_startup' in world
    assert 'setup_everything(area_startup)' in world
    # The failure path may notify readiness hooks first, but must close the
    # one-shot startup token before rethrowing.
    failure=world.split('setup_everything(area_startup)\n\t\tcatch(var/exception/E)\n',1)[1].split('\n\t\tarea_startup.close()',1)[0]
    assert '\t\t\tarea_startup.close()' in failure and failure.index('\t\t\tarea_startup.close()') < failure.index('\t\t\tthrow E')
    start=adapter.extract(zone,'proc/initialize_areas')
    assert 'if(used || persistence_area_startup_token != src)' in start
    assert 'used = TRUE' in start
    assert start.index('used = TRUE') < start.index('A.initialize(src)')
    assert 'catch(var/exception/E)\n\t\tclose()' in start
    assert start.rstrip().endswith('close()')
    assert 'epoch != persistence_area_epoch' in adapter.extract(zone.split('/datum/persistence_area_startup\n',1)[1].split('/area/var/tmp/',1)[0],'proc/require_owner')
    selected=adapter.extract(areas,'/proc/get_area_turfs',defines={'CIV13_ZONE_PERSISTENCE':True})
    for anchor in ('season_work_pause(season_epoch, ++season_work, TRUE)',
                   'season_work_pause(season_epoch, season_work, TRUE)'):
        tail=selected.split(anchor,1)[1]
        assert tail.index('require_persistence_area_snapshot(registry_epoch)') < tail.index('if (')
    assert selected.count('var/accepted = persistence_area_predicates_true') == 3
    assert selected.count('require_persistence_area_snapshot(registry_epoch)') == 5
    for part in selected.split('var/accepted = persistence_area_predicates_true')[1:]:
        assert part.index('require_persistence_area_snapshot(registry_epoch)') < part.index('if (accepted)')
    callback=adapter.extract(areas.rsplit('#endif',1)[0],'/proc/persistence_area_predicates_true',defines={'CIV13_ZONE_PERSISTENCE':True})
    assert 'var/accepted = call(callbacks[i])(T)\n\t\trequire_persistence_area_snapshot(epoch)' in callback
    assert 'startup.require_owner()' in init
    assert init.count('else require_persistence_area_snapshot(registry_epoch)') == 4
    weather=adapter.extract(zone,'/map_storage/proc/reconcile_saved_zone_weather')
    assert 'context.require_owner()' in weather
    assert 'A.weather != fields["weather"]' in weather
    assert 'A.weather_intensity != fields["weather_intensity"]' in weather
    assert 'A.icon_state = fields["icon_state"]' in weather
    assert 'A.weather =' not in weather and 'A.weather_intensity =' not in weather
    assert 'A.icon =' not in weather
    assert 'schema["icon_state"] = "text"' in zone
    publish=adapter.extract(zone,'/map_storage/proc/restore_zone_spawns')
    assert publish.index('next_epoch = new') < publish.index('reconcile_saved_zone_weather(C)')
    assert 'persistence_area_epoch = next_epoch' in publish
    assert 'invalidate_persistence_area_snapshots()' not in publish
    assert publish.index('reconcile_saved_zone_weather(C)') < publish.rindex('verify_zone_topology()') < publish.index('area_list = index')


class Corrections(unittest.TestCase):
    def test_source_contract_and_negative_omissions(self):
        correction_contract()
        mutations=[dict(zone=ZONE.replace('if(persistence_area_registry_blocked()) throw','if(FALSE) throw',1)),
                   dict(zone=ZONE.replace('used = TRUE','used = FALSE',1)),
                   dict(zone=ZONE.replace('A.icon_state = fields["icon_state"]','A.icon_state = ""',1)),
                   dict(zone=ZONE.replace('A.weather != fields["weather"]','FALSE',1)),
                   dict(zone=ZONE.replace('A.icon_state = fields["icon_state"]',"A.icon = 'icons/effects/weather.dmi'\n\t\tA.icon_state = fields[\"icon_state\"]",1)),
                   dict(areas=AREAS.replace('require_persistence_area_snapshot(registry_epoch)','// omitted',1)),
                   dict(areas=AREAS.replace('var/accepted = call(callbacks[i])(T)\n\t\trequire_persistence_area_snapshot(epoch)','var/accepted = call(callbacks[i])(T)\n\t\t// omitted',1)),
                   dict(world=WORLD.replace('area_startup.close()','// omitted',1)),
                   dict(init=INIT.replace('else require_persistence_area_snapshot(registry_epoch)','else return',1))]
        for n,mutant in enumerate(mutations):
            with self.subTest(omission=n),self.assertRaises(AssertionError): correction_contract(**mutant)

    def cave_restore_scene(self, levels, layout, existing=False, source=None):
        """Execute the actual restore control flow with fake BYOND boundaries."""
        source = source or read('code/modules/multiz/dug_underground.dm')
        body = adapter.extract(source, '/map_storage/proc/restore_dug_underground')
        body = body.replace('TICK_CHECK', 'tick()')
        projected = '/map_storage/proc/restore_dug_underground()\n' + body + '\n'
        events = []

        class DMList(list):
            @property
            def len(self): return len(self)
            def __iadd__(self, value):
                self.append(value)
                return self
            def Cut(self): events.append('breaches cleared')

        class Area:
            def __init__(self, kind):
                self.type = kind
                self.contents = Members(self)

        class Members:
            def __init__(self, owner): self.owner = owner
            def Add(self, turfs):
                for turf in turfs:
                    turf.loc = self.owner
                events.append(('assigned', len(turfs)))

        default, saved = Area('default'), Area('saved')
        cave = Area('cave') if existing else None
        holder = NS(cave=cave, created=0, lookups=[])
        cells = {}
        for z, kinds in layout.items():
            cells[z] = [NS(loc={'default': default, 'saved': saved, 'cave': cave}[kind])
                        for kind in kinds]

        def lookup(create=True):
            holder.lookups.append(create)
            if not holder.cave and create:
                holder.cave = Area('cave')
                holder.created += 1
            return holder.cave

        def block(first, last):
            self.assertEqual(first[2], last[2])
            return cells.get(first[2], [])

        env = dict(underground_levels_refresh=lambda: events.append('refresh'),
                   tunnel_breaches=DMList(), underground_breach_scan=lambda z: events.append(('breach', z)),
                   underground_level_z=lambda: 1, dug_underground_area=lookup,
                   underground_levels=lambda: levels, building_base_maxz=lambda: 2,
                   list=DMList, typed_iter=lambda values, _type: values,
                   block=block, locate=lambda x, y, z: (x, y, z),
                   world=NS(area='default', maxx=4, maxy=4), tick=lambda: None,
                   dug_underground_light_level=lambda z: events.append(('light', z)))
        adapter.project(projected, '/map_storage/proc/restore_dug_underground', '', env)()
        return holder, cells, default, saved, events

    def test_cave_lookup_respects_no_create_and_reuses_existing_area(self):
        source = read('code/modules/multiz/dug_underground.dm')
        body = adapter.extract(source, '/proc/dug_underground_area')
        expression = 'return create ? new /area/caribbean/void/caves : null'
        self.assertIn(expression, body)
        # Keep the helper's branches and loop; fake only the native constructor
        # and path identity, which the Python source adapter cannot represent.
        body = body.replace(expression, 'return make_cave() if create else None')
        body = body.replace('A.type == /area/caribbean/void/caves', 'A.type == CAVE_TYPE')
        projected = '/proc/dug_underground_area(create)\n' + body + '\n'
        areas, made = [], []
        def make_cave():
            area = NS(type='cave')
            made.append(area)
            areas.append(area)
            return area
        env = dict(world=areas, CAVE_TYPE='cave', make_cave=make_cave,
                   typed_iter=lambda values, _type: values)
        lookup = adapter.project(projected, '/proc/dug_underground_area', 'create=True', env)
        self.assertIsNone(lookup(False))
        self.assertEqual(made, [])
        cave = lookup(True)
        self.assertEqual(len(made), 1)
        self.assertIs(lookup(False), cave)
        self.assertIs(lookup(True), cave)
        self.assertEqual(len(made), 1)

    def test_cave_restore_does_not_create_without_strays(self):
        source = read('code/modules/multiz/dug_underground.dm')
        for levels, layout, existing in [([], {}, False), ([1, 2], {1: ['default']}, False),
                                         ([3], {3: ['saved']}, False),
                                         ([3], {3: ['cave', 'saved']}, True)]:
            with self.subTest(levels=levels, existing=existing):
                holder, cells, _, saved, events = self.cave_restore_scene(levels, layout, existing, source)
                self.assertEqual(holder.created, 0)
                self.assertEqual(holder.lookups, [False])
                self.assertNotIn('assigned', [e[0] for e in events if isinstance(e, tuple)])
                if layout.get(3) == ['cave', 'saved']:
                    self.assertIs(cells[3][0].loc, holder.cave)
                    self.assertIs(cells[3][1].loc, saved)
                self.assertLess(events.index(('breach', 1)), events.index(('light', 3)) if 3 in levels else len(events))
        # Restoring the old eager constructor must fail the no-level case.
        mutant = source.replace('dug_underground_area(FALSE)', 'dug_underground_area()', 1)
        self.assertNotEqual(mutant, source)
        holder, *_ = self.cave_restore_scene([], {}, source=mutant)
        with self.assertRaises(AssertionError):
            self.assertEqual(holder.created, 0)

    def test_cave_restore_moves_only_strays_and_reuses_one_cave(self):
        source = read('code/modules/multiz/dug_underground.dm')
        for existing in (False, True):
            with self.subTest(existing=existing):
                holder, cells, default, saved, events = self.cave_restore_scene(
                    [1, 3, 4], {1: ['default'], 3: ['default', 'saved'], 4: ['default']}, existing, source)
                self.assertEqual(holder.created, 0 if existing else 1)
                self.assertIs(cells[1][0].loc, default)  # compiled level is excluded
                self.assertIs(cells[3][0].loc, holder.cave)
                self.assertIs(cells[4][0].loc, holder.cave)
                self.assertIs(cells[3][1].loc, saved)
                self.assertEqual([e for e in events if isinstance(e, tuple) and e[0] == 'light'],
                                 [('light', 3), ('light', 4)])
        # An omitted assignment must fail the same membership assertion.
        mutant = source.replace('caves.contents.Add(strays)', 'tick()', 1)
        self.assertNotEqual(mutant, source)
        holder, cells, _, _, _ = self.cave_restore_scene([3], {3: ['default']}, source=mutant)
        with self.assertRaises(AssertionError):
            self.assertIs(cells[3][0].loc, holder.cave)

    def test_predicate_load_cannot_reuse_turf_for_the_next_callback(self):
        body=adapter.extract(AREAS.rsplit('#endif',1)[0],'/proc/persistence_area_predicates_true',defines={'CIV13_ZONE_PERSISTENCE':True})
        body=body.replace('for(var/i = 1, i <= callbacks.len, i++)','for(var/i in indices(callbacks))')
        body=body.replace('call(callbacks[i])(T)','invoke(callbacks[i],T)')
        source='/proc/persistence_area_predicates_true(T,predicates,epoch)\n'+body
        before=object(); state=NS(epoch=before);called=[]
        def gate(epoch):
            if epoch is not state.epoch: raise ValueError('expired')
        def first(turf): called.append('first'); state.epoch=object(); return True
        def second(turf): called.append('second'); return True
        class Callbacks(list):
            def Copy(self): return Callbacks(self)
        env=dict(require_persistence_area_snapshot=gate,functional_sanity=lambda a,b:None,
                 list=lambda value:[value],indices=lambda c:range(len(c)),invoke=lambda p,t:p(t))
        run=adapter.project(source,'/proc/persistence_area_predicates_true','T,predicates,epoch',env)
        with self.assertRaisesRegex(ValueError,'expired'): run(object(),Callbacks([first,second]),before)
        self.assertEqual(called,['first'])

    def test_actual_snapshot_gate_rejects_active_and_completed_loads(self):
        old,new=object(),object()
        state=NS(blocked=False)
        def admission():
            if state.blocked: raise ValueError('admission')
        env=dict(require_persistence_area_registry=admission,persistence_area_epoch=old,EXCEPTION=ValueError)
        env['fail']=lambda message:(_ for _ in ()).throw(ValueError(message))
        gate=adapter.project(ZONE.replace('throw EXCEPTION(', 'return fail('),'/proc/require_persistence_area_snapshot','epoch',env)
        gate(old)
        state.blocked=True
        with self.assertRaisesRegex(ValueError,'admission'): gate(old)
        state.blocked=False
        env['persistence_area_epoch']=new
        with self.assertRaisesRegex(ValueError,'expired'): gate(old)
        gate(new)  # Ordinary save does not rotate the epoch or close admission.
        with self.assertRaisesRegex(ValueError,'expired'): gate(None)

    def test_actual_startup_owner_checks_identity_epoch_and_operations(self):
        adapter.FIELDS += ('used','active','epoch')
        token=NS(used=True,active=True,epoch=object())
        env=dict(persistence_area_startup_token=token,persistence_area_epoch=token.epoch,
                 persistence_active_operation=None,persistence_load_recovery_required=False,
                 map_storage=NS(dimension_recovery_required=False,dimension_budget_hold=False),EXCEPTION=ValueError)
        env['fail']=lambda message:(_ for _ in ()).throw(ValueError(message))
        selected=ZONE.split('/datum/persistence_area_startup\n',1)[1].split('/area/var/tmp/',1)[0]
        gate=adapter.project(selected.replace('throw EXCEPTION(', 'return fail('),'proc/require_owner','src',env,True)
        gate(token)
        for field,value in [('used',False),('active',False),('epoch',object())]:
            before=getattr(token,field);setattr(token,field,value)
            with self.subTest(field=field),self.assertRaises(ValueError): gate(token)
            setattr(token,field,before)
        for key,value in [('persistence_area_startup_token',object()),('persistence_active_operation',object()),('persistence_load_recovery_required',True)]:
            before=env[key];env[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError): gate(token)
            env[key]=before

    def test_one_shot_closes_on_error_and_cannot_be_reentered_model(self):
        class Pass:
            def __init__(self): self.used=False; self.active=False
            def run(self,callback):
                if self.used: raise ValueError('consumed')
                self.used=True;self.active=True
                try: callback()
                finally: self.active=False
        for mode in ('ok','failure','reentrant'):
            token=Pass()
            def action():
                if mode=='failure': raise ValueError('callback')
                if mode=='reentrant': token.run(lambda:None)
            try: token.run(action)
            except ValueError: pass
            self.assertFalse(token.active)
            with self.assertRaisesRegex(ValueError,'consumed'): token.run(lambda:None)

    def test_actual_weather_reconciliation_preserves_local_scalars(self):
        # Project the complete body; replace only the scheduler boundary.
        body=adapter.extract(ZONE,'/map_storage/proc/reconcile_saved_zone_weather').replace('TICK_CHECK','tick()').replace('throw EXCEPTION(', 'return fail(')
        source='/map_storage/proc/reconcile_saved_zone_weather(context)\n'+body
        local=NS(persistence_zone_id='local',weather=2,weather_intensity=1.25,icon='icons/custom/area.dmi',icon_state='wrong')
        fields=dict(weather=2,weather_intensity=1.25,icon_state='snow1')
        calls=[]
        # An outdoor zone: the roof weather mask (weather_chunks.dm) leaves it alone.
        local.weather_roof_mask=lambda:calls.append('mask')
        context=NS(require_owner=lambda:calls.append('owner'))
        env=dict(restored_zones={'local':local},validated_zones={'local':{'fields':fields}},tick=lambda:calls.append('tick'),EXCEPTION=ValueError)
        env['fail']=lambda message:(_ for _ in ()).throw(ValueError(message))
        reconcile=adapter.project(source,'/map_storage/proc/reconcile_saved_zone_weather','context',env)
        reconcile(context)
        self.assertEqual((local.weather,local.weather_intensity),(2,1.25))
        self.assertEqual((local.icon,local.icon_state),('icons/custom/area.dmi','snow1'))
        self.assertGreaterEqual(calls.count('owner'),3)
        self.assertEqual(calls.count('mask'),1)
        mutant=source.replace('A.icon_state = fields["icon_state"]',
                              "A.icon = 'icons/effects/weather.dmi'\n\t\tA.icon_state = fields[\"icon_state\"]")
        regressed=adapter.project(mutant,'/map_storage/proc/reconcile_saved_zone_weather','context',env)
        regressed(context)
        with self.assertRaises(AssertionError):
            self.assertEqual(local.icon,'icons/custom/area.dmi')
        local.icon='icons/custom/area.dmi'

        # Mismatch rejects before rebuilding appearances; no global weather input.
        local.weather=9;local.icon_state='sentinel'
        with self.assertRaisesRegex(ValueError,'weather changed'): reconcile(context)
        self.assertEqual(local.icon_state,'sentinel')
        context.require_owner=lambda:(_ for _ in ()).throw(ValueError('unowned'))
        with self.assertRaisesRegex(ValueError,'unowned'): reconcile(context)

    def test_both_new_overrides_are_included_and_parent_chain_registers(self):
        dme=read('civ13.dme')
        self.assertLess(dme.index('code\\game\\area\\areas.dm'),dme.index('code\\modules\\lighting\\lighting_area.dm'))
        early=read('code/game/area/areas.dm')
        late=read('code/modules/lighting/lighting_area.dm')
        calls=[]
        env=dict(parent=lambda:calls.append('atom'),persistence_register_area=lambda area:calls.append('register'),
                 weather_roof_mask=lambda:None)
        # The adapter models documented .. chaining, not compiler acceptance.
        adapter.FIELDS += ('icon','layer','luminosity','dynamic_lighting')
        first=adapter.project(early.replace('..()','parent()'),'/area/New','src',env,True)
        env2=dict(parent=lambda:first(area))
        last=adapter.project(late.replace('..()','parent()'),'/area/New','src',env2,True)
        area=NS(dynamic_lighting=True,luminosity=True)
        last(area)
        self.assertEqual(calls,['atom','register'])
        self.assertFalse(area.luminosity)
        self.assertEqual(early.count('/area/Destroy()'),1)
        # Omission control: later override without parent loses registration.
        calls.clear()
        omitted=adapter.project(late.replace('. = ..()','. = FALSE'),'/area/New','src',{},True)
        omitted(area)
        self.assertEqual(calls,[])

if __name__=='__main__': unittest.main()
