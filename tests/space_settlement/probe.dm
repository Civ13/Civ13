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
	catch(var/exception/e)
		space_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = space_failures, "runtime_error" = space_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
