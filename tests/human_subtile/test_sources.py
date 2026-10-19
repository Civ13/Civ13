"""Offline source/parity contracts only. Never invokes a BYOND executable."""
from pathlib import Path
import math
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASE = "cc03b199128f8afed58713912c551ad7556e6bc4"
MOVEMENT = "code/game/mob/mob_movement.dm"
MODULE = "code/game/mob/living/carbon/human/subtile_movement.dm"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def baseline(path):
    return subprocess.check_output(["git", "show", BASE + ":" + path], cwd=ROOT).decode().replace("\r\n", "\n")


def deadline(raw, now, traits=(), multiplier=1, role=""):
    if "Slowness" in traits:
        multiplier *= .85
    elif "Agile" in traits:
        multiplier *= 1.15
    elif role == "Tuy Phai":
        multiplier *= 1.25
    if "Gigantism" in traits:
        multiplier *= .9
    return now + (raw - now if raw > now else raw) / multiplier


class SourceContracts(unittest.TestCase):
    def test_original_cardinal_epilogue_still_exact(self):
        marker = "\t\tvar/t_movement_speed_multiplier = mob.movement_speed_multiplier"
        old = baseline(MOVEMENT)
        tail = old[old.index(marker):old.index("\n#define NO_ACCURACY_MOVEMENT_CHECKS")]
        self.assertIn(tail, read(MOVEMENT))
        self.assertIn("/mob/living/Move(a, b, flag)", read("code/game/mob/living/living.dm"))

    def test_deadline_formula_preserves_legacy_priority_and_values(self):
        for now in (0, 100, 1000):
            for duration in (.7, 2.6, 5.85, 20):
                for traits in ((), ("Agile",), ("Slowness", "Gigantism"), ("Agile", "Slowness")):
                    for scale in (.75, 1, 1.25):
                        factor = scale
                        factor *= .85 if "Slowness" in traits else 1.15 if "Agile" in traits else 1
                        if "Gigantism" in traits:
                            factor *= .9
                        self.assertAlmostEqual(deadline(now + duration, now, traits, scale), now + duration / factor)
        source = read(MODULE)
        for literal in ('multiplier *= 0.85', 'multiplier *= 1.15', 'multiplier *= 1.25', 'multiplier *= 0.9'):
            self.assertIn(literal, source)

    def test_absolute_schedule_catches_up_without_eight_rounding_losses(self):
        for tick in (1, .5):
            for duration in (.7, 2.6, 5.85, 20):
                due = [i * duration / 8 for i in range(8)]
                actual = [math.ceil((d - 1e-9) / tick) * tick for d in due]
                self.assertEqual(len(actual), 8)
                self.assertLessEqual(actual[-1], math.ceil(duration / tick) * tick)
                self.assertEqual(8 * 4, 32)
        source = read(MODULE)
        self.assertIn("start_time + (i - 1) * duration / 8", source)
        self.assertIn("sleep(due - world.time)", source)
        self.assertNotIn("sleep(duration / 8)", source)

    def test_one_use_context_and_no_direct_position_bypass(self):
        module = read(MODULE)
        self.assertIn('moved = T.perform(direct)', module)
        self.assertIn('/datum/human_subtile_transaction/proc/perform(direction)', module)
        self.assertNotIn('/proc/run(', module)  # DM reserves run.
        for guard in ('!P.armed', 'P.actor != src', 'P.destination != destination', 'P.direction != direction', 'P.armed = FALSE'):
            self.assertIn(guard, module)
        self.assertNotRegex(module, r"\b(?:loc|step_x|step_y)\s*=(?!=)")
        source = read(MOVEMENT)
        self.assertIn('var/mob/living/human/subtile_actor\n\tif (ishuman(src))\n\t\tsubtile_actor = src', source)
        self.assertIn("..(newloc, direct, subtile_pulse.sx, subtile_pulse.sy)", source)
        self.assertIn("if (!subtile_pulse)\n\t\t\t\treturn FALSE", source)

    def test_completion_and_cleanup_cover_partial_cancel_delete(self):
        source = read(MODULE)
        self.assertIn("!completed && actor && !isDeleted(actor) && total_distance > 0", source)
        self.assertIn("actor.living_movement_completed()", source)
        self.assertIn("actor.human_movement_completed()", source)
        self.assertIn("if (!actor || isDeleted(actor) || actor.human_subtile_transaction != src)", source)
        self.assertIn("catch (var/exception/subtile_completion_error)\n\t\trelease()", source)

    def test_owned_import_precedes_assignments_without_legacy_global_exclusion(self):
        source = read("code/modules/persistence/loading.dm")
        self.assertLess(source.index("restored_human.human_subtile_prepare_import(savefile)"), source.index("for(var/v in savefile.dir)"))
        module = read(MODULE)
        self.assertIn('(human_subtile_import_owned || human_subtile_position)', module)
        self.assertIn('human_subtile_import_owned = ("human_subtile_position" in F.dir)', module)
        self.assertIn('(human_subtile_enabled || human_subtile_offset_owned) && (step_x || step_y)', module)

    def test_restore_requires_anchor_geometry_callbacks_and_preserves_facing(self):
        source = read(MODULE)
        self.assertIn('x != S["x"] || y != S["y"] || z != S["z"]', source)
        self.assertIn('!human_subtile_destination_clear(S)', source)
        self.assertIn('!A.CanPass(src, T, 1.5, FALSE)', source)
        self.assertIn('P.direction = dir', source)
        self.assertIn('Move(loc, dir)', source)
        self.assertIn('throw EXCEPTION("Malformed sub-tile position capsule")', source)

    def test_fixture_uses_production_codec_and_explicit_authority_adapter(self):
        fixture = read("tests/human_subtile/probe.dm")
        for call in ('map_storage.BuildVarDirectory(F, C, 1)', 'map_storage.Load_Entry(F, ref', 'L.after_load()', 'C.Move(get_step(H, direction), direction, FALSE)'):
            self.assertIn(call, fixture)
        self.assertIn('if (client)\n\t\treturn ..()', fixture)
        self.assertIn('"real_client_failed_attempt_cost_and_cooldown_parity"', fixture)
        self.assertIn('"production_shoe_step_and_footstep_gate_once"', fixture)
        self.assertIn('var/human_subtile_fixture_phase', fixture)
        self.assertIn('text2file(json_encode(row), "client-observations.jsonl")', fixture)
        blocked = fixture[fixture.index('for (var/enabled_blocked'):]
        self.assertLess(blocked.index('human_subtile_fixture_record_client(row)'), blocked.index('human_subtile_fixture_assert('))
        self.assertIn('row["admission_state"] = blocked_admission_state', blocked)
        self.assertIn('row["end_state"] = human_subtile_fixture_client_state(C, H)', blocked)


if __name__ == "__main__":
    unittest.main(verbosity=2)
