"""Offline checks for the gun sprite-state fallback; stdlib only, no BYOND.

run.py is the runtime sweep. These tests keep its reviewed gap list honest
against the checked-in DMI files and pin the render paths that apply the
fallback, so an unloaded gun asking for "<name>_open" draws "<name>" instead
of BYOND's error icon.
"""
import importlib.util
import re
import struct
import unittest
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SUFFIXES = ('_empty', '-empty', '_open')
SLOTS = {'icon', 'slot_l_hand', 'slot_r_hand', 'worn'}


def dmi_states(path, cache={}):
    if path not in cache:
        data = path.read_bytes()
        states = set()
        offset = 8
        while offset + 8 <= len(data):
            length, kind = struct.unpack('>I4s', data[offset:offset + 8])
            chunk = data[offset + 8:offset + 8 + length]
            offset += 12 + length
            if kind == b'zTXt':
                text = zlib.decompress(chunk[chunk.index(0) + 2:]).decode('utf-8')
                states = {' '.join(s.split()) for s in re.findall(r'^state = "(.*)"$', text, re.M)}
                break
        cache[path] = states
    return cache[path]


def known_entries():
    entries = []
    for line in (HERE / 'known_missing.txt').read_text(encoding='utf-8').splitlines():
        line = line.split('#', 1)[0].strip()
        if line:
            parts = line.split()
            entries.append((parts[0], parts[1], ' '.join(parts[2:-1]), parts[-1]))
    return entries


def trimmed(state):
    """The states sprite_state_for tries after state itself, in order."""
    found = True
    while found:
        found = False
        for suffix in SUFFIXES:
            if len(state) > len(suffix) and state.endswith(suffix):
                state = state[:-len(suffix)]
                yield state
                found = True
                break


class KnownMissingTest(unittest.TestCase):
    def test_entries_are_well_formed_and_unique(self):
        entries = known_entries()
        self.assertTrue(entries)
        self.assertEqual(len(entries), len(set(entries)))
        for path, slot, state, icon in entries:
            self.assertTrue(path.startswith('/obj/item/weapon/gun'), path)
            self.assertIn(slot, SLOTS, path)
            self.assertTrue(state, path)
            self.assertTrue(icon.endswith('.dmi') and (ROOT / icon).is_file(), icon)

    def test_listed_states_are_still_missing(self):
        # A listed sprite that now exists makes the entry stale; so does a
        # trimmed base the fallback would now find.
        for path, slot, state, icon in known_entries():
            states = dmi_states(ROOT / icon)
            self.assertNotIn(state, states, f'{path} {slot}: {icon} has {state}; remove the line')
            for base in trimmed(state):
                self.assertNotIn(base, states, f'{path} {slot}: fallback finds {base} in {icon}; remove the line')


class FallbackSourceTest(unittest.TestCase):
    def test_helper_trims_the_same_suffixes(self):
        source = (ROOT / 'code/_helpers/sprite_states.dm').read_text(encoding='utf-8')
        listed = re.search(r'var/static/list/suffixes = list\(([^)]*)\)', source)
        self.assertIsNotNone(listed)
        self.assertEqual(tuple(re.findall(r'"([^"]+)"', listed.group(1))), SUFFIXES)
        self.assertIn('#include "code\\_helpers\\sprite_states.dm"',
                      (ROOT / 'civ13.dme').read_text(encoding='utf-8'))

    def test_negative_control_target_exists_once(self):
        spec = importlib.util.spec_from_file_location('gun_icon_states_run', HERE / 'run.py')
        run = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(run)
        path, old, _ = run.CONTROL
        self.assertEqual((ROOT / path).read_text(encoding='utf-8').count(old), 1)

    def test_worn_and_held_overlays_apply_the_fallback(self):
        source = (ROOT / 'code/game/mob/living/carbon/human/update_icons.dm').read_text(encoding='utf-8')
        for call in ('overlay_state = back.sprite_state_for(overlay_icon, overlay_state)',
                     'overlay_state_shoulder = shoulder.sprite_state_for(overlay_icon_shoulder, overlay_state_shoulder)',
                     't_state = r_hand.sprite_state_for(t_icon, t_state)',
                     't_state = l_hand.sprite_state_for(t_icon, t_state)'):
            self.assertEqual(source.count(call), 1, call)
        self.assertNotIn('overlay_state_shoulder = back.item_state_slots', source)

    def test_guns_fall_back_to_their_base_icon(self):
        projectile = (ROOT / 'code/modules/projectiles/guns/projectile.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/item/weapon/gun/projectile/fallback_sprite_states()\n\treturn list(base_icon) + ..()', projectile)
        gun = (ROOT / 'code/modules/projectiles/gun.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/item/weapon/gun/update_held_icon()\n\tsettle_icon_state()', gun)


if __name__ == '__main__':
    unittest.main()
