"""Offline source preparation only; does not run or validate BYOND."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("lighting_adapter", Path(__file__).with_name("lighting_interleave_adapter.py"))
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
RUN_SPEC = importlib.util.spec_from_file_location("lighting_runner", Path(__file__).with_name("lighting_interleave_run.py"))
RUNNER = importlib.util.module_from_spec(RUN_SPEC)
RUN_SPEC.loader.exec_module(RUNNER)


class LightingInterleaveAdapter(unittest.TestCase):
    def test_seams_preserve_guards_and_only_instrument_two_refresh_checks(self):
        original = (ROOT / "code/modules/persistence/loading.dm").read_text()
        changed = ADAPTER.instrument_loading(original)
        self.assertEqual(changed.count("lighting_interleave_checkpoint("), 2)
        self.assertEqual(changed.count('!operation.current(src, "load") || all_loaded != lighting_entries || loading_z != B'), 2)
        restored = changed.replace('lighting_interleave_checkpoint(src, operation, "opacity", B) || ', "", 1)
        restored = restored.replace('lighting_interleave_checkpoint(src, operation, "light", B) || ', "", 1)
        for phase, name, call in (("opacity", "light_turf", "recalc_atom_opacity"),
                                  ("light", "light_owner", "update_light")):
            injected = (f'\t\t\t\tif((!QDELETED({name}) && !{name}.gcDestroyed) || '
                        f'(lighting_interleave_omit_guard && {name} == lighting_interleave_target))\n'
                        f'\t\t\t\t\tlighting_interleave_record("{phase}", {name})\n'
                        f'\t\t\t\t\t{name}.{call}()')
            original_guard = f'\t\t\t\tif(!QDELETED({name}) && !{name}.gcDestroyed) {name}.{call}()'
            restored = restored.replace(injected, original_guard, 1)
        self.assertEqual(restored, original)

    def test_missing_or_duplicate_tick_seam_is_rejected(self):
        original = (ROOT / "code/modules/persistence/loading.dm").read_text()
        section_start = original.index("\t\t\tvar/list/lighting_entries = all_loaded\n")
        start, section = original[:section_start], original[section_start:]
        with self.assertRaises(ValueError):
            ADAPTER.instrument_loading(start + section.replace("\t\t\t\tif(TICK_CHECK)\n", "", 1))
        with self.assertRaises(ValueError):
            ADAPTER.instrument_loading(start + section.replace("\t\t\t\tif(TICK_CHECK)\n", "\t\t\t\tif(TICK_CHECK)\n\t\t\t\tif(TICK_CHECK)\n", 1))

    def test_controls_are_explicit_and_source_has_real_scheduler_boundary(self):
        probe = Path(__file__).with_name("lighting_interleave_probe.dm").read_text()
        for case in ADAPTER.CASES:
            self.assertIn('"' + case + '"', probe)
        self.assertIn("sleep(world.tick_lag)", probe)
        self.assertIn("qdel(lighting_interleave_target)", probe)
        self.assertIn("lighting_interleave_target.gcDestroyed = world.time + 1", probe)
        self.assertIn("lighting_interleave_target.gc_destroyed = GC_QUEUED_FOR_QUEUING", probe)
        self.assertIn("spawn(0) lighting_interleave_mutate(storage, level)", probe)
        self.assertIn("hard_target.fixture_hard_delete_now = TRUE", probe)
        self.assertIn("if(hard_delete_now) return QDEL_HINT_HARDDEL_NOW", probe)
        self.assertIn("qdel(hard_target)", probe)
        self.assertNotIn("\n\t\t\tdel(lighting_interleave_target)", probe)
        self.assertIn("isnull(storage.all_loaded[index])", probe)
        self.assertIn("lighting_interleave_hardnull && !lighting_interleave_target && !lighting_interleave_null_calls", probe)

    def test_phase_selection_is_explicit_and_failure_receipt_keeps_state(self):
        probe = Path(__file__).with_name("lighting_interleave_probe.dm").read_text()
        reset = probe.split('/proc/lighting_interleave_reset(case_name)', 1)[1].split('/proc/lighting_interleave_case_run(', 1)[0]
        self.assertIn('if(case_name in list("turf_legacy", "turf_new", "replace_list", "change_level"))\n\t\tlighting_interleave_phase = "opacity"\n\telse\n\t\tlighting_interleave_phase = "light"', reset)
        self.assertNotIn('lighting_interleave_phase = case_name in', reset)
        for field in ('selected_phase', 'checkpoint_done', 'mutation_done'):
            self.assertIn('result["' + field + '"]', probe)

    def test_receipts_require_exact_phases_engine_and_complete_controls(self):
        head = "a" * 40
        writer = {"head": head, "phase": "writer", "version": 516, "build": 1688,
                  "port": 0, "ok": 1, "generation": "round-v2:" + "a" * 32}
        reader = {"head": head, "phase": "reader", "version": 516, "build": 1688,
                  "port": 0, "ok": 1, "cases": list(ADAPTER.CASES)}
        RUNNER.validate_receipt(writer, head, "writer")
        RUNNER.validate_receipt(reader, head, "reader")
        for key, bad in (("head", "b" * 40), ("phase", "writer"), ("port", 1),
                         ("build", 1681), ("ok", 0), ("cases", list(ADAPTER.CASES[:-1]))):
            with self.subTest(key=key):
                changed = dict(reader, **{key: bad})
                with self.assertRaises(RuntimeError):
                    RUNNER.validate_receipt(changed, head, "reader")

    def test_prepare_adds_only_reviewed_fixture_and_guarded_adapter(self):
        head = "a" * 40
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / "output"
            def fake_prepare(root, output, suite):
                self.assertEqual(suite, "human")
                stage = output / "stage"
                (stage / "code/modules/persistence").mkdir(parents=True)
                (stage / "tests/human_subtile").mkdir(parents=True)
                (stage / "code/modules/persistence/loading.dm").write_text(
                    (ROOT / "code/modules/persistence/loading.dm").read_text())
                (stage / "tests/human_subtile/probe.dm").write_text(
                    "/world/New()\n\tturf = /turf/floor/plating/subtile_fixture\n")
                (stage / "human_subtile.dme").write_text("base\n")
                return {"head": head, "dme": "stage/human_subtile.dme"}
            approved = RUNNER.scope()
            approved["sha256"] = "s"
            with mock.patch.object(RUNNER, "verify", return_value=approved), \
                 mock.patch.object(RUNNER.stage_helper, "prepare", side_effect=fake_prepare):
                manifest = RUNNER.stage(out, head, "s")
            self.assertEqual(manifest["review_scope"]["sha256"], "s")
            loader = (out / "stage/code/modules/persistence/loading.dm").read_text()
            self.assertEqual(loader.count("lighting_interleave_checkpoint("), 2)
            self.assertIn('tests\\human_subtile\\lighting_interleave_probe.dm',
                          (out / "stage/human_subtile.dme").read_text())
            self.assertIn("tests/human_subtile/lighting_interleave_probe.dm", manifest["stage_files"])


if __name__ == "__main__":
    unittest.main()
