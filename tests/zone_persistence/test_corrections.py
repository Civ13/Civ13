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
    assert 'catch(var/exception/E)\n\t\t\tarea_startup.close()' in world
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
        context=NS(require_owner=lambda:calls.append('owner'))
        env=dict(restored_zones={'local':local},validated_zones={'local':{'fields':fields}},tick=lambda:calls.append('tick'),EXCEPTION=ValueError)
        env['fail']=lambda message:(_ for _ in ()).throw(ValueError(message))
        reconcile=adapter.project(source,'/map_storage/proc/reconcile_saved_zone_weather','context',env)
        reconcile(context)
        self.assertEqual((local.weather,local.weather_intensity),(2,1.25))
        self.assertEqual((local.icon,local.icon_state),('icons/custom/area.dmi','snow1'))
        self.assertGreaterEqual(calls.count('owner'),3)
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
        env=dict(parent=lambda:calls.append('atom'),persistence_register_area=lambda area:calls.append('register'))
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
