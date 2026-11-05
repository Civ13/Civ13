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
		space_submarine_checks()
		space_exposure_checks()
	catch(var/exception/e)
		space_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = space_failures, "runtime_error" = space_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
