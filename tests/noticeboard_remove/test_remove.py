"""Noticeboard source contracts; native UI probe is kept separately."""
from pathlib import Path
from types import SimpleNamespace
import importlib.util
import unittest

ROOT = Path(__file__).resolve().parents[2]
BOARD = ROOT / "code/game/objects/structures/noticeboard.dm"
PREFIX = "/obj/structure/noticeboard/"
TOPIC = PREFIX + "Topic(href, href_list)"
OLD_TOPIC = TOPIC + '''
	..()
	usr.set_using_object(src)
	if (href_list["remove"])
		if ((usr.stat || usr.restrained()))
			return
		var/obj/item/P = locate(href_list["remove"])
'''


def body(source, declaration):
    start = source.find(declaration)
    if start < 0:
        return ""
    return source[start:].split("\n/", 1)[0]


def removal_problems(source):
    topic = body(source, TOPIC)
    readable = body(source, PREFIX + "proc/noticeboard_can_read(")
    handling = body(source, PREFIX + "proc/noticeboard_can_handle(")
    remove = topic.split('if (href_list["remove"])', 1)[-1].split('if (href_list["read"])', 1)[0]
    problems = []
    if not topic.startswith(TOPIC + "\n\tif (..())\n\t\treturn"):
        problems.append("ignores the parent Topic denial")
    if not all(part in readable for part in ("isliving(user)", "user.Adjacent(src)")) or not all(
        part in handling for part in ("noticeboard_can_read(user)", "!user.stat", "!user.restrained()")
    ) or "if (!noticeboard_can_handle(user) || noticeboard_blocks_changes())" not in remove:
        problems.append("permits distant, incapacitated, or covered removal")
    return problems


class NoticeboardRemoveTest(unittest.TestCase):
    def setUp(self):
        self.source = BOARD.read_text(encoding="utf-8")

    def test_removal_needs_access_life_adjacency_and_an_open_board(self):
        self.assertEqual(removal_problems(self.source), [])
        branch = body(self.source, TOPIC).split('if (href_list["remove"])', 1)[1].split('if (href_list["read"])', 1)[0]
        self.assertIn('locate(href_list["remove"]) in src', branch)
        self.assertIn('!noticeboard_accepts(P) || P.loc != src', branch)
        self.assertLess(branch.index('!P.forceMove(T)'), branch.index('noticeboard_refresh()'))
        self.assertIn('QDELETED(P) || P.loc != T', branch)

    def test_negative_control_old_topic_fails(self):
        self.assertEqual(len(removal_problems(OLD_TOPIC)), 2)

    def test_negative_control_stale_remove_link_is_rejected_by_contract(self):
        changed = self.source.replace("if (!noticeboard_can_handle(user) || noticeboard_blocks_changes())",
                                      "if (!noticeboard_can_handle(user))", 1)
        self.assertEqual(len(removal_problems(changed)), 1)

    def test_read_through_glass_with_read_only_per_type_views(self):
        route = body(self.source, TOPIC).split('if (href_list["read"])', 1)[1]
        self.assertNotIn("noticeboard_blocks_changes()", route)
        self.assertIn("noticeboard_accepts(I) && I.loc == src", route)
        reader = body(self.source, PREFIX + "proc/noticeboard_read_post(")
        for part in ('P.show_document(user, FALSE, "noticeboard", src)', "P.show(user)", "M.read_map(user)"):
            self.assertIn(part, reader)
        self.assertNotIn("attack_self(", reader)
        self.assertNotIn('href_list["write"]', self.source)

    def test_stale_editors_cannot_mutate_posted_items(self):
        paperwork = ROOT / "code/modules/paperwork"
        legacy = body((paperwork / "view.dm").read_text(), "/proc/paper_document_legacy_edit_allowed(")
        canonical = body((paperwork / "document.dm").read_text(), "/datum/paper_document_service/proc/has_access(")
        for proc in (legacy, canonical):
            self.assertNotIn("/obj/structure/noticeboard", proc)
            self.assertTrue(proc.rstrip().endswith("return FALSE"))
        chart = (ROOT / "code/game/objects/items/cartography_notes.dm").read_text()
        self.assertIn("loc != user", body(chart, "/obj/item/weapon/cartography_map/proc/mark_problem("))

    def test_post_capacity_and_inventory_admission(self):
        pin = body(self.source, PREFIX + "attackby(")
        before = pin.index("if (noticeboard_blocks_changes())")
        self.assertLess(before, pin.index("H.transfer_held_item_to(W, src)"))
        self.assertIn("noticeboard_post_count() >= NOTICEBOARD_MAX_POSTS", pin)
        self.assertIn("W.loc != src", pin)
        self.assertNotIn("drop_from_inventory", pin)

    def test_matching_keys_and_smash_only_pane(self):
        pin = body(self.source, PREFIX + "attackby(")
        keys = pin.split("if (board_glass && board_lock", 1)[1].split("if (noticeboard_blocks_changes())", 1)[0]
        self.assertLess(keys.index("!board_lock.matching_key(W)"), keys.index("board_glass_closed = !board_glass_closed"))
        self.assertIn("!F.family || !F.key_taken || !F.code", pin)
        self.assertIn("if (!G.use(1))", pin)
        smash = body(self.source, PREFIX + "proc/noticeboard_shatter(")
        self.assertIn("board_glass = FALSE", smash)
        self.assertIn("board_glass_closed = FALSE", smash)
        for operation in ("board_lock =", "qdel(", "forceMove(", "contents.Cut("):
            self.assertNotIn(operation, smash)

    def test_projected_glaze_toggle_and_smash_keep_originals(self):
        adapter_path = ROOT / "tests/save_movement/source_adapter.py"
        spec = importlib.util.spec_from_file_location("noticeboard_adapter", adapter_path)
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        adapter.FIELDS += ("board_glass", "board_glass_closed", "board_lock", "add_fingerprint",
                           "noticeboard_refresh", "noticeboard_can_handle")

        def destroy(obj):
            obj.deleted = True

        env = {"to_chat": lambda *args: None, "playsound": lambda *args: None,
               "SPAN_NOTICE": str, "SPAN_WARNING": str, "qdel": destroy,
               "istype": lambda item, path: item.kind == path}
        attack = body(self.source, PREFIX + "attackby(")
        topic = body(self.source, TOPIC)
        glass_start = attack.index("\tif (istype(W, /obj/item/stack/material/glass))")
        fit_start = attack.index("\tif (istype(W, /obj/item/fitted_lock))")
        glass = attack[glass_start:fit_start].replace("/obj/item/stack/material/glass)", '"glass")')
        key_start = attack.index("\tif (board_glass && board_lock")
        gate = attack.index("\tif (noticeboard_blocks_changes())")
        keyed = attack[key_start:gate]
        for path, kind in (("/obj/item/weapon/key", "key"), ("/obj/item/weapon/storage/belt/keychain", "keys")):
            keyed = keyed.replace(path + ")", f'"{kind}")')
        # The report string cannot change state. Translate its DM ternary explicitly.
        report = 'SPAN_NOTICE(board_glass_closed ? "You lock the glass cover." : "You unlock and open the glass cover.")'
        self.assertEqual(keyed.count(report), 1)
        keyed = keyed.replace(report, 'SPAN_NOTICE("cover changed")')
        click = topic[topic.index('\tif (href_list["cover"])'):topic.index('\tif (href_list["remove"])')]
        glaze = adapter.project("/proc/apply_glass(src, H, W)\n" + glass, "/proc/apply_glass", "src, H, W", env, method=True)
        key = adapter.project("/proc/apply_key(src, H, W)\n" + keyed, "/proc/apply_key", "src, H, W", env, method=True)
        toggle = adapter.project("/proc/click_cover(src, user, href_list)\n" + click,
                                 "/proc/click_cover", "src, user, href_list", env, method=True)
        smash_path = PREFIX + "proc/noticeboard_shatter"
        smash = adapter.project(self.source, smash_path, "src, user", env, method=True)

        class Board:
            board_glass = board_glass_closed = False
            board_lock = None

            def __init__(self):
                self.contents = [SimpleNamespace(deleted=False), SimpleNamespace(deleted=False)]
                self.refresh_count = 0

            def noticeboard_refresh(self):
                self.refresh_count += 1

            def noticeboard_can_handle(self, user):
                return user.can_handle

            def add_fingerprint(self, user):
                pass

        class Glass:
            kind = "glass"

            def __init__(self, amount):
                self.amount = amount

            def use(self, amount):
                if amount > self.amount:
                    return False
                self.amount -= amount
                return True

        board = Board()
        posts = tuple(board.contents)
        actor = SimpleNamespace(can_handle=True, visible_message=lambda *args: None)
        glaze(board, actor, Glass(0))
        self.assertFalse(board.board_glass)
        stock = Glass(1)
        glaze(board, actor, stock)
        self.assertEqual(stock.amount, 0)
        self.assertTrue(board.board_glass)
        self.assertFalse(board.board_glass_closed)
        toggle(board, actor, {"cover": True})
        self.assertTrue(board.board_glass_closed)
        fitting = SimpleNamespace(matching_key=lambda item: item.cut == 17)
        board.board_lock = fitting
        before = board.refresh_count
        toggle(board, actor, {"cover": True})
        key(board, actor, SimpleNamespace(kind="key", cut=16))
        self.assertEqual(board.refresh_count, before)
        self.assertTrue(board.board_glass_closed)
        good_key = SimpleNamespace(kind="key", cut=17)
        key(board, actor, good_key)
        self.assertFalse(board.board_glass_closed)
        key(board, actor, good_key)
        self.assertTrue(board.board_glass_closed)
        smash(board, actor)
        self.assertEqual(len(board.contents), len(posts))
        for actual, original in zip(board.contents, posts):
            self.assertIs(actual, original)
        self.assertTrue(all(not item.deleted for item in posts))
        self.assertIs(board.board_lock, fitting)
        self.assertFalse(board.board_glass or board.board_glass_closed)

        # A targeted collateral-damage mutation is observable with the same fixture.
        mutated = self.source.replace("\tboard_glass = FALSE\n\tboard_glass_closed = FALSE",
                                      "\tqdel(contents[1])\n\tboard_glass = FALSE\n\tboard_glass_closed = FALSE", 1)
        bad_smash = adapter.project(mutated, smash_path, "src, user", env, method=True)
        board.board_glass = True
        bad_smash(board, actor)
        self.assertTrue(posts[1].deleted)

    def test_map_startup_and_restore_are_separate(self):
        init = body(self.source, PREFIX + "initialize(")
        load = body(self.source, PREFIX + "after_load(")
        self.assertIn("!restoring && isturf(loc)", init)
        self.assertIn("var/obj/item/weapon/paper/P in loc", init)
        self.assertIn("update_icon()", load)
        self.assertNotIn("initialize(", load)
        self.assertNotIn("var/notices", self.source)
        mount = body(self.source, PREFIX + "proc/noticeboard_mount(")
        self.assertIn("painting_is_wall_turf(get_step(T, facing))", mount)
        self.assertIn("B.board_mount_dir == facing", mount)

    def test_mapped_wall_offsets_count_as_mounted(self):
        init = body(self.source, PREFIX + "initialize(")
        mapper = init.split("!restoring && isturf(loc)", 1)[-1]
        for offset, facing in (("pixel_y == 32", "NORTH"), ("pixel_y == -32", "SOUTH"),
                               ("pixel_x == 32", "EAST"), ("pixel_x == -32", "WEST")):
            self.assertIn(offset, mapper)
            self.assertIn("board_mount_dir = " + facing, mapper)
        self.assertIn("if (!board_mount_dir)", mapper)


if __name__ == "__main__":
    unittest.main()
