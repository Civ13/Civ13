// Late research on book-research worlds, on production source: standing node
// effects. Client presence, light and action waits are isolated.
var/late_failures = 0
var/late_wait_result = TRUE
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf
	visibility = 0
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/obj/map_metadata/late_fixture
	recipe_books = TRUE
	book_research = TRUE
/obj/map_metadata/late_fixture/New()
	return
/mob/living/human/late_fixture/New()
	initialize_recipe_knowledge()
/mob/living/human/late_fixture/incapacitated()
	return stat != CONSCIOUS
/mob/living/human/late_fixture/restrained()
	return FALSE
/mob/living/human/late_fixture/research_presence()
	return TRUE
/mob/living/human/late_fixture/reading_light_problem()
	return null
/mob/living/human/late_fixture/update_icons()
	return
// Knowledge granted directly: studying is covered by tests/research_interface.
/mob/living/human/late_fixture/proc/teach(node_id)
	known_recipe_nodes |= node_id
/obj/structure/research_bench/late_fixture/research_lit()
	return TRUE
/proc/late_wait(mob/living/human/H, delay, atom/target)
	return late_wait_result
/proc/late_check(condition, label)
	if(!condition) late_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	late_failures++
	world.log << "runtime error: [e] [e.file]:[e.line]"
/proc/late_test_node_effects()
	var/mob/living/human/late_fixture/H = new(locate(3,2,1))
	var/mob/living/human/late_fixture/novice = new(locate(5,2,1))
	for(var/node_id in research_node_effects)
		late_check(get_research_node(node_id) && length(research_node_effect_text(node_id)), "[node_id] is a real node with an effect line")
		late_check(!H.has_node_effect(node_id), "[node_id] gives nothing before it is studied")
		H.teach(node_id)
		late_check(H.has_node_effect(node_id) && !novice.has_node_effect(node_id), "[node_id] belongs to the character who knows it")
	late_check(!H.has_node_effect("basic_tools"), "nodes without a listed effect grant none")
	// Alloys: forged metal lasts longer; wood and other makers' work do not.
	var/obj/item/weapon/material/hatchet/plain = new(locate(1,1,1), "steel")
	var/obj/item/weapon/material/hatchet/alloyed = new(locate(1,1,1), "steel")
	var/obj/item/weapon/material/hatchet/wooden = new(locate(1,1,1), "wood")
	var/wood_health = wooden.maxhealth
	late_check(!apply_crafting_node_effects(novice, plain) && plain.maxhealth == alloyed.maxhealth, "a smith without Alloys forges ordinary steel")
	late_check(apply_crafting_node_effects(H, alloyed) && alloyed.maxhealth == round(plain.maxhealth * 1.3) && alloyed.health == alloyed.maxhealth, "Alloys makes forged steel last 30% longer ([plain.maxhealth] to [alloyed.maxhealth])")
	late_check(!apply_crafting_node_effects(H, wooden) && wooden.maxhealth == wood_health, "Alloys leaves wooden tools alone")
	late_check(!apply_crafting_node_effects(H, new /obj/item/weapon/paper(locate(1,1,1))), "Alloys ignores things that are not material tools")
	// The scales each hook multiplies by.
	late_check(farming_node_bonus(H) == 0.25 && farming_node_bonus(novice) == 0, "Advanced Agriculture adds a quarter to the harvest")
	late_check(harvest_skill_user_bonus(H, "farming") - harvest_skill_user_bonus(novice, "farming") == 0.25 && harvest_skill_user_bonus(H, "hunting") == harvest_skill_user_bonus(novice, "hunting"), "the harvest bonus reaches farming and not hunting")
	late_check(surgery_node_quality(H) == 1.15 && surgery_node_quality(novice) == 1, "Anesthetic Surgery steadies the surgeon's steps")
	late_check(surgery_node_time(H) == 0.75 && surgery_node_time(novice) == 1, "Modern Medicine shortens surgery steps")
	late_check(H.disease_node_scale() == 0.5 && novice.disease_node_scale() == 1, "Public Health halves the chance of catching an illness")
	late_check(flight_fuel_node_scale(H) == 0.75 && flight_fuel_node_scale(novice) == 1 && flight_fuel_node_scale(null) == 1, "Aviation & Rocketry saves flight fuel, and an empty cockpit saves none")
	// Off book-research worlds nothing applies and no line is shown.
	map.book_research = FALSE
	late_check(!H.has_node_effect("alloys") && isnull(research_node_effect_text("alloys")) && farming_node_bonus(H) == 0 && H.disease_node_scale() == 1, "effects are off where book research is off")
	map.book_research = TRUE
	H.stat = DEAD
	late_check(!H.has_node_effect("alloys"), "the dead hold no effects")
/world/New()
	OpenPort("none")
	generate_gameid()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	movementMachine = new
	map = new /obj/map_metadata/late_fixture(locate(1,1,1))
	map.persistence = TRUE
	map.ordinal_age = 0
	build_research_tree()
	try
		late_test_node_effects()
	catch(var/exception/e)
		late_failures++
		world.log << "FAIL: exception [e] [e.file]:[e.line]"
	var/list/params = islist(world.params) ? world.params : params2list(world.params)
	text2file(json_encode(list("failures" = late_failures, "commit" = params["tested_commit"], "byond_build" = world.byond_build)), "result.json")
	shutdown()
