"""Source-derived offline traces. Python adapters are not native DM/save evidence."""
from copy import deepcopy
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODE = "code/modules/persistence/persistence.dm"
SETUP = "code/setup.dm"
LOAD = "code/modules/persistence/functions.dm"
SIGNATURE = "/obj/map_metadata/proc/apply_persistence_age_floor()"
CALL = "map.apply_persistence_age_floor()"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def proc(source, signature):
    match = re.search(r"^" + re.escape(signature) + r"\n(.*?)(?=^/|\Z)",
                      source, re.M | re.S)
    if not match:
        raise ValueError(f"Missing production proc {signature}")
    return match[1]


def uncomment(source):
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return "\n".join(line for line in source.splitlines()
                     if not line.lstrip().startswith("//"))


def translate(source):
    """Explicit vocabulary retains production ordering, branches and indentation.

    Numeric conversion/string interpolation are adapters for ordinary test years;
    native text2num formatting and runtime type semantics need BYOND acceptance.
    Unknown executable instructions fail closed.
    """
    vocabulary = {
        "if (!persistence)": "if not ctx.persistence:",
        'if (age != "5000 B.C." && age != "313 B.C.")':
            'if ctx.age != "5000 B.C." and ctx.age != "313 B.C.":',
        "if (!istext(age))": "if not isinstance(ctx.age, str):",
        "var/year = text2num(age)": "year = number(ctx.age)",
        'if (isnull(year) || "[year]" != age || year >= 1943)':
            'if year is None or str(year) != ctx.age or year >= 1943:',
        # Explicit defect variants used below, not arbitrary source evaluation.
        'if (isnull(year) || "[year]" != age || year > 1943)':
            'if year is None or str(year) != ctx.age or year > 1943:',
        'age = "1943"': 'ctx.age = "1943"',
        "ordinal_age = max(ordinal_age, 6)":
            "ctx.ordinal_age = max(ctx.ordinal_age, 6)",
        "ordinal_age = 6": "ctx.ordinal_age = 6",
        "return": "return",
    }
    vocabulary.update({f"age{i}_done = TRUE": f"ctx.age{i}_done = True"
                       for i in range(1, 7)})
    lines = ["def execute(ctx):"]
    for raw in proc(source, SIGNATURE).splitlines():
        instruction = raw.strip()
        if not instruction or instruction.startswith("//"):
            continue
        if instruction not in vocabulary:
            raise ValueError(f"Unsupported instruction {instruction}")
        depth = len(raw) - len(raw.lstrip("\t"))
        if depth < 1:
            raise ValueError("Expected tab indentation")
        lines.append("    " * depth + vocabulary[instruction])
    def number(value):
        try:
            return int(value)
        except ValueError:
            return None
    namespace = {"number": number}
    exec(compile("\n".join(lines), "<restricted floor translation>", "exec"), namespace)
    return namespace["execute"]


def state(age, ordinal=0, persistence=True):
    return SimpleNamespace(age=age, ordinal_age=ordinal, persistence=persistence,
                           default_research=181.25, custom_civs={"A": [40, 50, 60]},
                           faction_research={"A": ["bronze"]},
                           faction_baseline_era={"A": 1},
                           **{f"age{i}_done": i <= ordinal for i in range(1, 9)})


def wiring(mode, setup, load):
    admin = uncomment(proc(mode, "/datum/admins/proc/persistent()"))
    # The call must belong to the enable branch; disable/Chad+ never call it.
    assert admin.count(CALL) == 1
    assert "\tif (map && !map.persistence)\n\t\tmap.persistence = TRUE\n\t\t" + CALL in admin
    assert admin.index(CALL) < admin.index("\n\telse\n")
    assert CALL not in proc(mode, "/datum/admins/proc/persistent_chad()")
    setup = uncomment(setup)
    assert setup.count(CALL) == 1
    assert '\tif (config.allowedgamemodes == "PERSISTENCE")\n\t\tmap.persistence = TRUE\n\t\t' + CALL in setup
    restore = uncomment(proc(load, "/datum/controller/gameticker/proc/loadmap(datum/persistence_restart_transaction/transaction)"))
    assert restore.count(CALL) == 1
    assert restore.index("map_storage.load_map_metadata()") < restore.index("map_storage.restore_durable_world()") < restore.index(CALL) < restore.index("map_storage.restore_round_state(src, saved_round)")
    assert "\n\t\t" + CALL + "\n" in restore


class FloorTests(unittest.TestCase):
    def setUp(self):
        self.source = read(LOAD)
        self.apply = translate(self.source)

    def test_earlier_epochs_and_numeric_years(self):
        for age in ("5000 B.C.", "313 B.C.", "1013", "1713", "1873", "1903", "1942"):
            with self.subTest(age=age):
                ctx = state(age)
                before = deepcopy(vars(ctx))
                self.apply(ctx)
                self.assertEqual(ctx.age, "1943")
                self.assertEqual(ctx.ordinal_age, 6)
                for i in range(1, 7):
                    self.assertTrue(getattr(ctx, f"age{i}_done"))
                for key in ("default_research", "custom_civs", "faction_research", "faction_baseline_era", "age7_done", "age8_done"):
                    self.assertEqual(vars(ctx)[key], before[key])

    def test_equal_later_and_unknown_dates_are_unchanged(self):
        for age in ("1943", "1944", "1969", "2013", "2023", "2050", "unknown", "Stone Age", "1942 A.D.", None):
            with self.subTest(age=age):
                ctx = state(age, ordinal=3)
                before = deepcopy(vars(ctx))
                self.apply(ctx)
                self.assertEqual(vars(ctx), before)

    def test_repeat_and_independently_advanced_research(self):
        ctx = state("1903", ordinal=8)
        self.apply(ctx)
        self.assertEqual(ctx.ordinal_age, 8)
        before = deepcopy(vars(ctx))
        self.apply(ctx)
        self.assertEqual(vars(ctx), before)

    def test_unrelated_modes_do_not_change_even_earlier_dates(self):
        for age in ("5000 B.C.", "1903", "1943", "2023"):
            ctx = state(age, persistence=False)
            before = deepcopy(vars(ctx))
            self.apply(ctx)
            self.assertEqual(vars(ctx), before)

    def test_activation_startup_and_completed_restore_wiring(self):
        wiring(read(MODE), read(SETUP), self.source)
        self.assertEqual(sum(read(p).count(CALL) for p in (MODE, SETUP, LOAD)), 3)

    def test_minimal_save_fixture_includes_the_real_helper(self):
        environment = read("tests/world_save/roundtrip.dme")
        self.assertIn('#include "../../code/modules/persistence/functions.dm"', environment)
        self.assertIn(SIGNATURE, read(LOAD))
        self.assertNotIn(SIGNATURE, read(MODE))
        stubs = read("tests/world_save/stubs.dm")
        for field in ("age", "ordinal_age", "persistence", *(f"age{i}_done" for i in range(1, 7))):
            self.assertRegex(stubs, r"\bvar/" + field + r"\b")

    def test_save_contract_and_restore_adapters(self):
        saving = read("code/modules/persistence/saving.dm")
        loading = read("code/modules/persistence/loading.dm")
        schema = read("code/modules/persistence/durable_contract.dm")
        self.assertIn('list(map.ID, "[map.age]", "[map.ordinal_age]"', saving)
        self.assertIn("map.age = meta[2]", loading)
        self.assertIn("map.ordinal_age = text2num(meta[3])", loading)
        self.assertIn('"age", "gamemode"', schema)
        self.assertIn('"ordinal_age", "default_research"', schema)
        self.assertNotIn(CALL, loading)  # durable restoration has not finished yet
        self.assertNotIn(CALL, saving)  # save must not mutate the world
        for persistent in (False, True):
            for age in ("1903", "1943", "2023"):
                for durable in (False, True):
                    with self.subTest(persistent=persistent, age=age, durable=durable):
                        original = state(age, ordinal=8, persistence=persistent)
                        saved = deepcopy(vars(original))
                        # Fresh configured startup is earlier than loading.
                        restored = state("5000 B.C.")
                        self.apply(restored)
                        # Legacy text header, followed by optional v2 fields.
                        restored.age = saved["age"]
                        restored.ordinal_age = saved["ordinal_age"]
                        restored.persistence = saved["persistence"]
                        if durable:
                            vars(restored).update(deepcopy(saved))
                        self.apply(restored)
                        self.assertEqual(restored.age, "1943" if persistent and age == "1903" else age)
                        self.assertEqual(restored.ordinal_age, 8)
                        self.assertEqual(restored.default_research, saved["default_research"])
                        after = deepcopy(vars(restored))
                        self.apply(restored)
                        self.assertEqual(vars(restored), after)

    def test_controls_detect_reset_equal_tier_and_missing_paths(self):
        equal = translate(self.source.replace("year >= 1943", "year > 1943"))
        ctx = state("1943", ordinal=0)
        before = deepcopy(vars(ctx))
        equal(ctx)
        self.assertNotEqual(vars(ctx), before)
        reset = translate(self.source.replace("max(ordinal_age, 6)", "6"))
        ctx = state("1903", ordinal=8)
        reset(ctx)
        self.assertNotEqual(ctx.ordinal_age, 8)
        for path in (MODE, SETUP, LOAD):
            sources = {p: read(p) for p in (MODE, SETUP, LOAD)}
            sources[path] = sources[path].replace(CALL, "", 1)
            with self.subTest(path=path), self.assertRaises(AssertionError):
                wiring(sources[MODE], sources[SETUP], sources[LOAD])


if __name__ == "__main__":
    unittest.main()
