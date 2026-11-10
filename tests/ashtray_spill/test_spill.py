"""Exercise the complete production throw proc through an offline DM adapter.

The fake locations model item membership and updates. This is not a BYOND
runtime, actual throwing, inventory interaction, or visual confirmation.
"""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/weapons/material/ashtray.dm'
DECL = '/obj/item/weapon/material/ashtray/throw_impact'
spec = importlib.util.spec_from_file_location('dm_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class DMList(list):
    @property
    def len(self):
        return len(self)


class Item:
    def __init__(self, kind, location):
        self.kind = kind
        self._loc = None
        self.loc = location

    @property
    def loc(self):
        return self._loc

    @loc.setter
    def loc(self, value):
        if hasattr(self._loc, 'contents'):
            self._loc.contents.remove(self)
        self._loc = value
        if hasattr(value, 'contents'):
            value.contents.append(self)


class Ashtray:
    def __init__(self, health=10):
        self.loc = object()
        self.health = health
        self.contents = DMList()
        self.messages = []
        self.updated = 0
        self.shattered = 0
        self.parent_calls = 0

    def impact(self, source=None):
        # Add only the fake engine qualification needed by the shared adapter;
        # reject unexpected drift rather than omit executable source.
        if source is None:
            source = SOURCE.read_text(encoding='utf-8')
        body = adapter.extract(source, DECL)
        body = body.replace('health', 'src.health').replace('return ..()', 'return parent()')
        code = DECL + '(atom/hit_atom)\n' + body + '\n'

        def typed_iter(items, typepath):
            accepted = {'/obj/item': {'butt', 'match', 'cigarette'},
                        '/obj/item/clothing/mask/smokable/cigarette': {'cigarette'}}
            if typepath not in accepted:
                raise AssertionError('Unknown type in throw proc: ' + typepath)
            return [item for item in list(items) if item.kind in accepted[typepath]]

        def parent():
            self.parent_calls += 1

        def shatter():
            self.shattered += 1

        def update_icon():
            self.updated += 1

        env = dict(typed_iter=typed_iter, parent=parent, shatter=shatter,
                   update_icon=update_icon, visible_message=self.messages.append)
        proc = adapter.project(code, DECL, 'src,hit_atom', env, method=True)
        return proc(self, object())


class AshtraySpillTests(unittest.TestCase):
    def test_cigarette_only_loop_negative_control(self):
        source = SOURCE.read_text(encoding='utf-8')
        fixed = 'for (var/obj/item/O in contents)'
        original = 'for (var/obj/item/clothing/mask/smokable/cigarette/O in contents)'
        self.assertEqual(source.count(fixed), 1, 'expected production loop changed')
        source = source.replace(fixed, original, 1)
        tray = Ashtray()
        cigarette = Item('cigarette', tray)
        butt = Item('butt', tray)
        match = Item('match', tray)
        tray.impact(source)
        self.assertIs(cigarette.loc, tray.loc)
        self.assertIs(butt.loc, tray)
        self.assertIs(match.loc, tray)

    def test_each_accepted_item_spills_after_nonfatal_impact(self):
        for kind in ('cigarette', 'butt', 'match'):
            with self.subTest(kind=kind):
                tray = Ashtray()
                item = Item(kind, tray)
                tray.impact()
                self.assertIs(item.loc, tray.loc)
                self.assertEqual(tray.contents, [])
                self.assertEqual((tray.health, tray.updated, tray.shattered, tray.parent_calls), (7, 1, 0, 1))

    def test_mixed_items_all_spill_before_shattering(self):
        tray = Ashtray(3)
        items = [Item(kind, tray) for kind in ('cigarette', 'butt', 'match')]
        tray.impact()
        self.assertTrue(all(item.loc is tray.loc for item in items))
        self.assertEqual(tray.contents, [])
        self.assertEqual((tray.updated, tray.shattered, tray.parent_calls), (0, 1, 0))

    def test_destroyed_tray_preserves_parent_dispatch(self):
        tray = Ashtray(0)
        item = Item('match', tray)
        tray.impact()
        self.assertIs(item.loc, tray)
        self.assertEqual((tray.updated, tray.shattered, tray.parent_calls), (0, 0, 1))


if __name__ == '__main__':
    unittest.main()
