"""Offline checks for gun blueprint design codes (gun_design_code.dm)."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class GunBlueprintCodesTest(unittest.TestCase):
    def test_included_and_named(self):
        self.assertIn('#include "code\\modules\\1713\\gunsmithing\\gun_design_code.dm"', read('civ13.dme'))
        shared = read('code/modules/paintings/design_codes.dm')
        self.assertIn('if ("GUN")\n\t\t\treturn "a gun blueprint"', shared)

    def test_import_is_the_bench_flow(self):
        code = read('code/modules/1713/gunsmithing/gun_design_code.dm')
        body = code.split('/obj/structure/gunbench/proc/import_design_steps(', 1)[1]
        # Every part goes through the bench's own handler, which checks the
        # research band and the bench's stock, including when a code is pasted.
        self.assertIn('bench_action(H, act.Copy())', body)
        self.assertIn('bench_action(H, list("action" = "name", "name" = G["name"]))', body)
        self.assertIn('design_code_log(H, "gun blueprint"', body)
        self.assertIn('if (!can_design(H))', code)
        self.assertIn('design_code_ask(H, "Gunsmithing Bench"', code)
        bench = read('code/modules/1713/gunsmithing/gunsmith.dm')
        self.assertIn('"name", "import_code")', bench)
        self.assertIn('if (href_list["action"] == "import_code")', bench)
        self.assertIn('if (!istype(H) || importing)', bench)

    def test_calibers_have_one_table(self):
        bench = read('code/modules/1713/gunsmithing/gunsmith.dm')
        self.assertEqual(bench.count('/obj/item/ammo_casing/a792x57'), 1)
        self.assertEqual(bench.count('custom_gun_caliber(choice'), 2)


class GunBlueprintFeeTest(unittest.TestCase):
    BENCH = "code/modules/1713/gunsmithing/gunsmith.dm"
    SHOW = "/obj/structure/gunbench/proc/show_gunsmith_ui"
    GATE = "/obj/structure/gunbench/proc/can_design"
    ACTION = "/obj/structure/gunbench/proc/bench_action"
    NAME = '\tif (href_list["action"] == "name")'
    ALLOCATE = "\t\t// Create blueprint"

    def setUp(self):
        self.source = read(self.BENCH)
        spec = importlib.util.spec_from_file_location(
            "gunsmith_source_adapter", ROOT / "tests/save_movement/source_adapter.py")
        self.adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.adapter)
        self.adapter.FIELDS += ("ui_interact", "can_design", "importing", "current_gun",
                                "design_stage", "using_wood", "using_steel")

    @staticmethod
    def actor(skill=2.5, coin=None):
        return SimpleNamespace(getStatCoeff=lambda _skill: skill, l_hand=coin, r_hand=None)

    @staticmethod
    def environment():
        return dict(istype=lambda value, kind=None: hasattr(value, "getStatCoeff") if kind is None
                    else bool(getattr(value, "coin", False)), to_chat=lambda *_: None,
                    map=SimpleNamespace(civilizations=True))

    def project_show(self, source, human):
        opened = []
        bench = SimpleNamespace(ui_interact=opened.append, importing=False)
        source = source.replace("/obj/item/stack/money)", '"coin")')
        gate = self.adapter.project(source, self.GATE, "src, H", self.environment(), method=True)
        bench.can_design = lambda user: gate(bench, user)
        run = self.adapter.project(source, self.SHOW, "src, user", self.environment(), method=True)
        run(bench, human)
        return opened

    def project_to_blueprint(self, source, human, stage="name"):
        action = source.split(self.ACTION, 1)[1].split(self.ALLOCATE, 1)[0]
        branch = action[action.index(self.NAME):].replace("/obj/item/stack/money)", '"coin")')
        reached = []
        bench = SimpleNamespace(design_stage=lambda: stage, current_gun=SimpleNamespace(name="unnamed"))
        # Observe arrival at allocation; the native fixture covers actual output.
        run = self.adapter.project("/proc/try_finish(src, H, href_list)\n" + branch
                                   + "\t\treached.append(current_gun.name)\n", "/proc/try_finish",
                                   "src, H, href_list", dict(self.environment(), reached=reached,
                                    sanitize=lambda name, length: name[:length], qdel=lambda _obj: None),
                                   method=True)
        run(bench, human, {"action": "name", "name": "Example"})
        return reached

    def test_empty_hands_open_designer_and_skill_still_applies(self):
        human = self.actor()
        self.assertEqual(self.project_show(self.source, human), [human])
        self.assertEqual(self.project_show(self.source, self.actor(skill=2.49)), [])
        paywall = self.source.replace(
            'Use an existing blueprint.")\n\t\treturn FALSE\n',
            'Use an existing blueprint.")\n\t\treturn FALSE\n'
            '\tif (!istype(H.l_hand, /obj/item/stack/money))\n\t\treturn FALSE\n', 1)
        self.assertNotEqual(paywall, self.source)
        self.assertEqual(self.project_show(paywall, human), [])

    def test_finish_without_coins_or_spending_held_coins(self):
        self.assertEqual(self.project_to_blueprint(self.source, self.actor()), ["Example"])
        coins = SimpleNamespace(coin=True, value=10, amount=8)
        self.assertEqual(self.project_to_blueprint(self.source, self.actor(coin=coins)), ["Example"])
        self.assertEqual(coins.amount, 8)
        self.assertEqual(self.project_to_blueprint(self.source, self.actor(), stage="appearance"), [])
        paywall = self.source.replace(
            self.ALLOCATE, "\t\tif (!istype(H.l_hand, /obj/item/stack/money))\n\t\t\treturn\n"
            + self.ALLOCATE, 1)
        self.assertNotEqual(paywall, self.source)
        self.assertEqual(self.project_to_blueprint(paywall, self.actor()), [])

    def test_design_and_reuse_keep_cost_and_first_gun_output(self):
        action = self.source.split(self.ACTION, 1)[1].split("proc/assemble_from_blueprint", 1)[0]
        parts, finish = action.split(self.NAME, 1)
        for check in ('var/band = gunsmith_tech_band(H)', 'choice in design_options(step, band)',
                      'using_wood > wood_amt || using_steel > steel_amt'):
            self.assertIn(check, parts)
        tokens = ("var/obj/item/blueprint/gun/newgunbp = new/obj/item/blueprint/gun(loc)",
                  "newgunbp.cost_wood = using_wood", "newgunbp.cost_steel = using_steel",
                  "current_gun.finish()", "wood_amt -= using_wood", "steel_amt -= using_steel",
                  "NEWGUN.loc = get_turf(src)")
        positions = [finish.index(token) for token in tokens]
        self.assertEqual(positions, sorted(positions))
        assembly = self.source.split("proc/assemble_from_blueprint", 1)[1].split("\n/obj", 1)[0]
        for material in ("wood", "steel"):
            self.assertEqual(assembly.count(f"{material}_amt < bpsource.cost_{material}"), 2)
            self.assertIn(f"{material}_amt -= using_{material}", assembly)


if __name__ == '__main__':
    unittest.main()
