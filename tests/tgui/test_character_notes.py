"""Notes parser/lease source projections. No native DM or client acceptance."""
from pathlib import Path
import copy, importlib.util, json, re, unittest
from types import SimpleNamespace as Obj
from notes_projection import SOURCE,ROOT,Budget,body,parser,view

class NotesParser(unittest.TestCase):
 def test_exact_native_budget_declarations(self):
  budget=Budget();self.assertEqual((budget.units_left,budget.nodes_left,budget.max_depth),(65536,2048,32))
 def test_balanced_styles_breaks_empty_and_once_encoded_text(self):
  for bytes_mode in (False,True):
   parse=parser(bytes_mode=bytes_mode)
   self.assertEqual(parse('',Budget()),[])
   self.assertEqual(parse('<B>bold <i>both</i></B><br />次 😀 &amp;lt;b&amp;gt;',Budget()),[
    dict(text='bold ',bold=True,italic=False),dict(text='both',bold=True,italic=True),dict(br=True),dict(text='次 😀 &amp;lt;b&amp;gt;',bold=False,italic=False)])
   self.assertIsNotNone(parse('x & y &amp; &#128512; &LT;ok&GT;',Budget()))
 def test_mixed_malformed_unsupported_entities_and_controls_fallback_whole(self):
  bad=['okay <b>broken','<b><i>x</b></i>','<b>x</b></b>','<span>x</span>','<b onclick=x>x</b>','< b>x</b>','<script>x</script>','<img src=x>','<','a &unknown;','&amp','&AmP;','&#x41;','&#0;','&#55296;','&#1114112;','&#128;','x\x00y','x\x1fy','x\x7fy']
  for bytes_mode in (False,True):
   parse=parser(bytes_mode=bytes_mode)
   for text in bad:
    with self.subTest(text=repr(text),bytes_mode=bytes_mode):self.assertIsNone(parse(text,Budget()))
 def test_depth_node_and_full_unicode_boundaries_never_truncate(self):
  for bytes_mode in (False,True):
   parse=parser(bytes_mode=bytes_mode)
   self.assertIsNotNone(parse('<b>'*32+'x'+'</b>'*32,Budget()))
   self.assertIsNone(parse('<b>'*33+'x'+'</b>'*33,Budget()))
   self.assertEqual(len(parse('<br>'*2048,Budget())),2048)
   self.assertIsNone(parse('<br>'*2049,Budget()))
   unit=4 if bytes_mode else 1;text='😀'*(65536//unit)
   self.assertEqual(parse(text,Budget())[0]['text'],text)
   self.assertIsNone(parse(text+'😀',Budget()))
 def test_aggregate_budget_empty_records_and_no_source_mutation(self):
  mind=dict(character='Reader',notes={'Job':['<b>role</b>','private memory']},memory='Stored<BR>')
  before=copy.deepcopy(mind);data=view(mind,'<br><b>Discoveries</b><br>known')
  self.assertEqual(len(data['sections'][0]['entries']),2);self.assertEqual(mind,before)
  mind['notes']['Job'].append('late <span>unsupported</span>')
  self.assertIsNone(view(mind,'known'))
  self.assertIsNone(view(dict(character='',notes={'':['']*2048},memory=''),''))
  self.assertIsNone(view(dict(character='x'*32768,notes={},memory='y'*32768),'z'))
 def test_existing_discovery_filter_is_only_input_no_hidden_identifiers(self):
  spec=importlib.util.spec_from_file_location('notes_discovery_contract',ROOT/'tests/character_discoveries/test_discoveries.py')
  module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
  records={};module.learn(records,'berry_smell','HIDDEN_ID','OLD_CONTEXT','Old berry','HIDDEN_OBSERVATION')
  module.learn(records,'berry_smell','SECOND_ID','current','Known berry','Public smell')
  records['learned_discoveries']['invalid']=dict(category='berry_smell',identity='BAD',context='current',label='Hidden malformed',observation='x'*257)
  before=copy.deepcopy(records);snapshot=module.render(records,'current')
  data=view(dict(character='Ghost',notes={},memory='private'),snapshot)
  serialized=json.dumps(data)
  self.assertIn('Public smell',serialized)
  self.assertIn('HIDDEN_OBSERVATION',serialized) # Existing historical observation remains visible, with warning.
  self.assertIn('Historical observation',serialized)
  for secret in ('HIDDEN_ID','OLD_CONTEXT','SECOND_ID','berry_smell','Hidden malformed'):self.assertNotIn(secret,serialized)
  self.assertEqual(records,before)

def admitted(mind,reader,source,user):
 guard=re.search(r'if \((.+)\)\n\t\treturn STATUS_CLOSE',body(SOURCE,'/datum/topic_state/character_notes/can_use_topic(var/src_object, var/mob/user)'))
 assert guard,'Missing owner guard'
 expression=guard[1].replace('!user.client','not user.client').replace('!mind','not mind').replace('!user','not user').replace('||','or').replace(' != ',' is not ')
 return not eval(expression,{'__builtins__':{}},dict(mind=mind,reader=reader,src_object=source,user=user))

class NotesOwnership(unittest.TestCase):
 def test_owner_wrong_source_logout_ghost_and_real_transfer_order(self):
  mind=object();owner=Obj(client=True,mind=mind);ghost=Obj(client=True,mind=mind)
  self.assertTrue(admitted(mind,owner,mind,owner));self.assertTrue(admitted(mind,ghost,mind,ghost))
  self.assertFalse(admitted(mind,owner,mind,ghost));self.assertFalse(admitted(mind,owner,object(),owner))
  owner.client=False;self.assertFalse(admitted(mind,owner,mind,owner))
  # Manager moves user before key/client linkage. Old reader lease never grants
  # new body access, even after linkage; normal explicit Notes reopen is needed.
  new_body=Obj(client=None,mind=mind)
  self.assertFalse(admitted(mind,owner,mind,new_body));new_body.client=True
  self.assertFalse(admitted(mind,owner,mind,new_body));self.assertTrue(admitted(mind,new_body,mind,new_body))
  new_body.mind=object();self.assertFalse(admitted(mind,new_body,mind,new_body))
 def test_complete_cached_snapshot_guarded_fallback_and_close_noninterference(self):
  presentation=body(SOURCE,'/datum/mind/proc/present_character_notes_ui(mob/user, legacy_snapshot, discovery_snapshot)')
  for marker in ('if (!user || !user.client || user.mind != src)','ui.legacy_snapshot = legacy_snapshot','if (isnull(data))','ui.legacy_renderer = TRUE','ui.use_on_close_logic(FALSE)'):
   self.assertIn(marker,presentation)
  self.assertLess(presentation.index('!user.client'),presentation.index('character_notes_ui_data('))
  self.assertLess(presentation.index('ui.legacy_snapshot = legacy_snapshot'),presentation.index('ui.open()'))
  html=body(SOURCE,'/datum/nanoui/tgui/character_notes/get_html()')
  self.assertIn('reader_state.can_use_topic(src_object, user) == STATUS_CLOSE',html)
  self.assertLess(html.index('can_use_topic'),html.index('return legacy_snapshot'))
  self.assertNotIn('character_notes_ui_data',html);self.assertNotIn('discoveries_html',SOURCE)
  close=body(SOURCE,'/datum/nanoui/tgui/character_notes/close()')
  self.assertEqual([x.strip() for x in close.splitlines() if x.strip()],['if (reader_closed)','return','reader_closed = TRUE','legacy_snapshot = null','return ..()'])
  self.assertNotIn('set_using_object',SOURCE);self.assertNotIn('unset_using_object',SOURCE)
  # Source-projected close idempotence: cancel clears cache once; a delayed old
  # close cannot send a second browse(null) after a new reader is opened.
  instructions={'if (reader_closed)':'if state["closed"]:','return':'return','reader_closed = TRUE':'state["closed"] = True','legacy_snapshot = null':'state["snapshot"] = None','return ..()':'state["parent_closes"] += 1'}
  from notes_projection import project
  f=project(SOURCE,'/datum/nanoui/tgui/character_notes/close()','state',instructions,{})
  old=dict(closed=False,snapshot='FULL_PRIVATE_SNAPSHOT',parent_closes=0);f(old)
  new=dict(closed=False,snapshot='REFRESHED_PRIVATE_SNAPSHOT',parent_closes=0);f(old)
  self.assertEqual(old,dict(closed=True,snapshot=None,parent_closes=1));self.assertEqual(new['snapshot'],'REFRESHED_PRIVATE_SNAPSHOT')
 def test_classic_builder_exact_preimage_and_fixed_hook(self):
  mind=(ROOT/'code/datums/mind.dm').read_text()
  current='/datum/mind/proc/show_memory(mob/recipient)\n'+body(mind,'/datum/mind/proc/show_memory(mob/recipient)')
  current=current.replace('\tvar/discovery_snapshot = discoveries_html()\n\toutput += discovery_snapshot','\toutput += discoveries_html()')
  old_tail='\trecipient << browse(replacetext(memory_stylized, "PLACEHOLDER", output),"window=memory;size=625x650")'
  start=current.index('\tvar/legacy_snapshot = ');end=current.index('\n',current.index('\trecipient << browse(legacy_snapshot',start))
  current=current[:start]+old_tail+current[end:]
  # The fixture excludes only blank lines separating top-level procs.
  self.assertEqual(current.rstrip('\n'),(ROOT/'tests/tgui/fixtures/notes-legacy-proc.dm.txt').read_text().rstrip('\n'))
  self.assertIn('hascall(src, "present_character_notes_ui") && call(src, "present_character_notes_ui")(recipient, legacy_snapshot, discovery_snapshot)',mind)
  transport=(ROOT/'code/modules/nano/tgui.dm').read_text();self.assertNotIn('character_notes.tmpl',transport)
  self.assertNotRegex(SOURCE,r'learned_discoveries\s*=|notes\[.*\]\s*=|memory\s*=|world <<|Topic\(')

if __name__=='__main__':unittest.main()
