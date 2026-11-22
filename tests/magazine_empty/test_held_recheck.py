"""Emptying a magazine rechecks that the player still holds it after the prompt (#6479)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/modules/projectiles/ammunition.dm").read_text(encoding="utf-8-sig")


def block(header):
    start = SOURCE.index(header)
    nxt = re.search(r"\n(?=\S)", SOURCE[start + len(header):])
    return SOURCE[start:start + len(header) + nxt.start()] if nxt else SOURCE[start:]


class MagazineEmptyRecheckTest(unittest.TestCase):
    def test_hold_is_rechecked_between_prompt_and_emptying(self):
        proc = block("/obj/item/ammo_magazine/attack_self(mob/user)")
        prompt = proc.index("player_input(user,")
        recheck = proc.index("(user.l_hand != src && user.r_hand != src)")
        empty = proc.index("C.loc = user.loc")
        self.assertLess(prompt, recheck)
        self.assertLess(recheck, empty)
        line = proc[proc.rindex("\n", 0, recheck):proc.index("\n", recheck)]
        self.assertIn("QDELETED(src)", line)
        self.assertIn("user.stat", line)
        self.assertIn("cont = FALSE", proc[recheck:empty])


if __name__ == "__main__":
    unittest.main()
