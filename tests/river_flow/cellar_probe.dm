// Native probe for cellars and seepage (flood_cellars.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/river_flow/cellar_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 6
	maxz = 2
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/cellar_probe/New()
	return
/mob/living/human/cellar_probe/update_icons()
	return
/mob/living/human/cellar_probe/update_hair(update_icons = 1)
	return
/mob/living/human/cellar_probe/update_inv_head(update_icons = 1)
	return
/mob/living/human/cellar_probe/handle_hud_list()
	return
/mob/living/human/cellar_probe/update_inv_wear_mask(update_icons = 1)
	return
/mob/living/human/cellar_probe/New()
	species = new /datum/species/human
	return
var/sewer_failures = 0
var/sewer_runtime_error = FALSE
/proc/sewer_check(condition, label)
	if (!condition)
		sewer_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sewer_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/cellar_probe
		sewer_checks()
	catch(var/exception/e)
		sewer_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sewer_failures, "runtime_error" = sewer_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// A river down the east column; a basin (x 3-5, y 3-4) at level 1 inside a rim
// at level 3; ground at 1 elsewhere. A stone drain runs from the basin east
// through the rim to the river.
// Level 2 is the surface: a river down the east column, ground at 1 with a
// rise at 4 in column 2. Level 1 is the cellar level under it.
/proc/cellar_flood_text()
	var/list/lines = list("civ13-river-flood 2", "size 10 6", "z 2", "reaches 1", "r 1 0 10 3 60 60 6")
	for (var/r in 1 to 6)
		lines += "01010101010101010101"
	for (var/r in 1 to 6)
		lines += "141111111."
	lines += list("hollows 0", "hollow_rows 0")
	return jointext(lines, "\n")

/obj/structure/cellar_test_pump
	cellar_reach = 2

/obj/structure/cellar_test_pump/cellar_pumping()
	return TRUE

/proc/sewer_checks()
	map.persistence = TRUE
	var/datum/terrain_heights/H = new
	H.maxx = 10
	H.maxy = 6
	H.rows_by_z["2"] = list("1411111110", "1411111110", "1411111110", "1411111110", "1411111110", "1411111110")
	map.terrain_height_file = "probe"
	map.terrain_heights_cache = H
	var/datum/river_flood/F = river_flood_parse(cellar_flood_text(), 10, 6, 2)
	sewer_check(!F.error && F.z_level == 2, "the probe flood file parses ([F.error])")
	map.river_flood_cache = F
	map.river_flood_loaded = TRUE
	map.river_flood_state = list()
	F.published = map.river_flood_state
	for (var/y in 1 to 6)
		var/turf/W = locate(10, y, 2)
		W.ChangeTurf(/turf/floor/beach/water/deep)
	sewer_check(F.cellar_z() == 1, "the level under the surface is the cellar level ([F.cellar_z()])")

	var/turf/C = locate(5, 3, 1)
	var/turf/HIGH = locate(2, 3, 1)
	F.stage[1] = 0
	sewer_check(!flood_depth_at(C), "a cellar is dry while the river is low")
	F.stage[1] = 1
	sewer_check(abs(flood_depth_at(C) - 0.45) < 0.001 && flood_band(flood_depth_at(C)) == FLOOD_BAND_KNEE, "a river near the top of its banks seeps knee-deep into cellars ([flood_depth_at(C)])")
	sewer_check(!flood_depth_at(HIGH), "a cellar under high ground stays dry")
	sewer_check(!flood_depth_at(locate(5, 3, 2)), "the surface above is still dry")
	F.stage[1] = 0.5
	sewer_check(abs(flood_depth_at(C) - 0.375) < 0.001, "seepage grows as the river rises ([flood_depth_at(C)])")

	// Over its banks, the flood pours down any way down.
	F.stage[1] = 2
	sewer_check(abs(flood_depth_at(locate(5, 3, 2)) - 1) < 0.001 && abs(flood_depth_at(C) - 0.45) < 0.001, "with the surface flooded and no way down, only seepage comes in")
	new /obj/structure/multiz(locate(5, 3, 2))
	sewer_check(abs(flood_depth_at(C) - 1) < 0.001 && abs(flood_depth_at(locate(6, 3, 1)) - 0.45) < 0.001, "floodwater pours down a way down ([flood_depth_at(C)])")

	// Bailing and pumps keep cellars dry.
	F.bail_cellar(locate(5, 4, 1))
	sewer_check(!flood_depth_at(C) && !flood_depth_at(locate(6, 5, 1)) && flood_depth_at(locate(7, 3, 1)) > 0, "bailing dries the tiles around you")
	F.cellar_dry[C] = world.time - 1
	sewer_check(flood_depth_at(C) > 0, "the water comes back when the bailing stops")
	var/obj/structure/cellar_test_pump/P = new /obj/structure/cellar_test_pump(locate(8, 3, 1))
	cellar_pumps += P
	sewer_check(!flood_depth_at(locate(7, 3, 1)) && !flood_depth_at(locate(8, 5, 1)) && flood_depth_at(locate(5, 1, 1)) > 0, "a working pump keeps its reach dry")
	cellar_pumps -= P

	// Rock is not a cellar.
	var/turf/R = locate(4, 2, 1)
	R.ChangeTurf(/turf/wall/rockwall)
	R = locate(4, 2, 1)
	sewer_check(!flood_depth_at(R), "solid rock holds no water")
	sewer_check(!flood_depth_at(locate(10, 3, 1)), "nothing seeps under the river itself")

	pump_checks(F)
	tunnel_checks(F)

/proc/pump_checks(datum/river_flood/F)
	F.cellar_dry = list()
	F.stage[1] = 1
	var/turf/C = locate(5, 3, 1)
	sewer_check(flood_depth_at(C) > 0, "the cellar is seeping again")

	// A lever pump keeps its reach dry for a while after each stroke.
	var/obj/structure/cellar_pump/lever/L = new /obj/structure/cellar_pump/lever(locate(6, 4, 1))
	sewer_check((L in cellar_pumps) && !L.cellar_pumping() && flood_depth_at(C) > 0, "an idle lever pump does nothing")
	L.stroke()
	sewer_check(L.cellar_pumping() && !flood_depth_at(C) && !flood_depth_at(locate(9, 4, 1)) && flood_depth_at(locate(1, 1, 1)) > 0, "a stroke keeps the floor within three tiles dry")
	for (var/i in 1 to 20)
		L.stroke()
	sewer_check(L.pumped_until <= world.time + 3000, "strokes bank at most five minutes")
	L.pumped_until = world.time - 1
	sewer_check(flood_depth_at(C) > 0, "the water comes back when the pumping stops")
	qdel(L)

	// A steam mine pump runs on fuel and keeps a wide working dry.
	var/obj/structure/cellar_pump/steam/S = new /obj/structure/cellar_pump/steam(locate(2, 1, 1))
	S.fuel = 2
	S.on = TRUE
	S.cellar_minute()
	sewer_check(S.running && S.fuel == 1 && !flood_depth_at(locate(8, 5, 1)) && S.icon_state == "mine_pump_on", "a fired mine pump keeps everything within seven tiles dry and burns fuel")
	S.cellar_minute()
	sewer_check(!S.on && !S.running && flood_depth_at(locate(8, 5, 1)) > 0 && S.icon_state == "mine_pump", "out of fuel it stops")
	qdel(S)

	// A sump pump runs on its float switch, from the mains or its battery.
	var/obj/structure/cellar_pump/sump/P = new /obj/structure/cellar_pump/sump(locate(5, 4, 1))
	sewer_check(P.water_coming_in(), "the float switch feels water coming in")
	P.cellar_minute()
	sewer_check(P.running && P.battery == 59 && !flood_depth_at(C), "with no power it runs on its battery")
	sewer_check(P.water_coming_in(), "and still feels the water it is pumping")
	P.battery = 0
	P.cellar_minute()
	sewer_check(!P.running && flood_depth_at(C) > 0, "a flat battery and no power: the cellar floods")
	P.battery = 10
	F.stage[1] = 0
	P.cellar_minute()
	sewer_check(!P.water_coming_in() && !P.running && P.battery == 10, "with no water coming in it waits and spends nothing")
	F.stage[1] = 1
	P.on = FALSE
	P.cellar_minute()
	sewer_check(!P.running, "switched off it does nothing")
	qdel(P)

	// The minute step runs pumps on the cellar level.
	var/obj/structure/cellar_pump/steam/S2 = new /obj/structure/cellar_pump/steam(locate(2, 1, 1))
	S2.fuel = 5
	S2.on = TRUE
	F.drain_hollows()
	sewer_check(S2.fuel == 4 && S2.running, "the river tick steps cellar pumps")

// Floodwater pouring down a tunnel mouth runs along the tunnel to the roof.
/proc/tunnel_checks(datum/river_flood/F)
	for (var/obj/structure/P in cellar_pumps.Copy())
		cellar_pumps -= P
		qdel(P)
	F.cellar_dry = list()
	F.stage[1] = 2
	F.tunnel_started = FALSE
	var/turf/near = locate(3, 5, 1)
	var/turf/edge = locate(6, 5, 1)
	var/turf/far = locate(8, 5, 1)
	sewer_check(flood_depth_at(near) < 1, "a tunnel with no mouth only seeps ([flood_depth_at(near)])")
	var/obj/structure/multiz/ladder/ww2/tunneltop/pit/M = new(locate(3, 5, 2))
	sewer_check(M in tunnel_mouths, "a dug hole is a tunnel mouth")
	sewer_check(F.tunnel_mouth_pouring(M), "the flood pours down the hole")
	F.tunnel_checked = world.time - 600
	sewer_check(abs(flood_depth_at(near) - 1.5) < 0.001 && flood_band(flood_depth_at(near)) == FLOOD_BAND_DEEP, "the tunnel under the hole floods to the roof ([flood_depth_at(near)])")
	sewer_check(abs(flood_depth_at(edge) - 0.8) < 0.001, "the edge of the water is waist-deep ([flood_depth_at(edge)])")
	sewer_check(flood_depth_at(far) < 0.5, "tunnel further off is not flooded yet ([flood_depth_at(far)])")
	sewer_check(flood_airless(near) && !flood_airless(edge) && !flood_airless(locate(3, 5, 2)), "roof-high tunnel water leaves no air")
	var/mob/living/human/cellar_probe/H = new(locate(4, 5, 1))
	H.handle_drowning()
	sewer_check(H.drowning && H.swim_breath == H.swim_breath_max() + 9 && !H.getOxyLoss(), "caught in the flooded tunnel, you hold your breath with 10 s extra ([H.swim_breath])")
	for (var/i in 1 to 18)
		H.handle_drowning()
	sewer_check(!H.getOxyLoss(), "an untrained swimmer still holds their breath after 19 s")
	for (var/i in 1 to 40)
		H.handle_drowning()
	sewer_check(H.getOxyLoss() > 0 && H.swim_tiredness == 0, "out of breath you drown; there is nowhere to swim up to ([H.getOxyLoss()])")
	H.adjustOxyLoss(-500)
	H.loc = edge
	H.handle_drowning()
	sewer_check(!H.drowning && !H.getOxyLoss(), "at the waist-deep edge you can breathe")
	qdel(H)
	F.tunnel_checked = world.time - 1200
	sewer_check(abs(flood_depth_at(far) - 1.5) < 0.001, "the water runs further along the tunnel as it keeps pouring ([flood_depth_at(far)])")
	for (var/y in 1 to 6)
		var/turf/wall = locate(7, y, 1)
		wall.ChangeTurf(/turf/floor/dirt/underground/empty/packed)
	F.tunnel_checked = world.time - 600
	sewer_check(flood_depth_at(locate(8, 5, 1)) <= 0.8 && flood_depth_at(locate(5, 5, 1)) > 1, "packed earth holds the water back ([flood_depth_at(locate(8, 5, 1))])")
	qdel(M)
	sewer_check(!(M in tunnel_mouths), "a filled hole is no longer a mouth")
	F.tunnel_checked = world.time - 6000
	sewer_check(flood_depth_at(near) > 0, "the water does not vanish at once")
	F.tunnel_checked = world.time - 6000
	sewer_check(flood_depth_at(near) < 1 && !F.tunnel_fill.len, "once the hole is filled the water soaks away ([flood_depth_at(near)])")
	breach_checks(F)

// A cell opened under a lake or river pours like a mouth (underground_opened);
// shallows and swamp above seep a little (dug_underground.dm, "Water above").
/proc/breach_checks(datum/river_flood/F)
	F.stage[1] = 0
	F.tunnel_fill = list()
	var/turf/B = locate(9, 2, 1)
	var/turf/S = locate(9, 2, 2)
	S.ChangeTurf(/turf/floor/beach/water/deep)
	sewer_check(underground_above_cell(B) == "wet", "a lake lies over the cell")
	tunnel_breaches += B
	F.tunnel_checked = world.time - 600
	sewer_check(abs(flood_depth_at(B) - 1.5) < 0.001 && flood_airless(B), "a breach under a lake floods the tunnel to the roof, river low or not ([flood_depth_at(B)])")
	B.ChangeTurf(/turf/floor/dirt/underground/empty/packed)
	F.tunnel_checked = world.time - 6000
	flood_depth_at(locate(8, 2, 1))
	sewer_check(!F.tunnel_fill[locate(9, 2, 1)], "packing the breach stops the water")
	tunnel_breaches -= locate(9, 2, 1)
	S = locate(9, 2, 2)
	S.ChangeTurf(/turf/floor/dirt)
	var/turf/M = locate(2, 1, 1)
	locate(2, 1, 2).ChangeTurf(/turf/floor/beach/water/swamp)
	sewer_check(abs(flood_depth_at(M) - 0.3) < 0.001 && !flood_airless(M), "swamp above seeps ankle-deep into the cell below ([flood_depth_at(M)])")
	sewer_check(!F.flooding && F.may_be_wet(2, 1, 1) && !F.may_be_wet(2, 1, 2), "with the river low, the drawing still looks for water below ground")
	var/turf/U = locate(3, 1, 1)
	locate(3, 1, 2).ChangeTurf(/turf/floor/beach/water/swamp)
	U.ChangeTurf(/turf/sky/building/unformed)
	U = locate(3, 1, 1)
	sewer_check(!U.density && !flood_depth_at(U), "unformed rock under swamp holds no water")
	F.bail_cellar(M)
	sewer_check(!flood_depth_at(M), "bailing keeps the seep back")
