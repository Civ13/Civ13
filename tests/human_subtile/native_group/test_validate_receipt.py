import copy, unittest
from validate_receipt import validate, ReceiptError

def actor(life,x,sx=0,step=32):
    return {'lifetime':life,'x':x,'y':3,'z':1,'sx':sx,'sy':0,'step_size':step,'bound_x':0,'bound_y':0,'bound_width':32,'bound_height':32,'appearance_flags':0,'tile_mover':0,'density':1}

def case(name,i):
    a=actor(f'{i}:a',2,0,2 if name=='pixel' else 32);b=actor(f'{i}:b',6 if name=='reach' else 3)
    af=copy.deepcopy(a);bf=copy.deepcopy(b)
    if name in ('reach','group'):af['x']=3
    if name=='group':bf['x']=2
    if name=='pixel':af['sx']=2
    forward=int(name in ('group','pixel'));events=[]
    def add(kind,rec='a',sub='a',aa=None,bb=None,depth=0,turf=None):
        events.append({'ordinal':len(events)+1,'time':10,'case':name,'kind':kind,'receiver':rec,'receiver_turf':turf,'subject':sub,'bump_depth':depth,'result':None,'a':copy.deepcopy(aa or a),'b':copy.deepcopy(bb or b),'a_in_b_group':forward,'b_in_a_group':0})
    add('attempt_begin',sub='b');add('move_enter')
    if name=='reach':
        origin={'x':2,'y':3,'z':1};dest={'x':3,'y':3,'z':1}
        add('exited_before','turf','a',turf=origin);add('exited_after','turf','a',turf=origin)
        add('entered_before','turf','a',af,bf,turf=dest);add('entered_after','turf','a',af,bf,turf=dest)
    if name in ('no_group','group'):
        add('bump_enter','a','b',depth=1)
        if name=='group':
            dest={'x':3,'y':3,'z':1}
            add('entered_before','turf','a',af,bf,1,dest);add('entered_after','turf','a',af,bf,1,dest)
        add('bump_exit','a','b',af,bf,1)
    add('move_exit','a','a',af,bf);add('attempt_return','a','b',af,bf);events[-1]['result']=1;add('settled','a','b',af,bf);events[-1]['time']=10.5
    return {'case':name,'lifetime':i,'start_a':a,'start_b':b,'a_in_b_group':forward,'b_in_a_group':0,'move_return':1,'end_a':af,'end_b':bf,'overflow':0,'final_bump_depth':0,'events':events}

def good():
    rows=[case(n,i) for i,n in enumerate(('reach','no_group','group','pixel'),1)]
    return {'schema':1,'kind':'native_group_bump_observation','version':516,'build':1688,'movement_mode':0,'legacy_mode':0,'tick_lag':0.5,'icon_size':32,'maxx':8,'maxy':6,'maxz':1,'failure':None,'cases':rows,'partial_case':'pixel','partial_events':copy.deepcopy(rows[-1]['events'])}

def event(r,case,kind):return next(e for e in r['cases'][case]['events'] if e['kind']==kind)
def remove_events(row,*kinds):
    row['events']=[e for e in row['events'] if e['kind'] not in kinds]
    for i,e in enumerate(row['events'],1):e['ordinal']=i

class ReceiptTests(unittest.TestCase):
    def test_controlled_valid(self):self.assertEqual(validate(good())['status'],'observed_consistent_on_this_trace')
    def test_no_application_anchor_field(self):
        self.assertNotIn('anchored', good()['cases'][0]['start_a'])
        self.assertEqual(validate(good())['status'], 'observed_consistent_on_this_trace')
    def test_wrong_mode(self):
        r=good();r['movement_mode']=1
        with self.assertRaises(ReceiptError):validate(r)
    def test_no_observer_reachability(self):
        r=good();remove_events(r['cases'][0],'exited_before','exited_after')
        with self.assertRaises(ReceiptError):validate(r)
    def test_no_notification_is_inconclusive(self):
        r=good();remove_events(r['cases'][2],'entered_before','entered_after')
        self.assertEqual(validate(r)['status'],'inconclusive_no_postcommit_notification')
    def test_intermediate_callback_fails_observation(self):
        r=good();event(r,2,'entered_before')['b']['x']=3
        self.assertEqual(validate(r)['status'],'observed_intermediate_state')
    def test_intermediate_move_exit_fails_observation(self):
        r=good();event(r,2,'move_exit')['b']['x']=3
        self.assertEqual(validate(r)['status'],'observed_intermediate_state')
    def test_intermediate_bump_exit_fails_observation(self):
        r=good();event(r,2,'bump_exit')['b']['x']=3
        self.assertEqual(validate(r)['status'],'observed_intermediate_state')
    def test_wrong_directed_group(self):
        r=good();r['cases'][2]['b_in_a_group']=1
        with self.assertRaises(ReceiptError):validate(r)
    def test_missing_geometry(self):
        r=good();del r['cases'][2]['start_a']['bound_width']
        with self.assertRaises(ReceiptError):validate(r)
    def test_wrong_step_size(self):
        r=good();r['cases'][2]['start_a']['step_size']=2
        with self.assertRaises(ReceiptError):validate(r)
    def test_tile_mover_flag(self):
        r=good();r['cases'][2]['start_a']['tile_mover']=1
        with self.assertRaises(ReceiptError):validate(r)
    def test_group_no_bump_is_unsupported(self):
        r=good();remove_events(r['cases'][2],'bump_enter','bump_exit','entered_before','entered_after')
        self.assertEqual(validate(r)['status'],'unsupported_no_group_bump')
    def test_no_group_must_not_displace(self):
        r=good();r['cases'][1]['end_b']['x']=2;r['cases'][1]['events'][-1]['b']['x']=2
        with self.assertRaises(ReceiptError):validate(r)
    def test_pixel_exchange_is_observation(self):
        r=good();r['cases'][3]['end_a']['x']=3;r['cases'][3]['end_b']['x']=2;r['cases'][3]['events'][-1]['a']['x']=3;r['cases'][3]['events'][-1]['b']['x']=2;r['partial_events']=copy.deepcopy(r['cases'][3]['events'])
        self.assertEqual(validate(r)['status'],'observed_pixel_exchange')
    def test_overflow_is_not_pass(self):
        r=good();r['cases'][2]['overflow']=1
        with self.assertRaises(ReceiptError):validate(r)
    def test_lifetime_mismatch(self):
        r=good();event(r,2,'bump_enter')['a']['lifetime']='1:a'
        with self.assertRaises(ReceiptError):validate(r)
    def test_nonfinite_time(self):
        r=good();event(r,2,'bump_enter')['time']=float('nan')
        with self.assertRaises(ReceiptError):validate(r)
    def test_late_geometry_mutation(self):
        r=good();event(r,2,'entered_before')['a']['step_size']=2
        with self.assertRaises(ReceiptError):validate(r)
    def test_missing_bump_return(self):
        r=good();remove_events(r['cases'][2],'bump_exit')
        with self.assertRaises(ReceiptError):validate(r)
    def test_missing_move_return(self):
        r=good();remove_events(r['cases'][2],'move_exit')
        with self.assertRaises(ReceiptError):validate(r)
    def test_missing_callback_return(self):
        r=good();remove_events(r['cases'][2],'entered_after')
        with self.assertRaises(ReceiptError):validate(r)
    def test_callback_turf_receiver_mismatch(self):
        r=good();e=event(r,2,'entered_after');e['receiver_turf']=dict(e['receiver_turf'],x=4)
        with self.assertRaises(ReceiptError):validate(r)
    def test_missing_event_result_field(self):
        r=good();del event(r,2,'entered_after')['result']
        with self.assertRaises(ReceiptError):validate(r)
    def test_unknown_kind(self):
        r=good();event(r,2,'entered_after')['kind']='invented_after'
        with self.assertRaises(ReceiptError):validate(r)
    def test_missing_observation_tick(self):
        r=good();r['cases'][2]['events'][-1]['time']=10
        with self.assertRaises(ReceiptError):validate(r)
    def test_nogroup_transient_displacement(self):
        r=good();event(r,1,'bump_enter')['a']['sx']=2
        with self.assertRaises(ReceiptError):validate(r)
    def test_partial_capture_mismatch(self):
        r=good();r['partial_events']=[]
        with self.assertRaises(ReceiptError):validate(r)
if __name__=='__main__':unittest.main(verbosity=2)
