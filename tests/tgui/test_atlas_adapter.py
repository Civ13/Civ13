"""Atlas adapter contracts/projections only; no DM/client/native execution."""
from pathlib import Path
import hashlib,json,re,unittest
ROOT=Path(__file__).resolve().parents[2]
CORE=(ROOT/'code/game/mob/crafting_atlas.dm').read_text()
ADAPTER=(ROOT/'code/game/mob/crafting_atlas_tgui.dm').read_text()
OPEN=ADAPTER.split('/datum/crafting_atlas_presenter/tgui/open(',1)[1].split('/datum/nanoui/tgui/crafting_atlas\n',1)[0]
NAV=ADAPTER.split('/datum/crafting_atlas_presenter/tgui/navigate(',1)[1].split('/datum/crafting_atlas_presenter/tgui/proc/recipe_data(',1)[0]
STATE=ADAPTER.split('/datum/topic_state/crafting_atlas/can_use_topic',1)[1].split('/datum/crafting_atlas_presenter/tgui/navigate',1)[0]
MODEL=ADAPTER.split('/datum/crafting_atlas_presenter/tgui/proc/model(',1)[1]
def proc(content,name):
 marker='/datum/crafting_atlas_reference/proc/'+name+'('
 body=content[content.index(marker):];end=re.search(r'\n/[^\n]+',body)
 return (body[:end.start()] if end else body).rstrip()+'\n'

class AtlasAdapterContract(unittest.TestCase):
 def test_existing_catalog_matching_and_real_classic_renderers_remain_unchanged(self):
  fixture=json.loads((ROOT/'tests/tgui/fixtures/atlas-legacy-contract.json').read_text())
  for name,digest in fixture['procs'].items():
   self.assertEqual(hashlib.sha256(proc(CORE,name).encode()).hexdigest(),digest,name)
  self.assertIn('legacy_renderer',ADAPTER)
  self.assertIn('var/list/arguments = list(user) + render_arguments',ADAPTER)
  self.assertIn('return reference.render_html(arglist(arguments))',ADAPTER)

 def test_original_entrypoints_throttle_load_and_cancellation_are_preserved(self):
  show=proc(CORE,'show')
  for marker in ('!viewer || !viewer.client','world.time < viewer.client.atlas_last_request + 10','viewer.client.atlas_last_request = world.time','!load_catalog()','crafting_atlas_presenter.open','viewer << browse'):
   self.assertIn(marker,show)
  self.assertLess(show.index('atlas_last_request = world.time'),show.index('!load_catalog()'))
  self.assertLess(show.index('!load_catalog()'),show.index('crafting_atlas_presenter.open'))
  topic=CORE.split('/datum/crafting_atlas_reference/Topic',1)[1]
  self.assertIn('if (!isnull(query))\n\t\t\tshow(viewer, query)',topic)
  for marker in ('show(src)','processor = "sawmill"','processor = "grain_mill"','processor = "tanning_rack"'):
   self.assertIn(marker,CORE)

 def test_owner_projection_preserves_observers_dead_readers_and_rejects_other_bodies(self):
  match=re.search(r'if \((.+)\)\n\t\treturn STATUS_CLOSE',STATE);self.assertIsNotNone(match)
  expression=match.group(1).replace('!user.client','not connected').replace('!user','not user').replace('||','or')
  def allowed(owner,user,source,reference,connected=True):
   return not eval(expression,{'__builtins__':{}},dict(user=user,reader=owner,src_object=source,reference=reference,connected=connected))
  for kind in ('human','observer','dead','incapacitated'):
   owner=object();reference=object()
   self.assertTrue(allowed(owner,owner,reference,reference),kind)
   self.assertFalse(allowed(owner,object(),reference,reference),kind)
   self.assertFalse(allowed(owner,owner,object(),reference),kind)
   self.assertFalse(allowed(owner,owner,reference,reference,False),kind)
  self.assertIn('return STATUS_INTERACTIVE',STATE)
  self.assertNotRegex(STATE,r'ishuman|isliving|shared_nano_interaction|stat|civilization')

 def test_typed_navigation_accepts_only_its_current_ui_state_after_transport_ack(self):
  for marker in ('!istype(ui)','ui.user != viewer','ui.src_object != reference','ui.state != state','STATUS_INTERACTIVE','ui.legacy_renderer','!ui.frontend_ready','!ui.frontend_acknowledged','length(payload) > 1024','params.len > 6','!istext(params["route"])'):
   self.assertIn(marker,NAV)
   self.assertLess(NAV.index(marker),NAV.index('var/route = params["route"]'))
  self.assertIn('return list("atlas_navigate")',ADAPTER)
  shared=(ROOT/'code/modules/nano/tgui.dm').read_text()
  self.assertNotIn('atlas_navigate',shared)
  topic=CORE.split('/datum/crafting_atlas_reference/Topic(href, list/href_list, state)',1)[1]
  self.assertIn('navigate(src, viewer, href_list["atlas_navigate"], state)',topic)

 def test_projected_action_keys_reject_arbitrary_forwarding_and_nested_payloads(self):
  switch=NAV.split('switch (route)',1)[1].split('for (var/key in params)',1)[0]
  keys={name:set(re.findall(r'"([^"]+)"',body)) for name,body in re.findall(r'if \("(\w+)"\)\n\t\t\tkeys = list\(([^)]+)\)',switch)}
  self.assertEqual(set(keys),{'open','page','resource','reset'})
  def valid(payload):
   if not isinstance(payload,dict) or len(payload)>6 or payload.get('route') not in keys:return False
   return all(key in keys[payload['route']] and isinstance(value,(str,int,float)) for key,value in payload.items())
  for payload in ({'route':'open','query':'wood','era':'multiple','processor':'sawmill','recipe':'r2'},{'route':'page','page':10000,'query':''},{'route':'resource','resource':'/material/wood'},{'route':'reset'}):
   self.assertTrue(valid(payload))
  for payload in ({'route':'craft'},{'route':'reset','href':'?admin=1'},{'route':'resource','resource':{}},{'route':'open','query':[]},{'route':'resource','query':'carry filters'}):
   self.assertFalse(valid(payload))
  self.assertIn('!(key in keys)',NAV)
  self.assertIn('!istext(params[key]) && !isnum(params[key])',NAV)

 def test_resource_route_resets_filters_and_every_navigation_uses_existing_show(self):
  resource=NAV.split('if (route == "resource")',1)[1].split('else if (route == "reset")',1)[0]
  self.assertIn('reference.resource_exists(resource_id)',resource)
  self.assertIn('reference.show(viewer, resource_id, 1, resource_id)',resource)
  self.assertNotIn('era =',resource)
  self.assertIn('legacy = TRUE',NAV)
  self.assertIn('return FALSE',NAV)
  self.assertNotIn('update_uis',NAV)
  self.assertNotRegex(NAV,r'\binput\(|\bnew\s+/obj|\.Topic\(|\bcall\(')

 def test_server_model_keeps_bounds_selection_recipe_filters_and_resource_independence(self):
  for marker in ('copytext("[query]", 1, 65)','max(1, min(10000, round(page)))','shown >= 12','matched > first + 11','resource_rows.len >= 150','matched <= 150','reference.matching_variants','reference.variant_record','processor && recipe["processor"] != processor','era == "unknown"','era == "multiple"','!(text2num(era) in eras)','!selected || choice["id"] == recipe_id'):
   self.assertIn(marker,MODEL)
  self.assertLess(MODEL.index('reference.matching_resources(query)'),MODEL.index('processor && recipe["processor"] != processor'))
  guidance=ADAPTER.split('/datum/crafting_atlas_presenter/tgui/proc/guidance_data',1)[1].split('/datum/crafting_atlas_presenter/tgui/proc/model',1)[0]
  self.assertIn('entries.len >= 12',guidance)
  self.assertIn('findtext("[resource_id]", "/turf/") == 1',guidance)
  self.assertIn('"Can provide (conditional)"',guidance)
  recipe=ADAPTER.split('/datum/crafting_atlas_presenter/tgui/proc/recipe_data',1)[1].split('/datum/crafting_atlas_presenter/tgui/proc/guidance_data',1)[0]
  self.assertNotIn('"raw"',recipe)
  self.assertIn('for (var/list/variant in matches)',recipe)

 def test_resource_preview_uses_initial_metadata_and_retains_existing_names_and_fallback(self):
  info=proc(CORE,'resource_info')
  for marker in ('initial(prototype.icon)','initial(prototype.icon_state)','image_data["state"]','/obj/item/weapon/paper','initial(prototype.dir)','atlas_[md5("[id]")].png','viewer << browse_rsc(preview, filename)'):
   self.assertIn(marker,info)
  self.assertNotRegex(info,r'new\s+/obj|new\s+typepath|\.New\(')
  self.assertIn('"image" = image_file',info)
  self.assertIn('"preview" = preview_label',info)

 def test_close_polling_and_standalone_fixture_boundaries(self):
  self.assertIn('ui.use_on_close_logic(FALSE)',OPEN)
  self.assertLess(OPEN.index('ui.use_on_close_logic(FALSE)'),OPEN.index('ui.open()'))
  self.assertIn('if (!ui.legacy_renderer)',OPEN)
  update=ADAPTER.split('/datum/nanoui/tgui/crafting_atlas/update',1)[1].split('/datum/topic_state/crafting_atlas\n',1)[0]
  self.assertNotRegex(update,r'\bmodel\(|resource_info|reference\.show|load_catalog|set_auto_update|spawn\(')
  self.assertIn('update_status(FALSE)',update)
  self.assertNotRegex(ADAPTER,r'set_using_object|unset_using_object|set_auto_update|spawn\(')
  self.assertNotRegex(CORE,r'\bnanoui\b|\bGLOB\b|\bSTATUS_')
  self.assertIn('#include "code\\game\\mob\\crafting_atlas_tgui.dm"',(ROOT/'civ13.dme').read_text())
  workflow=(ROOT/'.github/workflows/tgui.yml').read_text()
  self.assertIn("'code/game/mob/crafting_atlas.dm'",workflow)
  self.assertIn("'code/game/mob/crafting_atlas_tgui.dm'",workflow)

if __name__=='__main__':unittest.main()
