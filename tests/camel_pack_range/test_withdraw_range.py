"""Camel pack withdrawal rechecks range after the menu (#6720)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/game/mob/living/simple_animal/friendly/farm_animals.dm").read_text(encoding="utf-8-sig")


def block(header):
    start = SOURCE.index(header)
    nxt = re.search(r"\n(?=\S)", SOURCE[start + len(header):])
    return SOURCE[start:start + len(header) + nxt.start()] if nxt else SOURCE[start:]


class CamelPackRangeTest(unittest.TestCase):
    def test_range_is_rechecked_between_menu_and_transfer(self):
        verb = block("/mob/living/simple_animal/camel/verb/remove_from_storage()")
        self.assertIn("set src in range(2)", verb)
        menu = verb.index("WWinput(usr,")
        recheck = verb.index("get_dist(src, usr) > 2")
        move = verb.index("persistence_set_loc(get_turf(usr))")
        self.assertLess(menu, recheck)
        self.assertLess(recheck, move)
        line = verb[verb.rindex("\n", 0, recheck):verb.index("\n", recheck)]
        self.assertIn("usr.z != z", line)
        self.assertIn("QDELETED(src)", line)


if __name__ == "__main__":
    unittest.main()
