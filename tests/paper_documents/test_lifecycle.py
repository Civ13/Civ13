"""Complete lifecycle procedures projected with explicit inert observer/UI seams.
The engine moved/destroyed dispatch and recursive location semantics are models,
not native BYOND event ordering, client cleanup or save/load acceptance.
"""
import importlib.util,json,re,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('lifecycle_core_fixture',Path(__file__).with_name('test_authoring.py'))
core=importlib.util.module_from_spec(spec);spec.loader.exec_module(core)
vm=core.vm;EN=core.EN;RU=core.RU
SOURCE=(vm.ROOT/'code/modules/paperwork/lifecycle.dm').read_text(encoding='utf-8')

def environment(source=SOURCE):
 env,Session,Base,Reader,langs,render,Paper=core.environment()
 vm.Actor.gc_destroyed=False
 def movable(x):return isinstance(x,(vm.Actor,vm.Pen,Paper,core.copies.views.Container))
 class Event:
  def __init__(self,kind):self.kind=kind;self.event_sources={};self.fail_source=None
  def register(self,subject,listener,callback):
   if subject is self.fail_source:return False
   callbacks=self.event_sources.setdefault(subject,{}).setdefault(listener,set())
   if callback in callbacks:return False
   callbacks.add(callback)
   if self.kind=='move' and movable(getattr(subject,'loc',None)):
    self.register(subject.loc,subject,'/atom/movable/proc/recursive_move')
   return True
  def unregister(self,subject,listener,callback):
   listeners=self.event_sources.get(subject,{});callbacks=listeners.get(listener,set())
   if callback not in callbacks:return False
   callbacks.remove(callback)
   if not callbacks:listeners.pop(listener,None)
   if not listeners:self.event_sources.pop(subject,None)
   return True
  def has_listeners(self,subject):return bool(self.event_sources.get(subject))
  def emit(self,subject,*args):
   # Explicit engine dispatch seam. Production private notify() is projected.
   for listener,callbacks in list(self.event_sources.get(subject,{}).items()):
    for callback in list(callbacks):
     if callback=='/atom/movable/proc/recursive_move':self.emit(listener,*args)
     else:getattr(listener,callback.rsplit('/',1)[1])(subject,*args)
  def count(self):return sum(len(c) for listeners in self.event_sources.values() for c in listeners.values())
 glob=vm.Ref()
 for name,kind in [('paper_authoring_event','private'),('destroyed_event','destroy'),('moved_event','move'),('name_set_event','name'),('stat_set_event','stat')]:
  setattr(glob,name,Event(kind))
 events=[glob.paper_authoring_event,glob.destroyed_event,glob.moved_event,glob.name_set_event,glob.stat_set_event]
 class UI(vm.Ref):
  gc_destroyed=False
  def __init__(self,paper,actor):
   self.src_object=paper;self.user=actor;self.ref=None;self.on_close_logic=True;self.closed=0
  def use_on_close_logic(self,flag):self.on_close_logic=flag
  def close(self):
   self.closed+=1;env['paper_authoring_notify'](self,'close')
   # A hypothetical client close handler may apply the inherited machine logic.
   # Source contracts below bind FALSE to actual nanoclose behavior.
   if self.on_close_logic:self.user.using_object=None
 original_type=env['istype']
 def istype(value,path=None):
  if path=='/atom/movable':return movable(value)
  if path in ('/datum/nanoui','/datum/nanoui/tgui'):return isinstance(value,UI)
  return original_type(value,path)
 errors=[]
 env.update(GLOB=glob,istype=istype,Exception=Exception,error=errors.append,errors=errors,get_dist=lambda a,b: -1 if getattr(a,"z",1)!=getattr(b,"z",1) else abs(getattr(a,"x",0)-getattr(b,"x",0)))
 vm.METHODS |= {'register','unregister','has_listeners','notify','copy','close','use_on_close_logic',
  'lifecycle_physical_current','watch_lifecycle_source','plan_lifecycle','start_lifecycle','stop_lifecycle','unwatch_movement','lifecycle_signal','lifecycle_moved','lifecycle_destroyed','lifecycle_status','lifecycle_named','retire'}
 vm.ALLOWED |= {'paper_authoring_notify','get_dist','error'}
 adapted=source.replace('event_sources[source]','event_sources.get(source)').replace('listeners.Copy()','listeners.copy()')
 adapted=adapted.replace('lifecycle_sources += source','lifecycle_sources.append(source)').replace('seen += mover','seen.append(mover)').replace('seen += node','seen.append(node)').replace('planned += node','planned.append(node)').replace('links += list(list("mover" = node, "parent" = node.loc))','links.append({"mover":node,"parent":node.loc})')
 fields=('lifecycle_sources','lifecycle_bound','authoring_ui','lifecycle_links','writing_pen','session_closed','session_lease','context_owner','context_parent')
 methods=('lifecycle_physical_current','watch_lifecycle_source','plan_lifecycle','start_lifecycle','stop_lifecycle','unwatch_movement','retire')
 pieces=re.split(r'("(?:[^"\\]|\\.)*")',adapted)
 for i in range(0,len(pieces),2):
  pieces[i]=re.sub(r'(?<![\w./])src\b','self',pieces[i])
  pieces[i]=re.sub(r'(?<![\w./])('+'|'.join(fields)+r')\b',lambda m:'self.'+m[1],pieces[i])
  pieces[i]=re.sub(r'(?<![\w./])('+'|'.join(methods)+r')\(',lambda m:'self.'+m[1]+'(',pieces[i])
 adapted=''.join(pieces)
 # event_sources belongs to the event object, never to the service.
 bus=adapted.replace('event_sources.get(source)','self.event_sources.get(source)')
 Event.notify=vm.project(bus,'/decl/observ/paper_authoring/proc/notify','self,source,reason,exempt=None',env)
 env['paper_authoring_notify']=vm.project(adapted,'/proc/paper_authoring_notify','source,reason,exempt=None',env)
 old_init=Session.__init__
 def init(self,paper,actor,pen):
  old_init(self,paper,actor,pen);self.lifecycle_sources=None;self.lifecycle_links=None;self.lifecycle_bound=False;self.authoring_ui=None
 Session.__init__=init
 for name,args in [('lifecycle_physical_current','self'),('watch_lifecycle_source','self,source'),('plan_lifecycle','self'),('start_lifecycle','self'),('unwatch_movement','self,source'),('stop_lifecycle','self'),('bind_ui','self,actor,lease,ui'),('lifecycle_signal','self,source,reason'),('lifecycle_moved','self,source,old_loc,new_loc'),('lifecycle_destroyed','self,source'),('lifecycle_status','self,source,old_stat,new_stat'),('lifecycle_named','self,source,old_name,new_name')]:
  setattr(Session,name,vm.project(adapted,'/datum/paper_document_authoring/proc/'+name,args,env,True))
 return env,Session,Base,Reader,langs,render,Paper,glob,events,UI

class Lifecycle(unittest.TestCase):
 def setUp(self):
  self.env,self.Session,self.Base,self.Reader,self.langs,self.render,self.Paper,self.glob,self.events,self.UI=environment()
  self.actor=vm.Actor();self.actor.loc=core.copies.Turf();self.actor.languages=[self.langs[EN],self.langs[RU]]
  self.pen=vm.Pen(self.actor);self.paper=self.Paper(self.actor);self.paper.near=True;self.paper.Adjacent=lambda a:self.paper.near
  self.session=self.Session(self.paper,self.actor,self.pen)
 def start(self):
  self.assertTrue(self.session.begin(self.actor));return self.session.session_lease
 def notify(self,source,reason,exempt=None):return self.env['paper_authoring_notify'](source,reason,exempt)
 def ui(self,session=None):
  s=session or self.session;ui=self.UI(self.paper,self.actor);self.assertTrue(s.bind_ui(self.actor,s.session_lease,ui));return ui
 def append(self,s=None,text='FIRST',language=EN):
  s=s or self.session;data=s.snapshot(self.actor)
  return s.append(self.actor,self.pen,data['document_id'],data['revision'],language,'body',text,data['lease'])
 def assert_clean(self):self.assertTrue(all(e.count()==0 for e in self.events),[(e.kind,e.count()) for e in self.events])
 def test_inactive_open_cancel_and_no_observer_residue(self):
  self.assert_clean();before=self.paper.info;self.start()
  self.assertTrue(self.session.lifecycle_bound);self.assertEqual(len(self.session.lifecycle_sources),3)
  self.assertTrue(self.session.cancel(self.actor,self.session.session_lease));self.assert_clean()
  self.assertIsNone(self.paper.document_record);self.assertEqual(before,self.paper.info)
  self.session.retire();self.assert_clean()
 def test_carried_walking_uses_physical_checks_without_document_serialization(self):
  self.start();old=self.actor.loc;new=core.copies.Turf();self.actor.loc=new
  saved=self.env['json_encode'];self.env['json_encode']=lambda value:(_ for _ in ()).throw(AssertionError('Movement serialized a record'))
  self.glob.moved_event.emit(self.actor,old,new);self.assertFalse(self.session.session_closed)
  self.env['json_encode']=saved;self.assertTrue(self.append())
 def test_paper_pen_and_container_departure_return_cannot_revive_lease(self):
  for kind in ('paper','pen','folder'):
   self.setUp();target=self.paper if kind=='paper' else self.pen
   if kind=='folder':
    target=core.copies.views.Container('folder',self.actor);self.paper.loc=target
   lease=self.start();old=target.loc;new=core.copies.Turf()
   # Model the first observed callback being the nested return, after loc restored.
   target.loc=old;self.glob.moved_event.emit(target,new,old)
   self.assertTrue(self.session.session_closed);self.assert_clean()
   self.assertFalse(self.session.append(self.actor,self.pen,None,0,EN,'body','STALE',lease))
   self.session.lifecycle_moved(target,old,new) # delayed callback is inert
 def test_raw_relocation_and_lost_floor_range_are_sticky(self):
  self.start();self.paper.loc=self.actor.loc;self.notify(self.paper,'relocated')
  self.paper.loc=self.actor;self.assertTrue(self.session.session_closed);self.assert_clean()
  self.setUp();self.paper.loc=self.actor.loc;self.start()
  self.paper.near=False;self.glob.moved_event.emit(self.actor,self.actor.loc,core.copies.Turf())
  self.paper.near=True;self.assertTrue(self.session.session_closed);self.assert_clean()
 def test_hand_switch_unequip_and_stat_excursions_retire(self):
  for event in ('hand','custody','stat'):
   self.setUp();self.start()
   if event=='hand':self.notify(self.actor,'hand')
   elif event=='custody':self.notify(self.pen,'custody')
   else:
    self.actor.stat=1;self.glob.stat_set_event.emit(self.actor,0,1);self.actor.stat=0
   self.assertTrue(self.session.session_closed);self.assert_clean()
 def test_logout_and_pre_client_transfer_retire_unbound_sessions(self):
  for reason in ('logout','transfer'):
   self.setUp();lease=self.start();oldclient=self.actor.client
   self.notify(self.actor,reason) # before client/key reassignment
   other=vm.Actor();other.client=oldclient;oldclient.mob=other;self.actor.client=None
   self.assertTrue(self.session.session_closed);self.assert_clean()
   self.assertFalse(self.session.append(other,self.pen,None,0,EN,'body','STALE',lease))
 def test_ui_close_idempotence_and_machine_noninterference(self):
  self.start();ui=self.ui();self.actor.using_object='unrelated machine'
  self.assertFalse(ui.on_close_logic);ui.close()
  self.assertEqual(ui.closed,1);self.assertEqual(self.actor.using_object,'unrelated machine')
  self.assertTrue(self.session.session_closed);self.assertIsNone(self.session.authoring_ui);self.assert_clean()
 def test_logout_snapshot_dispatch_retires_multiple_sessions_and_owned_windows(self):
  self.start();first=self.ui();other=self.Session(self.paper,self.actor,self.pen);self.assertTrue(other.begin(self.actor));second=self.ui(other)
  self.notify(self.actor,'logout')
  self.assertTrue(self.session.session_closed and other.session_closed);self.assertEqual((first.closed,second.closed),(1,1));self.assert_clean()
 def test_destroyed_subject_and_destroyed_window_cleanup(self):
  for kind in ('paper','pen','actor','ui'):
   self.setUp();self.start();ui=self.ui();target={'paper':self.paper,'pen':self.pen,'actor':self.actor,'ui':ui}[kind]
   target.gc_destroyed=True;self.glob.destroyed_event.emit(target)
   self.assertTrue(self.session.session_closed);self.assertEqual(ui.closed,1);self.assert_clean()
 def test_partial_subscriptions_and_failed_ui_bind_leave_no_refs(self):
  self.glob.destroyed_event.fail_source=self.pen
  self.assertFalse(self.session.begin(self.actor));self.assertTrue(self.session.session_closed);self.assertIsNone(self.paper.document_record);self.assert_clean()
  self.setUp();self.start();ui=self.UI(self.paper,self.actor);self.glob.paper_authoring_event.fail_source=ui
  self.assertFalse(self.session.bind_ui(self.actor,self.session.session_lease,ui))
  self.assertEqual(ui.closed,1);self.assert_clean();self.assertIsNone(self.session.paper)
 def test_foreign_ui_and_shared_ui_rejected_without_closing_owner(self):
  self.start();ui=self.ui();other=self.Session(self.paper,self.actor,self.pen);self.assertTrue(other.begin(self.actor))
  self.assertFalse(other.bind_ui(self.actor,other.session_lease,ui));self.assertEqual(ui.closed,0)
  foreign=self.UI(self.paper,vm.Actor())
  self.assertFalse(other.bind_ui(self.actor,other.session_lease,foreign));self.assertTrue(foreign.on_close_logic)
  foreign_ref=self.UI(self.paper,self.actor);foreign_ref.ref=vm.Ref()
  self.assertFalse(other.bind_ui(self.actor,other.session_lease,foreign_ref));self.assertTrue(foreign_ref.on_close_logic)
  self.assertFalse(other.bind_ui(self.actor,other.session_lease,vm.Ref()))
  self.session.retire();other.retire();self.assert_clean()
 def test_commits_retire_peers_preserve_author_and_keep_unknown_text_private(self):
  self.start();other=self.Session(self.paper,self.actor,self.pen);self.assertTrue(other.begin(self.actor));ui=self.ui(other)
  self.assertTrue(self.append(text='UNKNOWN_BODY_CANARY',language=RU))
  self.assertTrue(other.session_closed);self.assertEqual(ui.closed,1);self.assertFalse(self.session.session_closed)
  self.assertTrue(self.append(text='KNOWN_BODY',language=EN))
  self.actor.languages=[self.langs[EN]];data=self.session.snapshot(self.actor)
  self.assertNotIn('UNKNOWN_BODY_CANARY',json.dumps(data));self.assertIn('KNOWN_BODY',json.dumps(data))
  self.session.retire();self.assert_clean()
 def test_external_physical_write_restore_and_name_change_are_sticky(self):
  for reason in ('physical','name'):
   self.setUp();self.start();before=self.paper.info
   if reason=='physical':
    self.paper.info+='external';self.notify(self.paper,'physical');self.paper.info=before
   else:self.glob.name_set_event.emit(self.paper,'old','new')
   self.assertTrue(self.session.session_closed);self.assert_clean()
 def test_shared_movement_forwarders_preserve_unrelated_listener(self):
  self.start();foreign=vm.Ref();path='/datum/proc/foreign'
  self.glob.moved_event.register(self.pen,foreign,path)
  self.session.retire()
  self.assertIn(foreign,self.glob.moved_event.event_sources[self.pen])
  self.assertIn(self.pen,self.glob.moved_event.event_sources[self.actor])
  self.assertTrue(all(not listeners.get(self.session) for e in self.events for listeners in e.event_sources.values()))
 def test_hooks_and_runtime_exclusions_are_exact_and_no_activation_or_learning(self):
  def body(path,signature):return vm.body((vm.ROOT/path).read_text(),signature)
  logout=body('code/modules/nano/nanomanager.dm','/datum/nanomanager/proc/user_logout')
  transfer=body('code/modules/nano/nanomanager.dm','/datum/nanomanager/proc/user_transferred')
  self.assertLess(logout.index('paper_authoring_notify(user, "logout")'),logout.index('return close_user_uis'))
  self.assertLess(transfer.index('paper_authoring_notify(oldMob, "transfer")'),transfer.index('if (!oldMob'))
  close=body('code/modules/nano/_nanoui.dm','/datum/nanoui/proc/close')
  self.assertLess(close.index('paper_authoring_notify(src, "close")'),close.index('GLOB.nanomanager.ui_closed'))
  native=body('code/modules/nano/nanoexternal.dm','/client/verb/nanoclose')
  self.assertIn('istype(ui, /datum/nanoui/tgui) && ui.user != mob',native)
  self.assertIn('if (ui.ref)',native);self.assertIn('else if (ui.on_close_logic)',native)
  self.assertIn('!isnull(ui.ref)',vm.body(SOURCE,'/datum/paper_document_authoring/proc/bind_ui'))

  raw=body('code/game/atoms_movable.dm','/atom/movable/proc/persistence_set_loc')
  self.assertLess(raw.index('loc = destination'),raw.index('paper_authoring_notify(src, "relocated")'))
  self.assertNotIn('raise_event',raw)
  for path,signature in [('code/game/mob/inventory.dm','/mob/proc/u_equip'),('code/game/mob/living/carbon/human/inventory.dm','/mob/living/human/u_equip')]:
   proc=body(path,signature)
   for hand in ('r_hand','l_hand'):self.assertIn(hand+' = null\n\t\tpaper_authoring_notify(W, "custody")',proc)
  swap=body('code/game/mob/living/carbon/carbon.dm','/mob/living/human/swap_hand')
  self.assertIn('hand = !( hand )\n\tpaper_authoring_notify(src, "hand")',swap)
  runtime=vm.body(core.SOURCE,'/datum/paper_document_authoring/persistence_runtime_var')
  for name in ('lifecycle_sources','lifecycle_links','lifecycle_bound','authoring_ui'):self.assertIn('"'+name+'"',runtime)
  self.assertNotRegex(SOURCE,r'(?i)register_global|spawn\(|hear_say|add_language|partial_languages|world\.time')
  self.assertNotIn('json_encode',vm.body(SOURCE,'/datum/paper_document_authoring/proc/lifecycle_moved'))
  self.assertIn('var/atom/node = root',vm.body(SOURCE,'/datum/paper_document_authoring/proc/plan_lifecycle'))
  self.assertIn('var/atom/node = source',vm.body(SOURCE,'/datum/paper_document_authoring/proc/stop_lifecycle'))
  self.assertNotIn('paper_document_record_valid',vm.body(SOURCE,'/datum/paper_document_authoring/proc/lifecycle_physical_current'))


 def test_carrier_raw_relocation_and_nested_range_return_retire(self):
  vehicle=core.copies.views.Container('vehicle',self.actor.loc);self.actor.loc=vehicle
  self.paper.loc=core.copies.Turf();self.start();self.paper.near=False
  self.notify(vehicle,'relocated');self.paper.near=True
  self.assertTrue(self.session.session_closed);self.assert_clean()
  self.setUp();self.paper.loc=self.actor.loc;near=self.actor.loc;near.x=0;far=core.copies.Turf();far.x=5
  self.start();self.glob.moved_event.emit(self.actor,far,near)
  self.assertTrue(self.session.session_closed);self.assert_clean()

 def test_new_containment_cancels_and_prunes_new_forwarding(self):
  self.start();old=self.actor.loc;vehicle=core.copies.views.Container('vehicle',old)
  self.actor.loc=vehicle
  self.glob.moved_event.register(vehicle,self.actor,'/atom/movable/proc/recursive_move')
  self.glob.moved_event.emit(self.actor,old,vehicle)
  self.assertTrue(self.session.session_closed);self.assert_clean()

 def test_oversized_or_cyclic_watch_graph_refuses_before_subscribing(self):
  for mode in ('large','cycle'):
   self.setUp();first=core.copies.views.Container('vehicle',self.actor.loc);self.actor.loc=first
   if mode=='cycle':first.loc=self.actor
   else:
    node=first
    for _ in range(17):
     parent=core.copies.views.Container('carrier',core.copies.Turf());node.loc=parent;node=parent
   self.assertFalse(self.session.begin(self.actor));self.assert_clean()
   self.assertIsNone(self.paper.document_record);self.assertIsNone(self.session.controller)

 def test_close_failure_cannot_stop_other_retirement_or_retain_authority(self):
  self.start();ui=self.ui();other=self.Session(self.paper,self.actor,self.pen);self.assertTrue(other.begin(self.actor));second=self.ui(other)
  class CloseError(Exception):desc='injected inert UI close failure'
  def fail():raise CloseError()
  ui.close=fail
  self.notify(self.actor,'logout')
  self.assertTrue(self.session.session_closed and other.session_closed)
  self.assertIsNone(self.session.controller);self.assertIsNone(self.session.expected_record_json)
  self.assertEqual(second.closed,1);self.assertEqual(self.env['errors'],['injected inert UI close failure']);self.assert_clean()


 def test_raw_nullspace_controller_retirement(self):
  self.start();self.actor.loc=None;self.notify(self.actor,'relocated')
  self.assertTrue(self.session.session_closed);self.assert_clean()

if __name__=='__main__':unittest.main()
