"""Stamp recording projections (stamps.dm); not native DM or real overlays."""
import copy,importlib.util,json,re,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('stamp_view_fixture',Path(__file__).with_name('test_views.py'))
views=importlib.util.module_from_spec(spec);spec.loader.exec_module(views)
vm=views.vm
STAMPS=(vm.ROOT/'code/modules/paperwork/stamps.dm').read_text(encoding='utf-8')
PAPER=(vm.ROOT/'code/game/objects/items/paper/paper.dm').read_text(encoding='utf-8')
VIEW=(vm.ROOT/'code/modules/paperwork/view.dm').read_text(encoding='utf-8')
CLIPBOARD=(vm.ROOT/'code/game/objects/items/clipboard.dm').read_text(encoding='utf-8')
EDITOR_TSX=(vm.ROOT/'tgui/src/interfaces/PaperEditor.tsx').read_text(encoding='utf-8')
EN='civ13:english:v1';RU='civ13:russian:v1'
LIMIT=int(re.search(r'#define PAPER_STAMP_LIMIT (\d+)',STAMPS)[1])

class Stamp(vm.Ref):
 def __init__(self,state='stamp-approved',name='APPROVED ink stamp'):self.icon_state=state;self.name=name;self.gc_destroyed=False

def environment(reach=True):
 env,Base,Reader,langs,render=views.environment()
 env['findtext']=lambda text,needle:(text or '').find(needle)+1
 env['PAPER_STAMP_LIMIT']=LIMIT
 env['refreshed']=[]
 env['notified']=[]
 env['paper_authoring_notify']=lambda source,reason,exempt=None:env['notified'].append(reason)
 env['paper_stamp_can_reach']=lambda P,user,S:reach
 env['paper_stamp_marker']=lambda S:'<img src="paperstamp_'+S.icon_state+'.png">'
 env['paper_stamp_refresh_overlays']=lambda P:env['refreshed'].append(P)
 vm.ALLOWED |= {'findtext','paper_stamp_can_reach','paper_stamp_marker','paper_stamp_list_with','paper_stamp_join','paper_stamp_refresh_overlays'}
 vm.METHODS |= {'Copy'}
 class DMList(list):
  def Copy(self):return DMList(self)
 def list_with(current,state):
  result=DMList(current) if isinstance(current,list) else DMList()
  result.append(state);return result
 env['paper_stamp_list_with']=list_with
 env['paper_stamp_join']=lambda current,marker:(current+marker) if current else '<BR>'+marker
 apply=vm.project(STAMPS,'/proc/paper_document_apply_stamp','P,S,user',env)
 return env,Base,langs,apply

class Stamps(unittest.TestCase):
 def setUp(self):
  self.env,self.Base,self.langs,self.apply=environment()
  self.actor=vm.Actor();self.actor.languages=[self.langs[EN],self.langs[RU]];self.pen=vm.Pen(self.actor)
  self.paper=vm.Paper(self.actor,views.LEGACY);self.paper.icon_state='paper_words';self.service=self.Base(self.paper,self.actor)
 def classify(self):
  self.assertTrue(self.service.initialize(self.actor,self.pen))
  for lang,kind,text in [(EN,'body','PUBLIC'),(RU,'title','SECRET_TITLE')]:
   r=self.paper.document_record;self.assertTrue(self.service.append(self.actor,self.pen,r['document_id'],r['revision'],lang,kind,text))
  return self.paper.document_record
 def test_unclassified_stamp_is_saved_in_both_fields_and_redrawn(self):
  info=self.paper.info;old=self.paper.stamps
  self.assertEqual(self.apply(self.paper,Stamp(),self.actor),'stamped')
  self.assertEqual(self.paper.stamped,['stamp-approved'])
  self.assertEqual(self.paper.stamps,old+'<img src="paperstamp_stamp-approved.png">')
  self.assertEqual(self.paper.info,info);self.assertIsNone(self.paper.document_record)
  self.assertEqual(self.env['refreshed'],[self.paper]);self.assertEqual(self.env['notified'],['physical'])
 def test_stamp_list_is_replaced_not_aliased(self):
  shared=[];self.paper.stamped=shared
  self.apply(self.paper,Stamp('seal-court','court seal stamp'),self.actor)
  self.assertEqual(shared,[]);self.assertEqual(self.paper.stamped,['seal-court'])
 def test_classified_stamp_commits_one_revision_and_keeps_sections(self):
  before=copy.deepcopy(self.classify())
  self.assertEqual(self.apply(self.paper,Stamp(),self.actor),'stamped')
  after=self.paper.document_record
  self.assertEqual(after['revision'],before['revision']+1);self.assertEqual(after['sections'],before['sections'])
  self.assertEqual(after['document_id'],before['document_id'])
  self.assertEqual(after['legacy']['stamped'],['stamp-approved']);self.assertEqual(self.paper.stamped,['stamp-approved'])
  self.assertEqual(after['legacy']['stamps'],self.paper.stamps);self.assertTrue(self.paper.stamps.endswith('paperstamp_stamp-approved.png">'))
  self.assertTrue(self.env['paper_document_record_valid'](after))
  # The committed record still projects for a reader after the stamp.
  projected=self.service.project(self.actor);self.assertNotIn('error',projected)
  self.assertTrue(projected['legacy_body_html'].endswith('paperstamp_stamp-approved.png">'))
 def test_classified_stale_legacy_refuses_without_change(self):
  self.classify();self.paper.info='changed outside the transaction';before=copy.deepcopy(self.paper.document_record)
  self.assertEqual(self.apply(self.paper,Stamp(),self.actor),'failed')
  self.assertEqual(self.paper.document_record,before);self.assertEqual(self.paper.stamped,[]);self.assertEqual(self.env['refreshed'],[])
 def test_crumpled_full_and_unreachable_pages_refuse(self):
  self.paper.icon_state='scrap';self.assertEqual(self.apply(self.paper,Stamp(),self.actor),'crumpled')
  self.paper.icon_state='scrollpaper1_scrap';self.assertEqual(self.apply(self.paper,Stamp(),self.actor),'crumpled')
  self.paper.icon_state='paper_words';self.paper.stamped=['stamp-deny']*LIMIT
  self.assertEqual(self.apply(self.paper,Stamp(),self.actor),'full');self.assertEqual(len(self.paper.stamped),LIMIT)
  self.paper.stamped=[];self.assertEqual(self.apply(self.paper,Stamp(''),self.actor),'failed')
  env,Base,langs,apply=environment(reach=False)
  self.assertEqual(apply(self.paper,Stamp(),self.actor),'failed');self.assertEqual(self.paper.stamped,[])
 def test_old_type_path_entries_are_kept(self):
  path=vm.TypePath('/obj/item/weapon/stamp');self.paper.stamped=[path]
  self.assertEqual(self.apply(self.paper,Stamp(),self.actor),'stamped')
  self.assertIs(self.paper.stamped[0],path);self.assertEqual(self.paper.stamped[1],'stamp-approved')
 def test_routes_and_display_are_wired(self):
  route=PAPER.split('/obj/item/weapon/paper/attackby(',1)[1].split('/obj/item/weapon/paper/Court/british',1)[0]
  self.assertIn('else if (istype(P, /obj/item/weapon/stamp))',route)
  self.assertIn('paper_document_apply_stamp(src, P, user)',route)
  self.assertNotIn('// stamps +=',route);self.assertNotIn('stamp/mail',route)
  self.assertIn('paper_stamp_refresh_overlays(src)',vm.body(PAPER,'/obj/item/weapon/paper/update_icon'))
  self.assertIn('paper_stamp_refresh_overlays(src)',vm.body(PAPER,'/obj/item/weapon/paper/official/update_icon'))
  self.assertIn('paper_stamp_refresh_overlays(src)',vm.body(STAMPS,'/obj/item/weapon/paper/after_load'))
  self.assertIn('paper_stamp_send_assets(reader, src)',vm.body(VIEW,'/obj/item/weapon/paper/proc/document_classic_html'))
  self.assertIn('istype(W, /obj/item/weapon/stamp)',CLIPBOARD)
  self.assertIn("stampLabel(element.getAttribute('alt'))",EDITOR_TSX)
 def test_marker_holds_no_runtime_reference(self):
  marker=vm.body(STAMPS,'/proc/paper_stamp_marker')
  self.assertNotIn('\\ref',marker);self.assertIn('html_encode(S.name)',marker)
  self.assertIn('"stamp_overlay_images"',STAMPS)

if __name__=='__main__':unittest.main()
