"""Offline checks: paths that sleep in a prompt pay only after re-checking.

A lagged repeat click is processed while the first click's prompt or build
wait sleeps. Each path below used to pay from values read before that sleep,
so two answers could both build or both pay. No BYOND, network or saves.
The mould pour itself has a native case in tests/stone_molds/casting.dm.
"""
from pathlib import Path
import importlib.util
import re
import unittest
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location('repeat_click_adapter', ROOT/'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(adapter)


def read(path):
    return (ROOT/path).read_text(encoding='utf-8')


def proc(path, declaration):
    return adapter.extract(read(path), declaration)


class RepeatClickPayment(unittest.TestCase):
    def test_grille_repair_requires_payment_and_restores_subtype_defaults(self):
        body = proc('code/game/objects/items/stacks/rods.dm', '/obj/item/stack/rods/attack_self')
        branch = body[body.index('\t\tfor (var/obj/structure/grille/G in usr.loc)'):
                      body.index('\n\telse if (!in_use)')]

        def run(branch_source, available, destroyed, initial_health=10, initial_icon='grille',
                broken_type=False, details=False):
            grilles = [SimpleNamespace(destroyed=value, health=0, density=False, icon_state='broken',
                                       initial_health=initial_health, initial_icon=initial_icon,
                                       broken_type=broken_type)
                       for value in destroyed]
            stock = [available]

            def use(amount):
                if stock[0] < amount:
                    return False
                stock[0] -= amount
                return True

            env = {'usr': SimpleNamespace(loc=grilles), 'use': use,
                   'typed_iter': lambda values, _type: values}
            normalized = '\n'.join(line[1:] if line.startswith('\t') else line
                                   for line in branch_source.splitlines())
            # Model BYOND's type/default-value lookups at the engine boundary.
            normalized = normalized.replace('initial(G.health)', 'G.initial_health')
            normalized = normalized.replace('initial(G.icon_state)', 'G.initial_icon')
            normalized = normalized.replace('istype(G, /obj/structure/grille/broken)', 'G.broken_type')
            projection = '/proc/grille_repair_projection()\n' + normalized + '\n'
            adapter.project(projection, '/proc/grille_repair_projection', '', env)()
            if details:
                return stock[0], [(g.health, g.density, g.destroyed, g.icon_state) for g in grilles]
            return stock[0], [not grille.destroyed for grille in grilles]

        self.assertEqual(run(branch, 1, [True, True]), (0, [True, False]))
        self.assertEqual(run(branch, 0, [True, True]), (0, [False, False]))
        self.assertEqual(run(branch, 2, [True, True]), (0, [True, True]))
        self.assertEqual(run(branch, 1, [False, True]), (1, [True, False]))
        fence = read('code/modules/1713/structures.dm').split('/obj/structure/grille/fence\n', 1)[1].split('\n\n', 1)[0]
        self.assertIn('health = 16', fence)
        self.assertIn('icon_state = "fence"', fence)
        self.assertEqual(run(branch, 1, [True], initial_health=16, initial_icon='fence', details=True),
                         (0, [(16, True, False, 'fence')]))
        self.assertEqual(run(branch, 1, [True], initial_icon='grille-b', broken_type=True, details=True),
                         (0, [(10, True, False, 'grille')]))
        # Recreate the former ordering as a negative control: payment failure
        # did not stop the loop, so one rod could restore two broken grilles.
        old = branch.replace('\t\t\t\tif (!use(1))\n\t\t\t\t\treturn TRUE\n', '')
        old = old.replace('\n\t\t\telse\n\t\t\t\treturn TRUE',
                          '\n\t\t\t\tuse(1)\n\t\t\telse\n\t\t\t\treturn TRUE')
        self.assertEqual(run(old, 1, [True, True]), (0, [True, True]))

    def test_slot_machine_jackpot_distinguishes_symbol_from_payout_weight(self):
        source = read('code/game/objects/structures/slotmachine.dm')
        body = proc('code/game/objects/structures/slotmachine.dm', '/obj/machinery/slotmachine/proc/check_win')
        weights = dict((name, int(weight)) for name, weight in re.findall(r'"(\w+)"\s*=\s*(\d+)',
                       re.search(r'var/weights = list\(([^\n]+)\)', source).group(1)))
        self.assertIn('var/weight = weights[slots["1"]]', body)
        condition = re.search(r'if \(([^\n]+)\) //Case of jackpot', body).group(1)
        self.assertIn('prize = jackpot\n\t\t\tjackpot = 0', body)
        operand = re.fullmatch(r'(weight|slots\["1"\]) == "Seven"', condition).group(1)
        def is_jackpot(symbol):
            return (weights[symbol] if operand == 'weight' else symbol) == 'Seven'
        self.assertTrue(is_jackpot('Seven'))
        self.assertFalse(is_jackpot('Diamond'))

    def assert_order(self, body, *tokens):
        last = -1
        for token in tokens:
            index = body.find(token, last + 1)
            self.assertGreater(index, last, f'{token!r} must follow the previous step')
            last = index

    def test_mould_pour_is_exclusive(self):
        body = proc('code/game/objects/structures/blacksmithing/molds.dm', '/obj/item/weapon/clay/mold/attackby')
        self.assert_order(body, 'if (ML.pouring || pouring)', ') as num', 'if (!can_receive_pour(ML, user))',
                          'amt_to_transfer = min(input,', '\tcapacity += amt_to_transfer')

    def test_vehicle_and_ship_walls_pay_after_prompts(self):
        frames = 'code/modules/1713/machinery/modular_vehicles/frame_parts.dm'
        pay = proc(frames, '/obj/structure/vehicleparts/frame/proc/pay_for_wall')
        for token in ('QDELETED(src)', 'QDELETED(S)', 'S.loc != H', 'get_dist(src, H) > 1',
                      '!wall_side_free(side)', 'return S.use(cost)'):
            self.assertIn(token, pay)
        for path, declaration, cost in ((frames, '/obj/structure/vehicleparts/frame/attackby', 'choice2/10'),
                                        ('code/modules/1713/machinery/modular_vehicles/ships/frame_parts.dm',
                                         '/obj/structure/vehicleparts/frame/ship/attackby', 'choice2/5')):
            with self.subTest(path=path):
                body = proc(path, declaration)
                self.assert_order(body, 'Which type of wall?', f'if (!pay_for_wall(S, H, choice1, {cost}))', 'update_icon()')
                self.assertNotIn('S.amount -=', body)

    def test_engine_steel_is_paid_after_the_wait(self):
        path = 'code/modules/1713/machinery/engines/engines.dm'
        body = proc(path, '/obj/item/weapon/enginemaker/attack_self')
        self.assertNotIn('.amount -=', body)
        self.assertEqual(body.count('if (!enginemaker_pay_steel(H, (enginesize/1000)*'), 9)
        for chunk in body.split('enginesize = input(')[1:]:
            self.assert_order(chunk, 'if (do_after(H,', 'enginemaker_pay_steel(', '= new/obj/structure/engine/')
        pay = proc(path, '/proc/enginemaker_pay_steel')
        self.assertIn('S.can_use(cost)', pay)
        self.assertIn('return S.use(cost)', pay)

    def test_grenade_and_rocket_parts_are_not_reused(self):
        path = 'code/modules/projectiles/ammo_crafting.dm'
        for declaration in ('/obj/item/stack/ammopart/casing/grenade/attackby', '/obj/item/stack/ammopart/casing/booster/attackby'):
            with self.subTest(declaration=declaration):
                body = proc(path, declaration)
                self.assert_order(body, 'WWinput(', '!QDELETED(src) && !QDELETED(W) && W.loc == user && ammo_part_stack_use(W, amount)',
                                  'new resultpath(', 'qdel(src)')
                self.assertNotIn('W.amount -=', body)

    def test_wall_frames_pay_for_a_live_frame(self):
        path = 'code/modules/1713/structures.dm'
        pay = proc(path, '/obj/structure/wallframe/proc/pay_for_build')
        self.assert_order(pay, 'QDELETED(src)', 'W.loc != H', 'return S.use(cost)')
        for declaration in ('/obj/structure/wallframe/attackby', '/obj/structure/wallframe/bamboo/attackby'):
            with self.subTest(declaration=declaration):
                body = proc(path, declaration)
                self.assertNotIn('W.amount -=', body)
                self.assertNotIn('\tqdel(W)\n', body)
                self.assertEqual(body.count('if (do_after('), body.count('&& pay_for_build(W, H, '))

    def test_plastic_pot_plants_fill_one_pot(self):
        path = 'code/game/objects/structures/plant_pots.dm'
        body = proc(path, '/obj/structure/plant_pot/proc/finish_plastic_plant')
        guard = 'if (QDELETED(src) || QDELETED(P) || P.loc != user || !P.use(1))'
        self.assert_order(body, 'WWinput(', 'S.filled_type = /obj/item/stack/material/plastic',
                          guard, 'qdel(S)', 'return', 'qdel(src)')
        self.assertNotIn('Cancel', body)
        for subtype in ('clay/light', 'medium_planter/clay/yellow'):
            with self.subTest(subtype=subtype):
                handler = proc(path, f'/obj/structure/plant_pot/{subtype}/attackby')
                plastic = handler[handler.index('if (istype(W, /obj/item/stack/material/plastic))'):]
                filled = f'new /obj/structure/plant_pot/{subtype}/filled(loc)'
                self.assert_order(plastic, 'if (filled_type || filled)', 'do_after(user, 15, src)',
                                  filled, 'finish_plastic_plant(W, user, S)', 'return')

    def test_plastic_pot_choices_keep_their_appearances(self):
        body = proc('code/game/objects/structures/plant_pots.dm',
                    '/obj/structure/plant_pot/proc/finish_plastic_plant')
        cases = (
            ('Plastic Tree', 'plastic1', "A pot with a plastic, it won't fool anybody but it looks nice."),
            ('Plastic Pine Tree', 'plastic2', "A pot with a plastic pine tree, it won't fool anybody but it looks nice."),
            ('Plastic Palm Tree', 'plastic3', "A pot with a plastic palm tree, it won't fool anybody but it looks nice."),
            ('Plastic Leaf Plant', 'plastic4', "A pot with a plastic leaf plant, it won't fool anybody but it looks nice."),
        )
        for name, suffix, description in cases:
            with self.subTest(name=name):
                self.assertIn(f'if (choice == "{name}")\n\t\tS.icon_state = "[planttype]{suffix}"\n\t\tS.desc = "{description}"', body)

    def test_computer_payments_recheck(self):
        source = read('code/modules/1713/computers/programs.dm')
        bail = proc('code/modules/1713/computers/programs.dm', '/datum/program/bail/Topic')
        self.assert_order(bail, 'Who do you wish to pay the bail for?', 'if (QDELETED(U) || U.bail_price <= 0)',
                          'M.use(U.bail_price/5)', 'U.bail_price = 0')
        repair = proc('code/modules/1713/computers/programs.dm', '/datum/program/swiftfix/Topic')
        self.assert_order(repair, 'Are you sure?', '!M.use(100/5)', 'switch(user.civilization)')
        self.assertNotIn('M.amount-=', bail + repair)
        self.assertIn('/datum/program/bail/Topic', source)


    def test_export_radios_pay_once(self):
        for path, coin in (('code/game/objects/map_metadata/pepelsibirsk.dm', 'rubles'),
                           ('code/game/objects/map_metadata/colonia.dm', 'silvercoin')):
            with self.subTest(path=path):
                source = read(path)
                self.assert_order(source, 'Sell the whole stack for',
                                  'if (exportChoice == "Yes" && !QDELETED(W) && W.loc == user && get_dist(src, user) <= 1)',
                                  f'new/obj/item/stack/money/{coin}(loc, round(moneyin))', 'qdel(W)')

    def test_research_desk_and_bookcase(self):
        desk = proc('code/modules/1713/researchcost.dm', '/obj/structure/researchdesk/attackby')
        self.assert_order(desk, 'Which category to research?', 'if (QDELETED(W) || W.loc != H)',
                          'map.custom_civs[H.civilization][1] += (moneyin)')
        shelf = read('code/game/objects/structures/bookcase.dm')
        check = proc('code/game/objects/structures/bookcase.dm', '/obj/structure/bookcase/proc/check_research')
        self.assert_order(check, 'sum_i = 0', 'sum_h = 0', 'for (var/obj/item/weapon/book/research/RB in contents)')
        study = proc('code/game/objects/structures/bookcase.dm', '/obj/structure/bookcase/attackby')
        self.assert_order(study, 'if (studying)', 'check_research()', 'studying = TRUE',
                          'var/studied = do_after(', 'studying = FALSE', 'if (studied)')
        self.assertIn('var/tmp/studying = FALSE', shelf)

    def test_bookcase_research_credits_and_rejections(self):
        source = read('code/game/objects/structures/bookcase.dm')
        attack = adapter.extract(source, '/obj/structure/bookcase/attackby')
        start = attack.index('\t\t\tif (user.civilization != null')
        end = attack.index('\n\t\t\tuser.adaptStat', start)
        body = '\n'.join(line[2:] if line.startswith('\t\t') else line
                         for line in attack[start:end].splitlines())
        fixture = '/fixture/credit()\n' + body + '\n\treturn TRUE\n'

        class DMList:
            def __init__(self, values):
                self.values = list(values)

            def __getitem__(self, index):
                return self.values[index - 1]

            def __setitem__(self, index, value):
                self.values[index - 1] = value

        old_fields = adapter.FIELDS
        try:
            adapter.FIELDS += ('sum_i', 'sum_m', 'sum_h', 'anti_abuse', 'credit_named_faction_research')
            for faction in 'abcdef':
                for reject in (None, 1, 2):
                    with self.subTest(faction=faction, rejected_call=reject):
                        custom = DMList([10, 20, 30])
                        named = {letter: DMList([100, 200, 300]) for letter in 'abcdef'}
                        world_map = SimpleNamespace(custom_civs={faction: custom},
                                                    **{f'civ{key}_research': value for key, value in named.items()})
                        calls = []
                        messages = []
                        shelf = SimpleNamespace(sum_i=1, sum_m=2, sum_h=3)
                        def anti_abuse(*args):
                            calls.append(args[1:])
                            return len(calls) == reject
                        shelf.anti_abuse = anti_abuse
                        env = {'map': world_map, 'to_chat': lambda *args: messages.append(args),
                               **{f'civname_{letter}': letter for letter in 'abcdef'}}
                        helper = adapter.project(source, '/obj/structure/bookcase/proc/credit_named_faction_research',
                                                 'src, user, research', env.copy(), method=True)
                        shelf.credit_named_faction_research = lambda user, research: helper(shelf, user, research)
                        credit = adapter.project(fixture, '/fixture/credit', 'src, user', env.copy(), method=True)
                        result = credit(shelf, SimpleNamespace(civilization=faction))
                        self.assertEqual(result, None if reject else True)
                        self.assertEqual(custom.values, [10, 20, 30] if reject == 1 else [11, 22, 33])
                        self.assertEqual(named[faction].values, [101, 202, 303] if reject is None else [100, 200, 300])
                        self.assertTrue(all(named[key].values == [100, 200, 300] for key in named if key != faction))
                        self.assertEqual(calls[0], (10, 20, 30, 1, 2, 3))
                        if reject != 1:
                            self.assertEqual(calls[1], (100, 200, 300, 1, 2, 3))
                        self.assertEqual((shelf.sum_i, shelf.sum_m, shelf.sum_h),
                                         (None, None, None) if reject else (1, 2, 3))
                        self.assertFalse(messages)
        finally:
            adapter.FIELDS = old_fields

    def test_roulette_brick_wall_and_trench(self):
        roulette = proc('code/game/objects/structures/roulette_table.dm', '/obj/structure/roulette/attackby')
        self.assert_order(roulette, 'Where do you want to place your bet?', 'if (betchoice && !spinning && can_bet)',
                          'if (!QDELETED(I) && I.loc == user)', 'current_bets += ')
        wall = proc('code/game/objects/covers_types/covers_buildable.dm', '/obj/covers/brick_wall/incomplete/attackby')
        self.assert_order(wall, 'What type of wall?', 'if (QDELETED(src) || QDELETED(W) || W.loc != user)', 'new /obj/covers/brick_wall(loc)')
        trench = read('code/modules/1713/trench.dm')
        self.assertEqual(trench.count('if (choice == "Yes" && !QDELETED(C) && C.loc == user)'), 2)

    def test_market_programs_and_vendor(self):
        programs = read('code/modules/1713/computers/programs.dm')
        bank = proc('code/modules/1713/computers/programs.dm', '/datum/program/junglebank/Topic')
        self.assert_order(bank, 'map.globalmarketplace[tcode][7] != 1', 'map.marketplaceaccounts[user.name] -= cost')
        self.assert_order(bank, 'Are you sure you want to sell', 'map.globalmarketplace[tcode][2] != user',
                          'map.marketplaceaccounts[user.name] += cost')
        self.assertEqual(programs.count('QDELETED(ST) || user.get_active_hand() != ST)'), 2)
        self.assertEqual(programs.count('QDELETED(M) || user.get_active_hand() != M)'), 2)
        vendor = proc('code/game/objects/structures/vending/vending_sales.dm', '/obj/structure/vending/sales/attackby')
        self.assert_order(vendor, 'var/atom/drop_loc = W.loc', 'What price do you want to set',
                          'if (QDELETED(W) || W.loc != drop_loc)', 'product_records.Add(product)')

    def test_mines_shells_and_printing_press(self):
        grenades = read('code/game/objects/items/weapons/grenades/grenade.dm')
        self.assertEqual(grenades.count('if (!QDELETED(src) && loc == user)'), 3)
        for declaration in ('/obj/item/weapon/grenade/secondary_attack_self',
                            '/obj/item/weapon/grenade/antitank/n75/secondary_attack_self',
                            '/obj/item/weapon/grenade/antitank/type99/secondary_attack_self'):
            with self.subTest(declaration=declaration):
                body = proc('code/game/objects/items/weapons/grenades/grenade.dm', declaration)
                self.assert_order(body, 'if (do_after(user,', 'if (!QDELETED(src) && loc == user)', 'BT = new', 'qdel(src)')
        shells = proc('code/modules/projectiles/ammo_crafting.dm', '/obj/item/stack/ammopart/casing/tank/attack_self')
        self.assert_order(shells, 'if (crafting_shells)', 'crafting_shells = TRUE', 'Which type of shell',
                          'if (QDELETED(src) || loc != user)', 'new/obj/item/cannon_ball/shell/tank', 'crafting_shells = FALSE\n\t\tto_chat', 'qdel(src)')
        press = proc('code/modules/1713/production.dm', '/obj/structure/printingpress/attackby')
        self.assert_order(press, 'Add to original or copy?', 'if (input == "Cancel" || QDELETED(W) || W.loc != user)', 'base += W')

class RouletteSettlement(unittest.TestCase):
    """Execute the production settlement and collection bodies with inert engine seams."""

    class Bet(list):
        def __getitem__(self, index):
            return super().__getitem__(index - 1)

        def __setitem__(self, index, value):
            super().__setitem__(index - 1, value)

    def settle(self, bets, number=7, color='black', half='1 to 18', dozen='1st 12', odd_even='odd', mutation=None):
        body = proc('code/game/objects/structures/roulette_table.dm', '/obj/structure/roulette/proc/process_wins')
        if mutation:
            body = mutation(body)
        # Preserve the nested DM list record; translate only the list API boundary.
        body = body.replace('unclaimed += list(L)', 'unclaimed.append(L)')
        body = body.replace('current_bets.len', 'len(current_bets)')
        body += '\n\treturn (current_bets, can_bet)\n'
        source = '/proc/roulette_settlement()\n' + body
        env = {'typed_iter': lambda values, _type: values, 'num2text': str}
        run = adapter.project(source, '/proc/roulette_settlement',
                              'current_bets, win_number, win_color, win_half, win_3rd, win_odd_even', env)
        return run([self.Bet(bet) for bet in bets], number, color, half, dozen, odd_even)

    def collect(self, bets, user, mutation=None):
        body = proc('code/game/objects/structures/roulette_table.dm', '/obj/structure/roulette/attack_hand')
        if mutation:
            body = mutation(body)
        body = body.replace('new/obj/item/weapon/roulette/chip(loc)', 'new_chip(loc)')
        body = body.replace('newlist += list(L)', 'newlist.append(L)')
        body = body.replace('newlist.Add(L)', 'newlist.extend(L)')
        body = body.replace('current_bets.len', 'len(current_bets)')
        body += '\n\treturn (current_bets, can_bet)\n'
        source = '/proc/roulette_collection()\n' + body
        env = {'typed_iter': lambda values, _type: values, 'to_chat': lambda *_: None,
               'new_chip': lambda _loc: SimpleNamespace(value=0), 'TRUE': True, 'FALSE': False}
        run = adapter.project(source, '/proc/roulette_collection', 'current_bets, H, loc, can_bet', env)
        return run(bets, user, None, False)

    def test_payouts_zero_losses_and_empty_table(self):
        cases = [('black', 20), ('1 to 18', 20), ('odd', 20), ('1st 12', 30), ('7', 360)]
        for choice, expected in cases:
            with self.subTest(choice=choice):
                remaining, can_bet = self.settle([['a', choice, 10]])
                self.assertEqual(remaining, [['a', 'won', expected]])
                self.assertFalse(can_bet)
        self.assertEqual(self.settle([['a', 'red', 10]]), ([], True))
        self.assertEqual(self.settle([]), ([], True))
        remaining, can_bet = self.settle([['a', '0', 5], ['b', 'odd', 5]],
                                         number=0, color='green', half=None, dozen=None, odd_even=None)
        self.assertEqual(remaining, [['a', 'won', 180]])
        self.assertFalse(can_bet)
        # Negative control: the old two-times branch swallowed dozen bets.
        old = lambda body: body.replace('win_half == L[2] || win_odd_even',
                                        'win_half == L[2] || win_3rd == L[2] || win_odd_even')
        self.assertEqual(self.settle([['a', '1st 12', 10]], mutation=old)[0][0][3], 20)
        old_losses = lambda body: body.replace('current_bets = unclaimed', 'current_bets = current_bets')
        self.assertFalse(self.settle([['a', 'red', 10]], mutation=old_losses)[1])

    def test_collection_preserves_other_players_nested_claims(self):
        class Actor:
            def __init__(self):
                self.chips = []
            def put_in_any_hand_if_possible(self, chip, *_):
                self.chips.append(chip.value)
        first, second = Actor(), Actor()
        remaining, can_bet = self.settle([[first, 'black', 10], [second, '1st 12', 5],
                                          [first, 'red', 8]])
        self.assertFalse(can_bet)
        pending, can_bet = self.collect(remaining, first)
        self.assertEqual(first.chips, [20])
        self.assertEqual(pending, [[second, 'won', 15]])
        self.assertFalse(can_bet)
        final, can_bet = self.collect(pending, second)
        self.assertEqual(second.chips, [15])
        self.assertEqual(final, [])
        self.assertTrue(can_bet)
        # DM Add(L) expands a list argument instead of retaining the record.
        old = lambda body: body.replace('newlist += list(L)', 'newlist.Add(L)')
        broken, _ = self.collect(remaining, first, mutation=old)
        self.assertNotEqual(broken, [[second, 'won', 15]])


if __name__ == '__main__':
    unittest.main()
