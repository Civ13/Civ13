"""Atlas adapter contracts/projections only; no DM/client/native execution."""
from pathlib import Path
import hashlib,json,re,unittest
ROOT=Path(__file__).resolve().parents[2]
CORE=(ROOT/'code/game/mob/crafting_atlas.dm').read_text()
ADAPTER=(ROOT/'code/game/mob/crafting_atlas_tgui.dm').read_text()
OPEN=ADAPTER.split('/datum/crafting_atlas_presenter/tgui/open(',1)[1].split('/datum/nanoui/tgui/crafting_atlas\n',1)[0]
NAV=ADAPTER.split('/datum/crafting_atlas_presenter/tgui/navigate(',1)[1].split('/client\n\tvar/list/atlas_icon_cache',1)[0]
STATE=ADAPTER.split('/datum/topic_state/crafting_atlas/can_use_topic',1)[1].split('/datum/crafting_atlas_presenter/tgui/navigate',1)[0]
MODEL=ADAPTER.split('/datum/crafting_atlas_presenter/tgui/proc/model(',1)[1]
def part(name,until):
 return ADAPTER.split('/datum/crafting_atlas_presenter/tgui/proc/'+name+'(',1)[1].split('/datum/crafting_atlas_presenter/tgui/proc/'+until+'(',1)[0]
def proc(content,name):
 marker='/datum/crafting_atlas_reference/proc/'+name+'('
 body=content[content.index(marker):];end=re.search(r'\n/[^\n]+',body)
 return (body[:end.start()] if end else body).rstrip()+'\n'

class AtlasAdapterContract(unittest.TestCase):
 def test_personal_manuals_are_per_reader_route_metadata_not_output_inference(self):
  hint=ADAPTER.split('/datum/crafting_atlas_presenter/tgui/manual_hint(',1)[1]
  self.assertIn('recipe["research_status"] != "gated"',hint)
  self.assertIn('recipe["research_nodes"]',hint)
  self.assertNotIn('outputs',hint)
  self.assertNotRegex(hint,r'recipe\[[^\n]+\]\s*=')
  helper=ADAPTER.split('/proc/crafting_node_manual_hint(',1)[1].split('/proc/crafting_recipe_manual_hint',1)[0]
  for guard in ('map.recipe_knowledge_enabled()', '!ishuman(viewer)', 'H.knows_recipe_node(node_id)', 'get_research_node(node_id)'):
   self.assertIn(guard,helper)
  self.assertIn('html_encode(manual_hint(viewer, recipe))',ADAPTER)
  self.assertIn('manual_hint_html(viewer, recipe)',proc(CORE,'page_html'))
  self.assertIn('manual_hint_html(viewer, selected)',proc(CORE,'graph_html'))

 def test_learning_refreshes_only_current_reader_and_retains_atlas_route(self):
  refresh=ADAPTER.split('/mob/living/human/proc/refresh_recipe_knowledge_menus()',1)[1].split('/datum/crafting_atlas_presenter/tgui/manual_hint',1)[0]
  for marker in ('ui.user == src', 'ui.render_arguments', 'ui.push_data(', 'stack.loc == src', 'item_is_in_hands(stack)'):
   self.assertIn(marker,refresh)
  self.assertNotIn('for (',refresh)
  self.assertNotIn('show(src)',refresh)
  learning=(ROOT/'code/modules/research_tree/character_knowledge.dm').read_text().split('/mob/living/human/proc/learn_recipe_node(',1)[1].split('/mob/living/human/proc/initialize_recipe_knowledge',1)[0]
  self.assertIn('refresh_recipe_knowledge_menus()',learning)

 def test_unknown_stack_recipe_has_no_single_or_batch_craft_link(self):
  stack=(ROOT/'code/game/objects/items/stacks/stack.dm').read_text()
  menu=stack.split('/obj/item/stack/proc/list_recipes(',1)[1].split('// Custom qdel',1)[0]
  lock=menu.index('if (manual_hint)')
  self.assertLess(lock,menu.index('make=[i]'))
  self.assertIn('continue',menu[lock:menu.index('if (can_build)',lock)])
  self.assertIn('html_encode(manual_hint)',menu)

 def test_station_labels_preserve_canonical_choices_and_explicit_foundry_gate(self):
  anvil=(ROOT/'code/game/objects/structures/blacksmithing/blacksmithing.dm').read_text()
  labels=[line for line in anvil.splitlines() if 'newlist += "[anvil_recipes[i][1]] - ' in line]
  self.assertEqual(len(labels),5)
  self.assertTrue(all('crafting_recipe_manual_suffix(H, "[anvil_recipes[i][9]]")' in line for line in labels))
  workbench=(ROOT/'code/game/objects/structures/blacksmithing/component_workbench.dm').read_text()
  for marker in ('choices[label] = recipe_name', 'choices[selected_label]', 'select_recipe(H, choice)'):
   self.assertIn(marker,workbench)
  dedicated=(ROOT/'code/game/objects/structures/blacksmithing/dedicated_workbenches.dm').read_text()
  self.assertIn('crafting_node_manual_hint(H, "machined_tools")',dedicated)
  factory=(ROOT/'code/modules/1713/factory_fabricators.dm').read_text()
  for marker in ('crafting_node_manual_hint(H, R.node)', 'labels[label] = recipe_choice', 'labels[selected_label]'):
   self.assertIn(marker,factory)

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
  for payload in ({'route':'open','query':'wood','era':'multiple','processor':'sawmill','recipe':'r2','scope':'all'},{'route':'page','page':10000,'query':''},{'route':'resource','resource':'/material/wood','recipe':'r2','scope':''},{'route':'reset'}):
   self.assertTrue(valid(payload))
  for payload in ({'route':'craft'},{'route':'reset','href':'?admin=1'},{'route':'resource','resource':{}},{'route':'open','query':[]},{'route':'resource','query':'carry filters'}):
   self.assertFalse(valid(payload))
  self.assertIn('!(key in keys)',NAV)
  self.assertIn('!istext(params[key]) && !isnum(params[key])',NAV)

 def test_resource_route_resets_filters_and_every_navigation_uses_existing_show(self):
  resource=NAV.split('if (route == "resource")',1)[1].split('else if (route == "reset")',1)[0]
  self.assertIn('reference.resource_exists(resource_id)',resource)
  self.assertIn('reference.show(viewer, resource_id, 1, resource_id, recipe_id = copytext("[params["recipe"]]", 1, 32))',resource)
  self.assertNotIn('era =',resource)
  self.assertNotIn('params["query"]',resource)
  self.assertIn('legacy = TRUE',NAV)
  self.assertIn('return FALSE',NAV)
  self.assertNotIn('update_uis',NAV)
  self.assertNotRegex(NAV,r'\binput\(|\bnew\s+/obj|\.Topic\(|\bcall\(')

 def test_server_model_keeps_bounds_selection_recipe_filters_and_resource_independence(self):
  for marker in ('copytext("[query]", 1, 65)','max(1, min(10000, round(page)))','shown >= 12','matched > first + 11','resource_rows.len >= 150','index.len >= 150 && family != selected_family','reference.matching_variants','reference.variant_record','processor && recipe["processor"] != processor','!era_allows(recipe, era)','choice["id"] == recipe_id'):
   self.assertIn(marker,MODEL)
  eras=part('era_allows','resource_model')
  for marker in ('era == "unknown"','era == "multiple"','!(text2num(era) in eras)'):
   self.assertIn(marker,eras)
  self.assertLess(MODEL.index('search_resources(reference, words)'),MODEL.index('processor && recipe["processor"] != processor'))
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

class AtlasFamilyContract(unittest.TestCase):
 def test_family_metadata_is_presentation_only_and_old_catalogs_remain_separate(self):
  self.assertIn('recipe["family_id"] ? recipe["family_id"] : "recipe_[recipe["id"]]"',MODEL)
  self.assertNotIn('family_id',NAV)
  self.assertNotIn('family_id',CORE)
  self.assertNotRegex(ADAPTER,r'new /obj|new typepath|text2path|parent_type')

 def test_grouping_is_after_each_recipe_filter_and_before_family_bound(self):
  self.assertLess(MODEL.index('search_variants(reference, recipe, words)'),MODEL.index('var/family = recipe["family_id"]'))
  for guard in ('processor && recipe["processor"] != processor','!era_allows(recipe, era)','matches = catalog_matches(matches, catalog, scope)'):
   self.assertLess(MODEL.index(guard),MODEL.index('var/family = recipe["family_id"]'))
  self.assertIn('if (!islist(members))\n\t\t\tmatched++',MODEL)
  self.assertIn('if (index.len >= 150 && family != selected_family)\n\t\t\tcontinue',MODEL)
  self.assertIn('data["recipe_count"] = recipe_matches',MODEL)
  self.assertIn('data["family_count"] = matched',MODEL)
  self.assertIn('members += list(list("group" = recipe, "matches" = matches))',MODEL)
  self.assertIn('row["id"] = choice["id"]',MODEL)
  self.assertIn('family_members[selected_family]',MODEL)
  self.assertIn('recipe_data(reference, viewer, selected_group, selected_matches, selected, catalog, known)',MODEL)

 def test_family_selector_retains_canonical_choices_and_selected_detail(self):
  options=ADAPTER.split('/datum/crafting_atlas_presenter/tgui/proc/family_variants(',1)[1].split('/datum/crafting_atlas_presenter/tgui/proc/model(',1)[0]
  for marker in ('var/list/matches = member["matches"]','variant["id"] == recipe_id','chosen = variant','amounts(reference, group["outputs"])','amounts(reference, group["inputs"])','chosen["kind"]','group["era_label"]','chosen["line"]','"id" = chosen["id"]','html_encode(label)'):
   self.assertIn(marker,options)
  self.assertNotIn('family_',NAV)
  self.assertIn('members.len > 1',MODEL)
  amounts=part('amounts','row_data')
  for marker in ('resource["quantity"]','display_name(reference, resource["id"], resource["name"])'):
   self.assertIn(marker,amounts)
  # Core IDs, classic HTML, search and action admission remain unchanged, covered above.

class AtlasReaderViewContract(unittest.TestCase):
 def test_scope_is_a_two_value_window_setting_and_reset_clears_it(self):
  self.assertIn('ui.scope = params["scope"] == "all" ? "all" : ""',NAV)
  self.assertLess(NAV.index('!(key in keys)'),NAV.index('ui.scope = params["scope"]'))
  self.assertIn('ui.scope = ""\n\t\treference.show(viewer)',NAV)
  self.assertIn('model(arglist(arguments + ui.scope))',ADAPTER)
  self.assertNotRegex(NAV,r'show\([^\n]*scope')

 def test_atlas_and_crafting_share_one_catalog_key(self):
  recipes=(ROOT/'code/game/objects/items/stacks/civ_recipes.dm').read_text()
  key=recipes.split('/proc/crafting_catalog_key(',1)[1].split('\n/',1)[0]
  for marker in ('faction_text','pygmy','map.override_global_recipes'):
   self.assertIn(marker,key)
  crafting=recipes.split('/material/proc/get_recipes_civs(',1)[1].split('\n/',1)[0]
  self.assertIn('crafting_catalog_key(',crafting)
  self.assertNotIn('override_global_recipes',crafting)
  self.assertIn('var/catalog = crafting_catalog_key(viewer)',MODEL)

 def test_other_map_catalogs_are_hidden_until_requested_and_counted(self):
  scope=part('catalog_matches','has_local')
  for marker in ('findtext(kind, "Material / ") != 1','kind == "Material / [catalog]"','if (scope == "all")\n\t\treturn local + other','return local'):
   self.assertIn(marker,scope)
  self.assertIn('hidden++',MODEL)
  self.assertIn('data["hidden_count"] = hidden',MODEL)
  self.assertLess(MODEL.index('hidden++'),MODEL.index('recipe_matches++'))

 def test_word_search_is_bounded_and_every_word_must_match_one_variant(self):
  words=part('search_words','search_variants')
  self.assertIn('words.len < 6',words)
  self.assertIn('reference.search_text(query)',words)
  variants=part('search_variants','all_words')
  self.assertIn('reference.matching_variants(recipe, words.len ? words[1] : "")',variants)
  self.assertIn('if (variant in also)',variants)
  resources=part('search_resources','amounts')
  self.assertIn('if (!words.len)\n\t\treturn exact',resources)
  self.assertIn('return exact + other',resources)
  self.assertIn('var/list/order = exact + named + other',MODEL)

 def test_resource_page_lists_exact_makers_and_users_within_bounds(self):
  page=part('resource_model','model')
  for marker in ('product["id"] == resource_id','ingredient["id"] == resource_id','makes && ++made <= 60','uses && ++used <= 60','data["query"] = ""','guidance["made_by_count"] = made','guidance["used_in_count"] = used'):
   self.assertIn(marker,page)
  self.assertNotIn('search_',page)
  self.assertIn('return resource_model(reference, viewer, data, resource_id, recipe_id, catalog, scope, known)',MODEL)

 def test_research_status_is_display_only_and_reuses_crafting_admission(self):
  research=part('research_data','research_state')
  for marker in ('recipe["research_status"] != "gated"','crafting_node_allowed(H, node_id)','crafting_node_world_allowed(H.civilization, node_id)','map.book_research_enabled()','known[key] = state','get_research_node(node_id)'):
   self.assertIn(marker,research)
  self.assertNotRegex(research,r'learn_|\.research|civilization\s*=')
  self.assertIn('recipe_age_allowed(recipe["maximum_era"])',part('retired','catalog_matches'))

 def test_previews_are_sent_once_per_reader(self):
  view=part('resource_view','research_data')
  for marker in ('reader.atlas_icon_cache[id]','if (!islist(cached))','reference.resource_info(viewer, resource)','reader.atlas_icon_cache[id] = cached'):
   self.assertIn(marker,view)
  self.assertLess(view.index('if (!islist(cached))'),view.index('reference.resource_info(viewer, resource)'))

class AtlasItemPageContract(unittest.TestCase):
 def test_item_page_carries_bounded_encoded_facts_and_opens_on_its_recipe(self):
  facts=part('facts_data','display_name')
  for marker in ('html_encode("[resource["kind"]]")','html_encode("[resource["desc"]]")','stat.len == 2 && rows.len < 16','html_encode("[stat[1]]")','html_encode("[stat[2]]")'):
   self.assertIn(marker,facts)
  self.assertIn('+ facts_data(reference, resource_id)',part('guidance_data','family_variants'))
  page=part('resource_model','model')
  for marker in ('if (makes && !first)','if (!selected && first)\n\t\tselected = first','hosts && ++hosted <= 60','guidance["made_here_count"] = hosted'):
   self.assertIn(marker,page)

 def test_workstation_links_are_presentation_only_and_need_a_real_resource(self):
  station=part('station_of','facts_data')
  self.assertIn('var/station = recipe["station"]',station)
  self.assertIn('kind_stations["[recipe["kind"]]"]',station)
  self.assertIn('reference.resource_exists(station) ? station : ""',station)
  catalog=json.loads((ROOT/'UI/crafting-atlas.json').read_text())
  table=ADAPTER.split('var/static/list/kind_stations = list(',1)[1].split(')\n',1)[0]
  pairs=re.findall(r'"([^"]+)" = "([^"]+)"',table)
  self.assertEqual(len(pairs),8)
  kinds={recipe['kind'] for recipe in catalog['recipes']}
  for kind,station in pairs:
   self.assertIn(kind,kinds)
   self.assertIn(station,catalog['resources'],station)
  self.assertNotRegex(ADAPTER,r'recipe\["station"\]\s*=[^=]')

class AtlasFactsContract(unittest.TestCase):
 def test_facts_read_literals_inherit_and_never_guess_runtime_values(self):
  import sys
  sys.path.insert(0,str(ROOT/'scripts'))
  from atlas.facts import resource_facts
  files={'a.dm':'/obj/item/clothing/suit/coat\n\tname = "coat"\n\tdesc = "A warm coat." // note\n\tw_class = ITEM_SIZE_NORMAL\n\tslot_flags = SLOT_OCLOTHING\n\tbody_parts_covered = UPPER_TORSO|ARMS\n\tarmor = list(melee = 10, arrow = 0, gun = FALSE)\n\tforce = 7\n'
   '/obj/item/clothing/suit/coat/fur\n\tdesc = "A fur coat. It has 0 holes in it."\n/obj/item/clothing/suit/coat/odd\n\tdesc = "Made of [material]."\n\tw_class = max(1, 2)\n'
   '/obj/item/weapon/club\n\tdesc = "A \\"big\\" club // not a comment."\n\tforce = 12\n\tthrowforce = 0\n\tsharp = TRUE\n\tproc/unused()\n\t\tforce = 99\n'
   '/obj/item/weapon/club/proc/swing()\n\tforce = 50\n/obj/item/weapon/material/sword\n\tforce = 30\n\tedge = TRUE\n'
   '/datum/reagent/water\n\tid = "water"\n\tdescription = "Wet."\n\ttaste_description = "water"\n/mob/living/simple_animal/goat\n\tmaxHealth = 40\n'}
  types={'/coat':'/obj/item/clothing/suit/coat','/fur':'/obj/item/clothing/suit/coat/fur','/odd':'/obj/item/clothing/suit/coat/odd','/club':'/obj/item/weapon/club','/sword':'/obj/item/weapon/material/sword','water':'water','mystery':'mystery','/goat':'/mob/living/simple_animal/goat'}
  facts=resource_facts(files,types)
  self.assertEqual(facts['/coat'],{'kind':'Clothing','desc':'A warm coat.','stats':[['Size','Normal'],['Worn on','over clothing'],['Covers','chest, arms'],['Armor','melee 10']]})
  self.assertEqual(facts['/fur']['desc'],'A fur coat.')
  self.assertEqual(facts['/fur']['stats'],facts['/coat']['stats'])
  self.assertNotIn('desc',facts['/odd'])
  self.assertNotIn('Size',dict(facts['/odd']['stats']))
  self.assertEqual(facts['/club'],{'kind':'Item','desc':'A "big" club // not a comment.','stats':[['Melee damage','12'],['Blade','sharp']]})
  self.assertEqual(facts['/sword'],{'kind':'Tool or weapon','stats':[['Blade','edged']]})
  self.assertEqual(facts['water'],{'kind':'Chemical','desc':'Wet.','stats':[['Taste','water']]})
  self.assertEqual(facts['mystery'],{'kind':'Chemical'})
  self.assertEqual(facts['/goat'],{'kind':'Animal','stats':[['Health','40']]})

 def test_generated_catalog_describes_most_resources(self):
  resources=json.loads((ROOT/'UI/crafting-atlas.json').read_text())['resources']
  self.assertTrue(all(value.get('kind') for value in resources.values()))
  self.assertGreater(sum('desc' in value for value in resources.values()),len(resources)*0.85)
  for key,value in resources.items():
   self.assertNotRegex(value.get('desc',''),r'[\[\]<>\\]',key)
   self.assertLessEqual(len(value.get('stats',[])),16,key)
   for row in value.get('stats',[]):
    self.assertTrue(len(row)==2 and all(isinstance(cell,str) and cell for cell in row),key)

class AtlasTitleContract(unittest.TestCase):
 def test_titles_use_declared_names_and_never_replace_reviewed_names(self):
  import sys
  sys.path.insert(0,str(ROOT/'scripts'))
  from atlas.titles import display_titles
  files={'a.dm':'/obj/item/pelt\n\tname = "animal pelt"\n/obj/item/pelt/bear/brown\n\tname = "brown bear pelt"\n/obj/item/pelt/bear/black\n\ticon_state = "black"\n/obj/item/stack/material/wood\n\tname = "wooden plank"\n/obj/item/fork\n\tname = "[display_name] fork"\n','b.txt':'/obj/item/ignored\n\tname = "ignored"\n'}
  types={'/obj/item/pelt/bear/brown':'/obj/item/pelt/bear/brown','/obj/item/pelt/bear/black':'/obj/item/pelt/bear/black','/material/wood':'/obj/item/stack/material/wood','/obj/item/fork':'/obj/item/fork','water':'water','/obj/item/pelt':'/obj/item/pelt','/obj/item/ignored':'/obj/item/ignored'}
  names={'/obj/item/pelt/bear/brown':'brown','/obj/item/pelt/bear/black':'black','/material/wood':'wood','/obj/item/fork':'fork','water':'water','/obj/item/pelt':'reviewed pelt','/obj/item/ignored':'ignored'}
  self.assertEqual(display_titles(files,types,names),{'/obj/item/pelt/bear/brown':'brown bear pelt','/obj/item/pelt/bear/black':'animal pelt (black)'})

 def test_generated_catalog_titles_are_presentation_only(self):
  catalog=json.loads((ROOT/'UI/crafting-atlas.json').read_text())
  resources=catalog['resources']
  titled={key:value for key,value in resources.items() if 'title' in value}
  self.assertGreater(len(titled),1000)
  self.assertEqual(resources['/obj/item/clothing/suit/storage/coat/fur']['title'],'fur coat')
  self.assertNotIn('title',resources['/material/wood'])
  for key,value in titled.items():
   self.assertTrue(value['name'] and value['title'] and '[' not in value['title'],key)
  for recipe in catalog['recipes']:
   for item in recipe['inputs']+recipe['outputs']:
    self.assertNotIn('title',item)
    self.assertNotIn('[',item['name'],recipe['name'])
    self.assertNotEqual(item['name'],'generate recipes civs',recipe['name'])

if __name__=='__main__':unittest.main()
