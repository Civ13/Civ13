"""Project the cabinet's lid interactions with inert engine boundaries."""
from pathlib import Path
import importlib.util
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/closets.dm'
BASE_SOURCE = ROOT / 'code/game/objects/structures/crates_lockers/closets.dm'
CABINET = '/obj/structure/closet/cabinet/extinguisher_cabinet/'
BASE_CLOSET = '/obj/structure/closet/proc/'
spec = importlib.util.spec_from_file_location('cabinet_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
adapter.FIELDS += (
    'opened', 'update_icon', 'can_open', 'can_close', 'keep_items', 'dump_contents',
    'icon_opened', 'icon_closed', 'open_sound', 'close_sound', 'density',
    'has_extinguisher', 'store_misc', 'store_items', 'store_mobs',
)
DECL = CABINET + 'AltClick'


def toggle(source, near, incapacitated, human=True, opened=False):
    cabinet = SimpleNamespace(opened=opened, updates=0)
    def update_icon():
        cabinet.updates += 1
    cabinet.update_icon = update_icon
    actor = SimpleNamespace(Adjacent=lambda target: near, incapacitated=lambda: incapacitated)
    proc = adapter.project(source, DECL, 'src, user', {'ishuman': lambda user: human}, method=True)
    proc(cabinet, actor)
    return cabinet.opened, cabinet.updates


class CabinetAltClickTest(unittest.TestCase):
    def test_distant_actor_cannot_toggle(self):
        self.assertEqual(toggle(SOURCE.read_text(encoding='utf-8-sig'), False, False), (False, 0))

    def test_incapacitated_actor_cannot_toggle(self):
        self.assertEqual(toggle(SOURCE.read_text(encoding='utf-8-sig'), True, True), (False, 0))

    def test_adjacent_capable_human_can_open_and_close(self):
        source = SOURCE.read_text(encoding='utf-8-sig')
        self.assertEqual(toggle(source, True, False), (True, 1))
        self.assertEqual(toggle(source, True, False, opened=True), (False, 1))
        self.assertEqual(toggle(source, True, False, human=False), (False, 0))



class CabinetLidTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8-sig')
        self.base_source = BASE_SOURCE.read_text(encoding='utf-8-sig')
        self.sounds = []
        self.cabinet = SimpleNamespace(
            opened=False, density=False, loc=object(), keep_items=False,
            icon_state='extinguisher_closed', icon_opened='extinguisher_empty',
            icon_closed='extinguisher_closed', open_sound='open', close_sound='close',
            can_open=lambda: True, can_close=lambda: True,
            store_misc=False, store_items=False, store_mobs=False,
        )
        self.stock = SimpleNamespace(loc=self.cabinet)
        self.stock.forceMove = lambda loc: setattr(self.stock, 'loc', loc)
        self.cabinet.has_extinguisher = self.stock

        dump = adapter.project(
            self.base_source, BASE_CLOSET + 'dump_contents', 'src',
            {'typed_iter': lambda cabinet, kind: (self.stock,) if kind == '/obj' else ()},
            method=True,
        )
        self.cabinet.dump_contents = lambda: dump(self.cabinet)
        update_icon = adapter.project(self.source, CABINET + 'update_icon', 'src', {}, method=True)
        self.cabinet.update_icon = lambda: update_icon(self.cabinet)

    def lid_action(self, action):
        declaration = CABINET + action
        source = self.source
        if declaration + '(' not in source:
            declaration = BASE_CLOSET + action
            source = self.base_source
        proc = adapter.project(
            source, declaration, 'src',
            {'playsound': lambda loc, sound, *args: self.sounds.append(sound)},
            method=True,
        )
        result = proc(self.cabinet)
        if result:
            self.cabinet.update_icon()  # The inherited Toggle Open dispatcher refreshes the icon.
        return result

    def test_open_full_cabinet_keeps_stock_inside(self):
        self.assertTrue(self.lid_action('open'))
        self.assertTrue(self.cabinet.opened)
        self.assertEqual(self.cabinet.icon_state, 'extinguisher_full')
        self.assertIs(self.stock.loc, self.cabinet)
        self.assertFalse(self.cabinet.density)
        self.assertEqual(self.sounds, ['open'])

    def test_close_preserves_passability_and_does_not_store_floor_item(self):
        self.cabinet.opened = True
        floor_stores = []
        self.cabinet.store_items = lambda stored_units: floor_stores.append(stored_units) or 1
        self.assertTrue(self.lid_action('close'))
        self.assertFalse(self.cabinet.opened)
        self.assertEqual(self.cabinet.icon_state, 'extinguisher_closed')
        self.assertFalse(self.cabinet.density)
        self.assertEqual(floor_stores, [])
        self.assertEqual(self.sounds, ['close'])

    def test_lid_still_checks_open_and_close_guards(self):
        self.cabinet.can_open = lambda: False
        self.assertFalse(self.lid_action('open'))
        self.assertFalse(self.cabinet.opened)

        self.cabinet.opened = True
        self.cabinet.can_close = lambda: False
        self.assertFalse(self.lid_action('close'))
        self.assertTrue(self.cabinet.opened)
        self.assertEqual(self.sounds, [])


if __name__ == '__main__':
    unittest.main()
