"""Static flavor reader source/lease contracts; no native DM acceptance."""
from pathlib import Path
import re,unittest
from types import SimpleNamespace as Obj
ROOT=Path(__file__).resolve().parents[2]
SOURCE=(ROOT/'code/game/mob/flavor_reader.dm').read_text(encoding='utf-8')
MOB=(ROOT/'code/game/mob/mob.dm').read_text(encoding='utf-8')
def proc(source,signature):
 match=re.search('^'+re.escape(signature)+r'\n((?:\t[^\n]*\n|\n)*)',source,re.M)
 assert match,'Missing proc '+signature
 return match[1]
class CharacterFlavorContract(unittest.TestCase):
 def test_exact_original_topic_and_visibility_gate_are_preserved(self):
  original=(ROOT/'tests/tgui/fixtures/flavor-legacy-topic.dm.txt').read_text(encoding='utf-8').rstrip('\n')
  current='/mob/Topic(href, href_list)\n'+proc(MOB,'/mob/Topic(href, href_list)')
  start=current.index('\t\t\tvar/legacy_snapshot = ');end=current.index('\n',current.index('\t\t\t\tonclose(usr, window_name)',start))
  old='\t\t\tusr << browse(text("<HTML><HEAD><TITLE>[]</TITLE></HEAD><BODY><TT>[]</TT></BODY></HTML>", name, replacetext(flavor_text, "\\n", "<BR>")), "window=[window_name];size=500x200")\n\t\t\tonclose(usr, window_name)'
  self.assertEqual((current[:start]+old+current[end:]).rstrip('\n'),original)
  self.assertLess(current.index('if (src in view(usr))'),current.index('var/legacy_snapshot'))
  self.assertIn('!hascall(src, "present_character_flavor_ui") || !call(src, "present_character_flavor_ui")(usr, legacy_snapshot)',current)
 def test_editor_cancel_and_preview_face_filter_are_not_reimplemented(self):
  editor=proc(MOB,'/mob/proc/update_flavor_text()')
  self.assertIn('sanitize(input(usr,',editor);self.assertIn('extra = FALSE)',editor)
  self.assertIn('if (msg != null)\n\t\tflavor_text = msg',editor)
  self.assertNotIn('flavor_change',SOURCE);self.assertNotIn('flavor_text =',SOURCE)
  human=(ROOT/'code/game/mob/living/carbon/human/human.dm').read_text(encoding='utf-8')
  self.assertIn('if (C.body_parts_covered & FACE)',proc(human,'/mob/living/human/print_flavor_text(var/shrink = TRUE)'))
 def test_admission_precedes_capture_and_canonical_budget_fallback_is_complete(self):
  opened=proc(SOURCE,'/mob/proc/present_character_flavor_ui(mob/viewer, legacy_snapshot)')
  for marker in ('!viewer || !viewer.client || !(src in view(viewer))','length(flavor_text) + length(encoded_name) <= 65536','html_encode(html_decode(flavor_text)) == flavor_text','lines.len > 2048','ui.legacy_snapshot = legacy_snapshot','if (!modern)','ui.legacy_renderer = TRUE','ui.set_initial_data(list())','"name" = encoded_name, "text" = flavor_text'):
   self.assertIn(marker,opened)
  self.assertLess(opened.index('!viewer.client'),opened.index('html_encode('))
  self.assertLess(opened.index('ui.legacy_snapshot = legacy_snapshot'),opened.index('ui.open()'))
  self.assertNotRegex(opened,r'copytext\(|strip_html|set_auto_update|spawn\(')
 def test_exact_reader_target_lease_allows_ghost_dead_and_disconnected_subject(self):
  state=proc(SOURCE,'/datum/topic_state/character_flavor/can_use_topic(var/src_object, var/mob/user)')
  guard=re.search(r'if \((.+)\)\n\t\treturn STATUS_CLOSE',state);self.assertIsNotNone(guard)
  expression=guard[1].replace('!user.client','not user.client').replace('!subject','not subject').replace('!user','not user').replace('||','or').replace(' != ',' is not ')
  def allowed(subject,source,user,reader):return not eval(expression,{'__builtins__':{}},dict(subject=subject,src_object=source,user=user,reader=reader))
  target=Obj(client=None);reader=Obj(client=True,stat=2);other=Obj(client=True,stat=2)
  self.assertTrue(allowed(target,target,reader,reader))
  self.assertFalse(allowed(target,target,other,reader));self.assertFalse(allowed(target,other,reader,reader))
  reader.client=None;self.assertFalse(allowed(target,target,reader,reader))
  # Real transfer order: a new mob before and after client linkage cannot use
  # the old reader lease. Explicit More is required to make its own new lease.
  new_body=Obj(client=None);self.assertFalse(allowed(target,target,new_body,reader))
  new_body.client=True;self.assertFalse(allowed(target,target,new_body,reader));self.assertTrue(allowed(target,target,new_body,new_body))
  self.assertIn('return STATUS_UPDATE',state);self.assertNotIn('view(',state);self.assertNotIn('stat',state.split('\n',1)[1].split('//')[0])
 def test_cached_html_owner_guard_no_polling_domain_actions_or_close_side_effect(self):
  html=proc(SOURCE,'/datum/nanoui/tgui/character_flavor/get_html()')
  self.assertIn('reader_state.can_use_topic(src_object, user) == STATUS_CLOSE',html)
  self.assertLess(html.index('can_use_topic'),html.index('return legacy_snapshot'))
  update=proc(SOURCE,'/datum/nanoui/tgui/character_flavor/update(var/force_open = FALSE)')
  self.assertNotIn('flavor_text',update);self.assertNotIn('present_character_flavor_ui',update)
  for marker in ('ui.use_on_close_logic(FALSE)','if (reader_closed)\n\t\treturn','reader_closed = TRUE','legacy_snapshot = null','return ..()'):self.assertIn(marker,SOURCE)
  self.assertNotRegex(SOURCE,r'using_object|set_auto_update|spawn\(|/Topic\(')
  self.assertNotIn('character_flavor.tmpl',(ROOT/'code/modules/nano/tgui.dm').read_text())
  self.assertIn('code/game/mob/flavor_reader.dm',(ROOT/'.github/workflows/tgui.yml').read_text())
if __name__=='__main__':unittest.main()
