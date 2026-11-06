// Space settlement phase 0: habitat air ledger and barren ground.
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

	// Nobody inside: no breathing, but breaches still vent and the module still cools.
	var/list/before = L.to_list()
	space_check(!L.advance(0, 1) && !L.advance(-5, 1) && json_encode(L.to_list()) == json_encode(before), "zero or negative time changes nothing")
	var/datum/habitat_ledger/E = space_room()
	space_check(E.advance(10, 0) && json_encode(E.to_list()) == json_encode(before), "an empty sealed module at the same temperature keeps its air")
	space_check(E.advance(10, 0, 2, -60) && E.pressure_kpa() < 100 && E.co2 == 0 && E.temperature < 20, "an empty breached module still vents and cools")

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
	space_check(shipped && shipped.region == "barren" && length(shipped.ir_sha256) == 64, "the shipped survey map is keyed by region and records its bundle hash")
	space_check(!get_space_survey_map("../barren") && !get_space_survey_map("Barren") && !get_space_survey_map("nowhere"), "bad or unknown region ids load nothing")
	space_check(survey_map_matches_manifest(shipped, json_encode(list("generation_result" = list("ir_sha256" = uppertext(shipped.ir_sha256))))), "a manifest from the same bundle matches")
	space_check(!survey_map_matches_manifest(shipped, json_encode(list("generation_result" = list("ir_sha256" = "00")))) && !survey_map_matches_manifest(shipped, "not json") && !survey_map_matches_manifest(shipped, json_encode(list("x" = 1))), "another bundle or a broken manifest does not match")
	space_check(!survey_map_matches_bundle("barren", "no/such/bundle"), "a missing bundle does not match")
	space_check(shipped && shipped.width == 40 && shipped.height == 40 && shipped.plain_cells().len > 100, "the shipped survey map loads at 40x40")
	// A sample window on the shipped map, written out for a visual check.
	var/obj/structure/survey_console/demo = new(locate(8, 8, 1))
	space_check(demo.begin_mission(new /obj/item/space_probe/advanced(demo), shipped, 20, 20, 3), "a probe lands on the shipped map")
	for (var/i = 1 to 6)
		demo.try_move(EAST)
		demo.try_move(NORTH)
	text2file(demo.ui_html("Shipped map demo"), "survey_console_shipped.html")
	qdel(demo)

	var/datum/survey_map/M = space_test_map()
	space_check(M.cell(1, 1) == "." && M.cell(4, 2) == "^" && M.cell(3, 2) == "*" && isnull(M.cell(0, 1)) && isnull(M.cell(9, 1)), "cells read south to north")
	space_survey_maps["barren"] = M
	M.region = "barren"

	var/turf/T = locate(2, 2, 1)
	var/obj/structure/launch_rail/R = new(T)
	var/obj/structure/survey_console/C = new(locate(4, 2, 1))
	space_check(R.launch() != null, "an empty rail does not launch")
	R.loaded = new /obj/item/space_probe(R)
	var/datum/reagents/fuel = new(200)
	fuel.add_reagent("water", 50)
	space_check(R.add_fuel(fuel) == 0 && R.fuel == 0, "the rail refuses fuel it cannot burn")
	fuel.add_reagent("gasoline", 40)
	space_check(R.add_fuel(fuel) == 0 && R.fuel == 0, "the rail no longer burns gasoline")
	fuel.add_reagent("rocket_propellant", 80)
	space_check(R.add_fuel(fuel) == 60 && R.fuel == 60 && fuel.get_reagent_amount("rocket_propellant") == 20, "the rail takes exactly 60 units of rocket propellant")
	space_check(R.launch(2, 2, 0) != null && R.loaded, "a landing site off the plains is refused and the probe stays loaded")
	space_check(isnull(R.launch(2, 1, 0)) && !R.loaded && R.fuel == 0 && C.mission, "a fuelled rail launches to the console nearby")
	space_check(C.dropout_chance == 8 && C.dust_chance == 3, "the basic probe's relay can drop commands")
	C.dropout_chance = 0
	C.dust_chance = 0
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
	space_check(isnull(R.launch(2, 1, 0)) && C.dropout_chance == 0 && C.battery == 160 && C.sample_capacity == 5 && C.revealed_count() == seen && C.is_revealed(4, 3), "the advanced probe flies further with a wider camera over the old survey")
	C.dust_chance = 0
	C.try_move(EAST)
	space_check(findtext(C.take_sample(), "already") && C.samples.len == 0, "a site cored on an earlier mission stays cored")
	C.try_move(WEST)
	var/datum/survey_map/other = new
	other.load_text(json_encode(list("schema" = SURVEY_MAP_SCHEMA, "seed" = "other", "rows" = M.rows)))
	space_survey_maps["barren"] = other
	other.region = "barren"
	space_check(findtext(C.try_move(EAST), "No signal") && C.probe_x == 2, "a changed survey map loses the probe")
	space_check(findtext(C.ui_html(), "Contact with") && findtext(C.ui_html(), "survey=abandon"), "the console window offers to close a lost mission")
	C.abandon()
	space_check(!C.mission && C.revealed_count() >= seen, "a lost mission can be closed and keeps its survey")
	// A rebuilt map with the same seed and size but different terrain is a new map too.
	var/list/rebuilt_rows = M.rows.Copy()
	rebuilt_rows[8] = "^^^^^^^."
	var/datum/survey_map/rebuilt = new
	rebuilt.load_text(json_encode(list("schema" = SURVEY_MAP_SCHEMA, "seed" = "t", "rows" = rebuilt_rows)))
	space_check(rebuilt.seed == M.seed && rebuilt.digest() != M.digest() && M.digest() == md5(jointext(M.rows, "")), "the row digest tells a rebuilt map from the old one")
	R.loaded = new /obj/item/space_probe/advanced(R)
	R.fuel = 60
	space_check(isnull(R.launch(2, 1, 0)) && C.revealed_count() == 12 && !C.sampled.len && !C.photographed.len && C.landing_sites ~= list("2,1"), "a new survey map starts a fresh survey record")
	// Hazards: a dropped command costs 1 and leaves the probe; dust halves recharge.
	C.dropout_chance = 100
	var/before = C.battery
	space_check(findtext(C.try_move(EAST), "dropped") && C.probe_x == 2 && C.battery == before - 1, "a relay dropout loses the command")
	C.dropout_chance = 0
	C.dust_chance = 100
	space_check(findtext(C.try_move(WEST), "dust") && C.dusty, "a dust gust coats the panels")
	space_check(findtext(C.ui_html(), "dusty panels"), "the window shows the dusty panels")
	C.battery = 0
	C.last_recharge = world.time - 30 * 10
	C.recharge()
	space_check(C.battery == 5, "dusty panels recharge at half speed")
	C.abandon()
	space_check(!C.dusty, "the dust clears with the sortie")

	// Landing scatter: an aimed probe lands on a plain within two cells.
	var/scatter_ok = TRUE
	for (var/i = 1 to 20)
		var/list/site = survey_landing_cell(other, 6, 6, SURVEY_LANDING_SCATTER)
		if (!site || abs(site[1] - 6) > 2 || abs(site[2] - 6) > 2 || other.cell(site[1], site[2]) != ".")
			scatter_ok = FALSE
	space_check(scatter_ok, "an aimed landing scatters onto nearby flat ground")
	space_check(isnull(survey_landing_cell(other, 4, 2, 0)) && survey_landing_cell(other, 4, 2, 1), "an exact landing needs a plain, a scattered one finds one")
	R.loaded = new /obj/item/space_probe(R)
	R.fuel = 60
	R.target_x = 6
	R.target_y = 6
	space_check(isnull(R.launch()) && abs(C.land_x - 6) <= 2 && abs(C.land_y - 6) <= 2, "the rail's aim sets the landing area")
	C.abandon()
	space_survey_maps = list()

	// Sample value by kind and novelty.
	space_check(survey_sample_value("ice", TRUE) == 2.25 && survey_sample_value("ice", FALSE) == 1.5 && survey_sample_value("regolith", FALSE) == 0.75 && survey_sample_value("sediment", FALSE) == 1, "ice is worth most, regolith least, a first sample of a kind more")

	// Research: nodes, recipes and sample analysis.
	build_research_tree()
	var/datum/research_node/rocketry = get_research_node("rocketry")
	var/datum/research_node/survey = get_research_node("planetary_survey")
	space_check(rocketry && rocketry.era_tier == 9 && ("digital_networks" in rocketry.prereqs) && ("missiles" in rocketry.prereqs), "Rocketry is an era 9 node after Digital Networks and Missiles")
	space_check(survey && survey.mode == RESEARCH_MODE_ANALYSIS && survey.era_tier == 9 && ("rocketry" in survey.prereqs), "Planetary Survey follows Rocketry and is not an era capstone")
	space_check(get_recipe_node_req("/obj/item/space_probe") == "rocketry" && get_recipe_node_req("/obj/structure/launch_rail") == "rocketry" && get_recipe_node_req("/obj/structure/survey_console") == "rocketry" && get_recipe_node_req("/obj/item/space_probe/advanced") == "planetary_survey", "probe recipes are gated on the spaceflight nodes")
	var/obj/item/space_sample/rock/sample = new(C.loc)
	var/obj/item/weapon/book/research/tree_book/book = C.analyse(sample, null)
	space_check(book && book.subject == "planetary_survey" && book.transfer_type == "notes" && QDELETED(sample) && book.boost_scale == 1.88, "analysis turns a first rock sample into notes worth more")
	var/obj/item/weapon/book/research/tree_book/again = C.analyse(new /obj/item/space_sample/rock(C.loc), null)
	space_check(again && again.boost_scale == 1.25, "a second rock sample is worth its plain value")
// A bare crew member: the full human constructor needs a running game.
/mob/living/human/space_probe_crew/New(newloc)
	loc = newloc
	human_mob_list |= src
/mob/living/human/space_probe_crew/adjustOxyLoss(amount)
	oxyloss += amount

// The fixture has no clients; the test says whether the world counts as awake.
/datum/flooding_controller/space_probe_test
	var/world_awake = TRUE
/datum/flooding_controller/space_probe_test/air_may_tick()
	return world_awake

// Outside exposure: humans read the two turf hooks from their own life tick.
/proc/space_exposure_checks()
	var/turf/R = locate(2, 3, 1)
	R = R.ChangeTurf(/turf/floor/dirt/dust/regolith, FALSE, FALSE)
	var/turf/D = locate(3, 3, 1)
	D = D.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/space_probe_crew/H = new(D)
	space_check(isnull(H.outside_temperature_c(D)) && !H.outside_exposure_step(D) && H.oxyloss == 0, "ordinary ground keeps the climate temperature and is breathable")
	H.loc = R
	space_check(H.outside_temperature_c(R) == BARREN_AMBIENT_C, "regolith imposes its cold on someone standing in the open")
	space_check(H.outside_exposure_step(R) && H.oxyloss == HABITAT_SUFFOCATE_OXYLOSS && H.losebreath >= 1, "a person without a suit on regolith cannot breathe")
	space_check(HABITAT_SUFFOCATE_OXYLOSS > 5, "exposure outpaces the conscious oxygen recovery of 5 per life tick")
	space_check(!H.outside_exposure_step(null) && isnull(H.outside_temperature_c(null)), "no turf means no exposure")
	H.stat = DEAD
	space_check(!H.outside_exposure_step(R), "the dead do not breathe")
	H.stat = CONSCIOUS
	H.loc = null

// Submarine compartments share one ledger each instead of per-tile air.
/proc/space_submarine_checks()
	var/datum/flooding_controller/space_probe_test/F = new
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

	// Nobody connected: the air does not tick. Players connected, nobody aboard:
	// a breached compartment still loses air.
	var/before = json_encode(G.to_list())
	F.world_awake = FALSE
	F.air_tick(1, list(), list(SUB_COMP_GALLEY = 1))
	space_check(json_encode(G.to_list()) == before, "an empty world's air does not tick, even with a breach")
	F.world_awake = TRUE
	F.air_tick(1, list(), list(SUB_COMP_GALLEY = 1))
	space_check(G.pressure_kpa() < 100 && G.co2 == 0, "a breached compartment leaks while players are in the world, even with nobody aboard")
	G.oxygen = 21 * 3
	G.inert = 79 * 3

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

// Phase 2: propellant, launch pad, crewed lander and the landed lander.
/proc/space_flight_payload(list/flight = null)
	var/list/P = list("v" = 1, "kind" = "character", "owner" = "spacetester", "name" = "Test Crew", "gender" = MALE, "age" = 30,
		"look" = list(), "skills" = list(), "nutrition" = 100, "water" = 100, "items" = list())
	for (var/key in flight)
		P[key] = flight[key]
	return P

/proc/space_flight_checks()
	var/datum/chemical_reaction/rocket_propellant/mix = new
	space_check(mix.result == "rocket_propellant" && mix.required_reagents["hydrazine"] == 2 && mix.required_reagents["nitric_acid"] == 1 && mix.result_amount == 3, "propellant mixes from hydrazine and nitric acid")
	space_check(!!get_space_survey_map("barren") && space_flight_destination_ok("barren") && !space_flight_destination_ok("gaia") && !space_flight_destination_ok("../barren"), "only worlds with a survey map can be flown to")

	var/turf/T = locate(7, 7, 1)
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = new(T)
	space_check(!pad.approved && !pad.accepts_arrivals() && findtext(pad.closed_reason(), "admin"), "a new launch pad waits for an admin and never takes arrivals")
	space_check(!length(pad.peer_choices()) && !pad.approve("barren", "admin"), "outside a region group a pad can lead nowhere")
	space_check(isnull(new /obj/structure/region_gate(T).travel_extra(null)) && isnull(pad.travel_extra(null)), "ordinary trips carry no flight")
	var/obj/structure/crewed_lander/L = new(locate(7, 6, 1))
	space_check(L.find_pad() == pad, "a lander beside the pad finds it")
	var/datum/reagents/fuel = new(500)
	fuel.add_reagent("gasoline", 100)
	space_check(L.add_propellant(fuel) == 0 && L.propellant == 0, "the lander refuses gasoline")
	fuel.add_reagent("rocket_propellant", 350)
	space_check(L.add_propellant(fuel) == 300 && L.propellant == 300 && fuel.get_reagent_amount("rocket_propellant") == 50, "the lander takes exactly 300 units of propellant")
	var/mob/living/human/space_probe_crew/H = new(L.loc)
	space_check(!length(L.crew()) && findtext(L.launch_refusal(H), "admin"), "an unapproved pad keeps the lander grounded")
	qdel(L)

	var/list/flight = list("lander" = "gaia-1-1234", "landing" = list(1, 1), "surveyed" = 1, "rough" = 0)
	space_check(space_flight_payload_ok(space_flight_payload()) && space_flight_payload_ok(space_flight_payload(flight)), "payloads with and without a flight are accepted")
	space_check(region_travel_decode(json_encode(space_flight_payload(flight))) && region_travel_decode(json_encode(space_flight_payload())), "a flight payload survives the travel decoder")
	var/list/bad_cell = flight.Copy()
	bad_cell["landing"] = list(0, 3)
	var/list/bad_flag = flight.Copy()
	bad_flag["rough"] = 2
	var/list/long_id = flight.Copy()
	var/long = ""
	for (var/i in 1 to 65)
		long += "a"
	long_id["lander"] = long
	var/list/stray = space_flight_payload()
	stray["landing"] = list(1, 1)
	space_check(!space_flight_payload_ok(space_flight_payload(bad_cell)) && !space_flight_payload_ok(space_flight_payload(bad_flag)) && !space_flight_payload_ok(space_flight_payload(long_id)) && !space_flight_payload_ok(stray), "malformed flights are refused")
	space_check(!region_travel_decode(json_encode(space_flight_payload(bad_cell))), "the travel decoder drops a malformed flight")

	var/list/P = space_flight_payload(flight)
	space_check(isnull(space_flight_arrival_turf(space_flight_payload(), TRUE)) && isnull(space_flight_arrival_turf(P, FALSE)), "only arriving flights build a lander")
	var/turf/at = space_flight_arrival_turf(P, TRUE)
	var/obj/structure/landed_lander/LL = space_landed_lander("gaia-1-1234")
	space_check(at && LL && get_turf(LL) == at && at.x <= 5 && at.y <= 5, "the first arrival sets the lander down in its survey cell")
	space_check(space_flight_arrival_turf(P, TRUE) == at && landed_landers.len == 1, "the rest of the crew join the same lander")
	var/decks = 0
	for (var/turf/floor/lander_deck/D in range(1, at))
		decks++
	var/obj/structure/bed/lander_bunk/bunk = locate() in range(1, at)
	space_check(decks == 9 && bunk && bunk.anchored && bunk.loc != at, "the lander lays a 3x3 deck with a bunk beside its core")
	space_check(bunk && bunk.valid_character_bed(H), "the bunk can be claimed as a home bed")
	var/turf/floor/lander_deck/deck = locate(at.x + 1, at.y + 1, 1)
	space_check(deck.outside_air_breathable() && deck.outside_ambient_c() == 20, "the cabin starts sealed, breathable and warm")
	space_check(space_near(LL.oxygen_reserve, 432) && LL.power_seconds == 10800, "the reserves last a full crew three hours")
	space_check(issaved(LL.cabin_oxygen) && issaved(LL.power_seconds) && !issaved(LL.air), "the cabin saves as plain numbers, not its ledger datum")
	var/before = json_encode(LL.cabin().to_list())
	LL.process()
	space_check(json_encode(LL.cabin().to_list()) == before && LL.power_seconds == 10800, "the cabin does not tick while nobody is connected")
	space_check(LL.life_support(10, 4) && space_near(LL.cabin().oxygen_kpa(), 21) && LL.power_seconds == 10790 && space_near(LL.oxygen_reserve, 432 - 0.4), "with power the core tops up the oxygen a crew breathes")
	LL.life_support(10, 4)
	space_check(LL.cabin().co2_kpa() <= 0.4 + 0.0001 && LL.cabin().temperature == 20, "with power the core scrubs CO2 and holds the heat")
	space_check(LL.life_support(1e6, 4) && LL.power_seconds == 10770, "a long gap counts as one capped step")
	H.loc = deck
	space_check(LL.breathers() == 1, "people on the deck count as breathers")
	H.stat = DEAD
	space_check(LL.breathers() == 0, "the dead do not breathe")
	H.loc = null
	LL.power_seconds = 0
	for (var/i in 1 to 200)
		LL.life_support(10, 4)
	space_check(!deck.outside_air_breathable() && deck.outside_ambient_c() < 20, "without power the cabin goes cold and stale")
	LL.air = null
	space_check(!LL.cabin().breathable() && LL.cabin().temperature < 20, "the cabin rebuilds from its saved numbers")
	var/turf/regolith = locate(8, 8, 1)
	regolith = regolith.ChangeTurf(/turf/floor/dirt/dust/regolith, FALSE, FALSE)
	space_check(space_landing_z(8, 8) == 1, "a lander sets down on the only level")

	var/datum/research_node/flight_node = get_research_node("crewed_flight")
	space_check(flight_node && flight_node.mode == RESEARCH_MODE_ANALYSIS && flight_node.era_tier == 9 && ("planetary_survey" in flight_node.prereqs), "Crewed Flight follows Planetary Survey and is not an era capstone")
	space_check(get_recipe_node_req("/obj/structure/region_gate/trail_marker/launch_pad") == "crewed_flight" && get_recipe_node_req("/obj/structure/crewed_lander") == "crewed_flight", "the pad and the lander are gated on Crewed Flight")

// Phase 3: habitat modules, hatches, the airlock pump and life support.
/obj/structure/life_support/electrolyser/space_test/has_power()
	return TRUE
/obj/structure/life_support/scrubber/space_test/has_power()
	return TRUE
/obj/structure/life_support/heater/space_test/has_power()
	return TRUE

/proc/space_habitat_checks()
	space_check(habitat_module_refusal(locate(2, 2, 1), null) && habitat_module_refusal(null, null), "a module that would not fit is refused")
	var/obj/structure/habitat_core/Q = habitat_unfold(locate(10, 12, 1), "quarters")
	var/walls = 0
	var/floors = 0
	for (var/turf/T in block(locate(8, 10, 1), locate(12, 14, 1)))
		if (istype(T, /turf/wall/habitat_shell))
			walls++
		else if (istype(T, /turf/floor/habitat))
			floors++
	space_check(Q && walls == 16 && floors == 9 && length(Q.ring()) == 16 && length(Q.interior()) == 9, "a kit unfolds into a 3x3 floor inside a 16-tile hull")
	var/bunks = 0
	for (var/obj/structure/bed/lander_bunk/B in range(1, Q))
		bunks++
	space_check(bunks == 2 && Q.kind == "quarters" && Q.breaches() == 0, "quarters come with two bunks and a sealed hull")
	var/turf/floor/habitat/F = locate(9, 11, 1)
	space_check(space_near(Q.air().pressure_kpa(), 100) && F.outside_air_breathable() && F.outside_ambient_c() == 20, "a new module is pressurised, breathable and warm")
	space_check(habitat_module_site(locate(13, 12, 1)) == locate(14, 12, 1) && habitat_module_site(locate(10, 15, 1)) == locate(10, 16, 1), "a kit unpacked near a module snaps to dock beside it")
	space_check(habitat_module_refusal(locate(14, 12, 1), null) == null && habitat_module_refusal(locate(12, 12, 1), null), "docking shares a hull but never overlaps a floor")

	var/obj/structure/habitat_core/airlock/A = habitat_unfold(locate(14, 12, 1), "airlock", /obj/structure/habitat_core/airlock, NORTH)
	var/obj/structure/simple_door/habitat_hatch/inner = locate() in locate(12, 12, 1)
	var/obj/structure/simple_door/habitat_hatch/outer = locate() in locate(16, 12, 1)
	space_check(inner && outer && !(locate(/obj/structure/simple_door/habitat_hatch) in locate(14, 14, 1)), "a docked airlock gets a shared inner hatch and its outer hatch on the far side")
	space_check(Q.breaches() == 0 && A.breaches() == 0 && Q.neighbour_through(locate(12, 12, 1)) == A, "closed hatches keep both modules sealed")
	var/turf/floor/habitat/H = locate(12, 12, 1)
	space_check(H.habitat_core() && H.outside_air_breathable(), "a hatch tile shares a neighbouring module's air")

	A.air().oxygen = 0
	A.air().co2 = 0
	A.air().inert = 0
	inner.density = FALSE
	space_check(length(Q.open_neighbours()) == 1 && Q.breaches() == 0, "an open hatch to a module is not a breach")
	Q.step_air(1, 0)
	space_check(space_near(Q.air().pressure_kpa(), A.air().pressure_kpa()) && Q.air().pressure_kpa() < 51 && Q.air().pressure_kpa() > 49, "an open hatch shares the air of two modules")
	inner.density = TRUE
	var/before = Q.air().oxygen + Q.air().inert + A.air().oxygen + A.air().inert
	space_check(isnull(A.pump("down")) && A.air().pressure_kpa() < 0.01 && Q.air().pressure_kpa() > 95, "pumping down moves the airlock's air into the module")
	space_check(isnull(A.pump("up")) && abs(A.air().pressure_kpa() - Q.air().pressure_kpa()) < 0.01, "pressurising evens the airlock with the module")
	var/after = Q.air().oxygen + Q.air().inert + A.air().oxygen + A.air().inert
	space_check(after < before && after > before * 0.9, "the hand pump loses a little air each way")
	outer.density = FALSE
	space_check(A.breaches() == 1 && A.pump("down"), "an open outer hatch is a breach and stops the pump")
	var/p = A.air().pressure_kpa()
	A.step_air(1, 0)
	space_check(A.air().pressure_kpa() < p, "the airlock vents through its open outer hatch")
	outer.density = TRUE

	var/turf/hole = locate(10, 14, 1)
	hole = hole.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	space_check(Q.breaches() == 1 && habitat_ring_core(hole) == Q && habitat_patchable(hole) && !habitat_patchable(F) && !habitat_patchable(locate(12, 12, 1)), "a missing hull panel is a breach a patch can close")
	hole.ChangeTurf(/turf/wall/habitat_shell, FALSE, FALSE)
	space_check(Q.breaches() == 0, "a patched hull is sealed again")

	var/mob/living/human/space_probe_crew/crew = new(F)
	space_check(Q.breathers() == 1, "people inside are counted as breathers")
	crew.loc = null

	var/datum/habitat_ledger/L = Q.air()
	L.oxygen = 0
	var/obj/structure/life_support/electrolyser/unpowered = new(locate(9, 13, 1))
	unpowered.water = 100
	space_check(!unpowered.work(L, 2) && L.oxygen == 0, "an uncabled electrolyser does nothing")
	qdel(unpowered)
	var/obj/structure/life_support/electrolyser/space_test/E = new(locate(9, 13, 1))
	space_check(!E.work(L, 2) && L.oxygen == 0, "an electrolyser without water does nothing")
	E.water = 100
	space_check(E.work(L, 2) && space_near(L.oxygen, 0.2) && space_near(E.water, 99.9), "an electrolyser turns water into oxygen")
	var/obj/structure/life_support/scrubber/space_test/S = new(locate(11, 13, 1))
	L.co2 = 9
	space_check(S.work(L, 2) && space_near(L.co2, 8.8), "a scrubber strips CO2")
	L.co2 = 1
	space_check(!S.work(L, 2) && L.co2 == 1, "a scrubber leaves CO2 below its target")
	var/obj/structure/life_support/heater/space_test/W = new(locate(11, 11, 1))
	L.temperature = 0
	space_check(W.work(L, 2) && L.temperature == 1, "a heater warms the module")
	var/o = L.oxygen
	Q.step_air(2, 0)
	space_check(L.oxygen > o && L.temperature > 1, "the core runs the machines inside it each step")
	var/stored = json_encode(L.to_list())
	Q.process()
	space_check(json_encode(Q.air().to_list()) == stored, "modules do not tick while nobody is connected")
	space_check(issaved(Q.air_oxygen) && issaved(Q.kind) && !issaved(Q.ledger), "a module saves its air as plain numbers on the core")
	Q.ledger = null
	space_check(json_encode(Q.air().to_list()) == stored, "the air rebuilds from those numbers")

	var/obj/structure/habitat_core/G = habitat_unfold(locate(10, 17, 1), "greenhouse")
	var/obj/structure/hydroponics_tray/tray = locate() in locate(9, 18, 1)
	space_check(G && tray && !(locate(/obj/structure/simple_door/habitat_hatch) in locate(10, 15, 1)), "a greenhouse comes with trays and only docks at the spacing")
	if (tray)
		tray.crop = "wheat"
		tray.stage = 1
		G.air().co2 = 1
		var/oxygen_before = G.air().oxygen
		G.step_air(2, 0)
		space_check(G.air().co2 < 1 && G.air().oxygen > oxygen_before, "growing plants turn CO2 into oxygen")

	var/datum/research_node/sealed = get_research_node("sealed_habitats")
	var/datum/research_node/support = get_research_node("life_support")
	space_check(sealed && support && ("crewed_flight" in sealed.prereqs) && ("sealed_habitats" in support.prereqs) && sealed.mode == RESEARCH_MODE_ANALYSIS && support.mode == RESEARCH_MODE_ANALYSIS, "Sealed Habitats and Life Support follow Crewed Flight as ordinary nodes")
	space_check(get_recipe_node_req("/obj/item/habitat_kit/airlock") == "sealed_habitats" && get_recipe_node_req("/obj/item/habitat_sealant") == "sealed_habitats" && get_recipe_node_req("/obj/structure/life_support/electrolyser") == "life_support", "module kits and machines are gated on their nodes")

// Phase 4: pressure suits and surface hazards.
/mob/living/human/space_probe_crew/rad_act(amount)
	radiation += amount

/proc/space_eva_checks()
	var/turf/R = locate(2, 3, 1)
	R = R.ChangeTurf(/turf/floor/dirt/dust/regolith, FALSE, FALSE)
	var/mob/living/human/space_probe_crew/H = new(R)
	var/obj/item/clothing/suit/pressure_suit/S = new(H)
	var/obj/item/clothing/head/pressure_helmet/M = new(H)
	var/obj/item/pressure_tank/A = new(H)
	H.wear_suit = S
	H.back = A
	space_check(!H.sealed_against_outside(), "a suit without its helmet does not seal")
	H.head = M
	space_check(H.sealed_against_outside() && A.air_seconds == SUIT_TANK_SECONDS && S.integrity == SUIT_INTEGRITY_MAX, "suit, helmet and a full tank seal the wearer")
	space_check(!H.outside_exposure_step(R) && H.oxyloss == 0 && A.air_seconds == SUIT_TANK_SECONDS - SUIT_LIFE_SECONDS, "a sealed wearer breathes from the tank on regolith")
	space_check(H.outside_temperature_c(R) == SUIT_ROOM_C && S.heater_charge == SUIT_HEATER_SECONDS - SUIT_LIFE_SECONDS, "the suit heater holds room temperature and drains its battery")
	S.heater_charge = 0
	space_check(H.outside_temperature_c(R) == BARREN_AMBIENT_C + SUIT_UNHEATED_INSULATION_C, "a flat heater leaves only the suit's insulation")
	S.heater_charge = SUIT_HEATER_SECONDS
	space_check(pressure_crossed(301, 299, SUIT_LOW_TANK_SECONDS) && !pressure_crossed(299, 297, SUIT_LOW_TANK_SECONDS), "low-air warnings fire once, as the tank crosses the line")

	H.handle_suit_punctures(BRUTE, 2, "chest")
	space_check(S.integrity == SUIT_INTEGRITY_MAX, "a graze does not wear the suit")
	H.handle_suit_punctures(BRUTE, 10, "chest")
	space_check(S.integrity == SUIT_INTEGRITY_MAX - 5, "hits wear down the suit's integrity")
	S.integrity = SUIT_LEAKY_INTEGRITY
	var/air = A.air_seconds
	H.outside_exposure_step(R)
	space_check(A.air_seconds == air - SUIT_LIFE_SECONDS * SUIT_LEAK_MULTIPLIER, "a badly worn suit leaks and empties the tank faster")
	space_check(S.wear_down(SUIT_LEAKY_INTEGRITY) && !H.sealed_against_outside(), "a torn suit no longer seals")
	space_check(H.outside_exposure_step(R) && H.oxyloss == HABITAT_SUFFOCATE_OXYLOSS, "a torn suit leaves the wearer suffocating")
	H.oxyloss = 0
	S.integrity = SUIT_INTEGRITY_MAX
	A.air_seconds = 0
	space_check(!H.sealed_against_outside(), "an empty tank does not seal")
	var/obj/item/pressure_suit_patch/P = new(R)
	space_check(!P.patch(S, null) && !QDELETED(P), "a patch kit is kept when the suit needs no patching")

	var/obj/structure/habitat_core/Q = habitat_unfold(locate(5, 15, 1), "storage")
	var/datum/habitat_ledger/L = Q.air()
	var/oxygen = L.oxygen
	var/used = pressure_tank_refill_from_ledger(A, L, null, Q)
	space_check(A.air_seconds == SUIT_TANK_SECONDS && space_near(used, SUIT_TANK_SECONDS * HABITAT_BREATH_PER_SECOND) && space_near(L.oxygen, oxygen - used), "a tank refills from a module's oxygen")
	A.air_seconds = 0
	L.oxygen = HABITAT_MIN_OXYGEN_KPA * L.volume + 1
	pressure_tank_refill_from_ledger(A, L, null, Q)
	space_check(space_near(L.oxygen, HABITAT_MIN_OXYGEN_KPA * L.volume) && space_near(A.air_seconds, 1 / HABITAT_BREATH_PER_SECOND), "refilling never leaves the module unbreathable")
	space_check(issaved(S.integrity) && issaved(S.heater_charge) && issaved(A.air_seconds), "suit and tank keep what is left as saved numbers")

	// Hazards.
	space_check(barren_ambient_c() == BARREN_AMBIENT_C && barren_hazard_start("cold") && barren_ambient_c() == BARREN_AMBIENT_C - BARREN_COLD_SNAP_DROP_C && R.outside_ambient_c() == barren_ambient_c(), "a cold snap drives the surface temperature down")
	barren_hazards_step(BARREN_COLD_SECONDS, FALSE)
	space_check(barren_ambient_c() == BARREN_AMBIENT_C && !barren_cold_seconds, "a cold snap ends on its timer")
	H.radiation = 0
	barren_hazard_start("flare")
	H.barren_hazard_exposure(R)
	space_check(H.radiation == BARREN_FLARE_DOSE, "a solar flare irradiates people on open ground")
	var/turf/floor/habitat/F = locate(5, 15, 1)
	H.loc = F
	H.radiation = 0
	H.outside_exposure_step(F)
	space_check(H.radiation == 0 && !F.barren_open_ground() && R.barren_open_ground(), "a module shelters its occupants from a flare")
	H.loc = R
	barren_hazards_step(BARREN_FLARE_SECONDS, FALSE)
	space_check(!barren_flare_seconds && !barren_hazard_start("nonsense"), "a flare passes and unknown hazards are refused")
	var/area/caribbean/nomads/barren/plain = new
	var/area/elsewhere = new /area/caribbean/nomads
	space_check(barren_solar_factor(plain) == 1, "clear skies leave solar output alone")
	barren_hazard_start("dust")
	H.eye_blurry = 0
	H.barren_hazard_exposure(R)
	space_check(H.eye_blurry >= BARREN_DUST_BLUR && barren_solar_factor(plain) == BARREN_DUST_SOLAR_FACTOR && barren_solar_factor(elsewhere) == 1, "a dust storm blurs sight outside and chokes barren solar arrays")
	barren_hazards_step(BARREN_DUST_SECONDS, FALSE)
	space_check(!barren_dust_seconds, "a dust storm blows out on its timer")
	H.loc = null

	var/turf/hit = barren_meteor_strike(Q)
	space_check(istype(hit, /turf/floor/dirt/dust/regolith/crater) && Q.breaches() == 1 && habitat_patchable(hit), "a meteorite holes a module's hull with a patchable breach")
	space_check(isnull(barren_meteor_strike()), "meteorites only strike modules in the barren area")
	barren_hazard_last_pulse = -1
	space_check(!barren_hazards_pulse() && !barren_hazards_pulse(), "hazards roll at most once a minute")

	var/datum/research_node/suits = get_research_node("pressure_suits")
	space_check(suits && ("sealed_habitats" in suits.prereqs) && suits.mode == RESEARCH_MODE_ANALYSIS, "Pressure Suits follows Sealed Habitats as an ordinary node")
	space_check(get_recipe_node_req("/obj/item/clothing/suit/pressure_suit") == "pressure_suits" && get_recipe_node_req("/obj/item/pressure_tank") == "pressure_suits" && get_recipe_node_req("/obj/item/pressure_suit_patch") == "pressure_suits", "suits, tanks and patches are gated on Pressure Suits")

// Phase 5: surface mining, ice and printed kits.
/obj/structure/reagent_dispensers/ice_melter/space_test/has_power()
	return TRUE

/proc/space_mining_checks()
	var/turf/R = locate(2, 3, 1)
	R = R.ChangeTurf(/turf/floor/dirt/dust/regolith, FALSE, FALSE)
	var/turf/D = locate(3, 3, 1)
	D = D.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/obj/structure/drill/regolith_rig/rig = new(R)
	rig.anchored = TRUE
	var/list/table = R.drill_ore_table()
	var/only_table = TRUE
	var/saw_ice = FALSE
	for (var/i = 1, i <= 200, i++)
		var/ore = rig.drill_ore()
		if (!(ore in table))
			only_table = FALSE
		if (ore == /obj/item/stack/ore/ice)
			saw_ice = TRUE
	space_check(only_table && saw_ice && !(/obj/item/stack/ore/gold in table), "a drill on regolith brings up the barren ore table, ice included")
	space_check(rig.valid_drill_site(), "the regolith rig drills open regolith")
	rig.loc = D
	space_check(!rig.valid_drill_site() && isnull(D.drill_ore_table()) && (rig.drill_ore() in rig.ore_types), "the rig refuses ordinary dirt, where drills keep the mainland table")
	qdel(rig)

	var/obj/structure/reagent_dispensers/ice_melter/unpowered = new(D)
	var/obj/item/stack/ore/ice/I = new(D)
	I.amount = 30
	space_check(!unpowered.melt_ice(I) && I.amount == 30, "an uncabled ice melter melts nothing")
	qdel(unpowered)
	var/obj/structure/reagent_dispensers/ice_melter/space_test/M = new(D)
	space_check(M.melt_ice(I) == SURFACE_MELTER_CAPACITY / SURFACE_ICE_WATER && M.reagents.get_reagent_amount("water") == SURFACE_MELTER_CAPACITY && I.amount == 30 - SURFACE_MELTER_CAPACITY / SURFACE_ICE_WATER, "the ice melter turns ice into water up to its capacity")
	space_check(!M.melt_ice(I) && I.amount == 10, "a full melter takes no more ice")
	var/obj/structure/life_support/electrolyser/E = new(D)
	E.water = E.water_max - 50
	space_check(E.melt_ice(I) == 2 && E.water == E.water_max - 10 && I.amount == 8, "the electrolyser melts ice into its own water tank")

	factory_load_recipes()
	var/datum/factory_recipe/kit = factory_recipes["printed habitat module kit"]
	var/datum/factory_recipe/tank = factory_recipes["printed suit air tank"]
	var/datum/factory_recipe/patch = factory_recipes["printed hull patch kit"]
	space_check(!factory_recipe_errors.len && kit && kit.tier == 4 && kit.node == "off_world_mining" && kit.output_type == /obj/item/habitat_kit && kit.inputs[/obj/item/stack/material/glass] == 10, "the 3D printer prints module kits from steel and glass after Off-world Mining")
	space_check(tank && tank.tier == 4 && tank.node == "pressure_suits" && patch && patch.node == "sealed_habitats", "the 3D printer prints suit tanks and hull patches")
	var/datum/research_node/mining = get_research_node("off_world_mining")
	space_check(mining && ("pressure_suits" in mining.prereqs) && mining.mode == RESEARCH_MODE_ANALYSIS, "Off-world Mining follows Pressure Suits as an ordinary node")
	space_check(get_recipe_node_req("/obj/structure/drill/regolith_rig") == "off_world_mining" && get_recipe_node_req("/obj/structure/reagent_dispensers/ice_melter") == "off_world_mining", "the rig and the melter are gated on Off-world Mining")

// Phase 5: rovers.
/obj/structure/rover_charger/space_test/has_power()
	return TRUE

/proc/space_rover_checks()
	var/turf/R = locate(2, 3, 1)
	R = R.ChangeTurf(/turf/floor/dirt/dust/regolith, FALSE, FALSE)
	var/turf/D = locate(3, 3, 1)
	D = D.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/obj/structure/engine/internal/diesel/diesel = new(D)
	space_check(diesel.engine_has_air(), "a combustion engine runs where there is air")
	diesel.loc = R
	space_check(!diesel.engine_has_air(), "a combustion engine cannot run on barren ground")
	qdel(diesel)
	var/obj/structure/engine/internal/electric_drive/drive = new(R)
	space_check(drive.engine_has_air() && ("rover_charge" in drive.fuels) && drive.name == "electric drive", "the electric drive runs anywhere on battery charge")

	// A sealed rover laid out by hand on regolith.
	var/obj/structure/vehicleparts/axis/car/rover_sealed/A = new(R)
	A.engine = drive
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/rover_battery/charged/B = new(R)
	drive.fueltank = B
	var/list/frames = list()
	for (var/dx = 0, dx <= 1, dx++)
		var/turf/T = locate(2 + dx, 5, 1)
		T = T.ChangeTurf(/turf/floor/dirt/dust/regolith, FALSE, FALSE)
		var/obj/structure/vehicleparts/frame/car/wyoming/lfc/rover/F = new(T)
		F.axis = A
		A.components += F
		frames += F
	A.fill_cabin()
	var/datum/habitat_ledger/L = A.cabin()
	space_check(A.cabin_volume() == 2 && L.breathable() && L.temperature == ROVER_CABIN_C && A.oxygen_reserve > 0 && issaved(A.cabin_oxygen) && !issaved(A.cabin_air), "a new sealed rover cabin is breathable and saves plain numbers")
	space_check(A.cabin_breaches() == 0, "closed doors keep the cabin sealed")
	var/obj/structure/vehicleparts/frame/F1 = frames[1]
	F1.w_left[7] = TRUE
	space_check(A.cabin_breaches() == 1, "an open door is a breach")
	F1.w_left[7] = FALSE

	var/aboard = A.cabin_occupants()
	var/mob/living/human/space_probe_crew/H = new(F1.loc)
	space_check(H.rover_cabin() == L && A.cabin_occupants() == aboard + 1, "a person on the rover is in its cabin")
	barren_hazard_start("flare")
	H.radiation = 0
	space_check(!H.outside_exposure_step(F1.loc) && H.oxyloss == 0 && H.radiation == 0 && H.outside_temperature_c(F1.loc) == ROVER_CABIN_C, "the cabin lets its crew breathe, keeps them warm and shelters them from a flare")
	barren_hazards_step(BARREN_FLARE_SECONDS, FALSE)
	var/charge = A.battery_charge()
	L.oxygen = 0
	A.cabin_step(2, 1)
	space_check(L.oxygen > 0 && A.battery_charge() < charge, "the cabin panel tops oxygen up from the reserve on battery charge")
	B.reagents.clear_reagents()
	L.oxygen = 0
	L.temperature = 0
	A.cabin_step(2, 1)
	space_check(L.oxygen == 0 && L.temperature < 0, "a flat battery leaves the cabin unrefreshed and cooling")
	space_check(H.outside_exposure_step(F1.loc) && H.oxyloss == HABITAT_SUFFOCATE_OXYLOSS, "a stale cabin suffocates its crew")
	H.oxyloss = 0

	var/obj/structure/rover_cabin_panel/P = new(F1.loc)
	var/obj/item/pressure_tank/T2 = new(F1.loc)
	var/reserve = A.oxygen_reserve
	P.attackby(T2, null)
	space_check(P.rover() == A && T2.air_seconds == 0 && space_near(A.oxygen_reserve, reserve + SUIT_TANK_SECONDS * HABITAT_BREATH_PER_SECOND), "a suit tank empties into the cabin's oxygen reserve")

	var/obj/structure/rover_charger/space_test/C = new(locate(4, 6, 1))
	space_check(C.rover_battery() == B && C.charge(B) == ROVER_CHARGE_PER_USE && B.reagents.get_reagent_amount("rover_charge") == ROVER_CHARGE_PER_USE, "a powered charger charges a parked rover's battery")
	B.reagents.add_reagent("rover_charge", ROVER_BATTERY_UNITS)
	space_check(!C.charge(B), "a full battery takes no more charge")
	H.loc = D
	space_check(isnull(H.rover_cabin()), "off the rover there is no cabin")
	H.loc = null

	var/obj/structure/car_workshop/rover_bay/bay = new(locate(15, 3, 1))
	space_check(bay.model_size("Sealed rover") == 4 && bay.costs("Sealed rover")["steel"] == 70 && bay.costs("Open rover")["steel"] == 50 && !bay.costs("SMC Falcon") && !bay.allowed(null), "the rover bay builds only rovers, after Surface Vehicles")
	var/obj/effects/premadevehicles/rover/sealed/plan = new(null, TRUE)
	var/has_drive = FALSE
	var/has_panel = FALSE
	for (var/coords in plan.tocreate)
		if (/obj/structure/engine/internal/electric_drive in plan.tocreate[coords])
			has_drive = TRUE
		if (/obj/structure/rover_cabin_panel in plan.tocreate[coords])
			has_panel = TRUE
	space_check(has_drive && has_panel && plan.axis == /obj/structure/vehicleparts/axis/car/rover_sealed, "the sealed rover template has an electric drive and a cabin panel")
	qdel(plan)
	var/datum/research_node/vehicles = get_research_node("surface_vehicles")
	space_check(vehicles && ("off_world_mining" in vehicles.prereqs) && get_recipe_node_req("/obj/structure/car_workshop/rover_bay") == "surface_vehicles" && get_recipe_node_req("/obj/structure/rover_charger") == "surface_vehicles", "Surface Vehicles gates the rover bay and charger")

// Phase 6: closed loops, the propellant plant and flights home.
/obj/structure/life_support/water_recycler/space_test/has_power()
	return TRUE
/obj/structure/life_support/oxygen_reclaimer/space_test/has_power()
	return TRUE
/obj/structure/reagent_dispensers/propellant_plant/space_test/has_power()
	return TRUE

/proc/space_selfsuff_checks()
	var/obj/structure/habitat_core/Q = locate() in locate(10, 12, 1)
	var/obj/structure/life_support/electrolyser/E = locate() in locate(9, 13, 1)
	space_check(Q && E, "the quarters module from the habitat checks is still there")
	if (!Q || !E)
		return
	var/datum/habitat_ledger/L = Q.air()
	var/obj/structure/life_support/water_recycler/unpowered = new(locate(10, 11, 1))
	var/mob/living/human/space_probe_crew/crew = new(locate(9, 11, 1))
	space_check(!unpowered.work(L, 10) && unpowered.water == 0, "an uncabled water recycler reclaims nothing")
	qdel(unpowered)
	var/obj/structure/life_support/water_recycler/space_test/R = new(locate(10, 11, 1))
	E.water = 0
	space_check(R.work(L, 10) && space_near(E.water, Q.breathers() * SPACE_RECYCLE_WATER_PER_SECOND * 10) && R.water == 0, "the recycler reclaims the crew's water and feeds the electrolyser first")
	E.water = E.water_max
	R.work(L, 10)
	space_check(space_near(R.water, Q.breathers() * SPACE_RECYCLE_WATER_PER_SECOND * 10), "with the electrolyser full the recycler keeps the water")
	R.water = SPACE_RECYCLER_CAPACITY - 0.01
	R.work(L, 100)
	space_check(R.water == SPACE_RECYCLER_CAPACITY, "the recycler holds no more than its tank")
	var/obj/item/weapon/reagent_containers/glass/beaker/cup = new(locate(10, 11, 1))
	var/room = cup.reagents.maximum_volume
	R.attackby(cup, crew)
	space_check(cup.reagents.get_reagent_amount("water") == room && space_near(R.water, SPACE_RECYCLER_CAPACITY - room), "water is drawn from the recycler with a container")
	crew.loc = null
	R.water = 0
	space_check(!R.work(L, 10) && R.water == 0, "an empty module reclaims no water")
	qdel(cup)
	qdel(R)

	var/obj/structure/life_support/oxygen_reclaimer/space_test/O = new(locate(10, 11, 1))
	L.co2 = 9
	var/oxygen = L.oxygen
	space_check(O.work(L, 2) && space_near(L.co2, 8.8) && space_near(L.oxygen, oxygen + 0.1), "the reclaimer scrubs CO2 and returns half of it as oxygen")
	L.co2 = 0.1
	space_check(!O.work(L, 2) && L.co2 == 0.1, "the reclaimer leaves CO2 below its target")
	qdel(O)

	var/turf/D = locate(15, 3, 1)
	var/obj/structure/reagent_dispensers/propellant_plant/cold = new(D)
	cold.ice = 5
	space_check(!cold.crack() && cold.ice == 5, "an uncabled propellant plant cracks nothing")
	qdel(cold)
	var/obj/structure/reagent_dispensers/propellant_plant/space_test/P = new(D)
	var/obj/item/stack/ore/ice/I = new(D)
	I.amount = 30
	space_check(P.load_ice(I) == 30 && P.ice == 30 && QDELETED(I), "the plant takes ice")
	space_check(P.crack() && P.ice == 29 && P.reagents.get_reagent_amount("rocket_propellant") == SPACE_PLANT_PROPELLANT_PER_ICE, "one piece of ice cracks into propellant")
	P.process()
	space_check(P.ice == 29, "the plant does not run while nobody is connected")
	var/obj/item/stack/ore/ice/more = new(D)
	more.amount = 100
	space_check(P.load_ice(more) == SPACE_PLANT_ICE_MAX - 29 && P.ice == SPACE_PLANT_ICE_MAX && more.amount == 29, "the plant holds no more than its hopper")
	while (P.crack())
		continue
	space_check(P.reagents.get_reagent_amount("rocket_propellant") == SPACE_PLANT_CAPACITY && P.ice == SPACE_PLANT_ICE_MAX - SPACE_PLANT_CAPACITY / SPACE_PLANT_PROPELLANT_PER_ICE + 1, "the plant stops when its tank is full")
	var/obj/structure/crewed_lander/lander = new(locate(16, 3, 1))
	space_check(lander.add_propellant(P.reagents) == LANDER_PROPELLANT && lander.propellant == LANDER_PROPELLANT, "a full plant fuels a lander")
	qdel(lander)
	qdel(P)
	qdel(more)

	var/old_mainland = shard_group.mainland
	var/old_region = shard_group.region
	shard_group.mainland = "gaia"
	shard_group.region = "barren"
	space_check(space_flight_destination_ok("gaia") && space_flight_return_ok("gaia") && !space_flight_return_ok("barren"), "a mapped world can fly home to the mainland")
	shard_group.region = "gaia"
	space_check(!space_flight_destination_ok("gaia") && !space_flight_return_ok("gaia"), "the mainland cannot fly to itself")
	shard_group.mainland = old_mainland
	shard_group.region = old_region
	var/list/home = list("lander" = "barren-1-1234", "return" = 1)
	space_check(space_flight_payload_ok(space_flight_payload(home)) && region_travel_decode(json_encode(space_flight_payload(home))), "a flight home survives the travel decoder")
	var/list/bad_return = home.Copy()
	bad_return["return"] = 2
	var/list/landing_home = home.Copy()
	landing_home["landing"] = list(1, 1)
	var/list/stray_return = space_flight_payload()
	stray_return["return"] = 1
	space_check(!space_flight_payload_ok(space_flight_payload(bad_return)) && !space_flight_payload_ok(space_flight_payload(landing_home)) && !space_flight_payload_ok(stray_return), "malformed flights home are refused")
	var/before = landed_landers.len
	space_check(isnull(space_flight_arrival_turf(space_flight_payload(home), TRUE)) && landed_landers.len == before, "a flight home builds no lander and arrives like any traveller")
	var/mob/living/human/space_probe_crew/pilot = new(D)
	var/list/sent = json_decode(pilot.region_travel_payload(list(), null, FALSE, home))
	space_check(sent["return"] == 1 && sent["lander"] == "barren-1-1234" && isnull(sent["landing"]), "the travel payload carries the flight home")
	qdel(pilot)

	var/datum/research_node/local = get_research_node("local_resources")
	space_check(local && ("surface_vehicles" in local.prereqs) && local.era_tier == 9 && local.mode == RESEARCH_MODE_ANALYSIS, "Local Resources follows Surface Vehicles as an ordinary node")
	space_check(get_recipe_node_req("/obj/structure/reagent_dispensers/propellant_plant") == "local_resources" && get_recipe_node_req("/obj/structure/life_support/water_recycler") == "life_support" && get_recipe_node_req("/obj/structure/life_support/oxygen_reclaimer") == "life_support", "the plant is gated on Local Resources and the recyclers on Life Support")

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
		space_exposure_checks()
		space_flight_checks()
		space_habitat_checks()
		space_eva_checks()
		space_mining_checks()
		space_rover_checks()
		space_selfsuff_checks()
	catch(var/exception/e)
		space_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = space_failures, "runtime_error" = space_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
