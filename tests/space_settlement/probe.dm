// Space settlement phase 0: habitat air ledger and barren ground.
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/space_probe/New()
	return
var/space_failures = 0
var/space_runtime_error = FALSE
/proc/space_check(condition, label)
	if (!condition)
		space_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	space_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/space_near(a, b)
	return abs(a - b) < 0.0001

// A ten-tile room at sea-level air.
/proc/space_room(volume = 10)
	var/datum/habitat_ledger/L = new(volume)
	L.add_gas(21 * volume, 0, 79 * volume)
	return L

/proc/space_ledger_checks()
	var/datum/habitat_ledger/L = space_room()
	space_check(space_near(L.pressure_kpa(), 100) && space_near(L.oxygen_kpa(), 21), "a filled room reads 100 kPa with 21 kPa oxygen")
	space_check(L.breathable(), "sea-level air is breathable")
	space_check(!(new /datum/habitat_ledger(10)).breathable(), "an empty module is not breathable")
	space_check((new /datum/habitat_ledger(0)).volume == 1 && (new /datum/habitat_ledger(1e9)).volume == HABITAT_MAX_VOLUME, "volume is clamped")

	// Nobody inside: nothing ticks, not even leaks or cooling.
	var/list/before = L.to_list()
	space_check(!L.advance(10, 0, 5, -60) && json_encode(L.to_list()) == json_encode(before), "an empty module never ticks")
	space_check(!L.advance(0, 1) && !L.advance(-5, 1) && json_encode(L.to_list()) == json_encode(before), "zero or negative time changes nothing")

	// Breathing turns oxygen into CO2 and conserves gas.
	var/total = L.oxygen + L.co2 + L.inert
	space_check(L.advance(5, 2), "an occupied module ticks")
	space_check(space_near(L.oxygen, 210 - HABITAT_BREATH_PER_SECOND * 2 * 5) && space_near(L.co2, HABITAT_BREATH_PER_SECOND * 2 * 5), "two breathers for 5 s use the expected oxygen")
	space_check(space_near(L.oxygen + L.co2 + L.inert, total), "breathing conserves gas")

	// A delayed tick cannot replay a backlog.
	var/datum/habitat_ledger/A = space_room()
	var/datum/habitat_ledger/B = space_room()
	A.advance(HABITAT_MAX_STEP_SECONDS, 1)
	B.advance(36000, 1)
	space_check(json_encode(A.to_list()) == json_encode(B.to_list()), "a ten-hour gap counts as one capped step")

	// Breaches vent air; no oxygen goes negative.
	var/datum/habitat_ledger/V = space_room()
	V.advance(10, 1, 3)
	space_check(V.pressure_kpa() < 100 && V.pressure_kpa() > 0, "breaches vent air")
	V.advance(10, 1, 1000)
	space_check(V.oxygen == 0 && V.co2 == 0 && V.inert == 0 && !V.breathable(), "a blown-out module empties without going negative")
	var/datum/habitat_ledger/S = new(1)
	S.add_gas(0.001, 0, 0)
	S.advance(10, 50)
	space_check(S.oxygen == 0 && space_near(S.co2, 0.001), "breathers cannot use more oxygen than there is")

	// Cooling drifts toward the outside, faster through breaches.
	var/datum/habitat_ledger/W = space_room()
	var/datum/habitat_ledger/H = space_room()
	W.advance(10, 1, 0, -60)
	H.advance(10, 1, 4, -60)
	space_check(W.temperature < 20 && W.temperature > -60, "a sealed module cools slowly toward the outside")
	space_check(H.temperature < W.temperature, "a breached module cools faster")
	var/datum/habitat_ledger/N = space_room()
	N.advance(10, 1, 0, null)
	space_check(N.temperature == 20, "no ambient keeps the temperature")

	// CO2 builds up until scrubbed.
	var/datum/habitat_ledger/C = space_room(1)
	C.add_gas(0, 3, 0)
	space_check(!C.breathable(), "3 kPa of CO2 is not breathable")
	space_check(space_near(C.scrub_co2(10), 3) && C.co2 == 0 && C.breathable(), "the scrubber removes only what is there")

	// An open hatch equalises and conserves.
	var/datum/habitat_ledger/R1 = space_room(10)
	var/datum/habitat_ledger/R2 = new(30)
	R2.temperature = -20
	var/o = R1.oxygen + R2.oxygen
	var/n = R1.inert + R2.inert
	space_check(R1.mix_with(R2), "two modules mix")
	space_check(space_near(R1.pressure_kpa(), R2.pressure_kpa()) && space_near(R1.pressure_kpa(), 25), "mixing equalises pressure by volume")
	space_check(space_near(R1.oxygen + R2.oxygen, o) && space_near(R1.inert + R2.inert, n), "mixing conserves gas")
	space_check(space_near(R1.temperature, -10) && R1.temperature == R2.temperature, "mixing weights temperature by volume")
	space_check(!R1.mix_with(R1) && !R1.mix_with(null), "a module cannot mix with itself or nothing")

	// Resizing keeps the gas.
	var/datum/habitat_ledger/G = space_room(10)
	G.resize(20)
	space_check(space_near(G.pressure_kpa(), 50) && space_near(G.oxygen, 210), "adding a module spreads the same gas")

	// Bad inputs are refused or clamped.
	var/datum/habitat_ledger/X = space_room()
	X.add_gas(-50, "lots", 1e40)
	space_check(space_near(X.oxygen, 210) && X.co2 == 0 && X.inert <= HABITAT_MAX_PARTIAL_KPA * X.volume, "negative, text and huge fills are clamped")

/proc/space_save_checks()
	var/datum/habitat_ledger/L = space_room(12)
	L.advance(7, 3, 1, -40)
	var/list/saved = L.to_list()
	var/datum/habitat_ledger/R = new
	space_check(R.from_list(json_decode(json_encode(saved))), "a saved ledger loads")
	space_check(json_encode(R.to_list()) == json_encode(saved), "the round trip keeps every value")
	for (var/key in saved)
		space_check(isnum(saved[key]), "saved [key] is a plain number")
	space_check(saved.len == 5, "only five fields are saved")
	var/datum/base = new
	for (var/name in R.vars)
		if (name in base.vars)
			continue
		if (findtext(name, "time") || findtext(name, "tick"))
			space_check(FALSE, "ledger stores no time stamp ([name])")
	var/list/bad = saved.Copy()
	bad["oxygen"] = "x"
	var/datum/habitat_ledger/K = space_room()
	var/list/kept = K.to_list()
	space_check(!K.from_list(bad) && json_encode(K.to_list()) == json_encode(kept), "a bad saved value is refused without changing the ledger")
	var/list/missing = saved.Copy()
	missing -= "co2"
	space_check(!K.from_list(missing) && !K.from_list(null), "missing fields and null are refused")
	var/list/nan = saved.Copy()
	nan["inert"] = 1e40 * 1e40 - 1e40 * 1e40
	space_check(!K.from_list(nan), "NaN is refused")
	var/list/huge = saved.Copy()
	huge["volume"] = -3
	huge["oxygen"] = -10
	space_check(K.from_list(huge) && K.volume == 1 && K.oxygen == 0, "out-of-range saved values are clamped")

/proc/space_turf_checks()
	var/turf/T = locate(2, 2, 1)
	T = T.ChangeTurf(/turf/floor/dirt/dust/regolith, FALSE, FALSE)
	space_check(istype(T, /turf/floor/dirt/dust/regolith), "regolith can be placed")
	space_check(!T.outside_air_breathable() && T.outside_ambient_c() == BARREN_AMBIENT_C, "regolith has no breathable air and is cold")
	var/turf/floor/dirt/dust/regolith/G = T
	space_check(G.soil_nutrition == 0 && G.max_soil_nutrition == 0 && !G.may_become_muddy && !G.uses_winter_overlay, "regolith is barren, never muddy and never snowed on")
	space_check(G.icon_state == "dust" && ("dust" in icon_states(G.icon)), "regolith reuses the dry-dirt sprite")
	var/turf/U = locate(3, 2, 1)
	U = U.ChangeTurf(/turf/floor/dirt/dust/regolith/crater, FALSE, FALSE)
	space_check(!U.outside_air_breathable() && U.color != T.color, "crater floor is barren and darker")
	var/turf/E = locate(4, 2, 1)
	E = E.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	space_check(E.outside_air_breathable() && isnull(E.outside_ambient_c()), "ordinary ground keeps breathable air and the usual climate")
	var/area/caribbean/nomads/barren/B = new
	space_check(B.base_turf == /turf/floor/dirt/dust/regolith && B.climate == "desert", "the barren area rests on regolith with a dry climate")
	space_check((B.icon_state in icon_states(B.icon)) && B.ambience[1] == "sound/ambience/desert.ogg", "the barren area reuses existing area art and sound")

// Phase 1: survey map, launch rail, mission console and samples.
/proc/space_test_map()
	var/datum/survey_map/M = new
	// Rows run south to north; the probe lands at 2,2.
	var/list/rows = list("........", ".~*^....", "...^....", "........", "........", "........", "........", "........")
	space_check(M.load_text(json_encode(list("schema" = SURVEY_MAP_SCHEMA, "seed" = "t", "rows" = rows))), "a well-formed survey map loads")
	return M

/proc/space_survey_checks()
	var/datum/survey_map/bad = new
	space_check(!bad.load_text("not json") && !bad.load_text(json_encode(list("schema" = "x", "rows" = list()))), "a broken or foreign survey file is refused")
	space_check(!bad.load_text(json_encode(list("schema" = SURVEY_MAP_SCHEMA, "rows" = list("........", "........", "........", "........", "........", "........", "........", "....X...")))), "unknown cells are refused")
	space_check(!bad.load_text(json_encode(list("schema" = SURVEY_MAP_SCHEMA, "rows" = list("^^^^^^^^", "^^^^^^^^", "^^^^^^^^", "^^^^^^^^", "^^^^^^^^", "^^^^^^^^", "^^^^^^^^", "^^^^^^^^")))), "a map with nowhere to land is refused")

	var/datum/survey_map/shipped = get_space_survey_map()
	space_check(shipped && shipped.width == 40 && shipped.height == 40 && shipped.plain_cells().len > 100, "the shipped survey map loads at 40x40")
	// A sample window on the shipped map, written out for a visual check.
	var/obj/structure/survey_console/demo = new(locate(8, 8, 1))
	space_check(demo.begin_mission(new /obj/item/space_probe/advanced(demo), shipped, 20, 20) || demo.begin_mission(new /obj/item/space_probe/advanced(demo), shipped), "a probe lands on the shipped map")
	for (var/i = 1 to 6)
		demo.try_move(EAST)
		demo.try_move(NORTH)
	text2file(demo.ui_html("Shipped map demo"), "survey_console_shipped.html")
	qdel(demo)

	var/datum/survey_map/M = space_test_map()
	space_check(M.cell(1, 1) == "." && M.cell(4, 2) == "^" && M.cell(3, 2) == "*" && isnull(M.cell(0, 1)) && isnull(M.cell(9, 1)), "cells read south to north")
	space_survey_map_cache = M

	var/turf/T = locate(2, 2, 1)
	var/obj/structure/launch_rail/R = new(T)
	var/obj/structure/survey_console/C = new(locate(4, 2, 1))
	space_check(R.launch() != null, "an empty rail does not launch")
	R.loaded = new /obj/item/space_probe(R)
	var/datum/reagents/fuel = new(200)
	fuel.add_reagent("water", 50)
	space_check(R.add_fuel(fuel) == 0 && R.fuel == 0, "the rail refuses fuel it cannot burn")
	fuel.add_reagent("gasoline", 40)
	fuel.add_reagent("diesel", 40)
	space_check(R.add_fuel(fuel) == 60 && R.fuel == 60 && fuel.get_reagent_amount("diesel") == 20, "the rail takes exactly 60 units of gasoline and diesel")
	space_check(R.launch(2, 2) != null && R.loaded, "a landing site off the plains is refused and the probe stays loaded")
	space_check(isnull(R.launch(2, 1)) && !R.loaded && R.fuel == 0 && C.mission, "a fuelled rail launches to the console nearby")
	space_check(C.battery == 100 && C.is_revealed(1, 1) && C.is_revealed(3, 2) && !C.is_revealed(4, 4) && C.revealed_count() == 6, "the probe lands with a full battery and sees the cells around it")

	// Terrain costs and limits.
	space_check(findtext(C.try_move(WEST), "plain") && C.battery == 99 && C.probe_x == 1, "a plain costs 1")
	space_check(findtext(C.try_move(WEST), "edge") && C.probe_x == 1, "the probe cannot leave the survey")
	C.try_move(EAST)
	C.try_move(NORTH)
	space_check(C.probe_y == 2 && C.probe_x == 2 && C.battery == 96, "a channel costs 2")
	C.try_move(EAST)
	space_check(C.probe_x == 3 && C.battery == 93, "ice costs 3")
	space_check(findtext(C.try_move(EAST), "steep") && C.probe_x == 3, "ridges block the probe")
	C.comms_range = 1
	space_check(findtext(C.try_move(NORTH), "relay") && C.probe_y == 2, "the probe stays inside relay range")
	C.comms_range = 12

	// Samples and records.
	space_check(findtext(C.take_sample(), "ice") && C.samples ~= list("ice") && C.battery == 88, "ice yields an ice core")
	space_check(findtext(C.take_sample(), "already") && C.samples.len == 1, "a site is cored once")
	var/papers = 0
	space_check(findtext(C.photograph(), "record") && C.battery == 86, "a photograph prints a record")
	space_check(findtext(C.photograph(), "already"), "a site is recorded once")
	for (var/obj/item/weapon/paper/P in C.loc)
		papers++
	space_check(papers == 1, "one survey record lies by the console")
	C.try_move(WEST)
	space_check(findtext(C.take_sample(), "sediment"), "a channel yields a sediment core")
	C.try_move(SOUTH)
	C.try_move(EAST)
	space_check(findtext(C.take_sample(), "regolith"), "open plain yields regolith")
	C.try_move(NORTH)
	space_check(findtext(C.take_sample(), "full") && C.samples.len == 3, "the sample bay holds three")
	C.battery = 0
	space_check(findtext(C.try_move(SOUTH), "battery") && C.probe_y == 2, "a flat battery stops the probe")

	// Recharge counts from a tmp clock and never replays a backlog after a restart.
	C.last_recharge = null
	C.recharge()
	space_check(C.battery == 0 && C.last_recharge == world.time, "a missing clock starts afresh without credit")
	C.last_recharge = world.time - 30 * 10
	C.recharge()
	space_check(C.battery == 10, "thirty seconds recharges 10 points")
	C.last_recharge = world.time - 10000 * 10
	C.recharge()
	space_check(C.battery == 100, "recharge stops at a full battery")
	var/list/tmp_vars = list()
	for (var/v in C.vars)
		if (issaved(C.vars[v]) == 0)
			tmp_vars += v
	space_check(("last_recharge" in tmp_vars), "the recharge clock is not saved")

	// Ascent from the landing site only.
	C.try_move(NORTH)
	var/page = C.ui_html("hello")
	space_check(findtext(page, "hello") && findtext(page, "survey=north") && findtext(page, "Battery") && findtext(page, ">P<") && findtext(page, ">L<") && findtext(page, ">?<"), "the console window shows the probe, landing site, fog and controls")
	text2file(page, "survey_console.html")
	space_check(findtext(C.ascend(), "landing site") && C.mission, "the ascent stage waits at the landing site")
	C.try_move(SOUTH)
	C.try_move(SOUTH)
	C.try_move(WEST)
	space_check(C.probe_x == 2 && C.probe_y == 1, "the probe drives home")
	var/seen = C.revealed_count()
	space_check(findtext(C.ascend(), "3 samples") && !C.mission && C.samples.len == 0, "the ascent ends the mission")
	space_check(C.revealed_count() == seen && seen > 6 && C.sampled.len == 3 && C.photographed.len == 1 && C.landing_sites ~= list("2,1"), "the survey record outlives the mission")
	var/list/kinds = list()
	for (var/obj/item/space_sample/S in C.loc)
		kinds += S.kind
	space_check(kinds.len == 3 && ("ice" in kinds) && ("sediment" in kinds) && ("regolith" in kinds), "the samples land by the console as items")

	// A replaced survey map loses contact instead of flying blind.
	R.loaded = new /obj/item/space_probe/advanced(R)
	R.fuel = 60
	space_check(isnull(R.launch(2, 1)) && C.battery == 160 && C.sample_capacity == 5 && C.revealed_count() == seen && C.is_revealed(4, 3), "the advanced probe flies further with a wider camera over the old survey")
	C.try_move(EAST)
	space_check(findtext(C.take_sample(), "already") && C.samples.len == 0, "a site cored on an earlier mission stays cored")
	C.try_move(WEST)
	var/datum/survey_map/other = new
	other.load_text(json_encode(list("schema" = SURVEY_MAP_SCHEMA, "seed" = "other", "rows" = M.rows)))
	space_survey_map_cache = other
	space_check(findtext(C.try_move(EAST), "No signal") && C.probe_x == 2, "a changed survey map loses the probe")
	space_check(findtext(C.ui_html(), "Contact with") && findtext(C.ui_html(), "survey=abandon"), "the console window offers to close a lost mission")
	C.abandon()
	space_check(!C.mission && C.revealed_count() >= seen, "a lost mission can be closed and keeps its survey")
	R.loaded = new /obj/item/space_probe/advanced(R)
	R.fuel = 60
	space_check(isnull(R.launch(2, 1)) && C.revealed_count() == 12 && !C.sampled.len && !C.photographed.len && C.landing_sites ~= list("2,1"), "a new survey map starts a fresh survey record")
	C.abandon()
	space_survey_map_cache = null

	// Research: nodes, recipes and sample analysis.
	build_research_tree()
	var/datum/research_node/rocketry = get_research_node("rocketry")
	var/datum/research_node/survey = get_research_node("planetary_survey")
	space_check(rocketry && rocketry.era_tier == 9 && ("digital_networks" in rocketry.prereqs) && ("missiles" in rocketry.prereqs), "Rocketry is an era 9 node after Digital Networks and Missiles")
	space_check(survey && survey.mode == RESEARCH_MODE_ANALYSIS && survey.era_tier == 9 && ("rocketry" in survey.prereqs), "Planetary Survey follows Rocketry and is not an era capstone")
	space_check(get_recipe_node_req("/obj/item/space_probe") == "rocketry" && get_recipe_node_req("/obj/structure/launch_rail") == "rocketry" && get_recipe_node_req("/obj/structure/survey_console") == "rocketry" && get_recipe_node_req("/obj/item/space_probe/advanced") == "planetary_survey", "probe recipes are gated on the spaceflight nodes")
	var/obj/item/space_sample/rock/sample = new(C.loc)
	var/obj/item/weapon/book/research/tree_book/book = C.analyse(sample, null)
	space_check(book && book.subject == "planetary_survey" && book.transfer_type == "notes" && QDELETED(sample), "analysis turns a sample into notes on Planetary Survey")
// A bare crew member: the full human constructor needs a running game.
/mob/living/human/space_probe_crew/New(newloc)
	loc = newloc
	human_mob_list |= src
/mob/living/human/space_probe_crew/adjustOxyLoss(amount)
	oxyloss += amount

// Submarine compartments share one ledger each instead of per-tile air.
/proc/space_submarine_checks()
	var/datum/flooding_controller/F = new
	var/list/galley = list()
	for (var/x in 2 to 4)
		var/turf/T = locate(x, 5, 1)
		galley += T.ChangeTurf(/turf/floor/sub_deck/galley, FALSE, FALSE)
	var/turf/S = locate(6, 5, 1)
	S = S.ChangeTurf(/turf/floor/sub_deck/storage, FALSE, FALSE)
	var/datum/habitat_ledger/G = F.get_air(SUB_COMP_GALLEY)
	var/datum/habitat_ledger/St = F.get_air(SUB_COMP_STORAGE)
	space_check(istype(G) && G.volume == 3 && space_near(G.pressure_kpa(), 100) && space_near(G.oxygen_kpa(), 21), "a three-tile compartment holds one ledger of sea-level air")
	space_check(istype(St) && St != G && F.compartment_air.len == 2, "each compartment gets its own ledger")
	var/turf/floor/sub_deck/D = galley[1]
	space_check(D.compartment_air() == G && G.breathable(), "deck tiles read their compartment's air")
	var/datum/base = new
	var/turf/floor/sub_deck/plain = locate(6, 7, 1)
	plain = plain.ChangeTurf(/turf/floor/sub_deck, FALSE, FALSE)
	for (var/name in plain.vars)
		if (findtext(name, "oxygen") || findtext(name, "co2") || findtext(name, "atmos") || findtext(name, "vent"))
			space_check(FALSE, "deck tiles carry no air of their own ([name])")
	space_check(plain.map_storage_saved_vars == "icon_state;name" && !plain.compartment_air(), "deck tiles save only their look, and a tile outside any compartment has no ledger")
	for (var/name in F.vars)
		if (name in base.vars)
			continue
		if (findtext(name, "time"))
			space_check(FALSE, "the controller stores no time stamp ([name])")

	// Nobody aboard: the air does not tick.
	var/before = json_encode(G.to_list())
	F.air_tick(1, list(), list(SUB_COMP_GALLEY = 1))
	space_check(json_encode(G.to_list()) == before, "an empty compartment's air does not tick, even with a breach")

	// Water shrinks the air pocket without destroying gas.
	var/total = G.oxygen + G.co2 + G.inert
	F.air_tick(1, list(SUB_COMP_GALLEY = 1.5), list())
	space_check(space_near(G.volume, 1.5) && space_near(G.pressure_kpa(), 200), "half-flooding the compartment compresses its air")
	F.air_tick(1, list(SUB_COMP_GALLEY = 3), list())
	space_check(space_near(G.volume, 1) && space_near(G.oxygen + G.co2 + G.inert, total), "a fully flooded compartment keeps an air pocket and all its gas")
	F.air_tick(1, list(), list())
	space_check(G.volume == 3 && space_near(G.pressure_kpa(), 100), "draining restores the original pressure")

	// Electrolysis and scrubbers.
	space_check(space_near(F.inject_oxygen(SUB_COMP_GALLEY, 1000), (SUB_AIR_MAX_O2_KPA - 21) * 3) && space_near(G.oxygen_kpa(), SUB_AIR_MAX_O2_KPA), "electrolysis stops at the oxygen cap")
	space_check(F.inject_oxygen(SUB_COMP_GALLEY, 5) == 0 && F.inject_oxygen("nowhere", 5) == 0, "a full or unknown compartment takes no oxygen")
	G.add_gas(0, 9, 0)
	space_check(space_near(F.get_compartment_co2(SUB_COMP_GALLEY), 3) && !G.breathable(), "the panel reads CO2 partial pressure")
	space_check(space_near(F.scrub_co2(SUB_COMP_GALLEY, 100), 9) && G.co2 == 0, "a scrubber removes only the CO2 that is there")

	// Ventilation draws open compartments toward shared air and conserves gas.
	G.add_gas(0, 6, 0)
	new /obj/structure/machinery/sub_physical/vent_duct/galley(D)
	new /obj/structure/machinery/sub_physical/vent_duct/storage(S)
	var/co2 = G.co2 + St.co2
	F.ventilate()
	space_check(St.co2 > 0 && G.co2 < 6 && space_near(G.co2 + St.co2, co2), "ventilation shares CO2 between compartments and conserves it")
	F.ventilation_off |= SUB_COMP_STORAGE
	var/held = St.co2
	F.ventilate()
	space_check(St.co2 == held && !F.is_ventilated(SUB_COMP_STORAGE) && F.is_ventilated(SUB_COMP_GALLEY), "a compartment with ventilation shut off keeps its air")
	space_check(F.get_compartment_oxygen("nowhere") == 0 && !F.get_air(""), "unknown compartments have no air")

	// A crew member breathes the compartment's air.
	F.ventilation_off |= SUB_COMP_GALLEY
	var/mob/living/human/space_probe_crew/H = new(galley[2])
	var/list/counted = F.count_breathers()
	space_check(counted[SUB_COMP_GALLEY] == 1 && !counted[SUB_COMP_STORAGE], "the crew member is counted in the galley only")
	var/o2 = G.oxygen
	var/gas = G.oxygen + G.co2 + G.inert
	F.air_tick(1, list(), list())
	space_check(space_near(G.oxygen, o2 - HABITAT_BREATH_PER_SECOND) && space_near(G.oxygen + G.co2 + G.inert, gas), "an occupied compartment breathes and conserves gas")
	var/stored = json_encode(St.to_list())
	F.air_tick(1, list(), list())
	space_check(json_encode(St.to_list()) == stored, "the empty storage compartment does not tick meanwhile")
	G.scrub_co2(G.co2)
	G.oxygen = 0
	var/lost = H.losebreath
	F.air_tick(1, list(), list())
	space_check(H.losebreath > lost && F.get_compartment_oxygen(SUB_COMP_GALLEY) < SUB_AIR_SUFFOCATE_O2_KPA, "a crew member without oxygen suffocates")
	space_check(F.is_compartment_vacuum(SUB_COMP_GALLEY), "the panel reports an oxygen-free compartment")

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/space_probe
		space_check(!world.port, "fixture has no listening port")
		space_ledger_checks()
		space_save_checks()
		space_turf_checks()
		space_survey_checks()
		space_submarine_checks()
	catch(var/exception/e)
		space_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = space_failures, "runtime_error" = space_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
