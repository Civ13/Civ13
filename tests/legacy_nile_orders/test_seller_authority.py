"""Source contracts for group-authorized Nile seller operations."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/modules/1713/computers/programs.dm").read_text()
NILE = SOURCE.split("/datum/program/nilestore/proc/active_seller_order", 1)[1].split(
    "/datum/program/elektra", 1)[0]


class NileSellerTests(unittest.TestCase):
    def test_live_order_bound_to_requester_and_group_without_migration(self):
        gate = NILE.split("/datum/program/nilestore/Topic", 1)[0]
        for check in (
            "actor != usr", "actor != user", "actor != origin.user",
            "actor.z != origin.z", "get_dist(actor, origin) > 1",
            "var/account = actor.civilization", "order[1] != account",
            'order[5] != "nile"', "order[6] != id", "order[7] != 1", "!QDELETED(I)",
        ):
            self.assertIn(check, gate)
        self.assertIn('list(user.civilization,ST,ST.amount,price*4,"nile"', NILE)
        self.assertIn('list(user.civilization,M,1,price*4,"nile"', NILE)

    def test_price_revalidates_exact_order_and_session_after_prompt(self):
        reprice = NILE.split('if (findtext(href_list["nile"],"ch") == 1)', 1)[1].split(
            'if (findtext(href_list["nile"],"cn") == 1)', 1)[0]
        prompt = reprice.index("player_input(actor")
        self.assertLess(reprice.index("if (!order)"), prompt)
        for guard in ("map != order_map", "origin != order_computer",
                      "active_seller_order(tcode, actor) != order"):
            self.assertLess(prompt, reprice.index(guard))
            self.assertLess(reprice.index(guard), reprice.index("order[4] = newprice*4"))

    def test_group_management_menu_and_cancellation_use_same_boundary(self):
        self.assertEqual(NILE.count("if (active_seller_order(i, user))"), 2)
        cancel = NILE.split('if (findtext(href_list["nile"],"cn") == 1)', 1)[1].split(
            'switch(href_list["nile"])', 1)[0]
        self.assertLess(cancel.index("if (!order)"), cancel.index("map.globalmarketplace -= tcode"))
        self.assertLess(cancel.index("map.globalmarketplace -= tcode"), cancel.index("BO.forceMove(site)"))


if __name__ == "__main__":
    unittest.main()
