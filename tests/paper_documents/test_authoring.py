"""Complete disabled authoring procedures with explicit inert parent/client seams.
Not native BYOND, real UI/pen callbacks, persistence or inventory acceptance.
"""
import copy, importlib.util, json, re, unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('authoring_copy_fixture',Path(__file__).with_name('test_copying.py'))
copies=importlib.util.module_from_spec(spec);spec.loader.exec_module(copies)
vm=copies.vm
SOURCE=(vm.ROOT/'code/modules/paperwork/authoring.dm').read_text(encoding='utf-8')
EN=copies.EN;RU=copies.RU

def environment(source=SOURCE):
 env,Base,Reader,langs,render,Paper,*_=copies.environment()
 Paper.document_capacity_ready=True # Explicit completed-constructor seam.
 env.update(max=max,parent_access=lambda s,a,w:Base.has_access(s,a,w),
            parent_mutate=lambda s,a,p:Base.can_mutate(s,a,p))
 vm.ALLOWED |= {'parent_access','parent_mutate','paper_written_language_choices','paper_written_default_language'}
 vm.METHODS |= {'capture_state','state_current','retire','project','document_copy_legacy_valid'}
 # Explicit parent dispatch and inherited/runtime fields only. Every production
 # procedure statement is projected; constructor is an inert reference seam.
 adapted=source.replace('..(actor, writing)','parent_access(self, actor, writing)').replace('..(actor, pen)','parent_mutate(self, actor, pen)')
 adapted=adapted.replace('paper.document_record != expected_record','paper.document_record is not expected_record')
 adapted=adapted.replace('view["error"]','view.get("error")')
 fields=('writing_pen','projection_reader','session_lease','session_closed','expected_record','expected_record_json','expected_legacy_json','context_owner','context_parent')
 methods=('capture_state','state_current','retire')
 pieces=re.split(r'("(?:[^"\\]|\\.)*")',adapted)
 for i in range(0,len(pieces),2):
  pieces[i]=re.sub(r'(?<![\w./])('+'|'.join(fields)+r')\b',lambda m:'self.'+m[1],pieces[i])
  pieces[i]=re.sub(r'(?<![\w./])('+'|'.join(methods)+r')\(',lambda m:'self.'+m[1]+'(',pieces[i])
 adapted=''.join(pieces)
 class Session(Base):
  def __init__(self,paper,actor,pen):
   super().__init__(paper,actor);self.writing_pen=pen;self.projection_reader=Reader(paper,actor,'editor')
   self.session_closed=True;self.session_lease=None;self.expected_record=None
   self.expected_record_json=None;self.expected_legacy_json=None;self.context_owner=None;self.context_parent=None
 for name,args in [('capture_state','self'),('state_current','self'),('begin','self,actor'),('cancel','self,actor,lease'),('retire','self'),('snapshot','self,actor')]:
  setattr(Session,name,vm.project(adapted,'/datum/paper_document_authoring/proc/'+name,args,env,True))
 for name,args in [('has_access','self,actor,writing=False'),('can_mutate','self,actor,pen'),('initialize','self,actor,pen'),('canonical_copy','self,actor'),('project','self,reader,forceshow=False'),('append','self,actor,pen,document_id,revision,language_id,kind,value,expected_lease=None')]:
  setattr(Session,name,vm.project(adapted,'/datum/paper_document_authoring/'+name,args,env,True))
 return env,Session,Base,Reader,langs,render,Paper

class Authoring(unittest.TestCase):
 def setUp(self):
  self.env,self.Session,self.Base,self.Reader,self.langs,self.render,self.Paper=environment()
  self.actor=vm.Actor();self.actor.languages=[self.langs[EN],self.langs[RU]]
  self.actor.default_language=self.langs[EN];self.actor.loc=copies.Turf()
  self.pen=vm.Pen(self.actor);self.paper=self.Paper(self.actor);self.paper.near=True
  self.paper.Adjacent=lambda a:self.paper.near
  self.session=self.Session(self.paper,self.actor,self.pen)
 def start(self):
  self.assertTrue(self.session.begin(self.actor));return self.session.snapshot(self.actor)
 def write(self,text='FIRST',language=EN,kind='body',**changes):
  data=self.session.snapshot(self.actor)
  args=dict(actor=self.actor,pen=self.pen,document_id=data['document_id'] if data else None,revision=data['revision'] if data else 0,language_id=language,kind=kind,value=text,expected_lease=data['lease'] if data else self.session.session_lease)
  args.update(changes);return self.session.append(**args)
 def state(self):
  return copy.deepcopy({k:getattr(self.paper,k) for k in copies.views.LEGACY}|{'document_record':self.paper.document_record})
 def test_open_cancel_reopen_do_not_classify_or_change_legacy_bytes(self):
  before=self.state();data=self.start()
  self.assertEqual(data['revision'],0);self.assertIsNone(data['document_id'])
  self.assertEqual(data['view']['legacy_body_html'],copies.views.LEGACY['info_links']+copies.views.LEGACY['stamps'])
  self.assertFalse(self.session.initialize(self.actor,self.pen));self.assertIsNone(self.session.canonical_copy(self.actor))
  self.actor.using_object='unrelated machine'
  self.assertFalse(self.session.cancel(vm.Actor(),data['lease']))
  self.assertFalse(self.session.cancel(self.actor,'wrong'));self.assertTrue(self.session.cancel(self.actor,data['lease']))
  self.assertEqual(self.state(),before);self.assertEqual(self.actor.using_object,'unrelated machine')
  self.assertIsNone(self.session.paper);self.assertIsNone(self.session.projection_reader);self.assertIsNone(self.session.writing_pen)
  new=self.Session(self.paper,self.actor,self.pen);self.assertTrue(new.begin(self.actor));self.assertNotEqual(new.session_lease,data['lease'])
 def test_atomic_first_append_and_existing_append_rotate_lease_once(self):
  data=self.start();space=self.paper.free_space
  self.assertTrue(self.write('FIRST'))
  r=self.paper.document_record;self.assertEqual(r['revision'],1);self.assertEqual(r['next_section'],2)
  self.assertEqual(self.paper.free_space,space-5);self.assertEqual(r['legacy']['info'],copies.views.LEGACY['info'])
  self.assertEqual(r['sections'][0]['language_id'],EN);self.assertNotEqual(self.session.session_lease,data['lease'])
  before=self.state();self.assertFalse(self.write('REPLAY',expected_lease=data['lease'],document_id=r['document_id'],revision=1))
  self.assertEqual(before,self.state());self.assertIsNotNone(self.session.snapshot(self.actor))
  self.assertTrue(self.write('SECOND',RU));self.assertEqual(self.paper.document_record['revision'],2)
  self.assertEqual([s['language_id'] for s in self.paper.document_record['sections']],[EN,RU])
  self.assertEqual(self.paper.free_space,space-11)
 def test_invalid_first_actions_never_create_empty_classified_record(self):
  self.start();before=self.state()
  for changes in (dict(language='English'),dict(language='unknown'),dict(kind='field_answer'),dict(text='x'*3073),dict(text=''),dict(text=None),dict(revision=0.5),dict(revision='0'),dict(document_id='guessed'),dict(expected_lease=None)):
   self.assertFalse(self.write(**changes));self.assertEqual(self.state(),before)
  self.pen.colour='expression(bad)';self.assertFalse(self.write());self.assertEqual(self.state(),before)
  self.pen.colour='#ffffff';self.assertTrue(self.write('accepted'))
 def test_only_current_spoken_members_and_eligible_default_are_exposed(self):
  self.actor.languages=[self.langs[EN]];self.actor.default_language=self.langs[RU]
  self.actor.muted=True;self.actor.universal_speak=True;self.actor.universal_understand=True
  data=self.start();self.assertEqual([x['id'] for x in data['languages']],[EN]);self.assertIsNone(data['default_language_id'])
  self.assertFalse(self.write(language=RU));self.assertTrue(self.write('Mute author'))
  self.actor.languages.append(self.langs[RU]);self.actor.default_language=self.langs[RU]
  data=self.session.snapshot(self.actor);self.assertEqual(data['default_language_id'],RU)
  self.assertEqual(self.paper.document_record['sections'][0]['language_id'],EN)
  self.actor.languages=[];self.assertIsNone(self.session.snapshot(self.actor));self.assertFalse(self.write())
 def test_removed_language_after_snapshot_and_unknown_ids_reject(self):
  self.start();data=self.session.snapshot(self.actor);before=self.state();self.actor.languages=[self.langs[EN]]
  self.assertFalse(self.write(language=RU,expected_lease=data['lease']))
  self.assertEqual(self.state(),before)
  self.actor.languages=[];self.actor.kind='ghost';self.actor.universal_speak=True
  another=self.Session(self.paper,self.actor,self.pen);self.assertFalse(another.begin(self.actor))
 def test_signature_uses_actual_forgery_and_ink_not_client_text(self):
  self.start();self.pen.kind='crayon';self.pen.signature='Intentional forged name';self.pen.colour='white'
  self.assertTrue(self.write('CLIENT_FORGED_VALUE',kind='signature'))
  s=self.paper.document_record['sections'][0]
  self.assertEqual(s['text'],'Intentional forged name');self.assertEqual(s['ink'],'white');self.assertEqual(s['tool'],'crayon')
  self.assertNotIn('CLIENT_FORGED_VALUE',json.dumps(self.paper.document_record))
 def test_signature_callback_lost_authority_never_classifies_legacy(self):
  for change in ('language','pen','client','body','legacy','custody','delete','cancel'):
   with self.subTest(change=change):
    self.setUp();data=self.start();space=self.paper.free_space
    def signature(actor):
     if change=='language':actor.languages=[]
     elif change=='pen':actor.active=None
     elif change=='client':actor.client=None
     elif change=='body':actor.client.mob=vm.Actor()
     elif change=='legacy':self.paper.info+=' external'
     elif change=='custody':self.paper.loc=actor.loc
     elif change=='delete':self.paper.gc_destroyed=True
     else:self.session.retire()
     return 'Callback text'
    self.pen.get_signature=signature;self.assertFalse(self.write(kind='signature'))
    self.assertIsNone(self.paper.document_record);self.assertEqual(self.paper.free_space,space)
 def test_existing_record_callback_and_equal_replacement_are_stale(self):
  self.start();self.assertTrue(self.write());before=self.state()
  self.pen.get_signature=lambda actor:(setattr(self.paper,'document_record',copy.deepcopy(self.paper.document_record)) or 'Text')
  self.assertFalse(self.write(kind='signature'));self.assertEqual(self.state(),before)
  self.assertIsNone(self.session.snapshot(self.actor))
 def test_two_sessions_cannot_rebase_or_replay_each_others_writes(self):
  data=self.start();other=self.Session(self.paper,self.actor,self.pen);self.assertTrue(other.begin(self.actor))
  other_data=other.snapshot(self.actor);self.assertTrue(self.write());before=self.state()
  self.assertFalse(other.append(self.actor,self.pen,None,0,EN,'body','SECOND',other_data['lease']))
  self.assertIsNone(other.snapshot(self.actor));self.assertEqual(before,self.state())
  self.assertFalse(self.write(expected_lease=data['lease']));self.assertIsNotNone(self.session.snapshot(self.actor))
 def test_wrong_actor_logout_transfer_restraint_and_pen_replacement_reject(self):
  self.start();before=self.state();old=self.actor.client
  self.assertFalse(self.write(actor=vm.Actor()));self.assertFalse(self.write(pen=vm.Pen(vm.Actor())))
  for field,value in [('stat',1),('bound',True),('active',None),('client',None)]:
   oldvalue=getattr(self.actor,field);setattr(self.actor,field,value)
   self.assertIsNone(self.session.snapshot(self.actor));self.assertFalse(self.write());setattr(self.actor,field,oldvalue)
  self.actor.client.mob=vm.Actor();self.assertFalse(self.write());self.actor.client.mob=self.actor
  self.actor.client=vm.Ref();self.actor.client.mob=self.actor;self.assertFalse(self.write());self.actor.client=old
  self.pen.gc_destroyed=True;self.assertFalse(self.write());self.pen.gc_destroyed=False
  self.pen.loc=self.actor.loc;self.assertFalse(self.write());self.pen.loc=self.actor
  self.assertEqual(self.state(),before)
 def test_custody_context_is_pinned_but_walking_with_held_paper_is_allowed(self):
  self.start();self.actor.loc=copies.Turf();self.assertTrue(self.write('Walking held'))
  self.paper.loc=self.actor.loc;self.assertIsNone(self.session.snapshot(self.actor))
  self.assertFalse(self.write());self.assertTrue(self.session.cancel(self.actor,self.session.session_lease))
 def test_held_containers_and_turf_use_actual_access_without_broadening(self):
  for kind in ('clipboard','folder'):
   self.setUp();container=copies.views.Container(kind,self.actor);self.paper.loc=container;self.start()
   self.assertTrue(self.write());container.loc=copies.Turf();self.assertFalse(self.write())
   self.assertIsNone(self.session.snapshot(self.actor))
  self.setUp();self.paper.loc=self.actor.loc;self.start();self.paper.near=False
  self.assertFalse(self.write());self.assertIsNone(self.session.snapshot(self.actor))
  for kind in ('envelope','bundle','noticeboard'):
   self.setUp();container=copies.views.Container(kind,self.actor);container.opened=True;container.pages=[self.paper]
   self.paper.loc=container;self.assertFalse(self.session.begin(self.actor));self.assertIsNone(self.paper.document_record)
 def test_subtypes_malformed_oversized_legacy_and_records_refuse_without_repair(self):
  for change in ('subtype','legacy','cycle','deep','capacity','record'):
   self.setUp()
   if change=='subtype':self.paper.type=vm.TypePath('/obj/item/weapon/paper/poem')
   elif change=='legacy':self.paper.info='x'*131073
   elif change=='cycle':self.paper.stamped=[];self.paper.stamped.append(self.paper.stamped)
   elif change=='deep':
    self.paper.stamped=[];x=self.paper.stamped
    for _ in range(18):x.append([]);x=x[0]
   elif change=='capacity':self.paper.free_space='bad'
   else:self.paper.document_record={'schema_version':2}
   self.assertFalse(self.session.begin(self.actor))
   if change!='record':self.assertIsNone(self.paper.document_record)
 def test_all_unknown_text_kinds_are_absent_from_whole_editor_payload(self):
  base=self.Base(self.paper,self.actor);self.assertTrue(base.initialize(self.actor,self.pen))
  for kind in ('body','title','signature'):
   self.pen.signature='SECRET_SIGNATURE_CANARY';r=self.paper.document_record
   self.assertTrue(base.append(self.actor,self.pen,r['document_id'],r['revision'],RU,kind,'SECRET_'+kind.upper()+'_CANARY'))
  for kind in ('field_label','field_answer'):
   self.paper.document_record['sections'].append(dict(id=kind,lineage='1'*32,version=1,kind=kind,language_id=RU,text='SECRET_'+kind.upper()+'_CANARY',ink='white',tool='pen'))
  self.actor.languages=[self.langs[EN]];self.paper.info_links='SECRET_CACHE_CANARY'
  data=self.start();encoded=json.dumps(data)
  self.assertNotIn('SECRET_',encoded)
  encoded+=self.render(data['view'],self.paper)
  self.assertNotIn('SECRET_',encoded);self.assertEqual(len(data['view']['sections']),5)
  self.assertIn('[Unintelligible writing]',encoded);self.assertNotIn('expected_record',encoded)
  self.assertIsNone(self.session.canonical_copy(self.actor));self.assertEqual(data,self.session.snapshot(self.actor))
 def test_record_or_legacy_in_place_mutation_invalidates_unchanged_revision(self):
  for classified in (False,True):
   self.setUp();self.start()
   if classified:
    self.assertTrue(self.write());self.paper.document_record['sections'][0]['text']='External replacement'
   else:self.paper.info+=' external'
   before=self.state();self.assertFalse(self.write());self.assertIsNone(self.session.snapshot(self.actor));self.assertEqual(self.state(),before)
 def test_runtime_exclusion_unwired_route_and_no_language_learning(self):
  runtime=vm.body(SOURCE,'/datum/paper_document_authoring/persistence_runtime_var')
  for name in ('writing_pen','projection_reader','session_lease','session_closed','expected_record','expected_record_json','expected_legacy_json','context_owner','context_parent'):
   self.assertIn('"'+name+'"',runtime)
  self.assertIn('retire()',vm.body(SOURCE,'/datum/paper_document_authoring/Destroy'))
  self.assertNotRegex(SOURCE,r'(?i)hear_say\(|add_language\(|partial_languages|using_object\s*=')
  for path in (vm.ROOT/'code/modules/paperwork').glob('*.dm'):
   if path.name!='authoring.dm':self.assertNotIn('/datum/paper_document_authoring',path.read_text(encoding='utf-8'))
  self.assertNotIn('paper_document_authoring',(vm.ROOT/'code/game/objects/items/paper/paper.dm').read_text(encoding='utf-8'))


 def test_actual_active_replacement_pen_cannot_reuse_session(self):
  self.start();before=self.state();replacement=vm.Pen(self.actor)
  self.assertFalse(self.write(pen=replacement));self.assertEqual(self.state(),before)

 def test_signature_reentrant_write_retires_outer_lease_without_replay(self):
  self.start();space=self.paper.free_space
  def signature(actor):
   self.assertTrue(self.write('INNER'))
   return 'OUTER'
  self.pen.get_signature=signature
  self.assertFalse(self.write(kind='signature'))
  self.assertEqual(self.paper.free_space,space-5)
  self.assertEqual([s['text'] for s in self.paper.document_record['sections']],['INNER'])
  self.assertIsNotNone(self.session.snapshot(self.actor))

 def test_direct_parent_projection_is_disabled_in_editor_context(self):
  self.start();self.assertIsNone(self.session.project(self.actor))


 def test_pending_constructor_capacity_refuses_editor_until_callback_finishes(self):
  self.paper.document_capacity_ready=False;before=self.state()
  self.assertFalse(self.session.begin(self.actor));self.assertEqual(self.state(),before)
  self.assertIsNone(self.paper.document_record)
  # Inert callback completion: actual native constructor scheduling is untested.
  self.paper.free_space-=20;self.paper.document_capacity_ready=True
  self.assertTrue(self.session.begin(self.actor));space=self.paper.free_space
  self.assertTrue(self.write('FIRST'));self.assertEqual(self.paper.free_space,space-5)
  self.assertEqual(self.paper.document_record['legacy']['free_space'],space-5)
  constructor=vm.body((vm.ROOT/'code/game/objects/items/paper/paper.dm').read_text(),'/obj/item/weapon/paper/New')
  self.assertIn('var/document_capacity_ready = FALSE',SOURCE)
  self.assertLess(constructor.index('update_space(info)'),constructor.index('document_capacity_ready = TRUE'))
  self.assertIn('key == "document_capacity_ready"',vm.body(SOURCE,'/obj/item/weapon/paper/persistence_runtime_var'))

if __name__=='__main__':unittest.main()
