"""Offline projections of complete reader procedures; no native/client acceptance."""
import copy
import html
import importlib.util
import json
from pathlib import Path
import re
import unittest

spec=importlib.util.spec_from_file_location('paper_view_projection',Path(__file__).with_name('projection.py'))
vm=importlib.util.module_from_spec(spec);spec.loader.exec_module(vm)
ROOT=vm.ROOT
SOURCE=(ROOT/'code/modules/paperwork/view.dm').read_text(encoding='utf-8')
LEGACY=json.loads((Path(__file__).parent/'fixtures/legacy.json').read_text(encoding='utf-8'))
EN='civ13:english:v1';RU='civ13:russian:v1'
ROUTES=('paper','editor','clipboard','folder','bundle','noticeboard')

class Container(vm.Ref):
 def __init__(self,kind,actor):
  self.kind=kind;self.loc=actor;self.gc_destroyed=False;self.near=True;self.pages=[];self.page=1
 def Adjacent(self,reader):return self.near

def environment(source=SOURCE):
 env,Base,langs=vm.environment()
 original_type=env['istype']
 def istype(value,path=None):
  kinds={'/obj/structure/noticeboard':'noticeboard','/obj/item/weapon/paper_bundle':'bundle'}
  return getattr(value,'kind',None)==kinds[path] if path in kinds else original_type(value,path)
 env.update(istype=istype,in_range=lambda actor,item:getattr(item,'near',True),
            is_bundle=lambda x:getattr(x,'kind',None)=='bundle',html_encode=lambda x:html.escape('' if x is None else str(x),quote=True),html_decode=html.unescape,
            replacetext=lambda text,old,new:text.replace(old,new),parent_project=lambda self,reader,forceshow:Base.project(self,reader,forceshow))
 vm.ALLOWED |= {'in_range','is_bundle','html_encode','html_decode','replacetext','parent_project','paper_document_route_access'}
 # Explicit inert seams: nested native list length/index, null var default,
 # subclass parent dispatch and inherited request fields. No DM statement omitted.
 # Protect HTML closing-tag literals from the shared DM typepath tokenizer.
 adapted=source.replace('</','<\\x2f').replace('B.pages.len','length(B.pages)').replace('B.pages[B.page]','B.pages[B.page-1]').replace('istype(B)','is_bundle(B)').replace('istype(reader)','is_actor(reader)')
 adapted=adapted.replace('var/list/result\n','var/list/result = null\n')
 adapted=adapted.replace('result = ..()','result = parent_project(self, reader, forceshow)')
 adapted=adapted.replace('"[paper.info_links][paper.stamps]"','dm_text(paper.info_links)+dm_text(paper.stamps)')
 adapted=adapted.replace('"[paper.info][paper.stamps]"','dm_text(paper.info)+dm_text(paper.stamps)')
 adapted=adapted.replace('data["error"]','data.get("error")').replace('result["error"]','result.get("error")').replace('data["legacy_monospace"]','data.get("legacy_monospace")')
 pieces=re.split(r'("(?:[^"\\]|\\.)*")',adapted)
 for i in range(0,len(pieces),2):
  pieces[i]=re.sub(r'(?<![\w.])(read_route|read_owner)\b',lambda m:'self.'+m[1],pieces[i])
 adapted=''.join(pieces)
 env['paper_document_route_access']=vm.project(adapted,'/proc/paper_document_route_access','P,reader,route,owner',env)
 class Reader(Base):
  def __init__(self,paper,actor,route,owner=None):
   super().__init__(paper,actor);self.read_route=route;self.read_owner=owner
 Reader.has_access=vm.project(adapted,'/datum/paper_document_reader/has_access','self,reader,writing=False',env,True)
 Reader.project=vm.project(adapted,'/datum/paper_document_reader/project','self,reader,forceshow=False',env,True)
 renderer=vm.project(adapted,'/proc/paper_document_view_body','data,P',env)
 env['paper_document_view_title']=vm.project(adapted,'/proc/paper_document_view_title','value',env)
 return env,Base,Reader,langs,renderer

class Views(unittest.TestCase):
 def setUp(self):
  self.env,self.Base,self.Reader,self.langs,self.render=environment()
  self.actor=vm.Actor();self.actor.languages=[self.langs[EN],self.langs[RU]]
  self.pen=vm.Pen(self.actor);self.paper=vm.Paper(self.actor,LEGACY)
  self.paper.deffont='Verdana';self.paper.signfont='Times New Roman';self.paper.crayonfont='Comic Sans MS';self.paper.near=True
 def context(self,route):
  self.paper.loc=self.actor;owner=None
  if route in ('clipboard','folder','bundle','noticeboard'):
   owner=Container(route,self.actor);self.paper.loc=owner
   if route=='bundle':owner.pages=[self.paper]
  return self.Reader(self.paper,self.actor,route,owner)
 def classify(self):
  service=self.Base(self.paper,self.actor);self.assertTrue(service.initialize(self.actor,self.pen))
  for kind in ('body','title','signature'):
   self.pen.signature='UNKNOWN_SIGNATURE_CANARY'
   record=self.paper.document_record
   self.assertTrue(service.append(self.actor,self.pen,record['document_id'],record['revision'],RU,kind,'UNKNOWN_'+kind.upper()+'_CANARY'))
  record=self.paper.document_record
  for kind in ('field_label','field_answer'):
   record['sections'].append(dict(id=kind,lineage='1'*32,version=1,kind=kind,language_id=RU,text='UNKNOWN_'+kind.upper()+'_CANARY',ink='white',tool='pen'))
  self.assertTrue(self.env['paper_document_record_valid'](record))
  self.actor.languages=[self.langs[EN]]
 def test_every_route_redacts_all_unknown_text_in_complete_data_and_html(self):
  self.classify();canonical=copy.deepcopy(self.paper.document_record)
  # A stale link cache must never substitute for classified projection.
  self.paper.info_links='UNKNOWN_LINK_CACHE_CANARY'
  for route in ROUTES:
   with self.subTest(route=route):
    request=self.context(route);self.assertTrue(request.has_access(self.actor))
    data=request.project(self.actor);encoded=json.dumps(data)+self.render(data,self.paper)
    self.assertNotIn('UNKNOWN_',encoded);self.assertIn('[Unintelligible writing]',encoded)
    self.assertEqual(self.paper.document_record,canonical)
 def test_legacy_reads_do_not_initialize_or_rewrite_stored_paper(self):
  before={k:copy.deepcopy(getattr(self.paper,k)) for k in LEGACY}
  for route in ROUTES:
   request=self.context(route);data=request.project(self.actor)
   self.assertIsNone(self.paper.document_record)
   expected=LEGACY['info']+LEGACY['stamps']
   if route=='editor':expected=LEGACY['info_links']+LEGACY['stamps']
   if route=='noticeboard':expected=LEGACY['info']
   self.assertEqual(data['legacy_body_html'],expected)
  for key,value in before.items():self.assertEqual(getattr(self.paper,key),value)
 def test_literacy_and_existing_board_editor_legacy_readability_are_separate(self):
  for kind,forceshow,legacy_full in [('human',False,True),('animal',False,False),('ghost',False,True),('ghost',True,False)]:
   self.actor.kind=kind
   for route in ROUTES:
    data=self.context(route).project(self.actor,forceshow)
    expected_full=legacy_full or route in ('editor','noticeboard')
    self.assertIn(LEGACY['info'] if expected_full and route!='editor' else LEGACY['info_links'] if route=='editor' else '*'*len(LEGACY['info']),data['legacy_body_html'])
  self.actor.kind='human';self.paper.loc=self.actor;self.classify();self.actor.languages=[self.langs[RU]]
  for kind,forceshow,understood in [('human',False,True),('animal',False,False),('ghost',False,True),('ghost',True,False)]:
   self.actor.kind=kind
   for route in ROUTES:
    encoded=json.dumps(self.context(route).project(self.actor,forceshow))
    self.assertEqual('UNKNOWN_BODY_CANARY' in encoded,understood)
 def test_request_rejects_reconnected_transferred_or_foreign_controller(self):
  for route in ROUTES:
   request=self.context(route);old=self.actor.client
   self.actor.client=vm.Ref();self.actor.client.mob=self.actor
   self.assertIsNone(request.project(self.actor));self.actor.client=old
   old.mob=vm.Actor();self.assertIsNone(request.project(self.actor));old.mob=self.actor
   self.assertIsNone(request.project(vm.Actor()))
   self.assertIsNotNone(request.project(self.actor))
 def test_membership_container_movement_and_actual_page_identity_rechecked(self):
  for route in ('clipboard','folder','bundle','noticeboard'):
   request=self.context(route);owner=request.read_owner
   self.paper.loc=self.actor;self.assertIsNone(request.project(self.actor));self.paper.loc=owner
   owner.gc_destroyed=True;self.assertIsNone(request.project(self.actor));owner.gc_destroyed=False
   if route in ('clipboard','folder'):
    owner.loc=vm.Actor();self.assertIsNone(request.project(self.actor));owner.loc=self.actor
   elif route=='noticeboard':
    owner.near=False;self.assertIsNone(request.project(self.actor));owner.near=True
   else:
    owner.loc=vm.Actor();owner.near=False;self.assertIsNone(request.project(self.actor));owner.loc=self.actor;owner.near=True
    folder=Container('folder',self.actor);owner.loc=folder;owner.near=False
    self.assertIsNotNone(request.project(self.actor));folder.loc=vm.Actor();self.assertIsNone(request.project(self.actor))
    folder.loc=self.actor;folder.gc_destroyed=True;self.assertIsNone(request.project(self.actor));owner.loc=self.actor;owner.near=True
    for page in (0,2,1.5,'bad',None):
     owner.page=page;self.assertIsNone(request.project(self.actor))
    owner.page=1;owner.pages=[vm.Ref()];self.assertIsNone(request.project(self.actor));owner.pages=[self.paper]
   self.assertIsNotNone(request.project(self.actor))
 def test_every_reader_context_is_incapable_of_mutation(self):
  for route in ROUTES:
   request=self.context(route)
   self.assertFalse(request.has_access(self.actor,True))
   self.assertFalse(request.can_mutate(self.actor,self.pen))
   self.assertFalse(request.initialize(self.actor,self.pen))
   self.assertIsNone(self.paper.document_record)
 def test_lost_range_state_and_unknown_route_fail_without_payload(self):
  self.paper.near=False
  self.assertIsNone(self.context('paper').project(self.actor))
  self.actor.kind='ghost';self.assertIsNotNone(self.context('paper').project(self.actor));self.actor.kind='human'
  self.paper.near=True
  self.assertIsNone(self.context('untrusted-route').project(self.actor))
  for route in ('clipboard','folder','editor'):
   self.actor.bound=True;self.assertIsNone(self.context(route).project(self.actor));self.actor.bound=False
   self.actor.stat=1;self.assertIsNone(self.context(route).project(self.actor));self.actor.stat=0
 def test_stale_or_malformed_classified_records_never_fall_back_to_raw_cache(self):
  self.classify();self.paper.info_links='UNKNOWN_CACHE_CANARY'
  for cause in ('legacy','schema','language'):
   record=copy.deepcopy(self.paper.document_record);old_info=self.paper.info
   if cause=='legacy':self.paper.info='changed'
   if cause=='schema':self.paper.document_record['schema_version']=2
   if cause=='language':self.paper.document_record['sections'][0]['language_id']='unregistered'
   for route in ROUTES:
    data=self.context(route).project(self.actor);self.assertEqual(set(data),{'error'})
    self.assertEqual(self.render(data,self.paper),'<b>Unable to read this document.</b>')
    self.assertNotIn('UNKNOWN_',json.dumps(data))
   self.paper.document_record=record;self.paper.info=old_info
 def test_known_new_ink_signature_and_literal_markup_render_without_reinterpretation(self):
  self.classify();self.actor.languages=[self.langs[RU]]
  for section in self.paper.document_record['sections']:section['text']='<script> literal & text\nnext'
  result=self.render(self.context('paper').project(self.actor),self.paper)
  self.assertIn('&lt;script&gt; literal &amp; text<BR>next',result)
  self.assertIn('face="Times New Roman" color="#ffffff"><i>',result)
  self.assertNotIn('<script>',result)
  data=self.context('paper').project(self.actor);data['sections'][-1]['ink']='white" onload="bad'
  self.assertEqual(self.render(data,self.paper),'<b>Unable to read this document.</b>')
 def test_title_decodes_once_reencodes_and_preserves_literal_entities_and_markup(self):
  title=self.env['paper_document_view_title']
  for stored,expected,visible in [
   ('A &amp; B','A &amp; B','A & B'),
   ('A &amp;amp; B','A &amp;amp; B','A &amp; B'),
   ('&quot;A&quot; &#38; B','&quot;A&quot; &amp; B','"A" & B'),
   ('&lt;b&gt;literal&lt;/b&gt;','&lt;b&gt;literal&lt;/b&gt;','<b>literal</b>'),
   ('</TITLE><script>alert(1)</script>','&lt;/TITLE&gt;&lt;script&gt;alert(1)&lt;/script&gt;','</TITLE><script>alert(1)</script>'),
   ('&amp;lt;b&amp;gt;','&amp;lt;b&amp;gt;','&lt;b&gt;'),
   ('日記 &amp; café','日記 &amp; café','日記 & café')]:
   with self.subTest(stored=stored):
    self.paper.name=stored;encoded=title(self.paper.name)
    self.assertEqual(encoded,expected);self.assertEqual(html.unescape(encoded),visible)
    self.assertNotIn('<',encoded);self.assertNotIn('>',encoded)
    self.assertEqual(self.paper.name,stored)
  self.assertIn('paper_document_view_title(name)',SOURCE)
  self.assertIn('reader << browse(html, "window=[name]")',SOURCE)
  self.assertIn('onclose(reader, "[name]")',SOURCE)
 def test_crayon_signature_retains_combined_bold_italic_and_ink(self):
  legacy_signature='<font face="Times New Roman"><i>Old &amp; unchanged</i></font>'
  self.paper.info=legacy_signature;self.pen.kind='crayon';self.pen.signature='Crayon & <Literal Signature>'
  service=self.Base(self.paper,self.actor);self.assertTrue(service.initialize(self.actor,self.pen))
  record=self.paper.document_record
  self.assertTrue(service.append(self.actor,self.pen,record['document_id'],record['revision'],RU,'signature','ignored caller text'))
  data=self.context('paper').project(self.actor);result=self.render(data,self.paper)
  self.assertIn('<font face="Times New Roman" color="#ffffff"><b><i>Crayon &amp; &lt;Literal Signature&gt;</i></b></font>',result)
  self.assertTrue(result.startswith(legacy_signature));self.assertEqual(self.paper.info,legacy_signature)
  self.actor.languages=[self.langs[EN]];hidden=self.render(self.context('paper').project(self.actor),self.paper)
  self.assertNotIn('Crayon &amp;',hidden);self.assertIn('color="#ffffff"><b><i>[Unintelligible writing]</i></b>',hidden)
  old_parser=vm.body((ROOT/'code/game/objects/items/paper/paper.dm').read_text(),'/obj/item/weapon/paper/proc/parsepencode')
  self.assertIn('<i>[get_signature(P, user)]</i>',old_parser)
  self.assertIn('<b>[t]</b>',old_parser)
 def test_all_classic_payload_sites_delegate_including_editor_and_noticeboard(self):
  for name in ('code/game/objects/items/clipboard.dm','code/game/objects/items/paper/folder.dm','code/game/objects/structures/noticeboard.dm'):
   text=(ROOT/name).read_text();self.assertIn('P.show_document(',text)
   self.assertNotRegex(text,r'browse\([^\n]*(?:P\.info|P\.stamps)')
  text=(ROOT/'code/game/objects/items/paper/bundle.dm').read_text()
  self.assertIn('P.document_classic_html(user, FALSE, "bundle", src)',text)
  self.assertNotRegex(text,r'dat\+=.*(?:P\.info|P\.stamps)')
  text=(ROOT/'code/game/objects/items/paper/paper.dm').read_text()
  self.assertIn('return show_document(user, forceshow)',text)
  self.assertIn('show_document(user, FALSE, "editor")',text);self.assertIn('show_document(usr, FALSE, "editor")',text)
  self.assertNotRegex(text,r'browse\([^\n]*(?:info_links|\[info\]|\[stamps\])')
  self.assertIn('var/datum/paper_document_reader/request = new(src, reader, route, owner)',SOURCE)
  self.assertIn('if (!data)\n\t\treturn null',SOURCE)
  self.assertIn('background:#FFFFFF;color:#000000',SOURCE)
  self.assertIn('return (key in list("read_route", "read_owner")) || ..()',SOURCE)
 def test_projection_rejects_unreviewed_effect_boundaries(self):
  with self.assertRaises(AssertionError):environment(SOURCE.replace('return paper_document_route_access(', 'sleep(1)\n\treturn paper_document_route_access('))

if __name__=='__main__':unittest.main()
