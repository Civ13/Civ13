"""Offline source projection of the legacy browser program entry gate."""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / "code/modules/1713/computers"
PROGRAMS = (DIRECTORY / "programs.dm").read_text()
OS = (DIRECTORY / "os.dm").read_text()
COMPUTERS = (DIRECTORY / "computers.dm").read_text()
SPEC = importlib.util.spec_from_file_location(
    "legacy_session_adapter", ROOT / "tests/save_movement/source_adapter.py")
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)


class LegacyProgramAuthorityTests(unittest.TestCase):
    def test_only_public_topic_dispatches_with_bound_actor(self):
        self.assertEqual(re.findall(r"^/datum/program[^\n]*?/Topic\(", PROGRAMS, re.M),
                         ["/datum/program/Topic("])
        self.assertEqual(len(re.findall(r"^/datum/program/(?!proc/)\w+/program_action\(", PROGRAMS, re.M)), 12)
        topic = ADAPTER.extract(PROGRAMS, "/datum/program/Topic")
        self.assertLess(topic.index("var/mob/living/human/actor = usr"),
                        topic.index("if (!program_actor_ready(actor))"))
        self.assertLess(topic.index("if (!program_actor_ready(actor))"),
                        topic.index("return program_action(href_list, actor, origin.console_session_generation)"))

    def test_gate_requires_current_actor_installed_program_and_generation(self):
        actor, second, current = object(), object(), object()
        origin = SimpleNamespace(user=actor, active_console_program=current,
                                 programs=[current], console_session_generation=8,
                                 console_operator_ready=lambda user: user is actor)
        env = dict(usr=actor, user=actor, origin=origin, src=current,
                   isnull=lambda value: value is None, QDELETED=lambda value: False)
        check = ADAPTER.project(PROGRAMS, "/datum/program/proc/program_actor_ready",
                                "actor, generation=None", env)
        self.assertTrue(check(actor))
        self.assertTrue(check(actor, 8))
        self.assertFalse(check(actor, 7))
        self.assertFalse(check(second))
        for field, changed in (("user", second), ("active_console_program", object()),
                               ("programs", []), ("console_operator_ready", lambda _: False)):
            original = getattr(origin, field)
            setattr(origin, field, changed)
            self.assertFalse(check(actor, 8), field)
            setattr(origin, field, original)

    def test_physical_open_binds_operator_and_selecting_program_rotates_epoch(self):
        hand = ADAPTER.extract(COMPUTERS, "/obj/structure/computer/attack_hand")
        self.assertIn("interact(H)", hand)
        opening = ADAPTER.extract(OS, "/obj/structure/computer/interact")
        self.assertLess(opening.index("console_operator_ready(m)"), opening.index("user = m"))
        self.assertLess(opening.index("console_session_generation++"), opening.index("do_html(user)"))
        select = ADAPTER.extract(OS, "/obj/structure/computer/Topic")
        self.assertLess(select.index("H != user"), select.index("active_console_program = loadedprogram"))
        self.assertLess(select.index("console_session_generation++"), select.index("loadedprogram.do_html(H)"))
        ready = ADAPTER.extract(OS, "/obj/structure/computer/proc/console_operator_ready")
        for term in ("!active", "H.stat", "H.restrained()", "H.can_use_hands()",
                     "H.z != z", "get_dist(src, H) > 1", "H.client?.mob == H",
                     "agent_character_for(H)", "!powerneeded || draw_cable_power()"):
            self.assertIn(term, ready)

    def test_delayed_draft_and_payment_handlers_recheck_session(self):
        for name, after in (
            ("monkeysoftmail", 'tmp_comp_vars["mail_subj"] = prompt_result'),
            ("deepnet", "order[4] = newprice*4"),
            ("nilestore", "order[4] = newprice*4"),
            ("cartrader", "var/basecolor = chosencolor"),
            ("bail", "M.use(U.bail_price/5)"),
            ("swiftfix", "M.use(100/5)"),
            ("warrants", "map.warrants += U.real_name"),
            ("junglebank", "map.marketplaceaccounts[user.name] += cost"),
        ):
            with self.subTest(program=name):
                handler = ADAPTER.extract(PROGRAMS, f"/datum/program/{name}/program_action")
                self.assertLess(handler.index("program_actor_ready(user, session_generation)"),
                                handler.index(after))


if __name__ == "__main__":
    unittest.main()
