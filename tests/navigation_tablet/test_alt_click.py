"""Source contracts for the navigation tablet's Alt-click reach guard."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/weapons/tools.dm'
HEADER = '/obj/item/weapon/compass/modern/AltClick(mob/user)'
GUARD = ('\tif (!istype(user, /mob/living) || user.incapacitated() || '
         '(loc != user && (!isturf(loc) || !user.Adjacent(src))))\n\t\treturn')


def assert_guard(test, source):
    body = source.split(HEADER, 1)[1].split('\n/obj/', 1)[0]
    test.assertIn(GUARD + '\n\t..()\n\tturn_on()', body)


class TabletAltClickTest(unittest.TestCase):
    def test_power_toggle_requires_an_able_nearby_actor(self):
        source = SOURCE.read_text(encoding='utf-8')
        assert_guard(self, source)
        test_subtype = '/obj/item/weapon/compass/modern/tacmap\n'
        self.assertIn(test_subtype, source)
        self.assertNotIn('/obj/item/weapon/compass/modern/tacmap/AltClick', source)

    def test_original_unchecked_toggle_is_rejected(self):
        source = SOURCE.read_text(encoding='utf-8')
        self.assertIn(GUARD, source)
        with self.assertRaises(AssertionError):
            assert_guard(self, source.replace(GUARD + '\n', '', 1))

    def test_alt_click_dispatch_does_not_itself_check_reach(self):
        source = (ROOT / 'code/_onclick/click.dm').read_text(encoding='utf-8')
        dispatch = source.split('/mob/proc/AltClickOn(var/atom/A)', 1)[1].split('\n/atom/proc/AltClick', 1)[0]
        self.assertIn('A.AltClick(src)', dispatch)


if __name__ == '__main__':
    unittest.main()
