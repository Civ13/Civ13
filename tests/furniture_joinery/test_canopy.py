"""Production canopy admission/completion with inert waits, roofs and actors.

Native fixtures separately exercise real roof/area constructors and icon states.
"""
import json
from pathlib import Path
import re
import sys
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/primitive_woodworking'))
from source_adapter import block, compile_body
SOURCE = (ROOT / 'code/game/objects/items/weapons/nomadstuff.dm').read_text()
ITEM = '/obj/item/weapon/tent'
TENT = '/obj/structure/tent'
ROOF = '/obj/roof/canopy'


def project(signature, args, env, fields=()):
    body = block(SOURCE, signature)
    # Typed iteration/constructors are explicit adapters, keeping production
    # predicates, completion order and all branches unchanged.
    body = re.sub(r'for \(var(/\w+(?:/\w+)*)/(\w+) in (.+)\)',
                  lambda m: 'for ' + m[2] + ' in typed(' + m[3] + ', ' + json.dumps(m[1]) + '):', body)
    body = re.sub(r'new (/[\w/]+)\(([^\n]*)\)',
                  lambda m: 'construct(' + json.dumps(m[1]) + ', ' + m[2] + ')', body)
    return compile_body(body, signature, args, env, fields)[0]


class World:
    def __init__(self):
        self.site = NS(type='/turf', x=2, y=2, z=1, area=NS(location=1), contents=[])
        self.neighbor = NS(type='/turf', x=3, y=2, z=1, area=NS(location=1), contents=[])
        self.actor = self.human()
        self.epoch = object()
        self.objects = []
        self.wait = lambda: True
        self.env = dict(QDELETED=lambda obj: obj is None or getattr(obj, 'deleted', False),
                        isturf=lambda obj: getattr(obj, 'type', '') == '/turf',
                        istype=lambda obj, path: getattr(obj, 'type', '').startswith(path),
                        persistence_save_in_progress=False, persistence_active_operation=None,
                        persistence_load_recovery_required=False,
                        persistence_admission_identity=self.epoch,
                        get_area=lambda obj: obj.area,
                        get_turf=self.turf, get_dist=lambda a, b: max(abs(self.turf(a).x-b.x), abs(self.turf(a).y-b.y)),
                        typed=lambda site, path: [obj for obj in (site.contents if hasattr(site, 'contents') else site)
                                                  if obj.type.startswith(path)],
                        range=lambda radius, site: list(self.site.contents) + list(self.neighbor.contents),
                        construct=self.new, qdel=self.delete, to_chat=lambda *args: None,
                        do_after=lambda *args: self.wait(), AREA_OUTSIDE=1)
        self.ready = project('/proc/canopy_actor_ready(', 'user,site,save_epoch', self.env)
        self.env['canopy_actor_ready'] = self.ready

    def human(self):
        actor = NS(type='/mob/living/human', loc=self.site, z=1, disabled=False, contents=[], deleted=False)
        actor.incapacitated = lambda: actor.disabled
        return actor

    def turf(self, obj):
        while obj and getattr(obj, 'type', '') != '/turf':
            obj = obj.loc
        return obj

    def delete(self, obj):
        obj.deleted = True
        if obj.loc is not None and hasattr(obj.loc, 'contents') and obj in obj.loc.contents:
            obj.loc.contents.remove(obj)
        obj.loc = None

    def new(self, kind, loc=None):
        obj = NS(type=kind, loc=loc, deleted=False, oldarea=True,
                 visible_message=lambda *args: None, update_icon=lambda: None)
        self.objects.append(obj)
        if loc is not None and hasattr(loc, 'contents'):
            loc.contents.append(obj)
        fields = ('loc', 'oldarea', 'unfold_allowed', 'fold_allowed', 'visible_message')
        if kind == ITEM:
            allowed = project(ITEM + '/proc/unfold_allowed(', 'self,user,site,source_loc,save_epoch', self.env, fields)
            obj.unfold_allowed = lambda *args: allowed(obj, *args)
            action = project(ITEM + '/attack_self(', 'self,user', self.env, fields)
            obj.unfold = lambda user: action(obj, user)
        if kind == TENT:
            allowed = project(TENT + '/proc/fold_allowed(', 'self,user,site,save_epoch', self.env, fields)
            obj.fold_allowed = lambda *args: allowed(obj, *args)
            action = project(TENT + '/proc/fold_up(', 'self,user', self.env, fields)
            obj.fold_up = lambda user: action(obj, user)
        return obj

    def count(self, kind):
        return sum(obj.type == kind and not obj.deleted for obj in self.objects)


class Canopy(unittest.TestCase):
    def test_existing_two_paid_routes_and_research_are_preserved(self):
        old = json.loads((Path(__file__).parent / 'legacy-furniture.json').read_text())
        rows = [r for r in old if ',' + ITEM + ',' in r['row']]
        self.assertTrue(rows)
        for row in rows:
            self.assertIn(row['row'], (ROOT / row['file']).read_text().splitlines())
        global_rows = (ROOT / 'config/crafting/material_recipes_global.txt').read_text()
        for row in ('/material/leather/,foldable canopy,' + ITEM + ',5,75,0,1,furniture,0,0,0,8,null',
                    '/material/cloth/,foldable canopy,' + ITEM + ',4,75,0,1,furniture,0,0,19,8,null'):
            self.assertIn('RECIPE: ' + row, global_rows)
        self.assertIn('"' + ITEM + '" = "weaving"',
                      (ROOT / 'code/modules/research_tree/research_node.dm').read_text())

    def test_destination_tile_is_checked_instead_of_actor_inventory(self):
        for blocker in (TENT, ROOF, '/obj/roof/wood'):
            w = World(); item = w.new(ITEM, w.actor); w.new(blocker, w.site)
            self.assertFalse(item.unfold_allowed(w.actor, w.site, w.actor, w.epoch))
            item.unfold(w.actor)
            self.assertFalse(item.deleted)
            self.assertEqual(w.count(TENT), int(blocker == TENT))
        w = World(); item = w.new(ITEM, w.actor)
        item.unfold(w.actor)
        self.assertTrue(item.deleted); self.assertEqual(w.count(TENT), 1)

    def test_late_occupancy_move_container_and_epoch_refuse_output(self):
        for change in ('canopy', 'roof', 'inside', 'moved', 'nested', 'epoch', 'save', 'cancelled'):
            with self.subTest(change=change):
                w = World(); item = w.new(ITEM, w.actor)
                def wait():
                    if change == 'canopy': w.new(TENT, w.site)
                    if change == 'roof': w.new('/obj/roof/wood', w.site)
                    if change == 'inside': w.site.area.location = 0
                    if change == 'moved': w.actor.loc = w.neighbor
                    if change == 'nested': item.loc = NS(type='/obj/container', loc=w.actor)
                    if change == 'epoch': w.ready.__globals__['persistence_admission_identity'] = object()
                    if change == 'save': w.ready.__globals__['persistence_save_in_progress'] = True
                    return change != 'cancelled'
                w.wait = wait; item.unfold(w.actor)
                self.assertFalse(item.deleted)
                self.assertEqual(w.count(TENT), int(change == 'canopy'))

    def test_container_actor_and_nested_stock_refuse_before_wait(self):
        for nesting in ('actor', 'item'):
            w = World(); item = w.new(ITEM, w.actor)
            if nesting == 'actor': w.actor.loc = NS(type='/obj/container', loc=w.site)
            else: item.loc = NS(type='/obj/container', loc=w.actor)
            w.wait = lambda: self.fail('Invalid placement reached timed action')
            item.unfold(w.actor)
            self.assertFalse(item.deleted); self.assertEqual(w.count(TENT), 0)

    def test_fold_preserves_other_roofs_and_late_roof_refuses_without_refund(self):
        for late in (False, True):
            w = World(); tent = w.new(TENT, w.site); cover = w.new(ROOF, w.site)
            permanent = None
            def wait():
                nonlocal permanent
                permanent = w.new('/obj/roof/wood', w.site)
                return True
            if late: w.wait = wait
            else: permanent = w.new('/obj/roof/wood', w.site)
            self.assertIsNone(tent.fold_up(w.actor))
            self.assertFalse(tent.deleted); self.assertFalse(cover.deleted)
            self.assertFalse(permanent.deleted); self.assertEqual(w.count(ITEM), 0)

    def test_shared_cover_survives_until_last_legacy_canopy_folds(self):
        w = World(); first = w.new(TENT, w.site); other = w.new(TENT, w.site); roof = w.new(ROOF, w.site)
        self.assertIsNotNone(first.fold_up(w.actor)); self.assertFalse(roof.deleted)
        self.assertIsNotNone(other.fold_up(w.actor)); self.assertTrue(roof.deleted)
        self.assertEqual((w.count(ITEM), w.count(TENT)), (2, 0))

    def test_fold_revalidates_cancelled_or_stale_actions_and_one_instance(self):
        for change in ('cancelled', 'moved', 'epoch', 'disabled', 'competing fold'):
            w = World(); tent = w.new(TENT, w.site); w.new(ROOF, w.site)
            def wait():
                if change == 'moved': w.actor.loc = NS(type='/turf', x=9, y=9, z=1)
                if change == 'epoch': w.ready.__globals__['persistence_admission_identity'] = object()
                if change == 'disabled': w.actor.disabled = True
                if change == 'competing fold':
                    w.wait = lambda: True
                    tent.fold_up(w.actor)
                return change != 'cancelled'
            w.wait = wait
            self.assertIsNone(tent.fold_up(w.actor))
            self.assertEqual(w.count(ITEM), int(change == 'competing fold'))
            self.assertEqual(tent.deleted, change == 'competing fold')


if __name__ == '__main__':
    unittest.main()
