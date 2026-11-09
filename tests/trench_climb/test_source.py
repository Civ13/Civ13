"""Source checks for climbing in and out of trenches with smooth movement.

Smooth movement steps a body 2px at a time, so near a trench edge it already
overlaps the next tile. The exit check then saw the climber's own body as a
dense blocker and refused, leaving players sliding along the trench edge.
tests/trench_climb/probe.dm reproduces this in a real build (see README).
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def proc_body(text, header):
    start = text.index(header)
    following = re.search(r"\n/", text[start + len(header):])
    end = start + len(header) + following.start() if following else len(text)
    return text[start:end]


class TrenchClimb(unittest.TestCase):
    def setUp(self):
        self.trench = read("code/modules/1713/trench.dm")
        self.subtile = read("code/game/mob/living/carbon/human/subtile_movement.dm")
        self.pull = read("code/game/mob/living/carbon/human/pull_pair_producer.dm")
        self.exit = proc_body(self.trench, "/turf/floor/trench/Exit(atom/movable/O, atom/newloc)")
        self.enter = proc_body(self.trench, "/turf/floor/trench/Enter(atom/movable/O, atom/oldloc)")

    def test_climber_does_not_block_its_own_exit(self):
        loop = re.search(r"for \(var/atom/A in newlocation\)\n(?:\t+//[^\n]*\n)?\t+if \(([^)]*)\)", self.exit)
        self.assertIsNotNone(loop)
        self.assertIn("A != L", loop.group(1))

    def test_climbs_never_move_by_raw_force_move(self):
        self.assertNotIn("L.forceMove(", self.exit)
        self.assertNotIn("L.forceMove(", self.enter)
        self.assertGreaterEqual(self.exit.count("trench_climb_place(L, newloc)"), 6)
        self.assertGreaterEqual(self.enter.count("trench_climb_place(L, src)"), 6)

    def test_exit_aligns_before_checking_the_next_tile(self):
        for match in re.finditer(r"var/turf/T = newloc", self.exit):
            before = self.exit[:match.start()].rstrip().splitlines()[-1].strip()
            self.assertEqual(before, "trench_climb_align(L)")

    def test_align_clears_owned_offset(self):
        body = proc_body(self.trench, "/proc/trench_climb_align(mob/living/L)")
        self.assertIn("L.step_x = 0", body)
        self.assertIn("L.step_y = 0", body)
        self.assertIn("human_subtile_offset_owned = FALSE", body)

    def test_climb_levels(self):
        level = proc_body(self.trench, "/turf/floor/trench/trench_climb_level()")
        self.assertIn("/obj/covers/repairedfloor", level)
        self.assertIn("/obj/structure/vehicleparts/frame", level)
        self.assertIn("/turf/proc/trench_climb_level()\n\treturn 0", self.trench)

    def test_level_changes_take_the_tile_path(self):
        ready = proc_body(self.subtile, "/mob/living/human/proc/human_subtile_ready(direction)")
        self.assertIn("!human_subtile_trench_crossing(direction)", ready)
        crawl = proc_body(self.subtile, "/mob/living/human/proc/human_subtile_crawl_ready(direction)")
        self.assertIn("!human_subtile_trench_crossing(direction)", crawl)
        pull = proc_body(self.pull, "/mob/living/human/proc/human_subtile_pull_ready(direct)")
        self.assertIn("human_subtile_trench_crossing(direct)", pull)
        crossing = proc_body(self.subtile, "/mob/living/human/proc/human_subtile_trench_crossing(direction)")
        # Only aligned bodies are rerouted; an offset body keeps smooth recovery.
        self.assertIn("if (step_x || step_y || !isturf(loc))\n\t\treturn FALSE", crossing)
        self.assertIn("direction & (NORTH | SOUTH)", crossing)
        self.assertIn("direction & (EAST | WEST)", crossing)

    def test_free_movement_climbs_from_between_tiles(self):
        ready = proc_body(self.subtile, "/mob/living/human/proc/human_subtile_ready(direction)")
        self.assertIn("(!human_subtile_trench_crossing(direction) || human_subtile_climb_ready())", ready)
        self_move = proc_body(self.subtile, "/mob/living/human/SelfMove(turf/n, direct, deadline = null, fine_step = FALSE)")
        self.assertIn("return human_subtile_trench_climb(climb_direction)", self_move)
        perform = proc_body(self.subtile, "/datum/human_subtile_transaction/proc/perform(direction)")
        # A pixel pulse never reaches a sleeping trench Enter/Exit.
        self.assertIn("actor.human_subtile_climb_direction(direction)", perform)
        self.assertIn("actor.human_subtile_pulse_climbs(dx, dy)", perform)
        climb = proc_body(self.subtile, "/mob/living/human/proc/human_subtile_trench_climb(direction)")
        self.assertIn("do_after(src, down ? 5 : 20, destination, needhand = FALSE)", climb)

    def test_same_level_moves_do_not_climb(self):
        self.assertIn("if (from_turf.trench_climb_level() == trench_climb_level())\n\t\t\treturn ..()", self.enter)
        self.assertIn("if (next_turf.trench_climb_level() == trench_climb_level())\n\t\t\treturn ..()", self.exit)


if __name__ == "__main__":
    unittest.main()
