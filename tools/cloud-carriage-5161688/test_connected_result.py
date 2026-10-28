import unittest,json
from connected_result import SOURCE,PHASES,validate_connected,validate_window
class ConnectedResult(unittest.TestCase):
 def fixture(self):
  rows=[dict(probe='connected_driver_source_v1',source=SOURCE,phase=p,client='c',body='d' if 1<=i<=5 else 'o',driver='d',eye='d' if 1<=i<=5 else 'camera',observer=int(i in (0,6,7)),driver_attached=int(1<=i<=5),eye_is_body=int(1<=i<=5),mob_perspective=int(1<=i<=5),time=i,body_glide=0,client_glide=0,client_fps=20,world_fps=20,visual_owned=0) for i,p in enumerate(PHASES)]
  d=dict(probe='connected_driver_disconnect_v1',source=SOURCE,client='c',method='server_del_client',user_window_close=0,client_deleted=1,directory_key_absent=1,visual_owner_absent=1,profile_store_absent=1,time=8)
  start=dict(phase='start',same_admitted_client=1,client_fps=20,world_fps=20);end=dict(start,phase='end');return rows,d,start,end
 def call(self,r,d,s,e):return validate_connected('\n'.join(map(json.dumps,r)),d,s,e)
 def test_native_disconnect_not_job_kill_or_user_close(self):
  r,d,s,e=self.fixture();self.assertEqual(self.call(r,d,s,e)['normal_disconnect'],'server_del_client');self.assertFalse(self.call(r,d,s,e)['walking_ownership_exercised'])
  with self.assertRaises(ValueError):self.call(r,None,s,e)
  for k,v in [('method','terminate_job'),('client_deleted',0),('directory_key_absent',0),('visual_owner_absent',0),('profile_store_absent',0),('user_window_close',1),('client','other'),('time',-1)]:
   with self.subTest(key=k),self.assertRaises(ValueError):self.call(r,{**d,k:v},s,e)
 def test_identity_camera_and_cadence_cannot_be_normalized(self):
  for i,k,v in [(4,'client','other'),(4,'eye','o'),(5,'mob_perspective',0),(4,'client_fps',60),(5,'world_fps',60),(6,'visual_owned',1)]:
   r,d,s,e=self.fixture();r[i][k]=v
   with self.subTest(key=k),self.assertRaises(ValueError):self.call(r,d,s,e)
 def test_bounded_native_window_receipt(self):
  rows,d,s,e=self.fixture();phases='\n'.join(map(json.dumps,rows))
  r=dict(source=SOURCE,phase='driver_ready',title='Civ13 carriage take',expected_title='Civ13 carriage take',control_id='cloud',production_login_title_effect_accepted=0,client='c',body='d',driver='d',driver_attached=1,eye_is_driver=1);self.assertEqual(validate_window(r,phases),'Civ13 carriage take')
  for change in [dict(control_id='mainwindow'),dict(production_login_title_effect_accepted=1),dict(title='other',expected_title='other'),dict(title='x'*129),dict(title='bad\ntitle'),dict(title='different'),dict(driver_attached=0),dict(source='wrong'),dict(client='other'),dict(body='o')]:
   with self.assertRaises(ValueError):validate_window({**r,**change},phases)
  with self.assertRaises(ValueError):validate_window(None,phases)
