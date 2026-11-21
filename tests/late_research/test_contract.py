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
                ("code/game/mob/living/carbon/human/immunity.dm", "disease_node_scale()"),
                ("code/modules/1713/machinery/modular_vehicles/aircraft/aircraft.dm", "flight_fuel_node_scale(driver)")):
            self.assertIn(call, read(path), path)
        # Public Health scales every natural infection roll through one helper.
        self.assertEqual(read("code/game/mob/living/carbon/human/immunity.dm").count("disease_node_scale()"), 1)
        self.assertIn("infection_chance_scale(", read("code/game/mob/living/carbon/human/severe_disease.dm"))
    def test_both_windows_show_the_effect(self):
        for path in ("code/modules/research_tree/book_interface.dm", "code/modules/research_tree/research_bench.dm"):
            self.assertIn('"effect" = research_node_effect_text(node_id)', read(path))
        for path, field in (("tgui/src/interfaces/Research.tsx", "detail.effect"), ("tgui/src/interfaces/ResearchBook.tsx", "row.effect")):
            self.assertIn(field, read(path))
class FieldWork(unittest.TestCase):
    def setUp(self):
        self.field = read("code/modules/research_tree/field_work.dm")
        self.nodes = read("code/modules/research_tree/research_node.dm")
        self.research = read("code/modules/research_tree/book_research.dm")
        self.interface = read("code/modules/research_tree/book_interface.dm")
        self.scholarship = read("code/modules/research_tree/scholarship.dm")
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
            tier = re.search(r'research_node\("%s", "[^"]+", "\w+", \d+, \d+, \w+, (null|list\([^)]*\)), (\d+)' % node, self.nodes)
            self.assertTrue(tier, node)
            # Early rows are only for first nodes; the rest is practice (practice_work.dm).
            # Natural Science subjects also take mining, smelting, firing and
            # syntheses (natural_science_work.dm), at most 0.2 each.
            if int(tier[2]) < 5:
                if activity in ("mining", "smelting", "firing", "reactions"):
                    self.assertIn('"%s" = "natural_science"' % node, self.scholarship)
                    self.assertLessEqual(float(share), 0.2, node)
                else:
                    self.assertEqual(tier[1], "null", node)
                    self.assertIn(activity, ("forage", "butchering"), node)
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
                ("code/modules/space/survey.dm", 'note_field_work(H, "samples")'),
                ("code/modules/ecology/foraging.dm", 'note_field_work(src, "forage")'),
                ("code/modules/1713/animal_harvest.dm", 'note_field_work(H, "butchering")')):
            self.assertIn(call, read(path), path)
    def test_a_recorded_prototype_says_what_is_left(self):
        protos = read("code/modules/research_tree/subject_prototypes.dm")
        record = proc(protos, "/proc/record_subject_prototype")
        self.assertIn('The chapter is [written]% written.', record)
        self.assertIn('needs work at a research bench or other field work', record)
        self.assertIn('"protos_made" = prototype_progress(node_id)[1]', read("code/modules/research_tree/book_interface.dm"))

    def test_philosophy_grows_from_a_scholars_work(self):
        # On book-research worlds nothing raised Philosophy, which gates language and holy books.
        for path, call in (("code/modules/research_tree/book_research.dm", "H.philosophy_from_study(node_id)"),
                           ("code/modules/research_tree/book_research.dm", "tutor.philosophy_from_tutoring(node_id, H)"),
                           ("code/modules/research_tree/book_pages.dm", "H.philosophy_from_writing(node_id)"),
                           ("code/modules/research_tree/compare_notes.dm", "partner.philosophy_from_comparing(node_id, H)")):
            self.assertIn(call, read(path), path)
        doing = read("code/modules/research_tree/learning_by_doing.dm")
        self.assertIn('adaptStat("philosophy", amount, what)', doing)
        self.assertIn('if (!learning_by_doing_enabled() || amount <= 0 || stat == DEAD)', doing)

    def test_a_craft_that_counts_says_so_and_the_bench_names_its_speed(self):
        # Players made the wrong things for a subject and saw nothing happen.
        note = proc(self.field, "/proc/note_field_work")
        self.assertIn('findtext(activity, "craft:") == 1 || findtext(activity, "deed:") == 1', note)
        self.assertIn('That counts towards researching', note)
        self.assertIn('([after] of [E[FIELD_EXP_NEEDED]])', note)
        rows = proc(self.field, "/obj/structure/research_bench/proc/field_work_rows")
        self.assertIn('get_node_recipe_names(copytext(activity, 7))', rows)
        interface = read("code/modules/research_tree/book_interface.dm")
        self.assertIn('out["factors"] = book_pace_factors(N, researcher, worker[2], supply, library)', interface)
        shared = read("tgui/src/interfaces/researchShared.tsx")
        self.assertIn('<h3>Without waiting</h3>', shared)
        self.assertIn('<h3>Speed right now</h3>', shared)

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
        self.assertEqual(self.interface.count("late_bench_rate(N)"), 3)  # both pace estimates and the speed line
        self.assertIn("N.era_tier >= FIELD_WORK_MIN_TIER", proc(self.field, "/proc/late_bench_rate"))
    def test_windows_list_field_work(self):
        self.assertEqual(self.interface.count('out["field_work"] = field_work_rows(H, '), 2)
        self.assertIn("book_mode()", proc(self.field, "/obj/structure/research_bench/proc/field_work_rows"))
        self.assertEqual(read("tgui/src/interfaces/Research.tsx").count("<FieldWork rows="), 2)
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
        for part in ("N.era_tier < TEAM_MIN_TIER", "BIG_SCIENCE_SOLO_RATE", "BIG_SCIENCE_NO_FACILITY_RATE", "helper_bonus(node_id, lead)"):
            self.assertIn(part, rate)
        solo = float(re.search(r"#define BIG_SCIENCE_SOLO_RATE ([\d.]+)", self.team)[1])
        facility = float(re.search(r"#define BIG_SCIENCE_NO_FACILITY_RATE ([\d.]+)", self.team)[1])
        self.assertGreater(solo * facility, 0)
        self.assertLessEqual(solo, 0.5)
    def test_the_lead_is_never_their_own_helper(self):
        for path in ("/obj/structure/research_bench/proc/big_science_assistant", "/obj/structure/research_bench/proc/second_scholar"):
            self.assertIn("H != lead", proc(self.team, path))
        self.assertIn("H == lead || !H.can_research_node_at(src, node_id)", proc(self.team, "/obj/structure/research_bench/proc/research_helpers"))
    def test_the_lead_may_work_near_the_bench_but_helpers_stay_at_it(self):
        book = (ROOT / "code/modules/research_tree/book_research.dm").read_text(encoding="utf-8")
        shared = (ROOT / "code/__defines/research.dm").read_text(encoding="utf-8")
        self.assertIn("#define BOOK_RESEARCH_NEAR 3", shared)
        self.assertIn("#define BOOK_RESEARCH_AWAY_RATE 0.75", shared)
        self.assertIn("distance > (as_lead ? BOOK_RESEARCH_NEAR : BOOK_RESEARCH_REACH)", book)
        self.assertEqual(book.count("can_research_node_at(src, assigned_node, TRUE)"), 1)
        self.assertNotIn(", TRUE)", proc(self.team, "/obj/structure/research_bench/proc/research_helpers"))
    def test_helpers_count_in_every_age_and_cannot_more_than_double_the_pace(self):
        # Chat feedback, 2026-11-17: tribes asked why helping at the bench did nothing before the fifth age.
        share = float(re.search(r"#define TEAM_HELPER_SHARE ([\d.]+)", self.team)[1])
        helpers = int(re.search(r"#define TEAM_MAX_HELPERS (\d+)", self.team)[1])
        self.assertLessEqual(share * helpers, 1)
        self.assertIn("TEAM_HELPER_SHARE * min(1, helpers[H] / lead_pace)", proc(self.team, "/obj/structure/research_bench/proc/helper_bonus"))
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
        self.assertIn('"toggle_rush"', read("code/modules/research_tree/research_bench.dm").split("/obj/structure/research_bench/ui_actions(ui_key)", 1)[1].split("\n/", 1)[0])
        self.assertIn('action="toggle_rush"', read("tgui/src/interfaces/Research.tsx"))
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


class Practice(unittest.TestCase):
    """Early nodes advance by making what their prerequisites teach."""
    def setUp(self):
        self.practice = read("code/modules/research_tree/practice_work.dm")
    def test_included_in_the_build(self):
        self.assertIn('#include "code\\modules\\research_tree\\practice_work.dm"', read("civ13.dme"))
    def test_generated_only_for_early_nodes_and_counted_only_on_book_worlds(self):
        build = proc(self.practice, "/proc/build_practice_experiments")
        for guard in ("practice_experiments_built", "N.era_tier >= PRACTICE_BELOW_TIER", "N.prereqs.len", "field_activity_caps = null"):
            self.assertIn(guard, build)
        note = proc(self.practice, "/proc/note_craft_practice")
        for guard in ("map.book_research_enabled()", "get_recipe_node_req(result_path_string)", "note_field_work(user, practice_activity(node_id))"):
            self.assertIn(guard, note)
        field = read("code/modules/research_tree/field_work.dm")
        for name in ("/proc/field_activity_cap", "/proc/node_field_experiments"):
            self.assertIn("build_practice_experiments()", proc(field, name), name)
    def test_crafting_routes_count_practice(self):
        for path, count in (("code/game/objects/items/stacks/stack.dm", 1),
                            ("code/game/objects/structures/blacksmithing/blacksmithing.dm", 2),
                            ("code/game/objects/structures/blacksmithing/component_workbench.dm", 1),
                            ("code/game/objects/structures/blacksmithing/dedicated_workbenches.dm", 3)):
            self.assertEqual(read(path).count("note_craft_practice("), count, path)


class Demonstrations(unittest.TestCase):
    """Late capstones need a working demonstration on book-research worlds."""
    def setUp(self):
        self.demo = read("code/modules/research_tree/demonstrations.dm")
    def test_included_in_the_build(self):
        self.assertIn('#include "code\\modules\\research_tree\\demonstrations.dm"', read("civ13.dme"))
    def test_only_book_worlds_and_the_bench_refuses_parts(self):
        self.assertIn("map.book_research_enabled()", proc(self.demo, "/proc/node_demonstration"))
        attack = read("code/modules/research_tree/book_research.dm")
        self.assertIn("take_demonstration_notes(W, user)", attack)
        self.assertLess(attack.index("if (node_needs_demonstration(assigned_node))"), attack.index("if (B.research_prototype_installed(assigned_node))"))
    def test_experimental_builds_are_gated_and_marked(self):
        self.assertIn("|| demonstration_kit_allowed(H, result_path_string)", read("code/modules/research_tree/recipe_gates.dm"))
        self.assertIn('mark_experimental_build(H, O, "[recipe.result_type]")', read("code/game/objects/items/stacks/stack.dm"))
        self.assertIn('demonstration_kit_allowed(H, "[result_type]")', read("code/modules/1713/machinery/modern_generation.dm"))
        kit = proc(self.demo, "/proc/demonstration_kit_node")
        for guard in ("map.book_research_enabled()", "H.knows_research_prereqs(node_id)", "H.demonstration_book(node_id)"):
            self.assertIn(guard, kit)
    def test_recording_needs_a_pen_light_and_a_running_machine(self):
        record = proc(self.demo, "/mob/living/human/proc/record_demonstration")
        for guard in ("held_writing_pen()", "do_reading(src, DEMO_STEP, src)", "demonstration_machine_running(node_id, machine)", "demonstration_mishap(machine, node_id)", "commit_demonstration(src, carrier, node_id)"):
            self.assertIn(guard, record)
        self.assertLess(record.index("demonstration_mishap"), record.index("commit_demonstration(src"))


class SubjectPrototypes(unittest.TestCase):
    """Prototypes from a part-written chapter, and field study of existing things."""
    def setUp(self):
        self.src = read("code/modules/research_tree/subject_prototypes.dm")
    def test_included_and_wired(self):
        self.assertIn('#include "code\\modules\\research_tree\\subject_prototypes.dm"', read("civ13.dme"))
        self.assertIn("|| subject_prototype_allowed(H, result_path_string)", read("code/modules/research_tree/recipe_gates.dm"))
        self.assertIn("record_subject_prototype(user, result_path_string)", read("code/modules/research_tree/practice_work.dm"))
        self.assertIn("take_field_notes(W, user)", read("code/modules/research_tree/book_research.dm"))
    def test_gates(self):
        node = proc(self.src, "/proc/subject_prototype_node")
        for guard in ("map.book_research_enabled()", "H.knows_research_prereqs(node_id)", "H.prototype_book(node_id)"):
            self.assertIn(guard, node)
        self.assertIn("SUBJECT_PROTO_MAX", proc(self.src, "/mob/living/human/proc/prototype_book"))
        record = proc(self.src, "/proc/record_subject_prototype")
        self.assertLess(record.index("B.prototypes_made(node_id) >= SUBJECT_PROTO_MAX"), record.index("B.add_prototype_made(node_id)"))
    def test_working_from_a_book_is_slower_everywhere(self):
        mult = proc(self.src, "/proc/reference_build_mult")
        for guard in ("guided_work_node(H, result_path_string)", "subject_prototype_node(H, result_path_string)", "REFERENCE_SLOW_FLOOR"):
            self.assertIn(guard, mult)
        for path, count in (("code/game/objects/items/stacks/stack.dm", 1),
                            ("code/game/objects/structures/blacksmithing/blacksmithing.dm", 2),
                            ("code/game/objects/structures/blacksmithing/dedicated_workbenches.dm", 2),
                            ("code/game/objects/structures/blacksmithing/component_workbench.dm", 1),
                            ("code/modules/materials/lathes.dm", 1)):
            with self.subTest(path=path):
                self.assertEqual(read(path).count("reference_build_time(H, "), count)
        study = proc(self.src, "/mob/living/human/proc/study_in_field")
        for guard in ("held_writing_pen()", "do_reading(src, FIELD_STUDY_TIME, thing)", "commit_field_study(src, carrier, node_id, kind, thing.name)"):
            self.assertIn(guard, study)
    def test_a_refused_prototype_says_what_is_missing(self):
        refusal = proc(self.src, "/proc/subject_prototype_refusal")
        for reason in ("until you know", "already holds the whole", "a third of it written", "early pieces", "points of <b>[N.name]</b> needed"):
            self.assertIn(reason, refusal)
        self.assertIn("subject_prototype_refusal(H, result_path_string)", read("code/modules/research_tree/recipe_gates.dm"))
        self.assertIn('to_chat(user, crafting_recipe_refusal(H, "[recipe.result_type]"))', read("code/game/objects/items/stacks/stack.dm"))
        self.assertIn("subject_in_carried_book(user, node_req)", read("code/game/objects/items/stacks/civ_recipes.dm"))
    def test_white_fur_coats_are_furriery(self):
        nodes = read("code/modules/research_tree/research_node.dm")
        self.assertIn('"/obj/item/clothing/suit/storage/coat/fur/white" = "furriery"', nodes)
        self.assertIn('"/obj/item/clothing/suit/storage/coat/fur/white/wool" = "fine_garments"', nodes)
        self.assertNotIn("/material/woolcloth/,wool coat,/obj/item/clothing/suit/storage/coat/fur/white,", read("config/crafting/material_recipes_global.txt"))

class LearningByDoing(unittest.TestCase):
    def test_included_after_scholarship(self):
        dme = read("civ13.dme")
        self.assertLess(dme.index('research_tree\\scholarship.dm"'), dme.index('research_tree\\learning_by_doing.dm"'))
    def test_every_active_route_teaches_scholarship(self):
        for path, call in (("code/modules/research_tree/field_work.dm", 'H.gain_active_scholarship(assigned_node, points, "field:[id]")'),
                           ("code/modules/research_tree/subject_prototypes.dm", '"prototype:[node_id]:[B.prototypes_made(node_id)]")'),
                           ("code/modules/research_tree/subject_prototypes.dm", 'user.gain_active_scholarship(N.id, points, "study:[N.id]:[kind]")'),
                           ("code/modules/research_tree/subject_prototypes.dm", 'H.gain_active_scholarship(node_id, ., "study:[node_id]:[kind]")'),
                           ("code/modules/research_tree/demonstrations.dm", 'H.gain_active_scholarship(node_id, demonstration_lesson_points(N), "demonstration:[node_id]")'),
                           ("code/modules/research_tree/demonstrations.dm", 'user.gain_active_scholarship(N.id, demonstration_lesson_points(N), "demonstration:[N.id]")'),
                           ("code/modules/research_tree/book_research.dm", 'user.gain_active_scholarship(assigned_node, boost, "sample:[assigned_node]:[W.type]")')):
            with self.subTest(call=call):
                self.assertIn(call, read(path))
    def test_skill_gain_knows_what_was_done(self):
        stats = read("code/game/mob/living/carbon/human/human_stats.dm")
        self.assertIn("skill_variety_mult(statname, variety_key) * skill_master_mult(statname)", stats)
        self.assertEqual(read("code/game/objects/items/stacks/stack.dm").count('H.adaptStat("crafting", 1*recipe.req_amount, recipe.result_type)'), 3)
        self.assertIn('H.adaptStat("medical", 1.5*mod, S.type)', read("code/modules/surgery/surgery.dm"))
        self.assertIn('H.adaptStat("farming", 1, type)', read("code/game/objects/farming.dm"))
    def test_only_on_book_research_worlds(self):
        source = read("code/modules/research_tree/learning_by_doing.dm")
        for name in ("/mob/living/human/proc/gain_active_scholarship", "/mob/living/human/proc/skill_variety_mult", "/mob/living/human/proc/skill_master_nearby"):
            self.assertIn("learning_by_doing_enabled()", proc(source, name))
class TrialAndError(unittest.TestCase):
    def setUp(self):
        self.src = read("code/modules/research_tree/subject_prototypes.dm")
    def test_every_bench_and_menu_asks_before_handing_over_the_result(self):
        for path, call, count in (("code/game/objects/items/stacks/stack.dm", 'if (trial_craft_ruined(user, "[recipe.result_type]"))', 1),
                                  ("code/game/objects/structures/blacksmithing/blacksmithing.dm", 'if (!trial_craft_ruined(user, "[rtype]"))', 2),
                                  ("code/game/objects/structures/blacksmithing/dedicated_workbenches.dm", 'if (trial_craft_ruined(H, "[result_type]"))', 3),
                                  ("code/game/objects/structures/blacksmithing/component_workbench.dm", 'if (M && trial_craft_ruined(H, "[M.type]"))', 1)):
            with self.subTest(path=path):
                self.assertEqual(read(path).count(call), count)
    def test_materials_are_spent_before_the_attempt_is_judged(self):
        stack = read("code/game/objects/items/stacks/stack.dm")
        self.assertLess(stack.index("if (use(required, (joinery || carving) ? null : H))"), stack.index("trial_craft_ruined(user"))
        self.assertLess(stack.index("trial_craft_ruined(user"), stack.index("O = new recipe.result_type(build_loc, recipe.use_material)"))
    def test_gates(self):
        book = proc(self.src, "/mob/living/human/proc/prototype_book")
        for guard in ("B.trial_subject == node_id", "trial_count(node_id) < TRIAL_CHARACTER_MAX", "SUBJECT_PROTO_SHARE"):
            self.assertIn(guard, book)
        chance = proc(self.src, "/mob/living/human/proc/trial_success_chance")
        self.assertIn("if (share >= SUBJECT_PROTO_SHARE)\n\t\treturn 100", chance)
        failure = proc(self.src, "/proc/commit_trial_failure")
        for guard in ("lessons_learned(node_id) < TRIAL_LESSON_MAX", "gain_active_scholarship(", "/obj/item/trash/failed_attempt"):
            self.assertIn(guard, failure)
        self.assertIn("player_input(", proc(self.src, "/mob/living/human/proc/attempt_a_subject"))
class TradeLearning(unittest.TestCase):
    def setUp(self):
        self.src = read("code/modules/research_tree/trade_learning.dm")
    def test_included_and_wired(self):
        dme = read("civ13.dme")
        self.assertLess(dme.index('research_tree\\learning_by_doing.dm"'), dme.index('research_tree\\trade_learning.dm"'))
        self.assertIn("|| guided_work_allowed(H, result_path_string)", read("code/modules/research_tree/recipe_gates.dm"))
        practice = read("code/modules/research_tree/practice_work.dm")
        self.assertIn("if (!record_guided_work(user, result_path_string))\n\t\trecord_subject_prototype(user, result_path_string)", practice)
        self.assertIn("note_craft_watched(user, result_path_string)", practice)
        ruined = proc(read("code/modules/research_tree/subject_prototypes.dm"), "/proc/trial_craft_ruined")
        self.assertLess(ruined.index("guided_work_node(H, result_path_string)"), ruined.index("subject_prototype_node(H, result_path_string)"))
    def test_gates(self):
        learn = proc(self.src, "/mob/living/human/proc/can_learn_trade")
        for guard in ("map.book_research_enabled()", "knows_recipe_node(node_id)", "knows_research_prereqs(node_id)", "trade_learning_cap(N)"):
            self.assertIn(guard, learn)
        teacher = proc(self.src, "/mob/living/human/proc/trade_teacher")
        for guard in ("M.stat != CONSCIOUS", "M.research_presence()", "M.knows_recipe_node(node_id)"):
            self.assertIn(guard, teacher)
        watched = proc(self.src, "/proc/note_craft_watched")
        for guard in ("maker.knows_recipe_node(node_id)", "TRADE_WATCH_MAX", "watcher.can_learn_trade(node_id)"):
            self.assertIn(guard, watched)
        self.assertIn("learn_recipe_node(node_id)", proc(self.src, "/mob/living/human/proc/add_trade_learning"))
class CompareNotes(unittest.TestCase):
    def setUp(self):
        self.src = read("code/modules/research_tree/compare_notes.dm")
    def test_included_after_teams(self):
        dme = read("civ13.dme")
        self.assertLess(dme.index('research_tree\\team_research.dm"'), dme.index('research_tree\\compare_notes.dm"'))
    def test_gates(self):
        problem = proc(self.src, "/obj/structure/research_bench/proc/compare_notes_problem")
        for guard in ("comparable_subjects()", "cipher_refuses(H)", "research_lit()", "H.can_research_node_at(src, node_id)", "second_scholar(node_id, H)"):
            self.assertIn(guard, problem)
        subjects = proc(self.src, "/obj/structure/research_bench/proc/comparable_subjects")
        for guard in ("book_mode()", "A.has_compared(node_id) || B.has_compared(node_id)", "has_research_chapter(node_id)"):
            self.assertIn(guard, subjects)
        commit = proc(self.src, "/obj/structure/research_bench/proc/compare_notes_commit")
        self.assertIn("fuller.mark_compared(node_id)\n\tlesser.mark_compared(node_id)", commit)
        self.assertIn("player_input(", proc(self.src, "/obj/structure/research_bench/proc/compare_notes"))
    def test_first_samples_teach_more(self):
        research = read("code/modules/research_tree/book_research.dm")
        self.assertIn("#define BOOK_SAMPLE_FIRST_KINDS 2", research)
        self.assertIn("#define BOOK_SAMPLE_FIRST_FRACTION 0.2", research)
        self.assertIn("studied_samples.len <= BOOK_SAMPLE_FIRST_KINDS ? BOOK_SAMPLE_FIRST_FRACTION : RESEARCH_SAMPLE_BOOST_FRACTION", research)

class NaturalistFinds(unittest.TestCase):
    def setUp(self):
        self.src = read("code/modules/research_tree/naturalist_finds.dm")
    def test_included(self):
        self.assertIn('research_tree\\naturalist_finds.dm"', read("civ13.dme"))
    def test_limits(self):
        self.assertIn("#define FIND_POINTS 0.05", self.src)
        self.assertIn("#define FIND_CHAPTER_CAP 0.3", self.src)
        room = proc(self.src, "/obj/item/weapon/book/proc/find_room")
        for guard in ("has_research_chapter(node_id)", "has_find(kind)", "FIND_CHAPTER_CAP", "double ? 2 : 1"):
            self.assertIn(guard, room)
    def test_gates(self):
        subjects = proc(self.src, "/proc/find_subjects")
        for guard in ("map.book_research_enabled()", "node_discipline(node_id) != discipline", "H.knows_recipe_node(node_id) || !H.knows_research_prereqs(node_id)"):
            self.assertIn(guard, subjects)
        verb = proc(self.src, "/mob/living/human/proc/record_a_find")
        for guard in ("held_writing_pen()", "do_reading(", "player_input("):
            self.assertIn(guard, verb)
        self.assertIn('gain_active_scholarship(node_id, ., "find:[kind]")', proc(self.src, "/proc/commit_find"))
    def test_bench_takes_notes(self):
        self.assertIn("take_find_notes(W, user)", read("code/modules/research_tree/book_research.dm"))

class NaturalScienceWork(unittest.TestCase):
    def test_included(self):
        self.assertIn('research_tree\\natural_science_work.dm"', read("civ13.dme"))
    def test_hooks_count_when_the_fire_is_lit(self):
        self.assertIn("note_smelting(H, src)\n\t\tstart_smelt()", read("code/game/objects/structures/blacksmithing/refining.dm"))
        self.assertIn("note_smelting(H, src)", read("code/game/objects/structures/kitchen/stone_kiln_upgrade.dm"))
        self.assertIn('note_field_work(H, "smelting", iron_sand)', read("code/modules/1713/tatara.dm"))
        self.assertEqual(read("code/game/objects/structures/kitchen/oven.dm").count("note_firing(H, src)"), 3)
        self.assertIn('note_field_work(H, "mining")', read("code/game/turfs/floor_attackby.dm"))
    def test_place_finds_are_rechecked(self):
        finds = read("code/modules/research_tree/naturalist_finds.dm")
        record = finds[finds.index("/mob/living/human/proc/record_a_find("):]
        self.assertLess(record.index("find_place_still_here(src, kind)"), record.index("commit_find(src, carrier"))
        self.assertIn('"weather:[what]:[lowertext("[season]")]"', finds)

class SubjectDeeds(unittest.TestCase):
    def setUp(self):
        self.src = read("code/modules/research_tree/practice_work.dm")
    def test_deeds_replace_generated_practice(self):
        build = proc(self.src, "/proc/build_practice_experiments")
        self.assertLess(build.index("islist(subject_deeds[N.id])"), build.index("practice_items_needed(N)"))
        self.assertIn('field_experiments["deed_[N.id]_[D[1]]"]', build)
    def test_crafting_counts_deeds_first(self):
        note = proc(self.src, "/proc/note_craft_practice")
        self.assertLess(note.index("note_deed_work(user, result_path_string)"), note.index("get_recipe_node_req(result_path_string)"))
        self.assertIn('findtext(result_path_string, "[path]/") != 1', proc(self.src, "/proc/note_deed_work"))
    def test_subject_count(self):
        import re
        block = self.src[self.src.index("/proc/subject_deeds_table()"):self.src.index("var/global/list/deed_paths")]
        self.assertEqual(len(re.findall(r'^\t"\w+" = list\($', block, re.M)), 57)

class SkillMastery(unittest.TestCase):
    def setUp(self):
        self.src = read("code/modules/research_tree/learning_by_doing.dm")
    def test_hooked_into_skill_gain(self):
        stats = read("code/game/mob/living/carbon/human/human_stats.dm")
        adapt = proc(stats, "/mob/living/human/proc/adaptStat")
        self.assertIn("note_skill_mastery(statname)", adapt)
        self.assertLess(adapt.index("min(stats[statname][2], cap)"), adapt.index("note_skill_mastery(statname)"))
    def test_one_gain_stops_at_next_milestone(self):
        stats = read("code/game/mob/living/carbon/human/human_stats.dm")
        adapt = proc(stats, "/mob/living/human/proc/adaptStat")
        self.assertIn("skill_mastery_ceiling(statname, before_value)", adapt)
        self.assertLess(adapt.index("skill_mastery_ceiling(statname, before_value)"), adapt.index("note_skill_mastery(statname)"))
        ceiling = proc(self.src, "/mob/living/human/proc/skill_mastery_ceiling")
        self.assertIn("learning_by_doing_enabled()", ceiling)
    def test_crafting_gain_capped_per_action(self):
        stats = read("code/game/mob/living/carbon/human/human_stats.dm")
        adapt = proc(stats, "/mob/living/human/proc/adaptStat")
        self.assertIn("skill_gain_cap(statname)", adapt)
        self.assertLess(adapt.index("skill_variety_mult(statname, variety_key)"), adapt.index("skill_gain_cap(statname)"))
        cap = proc(self.src, "/mob/living/human/proc/skill_gain_cap")
        self.assertIn("learning_by_doing_enabled()", cap)
        self.assertIn("#define SKILL_CRAFTING_GAIN_CAP 10", self.src)
    def test_paid_once_per_discipline(self):
        note = proc(self.src, "/mob/living/human/proc/note_skill_mastery")
        for guard in ("learning_by_doing_enabled()", "skill_mastery_key(discipline, M[1])", "if (key in skill_mastery)", "SCHOLAR_MAX_LEVEL"):
            self.assertIn(guard, note)
        self.assertIn("list(250, 12, \"master\")", self.src)
    def test_saved_and_cleared_on_death(self):
        imp = proc(self.src, "/mob/living/human/persistence_import_fields")
        self.assertIn("skill_mastery = clean_skill_mastery(skill_mastery)", imp)
        self.assertIn("skill_mastery = list()", imp)

if __name__ == "__main__":
    unittest.main()
