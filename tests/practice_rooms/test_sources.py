"""Source contracts for practice rooms. Never launches BYOND."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class PracticeRoomSourceTests(unittest.TestCase):
    def test_included_once(self):
        self.assertEqual(read('civ13.dme').count('#include "code\\modules\\1713\\practice_rooms.dm"'), 1)

    def test_every_save_closes_rooms_first(self):
        source = read('code/modules/persistence/functions.dm')
        hook = source.index('practice_rooms_close_for_save()')
        self.assertLess(hook, source.index('persistence_active_operation = operation'))
        self.assertIn('kind == "save" && !practice_rooms_close_for_save()', source)

    def test_level_stays_on_top(self):
        budget = read('code/modules/multiz/world_z_budget.dm')
        self.assertIn('if (practice_room_z && purpose != "practice")', budget)
        self.assertIn('purpose == "practice" && practice_admitted(target_z)', budget)
        multiz = read('code/modules/multiz/dug_underground.dm')
        self.assertIn('z == practice_room_z || z + 1 == practice_room_z', multiz)

    def test_body_is_never_a_character(self):
        rooms = read('code/modules/1713/practice_rooms.dm')
        self.assertIn('/mob/living/human/practice\n\tshould_save = FALSE', rooms)
        self.assertIn('/mob/living/human/practice/record_persistence_owner()\n\tpersistence_owner_ckey = null', rooms)
        self.assertIn('CM-SS13', rooms)

    def test_lobby_link(self):
        lobby = read('code/game/mob/new_player/new_player.dm')
        self.assertIn('practice=1', lobby)
        self.assertIn('practice_rooms.enter(src)', lobby)

    def test_fixture_prepares(self):
        generated = run.sources()
        self.assertIn('#include "tests/practice_rooms/probe.dm"', generated['.practice_rooms_ci.dme'])


if __name__ == '__main__':
    unittest.main()
