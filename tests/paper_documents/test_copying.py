"""Complete copy/admission procedure projections with explicit inert engine seams.

Not native BYOND, real-client inventory/callback ordering, persistence or delivery.
"""
import copy, importlib.util, json, re, unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('copy_view_fixture',Path(__file__).with_name('test_views.py'))
views=importlib.util.module_from_spec(spec);spec.loader.exec_module(views)
vm=views.vm
SOURCE=(vm.ROOT/'code/modules/paperwork/copy.dm').read_text(encoding='utf-8')
PAPER=(vm.ROOT/'code/game/objects/items/paper/paper.dm').read_text(encoding='utf-8')
PRESS=(vm.ROOT/'code/modules/1713/production.dm').read_text(encoding='utf-8')
MAIL=(vm.ROOT/'code/game/objects/structures/noticeboard.dm').read_text(encoding='utf-8')
TELE=(vm.ROOT/'code/modules/1713/telegraph.dm').read_text(encoding='utf-8')
EN='civ13:english:v1';RU='civ13:russian:v1';PLAIN='/obj/item/weapon/paper'

class Turf(vm.Ref):kind='turf'
class Machine(vm.Ref):
 def __init__(self,place):
  self.loc=place;self.gc_destroyed=False;self.near=True;self.copying=False
  self.base=[];self.copy=[];self.events=[];self.icon_state='printingpress0'
  self.faction='fixture';self.receive_only=False
 def Adjacent(self,actor):return self.near
 def visible_message(self,text):self.events.append(text)

def environment(source=None,paper_source=None):
 source=SOURCE if source is None else source;paper_source=PAPER if paper_source is None else paper_source
 env,Base,Reader,langs,render=views.environment()
 state=dict(created=[],all_papers=[],deleted=[],world=[],prompt=lambda:'Original',wait=lambda:True,create_hook=lambda p:None,transfer_hook=lambda p:None)
 class Paper(vm.Paper):
  def __init__(self,owner=None,legacy=None):
   super().__init__(owner,legacy or views.LEGACY)
   self.type=vm.TypePath(PLAIN);self.desc='Fixture facsimile';self.rigged=False;self.spam_flag=False
   self.deffont='Verdana';self.signfont='Times New Roman';self.crayonfont='Comic Sans MS';self.effects=[]
   state['all_papers'].append(self)
  def updateinfolinks(self):self.info_links='rebuilt-for-copy';self.effects.append('links')
  def update_icon(self):self.effects.append('icon')
 original_type=env['istype']
 def istype(value,path=None):
  if path is None:return isinstance(value,Paper)
  if path=='/mob/living':return isinstance(value,vm.Actor) and value.kind!='ghost'
  return original_type(value,path)
 def factory():
  p=Paper();p.loc=None;state['created'].append(p);state['create_hook'](p);return p
 def qdel(value):
  if value is not None:value.gc_destroyed=True;value.loc=None;state['deleted'].append(value)
 def remove_input(items,item):
  # Native -= removes the last matching occurrence. Inputs are singletons here.
  for i in range(len(items)-1,-1,-1):
   if items[i] is item:items.pop(i);return
 def append_input(items,item):items.append(item)
 def unique_input(items,item):
  if not any(x is item for x in items):items.append(item)
 def wait(actor,delay,machine):
  state['delay']=delay;return state['wait']()
 def prompt(*args):return state['prompt']()
 def parent_destroy(machine):
  # Explicit parent effect seam: movable Destroy deletes contents after override.
  for p in state['all_papers']:
   if p.loc is machine:qdel(p)
  machine.gc_destroyed=True;return True
 env.update(istype=istype,MAX_FIELDS=50,new_copy_paper=factory,qdel=qdel,
  get_turf=lambda a:a.loc if a and isinstance(a.loc,Turf) else None,
  remove_input=remove_input,append_input=append_input,unique_input=unique_input,
  paper_inputs=lambda items:[x for x in (items or []) if isinstance(x,Paper)],
  do_after=wait,WWinput=prompt,parent_destroy=parent_destroy,world=state['world'])
 names={'paper_document_copy_metadata_valid','paper_document_copy_metadata','paper_document_copy_snapshot','paper_document_copy_current','paper_document_create_copy','paper_document_copy_actor_valid','new_copy_paper','qdel','get_turf','remove_input','append_input','unique_input','paper_inputs','do_after','WWinput','parent_destroy'}
 vm.ALLOWED |= names
 vm.METHODS |= {'document_copy_legacy_valid','updateinfolinks','update_icon','visible_message','transfer_held_item_to'}
 Paper.document_copy_legacy_valid=vm.project(paper_source,'/obj/item/weapon/paper/proc/document_copy_legacy_valid','self,legacy',env)
 adapted=source
 marker='var/obj/item/weapon/paper/result = new /obj/item/weapon/paper(null, TRUE)'
 assert adapted.count(marker)==1,'Constructor seam must include location and TRUE capacity flag'
 adapted=adapted.replace(marker,'var/result = new_copy_paper()')
 for field in ('base','copy'):
  adapted=adapted.replace('src.'+field+'.len','length(src.'+field+')')
  adapted=adapted.replace('src.'+field+'[1]','src.'+field+'[0]')
  for item in ('original','stock','P'):
   adapted=adapted.replace('src.'+field+' -= '+item,'remove_input(src.'+field+','+item+')')
  adapted=adapted.replace('src.'+field+' += P','append_input(src.'+field+',P)')
 adapted=adapted.replace('choices += "Original"','choices.append("Original")').replace('choices += "Copy"','choices.append("Copy")')
 adapted=adapted.replace('papers |= original','unique_input(papers,original)').replace('papers |= stock','unique_input(papers,stock)')
 adapted=adapted.replace('for (var/obj/item/weapon/paper/original in src.base)','for (var/original in paper_inputs(src.base))')
 adapted=adapted.replace('for (var/obj/item/weapon/paper/stock in src.copy)','for (var/stock in paper_inputs(src.copy))')
 adapted=adapted.replace('receivers[check_index]','receivers[check_index-1]').replace('places[check_index]','places[check_index-1]')
 adapted=adapted.replace('outputs[publish_index]','outputs[publish_index-1]').replace('places[publish_index]','places[publish_index-1]')
 adapted=adapted.replace('return ..()','return parent_destroy(src)')
 for name,args in [('copy_metadata_valid','data'),('copy_metadata','P'),('copy_snapshot','P'),('copy_current','snapshot'),('create_copy','snapshot'),('copy_actor_valid','actor,expected_client,machine')]:
  env['paper_document_'+name]=vm.project(adapted,'/proc/paper_document_'+name,args,env)
 insert=vm.project(adapted,'/obj/structure/printingpress/proc/insert_copy_paper','src,P,actor',env)
 press=vm.project(adapted,'/obj/structure/printingpress/proc/copy_paper_document','src,actor',env)
 destroy=vm.project(adapted,'/obj/structure/printingpress/Destroy','src',env)
 mail=vm.project(adapted,'/obj/structure/mailbox/proc/copy_paper_delivery','src,original,actor',env)
 def transfer(actor,p,machine):
  if p.loc is not actor or actor.active is not p:return False
  p.loc=machine;actor.active=None;state['transfer_hook'](p)
  return not p.gc_destroyed and p.loc is machine
 return env,Base,Reader,langs,render,Paper,state,insert,press,destroy,mail,transfer

class Copies(unittest.TestCase):
 def setUp(self):
  self.env,self.Base,self.Reader,self.langs,self.render,self.Paper,self.state,self.insert,self.press,self.destroy,self.mail,self.transfer=environment()
  self.actor=vm.Actor();self.actor.languages=[self.langs[EN],self.langs[RU]]
  self.actor.transfer_held_item_to=lambda p,m:self.transfer(self.actor,p,m)
  self.pen=vm.Pen(self.actor);self.place=Turf();self.actor.loc=self.place;self.machine=Machine(self.place)
  self.paper=self.Paper(self.actor)
 def classified(self):
  service=self.Base(self.paper,self.actor);self.assertTrue(service.initialize(self.actor,self.pen))
  for lang,kind,text in [(EN,'body','KNOWN_BODY'),(RU,'body','UNKNOWN_COPY_CANARY'),(RU,'title','UNKNOWN_TITLE_CANARY'),(RU,'signature','ignored')]:
   self.pen.signature='UNKNOWN_SIGNATURE_CANARY';r=self.paper.document_record
   self.assertTrue(service.append(self.actor,self.pen,r['document_id'],r['revision'],lang,kind,text))
  for kind in ('field_label','field_answer'):
   self.paper.document_record['sections'].append(dict(id=kind,lineage='1'*32,version=1,kind=kind,language_id=RU,text='UNKNOWN_'+kind.upper()+'_CANARY',ink='white',tool='pen'))
  self.assertTrue(self.env['paper_document_record_valid'](self.paper.document_record))
  return self.paper.document_record
 def snapshot(self):return self.env['paper_document_copy_snapshot'](self.paper)
 def create(self,snapshot=None):return self.env['paper_document_create_copy'](snapshot if snapshot is not None else self.snapshot())
 def loaded_press(self):
  self.stock=self.Paper(self.machine);self.paper.loc=self.machine
  self.machine.base=[self.paper];self.machine.copy=[self.stock]
 def test_classified_copy_preserves_canonical_language_identity_and_redacts_view(self):
  before=copy.deepcopy(self.classified());snapshot=self.snapshot();out=self.create(snapshot);self.assertIsNotNone(out)
  self.assertNotEqual(out.document_record['document_id'],before['document_id'])
  for key in ('sections','revision','next_section','legacy_policy'):self.assertEqual(out.document_record[key],before[key])
  self.assertEqual(self.paper.document_record,before);self.assertIsNot(out.document_record,self.paper.document_record)
  self.actor.languages=[self.langs[EN]];out.loc=self.actor
  data=self.Reader(out,self.actor,'paper').project(self.actor)
  self.assertNotIn('UNKNOWN_',json.dumps(data)+self.render(data,out));self.assertIn('KNOWN_BODY',json.dumps(data))
  self.assertEqual(out.info,views.LEGACY['info']);self.assertNotEqual(out.info_links,self.paper.info_links)
  self.assertEqual(out.effects,['links','icon']);self.assertIsNone(getattr(out,'study_progress',None))
  snapshot['record']['sections'][0]['text']='caller changed token'
  self.assertEqual(out.document_record['sections'],before['sections'])
 def test_legacy_null_paths_lists_ink_and_capacity_remain_exact_and_unaliased(self):
  self.paper.stamped=[vm.TypePath('/obj/item/weapon/stamp/test')];self.paper.ico=['fixture'];self.paper.offset_x=[-2];self.paper.offset_y=[3]
  self.paper.fields=None;self.paper.free_space=-10;self.paper.stamps=None
  snapshot=self.snapshot();out=self.create(snapshot);self.assertIsNotNone(out);self.assertIsNone(out.document_record)
  for key in ('name','info','stamps','fields','free_space','stamped','ico','offset_x','offset_y'):self.assertEqual(getattr(out,key),getattr(self.paper,key))
  self.assertIsInstance(out.stamped[0],vm.TypePath);self.assertIsNone(out.fields)
  for key in ('stamped','ico','offset_x','offset_y'):self.assertIsNot(getattr(out,key),getattr(self.paper,key))
  out.stamped.append('different');self.assertEqual(len(self.paper.stamped),1)
  snapshot['legacy']['ico'].append('caller changed token');self.assertEqual(out.ico,['fixture'])
 def test_unknown_malformed_classified_subtype_and_overbudget_refuse_whole(self):
  for case in ('unknown','subtype','overbudget','physical-root'):
   with self.subTest(case=case):
    self.setUp()
    if case=='unknown':self.paper.document_record={'schema_version':999}
    elif case=='subtype':self.classified();self.paper.type=vm.TypePath(PLAIN+'/official')
    elif case=='overbudget':self.paper.ico=[0]*1024
    else:self.paper.stamped='invalid'
    self.assertIsNone(self.snapshot());self.assertFalse(self.state['created'])
 def test_legacy_subtype_remains_generic_facsimile_without_authority_fields(self):
  self.paper.type=vm.TypePath(PLAIN+'/official');self.paper.faction='fixture-government'
  out=self.create();self.assertEqual(out.type,PLAIN);self.assertFalse(hasattr(out,'faction'))
 def test_stale_identity_content_metadata_location_and_deleted_source_reject(self):
  for change in ('identity','text','desc','place','delete'):
   with self.subTest(change=change):
    self.setUp();self.classified();snapshot=self.snapshot()
    if change=='identity':self.paper.document_record=copy.deepcopy(self.paper.document_record)
    elif change=='text':self.paper.document_record['sections'][0]['text']='replacement'
    elif change=='desc':self.paper.desc+=' changed'
    elif change=='place':self.paper.loc=Turf()
    else:self.paper.gc_destroyed=True
    self.assertIsNone(self.create(snapshot));self.assertFalse(self.state['created'])
 def test_constructor_reentry_cleans_unpublished_copy_and_retains_source(self):
  self.classified();before=copy.deepcopy(self.paper.document_record)
  self.state['create_hook']=lambda p:setattr(self.paper,'desc','changed during construction')
  self.assertIsNone(self.create());self.assertEqual(self.paper.document_record,before)
  self.assertEqual(len(self.state['created']),1);self.assertTrue(self.state['created'][0].gc_destroyed)
 def test_press_normal_and_old_null_custody_preserve_original_consume_stock(self):
  for old in (False,True):
   with self.subTest(old=old):
    self.setUp();self.classified();self.loaded_press()
    if old:self.paper.loc=None;self.stock.loc=None
    self.assertTrue(self.press(self.machine,self.actor));self.assertEqual(self.state['delay'],90)
    self.assertIs(self.paper.loc,self.place);self.assertFalse(self.paper.gc_destroyed);self.assertTrue(self.stock.gc_destroyed)
    self.assertIs(self.state['created'][0].loc,self.place);self.assertFalse(self.machine.copying);self.assertEqual(self.machine.base,[]);self.assertEqual(self.machine.copy,[])
 def test_cancel_or_stale_press_wait_keeps_inputs_and_resets_busy(self):
  for change in ('cancel','source','stock','custody','client','page','range','delete'):
   with self.subTest(change=change):
    self.setUp();self.classified();self.loaded_press()
    def wait():
     if change=='source':self.paper.document_record['revision']+=1
     elif change=='stock':self.stock.info+=' other edit'
     elif change=='custody':self.stock.loc=Turf()
     elif change=='client':self.actor.client=vm.Ref();self.actor.client.mob=self.actor
     elif change=='page':self.machine.base=[self.Paper(self.machine)]
     elif change=='range':self.machine.near=False
     elif change=='delete':self.machine.gc_destroyed=True
     return change!='cancel'
    self.state['wait']=wait;self.assertFalse(self.press(self.machine,self.actor))
    self.assertFalse(self.paper.gc_destroyed);self.assertFalse(self.stock.gc_destroyed);self.assertFalse(self.state['created'])
    if change!='delete':self.assertFalse(self.machine.copying);self.assertEqual(self.machine.icon_state,'printingpress0')
 def test_press_constructor_callback_rechecks_stock_and_owns_failed_output(self):
  self.classified();self.loaded_press();self.state['create_hook']=lambda p:setattr(self.stock,'info','changed')
  self.assertFalse(self.press(self.machine,self.actor));self.assertFalse(self.stock.gc_destroyed)
  self.assertTrue(self.state['created'][0].gc_destroyed);self.assertFalse(self.machine.copying)
 def test_press_retirement_during_construction_and_void_publication_cleanup(self):
  for case in ('retired','void'):
   with self.subTest(case=case):
    self.setUp();self.loaded_press()
    if case=='retired':self.state['create_hook']=lambda p:setattr(self.machine,'gc_destroyed',True)
    else:self.state['wait']=lambda:setattr(self.machine,'loc',None) or True
    self.assertFalse(self.press(self.machine,self.actor));self.assertFalse(self.paper.gc_destroyed);self.assertFalse(self.stock.gc_destroyed)
    self.assertTrue(self.state['created'][0].gc_destroyed)
 def test_insert_normal_cancel_stale_slot_revision_session_and_drop_callbacks(self):
  for change in ('normal','cancel','slot','text','client','range','transfer'):
   with self.subTest(change=change):
    self.setUp();self.classified();self.actor.active=self.paper
    def prompt():
     if change=='slot':self.machine.base=[self.Paper()]
     elif change=='text':self.paper.document_record['revision']+=1
     elif change=='client':self.actor.client=vm.Ref();self.actor.client.mob=self.actor
     elif change=='range':self.machine.near=False
     return 'Cancel' if change=='cancel' else 'Original'
    self.state['prompt']=prompt
    if change=='transfer':self.state['transfer_hook']=lambda p:setattr(self.actor,'stat',1)
    self.assertEqual(self.insert(self.machine,self.paper,self.actor),change=='normal')
    if change=='normal':self.assertIs(self.paper.loc,self.machine);self.assertEqual(self.machine.base,[self.paper])
    else:self.assertNotIn(self.paper,self.machine.base);self.assertNotIn(self.paper,self.machine.copy)
    if change not in ('normal','transfer'):self.assertIs(self.paper.loc,self.actor)
    self.assertFalse(self.paper.gc_destroyed)
 def test_destroy_recovers_only_retained_papers_once_and_ignores_books_or_stolen(self):
  self.loaded_press();self.stock.loc=None;stolen=self.Paper(self.actor);book=vm.Ref()
  self.machine.base += [self.paper,stolen,book];self.machine.copy += [self.paper]
  self.assertTrue(self.destroy(self.machine));self.assertIs(self.paper.loc,self.place);self.assertIs(self.stock.loc,self.place)
  self.assertIs(stolen.loc,self.actor);self.assertIn(book,self.machine.base);self.assertFalse(self.paper.gc_destroyed)
 def test_destruction_during_held_transfer_rescues_reserved_input_before_parent(self):
  self.actor.active=self.paper
  self.state['transfer_hook']=lambda p:self.destroy(self.machine)
  self.assertFalse(self.insert(self.machine,self.paper,self.actor))
  self.assertTrue(self.machine.gc_destroyed);self.assertFalse(self.paper.gc_destroyed)
  self.assertIs(self.paper.loc,self.place);self.assertNotIn(self.paper,self.machine.base)
 def test_transfer_callback_malformed_slot_rejects_without_cleanup_exception(self):
  self.actor.active=self.paper;self.state['transfer_hook']=lambda p:setattr(self.machine,'base',None)
  self.assertFalse(self.insert(self.machine,self.paper,self.actor))
  self.assertFalse(self.paper.gc_destroyed);self.assertIs(self.paper.loc,self.place);self.assertFalse(self.machine.copying)
 def receivers(self,count=2):
  result=[Machine(Turf()) for _ in range(count)];self.state['world'][:]=result;return result
 def test_mail_fanout_copies_canonical_original_not_projection_or_aliases(self):
  before=copy.deepcopy(self.classified());targets=self.receivers();self.actor.languages=[self.langs[EN]]
  self.assertTrue(self.mail(self.machine,self.paper,self.actor));self.assertTrue(self.paper.gc_destroyed)
  self.assertEqual(len(self.state['created']),2)
  for out,target in zip(self.state['created'],targets):
   self.assertIs(out.loc,target.loc);self.assertEqual(out.document_record['sections'],before['sections'])
  self.assertNotEqual(self.state['created'][0].document_record['document_id'],self.state['created'][1].document_record['document_id'])
  self.state['created'][0].document_record['sections'][0]['text']='independent'
  self.assertEqual(self.state['created'][1].document_record['sections'],before['sections'])
 def test_mail_no_receivers_and_constructor_changes_preserve_original_and_cleanup(self):
  for change in ('none','source','receiver','faction','client','deleted-copy'):
   with self.subTest(change=change):
    self.setUp();self.classified();targets=self.receivers(0 if change=='none' else 2)
    def hook(p):
     if len(self.state['created'])!=2:return
     if change=='source':self.paper.document_record['revision']+=1
     elif change=='receiver':targets[0].loc=Turf()
     elif change=='faction':self.machine.faction='changed'
     elif change=='client':self.actor.client=vm.Ref();self.actor.client.mob=self.actor
     elif change=='deleted-copy':p.gc_destroyed=True
    self.state['create_hook']=hook
    self.assertFalse(self.mail(self.machine,self.paper,self.actor));self.assertFalse(self.paper.gc_destroyed)
    self.assertTrue(all(p.gc_destroyed for p in self.state['created']))
 def test_real_routes_register_and_never_forward_cached_html_or_classified_teleprint(self):
  self.assertIn('return insert_copy_paper(W, user)',vm.body(PRESS,'/obj/structure/printingpress/attackby'))
  self.assertIn('return copy_paper_document(H)',vm.body(PRESS,'/obj/structure/printingpress/attack_hand'))
  self.assertIn('copy_paper_delivery',vm.body(MAIL,'/obj/structure/mailbox/attackby'))
  self.assertNotIn('info_links =',SOURCE)
  self.assertIn('!isnull(document.document_record)',vm.body(TELE,'/obj/structure/teleprinter/attackby'))
  self.assertIn('!isnull(C.document_record)',vm.body(TELE,'/obj/structure/teleprinter/proc/print'))
  self.assertIn('!copy_skip_space && isnull(document_record)',PAPER)
  self.assertIn('/obj/item/weapon/paper/New(var/newloc, var/copy_skip_space = FALSE)',PAPER)
 def test_delayed_constructor_capacity_guard_has_legacy_positive_and_copy_controls(self):
  matched=re.search(r'^\tspawn\(2\)\n((?:\t\t[^\n]*\n|\n)+)',PAPER,re.M)
  self.assertIsNotNone(matched,'Missing complete delayed constructor block')
  code=''.join(line[1:] if line.startswith('\t') else line for line in matched[1].splitlines(True))
  for field in ('gc_destroyed','document_record','info'):
   code=re.sub(r'(?<![\w.])'+field+r'\b','self.'+field,code)
  for method in ('update_icon','update_space','updateinfolinks'):
   code=re.sub(r'(?<![\w.])'+method+r'\(',r'self.'+method+'(',code)
  vm.METHODS.add('update_space')
  callback=vm.project('/callback()\n'+code,'/callback','self,copy_skip_space=False',self.env)
  for skip,classified,deleted,expected in [(False,False,False,1),(True,False,False,0),(False,True,False,0),(False,False,True,0)]:
   with self.subTest(skip=skip,classified=classified,deleted=deleted):
    p=self.Paper();p.document_record={} if classified else None;p.gc_destroyed=deleted
    calls=[];p.update_space=lambda text:calls.append(text);callback(p,skip)
    self.assertEqual(len(calls),expected)
 def test_teleprinter_legacy_positive_and_classified_deleted_lost_custody_negative(self):
  env=self.env
  env.update(isemptylist=lambda x:not x,strip_html_properly=lambda x:re.sub('<[^>]*>','',x),format_telegram=lambda text:'<b>Telegram fixture: '+text+'</b><br>')
  vm.ALLOWED |= {'isemptylist','strip_html_properly','format_telegram'}
  code=TELE.replace('for(var/obj/item/weapon/paper/C in inpaper)','for (var/C in paper_inputs(src.inpaper))').replace('isemptylist(inpaper)','isemptylist(src.inpaper)')
  marker='new_text = "<b><font face=\'Courier New\'>Telegram at [roundduration2text_days()]: [new_text]</b></font><br>"'
  self.assertEqual(code.count(marker),1,'Clock/format seam drift')
  code=code.replace(marker,'new_text = format_telegram(new_text)')
  printer=vm.project(code,'/obj/structure/teleprinter/proc/print','src,new_text',env)
  for case in ('legacy','classified','deleted','moved','full'):
   with self.subTest(case=case):
    p=self.Paper();p.loc=None
    if case=='classified':p.document_record={'schema_version':999}
    elif case=='deleted':p.gc_destroyed=True
    elif case=='moved':p.loc=self.actor
    elif case=='full':p.free_space=21
    before=(p.info,p.free_space);self.machine.inpaper=[p];printer(self.machine,'TEST')
    self.assertEqual((p.info,p.free_space)!=before,case=='legacy')

if __name__=='__main__':unittest.main()
