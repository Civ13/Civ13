// Late research on book-research worlds, on production source: standing node
// effects, field work, research teams and rushed work. Client presence, light and action waits are isolated.
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
// Bodies here have no organs or species: record what would have hurt them.
/mob/living/human/late_fixture
	var/list/fixture_hurt = list()
/mob/living/human/late_fixture/apply_damage(var/damage = 0,var/damagetype = BRUTE, var/def_zone = null, var/blocked = FALSE, var/used_weapon = null, var/sharp = FALSE, var/edge = FALSE)
	fixture_hurt[damagetype] = (fixture_hurt[damagetype] || 0) + damage
	return TRUE
/mob/living/human/late_fixture/apply_effect(var/effect = FALSE, var/effecttype = STUN, var/blocked = FALSE, var/check_protection = TRUE)
	fixture_hurt[effecttype] = (fixture_hurt[effecttype] || 0) + effect
	return TRUE
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
/proc/late_test_field_work()
	// Every experiment is well formed.
	var/list/shares = list()
	var/formed = TRUE
	for(var/id in field_experiments)
		var/list/E = field_experiments[id]
		var/datum/research_node/N = get_research_node(E[1])
		if(!N || N.era_tier < 5 || !(E[2] in field_activities) || E[3] < 1 || E[4] <= 0 || !length(E[5]))
			formed = FALSE
			world.log << "FAIL: experiment [id] is malformed"
		shares[E[1]] = (shares[E[1]] || 0) + E[4]
	for(var/node_id in shares)
		if(shares[node_id] > 0.7)
			formed = FALSE
			world.log << "FAIL: field work covers too much of [node_id]"
	late_check(formed && field_experiments.len >= 20, "[field_experiments.len] experiments name late nodes, known activities and leave bench work to do")
	late_check(late_bench_rate(get_research_node("cartridge_ammo")) == 1.5 && late_bench_rate(get_research_node("rifling")) == 1, "late nodes are studied faster at the bench, earlier ones are not")
	var/mob/living/human/late_fixture/soldier = new(locate(3,2,1))
	soldier.name = "Brann"
	var/mob/living/human/late_fixture/doctor = new(locate(6,6,1))
	var/mob/living/human/late_fixture/patient = new(locate(6,7,1))
	var/mob/living/human/late_fixture/patient2 = new(locate(7,7,1))
	// Counting.
	late_check(note_field_work(soldier, "shots") && soldier.field_work_amount("shots") == 1, "a shot is counted on the character")
	note_field_work(soldier, "shots", 500)
	late_check(soldier.field_work_amount("shots") == field_activity_cap("shots") && !note_field_work(soldier, "shots"), "counting stops at the most any experiment needs ([field_activity_cap("shots")])")
	late_check(!note_field_work(soldier, "juggling") && !note_field_work(null, "shots"), "unknown activities and nobody count nothing")
	late_check(note_field_diagnosis(doctor, patient) && !note_field_diagnosis(doctor, patient) && note_field_diagnosis(doctor, patient2) && doctor.field_work_amount("diagnosis") == 2, "the same patient twice in a row is one diagnosis")
	late_check(!note_field_diagnosis(doctor, doctor), "diagnosing yourself is not field work")
	map.book_research = FALSE
	late_check(!note_field_work(doctor, "surgery") && doctor.field_work_amount("surgery") == 0, "nothing is counted where book research is off")
	map.book_research = TRUE
	// Crediting at a bench.
	var/obj/structure/research_bench/late_fixture/bench = new(locate(3,3,1))
	bench.tier = 8
	var/obj/item/weapon/book/journal = new(bench)
	journal.name = "journal"
	bench.assigned_node = "cartridge_ammo"
	var/datum/research_node/CN = get_research_node("cartridge_ammo")
	var/list/rows = bench.field_work_rows(soldier, "cartridge_ammo")
	late_check(rows.len == 1 && rows[1]["percent"] == 35 && !rows[1]["done"] && rows[1]["have"] == 30 && rows[1]["needed"] == 30, "the window lists the experiment and the viewer's own experience")
	soldier.stat = UNCONSCIOUS
	late_check(!bench.credit_field_work() && journal.research_ticks("cartridge_ammo") == 0, "an unconscious veteran reports nothing")
	soldier.stat = CONSCIOUS
	bench.book_analysis_tick()
	var/expected = round(CN.cost_ticks * 0.35)
	late_check(journal.research_ticks("cartridge_ammo") == expected && journal.has_field_work("cartridge_ammo_range"), "standing at the bench writes the field work into the book without any scholar ([expected] of [CN.cost_ticks] points)")
	bench.book_analysis_tick()
	late_check(journal.research_ticks("cartridge_ammo") == expected && !bench.credit_field_work(), "the same experiment is written into a book only once")
	rows = bench.field_work_rows(soldier, "cartridge_ammo")
	late_check(rows[1]["done"] == 1, "the window shows it is in the book")
	// Another book has not heard it yet.
	journal.loc = locate(1,1,1)
	var/obj/item/weapon/book/second = new(bench)
	late_check(bench.credit_field_work() && second.research_ticks("cartridge_ammo") == expected, "the same veteran can report to another book")
	// Too little experience, and far away.
	bench.assigned_node = "automatic_weapons"
	var/mob/living/human/late_fixture/recruit = new(locate(3,4,1))
	note_field_work(recruit, "shots", 50)
	soldier.loc = locate(8,8,1)
	late_check(!bench.credit_field_work() && second.research_ticks("automatic_weapons") == 0, "too little experience, or a veteran out of reach, adds nothing")
	// Field work can finish a chapter that is nearly done.
	soldier.loc = locate(3,2,1)
	var/datum/research_node/AN = get_research_node("automatic_weapons")
	second.add_research_work("automatic_weapons", AN.cost_ticks - 5)
	late_check(bench.credit_field_work() && second.has_research_chapter("automatic_weapons") && !second.has_field_work("automatic_weapons_range") && second.has_field_work("cartridge_ammo_range"), "field work finishes a nearly done chapter and is then forgotten for that subject only")
	late_check(!second.record_field_work("automatic_weapons_range"), "a finished chapter takes no more field work")
	// A dark bench does no bookkeeping at all.
	late_check(bench.field_work_rows(soldier, "basic_tools").len == 0, "early subjects have no field work")
// A scholar with the given levels who knows a subject's groundwork.
/mob/living/human/late_fixture/scholar/research_tool_rate()
	return 1
/mob/living/human/late_fixture/scholar/proc/prepare(node_id, discipline_level)
	var/datum/research_node/N = get_research_node(node_id)
	for(var/prereq in N.prereqs)
		teach(prereq)
	scholarship = list("mathematics" = 100)
	scholarship[node_discipline(node_id)] = discipline_level
/obj/structure/research_bench/late_fixture/has_research_instrument(node_id, mob/living/human/researcher = null)
	return TRUE
/proc/late_tick_gain(obj/structure/research_bench/bench, obj/item/weapon/book/B, node_id)
	var/before = B.research_ticks(node_id)
	bench.book_analysis_tick()
	return B.research_ticks(node_id) - before
/proc/late_test_teams()
	var/obj/structure/research_bench/late_fixture/bench = new(locate(5,5,1))
	bench.tier = 8
	var/obj/item/weapon/book/B = new(bench)
	var/mob/living/human/late_fixture/scholar/lead = new(locate(5,4,1))
	var/mob/living/human/late_fixture/scholar/second = new(locate(8,8,1))
	// An ordinary late subject: a second able scholar helps a little.
	lead.prepare("selfloading_firearms", 100)
	second.prepare("selfloading_firearms", 100)
	bench.assigned_node = "selfloading_firearms"
	late_check(lead.can_research_node_at(bench, "selfloading_firearms") && bench.team_rate("selfloading_firearms", lead) == 1 && !bench.team_rows("selfloading_firearms", lead).len, "a lone scholar works an ordinary late subject at the usual speed")
	var/alone = late_tick_gain(bench, B, "selfloading_firearms")
	second.loc = locate(6,5,1)
	late_check(bench.team_rate("selfloading_firearms", lead) == 1.25 && bench.team_rows("selfloading_firearms", lead).len == 1, "a second able scholar makes it a quarter faster")
	var/together = late_tick_gain(bench, B, "selfloading_firearms")
	late_check(alone > 0 && abs(together - alone * 1.25) <= 0.11, "the bench tick writes the faster pace into the book ([alone] alone, [together] together)")
	second.scholarship = list()
	late_check(bench.team_rate("selfloading_firearms", lead) == 1, "a bystander without the skill is no second scholar")
	// Early subjects are unchanged.
	lead.teach("basic_tools")
	second.prepare("iron_tools", 100)
	late_check(bench.team_rate("iron_tools", lead) == 1, "early subjects gain nothing from a second scholar")
	// Big science: a second discipline and a facility.
	lead.prepare("nuclear_power", 100)
	bench.assigned_node = "nuclear_power"
	second.scholarship = list("engineering" = big_science_assistant_level("nuclear_power") - 1)
	late_check(big_science_assistant_level("nuclear_power") == 42 && is_big_science("nuclear_power") && !is_big_science("automation"), "Nuclear Power is big science and wants Engineering 42 from its second scholar")
	late_check(bench.team_rate("nuclear_power", lead) == 0.125, "alone and without a laboratory, big science crawls at an eighth speed but still moves")
	var/crawl = late_tick_gain(bench, B, "nuclear_power")
	late_check(crawl > 0, "a lone scholar still makes progress on big science ([crawl] a tick)")
	second.scholarship = list("engineering" = 42)
	late_check(bench.team_rate("nuclear_power", lead) == 0.5 && bench.big_science_assistant("nuclear_power", lead) == second, "an engineer at the bench lifts the solo penalty")
	var/obj/structure/reaction_bench/lab = new(locate(7,7,1))
	late_check(bench.has_research_facility("nuclear_power") && bench.team_rate("nuclear_power", lead) == 1, "a laboratory within three tiles brings it to full speed")
	var/full = late_tick_gain(bench, B, "nuclear_power")
	late_check(abs(full - crawl * 8) <= 0.5, "full speed is eight times the crawl ([full] against [crawl])")
	var/list/rows = bench.team_rows("nuclear_power", lead)
	late_check(rows.len == 2 && rows[1]["ok"] && rows[2]["ok"] && findtext(rows[1]["label"], "Engineering 42") && findtext(rows[2]["label"], "laboratory"), "the window lists the second scholar and the facility")
	second.stat = UNCONSCIOUS
	lab.loc = locate(1,1,1)
	rows = bench.team_rows("nuclear_power", lead)
	late_check(bench.team_rate("nuclear_power", lead) == 0.125 && !rows[1]["ok"] && !rows[2]["ok"], "an unconscious assistant and a distant laboratory do not count")
	late_check(bench.big_science_assistant("nuclear_power", lead) != lead, "the lead cannot be their own second scholar")
	second.stat = CONSCIOUS
	for(var/node_id in big_science_nodes)
		var/list/need = big_science_nodes[node_id]
		late_check(get_research_node(node_id) && (need[1] in scholar_disciplines) && need[1] != node_discipline(node_id) && research_facilities[need[2]], "[node_id] names a real subject, another discipline and a facility")
	// --- Rushed research ---
	var/datum/research_node/NP = get_research_node("nuclear_power")
	late_check(!bench.rushed && bench.rush_rate(NP) == 1 && isnull(bench.roll_rush_accident(lead, NP, B)), "careful work is the default and has no accidents")
	late_check(bench.book_toggle_rush(lead) && bench.rushed && bench.rush_rate(NP) == 1.5, "rushing makes a late subject half again as fast")
	late_check(bench.rush_rate(get_research_node("iron_tools")) == 1 && isnull(bench.roll_rush_accident(lead, get_research_node("iron_tools"), B)), "early subjects cannot be rushed")
	second.loc = locate(8,8,1)
	late_check(!bench.book_toggle_rush(second) && bench.rushed, "nobody toggles rushing from across the room")
	lead.scholarship["natural_science"] = node_scholar_requirement("nuclear_power")
	late_check(rush_accident_chance(lead, "nuclear_power") == 1, "at the bare requirement an accident is a 1% chance each interval")
	lead.scholarship["natural_science"] = 100
	lead.scholarship["military"] = node_scholar_requirement("cartridge_ammo") + 40
	late_check(rush_accident_chance(lead, "cartridge_ammo") == 0.2 && rush_accident_chance(null, "cartridge_ammo") == 0, "forty levels of spare skill cut the chance to a fifth")
	late_check(rush_accident_kind("nuclear_power") == "radiation" && rush_accident_kind("rocketry") == "blast" && rush_accident_kind("modern_medicine") == "poison" && rush_accident_kind("power_tools") == "injury" && rush_accident_kind("digital_computing") == "error", "accidents fit their subject")
	// A mathematical error costs work, not blood.
	var/datum/research_node/DC = get_research_node("digital_computing")
	var/half = round(DC.cost_ticks / 2)
	B.add_research_work("digital_computing", half)
	lead.fixture_hurt = list()
	var/kind = bench.research_accident(lead, DC, B)
	late_check(kind == "error" && !lead.fixture_hurt.len && B.research_ticks("digital_computing") == half - round(DC.cost_ticks * 0.1), "an error hurts nobody and throws out a tenth of the subject ([B.research_ticks("digital_computing")] of [half] left)")
	late_check(B.lose_research_work("digital_computing", 100000) > 0 && B.research_ticks("digital_computing") == 0 && B.lose_research_work("digital_computing", 5) == 0, "lost work never goes below nothing")
	var/datum/research_node/MM = get_research_node("modern_medicine")
	half = round(MM.cost_ticks / 2)
	B.add_research_work("modern_medicine", half)
	kind = bench.research_accident(lead, MM, B)
	late_check(kind == "poison" && lead.fixture_hurt[TOX] >= 8 && B.research_ticks("modern_medicine") == half - round(MM.cost_ticks * 0.05), "a bad drug trial poisons the researcher and undoes a twentieth")
	second.loc = locate(6,5,1)
	second.fixture_hurt = list()
	lead.fixture_hurt = list()
	kind = bench.research_accident(lead, get_research_node("rocketry"), B)
	late_check(kind == "blast" && lead.fixture_hurt[BURN] >= 10 && second.fixture_hurt[BURN] >= 5 && second.fixture_hurt[BURN] <= 10, "a blast burns the researcher and, less, whoever stands beside the bench")
	kind = bench.research_accident(lead, NP, B)
	late_check(kind == "radiation" && lead.fixture_hurt[IRRADIATE] == 25 && second.fixture_hurt[IRRADIATE] == 25, "a reactor accident irradiates the room")
	kind = bench.research_accident(lead, get_research_node("power_tools"), B)
	late_check(kind == "injury" && lead.fixture_hurt[BRUTE] >= 8, "a slipped build crushes a hand")
	bench.book_toggle_rush(lead)
	late_check(!bench.rushed, "the bench can be told to work carefully again")
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
		late_test_field_work()
		late_test_teams()
	catch(var/exception/e)
		late_failures++
		world.log << "FAIL: exception [e] [e.file]:[e.line]"
	var/list/params = islist(world.params) ? world.params : params2list(world.params)
	text2file(json_encode(list("failures" = late_failures, "commit" = params["tested_commit"], "byond_build" = world.byond_build)), "result.json")
	shutdown()
