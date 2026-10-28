"""Bounded phase/normal-disconnect evidence, never OS-close or keyboard proof."""
import json,math
SOURCE='5260b60f0efef2c0af70fae204b1180106ef50b3'
PHASES=['observer_before','driver_login','east_handler','south_handler','drive_start','drive_end','observer_after','disconnect_requested']
def need(ok,why):
 if not ok:raise ValueError(why)
def validate_window(r, phases):
 need(type(r) is dict and type(phases) is str,'window/phase evidence missing')
 rows=[json.loads(x) for x in phases.splitlines() if x.strip()]
 matches=[x for x in rows if x.get('phase')=='south_handler']
 need(len(matches)==1,'one actual driver-ready phase required')
 phase=matches[0]
 need(phase.get('source')==SOURCE and all(r.get(k)==phase.get(k) and type(r.get(k)) is str and bool(r[k]) for k in ('client','body','driver')),'window/client/body phase mismatch')
 need(r.get('source')==SOURCE and r.get('phase')=='driver_ready','window source/phase')
 title=r.get('title');need(type(title) is str and 0<len(title)<=128 and all(ord(x)>=32 for x in title),'bounded exact native title')
 need(title==r.get('expected_title')=='Civ13 carriage take' and r.get('control_id')=='cloud','native title differs from exact fixture cloud title')
 need(r.get('production_login_title_effect_accepted')==0,'fixture window is not production Login title-effect acceptance')
 need(r.get('driver_attached')==1 and r.get('eye_is_driver')==1,'window driver admission')
 return title

def validate_connected(text,disconnected,cadence_start,cadence_end):
 need(type(text) is str and type(disconnected) is dict and type(cadence_start) is dict and type(cadence_end) is dict,'phase/disconnect/cadence receipt missing')
 rows=[json.loads(x) for x in text.splitlines() if x.strip()]
 need(len(rows)==8 and [r.get('phase') for r in rows]==PHASES,'phase sequence')
 client=rows[0].get('client');observer=rows[0].get('body');driver=rows[0].get('driver')
 need(all(type(x) is str and 0<len(x)<64 for x in (client,observer,driver)) and observer!=driver,'actual identity references')
 for i,r in enumerate(rows):
  need(r.get('source')==SOURCE and r.get('probe')=='connected_driver_source_v1' and r.get('client')==client and r.get('driver')==driver,'exact source/client/driver')
  for f in ('time','body_glide','client_glide','client_fps','world_fps'):need(type(r.get(f)) in (int,float) and math.isfinite(r[f]) and r[f]>=0,'finite phase observation')
  if 1<=i<=5:need(r.get('body')==driver and r.get('eye')==driver and r.get('driver_attached')==1 and r.get('eye_is_body')==1 and r.get('mob_perspective')==1,'driver camera phase')
  else:need(r.get('body')==observer and r.get('observer')==1 and r.get('driver_attached')==0,'observer phase')
  if i:need(r['time']>=rows[i-1]['time'],'ordered native clock')
 for phase,r in [('start',cadence_start),('end',cadence_end)]:
  need(r.get('phase')==phase and r.get('same_admitted_client')==1 and r.get('client_fps')==20 and r.get('world_fps')==20,'unchanged native capture cadence')
 need(all(rows[i]['client_fps']==20 and rows[i]['world_fps']==20 for i in (4,5)),'phase/capture cadence agreement')
 need(rows[6].get('visual_owned')==0 and rows[7].get('visual_owned')==0,'native Logout visual retirement')
 d=disconnected;need(d.get('source')==SOURCE and d.get('probe')=='connected_driver_disconnect_v1' and d.get('client')==client and d.get('method')=='server_del_client' and d.get('user_window_close')==0,'server-initiated exact disconnect')
 for f in ('client_deleted','directory_key_absent','visual_owner_absent','profile_store_absent'):need(d.get(f)==1,'missing post-Del evidence: '+f)
 need(type(d.get('time')) in (int,float) and math.isfinite(d['time']) and d['time']>=rows[-1]['time'],'post-Del server clock')
 return dict(status='NATIVE_CONNECTED_PHASES_RECORDED_REVIEW_REQUIRED',phases=8,normal_disconnect='server_del_client',user_window_close=False,keyboard_input_proven=False,walking_ownership_exercised=any(r.get('visual_owned')==1 for r in rows),accepted_for_marketing=False)
