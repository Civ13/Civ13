"""Offline source contracts; no browser or game runtime."""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[2] /
          "code/game/objects/items/paper/bundle.dm").read_text()


def body(name, following):
    return SOURCE.split(name, 1)[1].split(following, 1)[0]


class BundleBrowserActions(unittest.TestCase):
    def test_browser_controls_target_the_rendered_page_and_navigation_is_read_only(self):
        render = body("/proc/show_content", "/attack_self")
        self.assertIn(r";remove=\ref[W]", render)
        self.assertIn(r";insert_before=\ref[W]", render)
        self.assertIn(r";insert_after=\ref[W]", render)
        self.assertIn('P.document_classic_html(user, FALSE, "bundle", src)', render)
        topic = body("/Topic(href", "/verb/rename")
        navigation = topic[topic.index('else if (href_list["next_page"])'):]
        self.assertNotIn("browser_insert_page", navigation)
        self.assertNotIn("browser_remove_page", navigation)
        self.assertIn("attack_self(user)", navigation)

    def test_insert_and_remove_gate_on_held_actor_and_same_live_page(self):
        gate = body("/proc/can_change_held_bundle", "/proc/held_bundle_page")
        for check in ("user.client?.mob == user", "!user.stat", "!user.restrained()",
                      "user.can_use_hands()", "loc == user", "user.item_is_in_hands(src)"):
            self.assertIn(check, gate)
        insert = body("/proc/browser_insert_page", "/proc/release_browser_page")
        remove = body("/proc/browser_remove_page", "/Topic(href")
        for branch in (insert, remove):
            self.assertIn("!can_change_held_bundle(user)", branch)
            self.assertIn("held_bundle_page() != expected", branch)
        self.assertLess(insert.index("transfer_held_item_to(sheet, src)"), insert.index("pages.Insert"))
        release = body("/proc/release_browser_page", "/proc/browser_remove_page")
        refused_move = "if (sheet.loc != user && sheet.loc != site)\n\t\treturn FALSE"
        self.assertLess(release.index("user.put_in_hands(sheet)"), release.index(refused_move))
        self.assertLess(release.index(refused_move), release.index("pages -= sheet"))
        self.assertLess(remove.index("if (!release_browser_page(user, expected, site))"), remove.index("page = max"))
        self.assertIn("if (remaining && release_browser_page(user, remaining, site))", remove)
        self.assertIn("if (!contents.len && user.transfer_held_item_to(src, site))", remove)

    def test_loosen_leaves_refused_pages_in_a_retained_bundle(self):
        loosen = body("/verb/remove_all", "/update_icon()")
        self.assertLess(loosen.index("!can_change_held_bundle(user)"), loosen.index("forceMove(site)"))
        self.assertLess(loosen.index("O.loc != site"), loosen.index("pages -= O"))
        self.assertLess(loosen.index("if (contents.len)"), loosen.index("else if (user.transfer_held_item_to(src, site))"))
        self.assertEqual(loosen.count("qdel(src)"), 1)


if __name__ == "__main__":
    unittest.main()
