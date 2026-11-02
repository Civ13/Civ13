"""Synthetic data ONLY for rejecting false receipts. Never execution evidence."""
import copy
import unittest
import contract


def synthetic():
    rows=[];tick=0
    def emit(case,event,**fields):
        nonlocal tick
        tick+=1
        rows.append(dict(seq=len(rows)+1,tick=tick,source=contract.PIN,case=case,event=event,**fields))
    def frame(case,cars,kind='pulse',moved=0,auto=0,on=0,switches=None):
        emit(case,'frame',kind=kind,cars=cars,moved=moved,auto=auto,on=on,switches=switches or [],levers=[],rotators=[])
    turns=[dict(x=x,y=y,dir=d,turn=t,type='/obj/structure/rails/turn') for x,y,d,t in ((24,-1,1,8),(24,-8,2,4),(34,-8,4,1),(34,-1,8,2))]
    emit('startup','check',label='native port closed',ok=1)
    for case in contract.ROUTES:
        emit(case,'begin');emit(case,'layout',rails=turns)
        for i in range(2,9):emit(case,'check',label='native hitch '+str(i),ok=1)
        cars=[dict(id=i+1,x=-i,y=0,dir=4,health=1000,next=i+2 if i<7 else 0) for i in range(8)]
        frame(case,copy.deepcopy(cars),'initial')
        for a,b in zip(contract.expected_route(case),contract.expected_route(case)[1:]):
            heading=4 if (a,b) in {((4,0),(4,1)),((16,1),(16,0)),((22,0),(22,-1)),((36,-1),(36,0))} else 4 if b[0]>a[0] else 1 if b[1]>a[1] else 2
            positions=[b]+[(c['x'],c['y']) for c in cars[:-1]]
            for car,pos in zip(cars,positions):car.update(x=pos[0],y=pos[1],dir=heading)
            frame(case,copy.deepcopy(cars),moved=1,auto=1,on=1)
            if (case=='passenger' and b==(13,1)) or (case=='depot' and b==(32,-8)):
                emit(case,'target_stop',x=b[0],y=b[1],on=0,auto=0,method='locomotive.attack_hand');frame(case,copy.deepcopy(cars),'stopped');frame(case,copy.deepcopy(cars),'service_dwell')
        emit(case,'target_stop',x=44,y=0,on=0,auto=0,method='locomotive.attack_hand');frame(case,copy.deepcopy(cars),'stopped');emit(case,'end',failures=0)
    for case in contract.CONTROLS:
        emit(case,'begin');emit(case,'layout',rails=[]);emit(case,'check',label='synthetic control',ok=1)
        if case=='lever_radius':
            for state in ('split','forward'):
                frame(case,[],'lever',switches=[dict(x=4,y=0,state=state),dict(x=6,y=4,state=state),dict(x=7,y=2,state='forward')])
        elif case=='detached_rotator':
            for kind,d in (('initial',2),('rotate_right',4),('rotate_left',2),('rotate_hand',4)):
                frame(case,[dict(id=1,x=24,y=-4,dir=d,next=0),dict(id=2,x=25,y=-4,dir=4,next=0)],kind)
        else:
            pos={'missing_siding_guard':(16,1),'missing_depot_guard':(36,-1),'end_of_track':(47,0),
                 'blocked_switch_target':(4,0),'wrong_facing_switch':(5,0),'fuel_stall':(0,0)}[case]
            car=dict(id=1,x=pos[0],y=pos[1],health=995 if case=='blocked_switch_target' else 1000,dir=4)
            frame(case,[car],moved=int(case=='wrong_facing_switch'));frame(case,[car],'stopped')
        emit(case,'end',failures=0)
    emit(case,'complete',failures=0,port=0)
    return rows


class Contract(unittest.TestCase):
    def test_synthetic_valid_shape_accepted(self):self.assertTrue(contract.validate(synthetic())['accepted'])
    def rejects(self,mutate):
        rows=synthetic();mutate(rows)
        with self.assertRaises(ValueError):contract.validate(rows)
    def test_changed_source_rejected(self):self.rejects(lambda rows:rows[3].update(source='0'*40))
    def test_sequence_gap_rejected(self):self.rejects(lambda rows:rows[3].update(seq=99))
    def test_failed_assertion_rejected(self):self.rejects(lambda rows:rows[0].update(ok=0))
    def test_missing_native_hitch_rejected(self):
        self.rejects(lambda rows:next(r for r in rows if r.get('label')=='native hitch 2').update(label='not hitch'))
    def test_wrong_route_rejected(self):
        self.rejects(lambda rows:next(r for r in rows if r['event']=='frame' and r.get('moved')==1)['cars'][0].update(y=1))
    def test_follower_teleport_rejected(self):
        self.rejects(lambda rows:next(r for r in rows if r['event']=='frame' and r.get('moved')==1)['cars'][3].update(x=30))
    def test_broken_coupling_rejected(self):
        self.rejects(lambda rows:next(r for r in rows if r['event']=='frame' and r.get('moved')==1)['cars'][2].update(next=0))
    def test_route_damage_rejected(self):
        self.rejects(lambda rows:next(r for r in rows if r['event']=='frame' and r.get('moved')==1)['cars'][3].update(health=995))
    def test_tail_still_on_merge_rejected(self):
        self.rejects(lambda rows:next(r for r in rows if r['case']=='depot' and r['event']=='frame' and r.get('moved')==1 and r['cars'][0]['x']==44)['cars'][-1].update(x=36))
    def test_auto_not_stopped_rejected(self):
        self.rejects(lambda rows:next(r for r in rows if r['event']=='frame' and r.get('kind')=='stopped').update(auto=1))
    def test_rotator_changed_adjacent_car_rejected(self):
        self.rejects(lambda rows:next(r for r in rows if r.get('kind')=='rotate_right')['cars'][1].update(dir=8))
    def test_rotator_wrong_cardinal_cycle_rejected(self):
        self.rejects(lambda rows:next(r for r in rows if r.get('kind')=='rotate_right')['cars'][0].update(dir=8))
    def test_boundary_collision_damage_not_suppressed(self):
        self.rejects(lambda rows:next(r for r in reversed(rows) if r['case']=='blocked_switch_target' and r['event']=='frame')['cars'][0].update(health=1000))
    def test_lever_outside_radius_rejected(self):
        self.rejects(lambda rows:next(r for r in rows if r.get('kind')=='lever')['switches'][-1].update(state='split'))


if __name__=='__main__':unittest.main()
