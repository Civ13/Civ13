"""Company stock ledger guards: no stock from nothing, single estate rows, taxes once."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
COMPANIES = (ROOT / 'code/game/mob/groups/companies.dm').read_text()
MARKET = (ROOT / 'code/modules/1713/marketplace.dm').read_text()
DEATH = (ROOT / 'code/game/mob/living/carbon/human/death.dm').read_text()
VENDING = (ROOT / 'code/game/objects/structures/vending/vending_sales.dm').read_text()


def proc(source, header, end_marker):
    return source.split(header, 1)[1].split(end_marker, 1)[0]


class LedgerMove(unittest.TestCase):
    def setUp(self):
        self.move = proc(COMPANIES, '/proc/company_move_stake(', '\n/')

    def test_move_takes_whole_amount_from_one_covering_row(self):
        # One covering row is chosen before anything changes, so a holder (or
        # the estate pool) can never go negative or drain several rows.
        self.assertIn('row[1] == source && row[2] >= amount', self.move)
        self.assertLess(self.move.index('if (!from)'), self.move.index('from[2] -= amount'))
        self.assertNotIn('currb', self.move)

    def test_transfers_report_failure_and_message_only_on_success(self):
        for header in ('/mob/living/human/proc/transfer_stock_proc(', '/proc/transfer_stock_nomob('):
            body = proc(COMPANIES, header, '\n/')
            self.assertIn('if (!company_move_stake(', body)
            self.assertLess(body.index('company_move_stake('), body.index('to_chat('))
            self.assertIn('return TRUE', body)

    def test_transfer_verb_rechecks_after_prompts(self):
        verb = proc(COMPANIES, '/mob/living/human/proc/transfer_company_stock()', '\n// TRUE when')
        self.assertIn('M != H', verb)
        self.assertIn('if (!H.transfer_stock_proc(compchoice, compchoice_amt, CM))', verb)
        self.assertNotIn('map.custom_company[compchoice][l][2] = currb', verb)

    def test_company_names_are_sanitized_and_reserved(self):
        create = proc(COMPANIES, '/mob/living/human/proc/create_company_pr(', '\n/mob/')
        self.assertIn('sanitize(newname, COMPANY_NAME_MAX_CHARS + 1, FALSE)', create)
        # "Global" was only refused inside a loop over existing companies.
        self.assertIn('newname == "Global" || (newname in map.custom_company_nr)', create)


class StockMarket(unittest.TestCase):
    def setUp(self):
        self.buy = proc(MARKET, 'if (href_list["buy"])', '// Sell stock')

    def test_listing_is_revalidated_before_money_is_taken(self):
        check = self.buy.index('if (!company_has_stake(ord, SELLER, ord_perc))')
        move = self.buy.index('SELLER.transfer_stock_proc(ord, ord_perc, H)')
        self.assertLess(check, self.buy.index('qdel(M)'))
        self.assertLess(move, self.buy.index('qdel(M)'))

    def test_listings_are_removed_as_elements(self):
        # "registry -= L" removes L's items, not the listing itself.
        self.assertIsNone(re.search(r'sales_registry -= L{1,2}\b', MARKET))
        self.assertIsNone(re.search(r'sales_registry -= LL\b', DEATH))

    def test_estate_purchase_keeps_other_identical_estates(self):
        estate = self.buy.split('else\n\t\t\t\t\t\t// Only this estate listing', 1)[1]
        self.assertNotIn('for (var/list/LL in map.sales_registry)', estate.split('to_chat(', 1)[0])

    def test_links_use_company_index(self):
        for key in ('sell', 'viewmembers', 'distribute', 'withdraw'):
            self.assertIn(f';{key}=[cmp_idx]', MARKET)
            self.assertIn(f'var/cmp = href_company(href_list["{key}"])', MARKET)

    def test_taxes_clamp_to_thirty(self):
        self.assertNotIn('if (val > 30) val = 10', MARKET)
        self.assertEqual(MARKET.count('if (val > 30) val = 30'), 2)

    def test_payouts_never_create_empty_or_fractional_coin_stacks(self):
        self.assertNotIn('GC.amount = round(price_without_tax/4)', MARKET)
        self.assertNotIn('[5]/4', MARKET)
        pay = proc(COMPANIES, '/proc/company_pay_coins(', '\n/')
        self.assertIn('amount = round(amount)', pay)
        self.assertIn('if (gold > 0)', pay)
        self.assertIn('if (silver > 0)', pay)


class DeathAndVending(unittest.TestCase):
    def test_dead_holder_listings_are_withdrawn(self):
        self.assertIn('if (LL.len >= 4 && LL[4] == src)', DEATH)

    def test_sales_tax_is_not_also_credited_to_the_company(self):
        self.assertNotIn('custom_company_value[owner] += price_with_tax*inp', VENDING)
        self.assertNotIn('[accepted_currency] += price_with_tax*inp', VENDING)
        self.assertIn('map.custom_company_value[owner] += R.price*inp', VENDING)
        self.assertIn('civ[11][accepted_currency]', VENDING)


class DeathReturnsStake(unittest.TestCase):
    def setUp(self):
        self.ret = proc(COMPANIES, '/proc/company_return_stake(', '\n//for automated')

    def test_stake_is_shared_among_living_holders(self):
        self.assertIn('M.stat != DEAD', self.ret)
        self.assertIn('round(stake * row[2] / heir_total)', self.ret)
        # Rounding leftovers go to the largest holder, so nothing is lost.
        self.assertIn('largest[2] += stake - given', self.ret)

    def test_sole_holder_falls_back_to_faction_leader(self):
        self.assertIn('map.custom_civs[civilization][4]', self.ret)
        self.assertIn('company_move_stake(company, holder, stake, leader)', self.ret)

    def test_unwithdrawn_profits_return_to_company(self):
        self.assertIn('map.custom_company_value[company] += dead_row[3]', self.ret)

    def test_death_lists_only_when_nobody_can_take_it(self):
        death = DEATH.split('for(var/stocky in poss_list)', 1)[1]
        self.assertLess(death.index('company_return_stake(stocky, src, civilization)'),
                        death.index('map.sales_registry += list('))


if __name__ == '__main__':
    unittest.main()
