"""Exercise premade constructor flow from DM source with fake engine effects."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = adapter.read('code/game/objects/structures/vending/fuel_pump.dm')
BASE = '/obj/structure/fuelpump/premade'


def projection(declaration, args, env):
    body = adapter.extract(SOURCE, declaration)
    body = body.replace('..()', 'parent()')
    body = body.replace('map.ID', 'game_map.ID')
    body = body.replace('"[brand] [fueltype] pump"', 'f"{pump.brand} {pump.fueltype} pump"')
    for expression in ('vol', 'fueltype', 'price/4', 'price'):
        body = body.replace('[' + expression + ']', '{pump.' + expression + '}')
    body = body.replace('"This pump has ', 'f"This pump has ')
    for field in ('fueltype', 'vol', 'name', 'price', 'desc'):
        body = body.replace('\t' + field + ' = ', '\tpump.' + field + ' = ')
    body = body.replace('pump.vol = maxvol', 'pump.vol = pump.maxvol')
    body = body.replace('(!restoring)', '(not pump.restoring)')
    return adapter.project('/proc/projected()\n' + body + '\n', '/proc/projected', args, env)


class PremadePumpTests(unittest.TestCase):
    def test_variants_preserve_parent_order_and_descriptions(self):
        for brand, variant in (('UngOil', ''), ('Yamaha Gas', '/yamaha')):
            for fuel in ('gasoline', 'diesel'):
                for deal in (False, True):
                    with self.subTest(brand=brand, fuel=fuel, deal=deal):
                        pump = SimpleNamespace(brand=brand, maxvol=1000, vol=0, price=3,
                                               fueltype='none', name='fuel pump', desc='', restoring=False)
                        events = []
                        game_map = SimpleNamespace(ID='deal' if deal else 'other')
                        desc = projection('/obj/structure/fuelpump/proc/updatedesc', 'pump, game_map',
                                          {'MAP_THE_ART_OF_THE_DEAL': 'deal'})

                        def updatedesc():
                            desc(pump, game_map)
                            events.append(('description', pump.fueltype, pump.name, pump.desc))

                        def pick(*choices):
                            self.assertEqual(choices, ('gasoline', 'diesel', 'biodiesel', 'pethanol', 'petroleum'))
                            events.append(('pick',))
                            return 'petroleum'

                        def color():
                            events.append(('color', pump.fueltype, pump.name, pump.vol, pump.price))

                        helper = projection(BASE + '/proc/set_premade_fuel', 'pump, new_fuel, updatedesc', {})
                        parent = projection(BASE + '/New', 'pump, parent, pick, do_color, updatedesc', {})
                        child = projection(BASE + variant + '/' + fuel + '/New', 'parent, set_premade_fuel', {})
                        child(lambda: parent(pump, lambda: events.append(('ancestor',)), pick, color, updatedesc),
                              lambda chosen: helper(pump, chosen, updatedesc))

                        currency = '0.1 dollars' if deal else '0.4 silver coins'
                        suffix = '' if deal else ' Copper and Gold accepted too.'
                        def expected_desc(kind):
                            return f'This pump has 1000 units of {kind} available. Price: {currency} per unit.{suffix}'
                        self.assertEqual(events, [
                            ('ancestor',), ('pick',),
                            ('color', 'petroleum', f'{brand} petroleum pump', 1000, 0.4),
                            ('description', 'petroleum', f'{brand} petroleum pump', expected_desc('petroleum')),
                            ('description', fuel, f'{brand} {fuel} pump', expected_desc(fuel)),
                        ])
                        self.assertEqual((pump.fueltype, pump.name, pump.vol, pump.price),
                                         (fuel, f'{brand} {fuel} pump', 1000, 0.4))

    def test_a_load_keeps_the_saved_fuel_and_stock(self):
        # Under restore the saved fields arrive after New(): no new fuel roll,
        # no refill, only the colour overlay.
        pump = SimpleNamespace(brand='UngOil', maxvol=1000, vol=250, price=3,
                               fueltype='gasoline', name='saved', desc='saved', restoring=True)
        events = []
        parent = projection(BASE + '/New', 'pump, parent, pick, do_color, updatedesc', {})
        parent(pump, lambda: events.append('ancestor'), lambda *c: events.append('pick'),
               lambda: events.append('color'), lambda: events.append('description'))
        self.assertEqual(events, ['ancestor', 'color'])
        self.assertEqual((pump.fueltype, pump.vol, pump.name, pump.desc), ('gasoline', 250, 'saved', 'saved'))

    def test_brand_defaults_remain_distinct(self):
        self.assertIn('var/brand = "UngOil"\n\ticon_state = "oilpump3"\n\tcustomcolor = "#3cb44b"\n\tmaxvol = 1000', SOURCE)
        self.assertIn('/premade/yamaha\n\tbrand = "Yamaha Gas"\n\ticon_state = "oilpump1"\n\tcustomcolor = "#7F0000"', SOURCE)


class ManagementPriceTests(unittest.TestCase):
    def test_both_price_actions_preserve_validation_and_unlock_behavior(self):
        declaration = '/obj/structure/fuelpump/Topic(href, href_list)\n'
        self.assertEqual(SOURCE.count(declaration), 1)
        topic = SOURCE.split(declaration, 1)[1]
        helper = projection('/obj/structure/fuelpump/proc/update_management_price',
                            'pump, user, custp, updatedesc, show_manage_ui',
                            {'isnum': lambda value: isinstance(value, (int, float))})

        # The typed-in price is the only price action; the script prompt variant went with the HTML page.
        self.assertNotIn('"change_price")', topic)
        for action in ('change_price_direct',):
            marker = '\tif (href_list["action"] == "' + action + '")\n'
            self.assertEqual(topic.count(marker), 1)
            branch = topic.split(marker, 1)[1].split('\n\tif (href_list["action"]', 1)[0]
            if action == 'change_price_direct':
                branch = branch.split('\n\tshow_manage_ui(user)', 1)[0]
            branch = '\n'.join(line[1:] if line.startswith('\t') else line
                               for line in branch.splitlines())
            branch = branch.replace('if (unlocked)', 'if (pump.unlocked)').replace('|| unlocked ||', '|| pump.unlocked ||')
            branch = branch.replace('QDELETED(src)', 'QDELETED(pump)').replace('in_range(src, user)', 'in_range(pump, user)').replace('company_may_operate(user, owner)', 'company_may_operate(user, pump.owner)')
            run = adapter.project('/proc/projected()\n' + branch + '\n', '/proc/projected',
                                  'pump, user, href_list, player_input, text2num, update_management_price, to_chat',
                                  {'QDELETED': lambda pump: pump.removed,
                                   'in_range': lambda pump, user: pump.in_range,
                                   'company_may_operate': lambda user, owner: owner == 'authorized'})
            for unlocked in (False, True):
                for value, expected in ((None, None), (-1, 0), (0, 0), (12.5, 12.5), (50, 50), (51, 50)):
                    with self.subTest(action=action, unlocked=unlocked, value=value):
                        pump = SimpleNamespace(unlocked=unlocked, price=7, removed=False, in_range=True, owner="authorized")
                        user = object()
                        events = []

                        def updatedesc():
                            events.append(('description', pump.price))

                        def show_manage_ui(actor):
                            events.append(('ui', actor, pump.price))

                        def update(actor, amount):
                            events.append(('update', actor, amount))
                            helper(pump, actor, amount, updatedesc, show_manage_ui)

                        def prompt(*args):
                            events.append(('prompt', args[0]))
                            return value

                        def convert(raw):
                            events.append(('convert', raw))
                            return value

                        def notify(actor, message):
                            events.append(('notice', actor))

                        run(pump, user, {'price': 'input'}, prompt, convert, update, notify)
                        if unlocked:
                            self.assertEqual(pump.price, 7)
                            self.assertEqual(events, [('notice', user)])
                            continue
                        first = ('prompt', user) if action == 'change_price_direct' else ('convert', 'input')
                        wanted = [first, ('update', user, value)]
                        if expected is not None:
                            wanted.extend((('description', expected), ('ui', user, expected)))
                        self.assertEqual(events, wanted)
                        self.assertEqual(pump.price, 7 if expected is None else expected)

            for state in ({'owner': 'revoked'}, {'removed': True}, {'in_range': False}, {'unlocked': True}):
                with self.subTest(state=state):
                    pump = SimpleNamespace(unlocked=False, price=7, removed=False, in_range=True, owner='authorized')
                    calls = []
                    def prompt_then_change(*args):
                        calls.append('prompt')
                        vars(pump).update(state)
                        return 25
                    run(pump, object(), {}, prompt_then_change, None,
                        lambda *args: calls.append('mutation'), lambda *args: calls.append('notice'))
                    self.assertEqual(calls, ['prompt'])
                    self.assertEqual(pump.price, 7)

class PurchaseQuoteTests(unittest.TestCase):
    def project(self, proc, args):
        body = adapter.extract(SOURCE, "/obj/structure/fuelpump/proc/" + proc)
        replacements = {
            '\tif (unlocked)': '\tif (src.unlocked)',
            'if (price != quote.unit_price || fueltype != quote.fuel': 'if (src.price != quote.unit_price || src.fueltype != quote.fuel',
            '|| vol < quote.units': '|| src.vol < quote.units',
            '\tstoredval += money': '\tsrc.storedval += [money]',
            '\tunlockedvol = quote.units': '\tsrc.unlockedvol = quote.units',
            '\tunlocked = TRUE': '\tsrc.unlocked = TRUE',
        }
        for old, new in replacements.items():
            body = body.replace(old, new)
        return adapter.project('/proc/receipt()\n' + body + '\n', '/proc/receipt', args, {
            'istype': lambda value: value is not None,
            'QDELETED': lambda value: value is None or value.deleted,
            'SPAN_NOTICE': str,
        })

    def setup_payment(self):
        user = SimpleNamespace()
        user.l_hand = SimpleNamespace(amount=1, value=10, loc=user, deleted=False)
        right = SimpleNamespace(amount=3, value=10, loc=user, deleted=False)
        right.forceMove = lambda target: setattr(right, 'loc', target)
        user.r_hand = right
        user.item_is_in_hands = lambda item: item is user.l_hand or item is user.r_hand
        pump = SimpleNamespace(unlocked=False, unlockedvol=0, price=2, vol=40,
                               fueltype='diesel', storedval=[])
        quote = SimpleNamespace(buyer=user, payment=right, payment_count=3, payment_value=10,
                                unit_price=2, fuel='diesel', units=15)
        moved = []

        def transfer(item, target):
            moved.append((item, target))
            item.loc = target
            user.r_hand = None
            return True

        user.transfer_held_item_to = transfer
        return pump, user, quote, moved

    def test_click_and_render_capture_one_window_owned_quote(self):
        attack = adapter.extract(SOURCE, '/obj/structure/fuelpump/attackby')
        self.assertIn('show_purchase_quote(user, W)', attack)
        build = adapter.extract(SOURCE, '/obj/structure/fuelpump/proc/show_purchase_quote')
        self.assertIn('new(user, money, price, fueltype)', build)
        self.assertLess(build.index('close_user_uis(user, src, "buy")'), build.index('ui_interact(user, "buy"'))
        data = adapter.extract(SOURCE, '/obj/structure/fuelpump/ui_interact')
        self.assertIn('[quote.units] units of [quote.fuel]', data)
        self.assertIn('state = quote', data)
        action = adapter.extract(SOURCE, '/obj/structure/fuelpump/ui_act')
        self.assertIn('ui.ui_key != "buy"', action)
        self.assertLess(action.index('quote = ui.state'), action.index('ui.close()'))
        self.assertIn('complete_purchase(buyer, quote)', action)
        self.assertIn('else if (params["value"] == "buy_no")\n\t\tui.close()', action)
        legacy = adapter.extract(SOURCE, '/obj/structure/fuelpump/Topic')
        self.assertNotIn('complete_purchase', legacy)
        self.assertIn('if (href_list["action"] in list("buy_yes", "buy_no"))\n\t\treturn', legacy)

    def test_confirmation_takes_only_the_quoted_item_and_honors_the_quoted_units(self):
        run = self.project('complete_purchase', 'src, user, quote, to_chat')
        pump, user, quote, moved = self.setup_payment()
        run(pump, user, quote, lambda *_: None)
        self.assertEqual(len(moved), 1)
        self.assertIs(moved[0][0], quote.payment)
        self.assertIsNotNone(user.l_hand)
        self.assertEqual(pump.storedval, [quote.payment])
        self.assertEqual(pump.unlockedvol, quote.units)
        self.assertTrue(pump.unlocked)

    def test_stale_confirmation_or_failed_transfer_does_not_reserve_fuel(self):
        run = self.project('complete_purchase', 'src, user, quote, to_chat')
        for change in ('price', 'fuel', 'stock', 'count', 'value', 'moved', 'deleted',
                       'locked', 'other buyer', 'no quote', 'transfer failed'):
            with self.subTest(change=change):
                pump, user, quote, moved = self.setup_payment()
                edits = {
                    'price': (pump, 'price', 3),
                    'fuel': (pump, 'fueltype', 'gasoline'),
                    'stock': (pump, 'vol', 14),
                    'count': (quote.payment, 'amount', 2),
                    'value': (quote.payment, 'value', 9),
                    'moved': (user, 'r_hand', object()),
                    'deleted': (quote.payment, 'deleted', True),
                    'locked': (pump, 'unlocked', True),
                    'other buyer': (quote, 'buyer', object()),
                    'transfer failed': (user, 'transfer_held_item_to', lambda *_: False),
                }
                if change == 'no quote':
                    quote = None
                else:
                    setattr(*edits[change])
                run(pump, user, quote, lambda *_: None)
                self.assertEqual(moved, [])
                self.assertEqual(pump.storedval, [])
                self.assertEqual(pump.unlockedvol, 0)
                self.assertEqual(pump.unlocked, change == 'locked')



if __name__ == '__main__':
    unittest.main()
