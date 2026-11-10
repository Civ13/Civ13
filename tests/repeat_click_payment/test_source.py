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

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location('repeat_click_adapter', ROOT/'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(adapter)


def read(path):
    return (ROOT/path).read_text(encoding='utf-8')


def proc(path, declaration):
    return adapter.extract(read(path), declaration)


class RepeatClickPayment(unittest.TestCase):
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

if __name__ == '__main__':
    unittest.main()
