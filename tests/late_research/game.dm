// Late research on book-research worlds, on production source: standing node
// effects, field work, research teams, rushed work,
// ciphers and the extended Health, Agriculture and Military lines. Client presence, light and action waits are isolated.
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
	var/mob/living/human/late_fixture/farmer = new(locate(4,2,1))
	farmer.teach("advanced_agriculture")
	late_check(farming_node_bonus(farmer) == 0.25 && farming_node_bonus(novice) == 0, "Advanced Agriculture adds a quarter to the harvest")
	late_check(farming_node_bonus(H) == 0.5, "Crop Breeding adds a further quarter on top")
	late_check(harvest_skill_user_bonus(H, "farming") - harvest_skill_user_bonus(novice, "farming") == 0.5 && harvest_skill_user_bonus(H, "hunting") == harvest_skill_user_bonus(novice, "hunting"), "the harvest bonus reaches farming and not hunting")
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
/turf/floor/dirt/late_fixture/New()
	return
/proc/late_test_late_lines()
	var/mob/living/human/late_fixture/H = new(locate(3,3,1))
	var/mob/living/human/late_fixture/novice = new(locate(5,3,1))
	var/list/ends = list("Health" = 0, "Agriculture" = 0, "Military" = 0)
	for(var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		if(N.category in ends)
			ends[N.category] = max(ends[N.category], N.era_tier)
	late_check(ends["Health"] >= 8 && ends["Agriculture"] >= 8 && ends["Military"] >= 8, "Health, Agriculture and Military all reach era 8 or later ([ends["Health"]], [ends["Agriculture"]], [ends["Military"]])")
	for(var/node_id in book_only_research_nodes)
		var/datum/research_node/N = get_research_node(node_id)
		late_check(N && N.book_only && N.era_tier >= 7 && N.mode == RESEARCH_MODE_ANALYSIS, "[node_id] is a late book-only subject and no era capstone")
		var/prereqs_ok = N && length(N.prereqs)
		for(var/prereq in N?.prereqs)
			var/datum/research_node/P = get_research_node(prereq)
			if(!P || P.era_tier > N.era_tier)
				prereqs_ok = FALSE
		late_check(prereqs_ok, "[node_id] follows from earlier subjects")
		late_check(length(get_node_recipe_paths(node_id)) || length(research_node_effect_text(node_id)), "[node_id] unlocks recipes or carries a standing effect")
		var/has_field_work = FALSE
		for(var/id in field_experiments)
			var/list/E = field_experiments[id]
			if(E[1] == node_id)
				has_field_work = TRUE
		late_check(has_field_work, "[node_id] can be advanced by field work")
		late_check(!research_node_dormant(N), "[node_id] is live on a book-research world")
	// What the new subjects unlock, for the character who knows them only.
	var/list/unlocks = list(
		"/obj/item/weapon/defibrillator/loaded" = "emergency_medicine",
		"/obj/item/weapon/cell/standard" = "emergency_medicine",
		"/obj/item/weapon/reagent_containers/syringe/autoinjector" = "emergency_medicine",
		"/obj/item/bodybag" = "emergency_medicine",
		"/obj/item/weapon/foldable/generic" = "support_weapons",
		"/obj/item/cannon_ball/mortar_shell" = "support_weapons",
		"/obj/item/cannon_ball/mortar_shell/smoke" = "support_weapons",
		"/obj/item/weapon/flamethrower" = "support_weapons",
		"/obj/item/weapon/reagent_containers/glass/flamethrower" = "support_weapons",
		"/obj/item/mine/ap" = "support_weapons",
		"/obj/item/mine/at" = "support_weapons",
		"/obj/item/weapon/foldable/atgm" = "guided_weapons",
		"/obj/item/ammo_casing/rocket/atgm" = "guided_weapons",
		"/obj/item/ammo_casing/rocket/atgm/he" = "guided_weapons")
	for(var/path in unlocks)
		late_check(ispath(text2path(path)) && get_recipe_node_req(path) == unlocks[path], "[path] is gated on [unlocks[path]]")
		late_check(!crafting_recipe_allowed(novice, path), "[path] cannot be made without the chapter")
	for(var/node_id in book_only_research_nodes)
		H.teach(node_id)
	var/all_allowed = TRUE
	for(var/path in unlocks)
		if(!crafting_recipe_allowed(H, path))
			all_allowed = FALSE
	late_check(all_allowed, "a character who studied the chapters can make everything they unlock")
	// What the defibrillator recipe gives is ready to use, and the pen starts empty.
	var/obj/item/weapon/defibrillator/loaded/defib = new(locate(1,1,1))
	late_check(istype(defib.bcell) && defib.bcell.check_charge(100), "a crafted defibrillator comes with a charged cell")
	var/obj/item/weapon/reagent_containers/syringe/autoinjector/pen = new(locate(1,1,1))
	late_check(pen.reagents && pen.reagents.total_volume == 0 && pen.single_use, "a crafted autoinjector is empty and works once")
	var/obj/item/weapon/reagent_containers/glass/flamethrower/tank = new(locate(1,1,1))
	late_check(tank.reagents && tank.reagents.total_volume == 0 && tank.volume == 100, "a crafted flamethrower backpack starts empty and holds 100 units of fuel")
	var/obj/item/mine/ap/mine = new(locate(1,1,1))
	late_check(!mine.anchored && !mine.triggered, "a crafted mine is not armed until someone deploys it")
	// Soil Science: a harvest feeds the plot, up to its limit.
	var/turf/floor/dirt/late_fixture/plot = new(locate(7,7,1))
	plot.soil_nutrition = 60
	late_check(!soil_node_return(novice, plot) && plot.soil_nutrition == 60, "an ordinary farmer's harvest leaves the soil as it was")
	late_check(soil_node_return(H, plot) && plot.soil_nutrition == 90, "Soil Science returns nutrition to the plot at harvest")
	plot.soil_nutrition = plot.max_soil_nutrition - 5
	soil_node_return(H, plot)
	late_check(plot.soil_nutrition == plot.max_soil_nutrition && !soil_node_return(H, locate(1,1,1)), "the soil never goes over its limit, and only farm soil gains")
	// Harvests are field work.
	late_check(note_field_work(H, "harvests", 3) && H.field_work_amount("harvests") == 3, "harvests count as field work")
	// Off book-research worlds the subjects do not exist for play.
	map.book_research = FALSE
	var/old_age = map.ordinal_age
	map.ordinal_age = 9
	var/dormant = TRUE
	for(var/node_id in book_only_research_nodes)
		if(!research_node_dormant(get_research_node(node_id)) || map.is_node_done("none", node_id) || map.is_node_done("Testers", node_id))
			dormant = FALSE
	late_check(dormant, "off book-research worlds the new subjects are never done, whatever the era")
	late_check(!research_node_dormant(get_research_node("modern_medicine")) && map.is_node_done("none", "modern_medicine"), "older subjects are untouched there")
	late_check(!crafting_recipe_allowed(H, "/obj/item/weapon/defibrillator/loaded") && !soil_node_return(H, plot), "and they unlock nothing there")
	map.ordinal_age = old_age
	map.book_research = TRUE
/proc/late_test_field_work()
	build_practice_experiments()
	// Every experiment is well formed. Late ones use a named activity; early
	// ones may also be practice, counted per prerequisite (practice_work.dm).
	var/list/shares = list()
	var/formed = TRUE
	for(var/id in field_experiments)
		var/list/E = field_experiments[id]
		var/datum/research_node/N = get_research_node(E[1])
		var/practice = findtext(E[2], "craft:") == 1 || findtext(E[2], "deed:") == 1
		if(!N || (practice && N.era_tier >= 5) || (!practice && !(E[2] in field_activities)) || E[3] < 1 || E[4] <= 0 || !length(E[5]))
			formed = FALSE
			world.log << "FAIL: experiment [id] is malformed"
		shares[E[1]] = (shares[E[1]] || 0) + E[4]
	for(var/node_id in shares)
		if(shares[node_id] > 0.7)
			formed = FALSE
			world.log << "FAIL: field work covers too much of [node_id]"
	late_check(formed && field_experiments.len >= 20, "[field_experiments.len] experiments name real nodes, known activities and leave bench work to do")
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
	late_check(bench.field_work_rows(soldier, "ritual_worship").len == 0, "a subject without experiments lists none")

// Working demonstrations for late capstones (demonstrations.dm).
/proc/late_test_demonstrations()
	for(var/node_id in capstone_demonstrations)
		var/datum/research_node/N = get_research_node(node_id)
		late_check(N && N.mode == RESEARCH_MODE_PROTOTYPE && node_needs_demonstration(node_id) && findtext(prototype_need_label(N), "demonstration"), "[node_id] is a capstone that needs a demonstration")
	late_check(!node_needs_demonstration("printing_currency") && findtext(prototype_need_label(get_research_node("printing_currency")), "used on the bench"), "other capstones keep their prototype")
	late_check(!node_needs_demonstration("mechanized_war") && findtext(prototype_need_label(get_research_node("mechanized_war")), "bill of materials"), "the World War II capstones take a bill instead of a prototype")
	// No demonstration may need something its own subject (or a later one)
	// unlocks, unless an experimental build covers it (Val, 2026-11-18).
	// Proven failing first: dropping the kit list fails steam_power and electricity.
	for (var/node_id in capstone_demonstrations)
		var/list/D = capstone_demonstrations[node_id]
		var/list/needs = D.len >= 4 ? D[4] : null
		late_check(islist(needs) && needs.len, "[node_id] lists what its demonstration needs built")
		var/list/earlier = late_research_ancestors(node_id)
		for (var/needed in needs)
			var/req = get_recipe_node_req("[needed]")
			// An experimental build is allowed whatever subject normally gates it.
			var/ok = !req || (req in earlier) || (needed in D[3])
			late_check(ok, "[node_id]'s demonstration can get [needed] (needs [req ? req : "nothing"]) before [node_id] is learned")
	late_check(findtext(prototype_need_label(get_research_node("steam_power")), "experimental steam engine"), "the steam power demonstration says how to build the engine")
	map.book_research = FALSE
	late_check(!node_needs_demonstration("steam_power"), "only book-research worlds need demonstrations")
	map.book_research = TRUE
	// Is it running?
	var/obj/structure/engine/external/steam/engine = new(locate(2,6,1))
	late_check(!demonstration_machine_running("steam_power", engine), "a cold engine demonstrates nothing")
	engine.on = TRUE
	late_check(demonstration_machine_running("steam_power", engine), "a running steam engine demonstrates Steam Power")
	late_check(!demonstration_machine_running("electricity", engine), "an engine is not an electric lamp")
	var/obj/item/weapon/telephone/mobile/phone = new(locate(2,7,1))
	phone.wireless = TRUE
	late_check(!demonstration_machine_running("digital_networks", phone), "an idle phone demonstrates nothing")
	phone.connected = 1234
	late_check(demonstration_machine_running("digital_networks", phone), "a connected mobile call demonstrates Digital Networks")
	// The recorder.
	var/mob/living/human/late_fixture/watcher = new(locate(2,5,1))
	watcher.name = "Ilse"
	watcher.teach("watermills")
	watcher.teach("iron_smithing")
	var/list/seen = demonstrations_in_view(watcher)
	late_check(seen.len == 1 && seen["steam_power"] == engine, "someone who knows the groundwork sees the steam engine demonstration")
	late_check(find_demonstration_machine(watcher, "steam_power") == engine, "the running engine is found within reach")
	// Experimental builds need a half-written chapter on the builder.
	var/datum/research_node/SN = get_research_node("steam_power")
	late_check(!demonstration_kit_allowed(watcher, "/obj/structure/engine/external/steam") && !crafting_recipe_allowed(watcher, "/obj/structure/engine/external/steam"), "no book, no experimental engine")
	var/obj/item/weapon/book/draft = new(watcher)
	draft.add_research_work("steam_power", round(SN.cost_ticks * 0.4))
	late_check(!demonstration_kit_allowed(watcher, "/obj/structure/engine/external/steam"), "less than half a chapter is not enough")
	draft.add_research_work("steam_power", SN.cost_ticks)
	late_check(!draft.has_research_chapter("steam_power"), "study alone does not finish the capstone")
	late_check(demonstration_kit_allowed(watcher, "/obj/structure/engine/external/steam") && crafting_recipe_allowed(watcher, "/obj/structure/engine/external/steam"), "half a chapter on you lets you build an experimental engine")
	late_check(!demonstration_kit_allowed(watcher, "/obj/structure/lamp/lamp_small"), "but not another capstone's machine")
	var/obj/structure/engine/external/steam/crude = new(locate(4,6,1))
	late_check(mark_experimental_build(watcher, crude, "/obj/structure/engine/external/steam") && crude.experimental_node == "steam_power" && findtext(crude.name, "experimental") == 1, "the build is marked experimental")
	late_check(!mark_experimental_build(watcher, engine, "/obj/structure/lamp/lamp_small") && !engine.experimental_node, "an ordinary build stays ordinary")
	// Experimental machines fail now and then during a demonstration.
	crude.on = TRUE
	var/failed = FALSE
	for(var/i = 1 to 500)
		if(demonstration_mishap(crude, "steam_power"))
			failed = TRUE
			break
	late_check(failed && QDELETED(crude), "an experimental engine can burst during a demonstration")
	late_check(!demonstration_mishap(engine, "steam_power"), "a proper engine never fails that way")
	// Recording onto paper, then at the bench.
	var/obj/item/weapon/paper/sheet = new(watcher)
	late_check(demonstration_carrier_ok(sheet, "steam_power") && commit_demonstration(watcher, sheet, "steam_power") && sheet.demonstration_node == "steam_power", "a sheet of paper takes the demonstration notes")
	late_check(!demonstration_carrier_ok(sheet, "steam_power"), "one demonstration per sheet")
	var/obj/item/weapon/paper/parchment/skin = new(watcher)
	late_check(demonstration_carrier_ok(skin, "electricity"), "parchment works too")
	var/obj/item/weapon/paper/research_page/page = new(watcher)
	late_check(!demonstration_carrier_ok(page, "steam_power"), "a torn-out chapter page is not a notebook")
	var/obj/structure/research_bench/late_fixture/bench = new(locate(6,6,1))
	bench.tier = 8
	draft.loc = bench
	bench.assigned_node = "steam_power"
	watcher.r_hand = sheet
	late_check(bench.take_demonstration_notes(sheet, watcher) && !draft.has_research_chapter("steam_power") && draft.research_prototype_installed("steam_power") && QDELETED(sheet), "the notes used on the bench are recorded while the bill is unpaid")
	late_pay_bill(bench, watcher, draft, "steam_power")
	late_check(draft.has_research_chapter("steam_power"), "paying the bill finishes the studied and demonstrated chapter")
	// Recording straight into a book.
	var/obj/item/weapon/book/journal = new(watcher)
	late_check(commit_demonstration(watcher, journal, "electricity") && journal.research_prototype_installed("electricity") && !journal.has_research_chapter("electricity"), "a book takes the demonstration straight away and waits for the study")
	late_check(!demonstration_carrier_ok(journal, "electricity"), "a book holds one demonstration of a subject")
	qdel(bench)

// Delivers node_id's whole bill to bench as stacks held by H.
/proc/late_pay_bill(obj/structure/research_bench/bench, mob/living/human/H, obj/item/weapon/book/B, node_id)
	var/list/bill = node_bill(node_id)
	var/datum/research_node/N = get_research_node(node_id)
	for (var/key in bill)
		var/list/M = bill_materials()[key]
		var/stype = M[2]
		var/obj/item/stack/S = new stype(H)
		S.amount = bill[key]
		bench.take_bill_delivery(S, H, B, N)

// Era bills for late capstones (era_bills.dm).
/proc/late_test_era_bills()
	var/list/bills = capstone_bills()
	for (var/node_id in bills)
		var/datum/research_node/N = get_research_node(node_id)
		late_check(N && N.mode == RESEARCH_MODE_PROTOTYPE && N.era_tier >= 4, "[node_id] is an Industrial or later capstone with a bill")
		var/list/earlier = late_research_ancestors(node_id)
		var/list/bill = bills[node_id]
		for (var/key in bill)
			var/list/M = bill_materials()[key]
			late_check(islist(M) && ispath(M[2], /obj/item/stack) && isnum(bill[key]) && bill[key] > 0, "[node_id] bills a real stack of [key]")
			var/req = M ? get_recipe_node_req("[M[2]]") : null
			late_check(!req || (req in earlier), "[node_id]'s [key] comes from an earlier subject (needs [req ? req : "nothing"])")
	late_check(!node_has_bill("printing_currency") && !node_has_bill("gunpowder") && !node_has_bill("iron_smithing"), "Medieval and Imperial capstones have no bill")
	late_check(!capstone_bill_replaces_prototype("steam_power") && capstone_bill_replaces_prototype("powered_flight") && capstone_bill_replaces_prototype("mechanized_war"), "only the capstones without a demonstration take the bill as their prototype")
	map.book_research = FALSE
	var/obj/item/weapon/book/plain = new(locate(1,1,1))
	late_check(!node_bill("steam_power") && plain.bill_complete("steam_power"), "bills apply only on book-research worlds")
	map.book_research = TRUE
	// The saved record keeps only sane entries, capped at the bill.
	plain.research_bills = "steam_power=coal:12,gold:5,iron:abc,copper:999;bogus=coal:3;mechanized_war"
	var/list/M = plain.research_bill_map()
	late_check(M.len == 1 && M["steam_power"]["coal"] == 12 && M["steam_power"]["copper"] == 10 && !("gold" in M["steam_power"]) && !("iron" in M["steam_power"]), "a damaged bill record is cleaned, never trusted")
	plain.research_bills = ""
	late_check(plain.deliver_bill("steam_power", "coal", 25) == 25 && plain.deliver_bill("steam_power", "coal", 50) == 35 && plain.deliver_bill("steam_power", "coal", 5) == 0, "a bill takes only what it still needs")
	late_check(plain.bill_left("steam_power")["iron"] == 40 && !("coal" in plain.bill_left("steam_power")), "what is left is counted per material")
	late_check(!plain.monk_copy_source_allowed() && !plain.monk_copy_blank(), "a book with deliveries is not a blank or a copy source")
	// World War II: the old part is refused, the bill stands in for it.
	var/datum/research_node/MW = get_research_node("mechanized_war")
	var/mob/living/human/late_fixture/smith = new(locate(5,5,1))
	smith.teach("field_artillery")
	smith.teach("combustion")
	smith.teach("steelmaking")
	var/obj/item/weapon/book/war = new(locate(1,1,1))
	war.add_research_work("mechanized_war", MW.cost_ticks)
	late_check(!war.has_research_chapter("mechanized_war"), "full study alone does not finish Mechanized Warfare")
	var/obj/structure/research_bench/late_fixture/bench = new(locate(6,6,1))
	bench.tier = 8
	war.loc = bench
	bench.assigned_node = "mechanized_war"
	var/obj/item/stack/ammopart/casing/tank/casing = new(smith)
	smith.r_hand = casing
	bench.attackby(casing, smith)
	late_check(!QDELETED(casing) && !war.research_prototype_installed("mechanized_war"), "a tank shell casing no longer counts as its prototype")
	var/obj/item/stack/material/steel/steel = new(smith)
	steel.amount = 50
	late_check(bench.take_bill_delivery(steel, smith, war, MW) && QDELETED(steel) && war.bill_delivered("mechanized_war", "steel") == 50, "anyone at the bench can deliver toward the bill")
	var/obj/item/stack/material/wood/wood = new(smith)
	late_check(!bench.take_bill_delivery(wood, smith, war, MW), "something off the bill is not taken for it")
	late_pay_bill(bench, smith, war, "mechanized_war")
	late_check(war.has_research_chapter("mechanized_war") && !length(war.research_bills), "the paid bill finishes the chapter and clears its record")
	qdel(bench)

// Prototypes and field study (subject_prototypes.dm).
/proc/late_test_subject_prototypes()
	var/item_path = null
	for(var/path in recipe_node_requirements)
		if(recipe_node_requirements[path] == "iron_tools" && ispath(text2path(path), /obj/item/weapon))
			item_path = path
			break
	late_check(item_path, "Iron Tools has something to make ([item_path])")
	var/datum/research_node/IN = get_research_node("iron_tools")
	var/mob/living/human/late_fixture/maker = new(locate(7,2,1))
	maker.name = "Wulf"
	maker.teach("basic_tools")
	maker.teach("iron_smithing")
	late_check(!subject_prototype_allowed(maker, item_path) && !crafting_recipe_allowed(maker, item_path), "no book, no prototypes")
	late_check(findtext(subject_prototype_refusal(maker, item_path), "a third of it written") && !subject_in_carried_book(maker, "iron_tools"), "without a book the refusal says a third of the chapter is needed")
	var/obj/item/weapon/book/notebook = new(maker)
	notebook.add_research_work("iron_tools", round(IN.cost_ticks * 0.2))
	late_check(!subject_prototype_allowed(maker, item_path), "a fifth of the chapter is too little")
	late_check(findtext(subject_prototype_refusal(maker, item_path), "points of <b>[IN.name]</b> needed"), "a fifth of the chapter: the refusal names the points still needed")
	notebook.add_research_work("iron_tools", round(IN.cost_ticks * 0.2))
	late_check(subject_prototype_allowed(maker, item_path) && crafting_recipe_allowed(maker, item_path), "a third of the chapter lets you make its things as prototypes")
	late_check(reference_build_mult(maker, item_path) == 2, "the first piece made from a book takes twice as long")
	var/before = notebook.research_ticks("iron_tools")
	var/points = record_subject_prototype(maker, item_path)
	late_check(points == round(IN.cost_ticks * 0.08) && notebook.research_ticks("iron_tools") == before + points && notebook.prototypes_made("iron_tools") == 1, "a prototype writes [points] points into the book")
	for(var/i = 2 to 5)
		record_subject_prototype(maker, item_path)
	late_check(notebook.prototypes_made("iron_tools") == 5 && subject_prototype_allowed(maker, item_path) && crafting_recipe_allowed(maker, item_path), "after five prototypes the book is still a reference, with no limit on uses")
	before = notebook.research_ticks("iron_tools")
	late_check(!record_subject_prototype(maker, item_path) && notebook.research_ticks("iron_tools") == before && notebook.prototypes_made("iron_tools") == 5, "only five prototypes per book write research")
	late_check(reference_build_mult(maker, item_path) == 1.5 && !subject_prototype_refusal(maker, item_path), "practice from the book brings the wait down to 1.5 times, and nothing is refused")
	maker.teach("iron_tools")
	late_check(reference_build_mult(maker, item_path) == 1, "learning the subject brings building back to full speed")
	maker.known_recipe_nodes -= "iron_tools"
	var/mob/living/human/late_fixture/stranger = new(locate(7,3,1))
	late_check(!subject_prototype_allowed(stranger, item_path), "without the groundwork you can't make prototypes")
	late_check(findtext(subject_prototype_refusal(stranger, item_path), "until you know"), "without the groundwork the refusal names the missing subjects")
	// White pelt fur coats are Furriery like every other fur coat; only the woven wool coat is Fine Garments.
	late_check(get_recipe_node_req("/obj/item/clothing/suit/storage/coat/fur/white") == "furriery" && get_recipe_node_req("/obj/item/clothing/suit/storage/coat/fur/white/wool") == "fine_garments", "white fur coats need Furriery, wool coats Fine Garments")
	// Field study.
	var/tool_path = text2path(item_path)
	var/obj/item/weapon/tool = new tool_path(locate(7,1,1))
	var/list/targets = field_study_targets(maker)
	late_check(targets[tool] == "iron_tools", "a nearby [tool] can be studied for Iron Tools")
	late_check(!field_study_targets(stranger)[tool], "not by someone who lacks the groundwork")
	var/obj/item/weapon/book/fresh = new(maker)
	var/kind = "[tool.type]"
	var/got = commit_field_study(maker, fresh, "iron_tools", kind, tool.name)
	late_check(got == round(IN.cost_ticks * 0.1) && fresh.research_ticks("iron_tools") == got, "studying it writes [got] points into a book")
	late_check(!field_study_carrier_ok(fresh, "iron_tools", kind) && !commit_field_study(maker, fresh, "iron_tools", kind, tool.name), "each kind of thing once per book")
	fresh.record_field_study("iron_tools", "/obj/a")
	fresh.record_field_study("iron_tools", "/obj/b")
	late_check(!fresh.can_take_field_study("iron_tools", "/obj/c") && fresh.field_study_count("iron_tools") == 3, "three kinds per subject per book")
	var/obj/item/weapon/paper/sheet = new(maker)
	late_check(commit_field_study(maker, sheet, "iron_tools", kind, tool.name) && sheet.field_study_node == "iron_tools", "paper takes field notes")
	late_check(!field_study_carrier_ok(sheet, "iron_tools", "/obj/a"), "one study per sheet")
	var/obj/structure/research_bench/late_fixture/bench = new(locate(6,2,1))
	bench.tier = 8
	var/obj/item/weapon/book/target = new(bench)
	bench.assigned_node = "iron_tools"
	maker.r_hand = sheet
	late_check(bench.take_field_notes(sheet, maker) && target.research_ticks("iron_tools") == got && QDELETED(sheet), "field notes used on the bench go into its book")
	map.book_research = FALSE
	late_check(!subject_prototype_allowed(maker, item_path) && !field_study_targets(maker).len, "only on book-research worlds")
	map.book_research = TRUE
	qdel(bench)

// Practice and gathering for early nodes (practice_work.dm).
/proc/late_test_practice_work()
	// Every real subject below the late tiers has hand-written deeds, so the
	// generated practice is checked on two subjects made up for this test.
	register_research_node(new /datum/research_node("test_practice_one", "Test Practice One", "General", 130, 0, RESEARCH_MODE_ANALYSIS, list("iron_smithing"), 4))
	register_research_node(new /datum/research_node("test_practice_two", "Test Practice Two", "General", 200, 0, RESEARCH_MODE_ANALYSIS, list("brickmaking", "steelmaking"), 4))
	practice_experiments_built = FALSE
	build_practice_experiments()
	var/list/iron = node_field_experiments("test_practice_one")
	late_check(iron.len == 1 && iron[1] == "practice_test_practice_one_iron_smithing", "a subject without deeds is advanced by practising its groundwork")
	var/list/E = field_experiments["practice_test_practice_one_iron_smithing"]
	var/datum/research_node/IN = get_research_node("test_practice_one")
	late_check(E[2] == "craft:iron_smithing" && E[3] == practice_items_needed(IN) && E[4] == 0.5, "the experiment asks for [E[3]] things for half the node")
	var/list/concrete = node_field_experiments("test_practice_two")
	late_check(concrete.len == 2 && field_experiments[concrete[1]][4] == 0.25, "two prerequisites split the practice share")
	late_check(!node_field_experiments("power_tools").len, "late nodes keep only their own field work")
	late_check(node_field_experiments("basic_tools").len == 1 && node_field_experiments("archery").len == 1, "first nodes advance by foraging or butchering")
	// Making something counts towards the node its recipe belongs to.
	var/craft_path = null
	for(var/path in recipe_node_requirements)
		if(recipe_node_requirements[path] == "iron_smithing")
			craft_path = path
			break
	var/mob/living/human/late_fixture/smith = new(locate(4,2,1))
	smith.name = "Odda"
	late_check(craft_path && note_craft_practice(smith, craft_path) && smith.field_work_amount("craft:iron_smithing") == 1, "making [craft_path] is practice in Iron Smithing")
	late_check(!note_craft_practice(smith, "/obj/item/not_a_recipe") && !note_craft_practice(smith, null), "unknown things count nothing")
	map.book_research = FALSE
	late_check(!note_craft_practice(smith, craft_path) && smith.field_work_amount("craft:iron_smithing") == 1, "nothing is counted where book research is off")
	map.book_research = TRUE
	late_check(note_field_work(smith, "forage", 3) && smith.field_work_amount("forage") == 3, "foraging is counted")
	// Credited at a bench once enough has been made.
	note_field_work(smith, "craft:iron_smithing", 50)
	var/obj/structure/research_bench/late_fixture/bench = new(locate(4,3,1))
	bench.tier = 8
	var/obj/item/weapon/book/notes = new(bench)
	bench.assigned_node = "test_practice_one"
	// The fixture has no craft lists, so name ten Iron Smithing recipes by hand.
	var/list/saved_names = recipe_names_by_node
	recipe_names_by_node = list("iron_smithing" = list("r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10"))
	var/list/rows = bench.field_work_rows(smith, "test_practice_one")
	recipe_names_by_node = saved_names
	late_check(rows.len == 1 && rows[1]["percent"] == 50 && rows[1]["have"] == E[3], "the bench lists the practice and the smith's own count")
	var/list/examples = rows[1]["examples"]
	late_check(islist(examples) && examples.len == 9 && examples[1] == "r1" && examples[9] == "2 more", "the practice row names eight things that count and how many more")
	var/list/pace = bench.book_pace_factors(IN, smith, 1, 0, 1.2)
	late_check(pace.len >= 4 && pace[3]["effect"] == "half speed until some are set out" && !pace[3]["ok"] && pace[4]["effect"] == "20% faster", "the bench names what sets its speed: no supplies is half speed, a library is a bonus")
	pace = bench.book_pace_factors(IN, smith, 1, 5, 1)
	late_check(pace[3]["effect"] == "full speed" && pace[3]["ok"], "supplies are full speed, never a bonus")
	var/expected = round(IN.cost_ticks * 0.5)
	late_check(bench.credit_field_work() && notes.research_ticks("test_practice_one") == expected && !bench.credit_field_work(), "the practice is written into the book once ([expected] of [IN.cost_ticks] points)")
	qdel(bench)
	for(var/id in list("test_practice_one", "test_practice_two"))
		for(var/exp in node_field_experiments(id))
			field_experiments -= exp
		research_nodes -= id
	field_activity_caps = null
// Hand-written deeds for the first ages (practice_work.dm).
/proc/late_test_subject_deeds()
	build_practice_experiments()
	var/sound = TRUE
	for(var/node_id in subject_deeds)
		var/datum/research_node/N = get_research_node(node_id)
		var/total = 0
		if(!N || N.era_tier > 4 || !N.prereqs.len)
			sound = FALSE
			world.log << "bad deed subject [node_id]"
			continue
		for(var/list/D in subject_deeds[node_id])
			total += D[4]
			var/list/groundwork = late_research_ancestors(node_id)
			for(var/path in D[2])
				// Every deed must be something the groundwork (or its own
				// groundwork, which a scholar of it must know) teaches, or anyone can make.
				var/req = recipe_node_requirements[path]
				if(!ispath(text2path(path)) || (req && !(req in groundwork)))
					sound = FALSE
					world.log << "bad deed path [path] for [node_id] (taught by [req])"
		if(abs(total - 0.5) > 0.001)
			sound = FALSE
			world.log << "deeds of [node_id] add up to [total]"
		for(var/id in node_field_experiments(node_id))
			if(findtext(id, "practice_") == 1)
				sound = FALSE
				world.log << "[node_id] still has a practice counter [id]"
	if(subject_deeds.len != 57)
		world.log << "subject_deeds has [subject_deeds.len] subjects"
	late_check(sound && subject_deeds.len == 57, "every subject of era tiers 0 to 4 has deeds its groundwork teaches, worth half the chapter, and no counter")
	var/list/coop = node_field_experiments("cooperage")
	late_check(coop.len == 3 && ("deed_cooperage_handles" in coop), "Cooperage asks for three deeds")
	var/mob/living/human/late_fixture/cooper = new(locate(4,6,1))
	cooper.name = "Hild"
	late_check(note_craft_practice(cooper, "/obj/item/weapon/material/handle") && cooper.field_work_amount("deed:cooperage:handles") == 1, "making a handle counts towards its deed")
	late_check(note_craft_practice(cooper, "/obj/item/weapon/material/handle/subtype_for_test") && cooper.field_work_amount("deed:cooperage:handles") == 2 && !note_deed_work(cooper, "/obj/item/weapon/material/handlebar"), "a kind of handle counts too, a lookalike name does not")
	note_craft_practice(cooper, "/obj/item/weapon/material/handle")
	late_check(cooper.field_work_amount("deed:cooperage:handles") == 2, "counting stops at what the deed asks")
	note_craft_practice(cooper, "/obj/structure/furnace/kiln")
	late_check(cooper.field_work_amount("deed:early_cells:kiln") == 1 && cooper.field_work_amount("deed:bronze_weapons:kiln") == 1, "one kiln serves both subjects that ask for it")
	var/obj/structure/research_bench/late_fixture/bench = new(locate(4,7,1))
	bench.tier = 8
	var/obj/item/weapon/book/notes = new(bench)
	bench.assigned_node = "cooperage"
	var/datum/research_node/CN = get_research_node("cooperage")
	var/list/rows = bench.field_work_rows(cooper, "cooperage")
	late_check(rows.len == 3 && rows[1]["label"] == "Make 2 tool handles" && rows[1]["have"] == 2, "the bench lists the deeds by name")
	late_check(bench.credit_field_work() && notes.research_ticks("cooperage") == round(CN.cost_ticks * 0.2) && !bench.credit_field_work(), "a finished deed is written into the book once")
	qdel(bench)
	cooper.loc = locate(1,1,1)
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
/mob/living/human/late_fixture/scholar/empty_handed/research_tool_rate()
	return 0
// Work while the bench runs (chat feedback, 2026-11-17).
/proc/late_test_working_nearby()
	var/obj/structure/research_bench/late_fixture/bench = new(locate(2,2,1))
	bench.tier = 8
	var/obj/item/weapon/book/B = new(bench)
	var/mob/living/human/late_fixture/scholar/lead = new(locate(2,3,1))
	lead.prepare("iron_tools", 100)
	bench.assigned_node = "iron_tools"
	var/beside = late_tick_gain(bench, B, "iron_tools")
	lead.loc = locate(2,5,1)
	var/near = late_tick_gain(bench, B, "iron_tools")
	late_check(beside > 0 && abs(near - beside * 0.75) <= 0.11, "a scholar three tiles off and in sight keeps the bench going at three quarters pace ([beside] beside, [near] near)")
	var/list/worker = bench.book_working_researcher("iron_tools")
	late_check(worker && worker[1] == lead, "the bench window names the scholar working nearby")
	var/turf/between = locate(2,4,1)
	between.opacity = TRUE
	late_check(late_tick_gain(bench, B, "iron_tools") == 0, "a scholar who cannot see the bench does not count")
	between.opacity = FALSE
	lead.loc = locate(2,6,1)
	late_check(late_tick_gain(bench, B, "iron_tools") == 0, "four tiles off is too far")
	lead.loc = locate(2,5,1)
	late_check(!lead.can_research_node_at(bench, "iron_tools") && lead.can_research_node_at(bench, "iron_tools", TRUE), "only the lead may stand off; helpers stay at the bench")
	qdel(lead)
	var/mob/living/human/late_fixture/scholar/empty_handed/bare = new(locate(2,3,1))
	bare.prepare("iron_tools", 100)
	late_check(late_tick_gain(bench, B, "iron_tools") == 0 && !bench.resting_tool(), "with no writing tool anywhere the bench stands still")
	var/obj/item/weapon/pen/pencil/pencil = new(bench)
	late_check(bench.resting_tool() == pencil && abs(late_tick_gain(bench, B, "iron_tools") - beside) <= 0.11, "a pencil resting on the bench serves the lead scholar")
	late_check(bench.placed_books().len == 1, "a resting tool is not mistaken for a book")
	qdel(bare)
	qdel(bench)

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
	late_check(abs(bench.team_rate("selfloading_firearms", lead) - 1.5) < 0.001 && bench.team_rows("selfloading_firearms", lead).len == 1, "a second scholar as able as the lead adds half")
	var/together = late_tick_gain(bench, B, "selfloading_firearms")
	late_check(alone > 0 && abs(together - alone * 1.5) <= 0.11, "the bench tick writes the faster pace into the book ([alone] alone, [together] together)")
	var/mob/living/human/late_fixture/scholar/third = new(locate(6,4,1))
	var/mob/living/human/late_fixture/scholar/fourth = new(locate(6,3,1))
	third.prepare("selfloading_firearms", 100)
	fourth.prepare("selfloading_firearms", 100)
	late_check(abs(bench.team_rate("selfloading_firearms", lead) - 2) < 0.001 && bench.research_helpers("selfloading_firearms", lead).len == 2, "only two helpers count, so the pace at most doubles")
	qdel(third)
	qdel(fourth)
	second.scholarship = list()
	late_check(bench.team_rate("selfloading_firearms", lead) == 1, "a bystander without the skill is no second scholar")
	// Early subjects are unchanged.
	lead.teach("basic_tools")
	second.prepare("iron_tools", 100)
	lead.prepare("iron_tools", 100)
	late_check(abs(bench.team_rate("iron_tools", lead) - 1.5) < 0.001, "helpers count on early subjects too")
	var/helper_need = node_scholar_requirement("iron_tools")
	second.prepare("iron_tools", helper_need)
	bench.assigned_node = "iron_tools"
	for (var/i in 1 to 20)
		bench.book_analysis_tick()
	late_check(second.can_research_node_at(bench, "iron_tools") && second.scholar_level(node_discipline("iron_tools")) > helper_need, "the helper learns from the work too ([second.scholar_level(node_discipline("iron_tools"))] from [helper_need])")
	bench.assigned_node = "selfloading_firearms"
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
/mob/living/human/late_fixture/scholar
	var/obj/item/weapon/pen/fixture_pen = null
/mob/living/human/late_fixture/scholar/held_writing_pen()
	return fixture_pen
/proc/late_test_ciphers()
	var/mob/living/human/late_fixture/scholar/writer = new(locate(2,6,1))
	writer.real_name = "Ansel"
	var/mob/living/human/late_fixture/scholar/spy = new(locate(2,7,1))
	spy.real_name = "Corvin"
	var/mob/living/human/late_fixture/scholar/friend = new(locate(3,7,1))
	friend.real_name = "Dessa"
	writer.scholarship = list("mathematics" = 60)
	var/obj/item/weapon/book/B = new(locate(2,6,1))
	B.name = "ledger"
	late_check(findtext(B.encipher_problem(writer), "no research"), "an empty book has nothing to hide")
	B.add_research_chapter("basic_tools")
	B.add_research_chapter("pottery_storage")
	late_check(findtext(B.encipher_problem(writer), "need to know"), "writing in cipher needs the Printing Press")
	writer.teach("printing_currency")
	late_check(findtext(B.encipher_problem(writer), "pencil or pen"), "and a pen in hand")
	writer.fixture_pen = new /obj/item/weapon/pen(writer)
	late_check(isnull(B.encipher_problem(writer)) && !B.is_enciphered() && !B.cipher_blocks(spy), "a plain book is open to everyone")
	late_check(!B.encipher_commit(writer, "ab") && !B.encipher_commit(writer, "a|b=c") && !B.is_enciphered(), "key words that are too short or would break the record are refused")
	late_check(B.encipher_commit(writer, "  Rosebud ") && B.cipher_key == "rosebud" && B.cipher_strength == 4, "the book goes into cipher under a tidied key word, at a strength set by the writer's mathematics")
	late_check(B.can_read_cipher(writer) && !B.cipher_blocks(writer) && B.cipher_blocks(spy) && B.cipher_refuses(spy), "the writer reads it, a stranger does not")
	late_check(findtext(B.encipher_problem(writer), "already"), "a book in cipher is not enciphered twice")
	// The cipher keeps strangers out of the research.
	late_check(!study_research_source(spy, B, "basic_tools") && !spy.knows_recipe_node("basic_tools"), "a stranger cannot study a chapter in cipher")
	late_check(!B.rip_page(spy, "basic_tools") && B.has_research_chapter("basic_tools"), "or tear one out")
	late_check(B.research_chapter_list().len == 2 && length(B.era_record_node_ids()) == 2, "the chapters are still in the book and still count as records")
	var/list/data = B.research_book_ui_data(spy)
	late_check(findtext(data["cipher_note"], "cannot study") && findtext(B.research_book_ui_data(writer)["cipher_note"], "You can read it"), "the book window says who can read it")
	// The key word.
	late_check(!B.try_cipher_key(friend, "tulip") && B.cipher_blocks(friend), "a wrong key word opens nothing")
	late_check(B.try_cipher_key(friend, "ROSEBUD") && !B.cipher_blocks(friend) && B.cipher_blocks(spy), "the right key word makes a reader of whoever is told it")
	// Code-breaking.
	spy.scholarship = list("mathematics" = 11)
	late_check(findtext(B.break_problem(spy), "Basic Mathematics 12"), "breaking a cipher takes some mathematics")
	spy.scholarship = list("mathematics" = 35)
	late_check(findtext(B.break_problem(spy), "pencil or pen"), "and a pen")
	spy.fixture_pen = new /obj/item/weapon/pen(spy)
	late_check(isnull(B.break_problem(spy)) && B.cipher_break_time(spy) == 9600, "a breaker with half the writer's mathematics needs twice the time (16 minutes at strength 4)")
	spy.scholarship = list("mathematics" = 100)
	late_check(B.cipher_break_time(spy) == 3360, "a master needs far less (5.6 minutes)")
	spy.scholarship = list("mathematics" = 35)
	late_check(!B.break_commit(spy) && B.cipher_break_fraction(spy) > 0.03 && B.cipher_break_fraction(spy) < 0.032 && B.cipher_blocks(spy), "one sitting is a small step and the working stays with the book")
	var/sittings = 1
	while(sittings < 100 && !B.break_commit(spy))
		sittings++
	late_check(sittings == 32 && !B.cipher_blocks(spy) && B.cipher_break_fraction(spy) == 0, "32 sittings of half a minute break it for the breaker alone")
	late_check(findtext(B.break_problem(spy), "no cipher"), "a reader has nothing left to break")
	late_check(!B.cipher_refuses(spy), "the cipher no longer refuses the breaker")
	// Copies keep the cipher; plain writing removes it.
	var/obj/item/weapon/book/copy = new(locate(2,6,1))
	copy.copy_cipher_from(B)
	late_check(copy.cipher_key == "rosebud" && copy.cipher_strength == 4 && copy.can_read_cipher(friend) && copy.cipher_progress == "", "a printed copy stays in the same cipher")
	var/mob/living/human/late_fixture/scholar/outsider = new(locate(4,7,1))
	outsider.real_name = "Egon"
	late_check(!B.decipher_commit(outsider) && B.is_enciphered(), "only a reader can write it out plainly")
	map.book_research = FALSE
	late_check(!B.cipher_blocks(outsider), "ciphers bind nobody where book research is off")
	map.book_research = TRUE
	late_check(B.decipher_commit(friend) && !B.is_enciphered() && !B.cipher_blocks(outsider) && B.cipher_readers == "", "written out plainly, the book is open again")
/proc/late_test_learning_by_doing()
	build_practice_experiments()
	// Scholarship from field work credited at a bench.
	var/mob/living/human/late_fixture/gunner = new(locate(2,5,1))
	note_field_work(gunner, "shots", 500)
	var/obj/structure/research_bench/late_fixture/bench = new(locate(2,6,1))
	bench.tier = 8
	var/obj/item/weapon/book/log = new(bench)
	bench.assigned_node = "cartridge_ammo"
	var/datum/research_node/CN = get_research_node("cartridge_ammo")
	var/discipline = node_discipline("cartridge_ammo")
	late_check(gunner.scholar_level(discipline) == 0, "a veteran starts with no scholarship")
	late_check(bench.credit_field_work(), "the veteran's field work is written into the book")
	var/points = round(CN.cost_ticks * 0.35)
	var/expected = round(points * 0.02 * 1.5, 0.01)
	var/taught = gunner.scholar_level(discipline)
	late_check(taught == expected && taught > 0, "field work teaches the scholarship of its points at the bench and half again ([taught] for [points] points)")
	late_check(gunner.scholar_level("mathematics") > 0 && gunner.scholar_level("mathematics") < taught, "it teaches some Basic Mathematics too")
	// A fresh book takes the report again, and teaches nothing new.
	log.loc = locate(1,1,1)
	var/obj/item/weapon/book/fresh = new(bench)
	late_check(bench.credit_field_work() && fresh.research_ticks("cartridge_ammo") == points && gunner.scholar_level(discipline) == taught, "the same field work in a fresh book teaches nothing more")
	late_check(!gunner.gain_active_scholarship("cartridge_ammo", 50, "field:cartridge_ammo_range") && gunner.gain_active_scholarship("cartridge_ammo", 50, "field:other") > 0, "each piece of work teaches once, new work teaches again")
	late_check(!gunner.gain_active_scholarship("cartridge_ammo", 0, "nothing") && !gunner.gain_active_scholarship("no_such_node", 50, "nowhere") && !gunner.gain_active_scholarship("cartridge_ammo", 50, null), "no points, no subject or no name teach nothing")
	// Prototypes teach their maker, once per prototype number.
	var/item_path = null
	for(var/path in recipe_node_requirements)
		if(recipe_node_requirements[path] == "iron_tools" && ispath(text2path(path), /obj/item/weapon))
			item_path = path
			break
	var/datum/research_node/IN = get_research_node("iron_tools")
	var/mob/living/human/late_fixture/maker = new(locate(7,5,1))
	for(var/req in IN.prereqs)
		maker.teach(req)
	var/obj/item/weapon/book/notebook = new(maker)
	notebook.add_research_work("iron_tools", round(IN.cost_ticks * 0.4))
	var/proto_points = record_subject_prototype(maker, item_path)
	var/proto_taught = maker.scholar_level(node_discipline("iron_tools"))
	late_check(proto_points > 0 && proto_taught == round(proto_points * 0.02 * 1.5, 0.01), "a prototype teaches its maker ([proto_taught])")
	record_subject_prototype(maker, item_path)
	late_check(maker.scholar_level(node_discipline("iron_tools")) > proto_taught, "the second prototype teaches again")
	var/after_two = maker.scholar_level(node_discipline("iron_tools"))
	var/obj/item/weapon/book/notebook2 = new(locate(1,1,1))
	notebook.loc = locate(1,1,1)
	notebook2.loc = maker
	notebook2.add_research_work("iron_tools", round(IN.cost_ticks * 0.4))
	late_check(record_subject_prototype(maker, item_path) > 0 && maker.scholar_level(node_discipline("iron_tools")) == after_two, "the first prototype in another book teaches nothing new")
	// Demonstrations teach as a fifth of the subject.
	late_check(demonstration_lesson_points(get_research_node("steam_power")) == round(get_research_node("steam_power").cost_ticks * 0.2), "a demonstration teaches as a fifth of its subject")
	// Off where book research is off; the dead learn nothing.
	map.book_research = FALSE
	late_check(!maker.gain_active_scholarship("iron_tools", 50, "off") && maker.skill_variety_mult("crafting", "x") == 1 && isnull(maker.skill_variety), "nothing is taught or counted where book research is off")
	map.book_research = TRUE
	maker.stat = DEAD
	late_check(!maker.gain_active_scholarship("iron_tools", 50, "dead"), "the dead learn nothing")
	// Variety for body skills.
	var/mob/living/human/late_fixture/smith = new(locate(7,7,1))
	late_check(skill_variety_factor(0) == 5 && skill_variety_factor(1) == 1 && skill_variety_factor(4) == 1 && skill_variety_factor(5) == 0.5 && skill_variety_factor(9) == 0.5 && skill_variety_factor(10) == 0.25 && skill_variety_factor(99) == 0.25, "first time five times, then normal, then half, then a quarter")
	var/start = smith.stats["crafting"][1]
	smith.adaptStat("crafting", 1, "/obj/item/knife")
	var/first = smith.stats["crafting"][1] - start
	smith.adaptStat("crafting", 1, "/obj/item/knife")
	var/second = smith.stats["crafting"][1] - start - first
	late_check(first > second * 4.5 && second > 0, "the first of a thing teaches about five times a repeat ([first] against [second])")
	for(var/i = 3 to 12)
		smith.adaptStat("crafting", 1, "/obj/item/knife")
	var/before_rote = smith.stats["crafting"][1]
	smith.adaptStat("crafting", 1, "/obj/item/knife")
	var/rote = smith.stats["crafting"][1] - before_rote
	var/before_new = smith.stats["crafting"][1]
	smith.adaptStat("crafting", 1, "/obj/item/spoon")
	late_check(rote < second && smith.stats["crafting"][1] - before_new > rote * 10, "the thirteenth knife teaches little, a first spoon teaches a lot")
	late_check(smith.skill_variety["crafting:/obj/item/knife"] == 10 && smith.skill_variety["crafting:/obj/item/spoon"] == 1, "counting stops at ten")
	var/plain_before = smith.stats["farming"][1]
	smith.adaptStat("farming", 1)
	late_check(round(smith.stats["farming"][1] - plain_before, 0.001) == round(plain_before * 0.005, 0.001) && smith.skill_variety.len == 2, "actions that name nothing teach as before and are not counted")
	// Beside a master.
	var/mob/living/human/late_fixture/novice = new(locate(4,8,1))
	var/mob/living/human/late_fixture/master = new(locate(5,8,1))
	late_check(!novice.skill_master_nearby("crafting") && novice.skill_master_mult("crafting") == 1, "an equal is no master")
	master.stats["crafting"] = list(125, 125)
	late_check(novice.skill_master_nearby("crafting") == master && novice.skill_master_mult("crafting") == 2 && !master.skill_master_nearby("crafting"), "someone a quarter better doubles the gain, and gains nothing themselves")
	late_check(novice.skill_master_mult("farming") == 1 && novice.skill_master_mult("strength") == 1, "only in the skill they are better at, and never strength")
	var/n0 = novice.stats["crafting"][1]
	novice.adaptStat("crafting", 5)
	late_check(round(novice.stats["crafting"][1] - n0, 0.01) == 2, "the pupil's gain is doubled ([novice.stats["crafting"][1] - n0])")
	master.loc = locate(8,8,1)
	late_check(novice.skill_master_mult("crafting") == 1, "a master out of reach teaches nothing")
	master.loc = locate(5,8,1)
	master.stat = UNCONSCIOUS
	late_check(novice.skill_master_mult("crafting") == 1, "nor does one who is out cold")
	master.stat = CONSCIOUS
	map.book_research = FALSE
	late_check(novice.skill_master_mult("crafting") == 1, "masters teach only where book research is on")
	map.book_research = TRUE
	// Saved records are cleaned.
	var/list/dirty = list("a" = 3, "b" = 99, "c" = "x", 5)
	var/list/clean = clean_skill_variety(dirty)
	late_check(clean.len == 2 && clean["a"] == 3 && clean["b"] == 10, "saved variety counts are cleaned")
	late_check(length(clean_scholar_lessons(list("x", "x", 7, ""))) == 1 && !length(clean_scholar_lessons("junk")), "saved lessons are cleaned")
// Philosophy grows from studying, teaching, writing and comparing (learning_by_doing.dm).
/proc/late_test_philosophy()
	var/mob/living/human/late_fixture/thinker = new(locate(6,6,1))
	var/mob/living/human/late_fixture/pupil = new(locate(6,7,1))
	pupil.name = "Pupil"
	thinker.stats["philosophy"] = list(100, 100)
	late_check(thinker.philosophy_from_study("basic_tools") && abs(thinker.stats["philosophy"][1] - 105) < 0.01, "a first chapter studied raises Philosophy from 100 to 105")
	thinker.philosophy_from_study("pottery")
	late_check(abs(thinker.stats["philosophy"][1] - 110.25) < 0.01, "each new chapter teaches as much again")
	var/before = thinker.stats["philosophy"][1]
	thinker.philosophy_from_writing("pottery")
	late_check(abs(thinker.stats["philosophy"][1] / before - 1.03) < 0.0005, "writing a chapter out for the first time teaches too")
	before = thinker.stats["philosophy"][1]
	thinker.philosophy_from_writing("pottery")
	late_check(abs(thinker.stats["philosophy"][1] / before - 1.006) < 0.0005, "writing the same chapter again teaches a fifth as much")
	before = thinker.stats["philosophy"][1]
	late_check(thinker.philosophy_from_tutoring("pottery", pupil) && thinker.philosophy_from_comparing("pottery", pupil) && thinker.stats["philosophy"][1] > before, "tutoring and comparing notes teach the scholar")
	map.book_research = FALSE
	before = thinker.stats["philosophy"][1]
	late_check(!thinker.philosophy_from_study("weaving") && thinker.stats["philosophy"][1] == before, "nothing changes where book research is off")
	map.book_research = TRUE

/proc/late_test_trial_and_error()
	var/item_path = null
	for(var/path in recipe_node_requirements)
		if(recipe_node_requirements[path] == "iron_tools" && ispath(text2path(path), /obj/item/weapon))
			item_path = path
			break
	var/datum/research_node/IN = get_research_node("iron_tools")
	var/discipline = node_discipline("iron_tools")
	var/mob/living/human/late_fixture/maker = new(locate(2,8,1))
	maker.name = "Hild"
	for(var/req in IN.prereqs)
		maker.teach(req)
	var/obj/item/weapon/book/B = new(maker)
	late_check(!subject_prototype_allowed(maker, item_path), "an empty book alone allows no attempts")
	var/list/choices = maker.trial_subject_choices(B)
	late_check(choices["Iron Tools"] == "iron_tools" && !("Nuclear Power" in choices) && !(get_research_node(IN.prereqs[1]).name in choices), "a book can be set to subjects whose groundwork its carrier knows, and not to known ones")
	late_check(!maker.set_trial_subject(B, "nuclear_power") && isnull(B.trial_subject), "a subject without its groundwork cannot be attempted")
	late_check(maker.set_trial_subject(B, "iron_tools") && B.trial_subject == "iron_tools", "the book is opened to Iron Tools")
	late_check(subject_prototype_allowed(maker, item_path) && crafting_recipe_allowed(maker, item_path), "now its things can be attempted from an empty chapter")
	// The chance: a low start, worse without the scholarship, better with it.
	var/req_level = node_scholar_requirement("iron_tools")
	var/unskilled = maker.trial_success_chance("iron_tools", item_path, B)
	maker.scholarship = list("[discipline]" = req_level, "mathematics" = req_level)
	var/skilled = maker.trial_success_chance("iron_tools", item_path, B)
	maker.scholarship = list("[discipline]" = req_level + 40, "mathematics" = req_level)
	var/expert = maker.trial_success_chance("iron_tools", item_path, B)
	late_check(skilled == 15 && unskilled == (req_level >= 10 ? 5 : 15 - req_level) && expert == 30, "an empty chapter gives 15 in 100, less without the scholarship and up to 30 with plenty ([unskilled], [skilled], [expert])")
	maker.scholarship = list("[discipline]" = req_level, "mathematics" = req_level)
	// A failure: a lesson in the book, a ruined piece, a better next try.
	var/level_before = maker.scholar_level(discipline)
	var/points = commit_trial_failure(maker, "iron_tools", item_path, B)
	var/obj/item/trash/failed_attempt/ruin = locate() in get_turf(maker)
	late_check(points == max(1, round(IN.cost_ticks * 0.04)) && B.research_ticks("iron_tools") == points && B.lessons_learned("iron_tools") == 1, "a failure writes a lesson of [points] points into the book")
	late_check(ruin && findtext(ruin.name, "ruined ") == 1, "it leaves a ruined piece ([ruin ? ruin.name : "none"])")
	late_check(maker.scholar_level(discipline) > level_before, "the lesson teaches scholarship")
	var/after_one = maker.trial_success_chance("iron_tools", item_path, B)
	late_check(after_one >= skilled + 10 + 5 && maker.trial_count("iron_tools>[item_path]") == 1, "the next try at the same thing is likelier to work ([skilled] to [after_one])")
	late_check(maker.trial_success_chance("iron_tools", "/obj/item/other", B) < after_one, "a different thing has only the chapter's progress to go on")
	for(var/i = 2 to 5)
		commit_trial_failure(maker, "iron_tools", item_path, B)
	var/ticks = B.research_ticks("iron_tools")
	late_check(B.lessons_learned("iron_tools") == 5 && !commit_trial_failure(maker, "iron_tools", item_path, B) && B.research_ticks("iron_tools") == ticks, "a book takes five lessons per subject, then failures only improve the odds")
	late_check(maker.trial_success_chance("iron_tools", item_path, B) == 95, "the odds never pass 95 in 100 before a third of the chapter")
	// A working piece made early.
	late_check(maker.trial_count("iron_tools") == 0, "no early pieces yet")
	var/made = record_subject_prototype(maker, item_path)
	late_check(made == max(1, round(IN.cost_ticks * 0.08)) && maker.trial_count("iron_tools") == 1 && maker.trial_count("iron_tools![item_path]") == 1, "a working piece writes its prototype share and is counted on its maker")
	late_check(!maker.note_trial_success("iron_tools", item_path) && maker.trial_count("iron_tools") == 2, "only the first of each thing is a breakthrough")
	// One character's early pieces are limited across books.
	maker.trial_work["iron_tools"] = 5
	var/obj/item/weapon/book/fresh = new(maker)
	B.loc = locate(1,1,1)
	maker.set_trial_subject(fresh, "iron_tools")
	late_check(fresh.trial_subject == "iron_tools" && !subject_prototype_allowed(maker, item_path), "five early pieces per character: a fresh book does not start the count again")
	// From a third of the chapter on it is the old rule: every one works.
	fresh.add_research_work("iron_tools", round(IN.cost_ticks * 0.4))
	late_check(subject_prototype_allowed(maker, item_path) && maker.trial_success_chance("iron_tools", item_path, fresh) == 100 && !trial_craft_ruined(maker, item_path), "from a third of the chapter prototypes always work, as before")
	var/count_before = maker.trial_count("iron_tools")
	record_subject_prototype(maker, item_path)
	late_check(maker.trial_count("iron_tools") == count_before, "and they are not counted as early pieces")
	// Nobody without a reason to fail fails.
	maker.teach("iron_tools")
	late_check(!trial_craft_ruined(maker, item_path) && !trial_craft_ruined(null, item_path) && !trial_craft_ruined(maker, "/obj/item/weapon/paper"), "someone who knows the subject, nobody, and ordinary things never fail this way")
	// Mishaps only from the Industrial Age on.
	var/mob/living/human/late_fixture/victim = new(locate(4,8,1))
	late_check(isnull(trial_mishap(victim, IN)) && !victim.fixture_hurt.len, "early subjects fail safely")
	var/datum/research_node/late_node = null
	for(var/node_id in research_nodes)
		var/datum/research_node/N = research_nodes[node_id]
		if(N.era_tier >= 4 && rush_accident_kind(node_id) == "injury")
			late_node = N
			break
	late_check(late_node && trial_mishap(victim, late_node) == "injury" && victim.fixture_hurt[BRUTE] >= 5, "a later engineering failure can cut the maker's hand")
	// Saved records are cleaned, and nothing works where book research is off.
	var/list/clean = clean_trial_work(list("a" = 3, "b" = 99, "c" = "x", 5))
	late_check(clean.len == 2 && clean["a"] == 3 && clean["b"] == 9, "saved trial records are cleaned")
	map.book_research = FALSE
	var/mob/living/human/late_fixture/other = new(locate(6,8,1))
	for(var/req in IN.prereqs)
		other.teach(req)
	var/obj/item/weapon/book/offbook = new(other)
	offbook.trial_subject = "iron_tools"
	late_check(!subject_prototype_allowed(other, item_path) && !trial_craft_ruined(other, item_path), "no attempts where book research is off")
	map.book_research = TRUE
/proc/late_test_trade_learning()
	var/item_path = null
	var/other_path = null
	for(var/path in recipe_node_requirements)
		if(recipe_node_requirements[path] == "iron_tools" && ispath(text2path(path), /obj/item/weapon))
			if(!item_path)
				item_path = path
			else if(!other_path)
				other_path = path
	var/datum/research_node/IN = get_research_node("iron_tools")
	late_check(item_path && other_path, "Iron Tools has two things to make")
	// Kept clear of the other tests' characters.
	var/mob/living/human/late_fixture/master = new(locate(1,4,1))
	master.name = "Weland"
	var/mob/living/human/late_fixture/pupil = new(locate(1,5,1))
	pupil.name = "Egil"
	var/mob/living/human/late_fixture/stranger = new(locate(1,6,1))
	for(var/mob/living/human/other in range(3, master))
		if(!(other in list(master, pupil, stranger)))
			other.loc = locate(8,1,1)
	for(var/req in IN.prereqs)
		master.teach(req)
		pupil.teach(req)
	master.teach("iron_tools")
	late_check(trade_learning_cap(IN) == 1 && trade_learning_cap(get_research_node("cartridge_ammo")) == 0.5, "early subjects can be learned wholly from a teacher, later ones half")
	late_check(pupil.can_learn_trade("iron_tools") && !master.can_learn_trade("iron_tools") && !stranger.can_learn_trade("iron_tools"), "only someone with the groundwork and without the subject can learn it")
	late_check(pupil.trade_teacher("iron_tools") == master && !master.trade_teacher("iron_tools"), "the teacher is someone within reach who knows it")
	// Watching.
	late_check(note_craft_watched(master, item_path) == 1 && pupil.study_percent("iron_tools") == 15, "watching a thing being made fills 15% of the subject")
	late_check(!note_craft_watched(master, item_path) && pupil.study_percent("iron_tools") == 15, "the same thing twice shows nothing new")
	late_check(note_craft_watched(master, other_path) == 1 && pupil.study_percent("iron_tools") == 30, "a different thing does")
	late_check(!stranger.study_fraction("iron_tools"), "someone without the groundwork picks up nothing")
	late_check(!note_craft_watched(pupil, item_path), "watching someone who does not know the subject teaches nothing")
	pupil.trade_watched["iron_tools"] = 3
	late_check(!note_craft_watched(master, "/obj/item/weapon/third") && pupil.study_percent("iron_tools") == 30, "three kinds of thing per subject is all watching gives")
	// Guided work.
	late_check(guided_work_node(pupil, item_path) == "iron_tools" && crafting_recipe_allowed(pupil, item_path), "beside the teacher, the pupil may make the subject's things")
	late_check(!guided_work_allowed(stranger, item_path) && !guided_work_allowed(master, item_path), "the unprepared and the teacher get no guided work")
	late_check(record_guided_work(pupil, item_path) && pupil.study_percent("iron_tools") == 50, "each thing made under guidance fills 20%")
	late_check(pupil.guided_fail_chance() == 30, "an ordinary pupil spoils 30 in 100")
	pupil.stats["crafting"] = list(150, 150)
	late_check(pupil.guided_fail_chance() == 5, "a skilled pupil seldom spoils one")
	pupil.stats["crafting"] = list(100, 100)
	late_check(abs(commit_guided_failure(pupil, "iron_tools", item_path) - 0.1) < 0.001 && pupil.study_percent("iron_tools") == 60 && (locate(/obj/item/trash/failed_attempt) in get_turf(pupil)), "a spoiled attempt leaves a ruined piece and still teaches half as much")
	master.loc = locate(5,1,1)
	late_check(!guided_work_allowed(pupil, item_path) && !crafting_recipe_allowed(pupil, item_path) && !record_guided_work(pupil, item_path), "with the teacher gone there is no guided work")
	master.loc = locate(1,4,1)
	master.stat = UNCONSCIOUS
	late_check(!guided_work_allowed(pupil, item_path), "an unconscious teacher guides nobody")
	master.stat = CONSCIOUS
	// A half-read chapter and a half-served apprenticeship add up, and it ends in knowing.
	var/master_before = master.scholar_level(node_discipline("iron_tools"))
	record_guided_work(pupil, item_path)
	late_check(pupil.study_percent("iron_tools") == 80 && !pupil.knows_recipe_node("iron_tools"), "four fifths is not yet knowing")
	record_guided_work(pupil, item_path)
	late_check(pupil.knows_recipe_node("iron_tools") && !pupil.study_fraction("iron_tools"), "the last piece teaches the subject, with no book")
	late_check(pupil.scholar_level(node_discipline("iron_tools")) >= 2.5 && master.scholar_level(node_discipline("iron_tools")) > master_before, "pupil and teacher both gain scholarship")
	late_check(!guided_work_allowed(pupil, item_path) && crafting_recipe_allowed(pupil, item_path), "after that it is ordinary work")
	// Later subjects stop at half.
	var/datum/research_node/CN = get_research_node("cartridge_ammo")
	var/mob/living/human/late_fixture/gunsmith = new(locate(1,8,1))
	var/mob/living/human/late_fixture/learner = new(locate(2,8,1))
	for(var/req in CN.prereqs)
		gunsmith.teach(req)
		learner.teach(req)
	gunsmith.teach("cartridge_ammo")
	learner.add_trade_learning("cartridge_ammo", 0.4, gunsmith)
	late_check(abs(learner.add_trade_learning("cartridge_ammo", 0.4, gunsmith) - 0.1) < 0.001 && learner.study_percent("cartridge_ammo") == 50 && !learner.knows_recipe_node("cartridge_ammo"), "a later subject fills to half and no further")
	late_check(!learner.can_learn_trade("cartridge_ammo") && !learner.add_trade_learning("cartridge_ammo", 0.4, gunsmith), "the rest has to be read")
	// Off where book research is off; saved records are cleaned.
	map.book_research = FALSE
	late_check(!learner.can_learn_trade("iron_tools") && !note_craft_watched(master, item_path), "nothing passes hand to hand where book research is off")
	map.book_research = TRUE
	var/list/clean = clean_trade_watched(list("a" = 1, "b" = 99, "c" = "x", 5))
	late_check(clean.len == 2 && clean["b"] == 3, "saved watching records are cleaned")
/proc/late_test_naturalist_finds()
	var/datum/research_node/N = get_research_node("basic_agriculture")
	var/mob/living/human/late_fixture/scholar/nat = new(locate(2,7,1))
	nat.name = "Linne"
	nat.real_name = "Linne"
	nat.prepare("basic_agriculture", 0)
	var/mob/living/simple_animal/rabbit/rabbit = new(locate(2,8,1))
	var/obj/item/stack/ore/copper/ore = new(locate(3,7,1))
	var/mob/living/simple_animal/civilian/person = new(locate(1,7,1))
	late_check(find_discipline(rabbit) == "agriculture" && find_discipline(ore) == "natural_science" && find_discipline(new /obj/structure/wild/flowers(locate(2,6,1))) == "medicine", "animals, ores and wild plants are finds of their own disciplines")
	late_check(isnull(find_discipline(person)) && isnull(find_discipline(nat)) && isnull(find_discipline(new /obj/structure/wild/tree_stump(locate(3,8,1)))), "people and stumps are no finds")
	var/list/targets = find_targets(nat)
	late_check(targets.len >= 3, "the scholar sees three things to record ([targets.len])")
	var/obj/item/weapon/book/B = new(nat)
	var/kind = "[rabbit.type]"
	late_check(node_discipline("basic_agriculture") == "agriculture" && ("basic_agriculture" in find_subjects(nat, "agriculture", B, kind)), "a subject of the discipline whose groundwork is known can take the find")
	var/level = nat.scholar_level("agriculture")
	var/points = commit_find(nat, B, kind, "agriculture", "rabbit", "basic_agriculture")
	late_check(points == max(1, round(N.cost_ticks * 0.05)) && B.research_ticks("basic_agriculture") == points, "a find writes a twentieth of the chapter ([points])")
	late_check(nat.scholar_level("agriculture") > level, "and teaches the one who made it")
	late_check(B.has_find(kind) && !commit_find(nat, B, kind, "agriculture", "rabbit", "basic_agriculture") && !B.find_room("weaving", kind), "a book takes each kind of find once")
	late_check(!commit_find(nat, B, "[ore.type]", "natural_science", "copper ore", "basic_agriculture"), "a find cannot go to a subject of another discipline")
	// Finds fill at most three tenths of a chapter.
	var/total = points
	for(var/i = 1 to 8)
		total += B.record_find("basic_agriculture", "test_kind_[i]")
	late_check(total == round(N.cost_ticks * 0.3) && B.find_points("basic_agriculture") == total && !B.find_room("basic_agriculture", "one_more"), "finds stop at three tenths of the chapter ([total] of [N.cost_ticks])")
	// A sheet of notes goes to a bench working on the discipline.
	var/obj/item/weapon/paper/P = new(nat)
	late_check(commit_find(nat, P, kind, "agriculture", "rabbit") == 1 && P.find_kind == kind && P.find_discipline == "agriculture" && !find_paper_ok(P), "a sheet takes one record")
	late_check(!field_study_carrier_ok(P, "basic_agriculture", "x") && !demonstration_carrier_ok(P, "steam_power"), "and is then no use for other notes")
	var/obj/structure/research_bench/late_fixture/bench = new(locate(6,7,1))
	var/obj/item/weapon/book/fresh = new(bench)
	bench.assigned_node = "basic_agriculture"
	nat.put_in_hands(P)
	late_check(bench.take_find_notes(P, nat) && fresh.has_find(kind) && fresh.research_ticks("basic_agriculture") == points, "notes used on the bench are written into its book")
	// Double on a land reached by expedition.
	var/obj/item/weapon/book/far = new(nat)
	expedition_land_info = list("biome" = "temperate", "land_type" = "plain", "size" = "small")
	late_check(find_double_here() && commit_find(nat, far, kind, "agriculture", "rabbit", "basic_agriculture") == max(1, round(N.cost_ticks * 0.1)), "a find on an expedition land is worth double")
	expedition_land_info = list()
	late_check(!find_double_here(), "and the usual amount at home")
	late_check(!find_sky_visible(null) && find_sky_kind() == "sky:[lowertext(season)]", "the night sky is one find a season")
// Natural Science from mining, smelting and firing, and weather and water finds.
/proc/late_test_natural_science_work()
	var/mob/living/human/late_fixture/smith = new(locate(1,3,1))
	smith.name = "Agricola"
	var/obj/structure/furnace/F = new(locate(2,3,1))
	F.iron = 30
	late_check(F.smelt_charge() == 30 && note_smelting(smith, F) && smith.field_work_amount("smelting") == 30, "iron ore in a lit bloomery counts as smelting")
	var/obj/structure/furnace/lime_kiln/L = new(locate(3,3,1))
	late_check(!L.smelt_charge() && !note_smelting(smith, L), "lime burning is not smelting")
	var/obj/structure/oven/O = new(locate(4,3,1))
	new /obj/item/stack/ore/glass(O)
	late_check(note_firing(smith, O) && smith.field_work_amount("firing") == 1, "glass sand in a lit oven counts as firing")
	late_check(!note_firing(smith, O) && smith.field_work_amount("firing") == 1, "lighting it again counts the same sand nothing more")
	var/before = smith.field_work_amount("mining")
	late_check(note_field_work(smith, "mining") && smith.field_work_amount("mining") == before + 1, "an ore vein counts as mining")
	for (var/id in list("alloys_smelting", "steelmaking_smelting", "early_cells_mining", "glassworking_firing", "combustion_reactions"))
		var/list/E = field_experiments[id]
		late_check(islist(E) && node_discipline(E[1]) == "natural_science" && (id in node_field_experiments(E[1])), "[id] is field work for a Natural Science subject")
	late_check(isnull(find_water(locate(5,5,1))) && isnull(find_weather(null)), "dry ground and nobody are no water or weather find")
	var/list/places = find_place_targets(smith)
	for (var/list/P in places)
		late_check(P[2] in scholar_disciplines, "a place find belongs to a discipline")

// Reaching a milestone in a body skill teaches its scholarship (learning_by_doing.dm).
/proc/late_test_skill_mastery()
	var/mob/living/human/late_fixture/hand = new(locate(1,1,1))
	hand.name = "Wulf"
	hand.scholarship = list()
	hand.stats["swords"] = list(149, 149)
	late_check(!hand.note_skill_mastery("swords") && !hand.scholar_level("military"), "below the first milestone a skill teaches no scholarship")
	hand.stats["swords"] = list(150, 150)
	late_check(hand.note_skill_mastery("swords") == 4 && hand.scholar_level("military") == 4, "a skilled swordsman gains 4 levels of Military Science")
	late_check(!hand.note_skill_mastery("swords") && hand.scholar_level("military") == 4, "a milestone pays once")
	hand.stats["bows"] = list(160, 160)
	late_check(!hand.note_skill_mastery("bows") && hand.scholar_level("military") == 4, "a second weapon skill does not pay the same milestone again")
	hand.stats["bows"] = list(250, 250)
	late_check(hand.note_skill_mastery("bows") == 20 && hand.scholar_level("military") == 24, "maxing a skill pays every milestone not yet paid, 24 levels in all")
	hand.stats["medical"] = list(149.4, 149.4)
	hand.adaptStat("medical", 1)
	late_check(hand.stats["medical"][1] >= 150 && hand.scholar_level("medicine") == 4, "the milestone is paid as the skill grows")
	// Val 2026-11-17: one craft teaches at most about 2% crafting, however big the recipe.
	hand.stats["crafting"] = list(140, 140)
	hand.adaptStat("crafting", 500)
	late_check(round(hand.stats["crafting"][1], 0.01) == 142.8 && !hand.scholar_level("engineering"), "one huge craft teaches only about 2% crafting")
	hand.adaptStat("crafting", 1, "/obj/item/late_cap_probe")
	var/small = hand.stats["crafting"][1] - 142.8
	late_check(small > 142.8 * 0.009 && small < 142.8 * 0.021, "a small first try still gets its first-time bonus under the cap ([small])")
	// Krunes 2026-11-15: one big gain jumped past every milestone and paid them all at the cap.
	hand.stats["swimming"] = list(140, 140)
	hand.adaptStat("swimming", 500)
	late_check(hand.stats["swimming"][1] == 150 && hand.stats["swimming"][2] == 150 && hand.scholar_level("natural_science") == 4, "a big gain stops at skilled and pays only that milestone")
	hand.adaptStat("swimming", 500)
	late_check(hand.stats["swimming"][1] == 200 && hand.scholar_level("natural_science") == 12, "the next big gain stops at expert and pays it")
	hand.adaptStat("swimming", 500)
	late_check(hand.stats["swimming"][1] == 250 && hand.scholar_level("natural_science") == 24, "and the next reaches master")
	hand.stats["crafting"] = list(250, 250)
	hand.adaptStat("crafting", -50)
	late_check(hand.stats["crafting"][1] < 250 && hand.stats["crafting"][1] > 200, "losing skill is not held back by milestones")
	hand.scholarship["engineering"] = 0
	hand.skill_mastery -= list(skill_mastery_key("engineering", 150), skill_mastery_key("engineering", 200), skill_mastery_key("engineering", 250))
	hand.stats["crafting"] = list(250, 250)
	hand.stats["farming"] = list(200, 200)
	hand.stats["philosophy"] = list(150, 150)
	hand.stats["strength"] = list(250, 250)
	hand.scholarship["engineering"] = 95
	hand.note_skill_mastery("crafting")
	hand.note_skill_mastery("farming")
	hand.note_skill_mastery("philosophy")
	late_check(hand.scholar_level("engineering") == 100 && hand.scholar_level("agriculture") == 12 && hand.scholar_level("mathematics") == 4 && !hand.note_skill_mastery("strength"), "crafting, farming and philosophy pay their own disciplines up to the cap; strength pays none")
	late_check(clean_skill_mastery(hand.skill_mastery + list("junk", 5)).len == hand.skill_mastery.len, "the record of paid milestones is cleaned on load")
	map.book_research = FALSE
	var/mob/living/human/late_fixture/other = new(locate(1,1,1))
	other.stats["swords"] = list(250, 250)
	late_check(!other.note_skill_mastery("swords"), "nothing is paid where book research is off")
	other.stats["swords"] = list(140, 140)
	other.adaptStat("swords", 500)
	late_check(other.stats["swords"][1] > 200, "gains are not held at milestones where book research is off")
	other.stats["crafting"] = list(100, 100)
	other.adaptStat("crafting", 500)
	late_check(other.stats["crafting"][1] == 200, "crafting gains are not capped where book research is off")
	map.book_research = TRUE
/proc/late_test_compare_notes()
	var/obj/structure/research_bench/late_fixture/bench = new(locate(7,3,1))
	bench.tier = 8
	for(var/mob/living/human/other in range(2, bench))
		other.loc = locate(1,1,1)
	var/datum/research_node/N = get_research_node("selfloading_firearms")
	var/obj/item/weapon/book/ours = new(bench)
	ours.name = "our book"
	var/mob/living/human/late_fixture/scholar/lead = new(locate(7,2,1))
	lead.name = "Ada"
	lead.real_name = "Ada"
	lead.prepare("selfloading_firearms", 100)
	var/mob/living/human/late_fixture/scholar/visitor = new(locate(1,1,1))
	visitor.name = "Bede"
	visitor.real_name = "Bede"
	visitor.prepare("selfloading_firearms", 100)
	ours.add_research_work("selfloading_firearms", round(N.cost_ticks * 0.6))
	late_check(!bench.comparable_subjects().len && !bench.compare_notes(lead), "one book has nothing to compare with")
	var/obj/item/weapon/book/theirs = new(bench)
	theirs.name = "their book"
	late_check(!bench.comparable_subjects().len, "the other book must hold part of the same chapter")
	theirs.add_research_work("selfloading_firearms", round(N.cost_ticks * 0.3))
	late_check(bench.comparable_subjects().len == 1 && bench.comparable_subjects()[1] == "selfloading_firearms", "two part-written chapters on one subject can be compared")
	late_check(findtext(bench.compare_notes_problem(lead, "selfloading_firearms"), "takes two") && !bench.compare_notes_commit(lead, "selfloading_firearms"), "a lone scholar cannot compare notes")
	visitor.loc = locate(8,3,1)
	var/before = ours.research_ticks("selfloading_firearms")
	var/lead_before = lead.scholar_level(node_discipline("selfloading_firearms"))
	lead.scholarship[node_discipline("selfloading_firearms")] = 90
	visitor.scholarship[node_discipline("selfloading_firearms")] = 90
	lead_before = 90
	late_check(isnull(bench.compare_notes_problem(lead, "selfloading_firearms")), "with a second scholar at the bench it can be done")
	var/points = bench.compare_notes(lead)
	var/expected = round(round(N.cost_ticks * 0.3) * 0.5)
	late_check(points == expected && ours.research_ticks("selfloading_firearms") == before + expected && theirs.research_ticks("selfloading_firearms") == round(N.cost_ticks * 0.3), "the fuller chapter gains half of the other's points ([points]) and the other keeps its own")
	late_check(lead.scholar_level(node_discipline("selfloading_firearms")) > lead_before && visitor.scholar_level(node_discipline("selfloading_firearms")) > 90, "both scholars learn from it")
	late_check(ours.has_compared("selfloading_firearms") && theirs.has_compared("selfloading_firearms") && !bench.comparable_subjects().len && !bench.compare_notes_commit(lead, "selfloading_firearms"), "a book is compared on a subject once")
	// A third book cannot be milked by a book already compared.
	theirs.loc = locate(1,1,1)
	var/obj/item/weapon/book/third = new(bench)
	third.add_research_work("selfloading_firearms", round(N.cost_ticks * 0.3))
	late_check(!bench.comparable_subjects().len, "nor again with a fresh book")
	// The lesser book may lie first; the gain never passes the chapter's cost.
	ours.loc = locate(1,1,1)
	var/obj/item/weapon/book/nearly = new(bench)
	nearly.add_research_work("selfloading_firearms", N.cost_ticks - 3)
	late_check(bench.placed_books()[1] == third && bench.compare_notes_commit(lead, "selfloading_firearms") == 3 && nearly.has_research_chapter("selfloading_firearms"), "the fuller book gains whichever lies first, up to a finished chapter")
	map.book_research = FALSE
	late_check(!bench.compare_notes(lead), "no comparing where book research is off")
	map.book_research = TRUE
	// Samples: the first two kinds taken apart teach a fifth each, later kinds less.
	bench.assigned_node = null
	for(var/obj/item/weapon/book/old in bench)
		old.loc = locate(1,1,1)
	var/obj/item/weapon/book/samples = new(bench)
	var/list/kinds = list()
	for(var/path in get_node_recipe_paths("selfloading_firearms"))
		if(ispath(path, /obj/item) && kinds.len < 3)
			kinds += path
	bench.assigned_node = "selfloading_firearms"
	bench.studied_samples = null
	if(kinds.len >= 3)
		var/list/gains = list()
		for(var/path in kinds)
			var/obj/item/sample = new path(lead)
			var/had = samples.research_ticks("selfloading_firearms")
			bench.book_attackby(sample, lead)
			gains += samples.research_ticks("selfloading_firearms") - had
		late_check(gains[1] == round(N.cost_ticks * 0.2) && gains[2] == gains[1] && gains[3] == round(N.cost_ticks * 0.12), "the first two kinds of sample write a fifth each, the third the usual share ([gains[1]], [gains[2]], [gains[3]])")
	else
		late_check(FALSE, "Self-loading Firearms has three kinds of thing to sample")
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
		late_test_practice_work()
		late_test_demonstrations()
		late_test_era_bills()
		late_test_subject_prototypes()
		late_test_learning_by_doing()
		late_test_trial_and_error()
		late_test_philosophy()
		late_test_trade_learning()
		late_test_compare_notes()
		late_test_naturalist_finds()
		late_test_natural_science_work()
		late_test_subject_deeds()
		late_test_skill_mastery()
		late_test_teams()
		late_test_working_nearby()
		late_test_ciphers()
		late_test_late_lines()
	catch(var/exception/e)
		late_failures++
		world.log << "FAIL: exception [e] [e.file]:[e.line]"
	var/list/params = islist(world.params) ? world.params : params2list(world.params)
	text2file(json_encode(list("failures" = late_failures, "commit" = params["tested_commit"], "byond_build" = world.byond_build)), "result.json")
	shutdown()

// Every subject node_id builds on, directly or through its groundwork.
/proc/late_research_ancestors(node_id)
	var/list/found = list()
	var/list/queue = list(node_id)
	while (queue.len)
		var/datum/research_node/N = get_research_node(queue[1])
		queue.Cut(1, 2)
		if (!N)
			continue
		for (var/req in N.prereqs)
			if (!(req in found))
				found += req
				queue += req
	return found
