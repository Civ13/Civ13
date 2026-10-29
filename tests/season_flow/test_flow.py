"""Production next-phase projection and unchanged transition payload checks."""
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
META = "code/game/objects/map_metadata/_map_metadata.dm"
BASE = "d6b06c638517bb4100beeca6a90d09adc3629fb7"
MASTER = "e30ecf95b0cef8fe223f1075418bdc96b1ce3428"
import sys
sys.path.insert(0, str(ROOT / "tests/snowfall_ground"))
from source_contract import without_season_snow
sys.path.insert(0, str(ROOT / "tests/seasonal_construction"))
from construction_contract import without_construction_hook


def body(source, signature):
    return re.search(r"^" + re.escape(signature) + r"\n(.*?)(?=^/|\Z)", source, re.M | re.S).group(1)


class DMList(list):
    """One-based associative lookup adapter, not evidence of native list semantics."""
    def __init__(self, values, associations=None):
        super().__init__(values)
        self.associations = associations or {}

    def lookup(self, key):
        return self.associations.get(key)


def supported(source):
    text = body(source, "/obj/map_metadata/proc/season_edge_supported(previous_phase, next_phase)")
    operations = {
        'if (!(previous_phase in list("SPRING", "SUMMER", "FALL", "WINTER")) || !(next_phase in list("SPRING", "SUMMER", "FALL", "WINTER")) || previous_phase == next_phase)':
            'if previous not in ("SPRING", "SUMMER", "FALL", "WINTER") or target not in ("SPRING", "SUMMER", "FALL", "WINTER") or previous == target:',
        "return FALSE": "return False",
        'return next_phase != "WINTER" || previous_phase == "FALL"': 'return target != "WINTER" or previous == "FALL"',
    }
    lines = ["def projected(previous, target):"]
    for raw in text.splitlines():
        if raw.strip() and not raw.strip().startswith("//"):
            depth = len(raw) - len(raw.lstrip("\t"))
            lines.append("    " * depth + operations[raw.strip()])
    env = {}
    exec("\n".join(lines), env)
    return env["projected"]


def defaults(source):
    text = body(source, "/obj/map_metadata/proc/season_edge_is_default(previous_phase, next_phase)")
    pairs = re.findall(r'if \("([A-Z]+)"\) return next_phase == "([A-Z]+)"', text)
    if len(pairs) != 4 or not text.rstrip().endswith("return FALSE"):
        raise ValueError(text)
    return dict(pairs)


def project(source):
    instructions = {
        'var/list/cycle = isnull(season_cycle) ? list("SPRING", "SUMMER", "FALL", "WINTER") : season_cycle':
            'cycle = DMList(["SPRING", "SUMMER", "FALL", "WINTER"]) if policy is None else policy',
        "if (!islist(cycle) || cycle.len < 2 || cycle.len > 4)":
            "if not isinstance(cycle, DMList) or len(cycle) < 2 or len(cycle) > 4:",
        "return null": "return None",
        "var/list/seen = list()": "seen = []",
        "for (var/phase in cycle)": "for phase in cycle:",
        'if (!(phase in list("SPRING", "SUMMER", "FALL", "WINTER")) || (phase in seen) || !isnull(cycle[phase]))':
            'if phase not in ["SPRING", "SUMMER", "FALL", "WINTER"] or phase in seen or cycle.lookup(phase) is not None:',
        "seen += phase": "seen.append(phase)",
        "for (var/i = 1, i <= cycle.len, i++)": "for i in range(1, len(cycle) + 1):",
        "if (!season_edge_supported(cycle[i], cycle[(i % cycle.len) + 1]))": "if not edge_supported(cycle[i - 1], cycle[i % len(cycle)]):",
        "var/position = cycle.Find(season)": "position = cycle.index(current) + 1 if current in cycle else 0",
        "if (!position)": "if not position:",
        "return cycle[(position % cycle.len) + 1]": "return cycle[position % len(cycle)]",
    }
    lines = ["def projected(policy, current):"]
    for raw in body(source, "/obj/map_metadata/proc/season_next_phase()").splitlines():
        if raw.strip() and not raw.strip().startswith("//"):
            depth = len(raw) - len(raw.lstrip("\t"))
            lines.append("    " * depth + instructions[raw.strip()])
    env = dict(DMList=DMList, edge_supported=supported(source))
    exec("\n".join(lines), env)
    return env["projected"]


class FlowTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / META).read_text()
        self.next = project(self.source)

    def test_default_order_wraparound_and_idempotent_lookup(self):
        for a, b in (("SPRING", "SUMMER"), ("SUMMER", "FALL"), ("FALL", "WINTER"), ("WINTER", "SPRING")):
            self.assertEqual(self.next(None, a), b)
            self.assertEqual(self.next(None, a), b)

    def test_configured_skip_and_order(self):
        policy = DMList(["SPRING", "FALL", "WINTER", "SUMMER"])
        before = policy.copy()
        for a, b in (("SPRING", "FALL"), ("FALL", "WINTER"), ("WINTER", "SUMMER"), ("SUMMER", "SPRING")):
            self.assertEqual(self.next(policy, a), b)
        self.assertEqual(policy, before)
        self.assertIsNone(self.next(policy, "EVENT"))

    def test_empty_singleton_unknown_duplicate_malformed_and_associative_fail_closed(self):
        for policy in (DMList([]), DMList(["SPRING"]), DMList(["SPRING", "SPRING"]),
                       DMList(["SPRING", "EVENT"]), DMList(["SPRING", 3]), "SUMMER", 0,
                       DMList(["SPRING", "SUMMER"], {"SPRING": "payload"}),
                       DMList(["SPRING", "SUMMER", "FALL", "WINTER", "SPRING"])):
            self.assertIsNone(self.next(policy, "SPRING"), policy)

    def test_current_season_absent_and_reload_select_from_actual_current(self):
        policy = DMList(["SUMMER", "FALL"])
        self.assertIsNone(self.next(policy, "SPRING"))
        self.assertEqual(self.next(policy, "FALL"), "SUMMER")
        # There is no saved pointer to advance twice when a current season is restored.
        self.assertEqual(self.next(DMList(policy), "FALL"), "SUMMER")

    def test_invalid_policy_is_rejected_before_epoch_cancellation_or_completion(self):
        queue = body(self.source, "/obj/map_metadata/proc/season_run_queue()")
        guard = queue.index("if (!isnull(season_cycle) && !season_next_phase())")
        for effect in ("season_epoch++", "durable_cancel_season_phases()", "season_apply(force, advance_decay, epoch)", "season_transition_complete(epoch)"):
            self.assertLess(guard, queue.index(effect))
        self.assertIn("if (!isnull(season_cycle) && !season_next_phase())\n\t\t\t\t\tcontinue", queue)
        apply = body(self.source, "/obj/map_metadata/proc/season_apply(var/force, var/advance_decay, var/epoch)")
        self.assertLess(apply.index("if (!next_phase)"), apply.index('season = "WINTER"'))

    def test_transition_payloads_and_counting_are_byte_for_byte_preserved_after_dispatch_projection(self):
        signature = "/obj/map_metadata/proc/season_apply(var/force, var/advance_decay, var/epoch)"
        before = subprocess.check_output(["git", "show", BASE + ":" + META], cwd=ROOT, text=True)
        old = without_season_snow(body(before, signature))[0]
        current = body(self.source, signature)
        current = current.replace("\tvar/next_phase = season_next_phase()\n\tif (!next_phase)\n\t\treturn\n", "")
        for target, prior in (("WINTER", "FALL"), ("SUMMER", "SPRING"), ("SPRING", "WINTER"), ("FALL", "SUMMER")):
            current = current.replace('next_phase == "' + target + '"', 'season == "' + prior + '"')
        self.assertEqual(current, old)
        self.assertEqual(current.count("record_abandonment_season_change(advance_decay)"), 4)

    def test_duration_requests_admin_and_subtype_calendars_unchanged(self):
        before = subprocess.check_output(["git", "show", MASTER + ":" + META], cwd=ROOT, text=True)
        for signature in ("/obj/map_metadata/proc/season_schedule_loop()",
                          "/obj/map_metadata/proc/seasons(var/looping = TRUE, var/force = FALSE, var/advance_decay = null)"):
            self.assertEqual(body(self.source, signature), body(before, signature))
        for relative in ("code/modules/admin/verbs/weather.dm", "code/processes/abandoned_items.dm",
                         "code/game/objects/map_metadata/nomads/nomads_mountain.dm",
                         "code/game/objects/map_metadata/nomads/nomads_ice_age.dm",
                         "code/game/objects/map_metadata/colonia.dm", "code/game/objects/map_metadata/pepelsibirsk.dm"):
            before = subprocess.check_output(["git", "show", MASTER + ":" + relative], cwd=ROOT, text=True)
            current = (ROOT / relative).read_text()
            if relative == "code/processes/abandoned_items.dm":
                current = without_construction_hook(current)
            self.assertEqual(current, without_season_snow(before)[0])

    def test_all_twelve_edges_and_entire_cycle_rejection_before_mutation(self):
        allows = supported(self.source)
        phases = ("SPRING", "SUMMER", "FALL", "WINTER")
        rejected = {("SPRING", "WINTER"), ("SUMMER", "WINTER")}
        for previous in phases:
            for target in phases:
                self.assertEqual(allows(previous, target), previous != target and (previous, target) not in rejected)
        self.assertFalse(allows("EVENT", "SUMMER"))
        for policy in (DMList(["SPRING", "WINTER"]), DMList(["SPRING", "SUMMER", "WINTER"])):
            for current in policy:
                self.assertIsNone(self.next(policy, current), "later invalid edge was partially admitted")

    def test_default_queue_order_preserved_with_one_new_reconciliation_boundary(self):
        queue = body(self.source, "/obj/map_metadata/proc/season_run_queue()")
        self.assertLess(queue.index("var/previous_phase = season"), queue.index("season_epoch++"))
        self.assertLess(queue.index("season_apply(force, advance_decay, epoch)"), queue.index("season_reconcile_edge(previous_phase, season, epoch)"))
        self.assertLess(queue.index("season_reconcile_edge(previous_phase, season, epoch)"), queue.index("season_transition_complete(epoch)"))
        self.assertEqual(queue.count("season_apply(force, advance_decay, epoch)"), 1)
        self.assertEqual(queue.count("season_transition_complete(epoch)"), 1)
        start = self.source.index("/obj/map_metadata/proc/season_edge_supported")
        end = self.source.index("/obj/map_metadata/proc/season_schedule_loop()", start)
        helpers = self.source[start:end]
        self.assertNotIn("record_abandonment_season_change", helpers)
        self.assertNotIn("seasons(", helpers)
        self.assertNotIn("spawn(", helpers)
        self.assertNotIn("season_schedule_phase(", helpers)
        self.assertNotIn("prob(", helpers)

    def test_policy_is_not_durable_payload_and_extraction_retains_helper_and_field(self):
        self.assertIn('"season_cycle"', body(self.source, "/obj/map_metadata/persistence_runtime_var(var/key)"))
        self.assertNotIn('"season_cycle"', (ROOT / "code/modules/persistence/durable_contract.dm").read_text())
        import importlib.util
        runner = ROOT / "tests/season_transition/run.py"
        spec = importlib.util.spec_from_file_location("season_source_preparation", runner)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        files, _ = module.prepare(ROOT, "candidate", "small", None)
        self.assertIn("/obj/map_metadata/proc/season_next_phase()", files["production.dm"])
        self.assertIn("var/list/season_cycle = null", files["production.dm"])


if __name__ == "__main__":
    unittest.main()
