"""Offline source-result contract, not a claim of native scheduler precision."""
import math
SOURCE='5260b60f0efef2c0af70fae204b1180106ef50b3'
def validate(result):
 def need(x,s):
  if not x:raise ValueError(s)
 need(result.get('probe')=='production_fast_collision_v1' and result.get('source')==SOURCE and result.get('complete')==1,'identity/completion')
 rows=result.get('steps');need(isinstance(rows,list) and len(rows)==6 and result.get('collision_count')==1,'six steps and one collision')
 for i,r in enumerate(rows):
  need((r.get('x'),r.get('y'))==(8,9-i),'route')
  need(abs(r.get('interval',0)-(11 if i==0 else 2.6))<1e-5 and r.get('gear')==(1 if i==0 else 3),'production gear')
  need(type(r.get('tick')) in (int,float) and math.isfinite(r['tick']),'clock')
 observed=[rows[i+1]['tick']-rows[i]['tick'] for i in range(5)]
 need(observed[0]==11 and all(2.5<=v<=3.5 for v in observed[1:]),'bounded observed scheduling; no rounding assumption')
 return dict(status='NATIVE_FAST_COLLISION_ASSERTIONS_PIXELS_PENDING',requested_intervals=[r['interval'] for r in rows],observed_intervals=observed,accepted_for_marketing=False,connected_driver_accepted=False)
