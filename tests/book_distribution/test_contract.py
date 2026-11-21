"""Offline wiring and bounds, not native gameplay evidence."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")
def proc(text, path):
    m = re.search(r"^" + re.escape(path) + r"\([^\n]*\)\n(.*?)(?=^/|\Z)", text, re.M|re.S)
    assert m, path
    return m[1]
class DistributionContract(unittest.TestCase):
    def setUp(self):
        self.source = read("code/modules/research_tree/book_distribution.dm")
    def test_copy_revalidates_payment_and_knowledge(self):
        p = proc(self.source, "/mob/living/human/proc/copy_recipe_manual")
        before, after = p.split("do_reading(src, RECIPE_COPY_TIME, paper)")
        for field in ("knows_recipe_node(id)", "can_learn_recipe_node(id)", "recipe_held(src, P)", "recipe_held(src, paper)", "recipe_blank_paper(paper)"):
            self.assertIn(field, before)
            self.assertIn(field, after)
        self.assertIn("qdel(paper)", after)
        self.assertNotIn("qdel(P)", after)
        self.assertIn("isnull(P.document_record)", self.source)
    def test_press_routes_before_generic_copy(self):
        p = proc(read("code/modules/1713/production.dm"), "/obj/structure/printingpress/attackby")
        self.assertLess(p.index("print_recipe_manual"), p.index("insert_copy_paper"))
        self.assertIn("node_compendium", p)
        print_body = proc(self.source, "/obj/structure/printingpress/proc/print_recipe_manual")
        self.assertIn("copying = FALSE", print_body)
        self.assertIn("B.node_id != id", print_body)
        self.assertNotIn("qdel(B)", print_body)
    def test_teaching_rechecks_both_participants(self):
        p = proc(self.source, "/mob/living/human/proc/teach_recipe_node")
        for text in ("student.client != student_session", "get_turf(student) != student_place", "get_turf(src) != teacher_place", "recipe_teaching_valid(src, student, id)", "student.learn_recipe_node(id)"):
            self.assertIn(text, p)
        self.assertIn('"Learn", "Decline"', self.source)
    def test_compendium_bounds_and_restore(self):
        self.assertIn("#define RECIPE_COMPENDIUM_MAX 16", self.source)
        restore = proc(self.source, "/obj/item/weapon/book/node_compendium/after_load")
        self.assertIn("clean_recipe_node_ids(node_ids)", restore)
        self.assertIn("node_ids.Cut(RECIPE_COMPENDIUM_MAX + 1)", restore)
        self.assertIn("length(kind) > 2048", self.source)
        region = read("code/modules/persistence/region_travel.dm")
        # A traveller's compendium is rebuilt by the shared item maker.
        self.assertIn("C.node_ids = recipe_compendium_wire_ids(kind)", region)
        self.assertIn("return region_travel_make_item(kind, amount, T)", read("code/modules/persistence/region_travel_gear.dm"))
    def test_cache_is_bounded_and_not_placed(self):
        p = proc(self.source, "/obj/structure/recipe_book_cache/proc/claim_manual")
        self.assertIn("if(restock_remaining > 0) return null", p)
        self.assertIn("N.era_tier <= map.ordinal_age", p)
        self.assertIn("N.era_tier == 0", p)
        self.assertEqual(p.count("create_node_book("), 1)
        self.assertNotIn("spawn(", self.source)
        self.assertIn('key == "restock_checked_at" || ..()', self.source)
        for path in (ROOT / "maps").rglob("*.dmm"):
            self.assertNotIn("/recipe_book_cache", path.read_text(errors="replace"))
    def test_shop_uses_existing_bounded_stock(self):
        s = read("code/game/objects/structures/vending/specialist_traders.dm")
        self.assertIn("H.can_learn_recipe_node(initial(B.node_id))", s)
        for name in ("basic_tools", "primitive_construction", "pottery_storage"):
            self.assertIn(f"list(/obj/item/weapon/book/node_book/{name}, 1, 0, 9, 2, 3)", s)
        self.assertIn("!map.recipe_knowledge_enabled()", s)
    def test_manuals_take_notes_but_not_chapters(self):
        book = read("code/modules/1713/book.dm")
        attack = proc(book, "/obj/item/weapon/book/attackby")
        self.assertIn("if (!can_hold_notes())", attack)
        self.assertIn("can_hold_notes() && ishuman(user)", attack)
        self.assertNotIn("if (unique)\n\t\t\tto_chat", attack)
        knowledge = read("code/modules/research_tree/character_knowledge.dm")
        self.assertIn("return TRUE", proc(knowledge, "/obj/item/weapon/book/node_book/can_hold_notes"))
        self.assertIn("return TRUE", proc(self.source, "/obj/item/weapon/book/node_compendium/can_hold_notes"))
        self.assertIn("offer_notes_reading(user,", proc(knowledge, "/obj/item/weapon/book/node_book/attack_self"))
        self.assertIn("offer_notes_reading(user,", proc(self.source, "/obj/item/weapon/book/node_compendium/attack_self"))
        pages = read("code/modules/research_tree/book_pages.dm")
        self.assertIn("!can_hold_research()", proc(pages, "/obj/item/weapon/book/proc/reinsert_page"))
        travel = read("code/modules/persistence/region_travel.dm")
        kind = proc(travel, "/proc/region_travel_item_kind")
        self.assertIn("!C.dat", kind)
        self.assertIn("!B.dat", kind)
    def test_press_prints_whole_books_for_paper(self):
        press = proc(read("code/modules/1713/production.dm"), "/obj/structure/printingpress/attackby")
        self.assertLess(press.index("print_recipe_manual"), press.index("load_printing_sheet"))
        self.assertLess(press.index("load_printing_sheet"), press.index("insert_copy_paper"))
        self.assertIn("press_prints_whole_book(base[1])", read("code/modules/1713/production.dm"))
        printing = read("code/modules/research_tree/book_printing.dm")
        finish = proc(printing, "/obj/structure/printingpress/proc/finish_whole_book_print")
        self.assertIn("whole_book_print_problem(original, stock)", finish)
        self.assertIn("printing_sheets -= chapters.len", finish)
        self.assertNotIn("research_progress", finish)
        problem = proc(printing, "/obj/structure/printingpress/proc/whole_book_print_problem")
        self.assertIn("stock.monk_copy_blank()", problem)
        self.assertIn("printing_sheets < needed", problem)
    def test_press_rechecks_slot_admission_after_prompt_and_before_transfer(self):
        source = read("code/modules/1713/production.dm")
        body = proc(source, "/obj/structure/printingpress/proc/insert_press_book_or_map")
        before, after = body.split("var/choice = WWinput", 1)
        for guard in ("copying", "paper_document_copy_actor_valid", "user.get_active_hand() != document"):
            self.assertIn(guard, before)
            self.assertIn(guard, after.split("slot += document", 1)[0])
        self.assertLess(after.index("if (slot.len)"), after.index("slot += document"))
        self.assertLess(after.index("B.monk_copy_blank()"), after.index("slot += document"))
        self.assertLess(after.index("slot += document"), after.index("user.transfer_held_item_to"))
        self.assertNotIn("locate(0,0,0)", body)
        self.assertIn("slot -= document", after.split("user.transfer_held_item_to", 1)[1])

    def test_press_can_unload_both_slots_and_reset_after_save(self):
        source = read("code/modules/1713/production.dm")
        unload = proc(source, "/obj/structure/printingpress/verb/unload_printing_press")
        self.assertIn("copying || !paper_document_copy_actor_valid", unload)
        self.assertIn("eject_press_documents(get_turf(src), usr)", unload)
        restore = proc(source, "/obj/structure/printingpress/after_load")
        self.assertIn("copying = FALSE", restore)
        self.assertIn('icon_state = "printingpress0"', restore)
        runtime = proc(source, "/obj/structure/printingpress/persistence_runtime_var")
        self.assertIn('key == "copying" || ..()', runtime)
        paper = read("code/modules/paperwork/copy.dm")
        destroy = proc(paper, "/obj/structure/printingpress/Destroy")
        self.assertLess(destroy.index("eject_press_documents"), destroy.index("return ..()"))
        self.assertLess(destroy.index("refund_printing_sheets"), destroy.index("return ..()"))
        book = read("code/modules/research_tree/book_printing.dm")
        self.assertNotIn("/obj/structure/printingpress/Destroy()", book)
        refund = proc(book, "/obj/structure/printingpress/proc/refund_printing_sheets")
        self.assertIn("i <= printing_sheets", refund)
        self.assertIn("new /obj/item/weapon/paper(place)", refund)
        self.assertIn("printing_sheets = 0", refund)

    def test_press_does_not_erase_original_legacy_research(self):
        source = read("code/modules/1713/production.dm")
        body = proc(source, "/obj/structure/printingpress/attack_hand")
        legacy = body.split("var/obj/item/weapon/book/research/NC = B", 1)[1]
        legacy = legacy.split("else if (istype(B, /obj/item/weapon/book/language_book))", 1)[0]
        self.assertIn("NB.completed = 0", legacy)
        self.assertIn('NB.k_class = "none"', legacy)
        self.assertNotRegex(legacy, r"NC\.(completed|k_class|k_level|styleb)\s*=")

    def test_whole_book_and_map_check_custody_before_copying(self):
        for file, finish, side_effect in (
            ("code/modules/research_tree/book_printing.dm", "finish_whole_book_print", "new /obj/item/weapon/book"),
            ("code/game/objects/items/cartography_notes.dm", "finish_map_print", "original.copy_map_into(stock)"),
        ):
            with self.subTest(finish=finish):
                body = proc(read(file), "/obj/structure/printingpress/proc/" + finish)
                self.assertLess(body.index("!press_retains_document(original) || !press_retains_document(stock)"),
                                body.index(side_effect))
if __name__ == "__main__":
    unittest.main()
