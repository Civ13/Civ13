"""Actual tack source projected with fake inventory/movement/menu boundaries.

No BYOND, savefile, gameplay client or performance claim. Unknown source fails
projection; complete selected procs execute, including fresh callback checks.
"""
import importlib.util
import json
from pathlib import Path
import re
import struct
from types import SimpleNamespace as N
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
PATH = 'code/game/objects/items/weapons/animal_tack.dm'
SOURCE = (ROOT/PATH).read_text()
ANIMAL = '/mob/living/simple_animal'
ITEM = '/obj/item/animal_tack'
spec = importlib.util.spec_from_file_location('tack_source_adapter', ROOT/'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
TYPES = {ITEM+'/saddle': 'SADDLE', ITEM+'/harness': 'HARNESS', ANIMAL+'/horse': 'HORSE', ANIMAL+'/cattle': 'CATTLE'}


class DMList(list):
    @property
    def len(self): return len(self)
    def __iadd__(self, item):
        self.append(item);return self


class Item:
    def __init__(self, world, kind, loc=None):
        self.world=world;self.kind=kind;self.loc=None;self.deleted=False;self.nodrop=False;self.move_hook=None
        self.forceMove(loc)
    def forceMove(self, target):
        if hasattr(self.loc, 'contents') and self in self.loc.contents:self.loc.contents.remove(self)
        self.loc=target
        if hasattr(target, 'contents'):target.contents.append(self)
        if self.move_hook:self.move_hook(self,target)
        self.world.refresh()
    def fits_animal(self, animal):
        return self.world.call(ITEM+'/'+self.kind+'/fits_animal','animal',animal)


class Animal:
    def __init__(self, world, species='horse'):
        self.world=world;self.species=species;self.contents=DMList();self.deleted=False
        self.stat=0;self.ride=False;self.rider=None;self.buckled=None;self.loc=world.site
        self.messages=[]
    def get_animal_tack(self, kind, ignore=None):return self.world.call(ANIMAL+'/proc/get_animal_tack','src,tack_type,ignore',self,kind,ignore)
    def can_handle_animal_tack(self,user):return self.world.call(ANIMAL+'/proc/can_handle_animal_tack','src,user',self,user)
    def remove_animal_tack(self,tack,user):return self.world.call(ANIMAL+'/proc/remove_animal_tack','src,T,user',self,tack,user)
    def animal_draft_hunger_cost(self):return self.world.call(ANIMAL+'/proc/animal_draft_hunger_cost','src',self)
    def visible_message(self,text):self.messages.append(text)


class User:
    def __init__(self, world):
        self.world=world;self.deleted=False;self.disabled=False;self.near=True;self.contents=DMList();self.hand=None;self.drop_hook=None;self.client=N(mob=self)
    def incapacitated(self):return self.disabled
    def Adjacent(self, animal):return self.near and not animal.deleted
    def get_active_hand(self):return self.hand
    def drop_from_inventory(self,item,site):
        if item.nodrop or self.hand is not item:return False
        self.hand=None;item.forceMove(site)
        if self.drop_hook:self.drop_hook()
        self.world.refresh()
        return True


class World:
    def __init__(self,source=SOURCE):
        self.source=source;self.site=N(contents=DMList());self.actor=User(self);self.animal=Animal(self)
        self.messages=[];self.menu_hook=None;self.choice=None;self.frames=[]
        self.state=dict(persistence_save_in_progress=False,persistence_active_operation=None,persistence_load_recovery_required=False,persistence_admission_identity=object())
    def refresh(self):
        for env in self.frames:env.update(self.state)
    def istype(self,obj,kind):
        if kind==ITEM:return isinstance(obj,Item)
        if kind in ('saddle','harness'):return isinstance(obj,Item) and obj.kind==kind
        if kind in ('horse','cattle'):return isinstance(obj,Animal) and obj.species==kind
        raise AssertionError('Unsupported fake type '+str(kind))
    def call(self,decl,args,*values):
        source=self.source
        # Only literal type expressions are renamed; the actual proc body stays
        # intact. The audited adapter handles conditionals and typed iteration.
        body=adapter.extract(source,decl)
        # Compile-time verb exposure metadata is outside the fake runtime.
        # The actual fresh Adjacent guard still executes below.
        body=body.replace('\tset src in oview(1)', '\t// native verb exposure metadata')
        for path,name in TYPES.items():body=body.replace(path,name)
        code=decl+'()\n'+body+'\n'
        def menu(*args):
            if self.menu_hook:self.menu_hook()
            return self.choice
        env=dict(self.state,src=self.animal,usr=self.actor,QDELETED=lambda x:x is None or getattr(x,'deleted',False),
            istype=self.istype,ishuman=lambda x:isinstance(x,User),get_turf=lambda x:None if x.deleted else x.loc,
            to_chat=lambda *x:self.messages.append(x),WWinput=menu,list=DMList,DEAD=2,
            typed_iter=lambda xs,t:[x for x in list(xs) if isinstance(x,Item)],
            SADDLE='saddle',HARNESS='harness',HORSE='horse',CATTLE='cattle')
        proc=adapter.project(code,decl,args,env)
        # Share save epoch changes injected by a menu callback through this
        # invocation's globals, as a real resumed proc observes current globals.
        original=menu
        def resumed(*args):
            result=original(*args);env.update(self.state);return result
        env['WWinput']=resumed
        self.frames.append(env)
        try:return proc(*values)
        finally:self.frames.remove(env)
    def held(self,kind='saddle'):
        item=Item(self,kind,self.actor);self.actor.hand=item;return item
    def fit(self,item):return self.call(ANIMAL+'/proc/fit_animal_tack','src,T,user',self.animal,item,self.actor)
    def mount_delay(self):return self.call(ANIMAL+'/proc/animal_mount_delay','src',self.animal)
    def cost(self):return self.call(ANIMAL+'/proc/animal_draft_hunger_cost','src',self.animal)
    def menu(self):return self.call(ANIMAL+'/verb/unfit_animal_tack','src',self.animal)


class TackTests(unittest.TestCase):
    def test_optional_effects_and_species(self):
        for species in ('horse','cattle','camel'):
            with self.subTest(species=species):
                w=World();w.animal.species=species
                self.assertEqual((w.mount_delay(),w.cost()),(40,1))
                Item(w,'saddle',w.animal);Item(w,'harness',w.animal)
                self.assertEqual(w.mount_delay(),20 if species=='horse' else 40)
                self.assertEqual(w.cost(),0.5 if species in ('horse','cattle') else 1)
                w.animal.stat=2;self.assertEqual(w.mount_delay(),40)

    def test_fit_remove_and_independent_slots_without_owner_pointers(self):
        w=World();s=w.held();self.assertTrue(w.fit(s));h=w.held('harness');self.assertTrue(w.fit(h))
        self.assertIs(s.loc,w.animal);self.assertIs(h.loc,w.animal)
        self.assertEqual((w.mount_delay(),w.cost()),(20,0.5))
        self.assertTrue(w.animal.remove_animal_tack(s,w.actor))
        self.assertIs(s.loc,w.site);self.assertEqual((w.mount_delay(),w.cost()),(40,0.5))
        self.assertNotIn('owner',s.__dict__)

    def test_preconditions_do_not_drop_or_duplicate_items(self):
        def busy(w):w.state['persistence_active_operation']=object()
        changes=[lambda w:setattr(w.actor,'near',False),lambda w:setattr(w.actor,'disabled',True),
            lambda w:setattr(w.animal,'stat',2),lambda w:setattr(w.animal,'ride',True),
            lambda w:setattr(w.animal,'rider',object()),lambda w:setattr(w.animal,'buckled',True),busy,
            lambda w:setattr(w.animal,'species','cattle'),lambda w:setattr(w.actor,'hand',None)]
        for change in changes:
            w=World();s=w.held();change(w);self.assertFalse(w.fit(s));self.assertIs(s.loc,w.actor)
        w=World();s=w.held();s.nodrop=True;self.assertFalse(w.fit(s));self.assertIs(s.loc,w.actor)
        w=World();s=w.held();s.forceMove(w.site);self.assertFalse(w.fit(s));self.assertIs(s.loc,w.site)
        w=World();old=Item(w,'saddle',w.animal);s=w.held();self.assertFalse(w.fit(s));self.assertIs(s.loc,w.actor);self.assertIs(old.loc,w.animal)

    def test_inventory_callbacks_revalidate_exact_item_actor_target_and_epoch(self):
        for mutation in ('item','actor','hitch','death','slot','epoch','target_deleted','actor_deleted','item_deleted'):
            with self.subTest(mutation=mutation):
                w=World();s=w.held();foreign=N(contents=DMList())
                def hook():
                    if mutation=='item':s.forceMove(foreign)
                    elif mutation=='actor':w.actor.near=False
                    elif mutation=='hitch':w.animal.buckled=True
                    elif mutation=='death':w.animal.stat=2
                    elif mutation=='slot':Item(w,'saddle',w.animal)
                    elif mutation=='target_deleted':w.animal.deleted=True
                    elif mutation=='actor_deleted':w.actor.deleted=True
                    elif mutation=='item_deleted':s.deleted=True
                    else:w.state['persistence_admission_identity']=object()
                w.actor.drop_hook=hook
                self.assertFalse(w.fit(s));self.assertIsNot(s.loc,w.animal)
                if mutation=='item':self.assertIs(s.loc,foreign)

    def test_move_callback_rolls_back_only_owned_item(self):
        w=World();s=w.held()
        def hook(item,target):
            if target is w.animal:w.animal.buckled=True
        s.move_hook=hook;self.assertFalse(w.fit(s));self.assertIs(s.loc,w.site)
        w=World();s=w.held();foreign=N(contents=DMList())
        def transfer(item,target):
            if target is w.animal:
                item.move_hook=None;item.forceMove(foreign)
        s.move_hook=transfer;self.assertFalse(w.fit(s));self.assertIs(s.loc,foreign)

    def test_stale_deleted_nested_and_foreign_items_do_not_grant_effect(self):
        w=World();s=Item(w,'saddle',w.site);w.animal.contents.append(s)
        self.assertEqual(w.mount_delay(),40)
        s.loc=w.animal;s.deleted=True;self.assertEqual(w.mount_delay(),40)
        s.deleted=False;s.forceMove(w.site);self.assertEqual(w.mount_delay(),40)
        bag=N(contents=DMList());s.forceMove(bag);self.assertEqual(w.mount_delay(),40)

    def test_removal_menu_revalidates_after_yield_and_corpse_salvage(self):
        for mutation in ('none','item','actor','hitch','epoch','cancel','logout','handoff'):
            with self.subTest(mutation=mutation):
                w=World();s=Item(w,'saddle',w.animal);w.choice=s
                def hook():
                    if mutation=='item':s.forceMove(w.site)
                    elif mutation=='actor':w.actor.near=False
                    elif mutation=='hitch':w.animal.buckled=True
                    elif mutation=='epoch':w.state['persistence_admission_identity']=object()
                    elif mutation=='logout':w.actor.client=None
                    elif mutation=='handoff':w.actor.client.mob=object()
                    elif mutation=='cancel':w.choice=None
                # Cancellation uses the result boundary directly.
                if mutation=='cancel':w.choice=None
                w.menu_hook=hook;w.menu()
                expected=w.site if mutation in ('none','item') else w.animal
                self.assertIs(s.loc,expected)
        w=World();s=Item(w,'saddle',w.animal);w.animal.stat=2
        self.assertTrue(w.animal.remove_animal_tack(s,w.actor))

    def test_causal_missing_callback_guard_allows_invalid_fit(self):
        guard='!src.can_handle_animal_tack(user) || src.stat == DEAD || QDELETED(T) || T.loc != site || get_turf(src) != site || !T.fits_animal(src) || src.get_animal_tack(tack_type) || tack_epoch != persistence_admission_identity'
        self.assertEqual(SOURCE.count(guard),1)
        # A missing pre-move guard can transfer an item stolen by a callback.
        mutant=SOURCE.replace('if ('+guard+')','if (FALSE)')
        w=World(mutant);s=w.held();foreign=N(contents=DMList())
        w.actor.drop_hook=lambda:s.forceMove(foreign)
        self.assertTrue(w.fit(s));self.assertIs(s.loc,w.animal)

    def test_real_recipe_research_riding_and_all_four_draft_slots_wired(self):
        rows=(ROOT/'config/crafting/material_recipes_global.txt').read_text().splitlines()
        for kind,cost in [('saddle',6),('harness',4)]:
            entries=[x.split(',') for x in rows if x.startswith('RECIPE: /material/leather/,') and x.split(',')[2]==ITEM+'/'+kind]
            self.assertEqual(len(entries),1);self.assertEqual(int(entries[0][3]),cost)
            self.assertIn('"'+ITEM+'/'+kind+'" = "basic_agriculture"',(ROOT/'code/modules/research_tree/research_node.dm').read_text())
        riding=(ROOT/'code/game/mob/living/simple_animal/riding.dm').read_text()
        self.assertIn('do_after(MM, src.animal_mount_delay(), src)',riding)
        self.assertEqual(riding.count('do_after(M, src.animal_mount_delay(), src)'),1)
        self.assertIn('do_after(M, 40, src)',riding) # forced removal stays unchanged
        transport=(ROOT/'code/game/objects/structures/transports.dm').read_text()
        for n in range(1,5):self.assertEqual(transport.count(f'pulling{n}.simplehunger -= pulling{n}.animal_draft_hunger_cost()'),1)
        attack=(ROOT/'code/game/mob/living/simple_animal/simple_animal.dm').read_text()
        self.assertIn('return src.fit_animal_tack(O, user)',attack)
        self.assertIn('animal_tack.dm',(ROOT/'civ13.dme').read_text())

    def test_actual_four_slot_debits_follow_current_owned_harness(self):
        source=(ROOT/'code/game/objects/structures/transports.dm').read_text()
        lines=re.findall(r'(?m)^\s*(pulling[1-4]\.simplehunger -= [^\n]+)',source)
        self.assertEqual(len(lines),4)
        code='/draft_step()\n'+''.join('\t'+line.split('//',1)[0].strip()+'\n' for line in lines)
        step=adapter.project(code,'/draft_step','pulling1,pulling2,pulling3,pulling4',{})
        worlds=[World() for _ in range(4)]
        for w in worlds:w.animal.simplehunger=100
        harnesses=[Item(w,'harness',w.animal) for w in worlds]
        step(*(w.animal for w in worlds))
        self.assertEqual([w.animal.simplehunger for w in worlds],[99.5]*4)
        for w,t in zip(worlds,harnesses):t.forceMove(w.site)
        step(*(w.animal for w in worlds))
        self.assertEqual([w.animal.simplehunger for w in worlds],[98.5]*4)

    def test_containment_persistence_contract_no_new_links_or_cached_effects(self):
        functions=(ROOT/'code/modules/persistence/functions.dm').read_text()
        self.assertIn('atom\n\tmap_storage_saved_vars',functions)
        self.assertIn('\tload_contents = 1',functions)
        saving=(ROOT/'code/modules/persistence/saving.dm').read_text()
        self.assertIn('for(var/obj/content in parent.contents)',saving)
        self.assertIn('if(content.loc != parent) continue',saving)
        # No atom pointers/slot cache in the new types. Native savefile roundtrip
        # remains untested; containment is the existing serializer ownership edge.
        type_bodies=re.findall(r'(?m)^/[^\n(]+\n((?:\t[^\n]*\n|\n)*)',SOURCE)
        for body in type_bodies:self.assertNotRegex(body,r'(?m)^\tvar/(?:mob|obj|datum)/')

    def test_offline_ci_registration_keeps_existing_shared_coverage(self):
        spec=importlib.util.spec_from_file_location('tack_ci_registration',ROOT/'scripts/ci_baseline.py')
        ci=importlib.util.module_from_spec(spec);spec.loader.exec_module(ci)
        self.assertEqual(ci.SUITES['animal_tack']['files'],('tests/animal_tack/test_tack.py',))
        def selected(path):return {k for k,v in ci.impact([path])['suites'].items() if v['selected']}
        self.assertEqual(selected(PATH),{'policy','bootstrap','progress','animal_tack'})
        current=ci.SUITES
        for path in current['animal_tack']['shared_paths']:
            actual=selected(path)
            try:
                ci.SUITES={k:v for k,v in current.items() if k!='animal_tack'}
                previous=selected(path)
            finally:ci.SUITES=current
            self.assertEqual(actual,previous|{'animal_tack'})

    def test_reused_icon_states_exist(self):
        for filename,state in [('icons/obj/clothing/belts.dmi','belt_satchel'),('icons/obj/items.dmi','leash')]:
            data=(ROOT/filename).read_bytes();at=8;text=[]
            while at<len(data):
                size=struct.unpack('>I',data[at:at+4])[0];kind=data[at+4:at+8];payload=data[at+8:at+8+size];at+=12+size
                if kind==b'zTXt':text.append(zlib.decompress(payload.split(b'\x00',1)[1][1:]).decode())
                elif kind==b'tEXt':text.append(payload.decode())
            self.assertIn('state = "'+state+'"','\n'.join(text))


if __name__=='__main__':unittest.main()
