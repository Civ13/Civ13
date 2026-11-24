"""Source contracts for practice rooms. Never launches BYOND."""
from pathlib import Path
import re
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
        # The practice level is left out of the level column, so nothing climbs to or from it.
        self.assertIn('if (z != practice_room_z && !(z in caves))', multiz)
        self.assertIn('if (practice_room_z && z == practice_room_z)\n\t\treturn 0', multiz)

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
        self.assertIn('practice_room_open(src)', lobby)

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

    def test_tutorial_region_never_saves(self):
        source = read('code/modules/persistence/functions.dm')
        self.assertLess(source.index('if(kind == "save" && tutorial_region_here()) return null'), source.index('persistence_active_operation = operation'))
        kind_list = read('code/modules/persistence/shard_group.dm').split(
            'entry["kind"] in list(', 1)[1].split(')', 1)[0]
        self.assertIn('"TUTORIAL"', kind_list)
        self.assertIn('"BARRACKS", "BATTLE", "EVENT", "TUTORIAL"', read('code/modules/persistence/region_home.dm'))
        self.assertIn('#include "code\\modules\\1713\\tutorial_region.dm"', read('civ13.dme'))

    def test_lobby_goes_to_the_tutorial_region(self):
        lobby = read('code/game/mob/new_player/new_player.dm')
        self.assertIn('if (practice_room_available())', lobby)
        self.assertIn('practice_room_open(src)', lobby)
        join = lobby[lobby.index('/mob/new_player/proc/handle_lobby_join('):]
        self.assertLess(join.index('tutorial_region_refuse_join(src)'), join.index('allow_new_character(src)'))

    def test_tutorial_map(self):
        dmm = read('maps/special/tutorial.dmm')
        self.assertIn('/obj/map_metadata/tutorial,', dmm)
        rows = dmm.split('{"\n', 1)[1].split('\n"}', 1)[0].splitlines()
        self.assertEqual((397, 257), (len(rows[0]), len(rows)))

    def test_workshop_keeps_twenty_four_private_slots(self):
        rooms = read('code/modules/1713/practice_rooms.dm')
        dmm = read('maps/special/tutorial.dmm')
        rows = dmm.split('{"\n', 1)[1].split('\n"}', 1)[0].splitlines()
        width, height = len(rows[0]), len(rows)
        self.assertTrue(all(len(row) == width for row in rows))
        self.assertEqual(1, sum(row.count('b') for row in rows))
        self.assertIn('tutorial_region_here() ? PRACTICE_TUTORIAL_WIDTH + 2 : PRACTICE_ROOM_PITCH_X', rooms)
        self.assertIn('tutorial_region_here() ? PRACTICE_TUTORIAL_HEIGHT + 2 : PRACTICE_ROOM_PITCH_Y', rooms)
        pitch_x = int(re.search(r'#define PRACTICE_TUTORIAL_WIDTH (\d+)', rooms)[1]) + 2
        pitch_y = int(re.search(r'#define PRACTICE_TUTORIAL_HEIGHT (\d+)', rooms)[1]) + 2
        cols, rows = (width - 1) // pitch_x, (height - 1) // pitch_y
        self.assertEqual((6, 4), (cols, rows))
        footprints = set()
        for column in range(cols):
            for row in range(rows):
                x, y = 2 + column * pitch_x, 2 + row * pitch_y
                slot = {(tx, ty) for tx in range(x, x + pitch_x - 2)
                        for ty in range(y, y + pitch_y - 2)}
                self.assertTrue(all(1 < tx < width and 1 < ty < height for tx, ty in slot))
                self.assertFalse(footprints.intersection(slot))
                footprints.update(slot)
        # The plot's rectangles are recorded by the room builder and are the
        # only ones the workshop checks trust.
        self.assertIn('props["plot"] = list(x + 1, y + 1, x + 62, y + 60)', rooms)
        self.assertIn('props["shop"] = list(x + 22, y + 1, x + 30, y + 13)', rooms)
        self.assertIn('props["paved"] = list(x + 32, y + 1, x + 62, y + 60)', rooms)
        self.assertIn('props["field"] = list(x + 1, y + 15, x + 62, y + 60)', rooms)
        self.assertIn('return owns_rect(A, props["shop"])', read('code/modules/1713/practice_workshop.dm'))
        self.assertIn('return owns_rect(A, props["plot"])', read('code/modules/1713/practice_workshop.dm'))
        # The fallback room on other regions keeps its own builder.
        self.assertIn('if (tutorial_region_here())\n\t\treturn build_tutorial_room(slot)', rooms)
        self.assertIn('get_turf(A)', read('code/modules/1713/practice_workshop.dm'))

    def test_every_registered_draught_has_an_explicit_lesson(self):
        registry = read('code/modules/naval/draught_kinds.dm')
        workshop = read('code/modules/1713/practice_workshop.dm')
        kinds = set(re.findall(r'^\s+"([A-Z]+)" = list\("name"', registry, re.M))
        offered = dict(re.findall(r'^\s+"((?:Build|Make|Assemble|Rig|Unfold) [^"]+)" = "([a-z]+)"', workshop, re.M))
        self.assertEqual(kinds, {('CAR' if key == 'plane' else key.upper()) for key in offered.values()})
        self.assertEqual(13, len(offered))
        self.assertEqual(set(offered.values()), set(re.findall(r'^\s+if \("([a-z]+)"\)', workshop.split('switch (exercise)', 1)[1].split('/proc/practice_workshop_stack', 1)[0], re.M)))
        self.assertNotIn('This is a paper exercise', workshop)
        self.assertIn('!owns_room(body) || !exercise || props["workshop_kind"]', workshop)
        self.assertIn('owner.sessions["[slot]"] != src', workshop)
        # A stale menu cannot clear yards that changed while it was open.
        self.assertIn('desk.Adjacent(body) || props["workshop_selected"] != current', workshop)
        clear = workshop.split('/datum/practice_session/proc/clear_workshop(', 1)[1].split('\n/', 1)[0]
        self.assertIn('for (var/key in list("paved", "field"))', clear)
        self.assertIn('owner.clear_column(props[key], stores)', clear)
        self.assertIn('owner.lay_tutorial_ground(slot, props[key])', clear)

    def test_tutorial_plot_uses_the_map_levels(self):
        rooms = read('code/modules/1713/practice_rooms.dm')
        region = read('code/modules/1713/tutorial_region.dm')
        metadata = region.split('/obj/map_metadata/tutorial\n', 1)[1].split('\n/', 1)[0]
        # The map keeps the default underground and building levels.
        self.assertNotIn('dig_down_underground', metadata)
        self.assertNotIn('building_levels', metadata)
        self.assertIn('return tutorial_region_here() ? 1 : practice_room_z', rooms)
        self.assertIn('if (practice_room_z || tutorial_region_here())\n\t\treturn TRUE', rooms)
        # A new underground level is walled to each plot before anything forms.
        create = read('code/modules/multiz/dug_underground.dm').split('/proc/underground_create(', 1)[1].split('\n/proc/', 1)[0]
        self.assertLess(create.index('underground_levels_refresh()'), create.index('practice_rooms.underground_added(target_z)'))
        # Every level is cleared when a plot opens or closes.
        wipe = rooms.split('/datum/practice_rooms/proc/wipe_room(', 1)[1].split('\n/', 1)[0]
        self.assertIn('clear_column(slot_rect(slot))', wipe)
        clear = rooms.split('/datum/practice_rooms/proc/clear_column(', 1)[1].split('\n/', 1)[0]
        self.assertIn('for (var/z = world.maxz, z >= 1, z--)', clear)
        self.assertIn('T.ChangeTurf(/turf/sky/building/unformed)', clear)
        # The trainee cannot walk off their plot on any level.
        self.assertIn('/mob/living/human/practice/Move(a, b, flag)\n\tif (practice && isturf(a) && !practice.may_stand(a))\n\t\treturn FALSE', rooms)
        self.assertIn('if (!may_stand(get_turf(body)))\n\t\tbody.forceMove(props["start"])', rooms)

    def test_stores_serve_only_the_plot_trainee(self):
        workshop = read('code/modules/1713/practice_workshop.dm')
        usable = workshop.split('/obj/structure/practice_stores/proc/usable_by(', 1)[1].split('\n/', 1)[0]
        self.assertIn('H.practice.owns_room(H) && H.practice.owns_room(src) && Adjacent(H)', usable)
        hand_out = workshop.split('/obj/structure/practice_stores/proc/hand_out(', 1)[1].split('\n/', 1)[0]
        self.assertIn('if (!path || !usable_by(H))', hand_out)
        self.assertIn('should_save = FALSE', workshop.split('/obj/structure/practice_stores\n', 1)[1].split('\n/', 1)[0])

    def test_aqueduct_allowance_is_exact_and_private(self):
        workshop = read('code/modules/1713/practice_workshop.dm')
        scope = workshop.split('/proc/tutorial_waterworks_recipe', 1)[1].split('/obj/structure/vehicleparts/axis', 1)[0]
        self.assertIn('P.practice.props["workshop_kind"] == "water" && P.practice.owns_rect(P, P.practice.props["paved"]) && P.z == P.practice.owner.room_z()', scope)
        self.assertEqual({
            '/obj/structure/aqueduct_intake',
            '/obj/structure/aqueduct/channel',
            '/obj/structure/sink/aqueduct_fountain',
        }, set(re.findall(r'"(/obj/[^"]+)"', scope)))

    def test_station_modules_stay_on_the_ground_in_the_paved_yard(self):
        workshop = read('code/modules/1713/practice_workshop.dm')
        scope = workshop.split('/proc/tutorial_station_module_site', 1)[1].split('/proc/tutorial_workshop_pair', 1)[0]
        self.assertIn('centre.z != P.practice.owner.room_z()', scope)
        self.assertIn('var/list/paved = P.practice.props["paved"]', scope)
        self.assertEqual(2, scope.count('P.practice.owns_rect('))

    def test_practice_submarine_cannot_leave_the_bay(self):
        workshop = read('code/modules/1713/practice_workshop.dm').split(
            '/obj/structure/vehicleparts/axis/ship/submarine/controls/practice/assembly_refusal', 1)[1]
        self.assertIn('S.min_x - 2', workshop)
        self.assertIn('S.max_x + 2', workshop)
        self.assertIn('not diving', workshop)
        source = read('code/modules/1713/practice_workshop.dm')
        site = source.split('/controls/practice/proc/practice_site()', 1)[1].split('\n/', 1)[0]
        self.assertIn('z == session.owner.room_z()', site)
        self.assertIn('session.owns_rect(src, session.props["paved"])', site)
        self.assertIn('!practice_site()', workshop)
        self.assertIn('stopmovementloop()', workshop)

    def test_owned_cords_are_checked_before_consuming_stock(self):
        code = read('code/modules/1713/mechanisms.dm')
        at_wait = code.split('do_after(user, MECHANISM_TIE_TIME, trigger)', 1)[1].split('\n', 1)[0]
        self.assertLess(at_wait.index('tutorial_workshop_pair'), at_wait.index('R.use(1)'))

    def test_marker_plans_check_private_footprint_before_commit(self):
        for path, handler, commit in (
            ('code/game/objects/house_plan_pegs.dm', '/proc/house_peg_menu(', 'var/list/result = house_plan_peg_out('),
            ('code/modules/1713/rail_plan.dm', '/proc/rail_peg_menu(', 'build_markers_pull(peg_set)'),
            ('code/modules/1713/waterworks_plan.dm', '/proc/peg_out(', 'build_markers_pull(set_id)'),
        ):
            code = read(path).split(handler, 1)[1]
            self.assertLess(code.index('tutorial_workshop_footprint('), code.index(commit), path)

    def test_all_live_tutorial_text_without_progress_writes(self):
        live = read('code/modules/client/player_tutorial.dm')
        step_line = live.split('/proc/tutorial_step_ids()', 1)[1].splitlines()[1]
        ids = set(re.findall(r'"([a-z_]+)"', step_line))
        board = read('code/modules/1713/practice_workshop.dm').split(
            '/obj/structure/practice_lesson_board/attack_hand', 1)[1].split(
            '/obj/structure/slipway/practice', 1)[0]
        self.assertEqual(ids, set(re.findall(r'= "([a-z_]+)"', board)))
        self.assertIn('tutorial_step_text(lessons[choice], connection)', board)
        self.assertNotIn('tutorial_done', board)
        self.assertNotIn('tutorial_state', board)

    def test_tutorial_fixtures_stay_out_of_public_atlas(self):
        public = read('UI/crafting-atlas.json')
        admin_only = read('code/game/mob/crafting_atlas_admin.dm')
        for path in ('/obj/structure/practice_lesson_board', '/obj/structure/practice_workshop_desk', '/obj/structure/practice_stores'):
            self.assertNotIn(path, public)
            self.assertIn(path + ' = ', admin_only)

    def test_fixture_prepares(self):
        generated = run.sources()
        self.assertIn('#include "tests/practice_rooms/probe.dm"', generated['.practice_rooms_ci.dme'])


if __name__ == '__main__':
    unittest.main()
