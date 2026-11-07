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
	catch (var/exception/E)
		world.log << "ORBIT EXCEPTION: [E.name] [E.file]:[E.line]"
		orbit_failures++
	text2file("[orbit_failures ? "FAIL" : "PASS"]: orbit world failures=[orbit_failures]", "result.txt")
	shutdown()
