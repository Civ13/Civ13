// Ships between worlds (code/modules/naval/ship_crossing.dm,
// docs/ship-crossing.md): a built hull is packed as a record, taken off the
// water, checked as a travel payload, and built again from the record off
// the far side of the map with her mast, chest and deck cargo; the crew of a
// voyage find her there.
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

/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/count_in(turf/T, path)
	. = 0
	for (var/atom/movable/M in T)
		if (istype(M, path))
			.++

/proc/probe_payload(list/ship, voyage = "v-1")
	var/list/P = list("v" = 1, "kind" = "character", "owner" = "probeowner", "name" = "Probe Sailor", "gender" = MALE, "age" = 30,
		"look" = list(), "skills" = list(), "nutrition" = 400, "water" = 400, "items" = list(), "voyage" = voyage)
	if (ship)
		P["ship"] = ship
	return json_encode(P)

/proc/naval_checks()
	naval_fixture()
	// ---- The Gull: 4 x 3 planks on the deep sea, a rigged mast, a chest, a crowbar ----
	for (var/x = 40, x <= 43, x++)
		for (var/y = 30, y <= 32, y++)
			hull_lay(x, y)
	// Steered by a steering oar and rowed from a bench (rowing_bench.dm).
	var/obj/structure/hull_tiller/tiller = new /obj/structure/hull_tiller/steering_oar(locate(41, 31, 2))
	naval_check(isnull(tiller.commission("Gull", EAST)) && tiller.craft, "the Gull is commissioned")
	var/obj/structure/bed/chair/wood/rowing_bench/bench = new(locate(43, 31, 2))
	bench.set_dir(NORTH)
	var/obj/structure/vehicleparts/movement/sail/premade/mast = new(locate(42, 31, 2))
	naval_check(mast.sails, "her mast is rigged")
	var/obj/structure/closet/crate/chest = new(locate(40, 30, 2))
	for (var/atom/movable/A in chest)
		qdel(A)
	var/obj/item/stack/material/wood/planks = new(chest, 20)
	naval_check(planks.loc == chest, "twenty planks are stowed in the chest")
	new /obj/item/weapon/crowbar(locate(43, 32, 2))
	var/obj/item/stack/material/wood/water_planks = new(locate(46, 31, 2), 5)

	// ---- Packing ----
	// A structure goes whole (ship_crossing_cargo.dm); an animal somebody plays never does.
	var/obj/structure/probe_rock/rock = new(locate(43, 30, 2))
	var/mob/living/simple_animal/goat/played = new(locate(42, 30, 2))
	played.ckey = "probegoatplayer"
	var/refusal = sea_crossing_pack(tiller)
	naval_check(istext(refusal) && findtext(refusal, "is somebody") && !findtext(refusal, "probe rock"), "an animal somebody plays keeps her in port and is named, a rock does not ([refusal])")
	played.ckey = null
	qdel(played)
	qdel(rock)
	// Her ledger and how her sail is carried cross with her (hull_ledger.dm, hull_rigging.dm).
	var/datum/hull_ledger/ledger = tiller.craft.ledger
	naval_check(!isnull(ledger), "she keeps a hull ledger")
	if (ledger)
		ledger.water = 3
		ledger.seams = 0.5
		ledger.old_anchor = FALSE
	mast.canvas = SAIL_REEFED
	mast.torn = TRUE
	var/list/packed = sea_crossing_pack(tiller)
	naval_check(islist(packed), "with it ashore she packs ([istext(packed) ? packed : "ok"])")
	var/list/R = islist(packed) ? packed["record"] : list()
	var/list/crew = islist(packed) ? packed["crew"] : list()
	naval_check(length(R["tiles"]) == 12 && R["name"] == "Gull" && R["dir"] == EAST && !crew.len, "the record holds her 12 tiles, her name and heading, and no crew")
	naval_check(sea_crossing_record_ok(R), "the record is a valid record")
	var/text = json_encode(R)
	naval_check(findtext(text, "/obj/structure/vehicleparts/movement/sail/premade") && findtext(text, "stack:wood") && findtext(text, "/obj/item/weapon/crowbar"), "the mast, the planks in the chest and the crowbar are in it")
	naval_check(findtext(text, "/obj/structure/bed/chair/wood/rowing_bench") && R["helm"] == "/obj/structure/hull_tiller/steering_oar", "so are her rowing bench and her steering oar")

	// ---- Bad records ----
	var/list/bad = json_decode(text)
	var/list/first_tile = bad["tiles"][1]
	first_tile[3] = list(list("c", "/obj/structure/probe_rock", 2, 100))
	naval_check(!sea_crossing_record_ok(bad), "a record naming a type that is not a floor is refused")
	bad = json_decode(text)
	bad["tiles"] += list(list(0, 0, list(list("c", "/obj/covers/repairedfloor/ship", 2, 100))))
	naval_check(!sea_crossing_record_ok(bad), "a record with the same tile twice is refused")
	bad = json_decode(text)
	for (var/list/tile in bad["tiles"])
		for (var/list/E in tile[3])
			if (E[1] == "k")
				E[4] = list(list("stack:wood", 99999))
	naval_check(!sea_crossing_record_ok(bad), "a chest with more planks than a stack holds is refused")
	bad = json_decode(text)
	bad["helm"] = "/obj/structure/probe_rock"
	naval_check(!sea_crossing_record_ok(bad), "a helm that is not a tiller is refused")

	// ---- As a payload ----
	naval_check(islist(region_travel_decode(probe_payload(R))), "a crew member carrying her decodes")
	naval_check(islist(region_travel_decode(probe_payload(null))), "a crew member without her decodes")
	naval_check(!region_travel_decode(probe_payload(bad)), "a payload with a bad ship is refused")
	var/long_text = probe_payload(null)
	// Past a character's cap (128 KiB) but within a ship carrier's (384 KiB).
	long_text = copytext(long_text, 1, length(long_text)) + ",\"pad\":\"[jointext(new /list(140000), "x")]\"}"
	naval_check(!region_travel_decode(long_text), "a long payload without a ship is refused")

	// ---- Off the water ----
	var/turf/pivot = get_turf(tiller)
	sea_crossing_strip(tiller)
	qdel(tiller)
	var/left = 0
	for (var/x = 40, x <= 43, x++)
		for (var/y = 30, y <= 32, y++)
			var/turf/T = locate(x, y, 2)
			left += count_in(T, /obj/covers) + count_in(T, /obj/structure) + count_in(T, /obj/item)
	naval_check(!left && !crafts.len, "stripped, nothing of her is left on the water ([left])")
	naval_check(sea_crossing_water(pivot), "her water is open sea again")
	naval_check(water_planks.loc == locate(46, 31, 2), "planks floating beside her are not taken")

	// ---- The far side ----
	var/list/offsets = list()
	for (var/list/tile in R["tiles"])
		offsets += list(list(tile[1], tile[2]))
	var/turf/anchorage = sea_crossing_anchorage(offsets, list(EAST))
	naval_check(anchorage && anchorage.x >= world.maxx - 64 && anchorage.x > 50 && anchorage.z == 2, "an anchorage is found off the east edge ([anchorage ? "[anchorage.x],[anchorage.y],[anchorage.z]" : "none"])")
	var/turf/landward = sea_crossing_anchorage(offsets, list(WEST))
	naval_check(landward && landward.x > 20, "off the west the sand is passed over for the first deep water ([landward ? landward.x : "none"])")
	var/obj/structure/hull_tiller/built = sea_crossing_build(R, anchorage, "v-1")
	naval_check(built && built.craft && built.craft.name == "Gull" && built.craft.anchored, "she is built, named and at anchor")
	var/datum/craft_body/built/B = built ? built.body() : null
	naval_check(B && B.tile_count() == 12 && B.heading() == EAST, "her hull is 12 tiles, bow east")
	var/turf/mast_turf = locate(anchorage.x + 1, anchorage.y, 2)
	var/obj/structure/vehicleparts/movement/sail/new_mast = locate() in mast_turf
	naval_check(new_mast && new_mast.sails, "her mast stands rigged where it stood")
	naval_check(new_mast && new_mast.canvas == SAIL_REEFED && new_mast.torn, "its sail is still reefed and still torn")
	var/datum/hull_ledger/arrived = built && built.craft ? built.craft.ledger : null
	naval_check(arrived && arrived.water == 3 && arrived.seams == 0.5 && !arrived.old_anchor, "her bilge water and her seams crossed with her ([arrived ? "[arrived.water] [arrived.seams]" : "no ledger"])")
	var/list/old_record = json_decode(json_encode(R))
	old_record -= "ledger"
	naval_check(sea_crossing_record_ok(old_record), "a record from before ledgers crossed is still a valid record")
	var/list/bad_ledger = json_decode(json_encode(R))
	bad_ledger["ledger"] = list("water" = "lots")
	naval_check(!sea_crossing_record_ok(bad_ledger), "a ledger that is not numbers is refused")
	var/turf/chest_turf = locate(anchorage.x - 1, anchorage.y - 1, 2)
	var/obj/structure/closet/crate/new_chest = locate() in chest_turf
	var/obj/item/stack/material/wood/new_planks = new_chest ? locate() in new_chest : null
	naval_check(new_planks && new_planks.amount == 20 && length(new_chest.contents) == 1, "her chest holds exactly the twenty planks")
	naval_check(locate(/obj/item/weapon/crowbar) in locate(anchorage.x + 2, anchorage.y + 1, 2), "the crowbar lies where it lay")
	var/obj/structure/bed/chair/wood/rowing_bench/new_bench = locate() in locate(anchorage.x + 2, anchorage.y, 2)
	naval_check(new_bench && new_bench.dir == NORTH && istype(built, /obj/structure/hull_tiller/steering_oar), "her bench is where it stood, facing as it faced, and she is steered by her oar")
	naval_check(sea_crossing_ship("v-1") == built && !sea_crossing_ship("v-2"), "her crew find her by the voyage")
	naval_check(isnull(sea_crossing_build(R, anchorage, "v-3")), "she is not built twice on the same water")

	// ---- Arrivals ----
	var/list/crewman = region_travel_decode(probe_payload(null))
	var/turf/aboard = sea_crossing_arrival_turf(crewman, TRUE)
	naval_check(aboard && B && B.contains(aboard), "a crew member of her voyage comes aboard her")
	var/list/carrier = region_travel_decode(probe_payload(R, "v-9"))
	var/turf/second = sea_crossing_arrival_turf(carrier, TRUE)
	var/obj/structure/hull_tiller/other = sea_crossing_ship("v-9")
	var/datum/craft_body/built/OB = other ? other.body() : null
	naval_check(other && other != built && second && OB && OB.contains(second), "the carrier of another voyage builds her own ship and comes aboard")
	naval_check(isnull(sea_crossing_arrival_turf(list("name" = "x"), TRUE)), "a traveller of no voyage is left to the trails")

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
