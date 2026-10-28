"""Offline production-predicate projections and exact fixture preparation.

These evaluate the actual simple can_cross/draw guards, not a second state
machine. DM native lifecycle, savefile and list behavior remain separate checks.
"""
from __future__ import annotations

import importlib.util
import itertools
from pathlib import Path
import re
import tempfile
from types import SimpleNamespace
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location("backrooms_prepare", HERE / "prepare.py")
prepare_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare_module)
SOURCE = (ROOT / prepare_module.CORE).read_text(encoding="utf-8")


def body(source: str, name: str) -> str:
    match = re.search(r"^\tproc/" + name + r"\([^\n]*\)\n((?:\t\t[^\n]*\n|\n)+)", source, re.M)
    if not match:
        raise AssertionError(f"missing production proc: {name}")
    return match.group(1)


def expression(value: str, context: dict) -> bool:
    # Deliberately only project audited pure boolean expressions, no DM statements.
    value = value.replace("&&", " and ").replace("||", " or ")
    value = re.sub(r"!(?!=)", "not ", value)
    return bool(eval(value, {"__builtins__": {}}, context))


def can_cross(source=SOURCE, **overrides) -> bool:
    context = dict(enabled=True, valid=lambda: True, destination_ready=True,
                   state="READY", supply=SimpleNamespace(connected=True, epoch=4, charge=2),
                   source_epoch=4, now=300, last_now=300, next_due=310,
                   backrooms_integer=lambda value, low, high: isinstance(value, (int, float))
                   and low <= value <= high and int(value) == value)
    context.update(overrides)
    lines = [line.strip() for line in body(source, "can_cross").splitlines() if line.strip()]
    if len(lines) != 3 or lines[1] != "return FALSE":
        raise AssertionError("predicate shape changed; review projection")
    if expression(lines[0][4:-1], context):
        return False
    return expression(lines[2].removeprefix("return "), context)


class ContractTests(unittest.TestCase):
    def test_power_admission_truth_table(self):
        for enabled, valid, destination, ready, connected, epoch, charge in itertools.product(
                (False, True), repeat=7):
            context = dict(enabled=enabled, valid=lambda: valid,
                           destination_ready=destination, state="READY" if ready else "STARTING",
                           supply=SimpleNamespace(connected=connected, epoch=4 if epoch else 5,
                                                  charge=2 if charge else 1))
            with self.subTest(context=context):
                self.assertEqual(can_cross(**context), all((enabled, valid, destination, ready,
                                                          connected, epoch, charge)))

    def test_lease_and_clock_boundaries(self):
        for now, allowed in ((299, False), (300, True), (309, True), (310, False),
                             (311, False), (-1, False), (300.5, False)):
            self.assertEqual(can_cross(now=now), allowed, now)

    def test_outage_control_is_detected_at_named_boundary(self):
        before, after = prepare_module.CONTROLS["outage"]
        altered = SOURCE.replace(before, after)
        supply = SimpleNamespace(connected=False, epoch=4, charge=2)
        self.assertFalse(can_cross(supply=supply))
        self.assertTrue(can_cross(source=altered, supply=supply))

    def test_supply_actual_rejection_guard(self):
        guard = body(SOURCE, "draw").splitlines()[0].strip()[4:-1]
        for valid, connected, units, charge in itertools.product(
                (False, True), (False, True), (-1, 0, 0.5, 1, 2, 600, 601), (0, 1, 600)):
            context = dict(valid=lambda: valid, connected=connected, units=units,
                           charge=charge, capacity=600,
                           backrooms_integer=lambda x, lo, hi: lo <= x <= hi and int(x) == x)
            expected = not (valid and connected and units >= 1 and units <= 600
                            and int(units) == units and units <= charge)
            self.assertEqual(expression(guard, context), expected)

    def test_restore_validates_before_publication_and_strips_runtime(self):
        restore = body(SOURCE, "restore")
        self.assertLess(restore.index('candidate[key] != binding[key]'), restore.index("supply = staged"))
        self.assertLess(restore.index('backrooms_integer(record["supply_charge"]'), restore.index("supply = staged"))
        self.assertIn("stop()", restore)
        snapshot = body(SOURCE, "snapshot")
        self.assertNotIn('"state"', snapshot)
        self.assertNotIn('"enabled"', snapshot)
        self.assertNotIn('"connected"', snapshot)
        self.assertNotIn('"next_due"', snapshot)

    def test_no_production_activation_or_transport(self):
        self.assertIn("var/enabled = FALSE", SOURCE)
        self.assertNotRegex(SOURCE, r"\b(?:spawn|sleep|locate|forceMove|persistence_set_loc|shell|Export)\(")
        self.assertNotIn("var/global", SOURCE)
        self.assertNotIn("/obj/", SOURCE)
        self.assertIn('backrooms\\gateway_core.dm"', (ROOT / "civ13.dme").read_text())

    def test_prepare_preserves_exact_source_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "packet"
            manifest = prepare_module.prepare(output)
            self.assertEqual((output / "gateway_core.dm").read_bytes(), (ROOT / prepare_module.CORE).read_bytes())
            self.assertEqual(manifest["production_sha256"], manifest["prepared_sha256"])
            self.assertEqual(manifest["target"], "516.1688")
            with self.assertRaises(FileExistsError):
                prepare_module.prepare(output)

    def test_all_mutations_are_isolated_and_bound_to_named_assertions(self):
        assertions = {"outage": "outage admission", "debit": "finite debit", "restore": "restore off"}
        with tempfile.TemporaryDirectory() as directory:
            for control in prepare_module.CONTROLS:
                output = Path(directory) / control
                manifest = prepare_module.prepare(output, control)
                self.assertNotEqual(manifest["production_sha256"], manifest["prepared_sha256"])
                self.assertIn(assertions[control], (output / "fixture.dm").read_text())


if __name__ == "__main__":
    unittest.main()
