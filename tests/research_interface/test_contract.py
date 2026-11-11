"""Offline wiring and bounds for the research bench screen and book window.

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
class ResearchInterfaceContract(unittest.TestCase):
    def setUp(self):
        self.interface = read("code/modules/research_tree/book_interface.dm")
        self.research = read("code/modules/research_tree/book_research.dm")
        self.pages = read("code/modules/research_tree/book_pages.dm")
        self.bench = read("code/modules/research_tree/research_bench.dm")
    def test_included_after_the_files_whose_defines_it_uses(self):
        dme = read("civ13.dme")
        order = [dme.index('research_tree\\%s.dm"' % name) for name in ("book_pages", "book_research", "book_interface")]
        self.assertEqual(order, sorted(order))
    def test_one_click_copy_keeps_every_cost_and_recheck(self):
        job = proc(self.research, "/obj/structure/research_bench/proc/book_copy_job")
        before, after = job.split("do_after(H, time, src)")
        for guard in ("source.loc != src", "dest.loc != src", "source.has_research_chapter(node_id)", "dest.has_research_chapter(node_id)",
                      "H.held_writing_pen()", "blank_writing_sheet(sheet)", "BOOK_WRITE_STAMINA(N.era_tier)", "dest.page_busy"):
            self.assertIn(guard, before)
        for guard in ("source.loc != src", "dest.loc != src", "recipe_held(H, sheet)", "recipe_held(H, pen)", "copy_chapter_commit(H, source, dest, node_id, sheet)"):
            self.assertIn(guard, after)
        self.assertLess(job.index("dest.page_busy = TRUE"), job.index("do_after(H, time, src)"))
        self.assertLess(job.index("do_after(H, time, src)"), job.index("dest.page_busy = FALSE"))
        commit = proc(self.research, "/obj/structure/research_bench/proc/copy_chapter_commit")
        for cost in ('H.stats["stamina"][1] -= cost', "qdel(sheet)"):
            self.assertIn(cost, commit)
        # The menu and the buttons share the one timed job.
        self.assertIn("return book_copy_job(H, job[1], job[2], job[3])", proc(self.research, "/obj/structure/research_bench/proc/book_copy_chapter"))
        self.assertIn("return book_copy_job(H, pair[1], pair[2], node_id)", proc(self.interface, "/obj/structure/research_bench/proc/book_copy_node"))
    def test_copy_all_stops_when_a_copy_fails_or_the_scribe_leaves(self):
        loop = proc(self.interface, "/obj/structure/research_bench/proc/book_copy_all")
        self.assertIn("source_index != 1 && source_index != 2", loop)
        for stop in ("source.loc != src || dest.loc != src || !in_range(src, H) || H.incapacitated()", "if (!book_copy_job(H, source, dest, node_id))\n\t\t\tbreak"):
            self.assertIn(stop, loop)
    def test_writing_a_chosen_chapter_still_needs_knowledge_pen_sheet_and_stamina(self):
        write = proc(self.pages, "/obj/item/weapon/book/proc/write_research_chapter")
        self.assertIn("!H.knows_recipe_node(node_id) || has_research_chapter(node_id) || page_busy", write)
        after = write.split("do_after(H, time, anchor ? anchor : src)")[1]
        for guard in ("has_research_chapter(node_id)", "!H.knows_recipe_node(node_id)", "!recipe_held(H, P)", "!recipe_held(H, sheet)", "!blank_writing_sheet(sheet)",
                      "loc != start_loc", "!H.Adjacent(anchor)", "commit_written_chapter(H, node_id, sheet)"):
            self.assertIn(guard, after)
        bench_write = proc(self.interface, "/obj/structure/research_bench/proc/book_write_node")
        self.assertIn("!H.knows_recipe_node(node_id)", bench_write)
        self.assertIn("dest.write_research_chapter(H, pen, node_id, src)", bench_write)
    def test_blank_sheet_helper_only_hands_over_blank_sheets_the_writer_carries(self):
        ready = proc(self.interface, "/mob/living/human/proc/ready_blank_sheet")
        self.assertEqual(ready.count("blank_writing_sheet(P)"), 2)
        self.assertIn("if (l_hand && r_hand)\n\t\treturn null", ready)
        self.assertIn("in get_contents()", ready)
        self.assertIn("recipe_held(src, P)", ready)
    def test_queue_is_bounded_and_never_interrupts_unfinished_work(self):
        self.assertIn("#define BOOK_QUEUE_MAX 12", self.interface)
        advance = proc(self.interface, "/obj/structure/research_bench/proc/book_advance_queue")
        self.assertLess(advance.index("!B.has_research_chapter(assigned_node)"), advance.index("assigned_node = started"))
        self.assertIn("book_can_assign_node(node_id)", advance)
        queue = proc(self.interface, "/obj/structure/research_bench/proc/book_queue_node")
        for guard in ("N.mode == RESEARCH_MODE_BOOK", "B.has_research_chapter(node_id)", "node_id == assigned_node", "node_id in q", "q.len >= BOOK_QUEUE_MAX"):
            self.assertIn(guard, queue)
        tick = proc(self.research, "/obj/structure/research_bench/proc/book_analysis_tick")
        self.assertLess(tick.index("book_advance_queue()"), tick.index("if (!B || !assigned_node)"))
    def test_screen_data_is_read_only(self):
        for name in ("/obj/structure/research_bench/proc/book_node_ui", "/obj/structure/research_bench/proc/book_assigned_ui",
                     "/obj/structure/research_bench/proc/book_row_ui", "/proc/book_viewer_ui", "/obj/item/weapon/book/proc/research_book_ui_data"):
            body = proc(self.interface, name)
            for writer in ("learn_recipe_node", "add_research_", "gain_scholarship", "use_research_supply", "set_queue", "assigned_node =", "qdel(", "research_chapters ="):
                self.assertNotIn(writer, body, name)
        self.assertIn("bench_ui_data(user)", proc(self.bench, "/obj/structure/research_bench/ui_interact"))
    def test_book_window_is_limited_to_a_book_in_reach(self):
        state = proc(self.interface, "/datum/topic_state/research_book/can_use_topic")
        for guard in ("!map.book_research_enabled()", "!B.can_hold_research()", "user.shared_nano_interaction()", "B.loc == user || (isturf(B.loc) && user.Adjacent(B))"):
            self.assertIn(guard, state)
        topic = proc(self.interface, "/obj/item/weapon/book/Topic")
        self.assertLess(topic.index("research_book_state.can_use_topic(src, H) != STATUS_INTERACTIVE"), topic.index("if (href_list[\"read\"])"))
        self.assertIn("has_research_chapter(href_list[\"rip\"])", topic)
        opened = proc(self.interface, "/obj/item/weapon/book/ui_interact")
        self.assertIn('ui_key != "research_book"', opened)
        self.assertIn("_state = research_book_state", opened)
        # Characters without a client keep the menu the agent prompts can answer.
        use = proc(self.research, "/obj/item/weapon/book/attack_self")
        self.assertLess(use.index("if (H.client && (chapters.len || length(research_progress_map())))"), use.index("player_input("))
if __name__ == "__main__":
    unittest.main()
