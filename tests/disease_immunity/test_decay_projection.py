"""Offline projection of immunity decay; this does not execute BYOND."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/save_movement"))
import source_adapter

DECL = "/mob/living/human/proc/handle_immunity"
BEFORE = (ROOT / "tests/disease_immunity/before_decay.dm.txt").read_text(encoding="utf-8")
AFTER = (ROOT / "code/game/mob/living/carbon/human/immunity.dm").read_text(encoding="utf-8")
DISEASE_GUARD = "if (!islist(disease_resistance) || disease_resistance.len)"
POISON_GUARD = "if (!islist(poison_exposure) || poison_exposure.len)"


class DMList(list):
    def __iadd__(self, item):
        self.append(item)
        return self


class Table(dict):
    @property
    def len(self):
        return len(self)

    def __isub__(self, values):
        for value in values:
            self.pop(value, None)
        return self


class NonList:
    """A fake invalid value, used only to check the guard's fallback path."""
    def __init__(self):
        self.operations = 0

    def __iter__(self):
        return iter(())

    def __isub__(self, values):
        self.operations += 1
        return self


def segment(source):
    body = source_adapter.extract(source, DECL)
    start = body.index("\tvar/list/faded")
    end = body.index("\n\tif (!fighting)", start)
    return body[start:end]


def execute(source, disease, poison, fighting):
    calls = []
    def make_list():
        calls.append("list")
        return DMList()
    text = "/proc/decay(disease_resistance, poison_exposure, fighting)\n"
    text += segment(source).replace("var/list/faded\n", "var/list/faded = null\n").replace("list()", "dm_list()") + "\n"
    text += "\treturn (disease_resistance, poison_exposure)\n"
    fn = source_adapter.project(text, "/proc/decay",
        "disease_resistance, poison_exposure, fighting",
        {"dm_list": make_list, "islist": lambda x: isinstance(x, Table),
         "IMMUNITY_DECAY": 0.015, "POISON_TOLERANCE_DECAY": 0.005})
    result = fn(disease, poison, fighting)
    return result, len(calls)


class DecayProjectionTests(unittest.TestCase):
    def compare(self, disease, poison, fighting=None):
        old_d, new_d = Table(disease), Table(disease)
        old_p, new_p = Table(poison), Table(poison)
        old, old_calls = execute(BEFORE, old_d, old_p, fighting)
        new, new_calls = execute(AFTER, new_d, new_p, fighting)
        self.assertEqual(old, new)
        self.assertIs(new[0], new_d)
        self.assertIs(new[1], new_p)
        return old_calls, new_calls, new

    def test_empty_and_mixed_tables(self):
        for disease, poison, saved in [
            ({}, {}, 2),
            ({"flu": 4}, {}, 1),
            ({}, {"arsenic": 4}, 1),
            ({"flu": 4}, {"arsenic": 4}, 0),
        ]:
            with self.subTest(disease=disease, poison=poison):
                old, new, _ = self.compare(disease, poison)
                self.assertEqual(old - new, saved)

    def test_expiry_fighting_and_aliases(self):
        old, new, result = self.compare(
            {"flu": 0.01, "plague": 0.01, "typhus": 3},
            {"arsenic": 0.003, "lead": 2}, "flu")
        self.assertEqual(old, new)
        self.assertEqual(result[0]["flu"], 0.01)
        self.assertNotIn("plague", result[0])
        self.assertNotIn("arsenic", result[1])
        self.assertAlmostEqual(result[0]["typhus"], 2.985)
        self.assertAlmostEqual(result[1]["lead"], 1.995)

    def test_shared_table_is_checked_again_after_disease_decay(self):
        old_shared = Table({"flu": 0.01})
        new_shared = Table({"flu": 0.01})
        old, old_calls = execute(BEFORE, old_shared, old_shared, None)
        new, new_calls = execute(AFTER, new_shared, new_shared, None)
        self.assertEqual(old, new)
        self.assertEqual(new_shared, {})
        self.assertIs(new[0], new[1])
        self.assertEqual((old_calls, new_calls), (2, 1))

    def test_invalid_values_use_original_path(self):
        for source in (BEFORE, AFTER):
            d, p = NonList(), NonList()
            _, count = execute(source, d, p, None)
            self.assertEqual((d.operations, p.operations, count), (1, 1, 2))

    def test_rest_of_handler_is_identical(self):
        before = source_adapter.extract(BEFORE, DECL)
        after = source_adapter.extract(AFTER, DECL)
        self.assertEqual(before[:before.index("\tvar/list/faded")].rstrip(),
                         after[:after.index("\tvar/list/faded")].rstrip())
        self.assertEqual(before[before.index("\tif (!fighting)"):].rstrip(),
                         after[after.index("\tif (!fighting)"):].rstrip())

    def test_guard_mutations_lose_decay(self):
        for guard in (DISEASE_GUARD, POISON_GUARD):
            self.assertEqual(AFTER.count(guard), 1)
            mutant = AFTER.replace(guard, "if (FALSE)", 1)
            expected, _ = execute(BEFORE, Table({"flu": 2}), Table({"lead": 2}), None)
            actual, _ = execute(mutant, Table({"flu": 2}), Table({"lead": 2}), None)
            self.assertNotEqual(expected, actual)


if __name__ == "__main__":
    unittest.main()
