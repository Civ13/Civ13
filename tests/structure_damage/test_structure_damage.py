"""Structures share one health/break path.

/obj/structure owns `health` and `maxhealth`, and code/_helpers/structure_damage.dm
owns try_destroy(): a type says how it breaks with break_message() and
on_break() instead of copying the health check, message and qdel. Weapon blows
go through weapon_structure_damage(). These checks keep new copies from coming
back.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / 'code/_helpers/structure_damage.dm'
DECLARED = re.compile(r'^/obj/structure/[\w/]+/proc/try_destroy\(', re.M)


def dm_files():
    return sorted((ROOT / 'code').rglob('*.dm'))


class StructureDamageTest(unittest.TestCase):
    def test_helper_is_compiled(self):
        self.assertIn('#include "code\\_helpers\\structure_damage.dm"',
                      (ROOT / 'civ13.dme').read_text(encoding='utf-8'))

    def test_try_destroy_ignores_structures_without_health(self):
        text = HELPER.read_text(encoding='utf-8')
        self.assertIn('/obj/structure\n\tvar/health = null\n\tvar/maxhealth = null\n', text)
        self.assertIn('/obj/structure/proc/try_destroy()\n'
                      '\tif (isnull(health) || health > 0)\n\t\treturn FALSE\n'
                      '\tvar/message = break_message()\n\tif (message)\n'
                      '\t\tvisible_message(SPAN_DANGER(message))\n'
                      '\ton_break()\n\tqdel(src)\n\treturn TRUE\n', text)

    def test_weapon_damage_uses_damage_type_multipliers(self):
        text = HELPER.read_text(encoding='utf-8')
        self.assertIn('\t\tif ("fire")\n\t\t\tamount = W.force * fire_mult\n'
                      '\t\tif ("brute")\n\t\t\tamount = W.force * brute_mult\n', text)
        self.assertIn('\treturn take_structure_damage(amount)\n', text)

    def test_no_structure_declares_its_own_try_destroy(self):
        found = []
        for path in dm_files():
            if path == HELPER:
                continue
            text = path.read_text(encoding='utf-8', errors='replace')
            found += [f'{path.relative_to(ROOT)}: {m.group(0)}' for m in DECLARED.finditer(text)]
        self.assertEqual(found, [])

    def test_break_hooks_keep_their_side_effects(self):
        falcon = (ROOT / 'code/game/objects/map_metadata/operation_falcon.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/structure/fob_spawnpoint/on_break()\n\tadmin_destroyed_notice("FOB")\n', falcon)
        self.assertIn('/obj/structure/supply_crate/on_break()\n\texplosion(get_turf(src),0,1,1,1)\n', falcon)
        wild = (ROOT / 'code/game/objects/structures/wild.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/structure/wild/on_break()\n\tif (stored_unit)\n\t\trelease_stored()\n', wild)
        barricade = (ROOT / 'code/game/objects/structures/barricades.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/structure/barricade/on_break()\n\tdismantle()\n', barricade)


if __name__ == '__main__':
    unittest.main()
