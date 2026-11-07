// Orbit world fixture (tests/orbit_world/run.py): plane registry, deck and
// edge links, multiz helpers, seams, sparse save kind and the shard kind.
/world
	maxx = 8
	maxy = 8
	maxz = 5
	turf = /turf/floor/space/orbit
	area = /area/caribbean/nomads/orbit
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/nomads/orbit/orbit_tester/New()
	return

/mob/orbit_tester/New()
	return

/obj/map_metadata/nomads/flight_tester/New()
	return

/mob/living/human/eva_tester/New()
	return

/mob/living/human/eva_tester/update_icons()
	return

var/global/orbit_failures = 0
/proc/orbit_check(label, actual, expected)
	world.log << "ORBIT CHECK [label]: [actual] expected [expected] [actual == expected ? "PASS" : "FAIL"]"
	if (actual != expected)
		orbit_failures++

/world/New()
	OpenPort("none")
	sleep(1)
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		orbit_check("not an orbit world yet", orbit_world() ? 1 : 0, 0)
		orbit_check("plain multiz above off orbit", multiz_level_above(1), 2)
		map = new /obj/map_metadata/nomads/orbit/orbit_tester
		orbit_check("orbit world", orbit_world() ? 1 : 0, 1)
		var/obj/structure/orbit_registry/R = orbit_get_registry()
		orbit_check("registry made on plane 1", R && R.z == 1 ? 1 : 0, 1)
		orbit_check("arrival plane owned", orbit_plane_owner(1), "arrival")
		orbit_check("four free planes", length(orbit_free_planes()), 4)
		orbit_check("unlinked planes have no level above", multiz_level_above(2), 0)

		var/a = orbit_claim_plane("civ:gaia:Alpha")
		var/b = orbit_claim_plane("civ:gaia:Alpha")
		var/c = orbit_claim_plane("civ:gaia:Beta")
		orbit_check("claims take the lowest free planes", "[a],[b],[c]", "2,3,4")
		orbit_check("arrival cannot be claimed by name", orbit_claim_plane("arrival"), 0)
		orbit_check("one plane left", length(orbit_free_planes()), 1)
		orbit_check("owned planes", length(orbit_owned_planes("civ:gaia:Alpha")), 2)

		orbit_check("link decks", orbit_link_planes(a, "up", b) ? 1 : 0, 1)
		orbit_check("multiz above follows the graph", multiz_level_above(a), b)
		orbit_check("multiz below follows the graph", multiz_level_below(b), a)
		orbit_check("no level below the bottom deck", multiz_level_below(a), 0)
		orbit_check("a taken side refuses another link", orbit_link_planes(a, "up", c) ? 1 : 0, 0)
		orbit_check("link a sector east", orbit_link_planes(b, "east", c) ? 1 : 0, 1)
		orbit_check("east link is two way", orbit_plane_link(c, "west"), b)
		orbit_check("bad direction refused", orbit_link_planes(a, "sideways", c) ? 1 : 0, 0)

		// Seam: an item dropped on the east edge of b arrives inside c's west edge.
		var/obj/item/I = new /obj/item(locate(7, 4, b))
		I.Move(locate(8, 4, b))
		orbit_check("seam moves to the neighbour plane", I.z, c)
		orbit_check("seam lands one tile inside", I.x, 2)
		var/obj/item/J = new /obj/item(locate(2, 5, a))
		J.Move(locate(1, 5, a))
		orbit_check("unlinked edge keeps the item", J.z == a && J.x == 1 ? 1 : 0, 1)

		// Ladders pair through the graph.
		var/obj/structure/multiz/ladder/up/LU = new(locate(4, 4, a))
		var/obj/structure/multiz/ladder/LT = new(locate(4, 4, b))
		LU.find_target()
		orbit_check("ladder pairs across linked decks", LU.target == LT ? 1 : 0, 1)

		// Saves: plane 1 in full, every other plane sparse against vacuum.
		orbit_check("arrival plane saves in full", isnull(map_storage.sparse_level_kind(1)) ? 1 : 0, 1)
		orbit_check("other planes save sparse", map_storage.sparse_level_kind(3), "orbit")
		orbit_check("vacuum baseline", map_storage.sparse_baseline_turf("orbit", 3), /turf/floor/space/orbit)
		orbit_check("registry fields are plain", R.links["[a]:up"], b)
		orbit_check("durable profile listed", (/obj/map_metadata/nomads/orbit in durable_nomads_profiles()) ? 1 : 0, 1)
		orbit_check("vacuum is unbreathable", locate(3, 3, 1).outside_air_breathable() ? 1 : 0, 0)

		// Release cuts every link and frees the plane.
		orbit_check("release", orbit_release_plane(b) ? 1 : 0, 1)
		orbit_check("released plane free", orbit_plane_owner(b) ? 1 : 0, 0)
		orbit_check("release cut the deck link", multiz_level_above(a), 0)
		orbit_check("release cut the sector link", orbit_plane_link(c, "west"), 0)
		orbit_check("arrival plane cannot be released", orbit_release_plane(1) ? 1 : 0, 0)

		// The ladders stood on planes the capsules will claim.
		qdel(LU)
		qdel(LT)
		orbit_flight_checks()
		orbit_eva_checks()
	catch (var/exception/E)
		world.log << "ORBIT EXCEPTION: [E.name] [E.file]:[E.line]"
		orbit_failures++
	text2file("[orbit_failures ? "FAIL" : "PASS"]: orbit world failures=[orbit_failures]", "result.txt")
	shutdown()

// Orbital flight (orbital_flight.dm): the launch side on a ground world, then
// the arrival, capsule and spending on the orbit world.
/proc/orbit_flight_checks()
	var/obj/map_metadata/orbit_map = map
	shard_group.enabled = TRUE
	shard_group.mainland = "gaia"
	shard_group.region = "gaia"
	shard_group.peers = list(
		"gaia" = list("name" = "Gaia", "kind" = "MAINLAND", "state" = "UP"),
		"orbit" = list("name" = "Orbit", "kind" = "ORBIT", "state" = "UP"),
		"moon" = list("name" = "Moon", "kind" = "BARREN", "state" = "UP"))
	map = new /obj/map_metadata/nomads/flight_tester
	map.ordinal_age = 6
	orbit_check("orbit closed before 1969", space_flight_orbit_ok("orbit") ? 1 : 0, 0)
	map.ordinal_age = 7
	orbit_check("orbit open from 1969", space_flight_orbit_ok("orbit") ? 1 : 0, 1)
	orbit_check("the mainland is not orbit", space_flight_orbit_ok("gaia") ? 1 : 0, 0)
	orbit_check("a pad may lead to orbit", space_flight_destination_ok("orbit") ? 1 : 0, 1)
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = new(locate(2, 2, 1))
	var/list/choices = pad.peer_choices()
	orbit_check("pad choices offer orbit", (choices.len && ("orbit" in list(choices[choices[1]]))) ? jointext(choices, ",") : "none", "Orbit (orbit)")
	var/obj/structure/trail_marker_probe = new /obj/structure/region_gate/trail_marker(locate(3, 2, 1))
	var/obj/structure/region_gate/trail_marker/TM = trail_marker_probe
	orbit_check("a trail never leads to orbit", ("Orbit (orbit)" in TM.peer_choices()) ? 1 : 0, 0)
	qdel(TM)
	qdel(pad)
	var/obj/structure/crewed_lander/orbital_rocket/rocket = new(locate(2, 3, 1))
	var/obj/structure/crewed_lander/lander = new(locate(3, 3, 1))
	orbit_check("rocket size", "[rocket.seats],[rocket.cargo_max],[rocket.propellant_needed]", "3,10,600")
	orbit_check("rocket flies to orbit", isnull(rocket.vehicle_refusal("orbit")) ? 1 : 0, 1)
	orbit_check("rocket flies nowhere else", findtext(rocket.vehicle_refusal("moon"), "only flies to orbit") ? 1 : 0, 1)
	orbit_check("a lander cannot reach orbit", findtext(lander.vehicle_refusal("orbit"), "cannot reach orbit") ? 1 : 0, 1)
	orbit_check("a lander still flies to the Moon", isnull(lander.vehicle_refusal("moon")) ? 1 : 0, 1)
	shard_group.peers["orbit"]["free_planes"] = 0
	orbit_check("a full orbit refuses the rocket", findtext(rocket.vehicle_refusal("orbit"), "taken") ? 1 : 0, 1)
	shard_group.peers["orbit"]["free_planes"] = 3
	if (!length(recipe_node_requirements))
		build_research_tree()
	orbit_check("orbital flight node follows crewed flight", get_research_node("orbital_flight") ? 1 : 0, 1)
	orbit_check("rocket recipe gated", get_recipe_node_req("/obj/structure/crewed_lander/orbital_rocket"), "orbital_flight")
	qdel(rocket)
	qdel(lander)
	orbit_check("orbit flight payload", space_flight_payload_ok(list("lander" = "gaia-1-1", "orbit" = 1)) ? 1 : 0, 1)
	orbit_check("orbit payload takes no landing", space_flight_payload_ok(list("lander" = "gaia-1-1", "orbit" = 1, "landing" = list(1, 1))) ? 1 : 0, 0)
	orbit_check("orbit payload is not a return", space_flight_payload_ok(list("lander" = "gaia-1-1", "orbit" = 1, "return" = 1)) ? 1 : 0, 0)
	orbit_check("orbit flag is 1", space_flight_payload_ok(list("lander" = "gaia-1-1", "orbit" = 2)) ? 1 : 0, 0)
	orbit_check("orbit flag needs a flight", space_flight_payload_ok(list("orbit" = 1)) ? 1 : 0, 0)

	// Arrival on the orbit world.
	del(map)
	map = orbit_map
	shard_group.region = "orbit"
	orbit_check("no orbit flight from orbit", space_flight_orbit_ok("orbit") ? 1 : 0, 0)
	orbit_check("orbit flies home", space_flight_return_ok("gaia") ? 1 : 0, 1)
	var/list/P = list("lander" = "gaia-1-1", "orbit" = 1)
	orbit_check("a refused flight builds nothing", isnull(space_flight_arrival_turf(P, FALSE)) ? 1 : 0, 1)
	var/turf/at = space_flight_arrival_turf(P, TRUE)
	var/obj/structure/landed_lander/capsule/C = space_landed_lander("gaia-1-1")
	orbit_check("capsule built", istype(C) && get_turf(C) == at ? 1 : 0, 1)
	orbit_check("capsule claims the lowest free plane", at && at.z, 3)
	orbit_check("capsule in the middle", at ? "[at.x],[at.y]" : "none", "4,4")
	orbit_check("plane owned by the capsule", orbit_plane_owner(3), "capsule:gaia-1-1")
	orbit_check("the crew join one capsule", space_flight_arrival_turf(P, TRUE) == at ? 1 : 0, 1)
	var/decks = 0
	for (var/turf/floor/lander_deck/D in range(1, at))
		decks++
	var/obj/structure/bed/lander_bunk/bunk = locate() in range(1, at)
	orbit_check("capsule deck and bunk", decks == 9 && bunk ? 1 : 0, 1)
	orbit_check("cabin breathable", locate(5, 5, 3).outside_air_breathable() ? 1 : 0, 1)
	orbit_check("vacuum outside the cabin", locate(6, 6, 3).outside_air_breathable() ? 1 : 0, 0)
	orbit_check("capsule cools to vacuum", C.ambient_c(), -100)
	orbit_check("capsule deorbits with nobody aboard", isnull(C.deorbit_refusal(null)) ? 1 : 0, 1)
	bunk.persistence_bed_owner_ckey = "someone"
	orbit_check("a home bunk keeps the capsule", findtext(C.deorbit_refusal(null), "home") ? 1 : 0, 1)
	bunk.persistence_bed_owner_ckey = null
	C.spend()
	orbit_check("spent capsule gone", QDELETED(C) && !space_landed_lander("gaia-1-1") ? 1 : 0, 1)
	orbit_check("deck back to vacuum", istype(locate(4, 4, 3), /turf/floor/space/orbit) && istype(locate(5, 5, 3), /turf/floor/space/orbit) ? 1 : 0, 1)
	orbit_check("bunk removed", (locate(/obj/structure/bed/lander_bunk) in range(1, locate(4, 4, 3))) ? 1 : 0, 0)
	orbit_check("empty plane released", orbit_plane_owner(3) ? 1 : 0, 0)

	// A plane with something left on it stays claimed.
	var/turf/second = space_flight_arrival_turf(list("lander" = "gaia-1-2", "orbit" = 1), TRUE)
	var/obj/structure/landed_lander/capsule/C2 = space_landed_lander("gaia-1-2")
	new /obj/item(locate(6, 6, second.z))
	C2.spend()
	orbit_check("a plane with a leftover stays claimed", orbit_plane_owner(second.z), "capsule:gaia-1-2")
	orbit_release_plane(second.z)

	// With every plane taken, the capsule shares the arrival plane.
	while (orbit_claim_plane("filler:[length(orbit_free_planes())]"))
		continue
	orbit_check("pool empty", length(orbit_free_planes()), 0)
	var/turf/shared = space_flight_arrival_turf(list("lander" = "gaia-1-3", "orbit" = 1), TRUE)
	var/obj/structure/landed_lander/capsule/C3 = space_landed_lander("gaia-1-3")
	orbit_check("full orbit uses the arrival plane", shared && shared.z, 1)
	orbit_check("arrival-plane capsule owns no plane", C3 && isnull(C3.plane_owner) ? 1 : 0, 1)
	orbit_check("capsule site keeps clear of the edges", shared && shared.x >= 3 && shared.y >= 3 && shared.x <= 6 && shared.y <= 6 ? 1 : 0, 1)
	C3.spend()
	orbit_check("the arrival plane is never released", orbit_plane_owner(1), "arrival")
	var/obj/structure/region_gate/capsule_hatch/hatch = new(locate(2, 6, 1))
	hatch.pending_flight = list("lander" = "gaia-1-3", "return" = 1)
	orbit_check("hatch carries the flight home", hatch.travel_extra(null)["return"], 1)
	orbit_check("hatch catches no arrivals", hatch.accepts_arrivals() ? 1 : 0, 0)
	qdel(hatch)

// EVA (orbit_eva.dm): handholds, push-off and drift, seams, unlinked edges and
// the safety tether. The drift loop needs clients, so steps are driven here.
/proc/orbit_eva_checks()
	for (var/z in 2 to 5)
		orbit_release_plane(z)
	var/east = orbit_claim_plane("eva")
	var/west = orbit_claim_plane("eva")
	orbit_check("eva planes", "[east],[west]", "2,3")
	orbit_link_planes(east, "east", west)
	for (var/z in 2 to 3)
		for (var/turf/T in block(locate(1, 1, z), locate(8, 8, z)))
			for (var/obj/O in T)
				qdel(O)
	var/obj/structure/orbit_truss/truss = new(locate(2, 4, east))
	orbit_check("truss is a handhold", locate(3, 4, east).orbit_handhold() ? 1 : 0, 1)
	orbit_check("open space has none", locate(4, 4, east).orbit_handhold() ? 1 : 0, 0)
	orbit_check("truss gated", get_recipe_node_req("/obj/structure/orbit_truss"), "orbital_flight")
	orbit_check("tether gated", get_recipe_node_req("/obj/item/eva_tether"), "orbital_flight")

	var/mob/living/human/eva_tester/H = new(locate(3, 4, east))
	H.m_intent = "stealth"
	H.Move(locate(4, 4, east), EAST)
	orbit_check("pushing off from a handhold drifts", orbit_drifters[H], EAST)
	var/turf/here = H.loc
	orbit_check("no steering while drifting", here.Exit(H, locate(4, 5, east)) ? 1 : 0, 0)
	orbit_drift_step(H)
	orbit_check("drift moves one tile", "[H.x],[H.y],[H.z]", "5,4,[east]")
	orbit_drift_step(H)
	orbit_drift_step(H)
	orbit_drift_step(H)
	orbit_check("drift crosses a linked edge", "[H.x],[H.y],[H.z]", "2,4,[west]")
	orbit_check("still drifting after the seam", orbit_drifters[H], EAST)
	new /obj/structure/orbit_truss(locate(5, 4, west))
	orbit_drift_step(H)
	orbit_drift_step(H)
	orbit_check("drifter catches hold", isnull(orbit_drifters[H]) && H.x == 4 ? 1 : 0, 1)
	for (var/obj/structure/orbit_truss/T in locate(5, 4, west))
		qdel(T)

	orbit_start_drift(H, EAST)
	for (var/i in 1 to 6)
		orbit_drift_step(H)
	orbit_check("unlinked edge stops the drift", isnull(orbit_drifters[H]) && H.x == 8 && H.z == west ? 1 : 0, 1)
	here = H.loc
	orbit_check("lost at the edge", here.Exit(H, locate(7, 4, west)) ? 1 : 0, 0)
	orbit_check("no push-off from the edge", orbit_drifters[H] ? 1 : 0, 0)

	H.forceMove(locate(4, 6, west))
	orbit_stop_drift(H)
	here = H.loc
	orbit_check("restored floater pushes off again", here.Exit(H, locate(4, 7, west)) ? 1 : 0, 0)
	orbit_check("push-off direction", orbit_drifters[H], NORTH)
	orbit_stop_drift(H)

	var/obj/item/eva_tether/tether = new(H)
	H.forceMove(locate(3, 4, east))
	tether.attack_self(H)
	orbit_check("tether clips to the truss", tether.anchor == get_turf(truss) ? 1 : 0, 1)
	orbit_check("tether anchor not saved", tether.persistence_runtime_var("anchor") ? 1 : 0, 1)
	tether.reach = 2
	H.Move(locate(4, 4, east), EAST)
	orbit_drift_step(H)
	orbit_check("taut tether pulls back", "[H.x],[orbit_drifters[H] ? orbit_drifters[H] : 0]", "3,0")
	H.forceMove(locate(4, 4, east))
	orbit_stop_drift(H)
	here = H.loc
	orbit_check("haul along the tether", here.Exit(H, locate(3, 4, east)) ? 1 : 0, 1)
	orbit_check("no pushing away on the tether", here.Exit(H, locate(5, 4, east)) ? 1 : 0, 0)
	orbit_stop_drift(H)
	tether.attack_self(H)
	orbit_check("tether unclips", tether.anchor ? 1 : 0, 0)
	qdel(H)
	qdel(truss)
