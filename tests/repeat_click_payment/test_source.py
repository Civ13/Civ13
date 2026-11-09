"""Offline checks: paths that sleep in a prompt pay only after re-checking.

A lagged repeat click is processed while the first click's prompt or build
wait sleeps. Each path below used to pay from values read before that sleep,
so two answers could both build or both pay. No BYOND, network or saves.
The mould pour itself has a native case in tests/stone_molds/casting.dm.
"""
from pathlib import Path
import importlib.util
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
        source = read('code/game/objects/structures/plant_pots.dm')
        guard = 'if (QDELETED(src) || QDELETED(P) || P.loc != user || !P.use(1))'
        self.assertEqual(source.count(guard), 2)
        for chunk in source.split('What type of plastic plant?')[1:]:
            self.assert_order(chunk, guard, 'qdel(S)', 'qdel(src)')

    def test_computer_payments_recheck(self):
        source = read('code/modules/1713/computers/programs.dm')
        bail = proc('code/modules/1713/computers/programs.dm', '/datum/program/bail/Topic')
        self.assert_order(bail, 'Who do you wish to pay the bail for?', 'if (QDELETED(U) || U.bail_price <= 0)',
                          'M.use(U.bail_price/5)', 'U.bail_price = 0')
        repair = proc('code/modules/1713/computers/programs.dm', '/datum/program/swiftfix/Topic')
        self.assert_order(repair, 'Are you sure?', '!M.use(100/5)', 'switch(user.civilization)')
        self.assertNotIn('M.amount-=', bail + repair)
        self.assertIn('/datum/program/bail/Topic', source)


if __name__ == '__main__':
    unittest.main()
