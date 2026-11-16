// Native fishing grounds probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/1713/fishing_grounds.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 64
	maxy = 64
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/fishing_grounds_probe/New()
	map = src
var/fg_failures = 0
var/fg_runtime_error = FALSE
/proc/fg_check(condition, label)
	if (!condition)
		fg_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	fg_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/fishing_grounds_probe
		fishing_grounds_checks()
	catch(var/exception/e)
		fg_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = fg_failures, "runtime_error" = fg_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/fg_water(x, y, type)
	var/turf/T = locate(x, y, 1)
	T.ChangeTurf(type, FALSE, FALSE)
	return locate(x, y, 1)

// Lets n minutes pass for a ground.
/proc/fg_wait(datum/fishing_ground/G, minutes)
	G.since -= minutes * 600

/proc/fishing_grounds_checks()
	// ---- Water ----
	var/turf/river = fg_water(5, 5, /turf/floor/beach/water)
	var/turf/pool = fg_water(6, 5, /turf/floor/beach/water/deep)
	var/turf/shelf = fg_water(20, 5, /turf/floor/beach/water/shallowsaltwater)
	var/turf/ocean = fg_water(40, 5, /turf/floor/beach/water/deep/saltwater)
	var/turf/swamp = fg_water(5, 20, /turf/floor/beach/water/swamp)
	var/turf/jungle = fg_water(20, 20, /turf/floor/beach/water/jungle)
	var/turf/ice = fg_water(40, 20, /turf/floor/beach/water/ice)
	var/turf/seabed = fg_water(40, 40, /turf/floor/beach/water/deep/saltwater/underwater)
	var/turf/land = locate(60, 60, 1)
	fg_check(fish_water_kind(river) == "fresh" && fish_water_kind(pool) == "fresh" && fish_water_kind(shelf) == "salt" && fish_water_kind(ocean) == "salt" && fish_water_kind(swamp) == "swamp" && fish_water_kind(jungle) == "jungle", "each water has its kind")
	fg_check(isnull(fish_water_kind(ice)) && isnull(fish_water_kind(seabed)) && isnull(fish_water_kind(land)), "ice, the seabed and dry land hold no fishing water")
	fg_check(fish_water_capacity(river, "fresh") == 6 && fish_water_capacity(pool, "fresh") == 10 && fish_water_capacity(shelf, "salt") == 12 && fish_water_capacity(ocean, "salt") == 6 && fish_water_capacity(swamp, "swamp") == 3, "the shelf holds 12, a deep river 10, a shallow river and the open sea 6, a swamp 3")

	// ---- A ground ----
	fg_check(!fishing_grounds.len && isnull(fishing_ground_at(river, FALSE)), "water nobody has fished has no record")
	fg_check(findtext(fish_ground_reading(river), "alive with fish") && !fishing_grounds.len, "unfished water reads as full without making a record")
	fg_check(isnull(fish_ground_reading(land)) && isnull(fish_ground_reading(ice)), "land and ice give no reading")
	var/datum/fishing_ground/G = fishing_ground_at(river)
	fg_check(G && G.capacity == 6 && G.stock == 6 && fishing_grounds.len == 1, "the first cast makes a full shallow-river ground of 6")
	fg_check(fishing_ground_at(locate(15, 15, 1), FALSE) == null && fishing_ground_at(fg_water(15, 15, /turf/floor/beach/water)) == G, "a tile 10 away in the same 16x16 stretch shares the ground")
	fg_check(fishing_ground_at(fg_water(16, 5, /turf/floor/beach/water)) != G, "the next stretch along is its own ground")
	fg_check(fishing_ground_at(pool) == G && G.capacity == 10 && G.stock == 10, "fishing its deep pool raises the ground to 10")
	var/datum/fishing_ground/S = fishing_ground_at(fg_water(7, 5, /turf/floor/beach/water/shallowsaltwater))
	fg_check(S != G && S.kind == "salt", "salt water in the same stretch is a separate ground")

	// ---- Taking fish ----
	fg_check(G.take(1) && G.stock == 9 && G.available() == 9, "a catch takes one fish")
	fg_check(!G.take(10) && G.stock == 9, "more than the ground holds cannot be taken")
	fg_check(findtext(fish_ground_reading(river), "alive with fish"), "at 9 of 10 the water is alive with fish")
	G.stock = 5
	fg_check(findtext(fish_ground_reading(river), "Fish move below"), "at half it reads as fish below the surface")
	G.stock = 2
	fg_check(findtext(fish_ground_reading(river), "fished hard"), "at 2 of 10 it reads as fished hard")
	G.stock = 0
	fg_check(findtext(fish_ground_reading(river), "fished out") && G.available() == 0 && !G.take(1), "an empty ground reads as fished out and gives nothing")

	// ---- Regrowth ----
	G.stock = 5
	G.since = world.time
	fg_wait(G, 4)
	G.settle()
	fg_check(abs(G.stock - 6) < 0.05, "at half stock about one fish comes back in four minutes ([G.stock])")
	G.stock = 9
	G.since = world.time
	fg_wait(G, 4)
	G.settle()
	fg_check(G.stock > 9.2 && G.stock < 9.5, "near full the same four minutes bring far less ([G.stock])")
	// Empty, with unfished neighbours: fish drift in at the spill rate.
	G.stock = 0
	G.since = world.time
	fg_wait(G, 16)
	G.settle()
	fg_check(G.stock >= 1 && G.stock < 1.2, "an empty ground beside full water gets its first fish back in sixteen minutes ([G.stock])")
	// Empty, with every neighbour fished out: nothing comes back.
	for (var/dx = -1, dx <= 1, dx++)
		for (var/dy = -1, dy <= 1, dy++)
			if (!dx && !dy)
				continue
			var/datum/fishing_ground/N = new /datum/fishing_ground("fresh", G.cx + dx, G.cy + dy, 1, 6)
			N.stock = 0
			fishing_grounds[fishing_ground_key("fresh", G.cx + dx, G.cy + dy, 1)] = N
	G.stock = 0
	G.since = world.time
	fg_wait(G, 60)
	G.settle()
	fg_check(G.stock == 0, "an empty ground among empty grounds stays empty ([G.stock])")
	var/datum/fishing_ground/east = fishing_grounds[fishing_ground_key("fresh", G.cx + 1, G.cy, 1)]
	east.stock = 3
	fg_wait(G, 16)
	G.settle()
	fg_check(G.stock >= 1, "and recovers once a neighbour has fish again ([G.stock])")
	G.stock = 0.5
	G.since = world.time
	fg_wait(G, 100 * 60)
	fg_check(G.available() == 10, "a ground left alone for days is full")
	fg_wait(G, 600)
	fg_check(G.take(1) && G.stock == 9 && G.since == world.time, "a full ground banks no regrowth")

	// ---- The catch ----
	var/list/seen = list()
	for (var/i in 1 to 400)
		seen["river [fish_catch_type(river, "fresh", FALSE)]"] = TRUE
		seen["shelf [fish_catch_type(shelf, "salt", FALSE)]"] = TRUE
		seen["ocean [fish_catch_type(ocean, "salt", FALSE)]"] = TRUE
		seen["baited ocean [fish_catch_type(ocean, "salt", TRUE)]"] = TRUE
		seen["swamp [fish_catch_type(swamp, "swamp", TRUE)]"] = TRUE
	fg_check(seen["river /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon"] && seen["river /obj/item/weapon/reagent_containers/food/snacks/rawfish"] && !seen["river /obj/item/weapon/reagent_containers/food/snacks/rawfish/cod"], "a river gives salmon and plain fish, never cod")
	fg_check(seen["shelf /obj/item/weapon/reagent_containers/food/snacks/rawfish/cod"] && seen["shelf /obj/item/weapon/reagent_containers/food/snacks/rawfish"] && !seen["shelf /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon"], "the coast gives cod and plain fish, never salmon")
	fg_check(seen["baited ocean /obj/item/weapon/reagent_containers/food/snacks/pink_squid"] && !seen["ocean /obj/item/weapon/reagent_containers/food/snacks/pink_squid"], "squid only take a baited line in the open sea")
	fg_check(seen["swamp /obj/item/weapon/reagent_containers/food/snacks/rawfish"] && !seen["swamp /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon"], "a swamp gives only plain fish")

	// ---- Tools ----
	var/list/pole = fishing_tool_profile(new /obj/item/weapon/fishing(land))
	var/list/net = fishing_tool_profile(new /obj/item/weapon/fishing/net(land))
	var/list/rod = fishing_tool_profile(new /obj/item/weapon/fishing/modern(land))
	var/list/harpoon = fishing_tool_profile(new /obj/item/weapon/material/harpoon/bone(land))
	var/obj/item/weapon/branch/stick = new(land)
	fg_check(pole[1] == 150 && pole[2] == 30 && !pole[3] && net[2] == 30 && rod[1] == 120 && rod[2] == 40, "a pole waits 15 s for 30%, a rod 12 s for 40%")
	fg_check(harpoon && harpoon[3] && harpoon[1] == spear_fishing_delay() && harpoon[2] == spear_fishing_chance(), "a bone harpoon fishes as a spear")
	fg_check(isnull(fishing_tool_profile(stick)), "a blunt branch is no fishing tool")
	stick.sharpened = TRUE
	var/list/sharp = fishing_tool_profile(stick)
	fg_check(sharp && sharp[3] && sharp[2] == 20, "a sharpened branch spears at 20%")
	fg_check(isnull(fishing_tool_profile(new /obj/item/weapon/reagent_containers/food/snacks/rawfish(land))), "a fish is no fishing tool")
	fg_check(!ispath(text2path("/obj/structure/fish")), "the old fishing spot object is gone")
