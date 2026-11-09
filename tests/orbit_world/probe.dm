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
		orbit_station_checks()
		orbit_project_checks()
		orbit_sortie_checks()
		orbit_pod_checks()
		orbit_deck_checks()
		orbit_upkeep_checks()
		orbit_modern_checks()
		orbit_wear_checks()
		orbit_sector_checks()
		orbit_reusable_checks()
		orbit_two_deck_checks()
		orbit_network_checks()
		orbit_freight_checks()
		orbit_freight_flight_checks()
		orbit_satellite_checks()
		orbit_docking_checks()
		orbit_lab_checks()
		orbit_defence_checks()
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

// Station hardware (orbit_station.dm): the orbital day, solar in orbit, the
// fuel cell, module heat, radiators, the orbital workshop and debris.
/proc/orbit_station_checks()
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	orbit_check("orbit starts sunlit", R.sunlit, 1)
	orbit_check("sunlit part is twenty minutes", R.sun_left, 1200)
	orbit_check("day holds partway", orbit_day_step(1199) ? 1 : 0, 0)
	orbit_check("sunset", orbit_day_step(1) ? "[R.sunlit],[R.sun_left]" : "none", "0,600")
	orbit_check("sunrise", orbit_day_step(600) ? "[R.sunlit],[R.sun_left]" : "none", "1,1200")
	R.sun_left = -5
	orbit_day_step(1)
	orbit_check("bad day count repaired", R.sun_left, 1199)
	orbit_check("orbit ambient", space_world_base_ambient_c(), -100)
	orbit_check("no dust storms in orbit", space_world_has_dust_storms() ? 1 : 0, 0)

	var/z = orbit_claim_plane("station")
	orbit_check("station plane", z, 4)
	var/obj/structure/civ_generator/solar/wing/W = new(locate(7, 7, z))
	orbit_check("solar wing in sunlight", W.rated_output(), 20)
	R.sunlit = 0
	orbit_check("solar wing in shadow", W.rated_output(), 0)
	var/obj/structure/civ_generator/solar/panel/P = new(locate(7, 6, z))
	orbit_check("any panel follows the orbital day", P.rated_output(), 0)
	R.sunlit = 1
	orbit_check("panel in orbital sunlight", P.rated_output(), P.peak_output)
	qdel(W)
	qdel(P)
	var/obj/structure/civ_generator/fuel_cell/F = new(locate(7, 7, z))
	orbit_check("dry fuel cell gives nothing", F.rated_output(), 0)
	F.hydrogen = 10
	orbit_check("fuel cell needs oxygen too", F.rated_output(), 0)
	F.oxygen = 10
	orbit_check("fuel cell output", F.rated_output(), 15)
	qdel(F)

	var/datum/habitat_ledger/L = new(9)
	L.temperature = 20
	orbit_module_heat(L, 10)
	orbit_check("sun warms a module", L.temperature, 21.5)
	R.sunlit = 0
	orbit_module_heat(L, 10)
	orbit_check("no sun in shadow", L.temperature, 21.5)
	R.sunlit = 1
	var/obj/structure/life_support/heater/heater = new(locate(7, 7, z))
	orbit_machine_heat(L, heater, 10)
	orbit_check("working machines warm a module", round(L.temperature, 0.01), 21.9)
	var/obj/structure/life_support/radiator/rad = new(locate(7, 6, z))
	orbit_check("radiator idle without power", rad.work(L, 10) ? 1 : 0, 0)
	orbit_check("radiators add no heat", orbit_machine_heat(L, rad, 10) ? 1 : 0, 0)
	qdel(heater)
	qdel(rad)

	var/obj/structure/habitat_core/C = habitat_unfold(locate(4, 4, z), "orbital workshop")
	var/bunks = 0
	for (var/obj/structure/bed/lander_bunk/B in range(1, C))
		bunks++
	orbit_check("orbital workshop furnishing", "[bunks],[(locate(/obj/structure/table) in range(1, C)) ? 1 : 0],[(locate(/obj/structure/closet/crate) in range(1, C)) ? 1 : 0]", "2,1,1")
	orbit_check("workshop sealed", C.breaches(), 0)
	var/turf/hit = barren_meteor_strike(C)
	orbit_check("debris breaches to vacuum", istype(hit, /turf/floor/space/orbit) ? 1 : 0, 1)
	orbit_check("one breach", C.breaches(), 1)
	orbit_check("debris breach is patchable", habitat_patchable(hit) ? 1 : 0, 1)
	orbit_check("workshop kit gated", get_recipe_node_req("/obj/item/habitat_kit/orbital_workshop"), "orbital_flight")
	orbit_check("solar wing gated", get_recipe_node_req("/obj/structure/civ_generator/solar/wing"), "orbital_flight")
	orbit_check("fuel cell gated", get_recipe_node_req("/obj/structure/civ_generator/fuel_cell"), "orbital_flight")
	orbit_check("radiator gated", get_recipe_node_req("/obj/structure/life_support/radiator"), "orbital_flight")

// Starter stations (orbit_project.dm): the launch complex office on the
// ground, then founding, boarding, the console and recovery in orbit.
/proc/orbit_project_checks()
	var/party = "civ:gaia:Alpha"
	var/obj/map_metadata/orbit_map = map
	map = new /obj/map_metadata/nomads/flight_tester
	map.ordinal_age = 7
	shard_group.region = "gaia"
	shard_group.kind = "MAINLAND"
	var/obj/structure/region_gate/launch_complex/office = new(locate(3, 3, 1))
	orbit_check("office needs an orbit pad", findtext(office.start_refusal(null, party), "launch pad") ? 1 : 0, 1)
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = new(locate(5, 5, 1))
	pad.destination = "orbit"
	pad.approved = TRUE
	orbit_check("office beside an orbit pad", isnull(office.start_refusal(null, party)) ? 1 : 0, 1)
	map.ordinal_age = 6
	orbit_check("stations from 1969", findtext(office.start_refusal(null, party), "1969") ? 1 : 0, 1)
	map.ordinal_age = 7
	office.party = party
	var/obj/structure/region_gate/launch_complex/second = new(locate(2, 6, 1))
	orbit_check("one project per party", findtext(second.start_refusal(null, party), "already has") ? 1 : 0, 1)
	qdel(second)
	orbit_check("project shows progress", findtext(office.closed_reason(), "steel 0/180") ? 1 : 0, 1)
	for (var/kind in orbit_station_requirements)
		var/list/need = orbit_station_requirements[kind]
		office.delivered[kind] = need[2]
	orbit_check("nothing left to deliver", length(office.remaining()), 0)
	office.complete(null)
	orbit_check("project complete", office.completed ? 1 : 0, 1)
	shard_group.peers["orbit"]["free_planes"] = 0
	orbit_check("full orbit refuses before launch", findtext(office.closed_reason(), "taken") ? 1 : 0, 1)
	office.boarded = TRUE
	orbit_check("a boarded party may fly to its station", findtext(office.closed_reason(), "taken") ? 1 : 0, 0)
	orbit_check("office leads to orbit", office.destination, "orbit")
	orbit_check("office trip is the party's", office.travel_party(null), party)
	orbit_check("home from the station lands at the office", party_train_arrival_turf(list("party" = party, "from" = "orbit")) == office.loc ? 1 : 0, 1)
	orbit_check("office gated", get_recipe_node_req("/obj/structure/region_gate/launch_complex"), "orbital_flight")
	orbit_check("console gated", get_recipe_node_req("/obj/structure/orbit_console"), "orbital_flight")
	qdel(office)
	qdel(pad)
	del(map)
	map = orbit_map
	shard_group.region = "orbit"
	shard_group.kind = "ORBIT"

	map.ordinal_age = 7
	// A bigger plane for the station layout.
	world.maxx = 28
	world.maxy = 28
	for (var/z in 2 to 5)
		orbit_release_plane(z)
	var/turf/at = party_train_arrival_turf(list("party" = party, "from" = "gaia"))
	var/obj/structure/region_gate/station_hatch/hatch = orbit_station_hatch(party)
	orbit_check("first arrival founds the station", hatch && at == hatch.loc ? 1 : 0, 1)
	var/z = at ? at.z : 0
	orbit_check("station plane", z, 2)
	orbit_check("plane owned by the party", orbit_station_party(z), party)
	orbit_check("hatch leads home", hatch && hatch.home_region, "gaia")
	orbit_check("station modules", length(orbit_station_modules(z)), 3)
	var/sealed = 0
	var/list/kinds = list()
	for (var/obj/structure/habitat_core/C in orbit_station_modules(z))
		kinds += C.kind
		if (!C.breaches())
			sealed++
	orbit_check("station sealed", sealed, 3)
	orbit_check("1969 workshop hub, quarters and airlock", ("station" in kinds) && ("quarters" in kinds) && ("airlock" in kinds) ? 1 : 0, 1)
	var/obj/structure/habitat_core/hub = locate() in locate(14, 14, z)
	orbit_check("workshop hub in the middle", hub ? hub.kind : "none", "station")
	orbit_check("quarters docked east", (locate(/obj/structure/habitat_core) in locate(18, 14, z)) && (locate(/obj/structure/simple_door/habitat_hatch) in locate(16, 14, z)) ? 1 : 0, 1)
	orbit_check("bunks in the quarters", length(orbit_find_all(/obj/structure/bed/lander_bunk, z, 16, 12, 20, 16)), 2)
	orbit_check("airlock docked south", (locate(/obj/structure/habitat_core/airlock) in locate(14, 10, z)) && (locate(/obj/structure/simple_door/habitat_hatch) in locate(14, 8, z)) ? 1 : 0, 1)
	orbit_check("life support in the hub", length(orbit_find_all(/obj/structure/life_support, z, 13, 15, 15, 15)), 3)
	orbit_check("hub doorways clear", orbit_blocked(locate(15, 14, z)) || orbit_blocked(locate(14, 13, z)) ? 1 : 0, 0)
	orbit_check("porch truss outside the outer hatch", (locate(/obj/structure/orbit_truss) in locate(14, 7, z)) ? 1 : 0, 1)
	orbit_check("wings on the cross boom", (locate(/obj/structure/civ_generator/solar/wing) in locate(11, 5, z)) && (locate(/obj/structure/civ_generator/solar/wing) in locate(17, 5, z)) ? 1 : 0, 1)
	orbit_check("boom is a handhold", (locate(/obj/structure/orbit_truss) in locate(12, 5, z)) && (locate(/obj/structure/orbit_truss) in locate(16, 5, z)) ? 1 : 0, 1)
	orbit_check("thruster at the aft end of the keel", (locate(/obj/structure/orbit_thruster) in locate(14, 2, z)) ? 1 : 0, 1)
	var/keel_holds = 0
	for (var/y = 7, y >= 2, y--)
		var/turf/K = locate(14, y, z)
		if (K.orbit_hold_point(null))
			keel_holds++
	orbit_check("every keel tile is a hold point", keel_holds, 6)
	orbit_check("nothing outside is out of reach", orbit_unreachable_hardware(z), 0)
	var/wings = 0
	for (var/obj/structure/civ_generator/solar/wing/W in world)
		if (W.z != z)
			continue
		W.settle_generation()
		if (W.output_power == 20)
			wings++
	orbit_check("two wings cabled and generating", wings, 2)
	var/obj/structure/life_support/heater/heater = orbit_find_on(/obj/structure/life_support/heater, z)
	orbit_check("heater on the station grid", heater && heater.has_power() ? 1 : 0, 1)
	var/obj/structure/life_support/scrubber/scrubber = orbit_find_on(/obj/structure/life_support/scrubber, z)
	orbit_check("scrubber on the station grid", scrubber && scrubber.has_power() ? 1 : 0, 1)
	var/obj/structure/civ_generator/fuel_cell/F = orbit_find_on(/obj/structure/civ_generator/fuel_cell, z)
	orbit_check("fuel cell fuelled and off", F ? "[F.hydrogen],[F.oxygen],[F.enabled]" : "none", "200,200,0")
	var/obj/structure/closet/crate/crate = orbit_find_on(/obj/structure/closet/crate, z)
	orbit_check("supplies stowed", crate && (locate(/obj/item/clothing/suit/pressure_suit) in crate) && (locate(/obj/item/habitat_sealant) in crate) ? 1 : 0, 1)
	orbit_check("later members board at the hatch", party_train_arrival_turf(list("party" = party, "from" = "gaia")) == at ? 1 : 0, 1)
	orbit_check("one plane per station", length(orbit_station_planes(party)), 1)
	orbit_check("hatch trip is the party's", hatch.travel_party(null), party)
	hatch.closed_reason()
	orbit_check("hatch flies home", hatch.destination, "gaia")

	var/obj/structure/orbit_console/console = orbit_find_on(/obj/structure/orbit_console, z)
	orbit_check("console, crate and hatch in the workshop", console && console.x == 15 && console.y == 13 && crate.x == 13 && crate.y == 13 && hatch.x == 14 && hatch.y == 13 ? 1 : 0, 1)
	orbit_check("console reports the owner", console && findtext(jointext(console.status_lines(), " "), "Station of Alpha") ? 1 : 0, 1)
	var/mob/living/human/eva_tester/H = new(locate(1, 12, z))
	H.m_intent = "stealth"
	human_mob_list |= H
	orbit_stop_drift(H)
	orbit_check("lost at an unlinked edge", (H in orbit_lost_drifters()) ? 1 : 0, 1)
	orbit_check("console recovers the drifter", console.recover(H) ? 1 : 0, 1)
	orbit_check("recovered aboard", istype(H.loc, /turf/floor/habitat) && get_dist(H, console) <= 1 ? 1 : 0, 1)
	orbit_check("no longer lost", (H in orbit_lost_drifters()) ? 1 : 0, 0)
	human_mob_list -= H
	qdel(H)

	while (orbit_claim_plane("filler:[length(orbit_free_planes())]"))
		continue
	orbit_check("a full orbit founds no station", isnull(orbit_station_arrival_turf(list("party" = "civ:gaia:Beta", "from" = "gaia"))) ? 1 : 0, 1)

/proc/orbit_find_on(type, z)
	for (var/atom/movable/A in world)
		if (istype(A, type) && A.z == z)
			return A
	return null

// Every instance of path on plane z inside the box, inclusive.
/proc/orbit_find_all(path, z, x1, y1, x2, y2)
	var/list/found = list()
	for (var/turf/T in block(locate(x1, y1, z), locate(x2, y2, z)))
		for (var/atom/A in T)
			if (istype(A, path))
				found += A
	return found

// TRUE when something solid stands on T.
/proc/orbit_blocked(turf/T)
	if (!T || T.density)
		return TRUE
	for (var/atom/movable/A in T)
		if (A.density)
			return TRUE
	return FALSE

// Outside hardware on plane z with no hold point within reach of the tiles
// beside it, which a suited crew member could only reach by drifting.
/proc/orbit_unreachable_hardware(z)
	. = 0
	for (var/obj/structure/O in world)
		if (O.z != z || !istype(O.loc, /turf/floor/space/orbit) || istype(O, /obj/structure/orbit_truss) || istype(O, /obj/structure/cable))
			continue
		var/reachable = FALSE
		for (var/turf/T in orange(1, O))
			if (!orbit_blocked(T) && T.orbit_handhold(null))
				reachable = TRUE
				break
		if (!reachable)
			.++

// Moon gear (lander.dm): the sortie reserve, its payload flag, lifting off
// home from a landed lander, and the lunar surface kit.
/proc/orbit_sortie_checks()
	var/obj/map_metadata/orbit_map = map
	map = new /obj/map_metadata/nomads/flight_tester
	map.ordinal_age = 7
	shard_group.region = "moon"
	shard_group.kind = "BARREN"
	var/obj/structure/crewed_lander/lander = new(locate(10, 10, 1))
	var/obj/structure/crewed_lander/orbital_rocket/rocket = new(locate(12, 10, 1))
	orbit_check("lander keeps an ascent reserve", lander.ascent_propellant, 150)
	orbit_check("rocket keeps none", rocket.ascent_propellant, 0)
	lander.propellant = 300
	orbit_check("a bare load is no sortie", lander.sortie_ready() ? 1 : 0, 0)
	lander.propellant = 450
	orbit_check("a full tank is a sortie", lander.sortie_ready() ? 1 : 0, 1)
	qdel(lander)
	qdel(rocket)
	orbit_check("sortie payload", space_flight_payload_ok(list("lander" = "gaia-1-9", "landing" = list(2, 2), "surveyed" = 1, "rough" = 0, "sortie" = 1)) ? 1 : 0, 1)
	orbit_check("sortie flag is 1", space_flight_payload_ok(list("lander" = "gaia-1-9", "landing" = list(2, 2), "surveyed" = 1, "rough" = 0, "sortie" = 2)) ? 1 : 0, 0)
	orbit_check("no sortie home", space_flight_payload_ok(list("lander" = "gaia-1-9", "return" = 1, "sortie" = 1)) ? 1 : 0, 0)
	orbit_check("no sortie to orbit", space_flight_payload_ok(list("lander" = "gaia-1-9", "orbit" = 1, "sortie" = 1)) ? 1 : 0, 0)
	orbit_check("no sortie without a flight", space_flight_payload_ok(list("sortie" = 1)) ? 1 : 0, 0)

	var/obj/structure/landed_lander/L = new(locate(10, 10, 1))
	L.lander_id = "gaia-1-9"
	L.deploy()
	orbit_check("a spent lander cannot lift off", findtext(L.deorbit_refusal(null), "propellant") ? 1 : 0, 1)
	L.ascent_ready = 1
	orbit_check("a sortie lander can lift off", L.can_lift_off() ? 1 : 0, 1)
	orbit_check("lift-off refusal is not about propellant", findtext("[L.deorbit_refusal(null)]", "propellant") ? 1 : 0, 0)
	L.spend()
	orbit_check("lifted-off lander gone", QDELETED(L) && !space_landed_lander("gaia-1-9") ? 1 : 0, 1)
	orbit_check("deck back to the ground", istype(locate(10, 10, 1), /turf/floor/dirt/dust/regolith) && istype(locate(11, 11, 1), /turf/floor/dirt/dust/regolith) ? 1 : 0, 1)

	var/obj/item/lunar_kit/kit = new(locate(14, 14, 1))
	orbit_check("lunar kit flies in the hold", space_cargo_kind(kit) ? 1 : 0, 1)
	orbit_check("lunar kit gated", get_recipe_node_req("/obj/item/lunar_kit"), "crewed_flight")
	var/mob/living/human/eva_tester/H = new(locate(14, 14, 1))
	H.m_intent = "stealth"
	kit.attack_self(H)
	var/suits = 0
	var/tanks = 0
	for (var/obj/item/clothing/suit/pressure_suit/S in locate(14, 14, 1))
		suits++
	for (var/obj/item/pressure_tank/T in locate(14, 14, 1))
		tanks++
	orbit_check("lunar kit unpacks", "[QDELETED(kit) ? 1 : 0],[suits],[tanks]", "1,2,4")
	qdel(H)
	del(map)
	map = orbit_map
	shard_group.region = "orbit"
	shard_group.kind = "ORBIT"

// Module pods and docking (orbit_pods.dm): release from a kit, the footprint,
// RCS steps, rams, hard docking, party checks, folding back and re-docking.
/proc/orbit_pod_checks()
	var/party = "civ:gaia:Alpha"
	for (var/p in 2 to 5)
		orbit_release_plane(p)
	orbit_claim_plane("keep")
	var/z = orbit_claim_plane(orbit_station_owner(party))
	orbit_check("pod plane", z, 3)
	var/obj/structure/habitat_core/C = habitat_unfold(locate(8, 12, z), "workshop")
	var/mob/living/human/eva_tester/H = new(locate(14, 12, z))
	H.m_intent = "stealth"
	H.party_train_party = party
	H.dir = EAST
	var/mob/living/human/eva_tester/O = new(locate(20, 20, z))
	O.m_intent = "stealth"
	O.party_train_party = "civ:gaia:Beta"

	orbit_check("no room near a hull", orbit_pod_blocker(locate(12, 13, z), null), "hull")
	orbit_check("no room at the edge", orbit_pod_blocker(locate(3, 12, z), null), "edge")
	var/obj/item/habitat_kit/K = new(H)
	var/obj/structure/orbit_pod/P = orbit_pod_release(K, H)
	orbit_check("kit released as a pod ahead", P ? "[P.x],[P.y]" : "none", "17,12")
	orbit_check("kit used up", QDELETED(K) ? 1 : 0, 1)
	orbit_check("pod answers to the party", P.party, party)
	orbit_check("pod kind", P.name, "quarters module pod")
	orbit_check("no second pod overlapping", orbit_pod_blocker(locate(19, 12, z), null), "pod")
	orbit_check("outsiders cannot steer", findtext("[P.burn_refusal(O)]", "Alpha") ? 1 : 0, 1)
	orbit_check("members can steer", isnull(P.burn_refusal(H)) ? 1 : 0, 1)
	orbit_check("not lined up yet", P.dock_core() ? 1 : 0, 0)
	for (var/i in 1 to 5)
		P.move_one(WEST)
	orbit_check("steered to the docking site", "[P.x],[P.y]", "12,12")
	orbit_check("each tile costs propellant", P.propellant, 15)
	orbit_check("lined up with the module", P.dock_core() == C ? 1 : 0, 1)
	orbit_check("a ram stops the pod", P.move_one(WEST) ? 1 : 0, 0)
	orbit_check("a ram damages the pod", P.integrity, 75)
	orbit_check("a ram costs nothing", P.propellant, 15)
	orbit_check("a burn starts", isnull(P.burn(EAST, 2, H)) ? 1 : 0, 1)
	orbit_check("one burn at a time", findtext("[P.burn(EAST, 2, H)]", "under way") ? 1 : 0, 1)
	P.burn_left = 0
	orbit_check("outsiders cannot dock", findtext("[P.dock_refusal(O)]", "Alpha") ? 1 : 0, 1)
	orbit_check("stand clear of the new hull", findtext("[P.dock_refusal(H)]", "hull") ? 1 : 0, 1)
	H.forceMove(locate(13, 12, z))
	orbit_check("ready to dock", isnull(P.dock_refusal(H)) ? 1 : 0, 1)
	var/obj/structure/habitat_core/D = P.hard_dock(H)
	orbit_check("hard dock unfolds the module", D && D.x == 12 && D.y == 12 ? 1 : 0, 1)
	orbit_check("pod gone", QDELETED(P) ? 1 : 0, 1)
	orbit_check("shared hatch", (locate(/obj/structure/simple_door/habitat_hatch) in locate(10, 12, z)) ? 1 : 0, 1)
	orbit_check("both modules sealed", "[C.breaches()],[D.breaches()]", "0,0")
	var/bunks = 0
	for (var/obj/structure/bed/lander_bunk/B in range(1, D))
		bunks++
	orbit_check("a kit pod is furnished", bunks, 2)
	orbit_check("fresh air aboard", round(D.air().pressure_kpa()), 100)

	var/obj/structure/simple_door/habitat_hatch/hatch = locate() in locate(10, 12, z)
	hatch.density = FALSE
	orbit_check("fold refused with a hatch open", findtext("[D.fold_refusal(H)]", "hatch") ? 1 : 0, 1)
	hatch.density = TRUE
	O.forceMove(locate(11, 13, z))
	orbit_check("fold refused with someone else inside", findtext("[D.fold_refusal(H)]", "Everyone") ? 1 : 0, 1)
	orbit_check("outsiders cannot fold", findtext("[D.fold_refusal(O)]", "Alpha") ? 1 : 0, 1)
	O.forceMove(locate(20, 20, z))
	var/obj/structure/cable/wire = new(locate(13, 13, z))
	orbit_check("fold refused with cables inside", findtext("[D.fold_refusal(H)]", "cables") ? 1 : 0, 1)
	qdel(wire)
	var/obj/structure/bed/lander_bunk/bunk = locate() in range(1, D)
	bunk.persistence_bed_owner_ckey = "someone"
	orbit_check("fold refused while a bunk is home", findtext("[D.fold_refusal(H)]", "home") ? 1 : 0, 1)
	bunk.persistence_bed_owner_ckey = null
	orbit_check("fold allowed", isnull(D.fold_refusal(H)) ? 1 : 0, 1)
	D.air().oxygen = 500
	D.store_air()
	var/obj/structure/orbit_pod/F = D.fold(H)
	orbit_check("folded into a pod", F && F.x == 12 && F.y == 12 ? 1 : 0, 1)
	orbit_check("folded pod carries its furniture", length(F.contents), 2)
	orbit_check("folded pod keeps its air", F.air_oxygen, 500)
	orbit_check("folded pod is the station's", F.party, party)
	orbit_check("module gone", QDELETED(D) ? 1 : 0, 1)
	orbit_check("site open to vacuum", istype(locate(12, 12, z), /turf/floor/space/orbit) && istype(locate(14, 12, z), /turf/floor/space/orbit) ? 1 : 0, 1)
	orbit_check("shared wall sealed", istype(locate(10, 12, z), /turf/wall/habitat_shell) && !(locate(/obj/structure/simple_door/habitat_hatch) in locate(10, 12, z)) ? 1 : 0, 1)
	orbit_check("old module still sealed", C.breaches(), 0)

	H.forceMove(locate(13, 12, z))
	orbit_check("folded pod docks again", isnull(F.dock_refusal(H)) ? 1 : 0, 1)
	var/obj/structure/habitat_core/E = F.hard_dock(H)
	bunks = 0
	for (var/obj/structure/bed/lander_bunk/B in range(1, E))
		bunks++
	orbit_check("re-docked without new furniture", bunks, 2)
	orbit_check("re-docked with its air", E.air().oxygen, 500)
	orbit_check("re-docked sealed", E.breaches(), 0)

	var/obj/structure/orbit_console/console = new(locate(8, 13, z))
	H.forceMove(locate(20, 6, z))
	H.dir = WEST
	var/obj/item/habitat_kit/K2 = new(H)
	var/obj/structure/orbit_pod/P2 = orbit_pod_release(K2, H)
	orbit_check("second pod released", P2 ? 1 : 0, 1)
	orbit_check("console steers member pods", length(console.steerable_pods(H)), 1)
	orbit_check("console steers none for outsiders", length(console.steerable_pods(O)), 0)
	qdel(H)
	qdel(O)

// Decks (orbit_decks.dm): node modules, deck hatches, building a deck above,
// shared air through open hatches, refusals and power risers.
/proc/orbit_deck_checks()
	var/party = "civ:gaia:Alpha"
	for (var/p in 2 to 5)
		orbit_release_plane(p)
	orbit_claim_plane("keep")
	orbit_claim_plane("keep")
	var/z = orbit_claim_plane(orbit_station_owner(party))
	orbit_check("deck station plane", z, 4)
	var/obj/structure/habitat_core/node/N = habitat_unfold(locate(12, 12, z), "node", /obj/structure/habitat_core/node)
	var/obj/structure/deck_hatch/hatch = N.deck_hatch()
	orbit_check("node has a deck hatch", hatch ? "[hatch.x],[hatch.y]" : "none", "13,11")
	orbit_check("node sealed with the hatch shut", N.breaches(), 0)
	var/mob/living/human/eva_tester/H = new(locate(12, 13, z))
	H.m_intent = "stealth"
	H.party_train_party = party
	var/mob/living/human/eva_tester/O = new(locate(11, 13, z))
	O.m_intent = "stealth"
	O.party_train_party = "civ:gaia:Beta"
	orbit_check("a deck needs the hatch open", findtext("[orbit_deck_refusal(hatch, "up", H)]", "Open") ? 1 : 0, 1)
	hatch.open = TRUE
	orbit_check("an open hatch to nothing is a breach", N.breaches(), 1)
	orbit_check("outsiders cannot build decks", findtext("[orbit_deck_refusal(hatch, "up", O)]", "Alpha") ? 1 : 0, 1)
	orbit_check("members can build a deck", isnull(orbit_deck_refusal(hatch, "up", H)) ? 1 : 0, 1)
	O.forceMove(locate(20, 20, z))
	var/obj/structure/habitat_core/node/U = orbit_add_deck(hatch, "up")
	orbit_check("new deck node", U ? "[U.x],[U.y],[U.z]" : "none", "12,12,5")
	orbit_check("deck linked up", orbit_plane_link(z, "up"), 5)
	orbit_check("multiz follows the deck", multiz_level_above(z), 5)
	orbit_check("deck owned by the station", orbit_station_party(5), party)
	var/obj/structure/deck_hatch/upper = U.deck_hatch()
	orbit_check("hatches pair through the shaft", hatch.partner("up") == upper && upper.partner("down") == hatch ? 1 : 0, 1)
	orbit_check("a hatch shut above seals the shaft", N.breaches(), 0)
	orbit_check("climbing needs both hatches open", findtext("[hatch.climb(H, "up")]", "both") ? 1 : 0, 1)
	var/datum/habitat_ledger/below = N.air()
	below.oxygen = 0
	N.store_air()
	N.step_air(2, 0)
	orbit_check("no mixing through a shut hatch", round(N.air().oxygen), 0)
	upper.open = TRUE
	orbit_check("open shaft joins the nodes", (U in N.deck_neighbours()) ? 1 : 0, 1)
	N.step_air(2, 0)
	orbit_check("air mixes between decks", N.air().oxygen > 50 ? 1 : 0, 1)
	orbit_check("both decks sealed", "[N.breaches()],[U.breaches()]", "0,0")
	orbit_check("one deck each way", findtext("[orbit_deck_refusal(hatch, "up", H)]", "already") ? 1 : 0, 1)
	orbit_check("no free plane for another deck", findtext("[orbit_deck_refusal(hatch, "down", H)]", "taken") ? 1 : 0, 1)
	orbit_check("fold refused with the deck hatch open", findtext("[N.fold_refusal(H)]", "deck hatch") ? 1 : 0, 1)
	hatch.open = FALSE
	orbit_check("fold refused while a deck is joined", findtext("[N.fold_refusal(H)]", "joined") ? 1 : 0, 1)
	var/obj/structure/orbit_console/console = new(locate(11, 12, z))
	orbit_check("console reports every deck", findtext(jointext(console.status_lines(), " "), "(plane 5)") ? 1 : 0, 1)
	var/obj/item/connector/riser/R1 = new(locate(11, 13, z))
	var/obj/item/connector/riser/R2 = new(locate(11, 13, 5))
	R1.anchored = TRUE
	R2.anchored = TRUE
	orbit_check("risers carry power between decks", (R2 in R1.riser_partners()) ? 1 : 0, 1)
	orbit_check("node kit gated", get_recipe_node_req("/obj/item/habitat_kit/node"), "orbital_flight")
	qdel(H)
	qdel(O)

// Upkeep (orbit_upkeep.dm): orbit decay by band, drag heating, the floor and
// ceiling, the hazard clock hook, the reboost thruster and the console.
/proc/orbit_upkeep_checks()
	var/party = "civ:gaia:Alpha"
	orbit_check("stations listed", ("[party]" in orbit_station_parties()) ? 1 : 0, 1)
	var/obj/structure/orbit_thruster/starter = orbit_find_on(/obj/structure/orbit_thruster, 2)
	orbit_check("starter station has a fuelled thruster", starter ? starter.propellant : 0, 60)
	orbit_set_station_altitude(party, 400)
	orbit_upkeep_step(600, FALSE)
	orbit_check("orbit decays with play", round(orbit_station_altitude(party), 0.01), 395.02)
	orbit_check("high orbit band", orbit_altitude_band(orbit_station_altitude(party)), "high")
	barren_hazards_step(60, FALSE)
	orbit_check("hazard clock drives decay", round(orbit_station_altitude(party), 0.01), 394.52)
	var/obj/structure/habitat_core/node/N = locate() in locate(12, 12, 4)
	orbit_set_station_altitude(party, 260)
	var/before = N.air().temperature
	orbit_upkeep_step(60, FALSE)
	orbit_check("no drag heat in low orbit", N.air().temperature - before, 0)
	orbit_set_station_altitude(party, 250.2)
	orbit_upkeep_step(60, FALSE)
	orbit_check("drag band", orbit_altitude_band(orbit_station_altitude(party)), "drag")
	orbit_check("drag heats the station", round(N.air().temperature - before, 0.01), 3)
	orbit_set_station_altitude(party, 190)
	before = N.air().temperature
	orbit_upkeep_step(10, FALSE)
	orbit_check("skimming heats hard", round(N.air().temperature - before, 0.01), 2)
	orbit_set_station_altitude(party, 151)
	orbit_upkeep_step(1000, FALSE)
	orbit_check("orbit floor", orbit_station_altitude(party), 150)
	orbit_set_station_altitude(party, 999)
	orbit_check("orbit ceiling", orbit_station_altitude(party), 420)

	var/mob/living/human/eva_tester/H = new(locate(20, 21, 4))
	H.m_intent = "stealth"
	H.party_train_party = party
	var/mob/living/human/eva_tester/O = new(locate(21, 21, 4))
	O.m_intent = "stealth"
	O.party_train_party = "civ:gaia:Beta"
	var/obj/structure/orbit_thruster/T = new(locate(20, 20, 4))
	orbit_set_station_altitude(party, 300)
	orbit_check("thruster needs propellant", findtext("[T.reboost_refusal(H)]", "propellant") ? 1 : 0, 1)
	T.propellant = 40
	orbit_check("outsiders cannot reboost", findtext("[T.reboost_refusal(O)]", "Alpha") ? 1 : 0, 1)
	orbit_check("members can reboost", isnull(T.reboost_refusal(H)) ? 1 : 0, 1)
	orbit_check("reboost climbs", T.reboost(), 320)
	orbit_check("reboost burns propellant", T.propellant, 20)
	orbit_set_station_altitude(party, 415)
	orbit_check("reboost stops at the ceiling", T.reboost(), 420)
	T.propellant = 40
	orbit_check("no reboost above the ceiling", findtext("[T.reboost_refusal(H)]", "high") ? 1 : 0, 1)
	var/obj/structure/orbit_console/console = new(locate(22, 22, 4))
	orbit_set_station_altitude(party, 240)
	orbit_check("console shows altitude and drag", findtext(jointext(console.status_lines(), " "), "Altitude 240 km, in drag") ? 1 : 0, 1)
	orbit_check("thruster gated", get_recipe_node_req("/obj/structure/orbit_thruster"), "orbital_flight")
	qdel(H)
	qdel(O)

// The 2013 layout and hardware: tracking arrays, the radioisotope generator,
// the extra node and greenhouse, six reboost burns and a node kit.
/proc/orbit_modern_checks()
	var/party = "civ:gaia:Gamma"
	world.maxx = 32
	world.maxy = 32
	for (var/p in 2 to 5)
		orbit_release_plane(p)
	for (var/p in 2 to 4)
		orbit_claim_plane("keep")
	for (var/turf/T in block(locate(1, 1, 5), locate(world.maxx, world.maxy, 5)))
		for (var/obj/O in T)
			if (!istype(O, /obj/effect))
				qdel(O)
		if (!istype(T, /turf/floor/space/orbit))
			T.ChangeTurf(/turf/floor/space/orbit, FALSE, FALSE)
	map.ordinal_age = 8
	var/turf/at = party_train_arrival_turf(list("party" = party, "from" = "gaia"))
	orbit_check("2013 station founded", at ? at.z : 0, 5)
	var/sealed = 0
	var/list/kinds = list()
	for (var/obj/structure/habitat_core/C in orbit_station_modules(5))
		kinds += C.kind
		if (!C.breaches())
			sealed++
	orbit_check("2013 modules", length(kinds), 5)
	orbit_check("2013 modules sealed", sealed, 5)
	orbit_check("2013 node, greenhouse and quarters", ("node" in kinds) && ("greenhouse" in kinds) && ("quarters" in kinds) ? 1 : 0, 1)
	var/obj/structure/habitat_core/node/hub = locate() in locate(16, 16, 5)
	orbit_check("node hub in the middle", hub ? 1 : 0, 1)
	orbit_check("hub deck hatch free", hub && hub.deck_hatch() && !orbit_blocked(hub.deck_hatch().loc) ? 1 : 0, 1)
	orbit_check("hub doorways clear", orbit_blocked(locate(15, 16, 5)) || orbit_blocked(locate(17, 16, 5)) || orbit_blocked(locate(16, 15, 5)) || orbit_blocked(locate(16, 17, 5)) ? 1 : 0, 0)
	orbit_check("life support in the hub corners", length(orbit_find_all(/obj/structure/life_support, 5, 15, 15, 17, 17)), 3)
	orbit_check("arms on four sides", (locate(/obj/structure/habitat_core) in locate(20, 16, 5)) && (locate(/obj/structure/habitat_core) in locate(12, 16, 5)) && (locate(/obj/structure/habitat_core) in locate(16, 20, 5)) && (locate(/obj/structure/habitat_core/airlock) in locate(16, 12, 5)) ? 1 : 0, 1)
	orbit_check("2013 hatch home in the workshop", at ? "[at.x],[at.y]" : "none", "20,15")
	orbit_check("bench, crate and console in the workshop", (locate(/obj/structure/table) in locate(20, 17, 5)) && (locate(/obj/structure/closet/crate) in locate(19, 15, 5)) && (locate(/obj/structure/orbit_console) in locate(21, 15, 5)) ? 1 : 0, 1)
	orbit_check("2013 keel", (locate(/obj/structure/orbit_truss) in locate(16, 9, 5)) && (locate(/obj/structure/civ_generator/isotope) in locate(16, 6, 5)) && (locate(/obj/structure/civ_generator/fuel_cell) in locate(16, 5, 5)) && (locate(/obj/structure/orbit_thruster) in locate(16, 4, 5)) ? 1 : 0, 1)
	orbit_check("2013 nothing outside is out of reach", orbit_unreachable_hardware(5), 0)
	var/arrays = 0
	for (var/obj/structure/civ_generator/solar/wing/tracking/W in world)
		if (W.z != 5)
			continue
		W.settle_generation()
		if (W.output_power == 35)
			arrays++
	orbit_check("two tracking arrays generating", arrays, 2)
	var/obj/structure/civ_generator/isotope/I = orbit_find_on(/obj/structure/civ_generator/isotope, 5)
	I.settle_generation()
	orbit_check("isotope generator on the grid", I ? I.output_power : 0, 10)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	R.sunlit = 0
	orbit_check("isotope generator ignores the shade", I.rated_output(), 10)
	R.sunlit = 1
	var/obj/structure/orbit_thruster/T = orbit_find_on(/obj/structure/orbit_thruster, 5)
	orbit_check("six reboost burns", T ? T.propellant : 0, 120)
	var/obj/structure/closet/crate/crate = orbit_find_on(/obj/structure/closet/crate, 5)
	orbit_check("node kit in the crate", crate && (locate(/obj/item/habitat_kit/node) in crate) ? 1 : 0, 1)
	orbit_check("tracking array gated", get_recipe_node_req("/obj/structure/civ_generator/solar/wing/tracking"), "orbital_flight")
	orbit_check("isotope generator gated", get_recipe_node_req("/obj/structure/civ_generator/isotope"), "orbital_flight")
	map.ordinal_age = 7
	orbit_check("no isotope power before 2013", civ_generation_era(/obj/structure/civ_generator/isotope) ? 1 : 0, 0)

// Wear (orbit_wear.dm): scrubber sorbent and its cartridge, panel wear in
// sunlight only, its cap and output loss, glass repairs, starter spares.
/proc/orbit_wear_checks()
	var/mob/living/human/eva_tester/H = new(locate(3, 3, 5))
	H.m_intent = "stealth"
	var/obj/structure/life_support/scrubber/S = new(locate(3, 4, 5))
	orbit_check("fresh sorbent bed", S.sorbent, 100)
	orbit_sorbent_use(S, 100)
	orbit_check("scrubbing wears the bed", S.sorbent, 90)
	orbit_check("a part-used bed still works", orbit_sorbent_ready(S) ? 1 : 0, 1)
	orbit_sorbent_use(S, 5000)
	orbit_check("bed runs out", S.sorbent, 0)
	orbit_check("a spent bed stops the scrubber", orbit_sorbent_ready(S) ? 1 : 0, 0)
	var/obj/item/sorbent_cartridge/cart = new(H)
	S.attackby(cart, H)
	orbit_check("a cartridge refills the bed", "[S.sorbent],[QDELETED(cart) ? 1 : 0]", "100,1")
	var/obj/structure/civ_generator/solar/wing/tracking/W = orbit_find_on(/obj/structure/civ_generator/solar/wing/tracking, 5)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	R.sunlit = 1
	W.wear = 0
	orbit_wear_step(3600)
	orbit_check("cells wear in sunlight", round(W.wear, 0.01), 3)
	orbit_check("worn cells give less", W.rated_output(), 34)
	R.sunlit = 0
	orbit_wear_step(3600)
	orbit_check("no wear in the shade", round(W.wear, 0.01), 3)
	R.sunlit = 1
	orbit_wear_step(3600 * 100)
	orbit_check("wear stops at half", W.wear, 50)
	orbit_check("half output at worst", W.rated_output(), 18)
	var/obj/item/stack/material/glass/G = new(H, 2)
	W.attackby(G, H)
	orbit_check("glass replaces cells", W.wear, 25)
	var/obj/structure/closet/crate/crate = orbit_find_on(/obj/structure/closet/crate, 5)
	var/carts = 0
	for (var/obj/item/sorbent_cartridge/C in crate)
		carts++
	orbit_check("starter spares", carts, 2)
	orbit_check("cartridge gated", get_recipe_node_req("/obj/item/sorbent_cartridge"), "life_support")
	qdel(H)

// Sectors (orbit_sectors.dm): the 2026 gate, reach, party, claiming and
// linking a sector, the quota, seam margins for modules and pods, and edge
// couplers joining cables across the seam.
/proc/orbit_sector_cable(x, y, z)
	var/obj/structure/cable/C = new(locate(x, y, z))
	C.d1 = 0
	C.d2 = WEST
	return C

/proc/orbit_sector_checks()
	var/party = "civ:gaia:Gamma"
	orbit_release_plane(4)
	var/mob/living/human/eva_tester/H = new(locate(16, world.maxy - 2, 5))
	H.m_intent = "stealth"
	H.party_train_party = party
	var/mob/living/human/eva_tester/O = new(locate(17, world.maxy - 2, 5))
	O.m_intent = "stealth"
	O.party_train_party = "civ:gaia:Beta"
	var/turf/edge = H.loc
	orbit_check("nearest edge", orbit_sector_side(edge), "north")
	orbit_check("no edge from the middle", orbit_sector_side(locate(16, 16, 5)) ? 1 : 0, 0)
	map.ordinal_age = 8
	orbit_check("no sectors before 2026", findtext("[orbit_sector_refusal(edge, "north", H)]", "2026") ? 1 : 0, 1)
	map.ordinal_age = 9
	orbit_check("outsiders cannot claim", findtext("[orbit_sector_refusal(edge, "north", O)]", "Gamma") ? 1 : 0, 1)
	orbit_check("too far from the edge", findtext("[orbit_sector_refusal(locate(16, 16, 5), null, H)]", "edge") ? 1 : 0, 1)
	orbit_check("members can claim", isnull(orbit_sector_refusal(edge, "north", H)) ? 1 : 0, 1)
	var/obj/item/connector/riser/coupler/K1 = new(locate(16, world.maxy - 1, 5))
	K1.anchored = TRUE
	var/obj/structure/cable/A = orbit_sector_cable(16, world.maxy - 1, 5)
	K1.connect_cables()
	var/level = orbit_add_sector(5, "north")
	orbit_check("sector claimed", level, 4)
	orbit_check("sector linked both ways", "[orbit_plane_link(5, "north")],[orbit_plane_link(4, "south")]", "4,5")
	orbit_check("sector owned by the station", orbit_station_party(4), party)
	orbit_check("one sector per side", findtext("[orbit_sector_refusal(edge, "north", H)]", "already") ? 1 : 0, 1)
	var/turf/across = locate(16, world.maxy, 5)
	orbit_check("the seam leads into the sector", across.orbit_seam_destination() == locate(16, 2, 4) ? 1 : 0, 1)
	var/obj/structure/cable/B = orbit_sector_cable(16, 2, 4)
	var/obj/item/connector/riser/coupler/K2 = new(locate(16, 2, 4))
	K2.anchored = TRUE
	K2.connect_cables()
	orbit_check("couplers pair across the seam", (K1 in K2.riser_partners()) && (K2 in K1.riser_partners()) ? 1 : 0, 1)
	orbit_check("cables join across the seam", (A.riser_links && (B in A.riser_links)) ? 1 : 0, 1)
	var/obj/item/connector/riser/coupler/K3 = new(locate(16, 3, 4))
	K3.anchored = TRUE
	orbit_check("a coupler off the seam has no partner", length(K3.riser_partners()), 0)
	var/obj/item/connector/riser/V = new(locate(16, 2, 5))
	V.anchored = TRUE
	orbit_check("plain risers ignore couplers", (K2 in V.riser_partners()) ? 1 : 0, 0)
	orbit_check("modules keep clear of the seam", findtext("[habitat_module_refusal(locate(16, 4, 4), null)]", "seam") ? 1 : 0, 1)
	orbit_check("modules fit inside the margin", isnull(habitat_module_refusal(locate(16, 6, 4), null)) ? 1 : 0, 1)
	orbit_check("pods keep clear of the seam", orbit_pod_blocker(locate(16, 4, 4), null), "edge")
	orbit_check("no free plane for another sector", findtext("[orbit_sector_refusal(locate(world.maxx - 2, 16, 5), "east", H)]", "taken") ? 1 : 0, 1)
	orbit_check("beacon gated", get_recipe_node_req("/obj/item/sector_beacon"), "orbital_flight")
	orbit_check("coupler gated", get_recipe_node_req("/obj/item/connector/riser/coupler"), "orbital_flight")
	map.ordinal_age = 7
	qdel(H)
	qdel(O)

// Reusable launch (orbit_reusable.dm): the 2026 gate, the crew ship's seats
// and flight field, booster wear and return, refurbishment, and an
// eight-seat capsule in orbit.
/proc/orbit_reusable_checks()
	var/obj/map_metadata/orbit_map = map
	shard_group.region = "gaia"
	shard_group.peers["orbit"]["free_planes"] = 3
	map = new /obj/map_metadata/nomads/flight_tester
	map.ordinal_age = 8
	var/obj/structure/crewed_lander/orbital_rocket/reusable/R = new(locate(2, 3, 1))
	orbit_check("crew ship seats", R.seats, 8)
	orbit_check("no reusable rockets before 2026", findtext("[R.vehicle_refusal("orbit")]", "2026") ? 1 : 0, 1)
	map.ordinal_age = 9
	orbit_check("reusable rocket flies to orbit", isnull(R.vehicle_refusal("orbit")) ? 1 : 0, 1)
	orbit_check("reusable rocket flies nowhere else", findtext("[R.vehicle_refusal("moon")]", "only flies to orbit") ? 1 : 0, 1)
	var/list/flight = list("lander" = "gaia-2-1", "orbit" = 1)
	R.flight_extras(flight)
	orbit_check("crew ship flight carries its seats", flight["seats"], 8)
	orbit_check("seats payload valid", space_flight_payload_ok(flight) ? 1 : 0, 1)
	orbit_check("too many seats refused", space_flight_payload_ok(list("lander" = "gaia-2-1", "orbit" = 1, "seats" = 9)) ? 1 : 0, 0)
	orbit_check("seats only on orbit flights", space_flight_payload_ok(list("lander" = "gaia-2-1", "return" = 1, "seats" = 8)) ? 1 : 0, 0)
	var/turf/T = get_turf(R)
	qdel(R)
	var/obj/structure/crewed_lander/orbital_rocket/reusable/B = orbit_booster_return(T, 100 - ORBIT_BOOSTER_WEAR)
	orbit_check("booster lands back worn and empty", B ? "[B.condition],[B.propellant],[get_turf(B) == T ? 1 : 0]" : "none", "80,0,1")
	B.condition = 10
	orbit_check("a worn booster will not fly", findtext("[B.vehicle_refusal("orbit")]", "worn") ? 1 : 0, 1)
	var/mob/living/human/eva_tester/H = new(locate(3, 3, 1))
	H.m_intent = "stealth"
	var/obj/item/stack/material/steel/S = new(H, 50)
	B.attackby(S, H)
	orbit_check("steel refurbishes the booster", "[B.condition],[S.amount]", "100,27")
	orbit_check("reusable rocket gated", get_recipe_node_req("/obj/structure/crewed_lander/orbital_rocket/reusable"), "orbital_flight")
	qdel(B)
	qdel(H)
	del(map)
	map = orbit_map
	map.ordinal_age = 7
	shard_group.region = "orbit"
	space_flight_arrival_turf(list("lander" = "gaia-2-2", "orbit" = 1, "seats" = 8), TRUE)
	var/obj/structure/landed_lander/capsule/C = space_landed_lander("gaia-2-2")
	orbit_check("crew ship capsule seats eight home", C ? C.lift_seats : 0, 8)
	if (C)
		C.spend()

// The 2026 starter station (orbit_project.dm): two decks joined through open
// deck hatches, the upper deck's modules sealed and powered through a riser,
// and a sector beacon in the crate.
/proc/orbit_two_deck_checks()
	var/party = "civ:gaia:Delta"
	world.maxx = 32
	world.maxy = 32
	for (var/p in 2 to 5)
		orbit_release_plane(p)
	for (var/p in 2 to 3)
		orbit_claim_plane("keep")
	for (var/p in 4 to 5)
		for (var/turf/T in block(locate(1, 1, p), locate(world.maxx, world.maxy, p)))
			for (var/obj/O in T)
				if (!istype(O, /obj/effect))
					qdel(O)
			if (!istype(T, /turf/floor/space/orbit))
				T.ChangeTurf(/turf/floor/space/orbit, FALSE, FALSE)
	map.ordinal_age = 9
	var/turf/at = party_train_arrival_turf(list("party" = party, "from" = "gaia"))
	orbit_check("2026 station founded", at ? at.z : 0, 4)
	orbit_check("2026 station has two decks", length(orbit_station_planes(party)), 2)
	orbit_check("upper deck linked above", orbit_plane_link(4, "up"), 5)
	var/kinds = list()
	var/sealed = 0
	for (var/obj/structure/habitat_core/C in orbit_station_modules(5))
		kinds += C.kind
		if (!C.breaches())
			sealed++
	orbit_check("upper deck modules", length(kinds), 3)
	orbit_check("upper deck sealed", sealed, 3)
	orbit_check("upper deck has quarters and storage", ("quarters" in kinds) && ("storage" in kinds) ? 1 : 0, 1)
	var/obj/structure/habitat_core/node/N = locate(/obj/structure/habitat_core/node) in locate(16, 16, 4)
	var/obj/structure/deck_hatch/H = N ? N.deck_hatch() : null
	orbit_check("lower hub sealed with its hatch open", N ? N.breaches() : -1, 0)
	orbit_check("deck hatches open and joined", H && H.open && H.partner("up") && H.partner("up").open ? 1 : 0, 1)
	var/obj/item/connector/riser/R = locate() in locate(16, 16, 5)
	orbit_check("upper deck powered through a riser", R && length(R.riser_partners()) ? 1 : 0, 1)
	var/obj/structure/cable/up_cable = locate() in locate(16, 16, 5)
	var/obj/structure/cable/down_cable = locate() in locate(16, 16, 4)
	orbit_check("upper cables join the lower spine", up_cable && down_cable && up_cable.riser_links && (down_cable in up_cable.riser_links) ? 1 : 0, 1)
	var/obj/structure/life_support/scrubber/S = locate() in locate(15, 15, 5)
	orbit_check("upper scrubber cabled", S && S.powersource ? 1 : 0, 1)
	var/obj/structure/closet/crate/crate = orbit_find_on(/obj/structure/closet/crate, 4)
	orbit_check("sector beacon in the crate", crate && (locate(/obj/item/sector_beacon) in crate) ? 1 : 0, 1)
	map.ordinal_age = 7

// The wider network (orbit_network.dm): flights from orbit down to the Moon
// and from the Moon up to orbit, and the station transceiver's built-in dish.
/proc/orbit_network_checks()
	var/obj/map_metadata/orbit_map = map
	map.ordinal_age = 9
	shard_group.region = "orbit"
	// The probe runs without the shipped survey maps, so the Moon gets one.
	var/datum/survey_map/moon_map = new
	moon_map.region = "moon"
	var/had_map = space_survey_maps["moon"]
	space_survey_maps["moon"] = moon_map
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = new(locate(3, 3, 1))
	var/list/choices = pad.peer_choices()
	orbit_check("a station pad leads to the Moon", ("Moon (moon)" in choices) ? 1 : 0, 1)
	orbit_check("a station pad leads home", ("Gaia (gaia)" in choices) ? 1 : 0, 1)
	orbit_check("a station pad never leads to orbit", ("Orbit (orbit)" in choices) ? 1 : 0, 0)
	qdel(pad)
	var/obj/structure/crewed_lander/lander = new(locate(4, 4, 1))
	orbit_check("a lander flies from orbit to the Moon", isnull(lander.vehicle_refusal("moon")) ? 1 : 0, 1)
	qdel(lander)
	if (had_map)
		space_survey_maps["moon"] = had_map
	else
		space_survey_maps -= "moon"
	shard_group.region = "moon"
	map = new /obj/map_metadata/nomads/flight_tester
	map.ordinal_age = 9
	orbit_check("the Moon can fly up to orbit", space_flight_orbit_ok("orbit") ? 1 : 0, 1)
	del(map)
	map = orbit_map
	shard_group.region = "orbit"
	var/obj/structure/telecom/relay/station/T = new(locate(5, 5, 1))
	orbit_check("transceiver has its own dish", T.has_antenna() ? 1 : 0, 1)
	orbit_check("transceiver gated like a relay", get_recipe_node_req("/obj/structure/telecom/relay/station"), "factories")
	qdel(T)
	map.ordinal_age = 7

// Methane-oxygen fuel (methalox.dm) and the uncrewed cargo freighter
// (orbit_freight.dm): chemistry, the plant's CO2, booster wear on methalox,
// freight payloads, arrival beside the party's station hatch, a refused
// flight coming back, and journal replays.
/proc/orbit_freight_checks()
	var/party = "civ:gaia:Delta"
	map.ordinal_age = 9
	// The probe world skips startup, which builds the reaction tables.
	if (!length(chemical_reagents_list))
		initialize_chemical_reagents()
	if (!length(chemical_reactions_list))
		initialize_chemical_reactions()
	var/obj/item/weapon/reagent_containers/glass/beaker/large/G = new(locate(3, 3, 1))
	G.reagents.add_reagent("carbon_dioxide", 10)
	G.reagents.add_reagent("hydrogen", 40)
	// Reactions normally run on the chemistry process, which the probe lacks.
	G.reagents.process_reactions()
	orbit_check("CO2 and hydrogen make methane", round(G.reagents.get_reagent_amount("methane")), 10)
	G.reagents.add_reagent("oxygen", 20)
	G.reagents.process_reactions()
	orbit_check("methane and oxygen make methalox", round(G.reagents.get_reagent_amount("methalox")), 30)
	var/obj/structure/crewed_lander/orbital_rocket/reusable/R = new(locate(4, 3, 1))
	orbit_check("booster takes methalox", R.add_propellant(G.reagents), 30)
	orbit_check("methalox in the tank", R.fuel_kind, "methalox")
	orbit_check("methalox halves booster wear", R.flight_wear(), ORBIT_BOOSTER_WEAR / 2)
	G.reagents.add_reagent("rocket_propellant", 10)
	orbit_check("one fuel at a time", R.add_propellant(G.reagents), 0)
	var/obj/structure/crewed_lander/lander = new(locate(5, 3, 1))
	orbit_check("a lander burns no methalox", lander.fuel_offered(G.reagents) && lander.fuel_in(G.reagents) == "rocket_propellant" ? 1 : 0, 1)
	qdel(lander)
	qdel(R)
	qdel(G)

	// The plant finds CO2 inside a module, never in open orbit.
	var/obj/structure/reagent_dispensers/propellant_plant/methalox/P = new(locate(6, 3, 1))
	orbit_check("no CO2 in open orbit", P.co2_source() ? 1 : 0, 0)
	var/obj/structure/region_gate/station_hatch/hatch = orbit_station_hatch(party)
	orbit_check("Delta's station hatch for freight", hatch ? 1 : 0, 1)
	if (!hatch)
		return
	var/turf/floor/habitat/F = null
	for (var/turf/floor/habitat/HT in orange(1, get_turf(hatch)))
		if (HT.habitat_core())
			F = HT
			break
	P.forceMove(F)
	var/datum/habitat_ledger/L = P.co2_source()
	orbit_check("plant takes CO2 from the module", istype(L) ? 1 : 0, 1)
	if (istype(L))
		L.co2 = 0.5
		orbit_check("too little CO2 for a batch", P.feedstock_ready() ? 1 : 0, 0)
		L.co2 = 3
		orbit_check("enough CO2 for a batch", P.feedstock_ready() ? 1 : 0, 1)
		P.use_feedstock()
		orbit_check("a batch scrubs the module", L.co2, 2)
	orbit_check("methalox plant gated", get_recipe_node_req("/obj/structure/reagent_dispensers/propellant_plant/methalox"), "local_resources")
	qdel(P)

	// Freight payloads.
	var/obj/structure/crewed_lander/freighter/FR = new(locate(7, 3, 1))
	map.ordinal_age = 7
	orbit_check("no freighters before 2013", findtext("[FR.vehicle_refusal("gaia")]", "2013") ? 1 : 0, 1)
	map.ordinal_age = 8
	orbit_check("freighter takes methalox and propellant", ("methalox" in FR.fuels) && ("rocket_propellant" in FR.fuels) ? 1 : 0, 1)
	orbit_check("freighter has no seats", FR.seats, 0)
	orbit_check("freighter has an id", istext(FR.freight_id) ? 1 : 0, 1)
	orbit_check("freighter gated", get_recipe_node_req("/obj/structure/crewed_lander/freighter"), "orbital_flight")
	var/list/cargo = list(list("stack:steel", 30), list("/obj/item/pressure_tank", 1))
	var/payload = orbit_freight_payload(FR.freight_id, party, locate(7, 3, 1), cargo, "tester")
	var/list/decoded = orbit_freight_decode(payload)
	orbit_check("freight payload round trip", decoded ? "[decoded["party"]],[length(decoded["cargo"])]" : "null", "[party],2")
	orbit_check("freight payloads detected", orbit_freight_payloads(list(payload)) ? 1 : 0, 1)
	orbit_check("characters are not freight", orbit_freight_payloads(list(json_encode(list("v" = 1, "kind" = "character")))) ? 1 : 0, 0)
	var/list/extra = json_decode(payload)
	extra["seats"] = 3
	orbit_check("unknown freight fields refused", orbit_freight_decode(json_encode(extra)) ? 1 : 0, 0)
	var/list/big = list()
	for (var/i in 1 to 21)
		big += list(list("stack:steel", 1))
	orbit_check("an overfull hold refused", orbit_freight_decode(orbit_freight_payload("x", party, locate(7, 3, 1), big, null)) ? 1 : 0, 0)
	orbit_check("unknown goods refused", orbit_freight_decode(orbit_freight_payload("x", party, locate(7, 3, 1), list(list("/obj/item/weapon/gun/energy", 1)), null)) ? 1 : 0, 0)

	// Arrival beside the hatch, and a refused flight back where it left.
	var/before = length(orbit_find_all(/obj/structure/closet/crate, hatch.z, hatch.x - 1, hatch.y - 1, hatch.x + 1, hatch.y + 1))
	orbit_freight_arrive(list(payload), TRUE)
	var/list/crates = orbit_find_all(/obj/structure/closet/crate, hatch.z, hatch.x - 1, hatch.y - 1, hatch.x + 1, hatch.y + 1)
	orbit_check("freight lands beside the station hatch", length(crates) - before, 1)
	var/obj/structure/closet/crate/delivered = null
	for (var/obj/structure/closet/crate/C in crates)
		if (C.name == "freight crate")
			delivered = C
	var/obj/item/stack/material/steel/steel = delivered ? locate() in delivered : null
	orbit_check("freight crate holds the cargo", steel ? "[steel.amount],[(locate(/obj/item/pressure_tank) in delivered) ? 1 : 0]" : "none", "30,1")
	orbit_check("crate off the hatch tile", delivered && get_turf(delivered) != get_turf(hatch) ? 1 : 0, 1)
	orbit_freight_arrive(list(payload), FALSE)
	var/obj/structure/closet/crate/back = locate() in locate(7, 3, 1)
	orbit_check("refused freight comes back where it left", back ? back.name : "none", "returned freight crate")
	if (back)
		qdel(back)

	// Journal replays: a departure finds the freighter by its id, and an
	// arrival unpacks again.
	var/obj/item/pressure_tank/tank = new(FR)
	transfer_bridge.replay(list(list("effect_id" = "probe-freight:remove", "kind" = "remove", "payloads" = list(payload))))
	orbit_check("replayed departure sends the freighter again", QDELETED(FR) && QDELETED(tank) ? 1 : 0, 1)
	transfer_bridge.replay(list(list("effect_id" = "probe-freight:return", "kind" = "return", "payloads" = list(payload))))
	back = locate() in locate(7, 3, 1)
	orbit_check("replayed return unpacks the crate", back ? back.name : "none", "returned freight crate")
	if (back)
		qdel(back)
	transfer_bridge.applied -= list("probe-freight:remove", "probe-freight:return")
	if (delivered)
		qdel(delivered)
	map.ordinal_age = 7

// A stand-in transfer agent: it answers the bridge's requests the way the
// real agent does (tools/transfer_storage/region.py), so a freighter's
// launch and arrival run through the real bridge code. Everything it was sent
// for escrow comes back as one pending incoming freight transfer.
/datum/transfer_bridge/probe_agent
	var/list/sent = list()
	var/list/paths = list()
	var/list/fast = list()

/datum/transfer_bridge/probe_agent/request(path, list/body)
	paths += path
	if (islist(body) && !isnull(body["fast"]))
		fast += body["fast"]
	switch (path)
		if ("/escrow")
			sent += body["payloads"]
			return list("ok" = 1, "result" = list("transfer_id" = "probe-out", "effect_id" = "probe-out:remove"))
		if ("/status")
			if (!length(sent))
				return list("ok" = 1, "result" = list("pending_transfers" = list(), "active" = list()))
			return list("ok" = 1, "result" = list(
				"pending_transfers" = list("probe-in"),
				"active" = list(list("transfer_id" = "probe-in", "direction" = "in")),
				"pending_kinds" = list("probe-in" = list("freight"))))
		if ("/import")
			return list("ok" = 1, "result" = list("effect_id" = "probe-in:credit", "payloads" = sent.Copy()))
	return null

// A freighter flies from a station pad down to Gaia through the bridge,
// then the same freight arrives back in orbit through the bridge's poll and
// lands beside the party's station hatch.
/proc/orbit_freight_flight_checks()
	var/party = "civ:gaia:Delta"
	var/datum/transfer_bridge/real_bridge = transfer_bridge
	var/datum/transfer_bridge/probe_agent/agent = new
	agent.port = 1
	agent.token = "probe"
	agent.ledger_base = 0
	agent.peers = list("gaia")
	transfer_bridge = agent
	var/list/real_gaia = shard_group.peers["gaia"]
	shard_group.peers["gaia"] = list("kind" = "NOMADS", "name" = "Gaia", "state" = "UP")
	map.ordinal_age = 8
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = new(locate(11, 3, 1))
	pad.destination = "gaia"
	pad.approved = TRUE
	var/obj/structure/crewed_lander/freighter/F = new(locate(10, 3, 1))
	var/fid = F.freight_id
	var/mob/living/human/eva_tester/H = new(locate(10, 4, 1))
	H.party_train_party = party
	var/obj/item/stack/material/steel/S = new(F, 25)
	new /obj/item/pressure_tank(F)
	F.propellant = 200
	F.fuel_kind = "methalox"
	orbit_check("pad open for freight", "[pad.closed_reason()]", "")
	orbit_check("freighter launch refusal", "[F.freight_refusal(H)]", "Only players with a BYOND account can launch a freighter.")
	var/reason = F.launch_freight(pad, H)
	orbit_check("freighter launched through the bridge", "[reason]", "")
	orbit_check("freighter spent", QDELETED(F) && QDELETED(S) ? 1 : 0, 1)
	orbit_check("one fast escrow sent", "[jointext(agent.paths, ",")]|[length(agent.sent)]", "/escrow|1")
	var/list/P = length(agent.sent) ? orbit_freight_decode(agent.sent[1]) : null
	orbit_check("escrowed freight payload", P ? "[P["id"] == fid ? 1 : 0],[P["party"]],[length(P["cargo"])]" : "null", "1,[party],2")
	var/obj/structure/region_gate/station_hatch/hatch = orbit_station_hatch(party)
	var/before = hatch ? length(orbit_find_all(/obj/structure/closet/crate, hatch.z, hatch.x - 1, hatch.y - 1, hatch.x + 1, hatch.y + 1)) : 0
	agent.poll_once()
	orbit_check("poll routes freight to an import", ("/import" in agent.paths) ? 1 : 0, 1)
	orbit_check("escrow and import are both fast", jointext(agent.fast, ","), "1,1")
	orbit_check("import recorded", ("probe-in:credit" in agent.applied) ? 1 : 0, 1)
	var/list/crates = hatch ? orbit_find_all(/obj/structure/closet/crate, hatch.z, hatch.x - 1, hatch.y - 1, hatch.x + 1, hatch.y + 1) : list()
	orbit_check("flown freight lands beside the hatch", length(crates) - before, 1)
	var/obj/structure/closet/crate/landed = null
	for (var/obj/structure/closet/crate/C in crates)
		if (C.name == "freight crate")
			landed = C
	var/obj/item/stack/material/steel/arrived = landed ? locate() in landed : null
	orbit_check("flown cargo intact", arrived ? "[arrived.amount],[(locate(/obj/item/pressure_tank) in landed) ? 1 : 0]" : "none", "25,1")
	var/imports = 0
	agent.poll_once()
	for (var/p in agent.paths)
		if (p == "/import")
			imports++
	orbit_check("a recorded import is not taken twice", imports, 1)
	if (landed)
		qdel(landed)
	qdel(pad)
	qdel(H)
	transfer_bridge = real_bridge
	shard_group.peers["gaia"] = real_gaia
	map.ordinal_age = 7

// Satellites (satellites.dm): launches from a Gaia pad pointed at orbit, the
// ground station's satellites, the weather report, the comms link for
// relays, GPS fixes and bearings, the era gate, and a survey orbiter mapping
// the Moon for a mission console.
/proc/orbit_satellite_load(obj/structure/crewed_lander/satellite_launcher/L, path)
	var/obj/item/satellite/S = new path(L)
	L.propellant = 150
	return S

/proc/orbit_satellite_checks()
	var/obj/map_metadata/orbit_map = map
	shard_group.region = "gaia"
	map = new /obj/map_metadata/nomads/flight_tester
	map.ordinal_age = 7
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = new(locate(20, 3, 1))
	pad.destination = "orbit"
	pad.approved = TRUE
	var/obj/structure/satellite_station/G = new(locate(24, 3, 1))
	var/obj/structure/telecom/relay/R = new(locate(26, 3, 1))
	orbit_check("relay without antenna or satellite", R.has_antenna() ? 1 : 0, 0)
	orbit_check("no GPS fix without a satellite", satellite_service("navigation") ? 1 : 0, 0)
	var/obj/structure/crewed_lander/satellite_launcher/L = new(locate(20, 4, 1))
	orbit_check("launcher wants a satellite", "[L.satellite_refusal()]", "Load a satellite first.")
	orbit_check("launcher takes only satellites", "[L.stow_refusal(new /obj/item/pressure_tank(locate(21, 4, 1)))]", "Only a satellite fits the fairing.")
	orbit_satellite_load(L, /obj/item/satellite/navigation)
	orbit_check("no navigation satellites before 2013", findtext("[L.satellite_refusal()]", "later age") ? 1 : 0, 1)
	for (var/obj/item/I in L.hold())
		qdel(I)
	orbit_satellite_load(L, /obj/item/satellite/weather)
	L.propellant = 100
	orbit_check("launcher needs fuel", findtext("[L.satellite_refusal()]", "150") ? 1 : 0, 1)
	L.propellant = 150
	orbit_check("weather satellite goes up", "[L.launch_satellite(null)]", "")
	orbit_check("launcher spent", QDELETED(L) ? 1 : 0, 1)
	orbit_check("ground station talks to the weather satellite", ("weather" in G.satellites) ? 1 : 0, 1)
	var/list/report = satellite_weather_report()
	orbit_check("weather report", length(report) >= 2 && findtext(report[1], "Weather:") && findtext(report[2], "Forecast:") ? 1 : 0, 1)
	L = new(locate(20, 4, 1))
	orbit_satellite_load(L, /obj/item/satellite/weather)
	orbit_check("one satellite of a kind per station", findtext("[L.satellite_refusal()]", "already") ? 1 : 0, 1)
	for (var/obj/item/I in L.hold())
		qdel(I)
	orbit_satellite_load(L, /obj/item/satellite/comms)
	orbit_check("comms satellite goes up", "[L.launch_satellite(null)]", "")
	orbit_check("relay linked through the satellite", R.has_antenna() ? 1 : 0, 1)
	map.ordinal_age = 8
	L = new(locate(20, 4, 1))
	orbit_satellite_load(L, /obj/item/satellite/navigation)
	orbit_check("navigation satellite goes up", "[L.launch_satellite(null)]", "")
	orbit_check("GPS fix with a navigation satellite", satellite_service("navigation") ? 1 : 0, 1)
	orbit_check("GPS bearing", gps_bearing(locate(5, 5, 1), "9,2,1", "Home"), "Home is 4 tiles southeast.")
	orbit_check("GPS bearing across levels", gps_bearing(locate(5, 5, 1), "5,5,2", "Deck"), "Deck is right here. It is 1 level up.")
	orbit_check("GPS at the waypoint", gps_bearing(locate(5, 5, 1), "5,5,1", "Camp"), "You are at Camp.")
	// Raids: a station belongs to the party that launches to it, and another
	// party can take it over or cut a satellite's link.
	var/obj/structure/satellite_station/G2 = new(locate(30, 10, 1))
	var/mob/living/human/eva_tester/owner = new(locate(30, 11, 1))
	owner.m_intent = "stealth"
	owner.civilization = "Foxtrot"
	var/mob/living/human/eva_tester/raider = new(locate(31, 10, 1))
	raider.m_intent = "stealth"
	raider.civilization = "Golf"
	var/fox = party_train_party_of(owner)
	var/golf = party_train_party_of(raider)
	qdel(G)
	var/obj/structure/region_gate/trail_marker/launch_pad/pad2 = new(locate(26, 10, 1))
	pad2.destination = "orbit"
	pad2.approved = TRUE
	L = new(locate(27, 10, 1))
	orbit_satellite_load(L, /obj/item/satellite/navigation)
	L.propellant = 150
	orbit_check("owned navigation satellite goes up", "[L.launch_satellite(owner)]", "")
	orbit_check("station claimed by its first launch", G2.owner, fox)
	orbit_check("GPS fix for the owners", satellite_service("navigation", fox) ? 1 : 0, 1)
	orbit_check("no GPS fix for others", satellite_service("navigation", golf) ? 1 : 0, 0)
	L = new(locate(27, 10, 1))
	orbit_satellite_load(L, /obj/item/satellite/weather)
	L.propellant = 150
	orbit_check("others cannot launch to it", findtext("[L.satellite_refusal(raider)]", "Take it over") ? 1 : 0, 1)
	orbit_check("owners need no break-in", findtext("[G2.hack_refusal(owner)]", "already") ? 1 : 0, 1)
	orbit_check("raider may break in", "[G2.hack_refusal(raider)]", "")
	G2.hack(raider, "navigation")
	orbit_check("cut link silences the satellite", ("navigation" in G2.satellites) ? 1 : 0, 0)
	orbit_check("cut satellite is lost, not gone", ("navigation" in G2.lost) ? 1 : 0, 1)
	orbit_check("raiders cannot reacquire it", findtext(G2.relink(raider, "navigation"), "no longer") ? 1 : 0, 1)
	orbit_check("nothing left to raid", findtext("[G2.hack_refusal(raider)]", "no satellite") ? 1 : 0, 1)
	orbit_check("owners reacquire it", findtext(G2.relink(owner, "navigation"), "locks on") ? 1 : 0, 1)
	orbit_check("reacquired satellite serves again", satellite_service("navigation", fox) && !length(G2.lost) ? 1 : 0, 1)
	G2.hack(raider, "navigation")
	orbit_check("weather satellite goes up for the owners", "[L.launch_satellite(owner)]", "")
	G2.hack(raider)
	orbit_check("raid takes the station over", G2.owner, golf)
	orbit_check("the raiders read it now", G2.serves(golf) && !G2.serves(fox) ? 1 : 0, 1)
	qdel(owner)
	qdel(raider)
	qdel(pad2)
	qdel(G2)
	L = new(locate(20, 4, 1))
	orbit_satellite_load(L, /obj/item/satellite/comms)
	orbit_check("a satellite needs a ground station", findtext("[L.satellite_refusal()]", "ground station") ? 1 : 0, 1)
	for (var/obj/item/I in L.hold())
		qdel(I)

	// A survey orbiter flies to the Moon and maps it for a mission console.
	var/datum/survey_map/moon_map = new
	moon_map.region = "moon"
	moon_map.seed = "probe"
	moon_map.width = 4
	moon_map.height = 2
	moon_map.rows = list("..^.", "~...")
	var/had_map = space_survey_maps["moon"]
	space_survey_maps["moon"] = moon_map
	pad.destination = "moon"
	orbit_satellite_load(L, /obj/item/satellite/survey)
	orbit_check("survey orbiter needs a mission console", findtext("[L.satellite_refusal()]", "mission console") ? 1 : 0, 1)
	var/obj/structure/survey_console/C = new(locate(22, 5, 1))
	orbit_check("survey orbiter goes to the Moon", "[L.launch_satellite(null)]", "")
	orbit_check("orbiter maps the whole Moon", C.map_region == "moon" && C.revealed == "11111111" ? 1 : 0, 1)
	orbit_check("orbiter marks every flat site it can", length(C.landing_sites_for("moon")), 6)
	if (had_map)
		space_survey_maps["moon"] = had_map
	else
		space_survey_maps -= "moon"
	for (var/path in list("/obj/structure/crewed_lander/satellite_launcher", "/obj/structure/satellite_station", "/obj/item/satellite/weather", "/obj/item/satellite/survey", "/obj/item/gps_receiver"))
		orbit_check("[path] gated", get_recipe_node_req(path), "orbital_flight")
	qdel(C)
	qdel(R)
	qdel(pad)
	del(map)
	map = orbit_map
	map.ordinal_age = 7
	shard_group.region = "orbit"

// A port whose owners count as online when crew is set.
/obj/structure/docking_port/probe_crew
	var/crew = FALSE

/obj/structure/docking_port/probe_crew/crew_aboard()
	return crew

// Station visits (orbit_docking.dm): ports belong to their plane's station,
// who may dock, ferrying across and home again, and parcels.
/proc/orbit_docking_checks()
	var/host = "civ:gaia:Delta"
	var/visitor = "civ:gaia:Echo"
	map.ordinal_age = 8
	// The fixture pool is small: free a plane the deck checks held back.
	for (var/p in 2 to world.maxz)
		if (orbit_plane_owner(p) == "keep")
			orbit_release_plane(p)
			for (var/turf/T in block(locate(1, 1, p), locate(world.maxx, world.maxy, p)))
				for (var/obj/O in T)
					if (!istype(O, /obj/effect))
						qdel(O)
				if (!istype(T, /turf/floor/space/orbit))
					T.ChangeTurf(/turf/floor/space/orbit, FALSE, FALSE)
			break
	var/turf/echo_at = party_train_arrival_turf(list("party" = visitor, "from" = "gaia"))
	if (!echo_at || orbit_station_party(echo_at.z) != visitor)
		visitor = null
	orbit_check("two stations to visit between", visitor ? 1 : 0, 1)
	if (!visitor)
		return
	map.ordinal_age = 8
	var/obj/structure/region_gate/station_hatch/HA = orbit_station_hatch(host)
	var/obj/structure/region_gate/station_hatch/HB = orbit_station_hatch(visitor)
	var/obj/structure/docking_port/probe_crew/A = new(orbit_freight_beside(get_turf(HA)))
	var/obj/structure/docking_port/B = new(orbit_freight_beside(get_turf(HB)))
	orbit_check("ports belong to their stations", "[A.owner()]|[B.owner()]", "[host]|[visitor]")
	var/obj/structure/docking_port/stray = new(locate(3, 3, 1))
	orbit_check("a port off any station is idle", stray.owner() ? 1 : 0, 0)
	qdel(stray)
	var/mob/living/human/eva_tester/V = new(get_turf(B))
	V.party_train_party = visitor
	V.m_intent = "stealth"
	orbit_check("visitor may use their port", "[B.use_refusal(V)]", "")
	map.ordinal_age = 7
	orbit_check("no docking before 2013", findtext("[B.use_refusal(V)]", "2013") ? 1 : 0, 1)
	map.ordinal_age = 8
	orbit_check("a closed station is not offered", length(B.ferry_choices(visitor)), 0)
	orbit_check("owners always welcome", A.welcomes(host) ? 1 : 0, 1)
	A.welcome = "guests"
	orbit_check("guests only once invited", A.welcomes(visitor) ? 1 : 0, 0)
	orbit_check("invite a guest", A.add_guest(visitor) ? 1 : 0, 1)
	orbit_check("owners cannot be their own guests", A.add_guest(host) ? 1 : 0, 0)
	var/label = "Station of [party_train_party_name(host)]"
	orbit_check("guest station offered", (label in B.ferry_choices(visitor)) ? 1 : 0, 1)
	orbit_check("ferry across", "[B.cross(V, label)]", "")
	orbit_check("visitor aboard the host station", V.z, A.z)
	orbit_check("way home offered", ("Home: your station" in A.ferry_choices(visitor)) ? 1 : 0, 1)
	orbit_check("ferry home", "[A.cross(V, "Home: your station")]", "")
	orbit_check("visitor home again", V.z, B.z)

	// Boarding raids: only while some of the owners are online.
	A.welcome = "owners"
	A.guests -= visitor
	var/raid_label = "Board [party_train_party_name(host)]"
	A.crew = FALSE
	orbit_check("no boarding while the owners are away", (raid_label in B.ferry_choices(visitor, TRUE)) ? 1 : 0, 0)
	orbit_check("the crew check asks who is online", B.crew_aboard() ? 1 : 0, 0)
	A.crew = TRUE
	orbit_check("boarding offered while the owners are aboard", (raid_label in B.ferry_choices(visitor, TRUE)) ? 1 : 0, 1)
	orbit_check("raiders board by force", "[B.cross(V, raid_label, TRUE)]", "")
	orbit_check("raider aboard the host station", V.z, A.z)
	orbit_check("raider can still ferry home", ("Home: your station" in A.ferry_choices(visitor)) ? 1 : 0, 1)
	A.cross(V, "Home: your station")
	A.crew = FALSE
	orbit_check("boarding refused once the crew leaves", findtext("[B.cross(V, raid_label, TRUE)]", "crew has left") ? 1 : 0, 1)
	A.welcome = "everyone"
	A.crew = TRUE
	orbit_check("no boarding a welcoming station", (raid_label in B.ferry_choices(visitor, TRUE)) ? 1 : 0, 0)
	A.welcome = "owners"

	// Parcels: anyone welcome leaves one for the station; owners for guests.
	var/obj/item/stack/material/steel/S = new(get_turf(A), 12)
	orbit_check("visitor leaves a parcel", "[A.leave_parcel(null, S, host)]", "")
	orbit_check("parcel waits for the owners", "[length(A.parcels(host))],[length(A.parcels(visitor))]", "1,0")
	orbit_check("no parcels for strangers", findtext("[A.leave_parcel(null, new /obj/item/pressure_tank(get_turf(A)), "civ:gaia:Nobody")]", "does not send") ? 1 : 0, 1)
	var/mob/living/human/eva_tester/O = new(get_turf(A))
	O.party_train_party = host
	O.m_intent = "stealth"
	orbit_check("owners collect their parcels", A.collect_parcels(O), 1)
	orbit_check("collected cargo at their feet", S.loc == get_turf(O) && S.amount == 12 ? 1 : 0, 1)
	A.welcome = "everyone"
	orbit_check("an open port welcomes anyone", A.welcomes("civ:gaia:Nobody") ? 1 : 0, 1)
	orbit_check("docking port gated", get_recipe_node_req("/obj/structure/docking_port"), "orbital_flight")
	qdel(S)
	for (var/obj/item/pressure_tank/T in get_turf(A))
		qdel(T)
	qdel(O)
	qdel(V)
	qdel(A)
	qdel(B)
	map.ordinal_age = 7

// A lab that is always on the grid, so the checks need no generators.
/obj/structure/zero_g_lab/probe_powered/draw_cable_power()
	return TRUE

// Zero-g manufacturing (orbit_lab.dm): where the lab works, feeding, batches,
// programmes and the empty-world pause.
/proc/orbit_lab_checks()
	var/obj/structure/zero_g_lab/stray = new(locate(3, 3, 1))
	orbit_check("lab refuses outside a module", findtext("[stray.work_refusal()]", "habitat") ? 1 : 0, 1)
	qdel(stray)
	var/z = 0
	for (var/p in 2 to world.maxz)
		if (orbit_station_party(p))
			z = p
	orbit_check("a station plane for the lab", z ? 1 : 0, 1)
	if (!z)
		return
	var/turf/centre = locate(world.maxx - 5, world.maxy - 5, z)
	var/obj/structure/habitat_core/C = habitat_unfold(centre, "laboratory")
	orbit_check("lab module sealed", C.breaches(), 0)
	var/obj/structure/zero_g_lab/probe_powered/L = new(locate(centre.x + 1, centre.y, z))
	orbit_check("lab gated", get_recipe_node_req("/obj/structure/zero_g_lab"), "orbital_flight")
	orbit_check("lab wants a cable", findtext("[L.work_refusal()]", "cable") ? 1 : 0, 1)
	var/obj/structure/cable/wire = new(get_turf(L))
	L.powersource = wire
	orbit_check("lab ready once cabled", "[L.work_refusal()]", "")
	orbit_check("lab idle unfed", L.step_work() || L.progress ? 1 : 0, 0)

	var/obj/item/stack/material/glass/G = new(get_turf(L), 50)
	var/obj/item/stack/material/copper/Cu = new(get_turf(L), 3)
	var/obj/item/stack/material/steel/St = new(get_turf(L), 10)
	orbit_check("lab takes glass", L.load(G), 50)
	orbit_check("lab takes copper", L.load(Cu), 3)
	orbit_check("lab refuses steel", L.load(St), 0)
	orbit_check("lab fed", L.fed() ? 1 : 0, 1)
	var/out = 0
	for (var/i in 1 to 30)
		if (L.step_work())
			out++
	orbit_check("one batch in thirty steps", out, 1)
	var/obj/item/stack/material/electronics/E = locate() in get_turf(L)
	orbit_check("semiconductors out", E ? E.amount : 0, 3)
	orbit_check("feed used", "[L.feed["glass"]]|[L.feed["copper"]]", "44|2")

	L.programme = "gems"
	L.progress = 0
	orbit_check("gems need coal", L.fed() ? 1 : 0, 0)
	var/obj/item/stack/ore/coal/coal = new(get_turf(L), 20)
	L.load(coal)
	L.progress = 29
	orbit_check("gem batch", L.step_work() ? 1 : 0, 1)
	orbit_check("diamond out", (locate(/obj/item/stack/ore/diamond) in get_turf(L)) ? 1 : 0, 1)
	orbit_check("coal used up", isnull(L.feed["coal"]) ? 1 : 0, 1)

	L.programme = "proteins"
	var/obj/item/stack/medical/bruise_pack/BP = new(get_turf(L), 5)
	L.load(BP)
	L.progress = 29
	orbit_check("protein batch", L.step_work() ? 1 : 0, 1)
	orbit_check("advanced packs out", (locate(/obj/item/stack/medical/advanced/bruise_pack) in get_turf(L)) ? 1 : 0, 1)

	L.programme = "semiconductors"
	L.progress = 5
	L.process()
	orbit_check("no work with nobody online", L.progress, clients.len ? 6 : 5)
	for (var/turf/T in range(2, centre))
		if (istype(T, /turf/wall/habitat_shell))
			T.ChangeTurf(/turf/floor/space/orbit, FALSE, FALSE)
			break
	orbit_check("breach stops the lab", findtext("[L.work_refusal()]", "breached") ? 1 : 0, 1)
	qdel(L)
	qdel(wire)

// A turret that is always powered and in fire control range.
/obj/structure/point_defence/probe_ready/ready()
	return isturf(loc)

// Station defences (orbit_defences.dm): armour plates soak strikes, turrets
// shoot them down and slow forced dockings.
/proc/orbit_defence_checks()
	var/z = 0
	for (var/p in 2 to world.maxz)
		if (orbit_station_party(p))
			z = p
	if (!z)
		orbit_check("a station plane for defences", 0, 1)
		return
	var/turf/centre = locate(world.maxx - 5, 6, z)
	var/obj/structure/habitat_core/C = habitat_unfold(centre, "armoury")
	var/mob/living/human/eva_tester/H = new(locate(centre.x, centre.y + 1, z))
	H.m_intent = "stealth"
	for (var/i in 1 to 4)
		var/obj/item/hull_plate/P = new(get_turf(H))
		H.put_in_active_hand(P)
		C.attackby(P, H)
	orbit_check("three plates at most", C.armour, 3)
	orbit_check("armour soaks a strike", barren_meteor_strike(C) ? 1 : 0, 0)
	orbit_check("a plate used up", C.armour, 2)
	orbit_check("hull still sealed", C.breaches(), 0)
	var/obj/structure/point_defence/probe_ready/D = new(locate(centre.x - 4, centre.y, z))
	D.intercept_chance = 100
	orbit_check("turret shoots the strike down", barren_meteor_strike(C) ? 1 : 0, 0)
	orbit_check("turret spares the armour", C.armour, 2)
	D.intercept_chance = 0
	barren_meteor_strike(C)
	barren_meteor_strike(C)
	orbit_check("armour gone after two more", C.armour, 0)
	orbit_check("the next strike holes the hull", barren_meteor_strike(C) ? 1 : 0, 1)
	orbit_check("breached", C.breaches() > 0 ? 1 : 0, 1)
	var/obj/structure/docking_port/port = new(locate(centre.x - 3, centre.y + 2, z))
	orbit_check("one turret slows a boarding", orbit_point_defence_delay(port), 150)
	var/obj/structure/point_defence/probe_ready/D2 = new(locate(centre.x - 3, centre.y - 2, z))
	var/obj/structure/point_defence/probe_ready/D3 = new(locate(centre.x - 2, centre.y - 2, z))
	orbit_check("two turrets count at most", orbit_point_defence_delay(port), 300)
	var/obj/structure/point_defence/plain = new(locate(3, 3, z))
	orbit_check("an uncabled turret is not ready", plain.ready() ? 1 : 0, 0)
	for (var/path in list("/obj/item/hull_plate", "/obj/structure/point_defence"))
		orbit_check("[path] gated", get_recipe_node_req(path), "orbital_flight")
	for (var/obj/O in list(D, D2, D3, plain, port, H))
		qdel(O)
