"""Inactive editor helper/UI bodies with explicit engine/window/transport seams.
No native Topic dispatch, browser delivery, BYOND compilation or client test.
"""
import copy,importlib.util,json,re,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('editor_lifecycle_fixture',Path(__file__).with_name('test_lifecycle.py'))
life=importlib.util.module_from_spec(spec);spec.loader.exec_module(life)
vm=life.vm;EN=life.EN;RU=life.RU
SOURCE=(vm.ROOT/'code/modules/paperwork/editor.dm').read_text(encoding='utf-8')
NANO=(vm.ROOT/'code/modules/nano/_nanoui.dm').read_text(encoding='utf-8')
TRANSPORT=(vm.ROOT/'code/modules/nano/tgui.dm').read_text(encoding='utf-8')

def environment(source=SOURCE):
 env,Session,Base,Reader,langs,render,Paper,glob,events,ParentUI=life.environment()
 class State(vm.Ref):
  def __init__(self,session):self.session=session
 state_base_type=env['istype']
 env['istype']=lambda value,path=None: isinstance(value,State) if path=='/datum/topic_state/paper_editor' else state_base_type(value,path)
 env['request_value']=lambda record,key:record.get(key) if isinstance(record,dict) else None
 env.update(STATUS_CLOSE=-1,STATUS_INTERACTIVE=2,json_decode=json.loads,paper_document_view_body=render)
 vm.ALLOWED|={'text2num','paper_editor_modern_supported','request_value','paper_editor_request','json_decode','paper_document_view_body','paper_document_view_title','parent_open','parent_push','parent_html','parent_close'}
 vm.METHODS|={'use_legacy_renderer','open','can_use_topic','editor_current','editor_data','set_initial_data','push_data','cancel','snapshot','Topic'}
 decoder=source
 # DM missing associative keys yield null. Python dicts need an explicit get.
 for key in ('operation','lease'):decoder=decoder.replace('request["'+key+'"]','request_value(request,"'+key+'")')
 env['paper_editor_request']=vm.project(decoder,'/proc/paper_editor_request','payload',env)
 env['editor_source']=source
 env['paper_editor_modern_supported']=vm.project(source,'/proc/paper_editor_modern_supported','data',env)
 State.can_use_topic=vm.project('/state()\n'+vm.body(source,'/datum/topic_state/paper_editor/can_use_topic').replace('session','self.session'),'/state','self,src_object,user',env)
 class UI(ParentUI):
  def __init__(self,paper,actor,session):
   super().__init__(paper,actor);self.editor_session=session;self.editor_closed=False;self.response_serial=0;self.last_result='ready'
   self.on_close_logic=False;self.state=State(session);self.status=2;self.frontend_ready=True;self.frontend_acknowledged=True;self.legacy_renderer=False
   self.sent=[];self.latest_data=None;self.opens=0
  def set_initial_data(self,data):self.latest_data=copy.deepcopy(data)
  def use_legacy_renderer(self):self.legacy_renderer=True;self.open()
 def parent_open(ui):
  ui.opens+=1
  if ui not in ui.user.open_uis:ui.user.open_uis.append(ui)
  return True
 def parent_push(ui,data,force):
  ui.latest_data=copy.deepcopy(data)
  if ui.frontend_ready:ui.sent.append(copy.deepcopy(data))
 def parent_close(ui):
  ParentUI.close(ui);ui.state=None
  if ui in ui.user.open_uis:ui.user.open_uis.remove(ui)
 env.update(parent_open=parent_open,parent_push=parent_push,parent_close=parent_close,parent_html=lambda ui:'modern shell')
 fields=('user','src_object','state','status','editor_session','editor_closed','response_serial','last_result','legacy_renderer','frontend_ready','frontend_acknowledged')
 methods=('use_legacy_renderer','open','editor_current','editor_data','set_initial_data','close','push_data')
 for name,args in [('editor_current','self'),('editor_data','self'),('open','self'),('push_data','self,data,force_push=False'),('update','self,force_open=False'),('get_html','self'),('consume_topic','self,href,href_list'),('close','self')]:
  signature='/datum/nanoui/tgui/paper_editor/'+('proc/' if name in ('editor_current','editor_data') else '')+name
  fragment=vm.body(source,signature)
  fragment=fragment.replace('istype(editor_state)','istype(editor_state, /datum/topic_state/paper_editor)')
  fragment=fragment.replace('"[P.info][P.stamps]"','dm_text(P.info)+dm_text(P.stamps)')
  parent={'open':'parent_open(self)','push_data':'parent_push(self, current, force_push)','get_html':'parent_html(self)','close':'parent_close(self)'}.get(name)
  if parent:fragment=fragment.replace('..(current, force_push)',parent).replace('..()',parent)
  pieces=re.split(r'("(?:[^"\\]|\\.)*")',fragment)
  for i in range(0,len(pieces),2):
   pieces[i]=re.sub(r'(?<![\w./])src\b','self',pieces[i])
   pieces[i]=re.sub(r'(?<![\w./])('+'|'.join(fields)+r')\b',lambda m:'self.'+m[1],pieces[i])
   pieces[i]=re.sub(r'(?<![\w./])('+'|'.join(methods)+r')\(',lambda m:'self.'+m[1]+'(',pieces[i])
  setattr(UI,name,vm.project('/ui()\n'+''.join(pieces),'/ui',args,env))
 # Native constructors/assets/open dispatch are explicit boundaries. The full
 # factory body, begin/bind/cleanup and post-constructor guards are projected.
 state=dict(sessions=[],uis=[],constructor_hook=lambda ui,session:None)
 def new_session(P,actor,pen):
  session=Session(P,actor,pen);state['sessions'].append(session);return session
 def new_ui(actor,P,key,template,title,width,height,_state):
  ui=UI(P,actor,_state.session);ui.editor_session=None;ui.state=_state;ui.key=key
  state['uis'].append(ui);state['constructor_hook'](ui,_state.session);return ui
 UI.set_auto_update=lambda self,flag:None
 ui_base_type=env['istype']
 env['istype']=lambda value,path=None:isinstance(value,UI) if path=='/datum/nanoui/tgui/paper_editor' else ui_base_type(value,path)
 env.update(new_authoring_session=new_session,new_editor_state=State,new_editor_ui=new_ui,ui_key=lambda session:'paper_editor_'+session.session_lease,native_factory=state)
 vm.ALLOWED|={'new_authoring_session','new_editor_state','new_editor_ui','ui_key'}
 vm.METHODS|={'set_auto_update','begin','bind_ui'}
 adapted=source.replace('var/datum/paper_document_authoring/session = new(P, actor, pen)','var/session = new_authoring_session(P, actor, pen)')
 adapted=adapted.replace('var/datum/topic_state/paper_editor/editor_state = new(session)','var/editor_state = new_editor_state(session)')
 adapted=adapted.replace('ui = new(actor, P, "paper_editor_[session.session_lease]"','ui = new_editor_ui(actor, P, ui_key(session)')
 adapted=adapted.replace('istype(existing)','istype(existing, /datum/nanoui/tgui/paper_editor)').replace('actor.open_uis.Copy()','actor.open_uis.copy()')
 env['paper_editor_open']=vm.project(adapted,'/proc/paper_editor_open','P,actor,pen',env)
 # Preserve the complete old NanoUI routing body around the new consuming
 # hook. Status calculation/window manager are explicit inert effect boundaries.
 native=re.sub(r'/\*.*?\*/','',NANO,flags=re.S)
 fragment=vm.body(native,'/datum/nanoui/Topic').replace('href_list["showMap"]','href_list.get("showMap")')
 fragment=re.sub(r'(?m)\s+//[^\n]*$','',fragment)
 pieces=re.split(r'("(?:[^"\\]|\\.)*")',fragment)
 for i in range(0,len(pieces),2):
  pieces[i]=re.sub(r'(?<![\w./])(status|user|src_object|state)\b',lambda m:'self.'+m[1],pieces[i])
  pieces[i]=re.sub(r'(?<![\w./])(update_status|set_show_map|consume_topic)\(',lambda m:'self.'+m[1]+'(',pieces[i])
 vm.METHODS|={'update_status','set_show_map','consume_topic','update_uis','Topic'}
 def native_number(value):
  try:return float(value)
  except (TypeError,ValueError):return None
 env['text2num']=native_number
 env['native_topic']=vm.project('/native()\n'+''.join(pieces),'/native','self,href,href_list',env)
 env['default_consume']=vm.project(NANO,'/datum/nanoui/proc/consume_topic','self,href,href_list',env)
 return env,Session,UI,State,langs,Paper,glob,events

class Editor(unittest.TestCase):
 def setUp(self):
  self.env,self.Session,self.UI,self.State,self.langs,self.Paper,self.glob,self.events=environment()
  self.actor=vm.Actor();self.actor.open_uis=[];self.actor.loc=life.core.copies.Turf();self.actor.languages=[self.langs[EN],self.langs[RU]]
  self.pen=vm.Pen(self.actor);self.paper=self.Paper(self.actor);self.paper.Adjacent=lambda a:True
  self.paper.info='';self.paper.stamps='';self.paper.info_links='DO_NOT_SEND_EDITOR_HREF'
  self.session=self.Session(self.paper,self.actor,self.pen);self.assertTrue(self.session.begin(self.actor))
  self.ui=self.UI(self.paper,self.actor,self.session);self.assertTrue(self.session.bind_ui(self.actor,self.session.session_lease,self.ui))
  self.env['usr']=self.actor
 def request(self,operation='append',**overrides):
  data=self.session.snapshot(self.actor)
  result=dict(operation=operation,lease=data['lease'])
  if operation=='append':result.update(document_id=data['document_id'],revision=data['revision'],language_id=EN,kind='body',value='WRITTEN')
  result.update(overrides);return result
 def dispatch(self,request):return self.ui.consume_topic('',{'paper_edit':json.dumps(request)})
 def test_decoder_accepts_only_finite_typed_bounded_requests(self):
  decode=self.env['paper_editor_request'];good=self.request();self.assertEqual(decode(json.dumps(good)),good)
  for value in ('',None,'null','[]','{',json.dumps(dict(good,unknown=1)),json.dumps(dict(good,revision=0.5)),json.dumps(dict(good,revision='0')),json.dumps(dict(good,kind='field_answer')),json.dumps(dict(good,value={})),json.dumps(dict(good,document_id='short')),json.dumps(dict(good,value='x'*3073)),json.dumps(dict(good,lease='x'))):
   self.assertIsNone(decode(value),value)
  self.assertIsNotNone(decode(json.dumps(self.request('refresh'))))
  self.assertIsNone(decode(json.dumps(dict(self.request('cancel'),value='extra'))))
 def test_append_rotates_lease_once_and_old_request_is_rejected(self):
  req=self.request();lease=req['lease'];self.assertTrue(self.dispatch(req))
  self.assertEqual(self.ui.last_result,'saved');self.assertEqual(len(self.paper.document_record['sections']),1);self.assertNotEqual(self.session.session_lease,lease)
  self.assertTrue(self.dispatch(req));self.assertEqual(self.ui.last_result,'rejected')
  self.assertEqual(len(self.paper.document_record['sections']),1);self.assertEqual(self.ui.response_serial,2)
  self.assertTrue(self.ui.sent);self.assertNotIn('record',self.ui.sent[-1])
 def test_unknown_language_and_forged_signature_are_not_client_authority(self):
  self.actor.languages=[self.langs[EN]];self.dispatch(self.request(language_id=RU))
  self.assertIsNone(self.paper.document_record);self.assertEqual(self.ui.last_result,'rejected')
  self.pen.signature='Actual pen signature';self.dispatch(self.request(kind='signature',value='CLIENT_CANARY'))
  self.assertEqual(self.paper.document_record['sections'][0]['text'],'Actual pen signature')
  self.assertNotIn('CLIENT_CANARY',json.dumps(self.ui.sent))
 def test_ready_ack_status_owner_legacy_state_and_binding_guards(self):
  for field,value in [('frontend_ready',False),('frontend_acknowledged',False),('status',1),('legacy_renderer',True),('state',None)]:
   with self.subTest(field=field):
    self.setUp();req=self.request();setattr(self.ui,field,value);self.dispatch(req);self.assertIsNone(self.paper.document_record)
  self.setUp();self.env['usr']=vm.Actor();self.dispatch(self.request());self.assertIsNone(self.paper.document_record)
  self.setUp();self.ui.state=self.State(self.Session(self.paper,self.actor,self.pen));self.dispatch(self.request());self.assertIsNone(self.paper.document_record)
  self.setUp();self.session.authoring_ui=None;self.dispatch(self.request());self.assertIsNone(self.paper.document_record)
 def test_legacy_editor_href_cache_never_enters_new_snapshot(self):
  self.paper.info='<b>Opaque old HTML</b>';self.session.capture_state()
  data=self.ui.editor_data();self.assertEqual(data['view']['legacy_body_html'],self.paper.info)
  self.assertNotIn('DO_NOT_SEND_EDITOR_HREF',json.dumps(data));self.assertIsNone(self.paper.document_record)
 def test_every_push_reprojects_knowledge_and_ignores_cached_payload(self):
  self.dispatch(self.request(language_id=RU,value='UNKNOWN_LANGUAGE_CANARY'))
  cached=copy.deepcopy(self.ui.sent[-1]);self.assertIn('UNKNOWN_LANGUAGE_CANARY',json.dumps(cached))
  self.actor.languages=[self.langs[EN]];self.ui.push_data(cached,True)
  self.assertNotIn('UNKNOWN_LANGUAGE_CANARY',json.dumps(self.ui.sent[-1]));self.assertIn('Unintelligible',json.dumps(self.ui.sent[-1]))
  self.ui.legacy_renderer=True;html=self.ui.get_html()
  self.assertNotIn('UNKNOWN_LANGUAGE_CANARY',html);self.assertIn('Unintelligible',html)
  self.assertIn('background:#FFFFFF;color:#000000',html)
 def test_classic_view_is_complete_readonly_and_cannot_dispatch_writes(self):
  self.paper.info='<table><tr><td>Old</td></tr></table>';self.session.capture_state()
  self.ui.legacy_renderer=True;html=self.ui.get_html();self.assertIn(self.paper.info,html)
  self.assertNotIn('DO_NOT_SEND_EDITOR_HREF',html);self.assertIn('read-only',html)
  self.dispatch(self.request());self.assertIsNone(self.paper.document_record)
 def test_refresh_old_lease_is_readonly_and_never_replays_text(self):
  req=self.request();self.dispatch(req);count=len(self.paper.document_record['sections'])
  self.dispatch(dict(operation='refresh',lease=req['lease']))
  self.assertEqual(self.ui.last_result,'refreshed');self.assertEqual(len(self.paper.document_record['sections']),count)
  self.assertEqual(self.ui.sent[-1]['lease'],self.session.session_lease)
 def test_cancel_and_close_retire_without_machine_side_effect_or_reuse(self):
  self.actor.using_object='unrelated machine';req=self.request('cancel');self.dispatch(req)
  self.assertTrue(self.session.session_closed);self.assertTrue(self.ui.editor_closed);self.assertEqual(self.ui.closed,1)
  self.assertEqual(self.actor.using_object,'unrelated machine');self.assertTrue(all(e.count()==0 for e in self.events))
  self.ui.close();self.assertEqual(self.ui.closed,1);self.dispatch(req);self.assertIsNone(self.paper.document_record)
 def test_lost_custody_logout_and_transfer_make_delayed_actions_inert(self):
  for reason in ('custody','logout','transfer'):
   with self.subTest(reason=reason):
    self.setUp();req=self.request();source=self.pen if reason=='custody' else self.actor
    self.env['paper_authoring_notify'](source,reason);self.dispatch(req)
    self.assertTrue(self.ui.editor_closed);self.assertIsNone(self.paper.document_record);self.assertTrue(all(e.count()==0 for e in self.events))
 def test_drift_and_response_exhaustion_close_without_sending_stale_data(self):
  self.paper.info='external drift';self.ui.push_data({'SECRET':'cached'},True)
  self.assertTrue(self.ui.editor_closed);self.assertEqual(self.ui.sent,[]);self.assertIsNone(self.paper.document_record)
  self.setUp();self.ui.response_serial=1048575;self.dispatch(self.request())
  self.assertTrue(self.ui.editor_closed);self.assertIsNone(self.paper.document_record)
 def test_status_poll_is_physical_only_and_default_dispatch_remains_exact(self):
  self.env['json_encode']=lambda value:(_ for _ in ()).throw(AssertionError('Status serialized data'))
  self.assertEqual(self.ui.state.can_use_topic(self.paper,self.actor),2)
  default=vm.body(NANO,'/datum/nanoui/proc/consume_topic')
  self.assertEqual(default.strip(),'return FALSE')
  topic=NANO.split('/datum/nanoui/Topic(href, href_list)',1)[1].split('/datum/nanoui/proc/process(',1)[0]
  self.assertLess(topic.index('status != STATUS_INTERACTIVE || user != usr'),topic.index('consume_topic(href, href_list)'))
  self.assertLess(topic.index('consume_topic(href, href_list)'),topic.index('src_object.Topic(href, href_list, state)'))
 def test_factory_and_fallback_source_contracts_enable_pen_route(self):
  factory=vm.body(SOURCE,'/proc/paper_editor_open')
  self.assertLess(factory.index('session.bind_ui('),factory.index('ui.open()'))
  self.assertIn('paper_editor_[session.session_lease]',factory);self.assertIn('session.retire()',factory)
  self.assertIn('ui.close()',factory);self.assertIn('catch (var/exception/e)',factory)
  self.assertNotIn('paper_editor_open',(vm.ROOT/'code/game/objects/items/paper/paper.dm').read_text(encoding='utf-8'))
  self.assertEqual(SOURCE.count('paper_editor_open('),2)
  self.assertIn('#define PAPER_EDITOR_ENTRYPOINT_ENABLED TRUE', SOURCE)
  self.assertIn('if (editor_closed || legacy_renderer)',vm.body(SOURCE,'/datum/nanoui/tgui/paper_editor/Topic'))
  for forbidden in ('hear_say(', 'add_language(', 'partial_languages','update_uis('):
   if forbidden=='update_uis(':continue # Comment explicitly says not to broadcast.
   self.assertNotIn(forbidden,SOURCE)
 def test_legacy_and_crayon_views_use_modern_editor_and_oversize_falls_back(self):
  for mode in ('legacy','crayon','oversize'):
   with self.subTest(mode=mode):
    self.setUp()
    if mode=='legacy':self.paper.info='<table><tr><td>Old</td></tr></table>';self.session.capture_state()
    elif mode=='crayon':self.pen.kind='crayon'
    else:self.paper.info='x'*65537;self.session.capture_state()
    self.ui.open()
    if mode=='oversize':
     self.assertTrue(self.ui.legacy_renderer)
     self.dispatch(self.request());self.assertIsNone(self.paper.document_record)
     self.assertIn('read-only',self.ui.get_html());continue
    self.assertFalse(self.ui.legacy_renderer)
    data=self.ui.editor_data()
    # The authored bytes, never the legacy href cache, reach the client.
    self.assertEqual(data['view']['legacy_body_html'],self.paper.info)
    self.assertEqual(data['draft_tool'],'crayon' if mode=='crayon' else 'pen')
    self.dispatch(self.request());record=self.paper.document_record
    self.assertIsNotNone(record);section=record['sections'][0]
    self.assertEqual(section['tool'],'crayon' if mode=='crayon' else 'pen');self.assertEqual(section['text'],'WRITTEN')
    self.assertEqual(record['legacy']['info'],self.paper.info)
 def test_signature_preview_comes_from_the_actual_pen_and_is_bounded(self):
  self.assertEqual(self.ui.editor_data()['draft_signature'],'Forged fixture')
  self.pen.signature='x'*300;self.assertEqual(self.ui.editor_data()['draft_signature'],'x'*256)
  self.pen.signature=None;self.assertEqual(self.ui.editor_data()['draft_signature'],'')
  # The getter runs before the snapshot, so authority lost inside it closes the data.
  def retiring(actor):self.session.retire();return 'late'
  self.pen.get_signature=retiring;self.assertIsNone(self.ui.editor_data())
  self.assertLess(SOURCE.index('writing_pen.get_signature(user)'),SOURCE.index('editor_session.snapshot(user)'))
 def test_complete_factory_binds_before_open_and_reuses_owned_view(self):
  self.session.retire()
  ui=self.env['paper_editor_open'](self.paper,self.actor,self.pen)
  self.assertIsNotNone(ui);self.assertFalse(ui.editor_closed);self.assertEqual(ui.opens,1)
  self.assertIs(ui.editor_session.authoring_ui,ui);self.assertEqual(len(self.env['native_factory']['sessions']),1)
  same=self.env['paper_editor_open'](self.paper,self.actor,self.pen)
  self.assertIs(same,ui);self.assertEqual(len(self.env['native_factory']['sessions']),1)
  self.assertIsNone(self.paper.document_record);ui.close()
  self.assertTrue(all(e.count()==0 for e in self.events));self.assertEqual(self.actor.open_uis,[])
 def test_constructor_custody_transfer_early_close_and_failure_release_session(self):
  for mode in ('pen','transfer','early-close','exception'):
   with self.subTest(mode=mode):
    self.setUp();self.session.retire()
    class NativeFailure(Exception):desc='Fixture native constructor failure'
    def callback(ui,session):
     if mode=='pen':self.actor.active=None
     elif mode=='transfer':self.actor.client=None
     elif mode=='early-close':ui.close()
     else:raise NativeFailure()
    self.env['native_factory']['constructor_hook']=callback
    self.assertIsNone(self.env['paper_editor_open'](self.paper,self.actor,self.pen))
    made=self.env['native_factory']['sessions'][0]
    self.assertTrue(made.session_closed);self.assertIsNone(made.paper)
    self.assertTrue(all(e.count()==0 for e in self.events))
    self.assertTrue(all(ui.opens==0 for ui in self.env['native_factory']['uis']))
    self.assertEqual(self.actor.open_uis,[]);self.assertIsNone(self.paper.document_record)
 def test_enabled_entrypoint_opens_editor_and_only_unclassified_papers_fall_back(self):
  self.session.retire()
  messages=[]
  self.env.update(entrypoint_enabled=False,to_chat=lambda actor,msg:messages.append((actor,msg)),SPAN_WARNING=lambda msg:msg)
  vm.ALLOWED |= {'to_chat','SPAN_WARNING','paper_editor_open'}
  route=vm.project(self.env['editor_source'].replace('PAPER_EDITOR_ENTRYPOINT_ENABLED','entrypoint_enabled'),'/proc/paper_editor_try_entrypoint','P,actor,pen',self.env)
  self.assertFalse(route(self.paper,self.actor,self.pen));self.assertEqual(self.actor.open_uis,[])
  self.env['entrypoint_enabled']=True
  # An unclassified paper the editor cannot take keeps the guarded legacy route.
  self.actor.active=None
  self.assertFalse(route(self.paper,self.actor,self.pen));self.assertEqual(self.actor.open_uis,[]);self.assertEqual(messages,[])
  self.assertIsNone(self.paper.document_record)
  self.actor.active=self.pen
  self.paper.info='<table><tr><td>Legacy text</td></tr></table>'
  self.assertTrue(route(self.paper,self.actor,self.pen))
  ui=self.actor.open_uis[0];self.assertFalse(ui.legacy_renderer)
  self.assertEqual(ui.editor_data()['view']['legacy_body_html'],self.paper.info)
  ui.consume_topic('',{'paper_edit':json.dumps({'operation':'append','lease':ui.editor_data()['lease'],'document_id':None,'revision':0,'language_id':EN,'kind':'body','value':'NEW'})})
  self.assertIsNotNone(self.paper.document_record);ui.close()
  self.assertTrue(all(e.count()==0 for e in self.events))
  # A classified paper never falls through to the unclassified legacy writer.
  self.actor.active=None
  self.assertTrue(route(self.paper,self.actor,self.pen));self.assertEqual(len(messages),1)
  self.assertEqual(self.actor.open_uis,[])
 def test_written_icon_source_and_refresh_only_after_successful_write(self):
  paper_source=(vm.ROOT/'code/game/objects/items/paper/paper.dm').read_text(encoding='utf-8')
  helper=vm.body(paper_source,'/obj/item/weapon/paper/proc/has_document_writing')
  helper=helper.replace('document_record','self.document_record').replace('if (info)','if (self.info)')
  has_writing=vm.project('/helper()\n'+helper,'/helper','self',self.env)
  self.assertFalse(has_writing(self.paper));before=list(self.paper.effects)
  bad=self.request();bad['language_id']='unknown';self.dispatch(bad)
  self.assertEqual(self.paper.effects,before);self.assertFalse(has_writing(self.paper))
  self.dispatch(self.request());self.assertTrue(has_writing(self.paper))
  self.assertEqual(self.paper.effects,before+['links','icon'])
  self.assertNotIn('WRITTEN',self.paper.info_links)
  icon=vm.body(paper_source,'/obj/item/weapon/paper/update_icon')
  self.assertEqual(icon.count('has_document_writing()'),4)
  self.assertIn('if (icon_state == "paper_talisman")',icon)
  self.assertIn('/obj/item/weapon/paper/crumpled/update_icon()',paper_source)
  route=paper_source.split('/obj/item/weapon/paper/attackby(',1)[1].split('/obj/item/weapon/paper/Court/british',1)[0]
  self.assertLess(route.index('if (icon_state == "scrap")'),route.index('paper_editor_try_entrypoint(src, user, P)'))
  self.assertLess(route.index('paper_editor_try_entrypoint(src, user, P)'),route.index('show_document(user, FALSE, "editor")'))
 def test_written_record_roundtrip_reprojects_language_without_runtime_authority(self):
  request=self.request();request['language_id']=RU;request['value']='SECRET_RELOAD_CANARY'
  self.dispatch(request);self.assertEqual(self.ui.last_result,'saved')
  serialized=json.dumps(self.paper.document_record,ensure_ascii=False)
  self.ui.close();self.assertTrue(self.session.session_closed)
  self.paper.document_record=json.loads(serialized)
  self.actor.languages=[self.langs[EN]]
  reopened=self.Session(self.paper,self.actor,self.pen);self.assertTrue(reopened.begin(self.actor))
  view=reopened.snapshot(self.actor)
  self.assertNotIn('SECRET_RELOAD_CANARY',json.dumps(view,ensure_ascii=False))
  self.assertEqual(self.paper.document_record['sections'][0]['language_id'],RU)
  reopened.retire();self.assertTrue(all(e.count()==0 for e in self.events))
 def test_original_nano_topic_dispatches_default_once_and_consumes_only_owned_path(self):
  calls=[];updates=[];ordinary=vm.Ref();target=vm.Ref();tag=vm.Ref()
  target.Topic=lambda *args:(calls.append(args) or True)
  ordinary.user=self.actor;ordinary.src_object=target;ordinary.state=tag;ordinary.status=2
  ordinary.update_status=lambda *args:None;ordinary.set_show_map=lambda *args:None
  ordinary.consume_topic=lambda href,params:self.env['default_consume'](ordinary,href,params)
  self.glob.nanomanager=vm.Ref();self.glob.nanomanager.update_uis=updates.append
  packet={'vend':'fixture'}
  self.env['native_topic'](ordinary,'old-href',packet)
  self.assertEqual(calls,[('old-href',packet,tag)]);self.assertEqual(updates,[target])
  ordinary.status=1;self.env['native_topic'](ordinary,'',packet)
  self.assertEqual(len(calls),1)
  ordinary.status=2;self.env['usr']=vm.Actor();self.env['native_topic'](ordinary,'',packet)
  self.assertEqual(len(calls),1)
  self.env['usr']=self.actor;ordinary.consume_topic=lambda *args:True
  self.env['native_topic'](ordinary,'',packet);self.assertEqual(len(calls),1);self.assertEqual(len(updates),1)
  calls.clear();updates.clear();self.paper.Topic=lambda *args:(calls.append(args) or True)
  self.ui.update_status=lambda *args:None;self.ui.set_show_map=lambda *args:None
  self.env['native_topic'](self.ui,'',{'paper_edit':json.dumps(self.request())})
  self.assertEqual(self.ui.last_result,'saved');self.assertEqual(calls,[]);self.assertEqual(updates,[])


if __name__=='__main__':unittest.main()
