import unittest
from fast_result import validate
class FastResult(unittest.TestCase):
 def test_fractional_request_is_not_observed_scheduler_time(self):
  rows=[dict(tick=t,interval=11 if i==0 else 2.6,gear=1 if i==0 else 3,x=8,y=9-i) for i,t in enumerate([100,111,114,117,120,123])]
  result=dict(probe='production_fast_collision_v1',source='5260b60f0efef2c0af70fae204b1180106ef50b3',complete=1,steps=rows,collision_count=1)
  self.assertEqual(validate(result)['observed_intervals'],[11,3,3,3,3])
  for change in ({'source':'wrong'},{'collision_count':0},{'complete':0},{'steps':rows[:-1]}):
   with self.assertRaises(ValueError):validate({**result,**change})
