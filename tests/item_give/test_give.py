"""Drive Give's real prompt/commit logic with deterministic input and item boundaries."""
from pathlib import Path
from types import SimpleNamespace
import importlib.util
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/game/mob/living/carbon/give.dm").read_text(encoding="utf-8")
SPEC = importlib.util.spec_from_file_location("give_source_adapter", ROOT / "tests/save_movement/source_adapter.py")
adapter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(adapter)
adapter.FIELDS += ("client", "incapacitated", "get_active_hand", "get_inactive_hand",
                   "give_held_item", "Adjacent", "item_is_in_hands", "canUnEquip",
                   "give_held_stack", "unEquip")


class GivePrompt(unittest.TestCase):
    def exercise(self, answer, change=None, *, stack=True):
        offered = SimpleNamespace(nodrop=False, nodrop_special_check=lambda: False, stack=stack)
        giver = SimpleNamespace(client=object(), disabled=False, held=offered, near=True, can_remove=True)
        other = SimpleNamespace(client=object(), disabled=False, full=False)
        offered.loc = giver
        changes = []
        notices = []
        giver.incapacitated = lambda: giver.disabled
        giver.get_active_hand = lambda: giver.held
        giver.get_inactive_hand = lambda: None
        giver.Adjacent = lambda other: giver.near
        giver.item_is_in_hands = lambda item: giver.held is item
        giver.canUnEquip = lambda item: giver.can_remove
        other.incapacitated = lambda: other.disabled
        other.hands_are_full = lambda: other.full
        other.visible_message = notices.append
        def receive_stack(item, target):
            changes.append("stack")
            item.loc = target
            return True

        def release(item):
            changes.append("loose")
            item.loc = None
            return True

        def receive_item(item):
            changes.append("receive")
            item.loc = other
            return True

        def prompt(*args):
            if change:
                change(giver, other, offered)
            return answer

        giver.give_held_stack = receive_stack
        giver.unEquip = release
        other.put_in_hands = receive_item
        env = {"QDELETED": lambda obj: obj is None or getattr(obj, "deleted", False),
               "istype": lambda value, kind=None: value is not None if kind is None else value.stack,
               "list": lambda *opts: opts, "STACK": object(), "WWinput": prompt,
               "to_chat": lambda *args: None, "SPAN_WARNING": str, "SPAN_NOTICE": str}
        source = SOURCE.replace("istype(I, /obj/item/stack)", "istype(I, STACK)")
        held = adapter.project(source, "/mob/living/human/proc/give_held_item", "src, I, target", env, method=True)
        giver.give_held_item = lambda item, target: held(giver, item, target)
        verb = adapter.project(source, "/mob/living/human/verb/give", "src, target", env, method=True)
        verb(giver, other)
        return changes, notices

    def test_only_yes_commits_an_offer(self):
        for answer in (None, "", "Cancel", "No"):
            with self.subTest(answer=answer):
                changes, notices = self.exercise(answer)
                self.assertEqual(changes, [])
                self.assertEqual(len(notices), int(answer == "No"))

    def test_both_players_are_rechecked_after_yes(self):
        for change in (lambda g, r, i: setattr(g, "disabled", True),
                       lambda g, r, i: setattr(r, "disabled", True),
                       lambda g, r, i: setattr(g, "client", None),
                       lambda g, r, i: setattr(r, "client", None),
                       lambda g, r, i: setattr(r, "client", object()),
                       lambda g, r, i: setattr(r, "deleted", True)):
            with self.subTest(change=change):
                self.assertEqual(self.exercise("Yes", change), ([], []))

    def test_reach_custody_available_hand_and_unequip_are_commit_time_checks(self):
        for change in (lambda g, r, i: setattr(g, "near", False),
                       lambda g, r, i: setattr(i, "loc", object()),
                       lambda g, r, i: setattr(g, "held", None),
                       lambda g, r, i: setattr(r, "full", True),
                       lambda g, r, i: setattr(g, "can_remove", False),
                       lambda g, r, i: setattr(i, "nodrop", True)):
            with self.subTest(change=change):
                self.assertEqual(self.exercise("Yes", change), ([], []))

    def test_yes_uses_direct_stack_handoff_and_existing_ordinary_path(self):
        changes, notices = self.exercise("Yes")
        self.assertEqual(changes, ["stack"])
        self.assertEqual(len(notices), 1)
        changes, notices = self.exercise("Yes", stack=False)
        self.assertEqual(changes, ["loose", "receive"])
        self.assertEqual(len(notices), 1)


if __name__ == "__main__":
    unittest.main()
