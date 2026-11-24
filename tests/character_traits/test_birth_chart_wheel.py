"""Offline projection of the chart model and private entry paths (no BYOND)."""
from pathlib import Path
import ast
import math
import operator
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HUMAN = ROOT / "code/game/mob/living/carbon/human"
MODEL = (HUMAN / "birth_chart_wheel.dm").read_text(encoding="utf-8")
LEGACY = (HUMAN / "birth_charts.dm").read_text(encoding="utf-8")
TRAVEL = (ROOT / "code/modules/persistence/region_travel.dm").read_text(encoding="utf-8")
JOIN = (ROOT / "code/game/mob/new_player/new_player.dm").read_text(encoding="utf-8")
SIGN_IDS = re.findall(r'^\s*"([a-z]+)" = list\("name"', LEGACY, re.M)


def body(source, header):
    return source.split(header, 1)[1].split("\n/", 1)[0]


def formula(expression, **values):
    """Translate only the fixed arithmetic in the checked-in DM expressions."""
    ops = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv}
    functions = {"round": math.floor, "world_calendar_fmod": operator.mod}
    # Evaluate the shared, pure arithmetic helpers without permitting other DM calls.
    for name, params in (("birth_chart_moon_angle", ("day", "minute")),
                         ("birth_chart_rising_angle", ("local_minute",))):
        expr = re.search(r"^\s*return (.+)$", body(MODEL, f"/proc/{name}("), re.M)[1]
        functions[name] = lambda *args, expr=expr, params=params: formula(expr, **dict(zip(params, args)))

    def calculate(node):
        if isinstance(node, ast.Constant) and type(node.value) is int:
            return node.value
        if isinstance(node, ast.Name) and node.id in values:
            return values[node.id]
        if isinstance(node, ast.BinOp) and type(node.op) in ops:
            return ops[type(node.op)](calculate(node.left), calculate(node.right))
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in functions and not node.keywords:
            return functions[node.func.id](*(calculate(arg) for arg in node.args))
        raise AssertionError(f"Unexpected model expression {ast.dump(node)}")

    return calculate(ast.parse(expression, mode="eval").body)


def angles(sign, day, minute, zone):
    prod = body(MODEL, "/proc/birth_chart_angles(")
    env = {"day": day, "minute": minute, "index": SIGN_IDS.index(sign) + 1}
    def assignment(target):
        return re.search(rf"{re.escape(target)} = (.+)", prod)[1]
    local = formula(assignment("local_minute").replace('record["zone"]', "zone"),
                    minute=minute, zone=zone) if zone is not None else None
    return (formula(assignment('angles["Sun"]'), **env),
            formula(assignment('angles["Moon"]'), **env),
            formula(assignment('angles["Rising"]'), local_minute=local) if local is not None else None)


def house(angle, rising):
    expr = re.search(r"^\s*return (1 \+ round\(.+)$", body(MODEL, "/proc/birth_chart_house("), re.M)[1]
    return formula(expr, angle=angle, rising=rising)


def aspect(angle_a, angle_b):
    source = body(MODEL, "/proc/birth_chart_aspect(")
    entries = re.findall(r'list\("([A-Za-z]+)", (\d+), "#[a-f0-9]+"\)', source)
    tolerance = int(re.search(r"if \(orb <= (\d+)\)", source)[1])
    distance = abs(angle_a - angle_b)
    if "min(distance, 360 - distance)" in source:
        distance = min(distance, 360 - distance)
    return next(((name, abs(distance - int(target))) for name, target in entries
                 if abs(distance - int(target)) <= tolerance), None)


class BirthChartWheel(unittest.TestCase):
    def test_sample_model_and_different_birthplace(self):
        self.assertEqual(len(SIGN_IDS), 12)
        a = angles("serpent", 12, 400, -2)  # Gaia: UTC 06:40, local 04:40
        self.assertEqual(a, (222, 159, 70))
        self.assertEqual([house(x, a[2]) for x in a], [6, 3, 1])
        b = angles("serpent", 12, 400, 1)
        self.assertEqual(b, (222, 159, 115))
        self.assertNotEqual(house(a[0], a[2]), house(b[0], b[2]))
        self.assertEqual(angles("serpent", 12, 400, None), (222, 159, None))
        self.assertEqual(angles("serpent", 12, 0, -2)[2], 330)
        self.assertNotEqual(angles("serpent", 13, 400, -2)[1], a[1])
        self.assertNotEqual(angles("serpent", 12, 404, -2)[2], a[2])

    def test_aspect_exact_boundary_wrap_and_no_hit(self):
        self.assertEqual(aspect(222, 159), ("Sextile", 3))
        self.assertEqual(aspect(159, 70), ("Square", 1))
        self.assertIsNone(aspect(222, 70))
        self.assertEqual(aspect(359, 4), ("Conjunction", 5))
        self.assertIsNone(aspect(359, 5))
        self.assertEqual(aspect(0, 120), ("Trine", 0))
        self.assertEqual(aspect(3, 184), ("Opposition", 1))
        self.assertEqual(house(1, 359), 1)
        self.assertEqual(house(358, 359), 12)

    def test_initial_spawn_once_and_transfer_leave_legacy_unknown(self):
        self.assertEqual(JOIN.count("new_character.record_birth_chart()"), 1)
        self.assertIn("faction_start_apply(new_character)\n\tnew_character.record_birth_chart()\n\tnew_character.key", JOIN)
        capture = body(MODEL, "/mob/living/human/proc/record_birth_chart()")
        self.assertIn("birth_chart_record || persistence_restored", capture)
        self.assertIn("var/list/now = world_calendar_now()", capture)
        self.assertNotIn("birth_chart_record", LEGACY)
        self.assertIn('P["chart_record"] = birth_chart_record.Copy()', TRAVEL)
        self.assertIn('("chart_record" in P) && !birth_chart_record_valid', TRAVEL)
        self.assertIn('H.birth_chart_record = P["chart_record"].Copy()', TRAVEL)
        model = body(MODEL, "/proc/birth_chart_angles(")
        self.assertIn('list("Sun" = null, "Moon" = null, "Rising" = null)', model)
        self.assertIn('|| isnull(record["day"])', model)
        self.assertIn('if (isnull(angle) || isnull(rising))', MODEL)
        self.assertIn('if (isnull(angle_a) || isnull(angle_b))', MODEL)

    def test_detail_view_preserves_model_outputs_and_missing_data(self):
        model_cusps = body(MODEL, "/proc/birth_chart_cusps(")
        self.assertIn("for (var/i in 1 to 12)", model_cusps)
        self.assertIn("birth_chart_placement(world_calendar_fmod(rising + (i - 1) * 30, 360), rising)", model_cusps)
        html = body(MODEL, "/proc/birth_chart_wheel_html(")
        for name in ("House cusps", "Shared calendar", "Longitude", 'aspect["separation"]', 'aspect["exact"]', 'aspect["orb"]'):
            self.assertIn(name, html)
        self.assertIn("House cusps not recorded.", html)
        self.assertNotIn("<img", html)

    def test_private_verb_has_no_mutator_and_wheel_has_text_equivalent(self):
        verb = body(MODEL, "/mob/living/human/verb/view_birth_chart()")
        self.assertIn("usr != src || !client || client.mob != src", verb)
        self.assertIn("new(src,", verb)
        self.assertIn("set_content(birth_chart_wheel_html(birth_chart, birth_chart_record))", verb)
        for unsafe in ("world <<", "Topic(", "href", "apply_birth_chart("):
            self.assertNotIn(unsafe, MODEL)
        html = body(MODEL, "/proc/birth_chart_wheel_html(")
        self.assertIn('list("Sun", "Moon", "Rising")', html)
        self.assertIn('html_encode(record["region"])', html)
        self.assertIn('Not enough placements recorded.', html)
        self.assertIn('if (aspect)\n\t\t\t\tsvg += birth_chart_wheel_line(', html)


if __name__ == "__main__":
    unittest.main()
