"""Offline checks for gun blueprint design codes (gun_design_code.dm)."""
from pathlib import Path
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
        # research band, the bench's stock and (for the name) the coins.
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


if __name__ == '__main__':
    unittest.main()
