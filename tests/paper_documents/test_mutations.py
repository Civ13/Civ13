"""Production transaction/erasure/legacy guard projections; not native DM."""
import copy,importlib.util,json,re,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('mutation_view_fixture',Path(__file__).with_name('test_views.py'))
views=importlib.util.module_from_spec(spec);spec.loader.exec_module(views)
vm=views.vm
PAPER=(vm.ROOT/'code/game/objects/items/paper/paper.dm').read_text(encoding='utf-8')
PHYSICAL=(vm.ROOT/'code/modules/paperwork/physical.dm').read_text(encoding='utf-8')
CHEM=(vm.ROOT/'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Compounds.dm').read_text(encoding='utf-8')
EN='civ13:english:v1';RU='civ13:russian:v1'

def environment():
 env,Base,Reader,langs,render=views.environment()
 original=env['istype']
 env['istype']=lambda value,path=None:getattr(value,'kind',None)=='envelope' if path=='/obj/item/weapon/storage/envelope' else original(value,path)
 vm.METHODS |= {'Cut','updateinfolinks','update_icon'}
 allowed=views.SOURCE.replace('B.pages.len','length(B.pages)').replace('B.pages[B.page]','B.pages[B.page-1]')
 env['paper_document_legacy_edit_allowed']=vm.project(allowed,'/proc/paper_document_legacy_edit_allowed','P,actor,expected_client,pen',env)
 # Deterministic native-randomness seam: only the damage choice is substituted.
 # Production bodies, arguments, candidate edits and commits execute unchanged.
 env['damage_calls']=[]
 def damage(value,prob=None):
  env['damage_calls'].append((value,prob))
  return ''.join(' ' if c==' ' else '*' for c in (value or ''))
 env['stars']=damage
 for name,args in [('set_name','P,value,edit=None'),('crumple','P')]:
  env['paper_document_'+name]=vm.project(PHYSICAL,'/proc/paper_document_'+name,args,env)
 # Only engine effects are inert: overlay clear, href rebuild, icon update.
 code=vm.body(PAPER,'/obj/item/weapon/paper/proc/clearpaper')
 pieces=re.split(r'("(?:[^"\\]|\\.)*")',code)
 for index in range(0,len(pieces),2):
  for field in ('document_record','info','stamps','free_space','stamped','overlays'):
   pieces[index]=re.sub(r'(?<![\w.])'+field+r'\b','self.'+field,pieces[index])
  pieces[index]=re.sub(r'(?<![\w.])src\b','self',pieces[index])
  pieces[index]=re.sub(r'(?<![\w.])(updateinfolinks|update_icon)\(',r'self.\1(',pieces[index])
 clearer=vm.project('/clear()\n'+''.join(pieces),'/clear','self',env)
 return env,Base,Reader,langs,render,clearer

class Overlays(list):
 def Cut(self):self.clear()

class Mutations(unittest.TestCase):
 def setUp(self):
  self.env,self.Base,self.Reader,self.langs,self.render,self.clearer=environment()
  self.actor=vm.Actor();self.actor.languages=[self.langs[EN],self.langs[RU]];self.pen=vm.Pen(self.actor)
  self.paper=vm.Paper(self.actor,views.LEGACY);self.service=self.Base(self.paper,self.actor);self.effects=[]
  self.paper.overlays=Overlays(['old-stamp']);self.paper.deffont='Verdana';self.paper.signfont='Times New Roman';self.paper.crayonfont='Comic Sans MS'
  def links():self.effects.append('links');self.paper.info_links='rebuilt-for-this-paper'
  self.paper.updateinfolinks=links;self.paper.update_icon=lambda:self.effects.append('icon')
 def initialize(self):
  self.assertTrue(self.service.initialize(self.actor,self.pen))
  for lang,kind,text in [(EN,'body','PUBLIC'),(RU,'title','SECRET_TITLE'),(RU,'signature','ignored')]:
   r=self.paper.document_record;self.assertTrue(self.service.append(self.actor,self.pen,r['document_id'],r['revision'],lang,kind,text))
  return self.paper.document_record
 def prepare(self):return self.env['paper_document_prepare_edit'](self.paper)
 def commit(self,edit):return self.env['paper_document_commit_edit'](self.paper,edit)
 def allowed(self,client=None):return self.env['paper_document_legacy_edit_allowed'](self.paper,self.actor,client or self.actor.client,self.pen)
 def test_prepare_is_detached_and_does_not_mutate_or_project_private_token(self):
  before=copy.deepcopy(self.initialize());edit=self.prepare()
  self.assertEqual(self.paper.document_record,before);self.assertIs(edit['original'],self.paper.document_record)
  self.assertIsNot(edit['record'],self.paper.document_record);self.assertIsNot(edit['record']['sections'],self.paper.document_record['sections'])
  edit['record']['sections'][0]['text']='candidate only';self.assertEqual(self.paper.document_record,before)
  projected=self.service.project(self.actor)
  for key in ('original','record','canonical_json','legacy_json'):self.assertNotIn(key,projected)
 def test_commit_requires_one_revision_and_is_once_only(self):
  self.initialize();edit=self.prepare();before=copy.deepcopy(self.paper.document_record)
  self.assertFalse(self.commit(edit));self.assertEqual(self.paper.document_record,before)
  edit['record']['revision']+=2;self.assertFalse(self.commit(edit));edit['record']['revision']-=1
  self.assertTrue(self.commit(edit));committed=copy.deepcopy(self.paper.document_record)
  self.assertFalse(self.commit(edit));self.assertEqual(self.paper.document_record,committed)
 def test_equal_content_record_replacement_is_stale_by_dm_list_identity(self):
  self.initialize();edit=self.prepare();edit['record']['revision']+=1
  self.paper.document_record=copy.deepcopy(self.paper.document_record)
  replacement=self.paper.document_record;self.assertFalse(self.commit(edit));self.assertIs(self.paper.document_record,replacement)
 def test_canonical_inplace_change_legacy_drift_and_deletion_reject(self):
  for change in ('text','revision','legacy','deleted'):
   with self.subTest(change=change):
    self.setUp();self.initialize();edit=self.prepare();edit['record']['revision']+=1
    if change=='text':self.paper.document_record['sections'][0]['text']='concurrent edit'
    elif change=='revision':self.paper.document_record['revision']+=1
    elif change=='legacy':self.paper.info+=' external legacy write'
    else:self.paper.gc_destroyed=True
    before=copy.deepcopy(self.paper.document_record);space=self.paper.free_space
    self.assertFalse(self.commit(edit));self.assertEqual(self.paper.document_record,before);self.assertEqual(self.paper.free_space,space)
 def test_invalid_candidate_or_identity_fails_without_partial_legacy_write(self):
  for change in ('schema','identity','sequence','runtime','overlong','overbudget'):
   with self.subTest(change=change):
    self.setUp();self.initialize();edit=self.prepare();edit['record']['revision']+=1
    if change=='schema':edit['record']['schema_version']=2
    elif change=='identity':edit['record']['document_id']='z'*32
    elif change=='sequence':edit['record']['next_section']=1
    elif change=='runtime':edit['record']['legacy']['ico']=[vm.Ref()]
    elif change=='overlong':edit['record']['sections'][0]['text']='x'*3073
    else:edit['record']['legacy']['ico']=[0]*4096
    before=copy.deepcopy(self.paper.document_record);info=self.paper.info
    self.assertFalse(self.commit(edit));self.assertEqual(self.paper.document_record,before);self.assertEqual(self.paper.info,info)
 def test_two_prepared_edits_cannot_overwrite_each_other(self):
  self.initialize();one=self.prepare();two=self.prepare()
  for token in (one,two):token['record']['revision']+=1
  one['record']['sections'][0]['text']='first writer'
  self.assertTrue(self.commit(one));self.assertFalse(self.commit(two))
  self.assertEqual(self.paper.document_record['sections'][0]['text'],'first writer')
 def test_commit_does_not_alias_candidate_or_physical_legacy_lists(self):
  self.initialize();edit=self.prepare();edit['record']['revision']+=1;self.assertTrue(self.commit(edit))
  before=copy.deepcopy(self.paper.document_record)
  edit['record']['sections'][0]['text']='caller changed after commit'
  edit['record']['legacy']['ico'].append('caller cache')
  self.assertEqual(self.paper.document_record,before)
  for field in ('stamped','ico','offset_x','offset_y'):
   self.assertIsNot(getattr(self.paper,field),self.paper.document_record['legacy'][field])
  self.paper.ico.append('physical mutation')
  self.assertEqual(self.paper.document_record,before)
  self.assertEqual(self.service.project(self.actor),dict(error='Legacy document changed'))
 def test_commit_preserves_the_1024_node_physical_legacy_budget(self):
  self.initialize();edit=self.prepare();edit['record']['revision']+=1
  edit['record']['legacy']['ico']=[0]*1024
  self.assertTrue(self.env['paper_document_record_valid'](edit['record']))
  before=copy.deepcopy(self.paper.document_record);physical=copy.deepcopy(self.paper.ico)
  self.assertFalse(self.commit(edit));self.assertEqual(self.paper.document_record,before);self.assertEqual(self.paper.ico,physical)
 def test_commit_preserves_opaque_legacy_bytes_nulls_and_path_types(self):
  self.paper.info='<font color=#ffffff><i>Old forged signature</i></font> &amp; [field] 日本語 🚢'
  self.paper.stamped=[vm.TypePath('/obj/item/weapon/stamp')];self.paper.offset_x=[None,0,-2]
  self.assertTrue(self.service.initialize(self.actor,self.pen));before=copy.deepcopy(self.paper.document_record['legacy'])
  edit=self.prepare();edit['record']['revision']+=1;self.assertTrue(self.commit(edit))
  self.assertEqual(self.env['paper_document_legacy_snapshot'](self.paper),before)
  self.assertIsInstance(self.paper.stamped[0],vm.TypePath);self.assertIsInstance(self.paper.document_record['legacy']['stamped'][0],vm.TypePath)
  self.assertIsNone(self.paper.offset_x[0]);self.assertIsNone(self.paper.document_record['legacy']['offset_x'][0])
 def test_erasure_clears_all_languages_without_minting_new_document_or_reusing_ids(self):
  before=copy.deepcopy(self.initialize());self.assertTrue(self.clearer(self.paper));record=self.paper.document_record
  self.assertEqual(record['sections'],[]);self.assertEqual(record['document_id'],before['document_id'])
  self.assertEqual(record['revision'],before['revision']+1);self.assertEqual(record['next_section'],before['next_section'])
  self.assertIsNone(self.paper.info);self.assertIsNone(self.paper.stamps);self.assertEqual(self.paper.stamped,[])
  self.assertEqual(self.paper.free_space,vm.MAXIMUM);self.assertEqual(self.paper.fields,views.LEGACY['fields'])
  self.assertEqual(record['legacy'],self.env['paper_document_legacy_snapshot'](self.paper));self.assertEqual(self.paper.overlays,[])
  self.assertEqual(self.effects,['links','icon']);self.assertNotIn('SECRET',json.dumps(self.service.project(self.actor)))
  self.assertIsNotNone(self.service.canonical_copy(self.actor))
 def test_erasure_makes_a_prepared_edit_and_old_append_revision_stale(self):
  before=self.initialize();edit=self.prepare();edit['record']['revision']+=1
  self.assertTrue(self.clearer(self.paper));cleared=copy.deepcopy(self.paper.document_record)
  self.assertFalse(self.commit(edit));self.assertFalse(self.service.append(self.actor,self.pen,before['document_id'],before['revision'],EN,'body','late'))
  self.assertEqual(self.paper.document_record,cleared)
 def test_legacy_erasure_retains_old_field_counter_and_other_bytes(self):
  kept={k:copy.deepcopy(getattr(self.paper,k)) for k in ('name','fields','ico','offset_x','offset_y')}
  self.assertTrue(self.clearer(self.paper));self.assertIsNone(self.paper.document_record)
  for k,value in kept.items():self.assertEqual(getattr(self.paper,k),value)
  self.assertEqual(self.effects,['links','icon'])
 def test_malformed_or_stale_classified_erasure_has_no_effects(self):
  for change in ('malformed','legacy','version-limit'):
   with self.subTest(change=change):
    self.setUp();self.initialize()
    if change=='malformed':self.paper.document_record['schema_version']=2
    elif change=='legacy':self.paper.info+=' external edit'
    else:self.paper.document_record['revision']=1048575
    before=copy.deepcopy(self.paper.document_record);info=self.paper.info;overlays=list(self.paper.overlays)
    self.assertFalse(self.clearer(self.paper));self.assertEqual(self.paper.document_record,before);self.assertEqual(self.paper.info,info)
    self.assertEqual(self.paper.overlays,overlays);self.assertEqual(self.effects,[])
 def test_legacy_guard_rejects_classification_logout_transfer_state_and_tool_change(self):
  self.assertTrue(self.allowed());client=self.actor.client
  for change in ('classified','unknown','logout','reconnect','transfer','incapacitated','restrained','pen','destroyed-pen'):
   with self.subTest(change=change):
    self.setUp();client=self.actor.client;self.assertTrue(self.allowed(client))
    if change=='classified':self.initialize()
    elif change=='unknown':self.paper.document_record={'future_schema':True}
    elif change=='logout':self.actor.client=None
    elif change=='reconnect':self.actor.client=vm.Ref();self.actor.client.mob=self.actor
    elif change=='transfer':client.mob=vm.Actor()
    elif change=='incapacitated':self.actor.stat=1
    elif change=='restrained':self.actor.bound=True
    elif change=='pen':self.actor.active=vm.Pen(self.actor)
    else:self.pen.gc_destroyed=True
    self.assertFalse(self.allowed(client))
 def test_legacy_guard_validates_container_page_and_open_envelope(self):
  turf=vm.Ref();turf.kind='turf'
  for kind in ('clipboard','folder','envelope','bundle'):
   with self.subTest(kind=kind):
    self.setUp();holder=views.Container(kind,self.actor);self.paper.loc=holder
    holder.opened=True;holder.pages=[self.paper];holder.page=1
    self.assertTrue(self.allowed());holder.gc_destroyed=True;self.assertFalse(self.allowed());holder.gc_destroyed=False
    holder.loc=turf;self.assertTrue(self.allowed());holder.near=False;self.assertFalse(self.allowed());holder.near=True
    closed=views.Container('envelope',self.actor);closed.opened=False;holder.loc=closed
    self.assertFalse(self.allowed());holder.loc=self.actor
    if kind=='envelope':holder.opened=False;holder.sealed=True;self.assertFalse(self.allowed());holder.opened=True;holder.knifed=True;self.assertTrue(self.allowed())
    if kind=='bundle':holder.pages=[vm.Paper(self.actor,views.LEGACY),self.paper];holder.page=1;self.assertFalse(self.allowed());holder.page=2;self.assertTrue(self.allowed());holder.page=1.5;self.assertFalse(self.allowed())
 def test_topic_guard_dominates_prompt_and_commit_and_chemistry_reports_success_only(self):
  # Existing unindented /* comments interrupt the strict procedure-body parser;
  # bound this source contract by the next real top-level procedure instead.
  start='/obj/item/weapon/paper/Topic(href, href_list)';end='/obj/item/weapon/paper/attackby('
  self.assertEqual(PAPER.count(start),1);self.assertEqual(PAPER.count(end),1)
  topic=PAPER.split(start,1)[1].split(end,1)[0];call='paper_document_legacy_edit_allowed(src, writer, writer_client, writing_pen)'
  self.assertEqual(topic.count(call),2)
  for marker in ('var/t =  sanitize(input(','t = parsepencode('):self.assertIn(marker,topic)
  prompt=topic.index('var/t =  sanitize(input(');first=topic.index(call);second=topic.index(call,first+len(call))
  self.assertLess(first,prompt);self.assertLess(prompt,second);self.assertLess(second,topic.index('t = parsepencode('))
  self.assertIn('usr != writer',topic)
  self.assertEqual(CHEM.count('if (paperaffected.clearpaper())'),2)
  commit=vm.body(vm.SOURCE,'/proc/paper_document_commit_edit')
  for forbidden in ('sleep(', 'input(', 'spawn(', 'get_signature(', 'to_chat(', 'browse('):self.assertNotIn(forbidden,commit)

 def rename(self,value,edit=None):return self.env['paper_document_set_name'](self.paper,value,edit)
 def crumple(self):return self.env['paper_document_crumple'](self.paper)
 def test_classified_name_sync_preserves_written_title_languages_and_copy_identity(self):
  before=copy.deepcopy(self.initialize());edit=self.prepare()
  self.assertTrue(self.rename('Public &amp; item label',edit));record=self.paper.document_record
  self.assertEqual(self.paper.name,record['legacy']['name']);self.assertEqual(record['sections'],before['sections'])
  self.assertEqual(record['document_id'],before['document_id']);self.assertEqual(record['next_section'],before['next_section'])
  self.assertEqual(record['revision'],before['revision']+1);self.assertIsNotNone(self.service.canonical_copy(self.actor))
  self.actor.languages=[self.langs[EN]]
  payload=json.dumps(self.service.project(self.actor))
  self.assertIn('Public &amp; item label',payload);self.assertNotIn('SECRET_TITLE',payload)
 def test_name_edit_rejects_stale_invalid_or_missing_token_without_partial_effect(self):
  for change in ('missing','identity','content','legacy','deleted','version'):
   with self.subTest(change=change):
    self.setUp();self.initialize();edit=self.prepare()
    if change=='missing':edit=None
    elif change=='identity':self.paper.document_record=copy.deepcopy(self.paper.document_record)
    elif change=='content':self.paper.document_record['sections'][0]['text']='concurrent'
    elif change=='legacy':self.paper.info+=' concurrent'
    elif change=='deleted':self.paper.gc_destroyed=True
    else:self.paper.document_record['revision']=1048575;edit=self.prepare()
    before=copy.deepcopy(self.paper.document_record);name=self.paper.name
    self.assertFalse(self.rename('Rejected label',edit));self.assertEqual(self.paper.name,name);self.assertEqual(self.paper.document_record,before)
 def test_legacy_name_retains_bytes_and_classification_cannot_be_downgraded(self):
  self.assertTrue(self.rename('A &amp; B &lt;literal&gt;'));self.assertEqual(self.paper.name,'A &amp; B &lt;literal&gt;')
  self.assertIsNone(self.paper.document_record)
  self.initialize();token=self.prepare();self.paper.document_record=None;before=self.paper.name
  self.assertFalse(self.rename('Stale classified name',token));self.assertEqual(self.paper.name,before)
 def test_crumple_damages_all_sections_once_preserves_ink_language_and_versions(self):
  before=copy.deepcopy(self.initialize());self.env['damage_calls'].clear()
  self.assertTrue(self.crumple());record=copy.deepcopy(self.paper.document_record)
  self.assertEqual(len(self.env['damage_calls']),1+len(before['sections']))
  self.assertTrue(all(prob==85 for value,prob in self.env['damage_calls']))
  self.assertEqual(self.paper.info,record['legacy']['info'])
  self.assertEqual(record['revision'],before['revision']+1);self.assertEqual(record['document_id'],before['document_id'])
  self.assertEqual(record['next_section'],before['next_section']);self.assertEqual(self.paper.free_space,before['legacy']['free_space'])
  for old,new in zip(before['sections'],record['sections']):
   self.assertNotEqual(old['text'],new['text']);self.assertEqual(new['version'],old['version']+1)
   for key in ('id','lineage','kind','language_id','ink','tool'):self.assertEqual(new[key],old[key])
  calls=len(self.env['damage_calls'])
  self.service.project(self.actor);self.service.canonical_copy(self.actor)
  self.assertEqual(len(self.env['damage_calls']),calls);self.assertEqual(self.paper.document_record,record)
 def test_crumple_unchanged_text_keeps_section_version_and_stale_append_rejects(self):
  self.initialize();self.paper.document_record['sections'][0]['text']='***'
  before=copy.deepcopy(self.paper.document_record);edit=self.prepare();edit['record']['revision']+=1
  self.assertTrue(self.crumple());record=self.paper.document_record
  self.assertEqual(record['sections'][0]['version'],before['sections'][0]['version'])
  self.assertFalse(self.commit(edit))
  self.assertFalse(self.service.append(self.actor,self.pen,before['document_id'],before['revision'],EN,'body','stale'))
 def test_crumple_invalid_drift_budget_and_version_refuse_atomically(self):
  for change in ('malformed','legacy','revision','section-version','budget'):
   with self.subTest(change=change):
    self.setUp();self.initialize()
    if change=='malformed':self.paper.document_record['schema_version']=2
    elif change=='legacy':self.paper.info+=' external'
    elif change=='revision':self.paper.document_record['revision']=1048575
    elif change=='section-version':self.paper.document_record['sections'][0]['version']=1048575
    else:self.paper.document_record['legacy']['ico']=[0]*4096
    before=copy.deepcopy(self.paper.document_record);info=self.paper.info;space=self.paper.free_space
    self.assertFalse(self.crumple());self.assertEqual(self.paper.document_record,before)
    self.assertEqual(self.paper.info,info);self.assertEqual(self.paper.free_space,space);self.assertEqual(self.effects,[])
 def test_legacy_crumple_does_not_classify_or_change_capacity_or_stamps(self):
  before=self.env['paper_document_legacy_snapshot'](self.paper);self.env['damage_calls'].clear()
  self.assertTrue(self.crumple());self.assertIsNone(self.paper.document_record)
  self.assertEqual(self.env['damage_calls'],[(before['info'],85)])
  after=self.env['paper_document_legacy_snapshot'](self.paper)
  for key in before:
   if key!='info':self.assertEqual(after[key],before[key])
 def test_physical_handlers_commit_before_effects_and_rename_binds_prompt(self):
  plane=vm.body(PAPER,'/obj/item/weapon/paper/verb/airplane')
  self.assertLess(plane.index('paper_document_set_name('),plane.index('src.icon_state ='))
  self.assertLess(plane.index('if (!fold_edit)'),plane.index('paper_document_set_name('))
  crumple=vm.body(PAPER,'/obj/item/weapon/paper/attack_self')
  self.assertLess(crumple.index('if (!paper_document_crumple(src))'),crumple.index('user.visible_message('))
  rename=vm.body(PAPER,'/obj/item/weapon/paper/verb/rename')
  self.assertLess(rename.index('paper_document_prepare_edit(src)'),rename.index('input(renamer,'))
  for guard in ('usr == renamer','renamer.client == rename_client','rename_client.mob == renamer','document_record == rename_record','rename_legacy_json'):
   self.assertIn(guard,rename)
  self.assertLess(rename.index('if (!paper_document_set_name('),rename.index('desc ='))
  self.assertNotRegex(PHYSICAL,r'(?i)hear_say\(|add_language\(|partial_languages|new /datum/paper_document_authoring')

 def test_physical_changes_copy_canonical_bytes_with_faithful_section_identity(self):
  spec=importlib.util.spec_from_file_location('physical_copy_fixture',Path(__file__).with_name('test_copying.py'))
  copies=importlib.util.module_from_spec(spec);spec.loader.exec_module(copies)
  env,Base,Reader,langs,render,Paper,state,*_=copies.environment()
  env['stars']=lambda value,prob=None:''.join(' ' if c==' ' else '*' for c in (value or ''))
  for name,args in [('set_name','P,value,edit=None'),('crumple','P')]:
   env['paper_document_'+name]=vm.project(PHYSICAL,'/proc/paper_document_'+name,args,env)
  actor=copies.vm.Actor();actor.languages=[langs[EN],langs[RU]];pen=copies.vm.Pen(actor);paper=Paper(actor);service=Base(paper,actor)
  self.assertTrue(service.initialize(actor,pen));r=paper.document_record
  self.assertTrue(service.append(actor,pen,r['document_id'],r['revision'],RU,'body','UNKNOWN_CANARY'))
  stale=env['paper_document_copy_snapshot'](paper);token=env['paper_document_prepare_edit'](paper)
  self.assertTrue(env['paper_document_set_name'](paper,'Folded public label',token))
  self.assertFalse(env['paper_document_copy_current'](stale))
  self.assertTrue(env['paper_document_crumple'](paper));current=copy.deepcopy(paper.document_record)
  snapshot=env['paper_document_copy_snapshot'](paper);result=env['paper_document_create_copy'](snapshot)
  self.assertIsNotNone(result);self.assertNotEqual(result.document_record['document_id'],current['document_id'])
  self.assertEqual(result.document_record['sections'],current['sections'])
  self.assertEqual(env['paper_document_legacy_snapshot'](result),current['legacy'])
  self.assertIsNot(result.document_record['sections'],paper.document_record['sections'])
  result.document_record['sections'][0]['text']='different copy'
  self.assertEqual(paper.document_record,current)
 def test_changed_damage_candidate_cannot_commit_after_nested_source_mutation(self):
  before=copy.deepcopy(self.initialize());space=self.paper.free_space
  def damaged(value,prob=None):
   self.paper.document_record['sections'][0]['text']='concurrent callback seam'
   return '*'*len(value or '')
  self.env['stars']=damaged;self.assertFalse(self.crumple())
  self.assertEqual(self.paper.info,before['legacy']['info']);self.assertEqual(self.paper.free_space,space)
  self.assertEqual(self.paper.document_record['sections'][0]['text'],'concurrent callback seam')

if __name__=='__main__':unittest.main()
