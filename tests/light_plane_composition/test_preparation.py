import hashlib
import json
import importlib.util
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("plane_runner", Path(__file__).with_name("run.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class Preparation(unittest.TestCase):
    def test_legacy_graph_control_prepares_against_complete_current_guard(self):
        loader = ROOT / "code/modules/persistence/loading.dm"
        before = loader.read_bytes()
        prepared = subprocess.run([
            sys.executable, "-B", "tests/world_save/run-durable-world.py",
            "--lighting", "--negative-control", "lighting-legacy", "--prepare-only",
        ], cwd=ROOT, capture_output=True, text=True, timeout=45)
        self.assertEqual(prepared.returncode, 0, prepared.stdout + prepared.stderr)
        output = Path(re.search(r"Retained evidence: (.+)", prepared.stdout).group(1).strip())
        guard = "if(ispath(type, /datum/light_source) || ispath(type, /datum/lighting_corner) || ispath(type, /atom/movable/lighting_overlay) || ispath(type, /atom/movable/lighting_fullbright))"
        self.assertEqual(before.decode().count(guard), 1)
        expected = before.decode().replace("\r\n", "\n").replace(guard, "if(FALSE)", 1)
        matches = [path for path in output.glob("*.dm") if path.read_text(encoding="utf-8") == expected]
        self.assertEqual(len(matches), 1)
        self.assertIn('#include "' + matches[0].name + '"', (output / "probe.dme").read_text(encoding="utf-8"))
        self.assertEqual(loader.read_bytes(), before)
        self.assertFalse(list(output.glob("*.dmb")))
        self.assertFalse(list(output.glob("*.rsc")))

    def test_exact_source_and_controls(self):
        expected = (ROOT / runner.PLANE).read_text()
        self.assertEqual(runner.prepare()["production.dm"], expected)
        self.assertEqual(runner.prepare()["coverage.dm"], (ROOT / "code/modules/lighting/lighting_composition.dm").read_text())
        for control, replacement in (("bypass", "FALSE"), ("ordinary", "TRUE")):
            self.assertEqual(runner.prepare(control)["production.dm"], expected.replace(
                "mymob && mymob.see_invisible >= INVISIBILITY_LEVEL_TWO", replacement))

    def test_render_evidence_binds_source(self):
        evidence = json.loads(Path(__file__).with_name("render-results.json").read_text())
        self.assertEqual(len(evidence["pairs"]), 15)
        for name, digest in evidence["canonical_lf_sources_sha256"].items():
            self.assertEqual(hashlib.sha256((Path(__file__).parent / "rejected" / (Path(name).name + ".txt")).read_text().encode()).hexdigest(), digest)

    def test_mode_refresh_order(self):
        life = (ROOT / "code/game/mob/living/life.dm").read_text()
        self.assertIn("handle_hud_icons()\n\thandle_vision()\n\tupdate_lighting_plane()", life)
        ghost = (ROOT / "code/game/mob/observer/ghost/ghost.dm").read_text()
        self.assertIn("\tupdate_lighting_plane()\n\tupdateghostimages()", ghost)
        human = (ROOT / "code/game/mob/living/carbon/human/human_life.dm").read_text()
        self.assertIn("species.handle_vision(src)", human)
        self.assertIn("\tif (!..())\n\t\treturn", human)

    def test_mask_and_authority_boundary(self):
        source = (ROOT / "code/modules/lighting/lighting_overlay.dm").read_text()
        self.assertIn("blend_mode\t   = BLEND_MULTIPLY", source)
        self.assertIn("blend_mode = LIGHTING_COMPOSITION_V2 ? BLEND_OVERLAY : BLEND_MULTIPLY", source)
        plane = runner.prepare()["production.dm"]
        self.assertNotIn("SEE_TURFS", plane)
        self.assertNotIn("SEE_OBJS", plane)
        self.assertNotIn("client.images", plane)
        self.assertIn("mouse_opacity = 0", plane)
        self.assertIn("#define LIGHTING_COMPOSITION_V2 0", (ROOT / "code/__defines/_planes+layers.dm").read_text())
        self.assertIn("#define LIGHTING_COMPOSITION_V2 0", runner.prepare(enabled=False)["probe.dme"])

    def test_coverage_mutation_changes_only_creation_guard(self):
        ordinary = runner.prepare()
        control = runner.prepare("coverage")
        self.assertEqual(control["coverage.dm"], ordinary["coverage.dm"].replace(
            "\tif(needed && !retained)\n\t\tnew", "\tif(FALSE && !retained)\n\t\tnew"))
        self.assertEqual(control["production.dm"], ordinary["production.dm"])

    def test_lifecycle_and_persistence_seams_are_present(self):
        for name in ("code/game/turfs/turf_changing.dm", "code/modules/lighting/lighting_turf.dm",
                     "code/modules/lighting/lighting_overlay.dm", "code/modules/persistence/loading.dm"):
            self.assertIn("sync_fullbright_coverage()", (ROOT / name).read_text())
        self.assertIn("sync_fullbright_coverage_world()", (ROOT / "code/modules/lighting/lighting_system.dm").read_text())
        self.assertIn("ispath(type, /atom/movable/lighting_fullbright)", (ROOT / "code/modules/persistence/loading.dm").read_text())
        self.assertIn("should_save = FALSE", (ROOT / "code/modules/lighting/lighting_composition.dm").read_text())

    def test_area_change_uses_exact_production_entry_and_hook(self):
        areas = (ROOT / "code/game/area/areas.dm").read_text()
        entry = areas.split("/proc/ChangeArea(", 1)[1]
        owner = "/turf/var/tmp/list/area_change_owner" + areas.split("/turf/var/tmp/list/area_change_owner", 1)[1].split("/proc/ChangeArea(", 1)[0]
        base = (ROOT / "code/modules/lighting/lighting_area.dm").read_text().split("/atom/proc/change_area(", 1)[1]
        base = base if base.endswith("\n") else base + "\n"
        hook = (ROOT / "code/modules/lighting/lighting_turf.dm").read_text().split("/turf/change_area(", 1)[1].split("/turf/proc/get_corners(", 1)[0]
        expected = owner + "/proc/ChangeArea(" + entry + "/atom/proc/change_area(" + base + "/turf/change_area(" + hook
        self.assertEqual(runner.prepare()["area_change.dm"], expected)
        self.assertLess(entry.index("if(old_area == A)"), entry.index("A.contents.Add(T)"))
        self.assertLess(entry.index("A.Entered(AM, old_area)"), entry.index("T.change_area(old_area, A)"))
        self.assertNotIn("old_area.", hook)
        self.assertIn("\twindow_coeff_dirty = TRUE\n\tif (new_area.dynamic_lighting)", hook)
        self.assertLess(hook.index("lighting_build_overlay()"), hook.index("var/area/current_area = get_area(src)"))
        self.assertIn("if (current_area && !current_area.dynamic_lighting && lighting_overlay)", hook)
        fixture = runner.prepare()["area_probe.dm"]
        self.assertIn("ChangeArea(T, fullbright)", fixture)
        self.assertIn("ChangeArea(T, dynamic)", fixture)
        self.assertIn("missing_old_area = TRUE", fixture)
        self.assertNotIn("T.change_area(", fixture)

    def test_eof_proc_has_a_separator_before_next_declaration(self):
        base = runner.production_proc("code/modules/lighting/lighting_area.dm", "/atom/proc/change_area(")
        self.assertTrue(base.endswith("\n"))
        generated = runner.prepare()["area_change.dm"]
        self.assertIn("\treturn\n/turf/change_area(", generated)
        self.assertNotIn("\treturn/turf/change_area(", generated)

    def test_area_change_omission_control_only_removes_dispatch(self):
        ordinary = runner.prepare()
        control = runner.prepare("area-change")
        for name, source in ordinary.items():
            self.assertEqual(control[name], source.replace("\t\tT.change_area(old_area, A)\n", "\t\treturn\n") if name == "area_change.dm" else source)
        self.assertNotEqual(ordinary["area_change.dm"], control["area_change.dm"])

    def test_area_owner_control_preserves_current_destination_guard(self):
        ordinary = runner.prepare()
        control = runner.prepare("area-owner")
        for name, source in ordinary.items():
            self.assertEqual(control[name], source.replace("if(!T || T.area_change_owner != request)", "if(!T)") if name == "area_change.dm" else source)
        self.assertIn("if(get_area(T) == A)", control["area_change.dm"])
        self.assertNotEqual(ordinary["area_change.dm"], control["area_change.dm"])

    def test_area_owner_lifetime_and_supersession_fixture(self):
        source = runner.prepare()["area_change.dm"]
        self.assertLess(source.index("if(old_area == A)"), source.index("T.area_change_owner = request"))
        self.assertLess(source.index("T.area_change_owner = request"), source.index("A.contents.Add(T)"))
        self.assertLess(source.index("A.Entered(AM, old_area)"), source.index("if(!T || T.area_change_owner != request)"))
        self.assertLess(source.index("T.area_change_owner = null"), source.index("if(get_area(T) == A)"))
        fixture = runner.prepare()["area_probe.dm"]
        self.assertIn("sleep(1)", fixture)
        self.assertIn("superseded away-and-back skips outer hook", fixture)
        self.assertIn("new /turf/area_change_probe/replacement(area_probe_turf)", fixture)
        self.assertIn('if (key == "area_change_owner")\n\t\treturn TRUE', (ROOT / "code/modules/persistence/functions.dm").read_text())

    def test_real_build_body_reads_actual_area_after_startup_wait(self):
        turf = (ROOT / "code/modules/lighting/lighting_turf.dm").read_text()
        expected = "/turf/proc/lighting_build_overlay(" + turf.split("/turf/proc/lighting_build_overlay(", 1)[1].split("/turf/proc/adjust_lighting_overlay_to_daylight(", 1)[0]
        body = runner.prepare()["build_overlay.dm"]
        self.assertEqual(body, expected)
        self.assertLess(body.index("while (lighting_startup_in_progress)"), body.index("var/area/A = loc"))
        self.assertLess(body.index("if (A && A.dynamic_lighting)"), body.index("PoolOrNew("))
        fixture = runner.prepare()["area_probe.dm"]
        self.assertIn("return ..()", fixture)
        self.assertIn("startup waiter reads final fullbright area before allocation", fixture)
        self.assertIn("startup dynamic waiters build one final overlay", fixture)

    def test_same_policy_controls_only_restore_skipping_reconciliation(self):
        ordinary = runner.prepare()
        anchor = "\twindow_coeff_dirty = TRUE\n\tif (new_area.dynamic_lighting)"
        for control, condition in (("area-policy", "old_area && new_area.dynamic_lighting == old_area.dynamic_lighting"),
                                   ("area-policy-dynamic", "old_area && new_area.dynamic_lighting && old_area.dynamic_lighting")):
            mutated = runner.prepare(control)
            for name, source in ordinary.items():
                expected = source.replace(anchor, "\twindow_coeff_dirty = TRUE\n\tif (" + condition + ")\n\t\treturn\n\tif (new_area.dynamic_lighting)") if name == "area_change.dm" else source
                self.assertEqual(mutated[name], expected)
            self.assertNotEqual(mutated["area_change.dm"], ordinary["area_change.dm"])


if __name__ == "__main__":
    unittest.main()
