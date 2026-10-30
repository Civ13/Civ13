import copy, json, tempfile, unittest
from pathlib import Path
import activation
from preflight_result import validate
from route_receipt_check import load_routes, REVISION, MAP_SHA, CROP_SHA

HERE=Path(__file__).resolve().parent

class CityPreflight(unittest.TestCase):
    def setUp(self):
        routes=load_routes(HERE/'route.json')
        def steps(path,item,start):
            return [{'xy':p,'actor':'courier','object':item,'held':1,'door_open':1,'time_ds':start+i} for i,p in enumerate(path)]
        ms=2+len(routes[0]); mf=ms+10; end=mf+len(routes[1])
        self.data={
          'city-route-receipt.json':{'schema':1,'source_revision':REVISION,'map_sha256':MAP_SHA,'crop_sha256':CROP_SHA,'scripted_actors':1,'capture_performed':0,'courier':'courier','baker':'baker','wheat':'wheat','flour':'flour','events':[
            {'phase':'harvest','time_ds':1,'actor':'courier','output':'wheat','ready_harvest':1,'normal_handler':1},
            {'phase':'route_to_mill','time_ds':ms-1,'actor':'courier','object':'wheat','steps':steps(routes[0],'wheat',2)},
            {'phase':'mill_start','time_ds':ms,'actor':'courier','input':'wheat','normal_handler':1},
            {'phase':'mill_finish','time_ds':mf,'input':'wheat','output':'flour','completed':1},
            {'phase':'route_to_bakery','time_ds':end,'actor':'courier','object':'flour','steps':steps(routes[1],'flour',mf+1)},
            {'phase':'flour_handoff','time_ds':end+1,'from':'courier','to':'baker','object':'flour','normal_handler':1}]},
          'city-bakery-receipt.json':{'flour':'flour','dough':'dough','bread':'bread','customer':'customer','picked_ref':'bread','placed_ref':'bread','received_ref':'bread','customer_holds_output':1,'fuel_paid':1,'flour_paid':5,'water_paid':5,'mixed_at':end+2,'cook_started':end+3,'produced_at':end+53,'time':end+160,'cooking_time':50,'departure':{'customer':'customer','bread':'bread','x':76,'y':54,'z':1,'dir':4,'driver_bound':1,'horse_bound':1,'bread_in_inactive_hand':1,'reins_in_active_hand':1,'moving':0,'speed':0,'boarding_started':end+100,'boarded_at':end+140,'route':[{'x':x,'y':y,'bread':'bread','time':end+60+4*i} for i,(x,y) in enumerate([(74,59),(74,58),(74,57),(73,57),(73,56),(73,55),(73,54)])]}},
          'city-train-before.json':{'phase':'train_staged','engine':'engine','fireman':'fireman','brakeman':'brake','health':1000,'x':83,'y':54,'z':1,'rail_count':8},
          'city-train-after.json':{'phase':'train_complete','engine':'engine','fireman':'fireman','brakeman':'brake','coal':'coal','health':1000,'x':85,'y':54,'z':1,'rail_count':8,'on':0,'automovement':0,'fueled_at':end+170,'started_at':end+171,'arrived_at':end+173,'stopped_at':end+174,'time':end+189}}
    def verify(self,data):
        with tempfile.TemporaryDirectory() as d:
            for name,row in data.items(): (Path(d)/name).write_text(json.dumps(row),encoding='utf-8')
            return validate(d,HERE/'route.json')
    def test_complete_receipts_are_preflight_only(self):
        self.assertFalse(self.verify(self.data)['capture_performed'])
    def test_reject_changed_loaf_or_unpaid_inputs(self):
        for key,value in [('received_ref','other'),('flour_paid',0),('cooking_time',1)]:
            data=copy.deepcopy(self.data);data['city-bakery-receipt.json'][key]=value
            with self.assertRaises(ValueError): self.verify(data)
        data=copy.deepcopy(self.data);data['city-bakery-receipt.json']['departure']['bread']='other'
        with self.assertRaises(ValueError):self.verify(data)
    def test_reject_changed_engine_or_failed_stop(self):
        for key,value in [('engine','other'),('health',900),('x',84),('on',1)]:
            data=copy.deepcopy(self.data);data['city-train-after.json'][key]=value
            with self.assertRaises(ValueError): self.verify(data)
    def test_reject_missing_receipt_and_closed_door(self):
        data=copy.deepcopy(self.data); del data['city-train-after.json']
        with self.assertRaises(ValueError):self.verify(data)
        data=copy.deepcopy(self.data)
        row=next(r for r in data['city-route-receipt.json']['events'][1]['steps'] if r['xy']==[85,95]);row['door_open']=0
        with self.assertRaises(ValueError):self.verify(data)
    def test_held_controller_cannot_enable_recording(self):
        for state in (False,True):
            self.assertEqual(activation.validate_release_states(state,state,False),state)
            with self.assertRaises(RuntimeError):activation.validate_release_states(state,state,True)
        run=(HERE/'run_scene.py').read_text(encoding='utf-8')
        self.assertNotIn('record_scene(',run)
        self.assertIn("< 240, 'Shared 240-second",run)
        self.assertIn('270-(time.monotonic()-started)',run)
        released=json.loads((HERE/'activation.json').read_text(encoding='utf-8'))['released']
        self.assertIn("if: >-\n      "+('true' if released else 'false')+" &&",(HERE/'workflow.reference.txt').read_text(encoding='utf-8'))

if __name__=='__main__':unittest.main()
