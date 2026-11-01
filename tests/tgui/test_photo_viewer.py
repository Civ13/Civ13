"""Photo producer/state contracts; no DM/client/native execution."""
from pathlib import Path
import re,unittest
ROOT=Path(__file__).resolve().parents[2]
DM=(ROOT/'code/game/objects/items/paper/photography.dm').read_text()
SHOW=DM.split('/obj/item/weapon/photo/proc/show(',1)[1].split('/datum/nanoui/tgui/photo_viewer/update',1)[0]
STATE=DM.split('/datum/topic_state/photo_viewer/can_use_topic',1)[1].split('/obj/item/weapon/photo/verb/rename()',1)[0]
UPDATE=DM.split('/datum/nanoui/tgui/photo_viewer/update',1)[1].split('/datum/topic_state/photo_viewer\n',1)[0]

class PhotoViewerContract(unittest.TestCase):
 def test_entrypoint_permissions_and_image_capture_handlers_are_not_replaced(self):
  examine=DM.split('/obj/item/weapon/photo/examine(',1)[1].split('/obj/item/weapon/photo/proc/show(',1)[0]
  for marker in ('if(!img)','if(distance <= 1)','show(user)','to_chat(user, desc)','It is too far away.'):
   self.assertIn(marker,examine)
  for path in ('code/game/objects/items/paper/folder.dm','code/game/objects/items/clipboard.dm'):
   text=(ROOT/path).read_text();self.assertIn('P.show(usr)',text);self.assertIn('P.loc == src',text)
  attack=DM.split('/obj/item/weapon/photo/attackby(',1)[1].split('/obj/item/weapon/photo/examine(',1)[0]
  self.assertIn('sanitize(input(user,',attack);self.assertIn('as text, 128)',attack)
  self.assertIn('if(loc == user && user.stat == 0)',attack)
  self.assertNotRegex(SHOW,r'generate_image|captureimage|createpicture|put_in|set_using_object|\bnew\s+/obj')

 def test_snapshot_has_only_existing_image_and_canonical_inert_text(self):
  self.assertIn('if (!user || !user.client)',SHOW)
  send='send_rsc(user, img, "tmp_photo_[id].png")'
  self.assertIn(send,SHOW);self.assertLess(SHOW.index(send),SHOW.index('var/list/data'))
  data=SHOW.split('var/list/data = list(',1)[1].split('\n',1)[0]
  self.assertEqual(re.findall(r'"(\w+)" =',data),['name','image','width','scribble'])
  self.assertIn('html_encode(html_decode("[name]"))',data)
  self.assertIn('html_encode(html_decode("[scribble]"))',data)
  self.assertNotRegex(SHOW,r'\n\t(?:name|scribble|photo_size|id|img)\s*=')
  self.assertIn('max(64, min(448, 64 * photo_size))',SHOW)
  self.assertIn('isnum(photo_size)',SHOW)

 def test_owner_projection_retains_admitted_readers_and_rejects_other_mobs_items_and_logout(self):
  match=re.search(r'if \((.+)\)\n\t\treturn STATUS_CLOSE',STATE);self.assertIsNotNone(match)
  expression=match.group(1).replace('!user.client','not connected').replace('!user','not user').replace('!photo','not photo').replace('||','or')
  def permits(reader,user,photo,src_object,connected=True):
   return not eval(expression,{'__builtins__':{}},dict(reader=reader,user=user,photo=photo,src_object=src_object,connected=connected))
  owner=object();photo=object()
  for label in ('human','observer','dead','incapacitated'):
   self.assertTrue(permits(owner,owner,photo,photo),label)
  self.assertFalse(permits(owner,object(),photo,photo));self.assertFalse(permits(owner,owner,photo,object()))
  self.assertFalse(permits(owner,owner,photo,photo,False));self.assertFalse(permits(owner,None,photo,photo))
  self.assertFalse(permits(owner,owner,None,None))
  self.assertIn('return STATUS_UPDATE',STATE)
  self.assertNotRegex(STATE,r'Adjacent|in_range|ishuman|isliving|shared_nano_interaction|STATUS_INTERACTIVE')

 def test_stale_state_is_replaced_and_close_cannot_clear_another_machine(self):
  for marker in ('GLOB.nanomanager.get_open_ui(user, src, ui_key)','!istype(ui)','!istype(old_state)','old_state.photo != src','old_state.reader != user','ui.close()','ui = null','new(src, user)'):
   self.assertIn(marker,SHOW)
  self.assertIn('ui.use_on_close_logic(FALSE)',SHOW)
  self.assertLess(SHOW.index('ui.use_on_close_logic(FALSE)'),SHOW.index('ui.open()'))
  self.assertIn('ui.set_initial_data(data)',SHOW)
  self.assertNotRegex(SHOW+UPDATE,r'set_using_object|unset_using_object|set_auto_update|spawn\(')

 def test_manager_refresh_is_status_only_and_neither_protocol_admits_domain_actions(self):
  self.assertIn('push_data(null, TRUE)',UPDATE)
  self.assertNotRegex(UPDATE,r'\.show\(|send_rsc|generate_image|captureimage|initial_data')
  transport=(ROOT/'code/modules/nano/tgui.dm').read_text()
  self.assertNotIn('photo_viewer',transport)
  component=(ROOT/'tgui/src/interfaces/PhotoViewer.tsx').read_text()
  self.assertNotRegex(component,r'\.act\(|dangerouslySetInnerHTML|innerHTML|\bonClick\b|\bonChange\b')
  classic=(ROOT/'UI/templates/photo_viewer.tmpl').read_text()
  self.assertNotRegex(classic,r'\bhref\s*=|\bonclick\s*=|<input|<button|<script')
  self.assertIn('tmp_photo_[0-9]+',classic);self.assertIn('tmp_photo_[0-9]+',component)

 def test_previous_photo_replacement_is_scoped_to_this_owner_and_subtype(self):
  self.assertIn('if (islist(user.open_uis))',SHOW)
  self.assertIn('for (var/datum/nanoui/tgui/photo_viewer/old_ui in user.open_uis.Copy())',SHOW)
  marker='istype(old_ui) && old_ui.user == user && old_ui.src_object != src'
  self.assertIn(marker,SHOW)
  self.assertIn('old_ui.close()',SHOW)
  # Projection uses the exact source condition; type identity is its one seam.
  expression=marker.replace('istype(old_ui)','is_photo').replace('old_ui.user','old_owner').replace('old_ui.src_object','old_source').replace('&&','and')
  user=object();src=object();other_photo=object()
  def closes(is_photo,old_owner,old_source):
   return eval(expression,{'__builtins__':{}},dict(is_photo=is_photo,old_owner=old_owner,old_source=old_source,user=user,src=src))
  self.assertTrue(closes(True,user,other_photo))
  self.assertFalse(closes(True,user,src));self.assertFalse(closes(True,object(),other_photo))
  self.assertFalse(closes(False,user,other_photo))

 def test_source_dependencies_and_registration_reuse_the_existing_adapter(self):
  self.assertIn('new /datum/nanoui/tgui/photo_viewer(user, src, ui_key, "photo_viewer.tmpl"',SHOW)
  workflow=(ROOT/'.github/workflows/tgui.yml').read_text()
  self.assertIn("'code/game/objects/items/paper/photography.dm'",workflow)
  self.assertIn("'photo_viewer.tmpl': PhotoViewer",(ROOT/'tgui/src/interfaces/index.tsx').read_text())

if __name__=='__main__':unittest.main()
