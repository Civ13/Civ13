"""Pointing at a tile: offline seam checks.

The native probe (probe.dm, run.py) checks the behaviour in a real build:
Shift+middle-click makes the arrow, the widescreen edge can be pointed at, and
the arrow expires. These checks keep the hooks the probe relies on in place.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


CLICK = read('code/_onclick/click.dm')
VERBS = read('code/game/mob/living/verbs.dm')
LIVING = read('code/game/mob/living/living.dm')
DECAL = read('code/game/objects/effects/decals/misc.dm')
GHOST = read('code/game/mob/observer/ghost/ghost.dm')


class PointingSources(unittest.TestCase):
    def test_shift_middle_click_points(self):
        self.assertLess(CLICK.index('modifiers["shift"] && modifiers["middle"]'),
                        CLICK.index('if (modifiers["middle"])'))
        body = CLICK[CLICK.index('/atom/proc/ShiftMiddleClick('):]
        self.assertIn('user.pointed(src)', body[:200])

    def test_range_follows_the_game_view(self):
        self.assertIn('in view(WORLD_VIEW))', VERBS)
        self.assertIn('view(client && client.view ? client.view : WORLD_VIEW, loc)', VERBS)

    def test_message_does_not_need_usr(self):
        body = LIVING[LIVING.index('/mob/living/pointed('):]
        body = body[:body.index('return TRUE')]
        self.assertNotIn('usr.', body)
        self.assertIn('visible_message(', body)

    def test_arrow_draws_above_light_and_cover(self):
        body = DECAL[DECAL.index('/obj/effect/decal/point'):DECAL.index('/obj/effect/decal/spraystill')]
        self.assertRegex(body, r'\n\tplane = CHAT_PLANE\n')
        self.assertIn("icon = 'icons/mob/screen/effects.dmi'", body)
        self.assertIn('icon_state = "arrow"', body)

    def test_ghosts_have_no_dead_point_verb(self):
        self.assertIsNone(re.search(r'/mob/observer/ghost/verb/pointed', GHOST))


if __name__ == '__main__':
    unittest.main()
