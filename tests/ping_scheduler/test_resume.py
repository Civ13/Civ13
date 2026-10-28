"""Offline restricted production traces; Python adapters are not native evidence."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
EARLY = 1234


def body(source, signature):
    match = re.search(r"^" + re.escape(signature) + r"\n(.*?)(?=^/|\Z)", source, re.M | re.S)
    if not match:
        raise ValueError(signature)
    return match.group(1)


def translate(source):
    operations = {
        "if (!current_list.len)": "if not ctx.pending:",
        "return": "return",
        "if (world && world.time > 864000)": "if ctx.time > 864000:",
        "avg = 0": "ctx.avg = 0",
        "ping_total = 0": "ctx.total = 0",
        "clients_checked = 0": "ctx.checked = 0",
        "var/clients_checked = 0": "ctx.checked = 0",
        "disabled = TRUE": "ctx.disabled = True",
        "for (current in current_list)": "for current in ctx.pending.copy():",
        "for (var/client/C in current_list)": "for C in ctx.pending.copy():",
        "var/client/C = current": "C = current",
        "track_client(C)": "ctx.track(ctx, C)",
        "PROCESS_LIST_CHECK": "ctx.remove(current)",
        "avg = clients_checked ? ping_total / clients_checked : 0":
            "ctx.avg = ctx.total / ctx.checked if ctx.checked else 0",
        "PROCESS_TICK_CHECK": "if ctx.budget(): return EARLY",
        "if (!C)": "if not C:",
        'if (!hascall(C, ".update_ping"))': "if not C.verb:",
        "if (!client_ckey_check[C.ckey])": "if not ctx.deadlines.get(C.key):",
        "client_ckey_check[C.ckey] = world.time+100": "ctx.deadlines[C.key] = ctx.time + 100",
        "if (world.time < client_ckey_check[C.ckey])": "if ctx.time < ctx.deadlines[C.key]:",
        'winset(C, null, "command=.update_ping+[world.time+world.tick_lag*world.tick_usage/100]")':
            "C = ctx.query(C)",
        "if (C)": "if C:",
        "ping_total += C.last_ping": "ctx.total += C.ping",
        "avg += C.last_ping": "ctx.avg += C.ping",
        "++clients_checked": "ctx.checked += 1",
        "continue": "continue",
        "if (clients_checked)": "if ctx.checked:",
        "avg /= clients_checked": "ctx.avg /= ctx.checked",
        "PROCESS_USE_FASTEST_LIST(clients)": "ctx.pending = ctx.live.copy()",
        "ticks++": "pass",
        "idle()": "pass",
        "main.processFinished(src)": "pass",
        "onFinish()": "pass",
        "if (fire_result == PROCESS_TICK_CHECK_RETURNED_EARLY && !length(current_list))":
            "if fire_result == EARLY and not ctx.pending:",
        "fire_result = null": "fire_result = None",
        "if (fire_result != PROCESS_TICK_CHECK_RETURNED_EARLY || !length(current_list))":
            "if fire_result != EARLY or not ctx.pending:",
        "current = null": "pass",
        "current_list = null": "ctx.pending = None",
        "return fire_result": "return fire_result",
    }
    lines = ["def execute(ctx, C=None, fire_result=None):"]
    for raw in source.splitlines():
        instruction = raw.strip().split(" //", 1)[0]
        if not instruction or instruction.startswith("//"):
            continue
        if instruction not in operations:
            raise ValueError(instruction)
        depth = len(raw) - len(raw.lstrip("\t"))
        if not depth:
            raise ValueError(raw)
        lines.append("    " * depth + operations[instruction])
    namespace = {"EARLY": EARLY}
    exec(compile("\n".join(lines), "<restricted ping source>", "exec"), namespace)
    return namespace["execute"]


class Client:
    def __init__(self, key, ping, verb=True):
        self.key, self.ping, self.verb = key, ping, verb
        self.connected = True

    def __bool__(self):
        return self.connected


class Trace:
    def __init__(self, source, clients):
        self.live = clients.copy()
        self.pending = None
        self.time = 200
        self.avg = 99
        self.total = self.checked = 0
        self.deadlines = {c.key: 1 for c in clients if c}
        self.queries = []
        self.disabled = False
        self.disconnect_on_query = False
        self.fire = translate(body(source, "/process/ping_track/fire()"))
        self.reset = translate(body(source, "/process/ping_track/reset_current_list()"))
        if "/process/ping_track/proc/track_client" in source:
            self.track = translate(body(source, "/process/ping_track/proc/track_client(client/C)"))
        shared = (ROOT / "code/processes/_process.dm").read_text()
        self.finish = translate(body(shared, "/process/proc/finished(fire_result = null)"))

    def remove(self, current):
        for i in range(len(self.pending) - 1, -1, -1):
            if self.pending[i] is current:
                del self.pending[i]
                return

    def query(self, client):
        self.queries.append(client.key)
        if self.disconnect_on_query:
            client.connected = False
            return None
        return client

    def budget(self):
        self.checks += 1
        return self.limit is not None and self.checks >= self.limit

    def dispatch(self, limit=None):
        if self.pending is None:
            self.reset(self)
        self.limit, self.checks = limit, 0
        self.last_result = self.fire(self)
        return self.finish(self, fire_result=self.last_result)


class PingTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / "code/processes/ping_track.dm").read_text()
        self.clients = [Client(key, ping) for key, ping in zip("abc", (10, 30, 50))]

    def test_partial_sum_count_survive_and_only_completed_average_is_published(self):
        t = Trace(self.source, self.clients)
        self.assertEqual(t.dispatch(1), EARLY)
        self.assertEqual((t.total, t.checked, t.avg), (10, 1, 99))
        self.assertEqual(t.dispatch(1), EARLY)
        self.assertEqual((t.total, t.checked, t.avg), (40, 2, 99))
        self.assertIsNone(t.dispatch(1))
        self.assertEqual(t.last_result, EARLY)
        self.assertEqual((t.total, t.checked, t.avg), (0, 0, 30))
        self.assertEqual(t.queries, list("abc"))
        self.assertIsNone(t.pending)

    def test_final_only_budget_publishes_average_and_next_pass_resets(self):
        t = Trace(self.source, self.clients)
        self.assertIsNone(t.dispatch(3))
        self.assertEqual(t.avg, 30)
        t.live = [self.clients[2]]
        t.dispatch(1)
        self.assertEqual(t.avg, 50)
        self.assertEqual(t.queries, list("abcc"))

    def test_all_skip_paths_consume_and_budget_without_queries(self):
        noverb, new, waiting = Client("noverb", 1, False), Client("new", 2), Client("wait", 3)
        t = Trace(self.source, [None, noverb, new, waiting])
        del t.deadlines["new"]
        t.deadlines["wait"] = 300
        for i in range(4):
            result = t.dispatch(1)
            self.assertEqual(t.checks, 1)
            self.assertEqual(result, EARLY if i < 3 else None)
        self.assertEqual(t.queries, [])
        self.assertEqual(t.deadlines["new"], 300)
        self.assertEqual(t.avg, 0)

    def test_pending_disconnect_is_consumed_and_omitted_from_average(self):
        t = Trace(self.source, self.clients)
        t.dispatch(1)
        self.clients[1].connected = False
        t.dispatch(1)
        t.dispatch(1)
        self.assertEqual(t.queries, list("ac"))
        self.assertEqual(t.avg, 30)

    def test_live_mutation_does_not_restart_prefix_or_admit_new_client(self):
        t = Trace(self.source, self.clients)
        t.dispatch(1)
        added = Client("new", 100)
        t.deadlines["new"] = 1
        t.live = [added]
        t.dispatch()
        self.assertEqual(t.queries, list("abc"))
        t.dispatch(1)
        self.assertEqual(t.queries, ["a", "b", "c", "new"])
        self.assertEqual(t.avg, 100)

    def test_disconnect_during_query_preserves_existing_denominator_rule(self):
        t = Trace(self.source, [self.clients[0]])
        t.disconnect_on_query = True
        t.dispatch(1)
        self.assertEqual(t.queries, ["a"])
        self.assertEqual(t.avg, 0)
        self.assertEqual((t.total, t.checked), (0, 0))

    def test_empty_pass_preserves_previous_average_and_day_cutoff_disables(self):
        t = Trace(self.source, [])
        t.dispatch(1)
        self.assertEqual(t.avg, 99)
        t.live = self.clients
        t.time = 864001
        t.total, t.checked = 20, 2
        t.dispatch(1)
        self.assertTrue(t.disabled)
        self.assertEqual((t.avg, t.total, t.checked), (0, 0, 0))
        self.assertIsNone(t.pending)

    def test_audited_baseline_repeats_prefix_and_publishes_partial_sum(self):
        old = Path(__file__).with_name('fixtures').joinpath('ping_track-9db2b2f.dm').read_text(encoding='utf-8')
        t = Trace(old, self.clients)
        for _ in range(3):
            self.assertEqual(t.dispatch(1), EARLY)
        self.assertEqual(t.queries, ["a", "a", "a"])
        self.assertEqual(t.avg, 10)

    def test_missing_consume_mutant_repeats_prefix(self):
        t = Trace(self.source.replace("\t\tPROCESS_LIST_CHECK\n", ""), self.clients)
        for _ in range(3):
            t.dispatch(1)
        self.assertEqual(t.queries, ["a", "a", "a"])
        self.assertEqual((t.total, t.checked, t.avg), (30, 3, 99))

    def test_finalization_after_budget_mutant_loses_published_result(self):
        late = self.source.replace("\t\t// Publish before the final budget check can return from fire().\n", "\t\tPROCESS_TICK_CHECK\n")
        late = late.replace("\t\t\tclients_checked = 0\n\t\tPROCESS_TICK_CHECK", "\t\t\tclients_checked = 0")
        t = Trace(late, self.clients)
        t.dispatch(3)
        self.assertIsNone(t.pending)
        self.assertEqual(t.avg, 99)
        self.assertEqual((t.total, t.checked), (90, 3))


if __name__ == "__main__":
    unittest.main()
