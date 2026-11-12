"""Offline wiring for late research on book-research worlds.

Source checks only: the native fixture (run.py) executes the procs.
"""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")
def proc(text, path):
    m = re.search(r"^" + re.escape(path) + r"\([^\n]*\)\n(.*?)(?=^/|^#|\Z)", text, re.M | re.S)
    assert m, path
    return m[1]
class NodeEffects(unittest.TestCase):
    def setUp(self):
        self.effects = read("code/modules/research_tree/node_effects.dm")
        self.nodes = read("code/modules/research_tree/research_node.dm")
    def test_included(self):
        self.assertIn('research_tree\\node_effects.dm"', read("civ13.dme"))
    def test_every_effect_names_a_registered_node(self):
        block = re.search(r"research_node_effects = list\((.*?)\)\n", self.effects, re.S)[1]
        ids = re.findall(r'^\t"(\w+)" = "', block, re.M)
        self.assertGreaterEqual(len(ids), 6)
        for node_id in ids:
            self.assertIn('research_node("%s", ' % node_id, self.nodes)
    def test_effects_need_book_research_and_personal_knowledge(self):
        has = proc(self.effects, "/mob/living/human/proc/has_node_effect")
        for guard in ("map.book_research_enabled()", "node_id in research_node_effects", "!recipe_knowledge_exempt()", "knows_recipe_node(node_id)"):
            self.assertIn(guard, has)
        self.assertIn("map.book_research_enabled()", proc(self.effects, "/proc/research_node_effect_text"))
    def test_each_effect_is_wired_into_its_system(self):
        for path, call in (
                ("code/game/objects/items/stacks/stack.dm", "apply_crafting_node_effects(user, O)"),
                ("code/modules/1713/harvest_skills.dm", "farming_node_bonus(H)"),
                ("code/modules/surgery/surgery.dm", "surgery_node_quality(user)"),
                ("code/modules/surgery/surgery.dm", "surgery_node_time(user)"),
                ("code/game/mob/living/carbon/human/severe_disease.dm", "disease_node_scale()"),
                ("code/modules/1713/machinery/modular_vehicles/aircraft/aircraft.dm", "flight_fuel_node_scale(driver)")):
            self.assertIn(call, read(path), path)
        self.assertEqual(read("code/game/mob/living/carbon/human/severe_disease.dm").count("disease_node_scale()"), 2)
    def test_both_windows_show_the_effect(self):
        for path in ("code/modules/research_tree/book_interface.dm", "code/modules/research_tree/research_bench.dm"):
            self.assertIn('"effect" = research_node_effect_text(node_id)', read(path))
        for path, field in (("tgui/src/interfaces/Research.tsx", "detail.effect"), ("tgui/src/interfaces/ResearchBook.tsx", "row.effect"),
                            ("UI/templates/research_bench.tmpl", "node.effect"), ("UI/templates/research_book.tmpl", "chapter.effect")):
            self.assertIn(field, read(path))
if __name__ == "__main__":
    unittest.main()
