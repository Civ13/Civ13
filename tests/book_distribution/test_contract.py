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
        before, after = p.split("do_after(src, RECIPE_COPY_TIME, paper)")
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
        self.assertIn("C.node_ids = recipe_compendium_wire_ids(entry[2])", region)
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
if __name__ == "__main__":
    unittest.main()
