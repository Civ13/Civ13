"""Offline wiring and bounds for map copying, drawing and notes.

Not native gameplay evidence: it reads the production sources.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CARTOGRAPHY = "code/game/objects/items/cartography.dm"
NOTES = "code/game/objects/items/cartography_notes.dm"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


def proc(text, path):
    m = re.search(r"^" + re.escape(path) + r"\([^\n]*\)\n(.*?)(?=^/|\Z)", text, re.M | re.S)
    assert m, path
    return m[1]


def define(text, name):
    m = re.search(r"^#define " + name + r" (\d+)", text, re.M)
    assert m, name
    return int(m[1])


class MapCopyContract(unittest.TestCase):
    def setUp(self):
        self.map = read(CARTOGRAPHY)
        self.notes = read(NOTES)

    def saved_vars(self):
        block = re.search(r"^/obj/item/weapon/cartography_map\n(.*?)(?=^\S)", self.map, re.M | re.S)[1]
        names = re.findall(r"^\tvar/(?:list/)?(chart\w*)", block, re.M)
        names += re.findall(r"^/obj/item/weapon/cartography_map/var/(?:list/)?(\w+)", self.notes, re.M)
        return names

    def test_copy_is_faithful(self):
        names = self.saved_vars()
        for expected in ("chart", "chart_land", "chart_label", "chart_cell", "chart_cols", "chart_rows", "chart_ink", "chart_notes"):
            self.assertIn(expected, names)
        body = proc(self.notes, "/obj/item/weapon/cartography_map/proc/copy_map_into")
        for name in names:
            self.assertRegex(body, r"\bM\." + name + r" = ", name + " is not copied")
        self.assertIn("M.name = name", body)

    def test_same_time_as_books(self):
        book = read("code/modules/1713/book.dm")
        monk = proc(book, "/obj/item/weapon/book/attackby")
        self.assertIn("do_after(user, %d, src)" % define(self.notes, "MAP_HAND_COPY_TIME"), monk)
        printing = read("code/modules/research_tree/book_printing.dm")
        self.assertEqual(define(self.notes, "MAP_PRESS_COPY_TIME"), define(printing, "PRESS_PRINT_TIME"))

    def test_hand_copy_uses_a_blank_map_and_rechecks(self):
        self.assertIn("hand_copy_into(I, user)", proc(self.map, "/obj/item/weapon/cartography_map/attackby"))
        body = proc(self.notes, "/obj/item/weapon/cartography_map/proc/hand_copy_into")
        before, after = body.split("do_after(user, MAP_HAND_COPY_TIME, src)")
        for check in ("map_has_content()", "blank.map_copy_blank()", "cartography_copy_light(user)"):
            self.assertIn(check, before)
            self.assertIn(check, after)
        self.assertIn("blank.loc != user", after)
        self.assertIn("copy_map_into(blank)", after.split("return FALSE")[-1])

    def test_blank_rules(self):
        blank = proc(self.notes, "/obj/item/weapon/cartography_map/proc/map_copy_blank")
        self.assertIn("!map_has_content()", blank)
        content = proc(self.notes, "/obj/item/weapon/cartography_map/proc/map_has_content")
        for part in ("has_known_cells()", "chart_ink", "length(chart_notes)"):
            self.assertIn(part, content)
        # A rebuilt chart drops drawing made on the old grid.
        start = proc(self.map, "/obj/item/weapon/cartography_map/proc/start_chart")
        self.assertIn('chart_ink = ""', start)
        self.assertIn("chart_notes = null", start)

    def test_press_routes_maps(self):
        source = read("code/modules/1713/production.dm")
        attack = proc(source, "/obj/structure/printingpress/attackby")
        self.assertIn("istype(W, /obj/item/weapon/cartography_map))", attack)
        self.assertIn("return insert_press_book_or_map(W, user)", attack)
        insert = proc(source, "/obj/structure/printingpress/proc/insert_press_book_or_map")
        self.assertIn("M.map_has_content()", insert)
        self.assertIn("M.map_copy_blank()", insert)
        hand = proc(source, "/obj/structure/printingpress/attack_hand")
        self.assertLess(hand.index("print_map(H)"), hand.index("var/spawntimer"))
        run = proc(self.notes, "/obj/structure/printingpress/proc/print_map")
        self.assertIn("copying = FALSE", run)
        self.assertIn("base[1] != original || copy[1] != stock", run)
        finish = proc(self.notes, "/obj/structure/printingpress/proc/finish_map_print")
        self.assertIn("cartography_print_problem(original, stock)", finish)
        self.assertIn("original.copy_map_into(stock)", finish)
        self.assertNotIn("qdel(", finish)

    def test_drawing_input_is_bounded(self):
        ink = proc(self.notes, "/proc/cartography_ink_clean")
        self.assertIn("length(packed) > MAP_INK_PACKED_MAX", ink)
        self.assertIn("painting_unpack(packed, count)", ink)
        self.assertIn('regex("\\[^0-4\\]")', ink)
        note = proc(self.notes, "/proc/cartography_note_valid")
        for part in ('N["x"] > cols', 'N["y"] > rows', 'N["x"] != round(N["x"])'):
            self.assertIn(part, note)
        self.assertIn("length(chart_notes) >= MAP_NOTES_MAX", proc(self.notes, "/obj/item/weapon/cartography_map/proc/add_note"))
        topic = proc(self.notes, "/obj/item/weapon/cartography_map/Topic")
        self.assertLess(topic.index("mark_problem(user)"), topic.index("set_ink("))
        self.assertIn("sanitize(player_input(", topic)
        self.assertIn("!mark_problem(user) && add_note(", topic)
        problem = proc(self.notes, "/obj/item/weapon/cartography_map/proc/mark_problem")
        for part in ("loc != user", "drawing_tool(user)", "cartography_copy_light(user)"):
            self.assertIn(part, problem)

    def test_notes_are_escaped_in_the_reader(self):
        html = proc(self.notes, "/obj/item/weapon/cartography_map/proc/map_notes_html")
        self.assertIn('html_encode(N["t"])', html)
        js = proc(self.notes, "/obj/item/weapon/cartography_map/proc/map_marks_js")
        self.assertNotIn('N["t"]', js)

    def test_ships_and_vehicles_are_not_drawn(self):
        # Ships, built hulls and moving hulls are drawn as the sea or ground
        # under them, before any cover or turf of theirs is read.
        terrain = proc(self.map, "/proc/cartography_terrain")
        self.assertLess(terrain.index("cartography_craft_ground(T)"), terrain.index("for (var/obj/covers/C in T)"))
        ground = proc(self.map, "/proc/cartography_craft_ground")
        self.assertIn("vessel_at(T)", ground)
        self.assertIn('L.originals["[T.x],[T.y]"]', ground)
        self.assertIn("/datum/craft_body/built", ground)
        self.assertIn("TB.open_turf", ground)
        self.assertIn("return T.type", ground)

    def test_included(self):
        dme = read("civ13.dme")
        self.assertLess(dme.index("items\\cartography.dm"), dme.index("items\\cartography_notes.dm"))


if __name__ == "__main__":
    unittest.main()
