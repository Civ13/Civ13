import copy
import unittest
from continuity import validate


class WitnessChecks(unittest.TestCase):
    def setUp(self):
        self.before=dict(phase='before',time=10,flour='flour',bucket='bucket',baker='baker',customer='customer',
                         oven='oven',counter='counter',water_before=5,flour_before=10,counter_clear=1,
                         carriage='carriage',horse='horse',door='door',carriage_x=8,carriage_y=3,
                         carriage_dir=8,door_open=1,horse_bound=1)
        coords=[(8,9),(8,8),(8,7),(7,7),(7,6),(7,5),(7,4),(7,3)]
        route=[dict(x=x,y=y,time=110+4*i,bread='bread') for i,(x,y) in enumerate(coords)]
        departure=dict(customer='customer',bread='bread',carriage='carriage',horse='horse',door='door',route=route,
                       walk_started=105,boarding_started=142,boarded_at=182,driving_started=192,
                       arrived_at=214,stopped_at=214,ended_at=229,x=6,y=3,z=1,dir=8,
                       driver_bound=1,horse_bound=1,bread_in_inactive_hand=1,reins_in_active_hand=1,moving=0,speed=0)
        self.after=dict(phase='after',time=229,flour='flour',bucket='bucket',baker='baker',customer='customer',
                        oven='oven',counter='counter',water_after=0,flour_after=5,mixed_at=20,dough_input='dough',
                        product='flatbread',produced_ref='bread',picked_ref='bread',picked_at=85,placed_ref='bread',
                        received_ref='bread',customer_holds_output=1,fuel_paid=1,cook_started=30,produced_at=80,
                        placed_at=95,received_at=105,cooking_time=50,departure=departure)

    def test_valid(self):
        validate(self.before,self.after,260)

    def test_bad_bakery_identity_or_cost_rejected(self):
        for key,value in [('flour_after',10),('water_after',1),('received_ref','replacement'),('picked_ref','replacement'),
                          ('customer_holds_output',0),('cooking_time',40),('produced_at',79),('placed_at',94),
                          ('received_at',104),('mixed_at',19),('cook_started',29),('baker','other'),('fuel_paid',0)]:
            with self.subTest(key=key):
                after=copy.deepcopy(self.after);after[key]=value
                with self.assertRaises(ValueError):validate(self.before,after,260)

    def test_bad_departure_identity_or_state_rejected(self):
        for key,value in [('customer','other'),('bread','replacement'),('carriage','other'),('horse','other'),
                          ('door','other'),('x',7),('driver_bound',0),('horse_bound',0),
                          ('bread_in_inactive_hand',0),('reins_in_active_hand',0),('moving',1),('speed',1),
                          ('boarded_at',181),('driving_started',191),('arrived_at',192),('ended_at',228)]:
            with self.subTest(key=key):
                after=copy.deepcopy(self.after);after['departure'][key]=value
                with self.assertRaises(ValueError):validate(self.before,after,260)

    def test_bad_start_route_or_time_rejected(self):
        for key,value in [('counter_clear',0),('door_open',0),('horse_bound',0),('carriage_x',7)]:
            with self.subTest(key=key),self.assertRaises(ValueError):
                validate(dict(self.before,**{key:value}),self.after,260)
        for field,value in [('x',9),('bread','replacement'),('time',111)]:
            after=copy.deepcopy(self.after);after['departure']['route'][1][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):validate(self.before,after,260)
        with self.assertRaises(ValueError):validate(self.before,self.after,228)


if __name__=='__main__':unittest.main()
