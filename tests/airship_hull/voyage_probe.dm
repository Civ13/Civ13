// Isolated airship-voyage probe. No world listener, remote peer or real save.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 2
	turf = /turf
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

var/voyage_probe_failures = 0
var/voyage_probe_runtime = FALSE

/world/Error(exception/e)
	voyage_probe_runtime = TRUE
	world.log << "Runtime: [e] [e.file]:[e.line]"

/obj/map_metadata/voyage_probe/New()
	return

/proc/voyage_probe_check(condition, label)
	if (!condition)
		voyage_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/proc/voyage_probe_run()
	try
		voyage_probe_scenarios()
	catch(var/exception/e)
		voyage_probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = voyage_probe_failures, "runtime_error" = voyage_probe_runtime, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	movementMachine = new
	map = new /obj/map_metadata/voyage_probe
	initialize_chemical_reagents()
	initialize_chemical_reactions()
	spawn(0)
		voyage_probe_run()

/proc/voyage_probe_scenarios()
	voyage_probe_check(!world.port, "the fixture has no listener")
	for (var/x = 1 to world.maxx)
		for (var/y = 1 to world.maxy)
			new /turf/floor/dirt(locate(x, y, 1))
			new /turf/sky/building(locate(x, y, 2))
	var/turf/T = locate(5, 20, 2)
	var/turf/W = get_step(T, WEST)
	var/turf/E = get_step(T, EAST)
	var/obj/covers/airship_deck/D = new(W)
	D.health -= 25
	new /obj/covers/airship_deck/aluminium(T)
	new /obj/covers/airship_deck/steel(E)
	var/obj/structure/airship_helm/helm = new(T)
	voyage_probe_check(!helm.commission("Halcyon", EAST), "a mixed hull commissions with the helm inside the deck")
	var/obj/structure/airship_gas_cell/rubber/G = new(W)
	G.gas = "helium"
	G.gas_amount = 37
	G.holes = 1
	G.health = 95
	G.update_icon()
	var/obj/structure/closet/crate/chest = new(E)
	var/obj/item/stack/material/rope/rope = new(chest, 3)
	var/obj/item/weapon/reagent_containers/glass/barrel/tank = new(E)
	tank.create_reagents(100)
	tank.reagents.add_reagent("water", 18, safety = TRUE)
	var/obj/structure/engine/internal/engine = new(T)
	engine.fueltank = tank
	var/list/ready = list()
	var/list/packed = helm.airship_voyage_pack(ready, WEST, 0.5)
	voyage_probe_check(islist(packed), "an actual mixed deck, partly filled damaged cell, tank, engine and nested cargo pack: [istext(packed) ? packed : "OK"]")
	if (!islist(packed))
		return
	var/list/R = packed["record"]
	voyage_probe_check(get_turf(G) == W && get_turf(helm) == T && rope.loc == chest && engine.fueltank == tank && tank.reagents.total_volume == 18, "packing does not move, refuel, heal or delete the source")
	voyage_probe_check(helm.airship_voyage_near(WEST) && !helm.airship_voyage_near(EAST), "the selected edge must be the edge ahead")
	var/obj/structure/airship_bomb_hatch/unsupported = new(W)
	voyage_probe_check(istext(helm.airship_voyage_pack(ready, WEST, null)) && get_turf(unsupported) == W, "unsupported fixtures stop the complete pack without moving them")
	qdel(unsupported)
	var/turf/new_pivot = locate(30, 20, 2)
	var/turf/wing = get_step(new_pivot, WEST)
	var/obj/item/stack/material/rope/obstacle = new(wing, 1)
	voyage_probe_check(!airship_voyage_clear(R, new_pivot) && !airship_voyage_build(R, new_pivot, null), "a loose item at a non-pivot tile blocks the whole footprint and nothing is built")
	qdel(obstacle)
	var/list/wire = json_decode(json_encode(R))
	var/flight = md5("voyage probe")
	var/list/P = list("airship_flight" = flight, "airship" = wire, "airship_seat" = list(-1, 0), "owner" = "probe")
	voyage_probe_check(airship_voyage_payload_ok(P), "a JSON round-trip preserves a valid flight record")
	var/list/bad = wire.Copy()
	var/list/tiles = bad["tiles"]
	var/list/disconnected = list(list(0, 0, "[/obj/covers/airship_deck]", NORTH, 10, list()), list(2, 0, "[/obj/covers/airship_deck]", NORTH, 10, list()))
	bad["tiles"] = disconnected
	voyage_probe_check(!airship_voyage_record_ok(bad), "a disconnected hull cannot be restored")
	bad["tiles"] = tiles + list(tiles[1])
	voyage_probe_check(!airship_voyage_record_ok(bad), "two records for one tile are refused")
	var/lift = G.lift()
	var/health = D.health
	var/gas_health = G.health
	// A chest can spill during the escrow wait. The originals still go once.
	rope.forceMove(E)
	airship_voyage_remove(helm, packed["objects"])
	voyage_probe_check(QDELETED(helm) && QDELETED(rope) && QDELETED(chest) && QDELETED(G), "confirmed removal leaves no spilled cargo or structural copy")
	var/turf/seat = airship_voyage_arrival(P, FALSE, locate(10, 10, 1))
	var/obj/structure/airship_helm/arrived = airship_voyage_find(flight)
	voyage_probe_check(istype(arrived) && get_turf(arrived) == T && seat == W, "a turned-back pilot takes the original deck position")
	if (!istype(arrived))
		return
	var/list/rider = list("airship_flight" = flight, "airship_seat" = list(1, 0))
	voyage_probe_check(airship_voyage_arrival(rider, FALSE, locate(10, 10, 1)) == E, "the other crew member goes to their own tile on the same ship")
	rider["airship_seat"] = list(0, 1)
	voyage_probe_check(airship_voyage_arrival(rider, FALSE, null) == T, "a seat outside the deck never drops a passenger")
	var/obj/structure/airship_gas_cell/rubber/new_cell = locate() in W
	var/obj/covers/airship_deck/new_deck = locate() in W
	var/obj/structure/closet/crate/new_chest = locate() in E
	var/obj/item/stack/material/rope/new_rope = locate() in new_chest
	var/obj/structure/engine/internal/new_engine = locate() in T
	voyage_probe_check(new_cell?.lift() == lift && new_cell?.health == gas_health && new_cell.gas_amount == 37 && new_cell.gas == "helium" && new_cell.holes == 1 && new_deck?.health == health, "the deck and gas cell retain damage, gas volume and lifting capacity")
	voyage_probe_check(new_rope?.amount == 3 && new_rope.loc == new_chest, "the original quantity of rope stays inside the chest")
	voyage_probe_check(new_engine && !new_engine.on && new_engine.fueltank?.reagents?.total_volume == 18, "the stopped engine is recoupled to the same barrel with its liquid")
	voyage_probe_check(arrived.craft.anchored && arrived.craft.name == "Halcyon" && arrived.voyage_hull_id == wire["id"], "the original hull identity and name return with the ship holding position")
	var/turf/away = airship_voyage_anchorage(wire, TRUE)
	voyage_probe_check(away && away.z == 2 && away.x == 8, "the incoming flight searches the matching coast on the open-air level ([away?.x],[away?.z])")
	airship_voyage_replay_departure(P)
	voyage_probe_check(QDELETED(arrived) && QDELETED(new_rope), "a journal replay finds and removes the same durable hull")
	// No summit or sky on the whole test map: do not lose the credited ship.
	for (var/x = 1 to world.maxx)
		for (var/y = 1 to world.maxy)
			new /turf/floor/dirt(locate(x, y, 2))
	var/turf/fallback = locate(10, 10, 1)
	voyage_probe_check(airship_voyage_arrival(P, TRUE, fallback) == fallback, "without sky crew arrive on solid ground")
	var/obj/structure/airship_recovery/cache = locate() in fallback
	voyage_probe_check(cache && cache.airship_owner == "probe" && cache.airship_record == json_encode(wire), "the pilot's recovery berth retains the entire original record")
