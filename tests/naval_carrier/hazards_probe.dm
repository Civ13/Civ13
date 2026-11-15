// Chart hazards and sectors (code/modules/craft/chart_hazards.dm,
// docs/craft-core.md): standing and passing hazards, drift and countdowns,
// fields that strike a craft going too fast, storms that set her off her
// course, paired wormholes, harbour sectors that keep hazards out, the
// boarding rule of a sector, and the tables of the open sea and orbit charts.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/datum/craft_drive/probe_push
	thrust = 1000

/obj/structure/probe_gun
	name = "probe gun"
	anchored = TRUE
/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

// A plank laid the way a player lays one, with its first update already run.
/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/hull_planks(turf/T)
	. = 0
	for (var/obj/covers/C in T)
		.++

// The steps a half minute covers at her speed: a gliding hull makes one tile
// a step. TRUE when every step moved her.
/proc/hull_leg(datum/craft/C)
	var/steps = 0
	while (steps < C.speed * VESSEL_TILES_PER_STEP)
		if (!C.sail_tick())
			return FALSE
		steps++
	return steps > 0

/datum/chart/probe_sky
	name = "probe chart"
	mode = CHART_MODE_STEERED
	width = 100
	height = 100

/datum/chart/probe_sky/standing_hazards()
	return list(list(/datum/chart_hazard/field, 20, 20, 3), list(/datum/chart_hazard/field, 50, 50, 2))

/datum/chart/probe_sky/passing_table()
	return list(/datum/chart_hazard/storm = 1)

/datum/chart_token/probe_ship
	var/moored = FALSE

/datum/chart_token/probe_ship/exposed()
	return !moored

/datum/craft/probe_ship
	var/list/heard = list()

/datum/craft/probe_ship/crew_message(text)
	heard += text

/proc/naval_checks()
	naval_fixture()
	// ---- Sectors and standing hazards ----
	var/datum/chart/probe_sky/sky = new
	var/datum/chart_sector/harbour/haven = new("the haven", 44, 44, 56, 56)
	naval_check(sky.add_sector(haven) && sky.sector_at(50, 50) == haven && isnull(sky.sector_at(43, 50)) && haven.kind == CHART_SECTOR_HARBOUR, "a harbour sector covers its box and nothing beyond")
	naval_check(!sky.hazard_allowed(50, 50) && !sky.hazard_allowed(42, 50, 2) && sky.hazard_allowed(41, 50, 2), "it keeps hazards out, by their whole size")
	naval_check(sky.lay_standing() == 1 && sky.hazards.len == 1 && sky.lay_standing() == 0, "the standing field outside it is laid once and the one inside it is not")
	var/datum/chart_hazard/field/rocks = sky.hazards[1]
	// Nothing passes until the passing checks below.
	sky.hazards_on = FALSE
	naval_check(istype(rocks) && rocks.x == 20 && rocks.y == 20 && rocks.radius == 3 && !rocks.passing && !rocks.lifetime, "the field lies where the chart says and stays")
	naval_check(findtext(haven.describe(), "The haven: no hazard comes here"), "the sector reads its rules ([haven.describe()])")

	// ---- A field strikes a craft that is too fast ----
	var/datum/craft/probe_ship/C = new
	C.name = "Petrel"
	var/datum/chart_token/probe_ship/T = new
	T.name = "Petrel"
	T.craft = C
	C.token = T
	sky.add_token(T, 20, 20)
	rocks.strike_chance = 100
	T.vx = 0.4
	sky.hazard_step(2)
	naval_check(C.heard.len == 1 && findtext(C.heard[1], "among the rocks of an asteroid field") && findtext(C.heard[1], "Keep under 0.5 a second") && T.vx == 0.4, "entering the field slowly her crew is warned and she is not struck ([C.heard.len ? C.heard[1] : ""])")
	T.vx = 1
	sky.hazard_step(2)
	naval_check(T.vx == 0.5 && C.heard.len == 2 && findtext(C.heard[2], "A rock strikes the hull and takes the way off her"), "too fast, a rock strikes her and halves her speed")
	sky.hazard_step(2)
	naval_check(T.vx == 0.5 && C.heard.len == 2, "at the safe speed she is left alone and not warned twice")
	T.vx = 1
	T.moored = TRUE
	sky.hazard_step(2)
	naval_check(T.vx == 1 && C.heard.len == 2, "a craft lying at a place is out of the hazard's reach")
	T.moored = FALSE
	T.vx = 0
	var/list/read = sky.hazard_lines(T)
	naval_check(read.len == 1 && findtext(read[1], "She lies in an asteroid field") && findtext(read[1], "Keep under 0.5"), "the helm reads that she lies in it ([jointext(read, " / ")])")
	sky.add_token(T, 20, 30)
	sky.hazard_step(2)
	read = sky.hazard_lines(T)
	naval_check(read.len == 1 && findtext(read[1], "An asteroid field, 7 squares across: 10 squares south") && !rocks.inside.len, "outside it the helm reads its size, distance and bearing ([jointext(read, " / ")])")
	sky.add_token(T, 50, 50)
	T.sensor_range = 15
	read = sky.hazard_lines(T)
	naval_check(read.len == 1 && findtext(read[1], "The haven"), "in the haven the helm reads the sector and no hazard in sight ([jointext(read, " / ")])")

	// ---- A struck hull ----
	for (var/x = 40, x <= 44, x++)
		hull_lay(x, 10)
		hull_lay(x, 11)
	var/obj/structure/hull_tiller/tiller = new(locate(42, 10, 2))
	naval_check(isnull(tiller.commission("Wren", EAST)), "the Wren is commissioned")
	var/datum/craft/W = tiller.craft
	var/obj/covers/hit = W.body.hazard_damage(100000)
	naval_check(istype(hit) && hit.health == max(1, round(hit.maxhealth * CHART_STRIKE_FLOOR)) && !QDELETED(hit), "a strike batters one plank of a built hull down to a quarter and no further ([hit ? hit.health : "none"] of [hit ? hit.maxhealth : 0])")
	var/was = hit ? hit.health : 0
	for (var/i = 1, i <= 30, i++)
		W.body.hazard_damage(100000)
	var/holed = 0
	for (var/turf/P in W.body.cells())
		if (!hull_planks(P))
			holed++
	naval_check(hit.health == was && !holed && W.body.tile_count() == 10, "thirty more strikes hole nothing")

	// ---- Storms ----
	var/datum/chart_hazard/storm/squall = new
	squall.radius = 2
	squall.blow = 90
	squall.push = 0.01
	squall.lifetime = 0
	naval_check(sky.add_hazard(squall, 70, 70) && !sky.add_hazard(new /datum/chart_hazard/storm, 50, 50), "a squall is put on the chart, but not in the haven")
	sky.add_token(T, 70, 71)
	T.vx = 0
	T.vy = 0
	var/heard_before = C.heard.len
	sky.hazard_step(2)
	naval_check(abs(T.vx - 0.02) < 0.0001 && abs(T.vy) < 0.0001 && C.heard.len == heard_before + 1 && findtext(C.heard[C.heard.len], "squall closes round the Petrel"), "the squall sets her east and her crew is told ([T.vx], [T.vy], [C.heard.len - heard_before], [C.heard[C.heard.len]])")
	naval_check(sky.interference_at(70, 71) == 15 && sky.interference_at(70, 73) == 0, "it muddies sensors inside it only")
	for (var/i = 1, i <= 200, i++)
		sky.hazard_step(2)
	naval_check(round(T.speed(), 0.01) == 1.5, "she is never blown faster than half again her top speed ([T.speed()])")
	T.moored = TRUE
	T.vx = 0
	squall.vx = 1
	sky.hazard_step(2)
	naval_check(squall.x == 72 && findtext(squall.motion_text(), "drifting east"), "a squall drifts ([squall.x])")
	squall.x = 99
	sky.hazard_step(2)
	naval_check(squall.x == 99 && squall.vx == -1, "and turns back from the edge of the chart")
	squall.x = 60
	squall.y = 50
	sky.hazard_step(2)
	naval_check(squall.x == 60 && squall.vx == 1, "and from the haven")
	squall.vx = 0
	squall.lifetime = 4
	naval_check(findtext(squall.time_text(), "passing in under a minute"), "a passing squall shows its countdown ([squall.time_text()])")
	sky.hazard_step(2)
	sky.hazard_step(2)
	naval_check(!(squall in sky.hazards) && QDELETED(squall) && sky.hazards.len == 1, "and is gone when it runs out")

	// ---- Wormholes ----
	var/datum/chart_hazard/wormhole/hole = new
	hole.radius = 1
	hole.lifetime = 500
	naval_check(sky.add_hazard(hole, 10, 80) && hole.arrive(), "a wormhole opens")
	var/datum/chart_hazard/wormhole/far = hole.twin
	naval_check(far && far.twin == hole && (far in sky.hazards) && far.lifetime == 500 && chart_distance(hole.x, hole.y, far.x, far.y) >= 25 && sky.hazard_allowed(far.x, far.y, 1), "its other end opens far off, outside the haven, with the same time to live")
	T.moored = FALSE
	T.vx = 0
	T.vy = 0
	sky.add_token(T, 10, 80)
	heard_before = C.heard.len
	sky.hazard_step(2)
	naval_check(far && T.x == far.x && T.y == far.y && T.hazard_rest == CHART_WORMHOLE_REST && C.heard.len == heard_before + 1 && findtext(C.heard[C.heard.len], "throws her out of its other end"), "a craft that enters is thrown to the other end and her crew is told")
	sky.hazard_step(2)
	naval_check(far && T.x == far.x && T.hazard_rest == CHART_WORMHOLE_REST - 2, "the far end leaves her alone while she gets clear")
	sky.hazard_step(CHART_WORMHOLE_REST)
	sky.hazard_step(2)
	naval_check(T.x == 10 && T.y == 80, "staying in its mouth she is thrown back in time")
	naval_check(far && findtext(hole.advice(T), "other end at [round(far.x)], [round(far.y)]"), "the helm reads where it leads ([hole.advice(T)])")
	qdel(hole)
	naval_check(QDELETED(far) && sky.hazards.len == 1, "when one end closes so does the other")

	// ---- Passing hazards ----
	T.moored = TRUE
	sky.add_token(T, 50, 50)
	sky.hazards_on = TRUE
	sky.hazard_clock = 0
	naval_check(sky.passing_count() == 0, "no hazard is passing yet")
	sky.hazard_step(CHART_HAZARD_ROLL)
	var/datum/chart_hazard/storm/first = null
	for (var/datum/chart_hazard/H in sky.hazards)
		if (H.passing)
			first = H
	naval_check(sky.passing_count() == 1 && istype(first) && first.lifetime > 0 && first.radius >= 3 && sky.hazard_allowed(first.x, first.y, first.radius), "after a roll a squall from the chart's table is passing, clear of the haven")
	for (var/datum/chart_hazard/H in sky.hazards)
		if (H.passing)
			H.lifetime = 0
			H.vx = 0
			H.vy = 0
	for (var/i = 1, i <= 12, i++)
		sky.hazard_step(CHART_HAZARD_ROLL)
	naval_check(sky.passing_count() == CHART_HAZARD_CAP, "a chart holds no more passing hazards than its cap ([sky.passing_count()])")
	var/datum/chart/probe_sky/calm = new
	calm.hazards_on = FALSE
	calm.hazard_step(CHART_HAZARD_ROLL * 3)
	naval_check(!calm.hazards.len && !calm.standing_laid, "a chart with hazards switched off has none")
	chart_hazards_off = TRUE
	var/datum/chart/probe_sky/quiet = new
	quiet.hazard_step(CHART_HAZARD_ROLL * 3)
	naval_check(!quiet.hazards.len, "nor has any chart while the global switch is off")
	chart_hazards_off = FALSE

	// ---- The open sea and orbit charts ----
	var/datum/chart/open_sea/sea = new
	naval_check(sea.lay_standing() == OPEN_SEA_REEFS && sea.sectors.len == 1, "the open sea lays its reefs and its home waters sector ([sea.hazards.len])")
	var/datum/chart_sector/home = sea.sector_at(50, 50)
	var/reefs_ok = TRUE
	for (var/datum/chart_hazard/field/reef/R in sea.hazards)
		if (!sea.in_bounds(R.x - R.radius, R.y - R.radius) || !sea.in_bounds(R.x + R.radius, R.y + R.radius) || home.touches(R.x, R.y, R.radius))
			reefs_ok = FALSE
	naval_check(home && home.kind == CHART_SECTOR_HARBOUR && !home.hazards && home.boarding && reefs_ok, "the home waters are a harbour sector where boarding is still allowed, and every reef lies on the chart clear of them")
	var/list/sea_table = sea.passing_table()
	naval_check(sea_table.len == 1 && sea_table[/datum/chart_hazard/storm] == 1, "squalls pass over the open sea")
	var/datum/chart/open_sea/sea2 = new
	sea2.lay_standing()
	var/same = sea.hazards.len == sea2.hazards.len
	for (var/i = 1, same && i <= sea.hazards.len, i++)
		var/datum/chart_hazard/A = sea.hazards[i]
		var/datum/chart_hazard/B = sea2.hazards[i]
		if (A.x != B.x || A.y != B.y)
			same = FALSE
	naval_check(same, "the reefs lie in the same places every time the chart is made")
	var/datum/chart/orbit/space = new
	naval_check(space.lay_standing() == ORBIT_CHART_FIELDS && space.sectors.len == 1 && !space.hazard_allowed(50, 50), "the orbit chart lays its asteroid fields and keeps the beacon's space clear")
	var/list/space_table = space.passing_table()
	naval_check(space_table[/datum/chart_hazard/wormhole] && space_table[/datum/chart_hazard/storm/solar], "solar storms and wormholes pass in orbit")
	var/datum/chart_hazard/storm/solar/flare = new
	flare.shape()
	naval_check(!flare.vx && !flare.vy && !flare.push && flare.interference == 10 && flare.lifetime > 0, "a solar storm blinds sensors, stays put and passes")
	qdel(sea)
	qdel(sea2)
	qdel(space)

	// ---- The boarding rule of a sector ----
	for (var/x = 47, x <= 49, x++)
		hull_lay(x, 10)
	var/obj/structure/hull_tiller/tiller2 = new(locate(48, 10, 2))
	naval_check(isnull(tiller2.commission("Kite", EAST)), "the Kite is commissioned")
	var/datum/craft/K = tiller2.craft
	var/datum/chart/sea/S = sea_chart(2)
	S.refresh()
	var/datum/chart_sector/harbour/port = new("the roads", 1, 1, S.width, S.height)
	port.boarding = FALSE
	S.add_sector(port)
	naval_check(W.token && findtext(W.sector_boarding_refusal(), "The roads are harbour waters: no boarding there") && findtext(S.boarding_refusal(1, 1), "no boarding"), "a sector that forbids boarding says so ([W.sector_boarding_refusal()])")
	naval_check(!W.order_grapple(K) && findtext(W.last_refusal, "no boarding there") && !W.grapple, "and no grapple is thrown there ([W.last_refusal])")
	port.boarding = TRUE
	naval_check(isnull(W.sector_boarding_refusal()) && W.order_grapple(K) && W.grapple, "where boarding is allowed the lines go across ([W.last_refusal])")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
