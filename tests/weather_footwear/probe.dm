// Headless probe for weather footwear (code/modules/1713/weather_footwear.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/weather_footwear/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

// Era gate only: a node counts as done once its era is reached.
/obj/map_metadata/footwear_probe/New()
	return
/obj/map_metadata/footwear_probe/is_node_done(faction, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	return N && N.era_tier <= ordinal_age

/mob/living/human/footwear_tester/New()
	return
// No species or body is set up, so skip drawing after a slip.
/mob/living/human/footwear_tester/update_icons()
	return
/mob/living/human/footwear_tester/UpdateDamageIcon(var/update_icons=1)
	return
/mob/living/human/footwear_tester/update_body(var/update_icons=1, var/forced=FALSE)
	return
// The probe checks the slip decision; knockdown needs a full body.
/mob/living/human/footwear_tester/var/knockdowns = 0
/mob/living/human/footwear_tester/Weaken(amount)
	knockdowns++
/mob/living/human/footwear_tester/Stun(amount)
	return

var/footwear_failures = 0
var/footwear_runtime_error = FALSE
/proc/footwear_check(condition, label)
	if (!condition)
		footwear_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	footwear_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/footwear_probe
		build_research_tree()
		footwear_recipe_checks()
		footwear_rating_checks()
		footwear_ground_checks()
		footwear_ice_checks()
		footwear_sprite_checks()
	catch(var/exception/e)
		footwear_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = footwear_failures, "runtime_error" = footwear_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/footwear_recipe_paths(material_name)
	var/material/M = get_material_by_name(material_name)
	M.generate_recipes_civs(list(0,0,0), "global")
	. = list()
	for (var/R in M.recipes)
		if (istype(R, /datum/stack_recipe))
			var/datum/stack_recipe/SR = R
			. += SR.result_type
		else if (istype(R, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/L = R
			for (var/datum/stack_recipe/SR in L.recipes)
				. += SR.result_type

/proc/footwear_recipe_checks()
	var/list/catalog = list()
	for (var/line in file2list("config/crafting/material_recipes_global.txt", "\n"))
		if (findtext(line, "RECIPE: ") && !findtext(line, "//"))
			catalog += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
	craftlist_lists["global"] = catalog
	footwear_check(catalog.len > 100, "global crafting catalog loaded")

	map.ordinal_age = 0
	var/list/wood = footwear_recipe_paths("wood")
	var/list/leather = footwear_recipe_paths("leather")
	footwear_check(/obj/item/clothing/shoes/weather/snowshoes in wood, "Stone Age: wood makes snowshoes")
	footwear_check(/obj/item/clothing/shoes/weather/mukluks in leather, "Stone Age: leather makes mukluks")
	footwear_check(!(/obj/item/clothing/shoes/weather/hobnail_boots in leather), "Stone Age: no hobnailed boots yet")
	footwear_check(!(/obj/item/clothing/shoes/weather/pattens in wood), "Stone Age: no pattens yet")

	map.ordinal_age = 2
	wood = footwear_recipe_paths("wood")
	leather = footwear_recipe_paths("leather")
	footwear_check(/obj/item/clothing/shoes/weather/hobnail_boots in leather, "Iron Age: leather makes hobnailed boots")
	footwear_check(/obj/item/clothing/shoes/weather/pattens in wood, "Medieval: wood makes pattens")

	map.ordinal_age = 4
	footwear_check(!(/obj/item/clothing/shoes/weather/rubber_boots in footwear_recipe_paths("plastic")), "Industrial: rubber boots wait for ready-made clothing")
	map.ordinal_age = 5
	footwear_check(/obj/item/clothing/shoes/weather/rubber_boots in footwear_recipe_paths("plastic"), "Early modern: plastic makes rubber boots")
	footwear_check(!(/obj/item/clothing/shoes/weather/climbing_boots in footwear_recipe_paths("steel")), "Early modern: no mountaineering boots yet")
	map.ordinal_age = 6
	footwear_check(/obj/item/clothing/shoes/weather/climbing_boots in footwear_recipe_paths("steel"), "Alloys: steel makes mountaineering boots")
	for (var/path in typesof(/obj/item/clothing/shoes/weather) - /obj/item/clothing/shoes/weather)
		footwear_check(get_recipe_node_req("[path]"), "[path] has a research node")

/proc/footwear_wear(mob/living/human/H, path)
	if (H.shoes)
		qdel(H.shoes)
		H.shoes = null
	if (path)
		H.shoes = new path(H)
	return H.shoes

/proc/footwear_rating_checks()
	var/mob/living/human/footwear_tester/H = new(locate(2, 2, 1))
	footwear_check(footwear_terrain_mult(H, "snow") == 1 && footwear_terrain_mult(H, "mud") == 1 && footwear_terrain_mult(H, "wade") == 1, "bare feet have neutral terrain ratings")
	footwear_check(footwear_ice_grip(H) == 0 && footwear_slope_grip(H) == 1 && footwear_offsnow_slowdown(H) == 0, "bare feet have no grip bonus")
	footwear_check(footwear_feet_bare_to_snow(H) && !footwear_feet_dry(H), "bare feet freeze in snow and get wet")

	footwear_wear(H, /obj/item/clothing/shoes/weather/snowshoes)
	footwear_check(footwear_terrain_mult(H, "snow") <= 0.25, "snowshoes float on snow")
	footwear_check(footwear_offsnow_slowdown(H) > 0, "snowshoes are clumsy off snow")
	footwear_check(!footwear_feet_bare_to_snow(H), "snowshoes keep feet warm")

	footwear_wear(H, /obj/item/clothing/shoes/weather/mukluks)
	footwear_check(footwear_terrain_mult(H, "snow") < 1 && footwear_terrain_mult(H, "mud") > 1 && !footwear_feet_bare_to_snow(H), "mukluks: good in snow, poor in mud, warm")

	footwear_wear(H, /obj/item/clothing/shoes/weather/hobnail_boots)
	footwear_check(footwear_ice_grip(H) == 1 && footwear_slope_grip(H) < 1, "hobnails grip ice and slopes")

	footwear_wear(H, /obj/item/clothing/shoes/weather/pattens)
	footwear_check(footwear_terrain_mult(H, "mud") <= 0.5 && footwear_slope_grip(H) > 1 && footwear_feet_dry(H), "pattens lift you out of mud but wobble on slopes")

	footwear_wear(H, /obj/item/clothing/shoes/weather/rubber_boots)
	footwear_check(footwear_terrain_mult(H, "mud") <= 0.5 && footwear_terrain_mult(H, "wade") < 1 && footwear_feet_dry(H), "rubber boots handle mud and wading")

	footwear_wear(H, /obj/item/clothing/shoes/weather/climbing_boots)
	footwear_check(footwear_ice_grip(H) == 1 && footwear_slope_grip(H) <= 0.3 && footwear_terrain_mult(H, "snow") < 1 && !footwear_feet_bare_to_snow(H), "mountaineering boots: crampons, slopes, snow, warm")

	footwear_wear(H, /obj/item/clothing/shoes/sandal)
	footwear_check(footwear_feet_bare_to_snow(H) && footwear_terrain_mult(H, "snow") > 1, "sandals leave toes bare in snow")

	footwear_wear(H, /obj/item/clothing/shoes/fur)
	footwear_check(!footwear_feet_bare_to_snow(H) && footwear_terrain_mult(H, "snow") < 1, "fur boots are warm and good in snow")
	footwear_check(footwear_ice_grip(H) == 0.5, "NOSLIP boots grip ice half as well as hobnails")

	footwear_wear(H, /obj/item/clothing/shoes/laceup)
	footwear_check(!footwear_feet_bare_to_snow(H) && !footwear_feet_dry(H), "laceup shoes keep toes warm but are not wading footwear")

	footwear_wear(H, /obj/item/clothing/shoes/jackboots)
	footwear_check(footwear_feet_dry(H) && footwear_terrain_mult(H, "mud") < 1, "jackboots keep feet dry and help in mud")

	var/obj/item/clothing/shoes/weather/snowshoes/S = new(H)
	footwear_check(S.footwear_trait_notes().len >= 2, "snowshoes explain themselves on examine")
	var/obj/item/clothing/shoes/laceup/L = new(H)
	footwear_check(!L.footwear_trait_notes().len, "ordinary shoes add no examine notes")
	qdel(H)

/proc/footwear_ground_checks()
	var/turf/water = new /turf/floor/beach/water(locate(4, 4, 1))
	var/turf/ice = new /turf/floor/beach/water/ice(locate(5, 4, 1))
	var/turf/floor/dry = new /turf/floor/dirt(locate(6, 4, 1))
	footwear_check(footwear_wet_ground(water), "shallow water wets the feet")
	footwear_check(!footwear_wet_ground(ice), "ice does not wet the feet")
	footwear_check(!footwear_wet_ground(dry), "dry dirt does not wet the feet")
	dry.muddy = TRUE
	footwear_check(footwear_wet_ground(dry), "mud wets the feet")
	dry.muddy = FALSE
	footwear_check(footwear_ice_turf(ice) && !footwear_ice_turf(water), "ice is ice, water is not")

/proc/footwear_ice_slips(path, tries)
	var/turf/ice = locate(5, 4, 1)
	var/mob/living/human/footwear_tester/H = new(ice)
	H.m_intent = "run"
	footwear_wear(H, path)
	. = 0
	for (var/i = 1 to tries)
		H.lying = FALSE
		H.buckled = null
		if (footwear_ice_slip_check(H, ice, 1))
			.++
	qdel(H)

/proc/footwear_ice_checks()
	var/bare = footwear_ice_slips(null, 2000)
	var/noslip = footwear_ice_slips(/obj/item/clothing/shoes/fur, 2000)
	var/hobnail = footwear_ice_slips(/obj/item/clothing/shoes/weather/hobnail_boots, 2000)
	world.log << "ice slips in 2000 running steps: bare [bare], fur boots [noslip], hobnails [hobnail]"
	footwear_check(bare > 20 && bare < 120, "bare feet slip on about 3% of running steps on ice ([bare]/2000)")
	footwear_check(noslip < bare, "gripping boots slip less than bare feet")
	footwear_check(hobnail == 0, "hobnails never slip on ice")
	var/mob/living/human/footwear_tester/W = new(locate(5, 4, 1))
	W.m_intent = "walk"
	var/walked = 0
	for (var/i = 1 to 500)
		if (footwear_ice_slip_check(W, locate(5, 4, 1), 1))
			walked++
	footwear_check(!walked, "walking on ice never slips")
	var/turf/water = locate(4, 4, 1)
	W.m_intent = "run"
	var/water_slips = 0
	for (var/i = 1 to 500)
		W.lying = FALSE
		if (footwear_ice_slip_check(W, water, 1))
			water_slips++
	footwear_check(!water_slips, "running through water is not ice")

/proc/footwear_sprite_checks()
	var/list/item_states = icon_states('icons/obj/weather_footwear.dmi')
	var/list/worn_states = icon_states('icons/mob/weather_footwear.dmi')
	for (var/path in typesof(/obj/item/clothing/shoes/weather) - /obj/item/clothing/shoes/weather)
		var/obj/item/clothing/shoes/S = path
		var/state = initial(S.icon_state)
		footwear_check(state in item_states, "item icon state [state]")
		footwear_check(state in worn_states, "worn icon state [state]")
		for (var/d in list(NORTH, SOUTH, EAST, WEST))
			var/icon/I = icon('icons/mob/weather_footwear.dmi', state, d)
			var/drawn = FALSE
			for (var/y = 1 to 12)
				for (var/x = 1 to 32)
					if (I.GetPixel(x, y))
						drawn = TRUE
						break
				if (drawn)
					break
			footwear_check(drawn, "worn [state] is drawn at the feet facing [dir2text(d)]")
