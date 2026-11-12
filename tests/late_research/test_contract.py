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
class TeamsAndRushing(unittest.TestCase):
    def setUp(self):
        self.team = read("code/modules/research_tree/team_research.dm")
        self.nodes = read("code/modules/research_tree/research_node.dm")
        self.research = read("code/modules/research_tree/book_research.dm")
        self.interface = read("code/modules/research_tree/book_interface.dm")
    def test_included_after_the_define_it_uses(self):
        dme = read("civ13.dme")
        self.assertLess(dme.index('research_tree\\book_research.dm"'), dme.index('research_tree\\team_research.dm"'))
    def test_big_science_names_real_subjects_and_facilities(self):
        rows = re.findall(r'^\t"(\w+)" = list\("(\w+)", "(\w+)"\)', self.team, re.M)
        self.assertGreaterEqual(len(rows), 5)
        facilities = dict(re.findall(r'^\t"(\w+)" = list\("[^"]+", (/obj/structure/[\w/]+)\)', self.team, re.M))
        for node, _discipline, facility in rows:
            self.assertIn('research_node("%s", ' % node, self.nodes)
            self.assertIn(facility, facilities)
    def test_a_lone_scholar_is_slowed_not_stopped(self):
        rate = proc(self.team, "/obj/structure/research_bench/proc/team_rate")
        for part in ("N.era_tier < TEAM_MIN_TIER", "BIG_SCIENCE_SOLO_RATE", "BIG_SCIENCE_NO_FACILITY_RATE", "TEAM_SECOND_SCHOLAR_RATE"):
            self.assertIn(part, rate)
        solo = float(re.search(r"#define BIG_SCIENCE_SOLO_RATE ([\d.]+)", self.team)[1])
        facility = float(re.search(r"#define BIG_SCIENCE_NO_FACILITY_RATE ([\d.]+)", self.team)[1])
        self.assertGreater(solo * facility, 0)
        self.assertLessEqual(solo, 0.5)
    def test_the_lead_is_never_their_own_helper(self):
        for path in ("/obj/structure/research_bench/proc/big_science_assistant", "/obj/structure/research_bench/proc/second_scholar"):
            self.assertIn("H != lead", proc(self.team, path))
    def test_rushing_is_off_by_default_late_only_and_skill_lowers_the_risk(self):
        self.assertIn("var/rushed = FALSE", self.team)
        self.assertIn("rushed && node_can_be_rushed(N)", proc(self.team, "/obj/structure/research_bench/proc/rush_rate"))
        self.assertIn("N.era_tier >= TEAM_MIN_TIER", proc(self.team, "/proc/node_can_be_rushed"))
        self.assertIn("clamp(1 - margin / 40, 0.2, 1)", proc(self.team, "/proc/rush_accident_chance"))
        roll = proc(self.team, "/obj/structure/research_bench/proc/roll_rush_accident")
        self.assertLess(roll.index("!rushed"), roll.index("prob("))
        toggle = proc(self.team, "/obj/structure/research_bench/proc/book_toggle_rush")
        for guard in ("book_mode()", "H.stat != CONSCIOUS", "get_dist(H, src) > BOOK_RESEARCH_REACH"):
            self.assertIn(guard, toggle)
    def test_the_bench_tick_and_estimate_use_team_and_rush_rates(self):
        tick = proc(self.research, "/obj/structure/research_bench/proc/book_analysis_tick")
        for part in ("team_rate(assigned_node, researcher)", "rush_rate(N)", "roll_rush_accident(researcher, N, B, analysis_scale)"):
            self.assertIn(part, tick)
        panel = proc(self.interface, "/obj/structure/research_bench/proc/book_assigned_ui")
        for part in ("team_rate(assigned_node, researcher) * rush_rate(N)", "checks += team_rows(assigned_node, researcher)", 'out["rushed"]', 'out["can_rush"]'):
            self.assertIn(part, panel)
    def test_the_rush_button_reaches_the_bench(self):
        self.assertIn('href_list["toggle_rush"]', read("code/modules/research_tree/research_bench.dm"))
        self.assertIn('"toggle_rush"', read("code/modules/nano/tgui.dm"))
        self.assertIn('action="toggle_rush"', read("tgui/src/interfaces/Research.tsx"))
        self.assertIn("'toggle_rush'", read("UI/templates/research_bench.tmpl"))
class LateLines(unittest.TestCase):
    NEW = ("emergency_medicine", "soil_science", "crop_breeding", "support_weapons", "guided_weapons")
    def setUp(self):
        self.nodes = read("code/modules/research_tree/research_node.dm")
        self.recipes = read("config/crafting/material_recipes_global.txt")
    def test_the_new_subjects_are_registered_and_book_only(self):
        listed = re.search(r"book_only_research_nodes = list\((.*?)\)", self.nodes)[1]
        self.assertEqual(tuple(re.findall(r'"(\w+)"', listed)), self.NEW)
        for node_id in self.NEW:
            self.assertEqual(self.nodes.count('research_node("%s", ' % node_id), 1, node_id)
        self.assertIn("N.book_only && !(map && map.book_research_enabled())", proc(self.nodes, "/proc/research_node_dormant"))
    def test_dormant_subjects_are_never_done_listed_or_assigned(self):
        faction = read("code/modules/research_tree/research_faction.dm")
        self.assertIn("if (research_node_dormant(N))\n\t\treturn FALSE", proc(faction, "/obj/map_metadata/proc/is_node_done"))
        bench = read("code/modules/research_tree/research_bench.dm")
        self.assertIn("if (research_node_dormant(N))\n\t\t\tcontinue", proc(bench, "/obj/structure/research_bench/proc/bench_ui_data"))
        self.assertIn("research_node_dormant(N)", proc(bench, "/obj/structure/research_bench/proc/can_assign_node"))
    def test_every_new_recipe_row_is_gated_on_a_new_subject(self):
        rows = [line.split(",") for line in self.recipes.splitlines() if line.startswith("RECIPE: ")]
        gates = dict(re.findall(r'"(/[\w/]+)" = "(\w+)"', self.nodes))
        mine = {path: node for path, node in gates.items() if node in self.NEW}
        self.assertEqual(len(mine), 14)
        by_path = {row[2]: row for row in rows}
        for path in mine:
            self.assertIn(path, by_path, path)
            self.assertEqual(len(by_path[path]), 13, path)
        for node_id in ("emergency_medicine", "support_weapons", "guided_weapons"):
            self.assertIn(node_id, mine.values())
    def test_the_farming_subjects_reach_the_harvest(self):
        effects = read("code/modules/research_tree/node_effects.dm")
        self.assertIn('"crop_breeding"', proc(effects, "/proc/farming_node_bonus"))
        self.assertIn('mob_has_node_effect(user, "soil_science")', proc(effects, "/proc/soil_node_return"))
        farming = read("code/game/objects/farming.dm")
        self.assertIn("soil_node_return(user, get_turf(src))", farming)
        self.assertIn('note_field_work(user, "harvests", 1)', farming)
class Ciphers(unittest.TestCase):
    def setUp(self):
        self.cipher = read("code/modules/research_tree/book_cipher.dm")
        self.research = read("code/modules/research_tree/book_research.dm")
    def test_included_after_the_reading_helper_it_uses(self):
        dme = read("civ13.dme")
        self.assertLess(dme.index('research_tree\\book_interface.dm"'), dme.index('research_tree\\book_cipher.dm"'))
    def test_ciphers_bind_only_on_book_research_worlds(self):
        blocks = proc(self.cipher, "/obj/item/weapon/book/proc/cipher_blocks")
        for guard in ("is_enciphered()", "map.book_research_enabled()", "!can_read_cipher(H)"):
            self.assertIn(guard, blocks)
    def test_enciphering_needs_the_printing_press_a_pen_and_research(self):
        problem = proc(self.cipher, "/obj/item/weapon/book/proc/encipher_problem")
        for guard in ("map.book_research_enabled()", "can_hold_research()", "is_enciphered()", "research_chapter_list()", "H.knows_recipe_node(CIPHER_NODE)", "H.held_writing_pen()"):
            self.assertIn(guard, problem)
        self.assertIn('#define CIPHER_NODE "printing_currency"', self.cipher)
        commit = proc(self.cipher, "/obj/item/weapon/book/proc/encipher_commit")
        self.assertLess(commit.index("encipher_problem(H)"), commit.index("cipher_key = key"))
    def test_key_words_cannot_corrupt_the_saved_record(self):
        clean = proc(self.cipher, "/proc/clean_cipher_key")
        for guard in ('findtext(word, "|")', 'findtext(word, "=")', "CIPHER_KEY_MIN", "CIPHER_KEY_MAX"):
            self.assertIn(guard, clean)
    def test_every_way_of_taking_research_out_of_a_book_asks_the_cipher(self):
        study = proc(self.research, "/proc/study_research_source")
        self.assertLess(study.index("cipher_book.cipher_refuses(H)"), study.index("H.knows_recipe_node(node_id)"))
        copy = proc(self.research, "/obj/structure/research_bench/proc/book_copy_job")
        self.assertLess(copy.index("source.cipher_refuses(H) || dest.cipher_refuses(H)"), copy.index("do_reading("))
        rip = proc(read("code/modules/research_tree/book_pages.dm"), "/obj/item/weapon/book/proc/rip_page")
        self.assertLess(rip.index("cipher_refuses(H)"), rip.index("do_after("))
        self.assertIn("printed.copy_cipher_from(original)", read("code/modules/research_tree/book_printing.dm"))
    def test_breaking_needs_skill_and_a_pen_and_is_kept_with_the_book(self):
        problem = proc(self.cipher, "/obj/item/weapon/book/proc/break_problem")
        for guard in ("cipher_blocks(H)", "CIPHER_BREAK_SKILL", "H.held_writing_pen()"):
            self.assertIn(guard, problem)
        commit = proc(self.cipher, "/obj/item/weapon/book/proc/break_commit")
        self.assertLess(commit.index("break_problem(H)"), commit.index("add_cipher_reader(H)"))
        self.assertIn("cipher_progress = jointext(parts", commit)
        self.assertIn("clamp(writer / breaker, 0.5, 3)", proc(self.cipher, "/obj/item/weapon/book/proc/cipher_break_time"))
    def test_the_pen_menu_and_both_windows_reach_it(self):
        book = read("code/modules/1713/book.dm")
        self.assertIn('pen_choices += "Cipher"', book)
        self.assertIn("cipher_menu(user)", book)
        self.assertIn('data["cipher_note"]', read("code/modules/research_tree/book_interface.dm"))
        self.assertIn("data.cipher_note", read("tgui/src/interfaces/ResearchBook.tsx"))
        self.assertIn("data.cipher_note", read("UI/templates/research_book.tmpl"))
if __name__ == "__main__":
    unittest.main()
