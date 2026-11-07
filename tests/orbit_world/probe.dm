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
	orbit_check("project shows progress", findtext(office.closed_reason(), "steel 0/150") ? 1 : 0, 1)
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
	world.maxx = 24
	world.maxy = 24
	for (var/z in 2 to 5)
		orbit_release_plane(z)
	var/turf/at = party_train_arrival_turf(list("party" = party, "from" = "gaia"))
	var/obj/structure/region_gate/station_hatch/hatch = orbit_station_hatch(party)
	orbit_check("first arrival founds the station", hatch && at == hatch.loc ? 1 : 0, 1)
	var/z = at ? at.z : 0
	orbit_check("station plane", z, 2)
	orbit_check("plane owned by the party", orbit_station_party(z), party)
	orbit_check("hatch leads home", hatch && hatch.home_region, "gaia")
	orbit_check("station modules", length(orbit_station_modules(z)), 2)
	var/sealed = 0
	for (var/obj/structure/habitat_core/C in orbit_station_modules(z))
		if (!C.breaches())
			sealed++
	orbit_check("station sealed", sealed, 2)
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
