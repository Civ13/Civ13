"""Whole forge handler projected with fake prompt, inventory and map effects."""
from types import SimpleNamespace as NS
import unittest

from test_maintenance import ROOT, istype, project

SOURCE = (ROOT / 'code/modules/research_tree/research_forge.dm').read_text()
COPPER = '/obj/item/stack/money/coppercoin'
SILVER = '/obj/item/stack/money/silvercoin'


class Forge:
    def __init__(self, book=False, switch=None, coin_type=SILVER, value=1):
        self.book = book
        self.switch = switch
        self.events = []
        self.coins = NS(type=coin_type, name='coins', amount=300, value=value, use=self.debit)
        self.map = NS(book_research_enabled=lambda: self.book, add_forge_value=self.credit,
                      get_bench_cap=lambda _: 4, get_forge_progress=lambda _: 30,
                      get_forge_next_cost=lambda _: 300)
        self.env = dict(map=self.map, istype=istype, ishuman=lambda user: True,
                        message=lambda: self.events.append('message'),
                        parent=lambda: self.events.append('parent'),
                        player_input=self.prompt, QDELETED=lambda obj: False,
                        in_range=lambda forge, user: True)
        self.run = project(SOURCE, '/obj/structure/research_forge/attackby',
                           'src, W, user', self.env, fields=())

    def prompt(self, *args):
        self.events.append('prompt')
        if self.switch:
            self.switch(self)
        return 300

    def debit(self, count):
        self.events.append(('debit', count))
        self.coins.amount -= count

    def credit(self, faction, value):
        self.events.append(('credit', faction, value))
        return value >= 300

    def attack(self):
        self.run(object(), self.coins, NS(civilization='Test Faction'))


class ResourceForgeResearchMode(unittest.TestCase):
    def test_book_research_refuses_before_prompt_debit_or_credit(self):
        case = Forge(book=True)
        case.attack()
        self.assertEqual(case.events, ['message'])
        self.assertEqual(case.coins.amount, 300)
        self.assertIn('There is no faction research bench limit to raise.', SOURCE)

    def test_switch_to_book_research_while_prompt_open_leaves_coins_untouched(self):
        case = Forge(switch=lambda forge: setattr(forge, 'book', True))
        case.attack()
        self.assertEqual(case.events, ['prompt', 'message'])
        self.assertEqual(case.coins.amount, 300)

    def test_replaced_map_during_prompt_cannot_receive_credit(self):
        case = Forge(switch=lambda forge: forge.env.update(map=None))
        case.attack()
        self.assertEqual(case.events, ['prompt'])
        self.assertEqual(case.coins.amount, 300)

    def test_faction_research_still_debits_and_credits_in_silver_equivalents(self):
        for coin, value, credit in ((SILVER, 1, 300), (COPPER, .1, 30)):
            case = Forge(coin_type=coin, value=value)
            case.attack()
            self.assertEqual(case.events, ['prompt', ('debit', 300),
                                           ('credit', 'Test Faction', credit), 'message'])
            self.assertEqual(case.coins.amount, 0)
