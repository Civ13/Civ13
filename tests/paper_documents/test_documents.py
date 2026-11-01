"""Offline production-source projection and compatibility tests; not native DM."""
import copy,importlib.util,json,re,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('paper_document_projection',Path(__file__).with_name('projection.py'))
projection=importlib.util.module_from_spec(spec);spec.loader.exec_module(projection)
for name in ('ROOT','SOURCE','LANG','IDS','MAXIMUM','Actor','Pen','Paper','Ref','TypePath','body','environment','project'):
 globals()[name]=getattr(projection,name)
LEGACY=json.loads((Path(__file__).parent/'fixtures/legacy.json').read_text(encoding='utf-8'))
EN='civ13:english:v1';RU='civ13:russian:v1'

class Documents(unittest.TestCase):
 def setUp(self):
  self.env,self.Service,self.languages=environment();self.actor=Actor();self.actor.languages=[self.languages[EN]];self.pen=Pen(self.actor);self.paper=Paper(self.actor,LEGACY);self.service=self.Service(self.paper,self.actor)
 def initialize(self):
  self.assertTrue(self.service.initialize(self.actor,self.pen));return self.paper.document_record
 def append(self,language=EN,kind='body',text='PRIVATE_CANARY',**changes):
  record=self.paper.document_record
  args=dict(actor=self.actor,pen=self.pen,document_id=record['document_id'],revision=record['revision'],language_id=language,kind=kind,value=text);args.update(changes)
  return self.service.append(**args)
 def test_legacy_import_is_opaque_and_preserves_original_fields(self):
  before=copy.deepcopy(self.paper.__dict__);record=self.initialize()
  self.assertEqual(record['legacy'],{k:v for k,v in LEGACY.items() if k!='info_links'});self.assertEqual(record['legacy_policy'],'legacy_unclassified');self.assertEqual(record['sections'],[])
  for key in LEGACY:self.assertEqual(getattr(self.paper,key),before[key])
  self.assertNotIn('language_id',record['legacy']);self.assertNotIn('author',record)
  self.assertFalse(self.service.initialize(self.actor,self.pen))
 def test_explicit_language_ids_are_type_mapped_and_unknown_ids_close(self):
  self.assertEqual(len(IDS),60)
  for value in [None,1,True,[],{},'English',':e','[0x123]','civ13:unknown:v1']:
   self.assertIsNone(self.env['paper_written_language'](value))
  self.assertIs(self.env['paper_written_language'](EN),self.languages[EN])
  self.assertFalse(any(x in IDS.values() for x in ['/datum/language/ant','/datum/language/ape','/datum/language/droid','/datum/language/blackspeech']))
 def test_registry_ids_match_real_definitions_and_reject_speech_only_flags(self):
  source=(ROOT/'code/game/mob/language/earth.dm').read_text(encoding='utf-8')
  for id,path in IDS.items():
   section=re.search('^'+re.escape(path)+r'\n(.*?)(?=^/datum/language|\Z)',source,re.M|re.S)[1]
   self.assertRegex(section,r'flags\s*=\s*RESTRICTED\s*\|\s*COMMON_VERBS')
  for flag in (4,8,16,64):
   self.languages[EN].flags=flag;self.assertIsNone(self.env['paper_written_language'](EN))
 def test_mute_keeps_knowledge_universal_and_dead_do_not_grant_membership(self):
  self.actor.muted=True;self.assertTrue(self.env['paper_knows_written_language'](self.actor,EN))
  self.actor.universal_speak=True;self.actor.stat=2
  self.assertFalse(self.env['paper_knows_written_language'](self.actor,RU))
  self.actor.kind='ghost';self.assertFalse(self.env['paper_knows_written_language'](self.actor,RU))
 def test_new_typing_is_language_tagged_and_signature_comes_from_actual_pen(self):
  self.initialize();self.assertTrue(self.append());self.assertTrue(self.append(kind='signature',text='CLIENT_FORGED_VALUE'))
  sections=self.paper.document_record['sections'];self.assertEqual(sections[0]['language_id'],EN);self.assertEqual(sections[0]['text'],'PRIVATE_CANARY')
  self.assertEqual(sections[1]['text'],'Forged fixture');self.assertEqual(sections[1]['ink'],'#ffffff')
  self.assertNotEqual(sections[0]['lineage'],sections[1]['lineage']);self.assertEqual(sections[0]['version'],1)
 def test_default_changes_do_not_rewrite_sections_or_create_knowledge(self):
  self.actor.default_language=self.languages[RU]
  self.assertIsNone(self.env['paper_written_default_language'](self.actor))
  self.initialize();self.assertTrue(self.append());self.actor.languages.append(self.languages[RU])
  self.assertEqual(self.env['paper_written_default_language'](self.actor),RU)
  self.assertEqual(self.paper.document_record['sections'][0]['language_id'],EN)
  self.assertEqual({r['id'] for r in self.env['paper_written_language_choices'](self.actor)},{EN,RU})
 def test_language_knowledge_rebinds_to_actual_member_after_identity_roundtrip(self):
  clone=copy.copy(self.languages[EN]);self.assertIsNot(clone,self.languages[EN]);self.actor.languages=[clone]
  self.assertTrue(self.env['paper_knows_written_language'](self.actor,EN))
  self.initialize();self.assertTrue(self.append())
 def test_every_text_kind_is_projected_without_unknown_originals(self):
  record=self.initialize()
  for index,kind in enumerate(['body','title','field_label','field_answer','signature']):
   record['sections'].append(dict(id=str(index),lineage=str(index)*32,version=1,kind=kind,language_id=RU,text='PRIVATE_CANARY_'+kind,ink='#ffffff',tool='pen'))
  visible=self.service.project(self.actor);encoded=json.dumps(visible)
  self.assertNotIn('PRIVATE_CANARY',encoded);self.assertEqual(len(visible['sections']),5)
  self.assertTrue(all(s['text']=='[Unintelligible writing]' for s in visible['sections']))
  self.assertTrue(all(s['ink']=='#ffffff' for s in visible['sections']))
  self.assertEqual(visible,self.service.project(self.actor))
  self.actor.languages.append(self.languages[RU]);self.assertIn('PRIVATE_CANARY',json.dumps(self.service.project(self.actor)))
  self.actor.languages.remove(self.languages[RU]);self.assertNotIn('PRIVATE_CANARY',json.dumps(self.service.project(self.actor)))
 def test_stale_revision_document_and_legacy_drift_reject_without_changes(self):
  record=self.initialize();docid=record['document_id'];rev=record['revision'];self.assertTrue(self.append(text='First'))
  before=copy.deepcopy(self.paper.document_record);space=self.paper.free_space
  self.assertFalse(self.append(revision=rev));self.assertFalse(self.append(document_id='wrong'))
  self.paper.info+=' legacy edit';self.assertFalse(self.append())
  self.assertEqual(self.paper.document_record,before);self.assertEqual(self.paper.free_space,space)
  self.assertEqual(self.service.project(self.actor),dict(error='Legacy document changed'))
  self.assertIsNone(self.service.canonical_copy(self.actor))
 def test_runtime_href_cache_is_not_canonical_content_or_a_rebase(self):
  self.initialize();self.paper.info_links='runtime hrefs regenerated for a different native reference'
  self.assertTrue(self.append());self.assertNotIn('info_links',self.service.canonical_copy(self.actor)['legacy'])
  self.assertNotIn('runtime hrefs',json.dumps(self.service.project(self.actor)))
 def test_legacy_read_body_interpolates_authorized_snapshot_and_stamps(self):
  self.initialize();self.assertEqual(self.service.project(self.actor)['legacy_body_html'],LEGACY['info']+LEGACY['stamps'])
  self.actor.kind='ghost';self.assertEqual(self.service.project(self.actor)['legacy_body_html'],LEGACY['info']+LEGACY['stamps'])
  # stars is an inert engine seam here, not a native RNG/comprehension proof.
  self.assertEqual(self.service.project(self.actor,True)['legacy_body_html'],'*'*len(LEGACY['info'])+LEGACY['stamps'])
 def test_known_language_keeps_nonhuman_and_forced_ghost_literacy_restrictions(self):
  self.initialize();self.assertTrue(self.append(text='KNOWN_LANGUAGE_PRIVATE_CANARY'))
  self.assertTrue(self.env['paper_knows_written_language'](self.actor,EN))
  self.actor.kind='animal'
  self.assertTrue(self.service.has_access(self.actor))
  self.assertEqual(self.service.project(self.actor)['sections'][0]['text'],'[Unintelligible writing]')
  self.assertNotIn('KNOWN_LANGUAGE_PRIVATE_CANARY',json.dumps(self.service.project(self.actor)))
  self.actor.kind='ghost'
  self.assertEqual(self.service.project(self.actor)['sections'][0]['text'],'KNOWN_LANGUAGE_PRIVATE_CANARY')
  self.assertEqual(self.service.project(self.actor,True)['sections'][0]['text'],'[Unintelligible writing]')
  self.assertNotIn('KNOWN_LANGUAGE_PRIVATE_CANARY',json.dumps(self.service.project(self.actor,True)))
 def test_last_guard_rechecks_state_after_signature_callback(self):
  for change in ('language','pen','legacy'):
   with self.subTest(change=change):
    self.setUp();record=self.initialize();before=copy.deepcopy(record);space=self.paper.free_space
    def signature(actor):
     if change=='language':actor.languages=[]
     elif change=='pen':actor.active=None
     else:self.paper.info+=' external edit'
     return 'Callback fixture'
    self.pen.get_signature=signature
    self.assertFalse(self.append(kind='signature'))
    self.assertEqual(self.paper.document_record,before);self.assertEqual(self.paper.free_space,space)
 def test_actor_pen_language_capacity_and_field_mutation_guards(self):
  self.initialize();before=copy.deepcopy(self.paper.document_record)
  for change in [dict(language=RU),dict(kind='field_answer'),dict(text='x'*3073)]:self.assertFalse(self.append(**change))
  self.actor.stat=1;self.assertFalse(self.append());self.actor.stat=0
  self.actor.bound=True;self.assertFalse(self.append());self.actor.bound=False
  self.actor.active=None;self.assertFalse(self.append());self.actor.active=self.pen
  self.pen.loc=object();self.assertFalse(self.append());self.pen.loc=self.actor
  self.assertEqual(before,self.paper.document_record)
 def test_logout_transfer_deleted_item_and_closed_container_reject(self):
  self.initialize();other=Actor();self.actor.client.mob=other;self.assertFalse(self.append());self.assertIsNone(self.service.project(self.actor));self.actor.client.mob=self.actor
  self.paper.gc_destroyed=True;self.assertFalse(self.append());self.paper.gc_destroyed=False
  holder=Ref();holder.kind='envelope';holder.loc=self.actor;holder.opened=False;holder.gc_destroyed=False;self.paper.loc=holder
  self.assertFalse(self.append());self.assertIsNone(self.service.project(self.actor))
  holder.kind='folder';self.assertIsNotNone(self.service.project(self.actor));holder.loc=other;self.assertIsNone(self.service.project(self.actor))
  holder.loc=self.actor;holder.gc_destroyed=True;self.assertIsNone(self.service.project(self.actor))
 def test_reconnected_client_cannot_reuse_old_request_context(self):
  self.initialize();old_client=self.actor.client;self.actor.client=Ref();self.actor.client.mob=self.actor
  self.assertFalse(self.append());self.assertIsNone(self.service.project(self.actor));self.assertIsNone(self.service.canonical_copy(self.actor))
  self.actor.client=old_client;self.assertIsNotNone(self.service.canonical_copy(self.actor))
 def test_malformed_records_fail_closed_without_repair_or_prefix(self):
  record=self.initialize()
  for mutate in [lambda r:r.update(schema_version=2),lambda r:r.update(unknown='x'),lambda r:r.update(sections=['not a section']),lambda r:r.update(legacy_policy='english')]:
   bad=copy.deepcopy(record);mutate(bad);self.paper.document_record=bad
   self.assertEqual(self.service.project(self.actor),dict(error='Unsupported document format'))
   self.assertEqual(self.paper.document_record,bad)
  self.paper.document_record=record;self.assertTrue(self.append());bad=copy.deepcopy(self.paper.document_record);bad['sections'][0]['language_id']='unknown';self.paper.document_record=bad
  self.assertNotIn('PRIVATE_CANARY',json.dumps(self.service.project(self.actor)))
 def test_bounded_deep_copy_keeps_bytes_types_and_does_not_alias(self):
  budget=self.env['new_budget']();source=dict(text=LEGACY['info'],paths=[TypePath('/obj/item/weapon/stamp')],nested=[dict(x='日本語 🚢')])
  result=self.env['paper_document_copy'](source,budget);self.assertTrue(budget.valid);self.assertEqual(source,result)
  result['nested'][0]['x']='changed';self.assertEqual(source['nested'][0]['x'],'日本語 🚢');self.assertIsInstance(result['paths'][0],TypePath)
  for invalid in [Ref(),'x'*131073]:
   budget=self.env['new_budget']();self.assertIsNone(self.env['paper_document_copy'](invalid,budget));self.assertFalse(budget.valid)
  cyclic=[];cyclic.append(cyclic);budget=self.env['new_budget']();self.assertIsNone(self.env['paper_document_copy'](cyclic,budget));self.assertFalse(budget.valid)
 def test_canonical_copy_retains_language_lineage_and_has_no_character_progress(self):
  self.initialize();self.assertTrue(self.append());canonical=self.service.canonical_copy(self.actor);visible=self.service.project(Actor())
  self.assertIsNone(visible);self.assertEqual(canonical,self.paper.document_record);self.assertIsNot(canonical,self.paper.document_record)
  self.assertNotIn('study',canonical);self.assertNotIn('ckey',json.dumps(canonical))
  for _ in range(5):canonical=json.loads(json.dumps(canonical,ensure_ascii=False));self.assertTrue(self.env['paper_document_record_valid'](canonical))
  self.assertEqual(canonical['sections'][0]['lineage'],self.paper.document_record['sections'][0]['lineage'])
 def test_character_and_utf8_length_adapters_do_not_change_stored_unicode(self):
  for bytes_mode in (False,True):
   env,Service,langs=environment(bytes_mode);actor=Actor();actor.languages=[langs[EN]];pen=Pen(actor);paper=Paper(actor,LEGACY);service=Service(paper,actor)
   self.assertTrue(service.initialize(actor,pen));r=paper.document_record
   self.assertTrue(service.append(actor,pen,r['document_id'],r['revision'],EN,'body','日本語 🚢'))
   self.assertEqual(paper.document_record['sections'][0]['text'],'日本語 🚢')
 def test_runtime_service_never_persists_and_old_writer_is_unmodified(self):
  self.assertIn('should_save = FALSE',SOURCE.split('/datum/paper_document_service',1)[1])
  self.assertIn('return (key in list("paper", "controller", "control_client")) || ..()',SOURCE)
  self.assertIn('var/list/document_record = null',SOURCE)
  saving=(ROOT/'code/modules/persistence/functions.dm').read_text()
  self.assertIn('src.vars[key] != initial(src.vars[key])',saving)
  self.assertNotIn('/obj/item/weapon/paper/get_saved_vars',SOURCE)
  for forbidden in ['hear_say(','.scramble(','partial_languages','add_language(','do_after(','Topic(','browse(','receiveUpdateData','sleep(']:self.assertNotIn(forbidden,SOURCE)
  includes=(ROOT/'civ13.dme').read_text();self.assertIn('paperwork\\document.dm',includes)
 def test_projection_rejects_unknown_effect_boundary(self):
  bad=SOURCE.replace('return has_access(actor, TRUE)','sleep(1)\n\treturn has_access(actor, TRUE)')
  with self.assertRaises(AssertionError):project(bad,'/datum/paper_document_service/proc/can_mutate','self,actor,pen',self.env,True)

if __name__=='__main__':unittest.main()
