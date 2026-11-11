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

    def test_ended_body_drops_its_key(self):
        rooms = read('code/modules/1713/practice_rooms.dm')
        end = rooms[rooms.index('/datum/practice_session/proc/end(reason)'):]
        self.assertLess(end.index('body.key = null'), end.index('qdel(body)'))

    def test_lobby_link(self):
        lobby = read('code/game/mob/new_player/new_player.dm')
        self.assertIn('practice=1', lobby)
        self.assertIn('practice_rooms.enter(src)', lobby)

    def test_ways_out_are_easy_to_find(self):
        rooms = read('code/modules/1713/practice_rooms.dm')
        # Chat link on the welcome line and on every step, handled by the session.
        self.assertIn('practice_leave=1', rooms)
        self.assertIn('if (href_list["practice_leave"] && body && usr == body)', rooms)
        self.assertIn('[leave_link()]', rooms[rooms.index('/datum/practice_session/proc/show_step()'):])
        # The exit marker can be clicked at any step.
        marker = rooms[rooms.index('/obj/effect/practice_marker/exit/Click()'):]
        self.assertIn('H.practice.leave()', marker)
        # Esc menu entry, only for a practice body.
        menu = read('code/modules/client/escape_menu.dm')
        self.assertIn('L["leave_practice"]', menu)
        self.assertIn('if ("leave_practice")', menu)
        # Side panel shows the verbs first on the IC tab, not under "Other".
        panel = read('interface/info/info.html')
        self.assertIn('"IC": [\n                ["Practice", ["Leave Practice Room", "Practice Instructions"]]', panel)

    def test_fixture_prepares(self):
        generated = run.sources()
        self.assertIn('#include "tests/practice_rooms/probe.dm"', generated['.practice_rooms_ci.dme'])


if __name__ == '__main__':
    unittest.main()
