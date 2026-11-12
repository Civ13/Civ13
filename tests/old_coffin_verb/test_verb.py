"""Check the closet Toggle Open verb keeps sealed old coffins shut, from source, not BYOND."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/structures/crates_lockers/closets.dm'
DECL = '/obj/structure/closet/verb/verb_toggleopen()'

# The pre-fix verb, frozen as a negative control: it tested an uninitialised local.
OLD_VERB = DECL + '''
	var/obj/structure/closet/CO
	if (!istype(CO,/obj/structure/closet/old_coffin))
		toggle(usr)
'''


def verb_body(source):
    start = source.index(DECL)
    return source[start:source.find('\n/', start + 1)]


def opens(body, coffin, opened):
    """Return True when the verb would call toggle() for a human."""
    if 'var/obj/structure/closet/CO' in body:
        return True  # istype(null, ...) is false, so the toggle branch always runs
    guard = 'if (istype(src, /obj/structure/closet/old_coffin) && !opened)'
    if guard in body and coffin and not opened:
        return False
    return 'toggle(usr)' in body


class OldCoffinVerbTest(unittest.TestCase):
    def setUp(self):
        self.body = verb_body(SOURCE.read_text(encoding='utf-8'))

    def test_sealed_old_coffin_stays_shut(self):
        self.assertFalse(opens(self.body, coffin=True, opened=False))

    def test_open_coffin_and_ordinary_closets_still_toggle(self):
        self.assertTrue(opens(self.body, coffin=True, opened=True))
        self.assertTrue(opens(self.body, coffin=False, opened=False))

    def test_verb_settings_are_unconditional(self):
        self.assertTrue(self.body.startswith(DECL + '\n\tset src in oview(1)\n\tset category = null\n\tset name = "Toggle Open"'))

    def test_negative_control_old_verb_opens_sealed_coffin(self):
        self.assertTrue(opens(OLD_VERB, coffin=True, opened=False))


if __name__ == '__main__':
    unittest.main()
