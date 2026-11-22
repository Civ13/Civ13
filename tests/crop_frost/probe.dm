// Native probe for crop frost and frost covers (docs/crop-frost.md).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/crop_frost/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 96
	maxy = 64
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/cf_probe/New()
	return
/area/caribbean/cf_probe
var/cf_failures = 0
var/cf_runtime_error = FALSE
/proc/cf_check(condition, label)
	if (!condition)
		cf_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	cf_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		config = new
		config.webhook_can_fire = FALSE
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/cf_probe
		cf_checks()
	catch(var/exception/e)
		cf_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = cf_failures, "runtime_error" = cf_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/cf_area(climate, x1, x2, location = AREA_OUTSIDE)
	var/area/caribbean/cf_probe/A = new
	A.climate = climate
	A.location = location
	for (var/turf/T in block(locate(x1, 1, 1), locate(x2, world.maxy, 1)))
		A.contents += T
	return A

// Even air over the whole grid: calm and clear, at temp with a dew point just under.
/proc/cf_air(temp)
	var/datum/weather_air_grid/G = weather_air
	for (var/i = 1, i <= G.temp.len, i++)
		G.temp[i] = temp
		G.dew[i] = temp - 0.5
		G.cloud[i] = 0
		G.wind_x[i] = 0
		G.wind_y[i] = 0

/proc/cf_checks()
	season = "SPRING"
	time_of_day = "Early Morning"
	map.winddirection = "West"
	map.windspeedvar = 0
	map.valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	cf_area("temperate", 1, 96)
	cf_area("temperate", 60, 70, AREA_INSIDE)
	weather_centres_clear()
	weather_systems_clear()
	weather_storm_count = 0
	var/turf/field = locate(24, 32, 1)
	var/turf/plot = locate(26, 32, 1)
	var/turf/barn = locate(64, 32, 1)

	cf_check(crop_frost_cover_warmth("mulch") == 2 && crop_frost_cover_warmth("row_cover") == 3 && crop_frost_cover_warmth("cloche") == 5 && !crop_frost_cover_warmth(""), "mulch keeps off 2 degrees, a row cover 3, a cloche 5")

	// Before the air grid exists nothing freezes.
	weather_air = null
	var/obj/structure/farming/plant/wheat/W = new(field)
	W.stage = 4
	cf_check(!W.frost_plant_step() && W.stage == 4, "no grid, no frost")

	weather_air_grid()
	// A mild dawn.
	cf_air(5)
	cf_check(!W.frost_plant_step() && W.stage == 4, "a mild dawn leaves the crop alone")
	// A light frost nips it back once a night.
	cf_air(0)
	cf_check(weather_frost_at(field) && W.frost_now() == "frost", "a still, clear night at 0 C is a frost")
	W.frost_plant_step()
	cf_check(W.stage == 3, "frost nips a growing crop back a stage ([W.stage])")
	W.frost_plant_step()
	cf_check(W.stage == 3, "but only once a night")
	// Wind keeps the frost off.
	W.frost_nipped_at = -100000
	for (var/i = 1, i <= weather_air.wind_x.len, i++)
		weather_air.wind_x[i] = 6
	cf_check(W.frost_now() == "" && !W.frost_plant_step() && W.stage == 3, "a breeze stops a light frost")
	// A hard freeze kills it.
	cf_air(-6)
	cf_check(W.frost_now() == "freeze" && W.frost_plant_step() && W.stage > W.readyStageMax, "a hard freeze kills a young crop ([W.name])")

	// Covers.
	var/mob/living/human/H = new /mob/living/human(field)
	var/obj/structure/farming/plant/wheat/C = new(plot)
	C.stage = 4
	var/obj/item/stack/material/cloth/cloth = new(plot, 5)
	C.attackby(cloth, H)
	cf_check(C.frost_cover == "row_cover" && cloth.amount == 3 && C.frost_cover_drawn == "row_cover", "two cloth make a row cover over the crop")
	cf_air(-1.5)
	cf_check(C.frost_now() == "" && !C.frost_plant_step() && C.stage == 4, "it keeps off a light frost")
	cf_air(-6)
	cf_check(C.frost_now() == "frost" && !C.frost_plant_step() && C.stage == 3, "and turns a hard freeze into a light frost")
	C.attack_hand(H)
	var/cloth_left = 0
	for (var/obj/item/stack/material/cloth/S in plot)
		cloth_left += S.amount
	cf_check(!C.frost_cover && cloth_left == 5, "an empty hand takes it off and gives the cloth back ([cloth_left])")
	var/obj/item/stack/material/glass/glass = new(plot, 2)
	C.attackby(glass, H)
	cf_check(C.frost_cover == "cloche" && QDELETED(glass), "two glass make a cloche")
	C.frost_nipped_at = -100000
	cf_air(-8)
	cf_check(C.frost_now() == "frost", "a cloche keeps a crop alive through -8 C")
	var/obj/item/stack/material/cloth/more = new(locate(40, 40, 1), 5)
	C.attackby(more, H)
	cf_check(C.frost_cover == "cloche" && more.amount == 5, "one cover at a time")
	var/list/states = icon_states('icons/obj/frost_covers.dmi')
	cf_check(("mulch" in states) && ("row_cover" in states) && ("cloche" in states), "each cover has its art")
	var/list/notes = C.farming_diagnostics(1)
	cf_check(findtext(jointext(notes, " "), "glass cloche"), "examining the crop names its cover")

	// Hardy crops, and crops under a roof.
	cf_air(-8)
	var/obj/structure/farming/plant/turnip/T = new(locate(30, 32, 1))
	T.stage = 4
	cf_check(!T.frost_plant_step() && T.stage == 4, "a winter-hardy crop shrugs off a hard freeze")
	var/obj/structure/farming/plant/wheat/I = new(barn)
	I.stage = 4
	cf_check(!I.frost_plant_step() && I.stage == 4, "a crop under a roof is safe")
