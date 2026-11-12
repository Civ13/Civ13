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
class FieldWork(unittest.TestCase):
    def setUp(self):
        self.field = read("code/modules/research_tree/field_work.dm")
        self.nodes = read("code/modules/research_tree/research_node.dm")
        self.research = read("code/modules/research_tree/book_research.dm")
        self.interface = read("code/modules/research_tree/book_interface.dm")
    def experiments(self):
        return re.findall(r'^\t"(\w+)" = list\("(\w+)", "(\w+)", (\d+), ([\d.]+), "([^"]+)"\)', self.field, re.M)
    def test_included_after_the_define_it_uses(self):
        dme = read("civ13.dme")
        self.assertLess(dme.index('research_tree\\book_research.dm"'), dme.index('research_tree\\field_work.dm"'))
    def test_experiments_name_late_nodes_and_known_activities(self):
        activities = set(re.findall(r'^\t"(\w+)" = "[^"]+"[,)]', self.field.split("field_experiments")[0], re.M))
        rows = self.experiments()
        self.assertGreaterEqual(len(rows), 20)
        shares = {}
        for _id, node, activity, needed, share, _text in rows:
            tier = re.search(r'research_node\("%s", "[^"]+", "\w+", \d+, \d+, \w+, (?:null|list\([^)]*\)), (\d+)' % node, self.nodes)
            self.assertTrue(tier, node)
            self.assertGreaterEqual(int(tier[1]), 5, node)
            self.assertIn(activity, activities)
            self.assertGreater(int(needed), 0)
            shares[node] = shares.get(node, 0) + float(share)
        self.assertLessEqual(max(shares.values()), 0.7)
    def test_every_activity_is_counted_somewhere(self):
        for path, call in (
                ("code/modules/projectiles/guns/projectile.dm", 'note_field_work(user, "shots")'),
                ("code/modules/1713/machinery/modular_vehicles/aircraft/aircraft.dm", 'note_field_work(driver, "flight")'),
                ("code/modules/surgery/surgery.dm", 'note_field_work(user, "surgery")'),
                ("code/modules/1713/doctor_handbook.dm", "note_field_diagnosis(user, H)"),
                ("code/modules/reagents/laboratory.dm", 'note_field_work(user, "reactions")'),
                ("code/modules/space/survey.dm", 'note_field_work(H, "samples")')):
            self.assertIn(call, read(path), path)
    def test_counting_needs_book_research_and_is_capped(self):
        note = proc(self.field, "/proc/note_field_work")
        for guard in ("map.book_research_enabled()", "field_activity_cap(activity)", "before >= cap", "min(cap, before + amount)"):
            self.assertIn(guard, note)
    def test_a_book_takes_each_experiment_once(self):
        record = proc(self.field, "/obj/item/weapon/book/proc/record_field_work")
        for guard in ("has_field_work(experiment_id)", "has_research_chapter(", "add_research_work(N.id, points)"):
            self.assertIn(guard, record)
        self.assertLess(record.index("has_field_work(experiment_id)"), record.index("add_research_work"))
    def test_the_bench_credits_field_work_and_studies_late_nodes_faster(self):
        tick = proc(self.research, "/obj/structure/research_bench/proc/book_analysis_tick")
        self.assertLess(tick.index("research_lit()"), tick.index("credit_field_work()"))
        self.assertLess(tick.index("credit_field_work()"), tick.index("var/mob/living/human/researcher"))
        self.assertIn("late_bench_rate(N)", tick)
        self.assertEqual(self.interface.count("late_bench_rate(N)"), 2)
        self.assertIn("N.era_tier >= FIELD_WORK_MIN_TIER", proc(self.field, "/proc/late_bench_rate"))
    def test_windows_list_field_work(self):
        self.assertEqual(self.interface.count('out["field_work"] = field_work_rows(H, '), 2)
        self.assertIn("book_mode()", proc(self.field, "/obj/structure/research_bench/proc/field_work_rows"))
        self.assertEqual(read("tgui/src/interfaces/Research.tsx").count("<FieldWork rows="), 2)
        self.assertIn("node.field_work", read("UI/templates/research_bench.tmpl"))
if __name__ == "__main__":
    unittest.main()
