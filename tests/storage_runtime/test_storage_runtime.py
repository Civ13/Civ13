"""Storage-session and legacy-import projections; no BYOND or live state."""
import importlib.util
from pathlib import Path
import re
import unittest
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('storage_source_adapter', ROOT/'tests/save_movement/source_adapter.py')
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)
A.FIELDS += ('boxes','storage_start','storage_continue','storage_end','closer','contents',
             'is_seeing','storage_slots','use_sound','loc','hide_from','show_to','orient2hud','s_active')
STORAGE = (ROOT/'code/game/objects/items/weapons/storage/storage.dm').read_text(encoding='utf8')
PERSISTENCE = (ROOT/'code/modules/persistence/functions.dm').read_text(encoding='utf8')
SAVING = (ROOT/'code/modules/persistence/saving.dm').read_text(encoding='utf8')
LOADING = (ROOT/'code/modules/persistence/loading.dm').read_text(encoding='utf8')
SLEEP = (ROOT/'code/game/mob/living/carbon/human/human_helpers.dm').read_text(encoding='utf8')
BED = (ROOT/'code/modules/persistence/bed_return.dm').read_text(encoding='utf8')
LOGIN = (ROOT/'code/game/mob/login.dm').read_text(encoding='utf8')
RUNTIME_CONTROLS = ('is_seeing','boxes','storage_start','storage_continue','storage_end',
                    'stored_start','stored_continue','stored_end','closer')

def body(source, declaration):
    return A.extract(source, declaration)

def storage_filter(source=STORAGE, parent=lambda key: False):
    actual=body(source,'/obj/item/weapon/storage/persistence_runtime_var')
    assert actual.count('return ..()') == 1
    projected='/fixture(key)\n'+actual.replace('return ..()', 'return parent_runtime(key)')+'\n'
    return A.project(projected,'/fixture','key',{'list':lambda *values: values,'parent_runtime':parent})

class DMList(set):
    def __isub__(self, item):
        if isinstance(item,(list,set,tuple)):self.difference_update(item)
        else:self.discard(item)
        return self
    def __ior__(self, item):
        if isinstance(item,(list,set,tuple)):self.update(item)
        else:self.add(item)
        return self
    def __iadd__(self, item):
        return self.__ior__(item)

class Control:
    def __init__(self):self.icon=None
class Item:
    def on_found(self,user):return False
class FakeBag:
    def __init__(self):
        for name in RUNTIME_CONTROLS[1:]:setattr(self,name,Control())
        self.is_seeing=DMList();self.contents=[Item()];self.storage_slots=1
        self.use_sound=None;self.loc=None
    def __iter__(self):return iter(self.contents)
    def orient2hud(self,user):
        # Inert boundary retains the actual layout code's closer dereference.
        self.closer.screen_loc='fixture'
class Actor:
    def __init__(self):
        self.s_active=None;self.client=SimpleNamespace(screen=DMList(),prefs=SimpleNamespace(UI_file='ui'))

def install_storage(source=STORAGE):
    env={'typed_iter':lambda xs,kind: xs,'playsound':lambda *args:None}
    for name in ('hide_from','close','show_to','open'):
        fn=A.project(source,'/obj/item/weapon/storage/proc/'+name,'src,user',env,method=True)
        setattr(FakeBag,name,fn)

class StorageRuntime(unittest.TestCase):
    def test_legacy_null_control_breaks_reopen_but_guard_preserves_constructor(self):
        self.assertIn('if (src.vars[key] != initial(src.vars[key])',PERSISTENCE)
        self.assertRegex(PERSISTENCE,r'/obj/screen\s+should_save = FALSE')
        for name in ('boxes','storage_start','storage_continue','storage_end','closer'):
            self.assertRegex(STORAGE,r'(?m)^\s*'+name+r' = new /obj/screen')
        for proc in ('/obj/item/weapon/storage/proc/slot_orient_objs','/obj/item/weapon/storage/proc/space_orient_objs'):
            self.assertIn('closer.screen_loc =',body(STORAGE,proc))
        install_storage();user=Actor();broken=FakeBag();broken.closer=None
        with self.assertRaises(AttributeError):broken.open(user)
        repaired=FakeBag();original=repaired.closer
        if not storage_filter()('closer'):repaired.closer=None
        repaired.open(user)
        self.assertIs(repaired.closer,original);self.assertIs(user.s_active,repaired)

    def test_control_references_round_trip_and_historical_nulls(self):
        policy=storage_filter(); bag=FakeBag(); original={n:getattr(bag,n) for n in RUNTIME_CONTROLS}
        # The actual saver encodes non-saveable screen objects as entry/ref=0,
        # and the actual loader decodes that entry as null before assignment.
        self.assertIn('if(!A.should_save)\n\t\treturn 0',SAVING)
        self.assertIn('if(!value["ref"])\n\t\t\t\treturn null',LOADING)
        self.assertIn('if(object.persistence_runtime_var(v))',LOADING)
        for key in RUNTIME_CONTROLS:
            historical=None
            if not policy(key):setattr(bag,key,historical)
        for key in RUNTIME_CONTROLS:self.assertIs(getattr(bag,key),original[key],key)
        self.assertEqual(len(bag.contents),1)
        self.assertFalse(policy('contents'));self.assertFalse(policy('max_storage_space'))
        self.assertTrue(storage_filter(parent=lambda key:key=='inherited')('inherited'))

    def test_each_omitted_guard_recreates_the_lost_runtime_field(self):
        policy=storage_filter()
        match=re.search(r'if \(key in list\(([^\n]+)\)\)',STORAGE)
        self.assertIsNotNone(match)
        for missing in RUNTIME_CONTROLS:
            bag=FakeBag(); original=getattr(bag,missing)
            names=[key for key in RUNTIME_CONTROLS if key!=missing]
            mutated=STORAGE[:match.start(1)]+', '.join('"'+key+'"' for key in names)+STORAGE[match.end(1):]
            mutant=storage_filter(mutated)
            self.assertTrue(policy(missing));self.assertFalse(mutant(missing))
            if not mutant(missing):setattr(bag,missing,None)
            with self.subTest(missing=missing):self.assertIsNot(getattr(bag,missing),original)

    def test_mob_active_storage_is_runtime_only_without_losing_other_vars(self):
        mob=body(PERSISTENCE,'/mob/persistence_runtime_var')
        switch=mob.split('\n\tswitch(key)\n',1)[1].split('\n\treturn ..()',1)[0]
        keys=re.findall(r'"([^"\n]+)"',switch)
        self.assertIn('s_active',keys)
        self.assertNotIn('back',keys);self.assertNotIn('contents',keys)
        restored={'s_active':None,'back':'backpack','contents':['tool']}
        saved={'s_active':'legacy-view','back':'backpack','contents':['tool']}
        for key,value in saved.items():
            if key not in keys:restored[key]=value
        self.assertEqual(restored,{'s_active':None,'back':'backpack','contents':['tool']})
        self.assertEqual({**restored,'s_active':saved['s_active']}['s_active'],'legacy-view')

    def test_reconnect_closes_stale_view_and_reopening_restores_controls(self):
        install_storage(); user=Actor(); bag=FakeBag(); bag.loc=user
        bag.open(user); self.assertIs(user.s_active,bag); self.assertIn(bag.boxes,user.client.screen)
        user.client=None;bag.close(user)
        self.assertIsNone(user.s_active);self.assertNotIn(user,bag.is_seeing)
        user.client=Actor().client;bag.open(user)
        self.assertIs(user.s_active,bag);self.assertIn(user,bag.is_seeing)
        self.assertIn(bag.boxes,user.client.screen);self.assertIn(bag.closer,user.client.screen)
        self.assertIn(bag.contents[0],user.client.screen)

    def test_stale_close_does_not_clear_another_active_storage(self):
        install_storage();user=Actor();old=FakeBag();current=FakeBag()
        old.open(user);current.open(user);self.assertIs(user.s_active,current)
        old.close(user)
        self.assertIs(user.s_active,current);self.assertIn(current.boxes,user.client.screen)
        self.assertIn(current.contents[0],user.client.screen)

    def test_pre_fix_disconnect_and_stale_close_reproduce_lost_ownership(self):
        old=(Path(__file__).parent/'legacy-storage-procs.dm.txt').read_text(encoding='utf8')
        def replace_proc(src,name):
            token='/obj/item/weapon/storage/proc/'+name+'(mob/user as mob)\n'
            current=token+body(src,'/obj/item/weapon/storage/proc/'+name).rstrip()+'\n'
            legacy=token+body(old,'/obj/item/weapon/storage/proc/'+name).rstrip()+'\n'
            assert src.count(current)==1
            return src.replace(current,legacy,1)
        legacy=replace_proc(replace_proc(STORAGE,'hide_from'),'close')
        install_storage(legacy)
        try:
            user=Actor();bag=FakeBag();bag.open(user)
            user.client=None;bag.close(user)
            self.assertIsNone(user.s_active);self.assertIn(user,bag.is_seeing)
            user=Actor();oldbag=FakeBag();newbag=FakeBag();oldbag.open(user);newbag.open(user)
            oldbag.close(user);self.assertIsNone(user.s_active)
        finally:
            install_storage()

    def test_offline_suite_is_registered_without_native_execution(self):
        ci=(ROOT/'scripts/ci_baseline.py').read_text(encoding='utf8')
        block=ci.split("'storage_runtime':",1)[1].split("# Stdlib-only native fixture",1)[0]
        self.assertIn("'tests/storage_runtime/test_storage_runtime.py'",block)
        self.assertIn("'tests/save_movement/source_adapter.py'",block)
        self.assertNotIn('test_native',block)

    def test_offline_selector_exempts_only_the_reviewed_test(self):
        from unittest.mock import patch
        spec = importlib.util.spec_from_file_location('storage_ci_selector', ROOT/'scripts/select-ci.py')
        selector = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(selector)
        paths = b'tests/storage_runtime/test_storage_runtime.py\0tests/storage_runtime/test_native.py\0'
        with patch.object(selector.subprocess, 'check_output', return_value=paths):
            self.assertEqual(selector.introduced_tests('a'*40, 'b'*40, 'pull_request'),
                             ['tests/storage_runtime'])
        with patch.object(selector.subprocess, 'check_output', return_value=paths.split(b'\0')[0]+b'\0'):
            self.assertEqual(selector.introduced_tests('a'*40, 'b'*40, 'pull_request'), [])
    def test_protected_sleep_closes_only_after_successful_move(self):
        install_storage()
        old_turf=SimpleNamespace(x=4,y=5,z=6)
        sleep_turf=SimpleNamespace(x=1,y=1,z=1)
        class Sleeper(Actor):
            def __init__(self,move_ok):
                super().__init__();self.loc=old_turf;self.move_ok=move_ok
                self.inducedSSD=False;self.buckled=None;self.sleeping=0
                self.lastx=8;self.lasty=9;self.lastz=10;self.updated=0
            def release_protected_sleep_buckle(self):return True
            def drop_item(self):return
            def forceMove(self,target):
                if self.move_ok:self.loc=target
            def sleep_update(self):self.updated+=1
        env={'persistence_sleep_transfer_blocked':lambda:False,
             'get_turf':lambda actor:actor.loc,'locate':lambda *coords:sleep_turf}
        enter=A.project(SLEEP,'/mob/living/human/proc/enter_protected_sleep','src',env,method=True)
        actor=Sleeper(True);bag=FakeBag();bag.open(actor)
        self.assertTrue(enter(actor));self.assertIsNone(actor.s_active)
        self.assertNotIn(actor,bag.is_seeing);self.assertEqual(actor.updated,1)
        actor=Sleeper(False);bag=FakeBag();bag.open(actor);before=set(actor.client.screen)
        self.assertFalse(enter(actor));self.assertIs(actor.s_active,bag)
        self.assertIn(actor,bag.is_seeing);self.assertEqual(actor.client.screen,before)
        self.assertEqual((actor.lastx,actor.lasty,actor.lastz,actor.sleeping,actor.inducedSSD),(8,9,10,0,False))

    def test_sleep_and_login_cleanup_are_at_success_boundaries(self):
        protected=body(SLEEP,'/mob/living/human/proc/enter_protected_sleep')
        self.assertLess(protected.index('get_turf(src) != sleep_turf'),protected.index('s_active.close(src)'))
        self.assertLess(protected.index('s_active.close(src)'),protected.index('sleep_update()'))
        self.assertEqual(protected.count('s_active.close(src)'),1)
        saved=body(BED,'/mob/living/human/proc/enter_saved_bed_sleep')
        self.assertLess(saved.index('inducedSSD = TRUE'),saved.index('s_active.close(src)'))
        self.assertLess(saved.index('s_active.close(src)'),saved.index('sleep_update()'))
        self.assertLess(LOGIN.index('s_active.close(src)'),LOGIN.index('client.screen = null'))

if __name__=='__main__':unittest.main()