"""Protect the server-side D.E.E.P.N.E.T. seller action contract."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/modules/1713/computers/programs.dm").read_text()
DEEPNET = SOURCE.split("/datum/program/deepnet/proc/active_seller_order", 1)[1].split(
    "/datum/program/cartrader", 1)[0]


class LegacyDeepnetSellerTests(unittest.TestCase):
    def test_operation_binds_actor_and_current_account_to_live_deepnet_order(self):
        helper = DEEPNET.split("/datum/program/deepnet/proc/deepnet_account", 1)[0]
        for control in (
            "actor != usr", "actor != user", "actor != origin.user",
            "actor.z != origin.z", "get_dist(actor, origin) > 1",
            "var/account = deepnet_account(actor)", "order[1] != account",
            'order[5] != "deepnet"', "order[6] != id", "order[7] != 1",
            "!QDELETED(I)",
        ):
            self.assertIn(control, helper)
        self.assertIn('actor.original_job_title == "Legitimate Business" ? actor.real_name : actor.civilization', DEEPNET)

    def test_price_revalidates_after_wait_before_changing_order(self):
        change = DEEPNET.split('if (findtext(href_list["deepnet"],"ch") == 1)', 1)[1].split(
            'if (findtext(href_list["deepnet"],"cn") == 1)', 1)[0]
        prompt = change.index("player_input(actor")
        self.assertLess(change.index("if (!order)"), prompt)
        for guard in ("map != order_map", "origin != order_computer",
                      "active_seller_order(tcode, actor) != order"):
            self.assertLess(prompt, change.index(guard))
            self.assertLess(change.index(guard), change.index("order[4] = newprice*4"))

    def test_cancel_uses_exact_active_order_and_creation_uses_same_account(self):
        cancel = DEEPNET.split('if (findtext(href_list["deepnet"],"cn") == 1)', 1)[1].split(
            'switch(href_list["deepnet"])', 1)[0]
        self.assertLess(cancel.index("if (!order)"), cancel.index('map.globalmarketplace -= tcode'))
        self.assertLess(cancel.index('map.globalmarketplace -= tcode'), cancel.index('BO.forceMove(site)'))
        self.assertIn('list(u_account,ST,ST.amount,price*4,"deepnet"', DEEPNET)
        self.assertIn('list(u_account,M,1,price*4,"deepnet"', DEEPNET)


if __name__ == "__main__":
    unittest.main()
