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
		ice_breaking_checks()
		ice_dynamics_checks()
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
	// The level's one shoal starts out of the way, at the top of its circuit.
	for (var/clock = 0, clock < 864000, clock += 600)
		var/list/far = fish_shoal_position(1, 1, clock)
		if (far[2] >= 54)
			fish_shoal_clock = clock
			break
	fg_check(!isnull(fish_shoal_clock), "the shoal can be found at the top of its circuit")
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
	G.stock = 4
	G.since = world.time
	fg_check(fishing_ground_cell(pool, "fresh", 10, FALSE) == G && G.capacity == 6 && G.stock == 4, "a cell lookup does not raise existing capacity")
	fg_check(fishing_ground_at(pool, FALSE) == G && G.capacity == 10 && G.stock == 8, "a non-creating water lookup raises capacity and preserves depletion")
	G.stock = 10
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
	fg_check(pole[1] == 150 && pole[2] == 30 && !pole[3] && pole[4] == 1 && rod[1] == 120 && rod[2] == 40, "a pole waits 15 s for 30%, a rod 12 s for 40%")
	fg_check(harpoon && harpoon[3] && harpoon[1] == spear_fishing_delay() && harpoon[2] == spear_fishing_chance(), "a bone harpoon fishes as a spear")
	fg_check(isnull(fishing_tool_profile(stick)), "a blunt branch is no fishing tool")
	stick.sharpened = TRUE
	var/list/sharp = fishing_tool_profile(stick)
	fg_check(sharp && sharp[3] && sharp[2] == 20, "a sharpened branch spears at 20%")
	fg_check(isnull(fishing_tool_profile(new /obj/item/weapon/reagent_containers/food/snacks/rawfish(land))), "a fish is no fishing tool")
	fg_check(!ispath(text2path("/obj/structure/fish")), "the old fishing spot object is gone")

	// ---- Cast net and set gear ----
	fg_check(net[1] == 150 && net[2] == 25 && !net[3] && net[4] == 3, "a cast net has three chances of 25% a throw")
	fg_check(harpoon[4] == 1 && sharp[4] == 1 && rod[4] == 1, "lines and spears take one fish at a time")
	fishing_grounds = list()
	var/datum/fishing_ground/T1 = fishing_ground_at(shelf)
	var/trapped = fish_ground_trap_catch(shelf)
	fg_check(ispath(trapped, /obj/item/weapon/reagent_containers/food/snacks/rawfish) && T1.stock == 11, "set gear takes its fish out of the ground")
	T1.take(T1.available())
	fg_check(isnull(fish_ground_trap_catch(shelf)), "set gear in a fished-out stretch gets nothing")
	fg_check(isnull(fish_ground_trap_catch(land)) && isnull(fish_ground_trap_catch(ice)), "nor on land or ice")
	var/obj/structure/fishing_cage/cage = new(land)
	fg_check(isnull(cage.pick_catch(swamp)) && isnull(cage.pick_catch(ice)), "a cage in a swamp or on ice catches nothing")
	var/cage_fish = 0
	var/cage_other = 0
	for (var/i = 1 to 200)
		var/picked = cage.pick_catch(shelf)
		if (ispath(picked, /obj/item/weapon/reagent_containers/food/snacks/rawfish))
			cage_fish++
		else if (picked)
			cage_other++
	fg_check(!cage_fish && cage_other > 20, "a cage in fished-out water still brings up shellfish and crabs, never fish ([cage_fish], [cage_other])")
	T1.stock = 2
	for (var/i = 1 to 200)
		if (ispath(cage.pick_catch(shelf), /obj/item/weapon/reagent_containers/food/snacks/rawfish))
			cage_fish++
	fg_check(cage_fish == 2 && T1.available() == 0, "and takes no more fish than the stretch holds ([cage_fish])")

	// ---- Season, sky and river ----
	season = "SUMMER"
	fg_check(fish_condition_factor("fresh", FALSE, FALSE, WEATHER_NONE, 0) == 1 && fish_condition_factor("salt", TRUE, FALSE, WEATHER_NONE, 0) == 1, "ordinary conditions change nothing")
	fg_check(fish_condition_factor("fresh", FALSE, TRUE, WEATHER_NONE, 0) == 1.5 && fish_condition_factor("salt", FALSE, TRUE, WEATHER_NONE, 0) == 1 && fish_condition_factor("jungle", FALSE, TRUE, WEATHER_NONE, 0) == 1, "the salmon run lifts river fishing by half, and only there")
	fg_check(fish_condition_factor("salt", FALSE, FALSE, WEATHER_WET, 0) == 1.25 && fish_condition_factor("swamp", FALSE, FALSE, WEATHER_WET, 0) == 1.25, "rain brings fish up everywhere")
	fg_check(fish_condition_factor("salt", TRUE, FALSE, WEATHER_EXTREME, 0) == 0.5 && fish_condition_factor("fresh", FALSE, FALSE, WEATHER_EXTREME, 0) == 0.75, "a storm halves sea fishing and cuts river fishing by a quarter")
	fg_check(fish_condition_factor("fresh", TRUE, FALSE, WEATHER_NONE, 1) == 0.6 && fish_condition_factor("salt", TRUE, FALSE, WEATHER_NONE, 1) == 1, "a river in spate fishes badly; the sea does not care")
	fg_check(fish_condition_factor("fresh", TRUE, FALSE, WEATHER_NONE, -1) == 1.2 && fish_condition_factor("fresh", FALSE, FALSE, WEATHER_NONE, -1) == 1, "at low water the deep pools fish better, the shallows no better")
	fg_check(abs(fish_condition_factor("fresh", FALSE, TRUE, WEATHER_WET, 1) - 1.5 * 1.25 * 0.6) < 0.001, "conditions stack")
	fg_check(fish_condition_factor_at(river, "fresh") == 1 && isnull(fish_condition_reading(river, "fresh")), "a summer river under a clear sky reads as ordinary")
	season = "FALL"
	fg_check(fish_run_season() && fish_condition_factor_at(river, "fresh") == 1.5 && findtext(fish_condition_reading(river, "fresh"), "salmon are running") && isnull(fish_condition_reading(shelf, "salt")), "in autumn the river says the salmon are running")
	var/run_salmon = 0
	for (var/i = 1 to 400)
		if (fish_catch_type(river, "fresh", FALSE) == /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon)
			run_salmon++
	fg_check(run_salmon > 300, "during the run most river fish are salmon ([run_salmon] of 400)")
	fishing_grounds = list()
	var/datum/fishing_ground/RG = fishing_ground_at(pool)
	RG.stock = 5
	fg_wait(RG, 4)
	var/run_stock = RG.stock
	season = "SUMMER"
	RG.stock = 5
	fg_wait(RG, 4)
	fg_check(abs((run_stock - 5) - 2 * (RG.stock - 5)) < 0.15, "a river regrows twice as fast during the run ([run_stock] against [RG.stock])")

	// ---- Flood strandings ----
	fishing_grounds = list()
	var/turf/plain = fg_water(60, 50, /turf/floor/grass)
	var/area/outside = get_area(plain)
	outside.location = AREA_OUTSIDE
	fg_check(isnull(fish_flood_stranding(plain, FLOOD_BAND_KNEE, 100)) && isnull(fish_flood_stranding(river, FLOOD_BAND_ANKLE, 100)) && isnull(fish_flood_stranding(plain, FLOOD_BAND_ANKLE, 0)), "fish strand only in ankle-deep floodwater over land")
	var/obj/item/stranded = fish_flood_stranding(plain, FLOOD_BAND_ANKLE, 100)
	var/datum/fishing_ground/FG = fishing_ground_cell(plain, "flooded", 2, FALSE)
	fg_check(istype(stranded, /obj/item/weapon/reagent_containers/food/snacks/rawfish) && stranded.loc == plain && FG && FG.stock == 1, "a stranded fish lies on the flooded ground and comes out of the stretch's stock")
	fg_check(isnull(fish_flood_stranding(plain, FLOOD_BAND_ANKLE, 100)), "a tile with a fish on it strands no second one")
	var/turf/plain2 = fg_water(61, 50, /turf/floor/grass)
	var/turf/plain3 = fg_water(62, 50, /turf/floor/grass)
	fg_check(fish_flood_stranding(plain2, FLOOD_BAND_ANKLE, 100) && isnull(fish_flood_stranding(plain3, FLOOD_BAND_ANKLE, 100)) && FG.available() == 0, "a stretch of flood plain gives two fish and then no more for a while")

	// ---- From a ship ----
	fg_check(fish_ship_factor(FALSE, VESSEL_SPEED_STOP) == 1 && fish_ship_factor(FALSE, VESSEL_SPEED_HALF) == 1, "a quiet ship, stopped or at half ahead, changes nothing")
	fg_check(fish_ship_factor(TRUE, VESSEL_SPEED_STOP) == 0.6, "a running engine costs four bites in ten")
	fg_check(fish_ship_factor(FALSE, VESSEL_SPEED_SLOW) == 1.3 && fish_ship_factor(FALSE, VESSEL_SPEED_FULL) == 0.5, "a line towed at slow ahead fishes better, at full ahead it skips")
	fg_check(abs(fish_ship_factor(TRUE, VESSEL_SPEED_SLOW) - 0.78) < 0.001, "an engine and a slow tow stack")
	var/datum/craft/hull = new
	fg_check(fish_craft_step(hull) == VESSEL_SPEED_STOP && !fish_craft_engines(hull), "an anchored hull with no engine is still and quiet")
	hull.anchored = FALSE
	hull.speed = VESSEL_SPEED_SLOW
	fg_check(fish_craft_step(hull) == VESSEL_SPEED_SLOW, "a hull under way reports her telegraph step")
	qdel(hull)
	// Sonar: the fish over a submerged boat.
	fishing_grounds = list()
	fg_check(fish_finder_line(ocean) == "Fish overhead: thick shoals. A great shoal bears north, about 50 tiles off." && isnull(fish_finder_line(land)), "a sonar set reads unfished sea as thick shoals and land as nothing")
	var/datum/fishing_ground/OG = fishing_ground_at(ocean)
	OG.stock = 3
	fg_check(findtext(fish_finder_line(ocean), "scattered shoals"), "half-fished water reads as scattered shoals")
	OG.stock = 0
	fg_water(40 + 16, 5, /turf/floor/beach/water/deep/saltwater)
	fg_check(fish_finder_line(ocean) == "Fish overhead: no fish. A great shoal bears north, about 50 tiles off. Stronger returns to the east.", "fished-out water points at a fuller stretch next door ([fish_finder_line(ocean)])")

	// ---- Signs on the water ----
	fishing_grounds = list()
	season = "SUMMER"
	var/list/signs = list()
	for (var/i = 1 to 400)
		var/sign = fish_sign_state(shelf)
		if (sign)
			signs[sign] = TRUE
	fg_check(signs["rise_a"] && signs["rise_b"] && signs["rise_c"] && signs["jump_a"] && signs["jump_b"] && signs["gulls"], "full coastal water shows rings, leaping fish and gulls")
	var/river_gulls = FALSE
	var/river_signs = 0
	for (var/i = 1 to 400)
		var/sign = fish_sign_state(river)
		if (sign)
			river_signs++
		if (sign == "gulls")
			river_gulls = TRUE
	fg_check(river_signs == 400 && !river_gulls, "a full river always has a sign to show, and never gulls")
	var/datum/fishing_ground/SG = fishing_ground_at(river)
	SG.stock = SG.capacity / 4
	var/thin_signs = 0
	for (var/i = 1 to 400)
		if (fish_sign_state(river))
			thin_signs++
	fg_check(thin_signs > 50 && thin_signs < 160, "water at a quarter stock shows a quarter of the signs ([thin_signs] of 400)")
	SG.stock = 0
	var/dead_signs = 0
	for (var/i = 1 to 200)
		if (fish_sign_state(river) || fish_sign_state(land) || fish_sign_state(ice))
			dead_signs++
	fg_check(!dead_signs, "fished-out water, land and ice show nothing")
	for (var/state in list("rise_a", "rise_b", "rise_c", "jump_a", "jump_b", "gulls"))
		fg_check(state in icon_states('icons/effects/fish_signs.dmi'), "the sheet has [state]")

	// ---- Ice holes ----
	fishing_grounds = list()
	fg_check(ice_hole_tool_delay(new /obj/item/weapon/material/pickaxe(land)) == 80 && ice_hole_tool_delay(new /obj/item/weapon/material/hatchet(land)) == 80 && ice_hole_tool_delay(new /obj/item/weapon/chisel(land)) == 120 && !ice_hole_tool_delay(new /obj/item/weapon/fishing(land)), "an axe or pick cuts ice in 8 s, a chisel in 12, a pole not at all")
	var/obj/structure/ice_hole/hole = new(ice)
	fg_check(hole.icon_state in icon_states(hole.icon), "the ice hole has its sprite")
	var/datum/fishing_ground/IG = hole.ground()
	fg_check(hole.open() && IG && IG.kind == "fresh" && IG.capacity == 6 && IG.cx == round(ice.x / 16), "a hole in river ice fishes the fresh ground under it")
	var/turf/sea_ice = fg_water(41, 20, /turf/floor/beach/water/ice/salty)
	var/obj/structure/ice_hole/sea_hole = new(sea_ice)
	var/datum/fishing_ground/SIG = sea_hole.ground()
	fg_check(SIG && SIG.kind == "salt" && SIG.capacity == 12 && SIG != IG, "a hole in sea ice fishes the salt ground")
	var/turf/thawed = fg_water(41, 20, /turf/floor/beach/water/shallowsaltwater)
	fg_check(fishing_ground_at(thawed) == SIG, "and the thawed sea is the same ground")
	fg_check(!sea_hole.open() && sea_hole.refreeze_check(sea_hole.check_epoch) && QDELETED(sea_hole), "a hole goes when the ice under it does")
	fg_check(hole.open(trap_now_minutes() + 19) && !hole.open(trap_now_minutes() + 20), "a hole stays open for twenty minutes")
	fg_check(!hole.refreeze_check(hole.check_epoch - 1) && !QDELETED(hole), "a stale check does nothing")
	hole.cut_at = trap_minutes_text(trap_now_minutes() - 30)
	fg_check(hole.refreeze_check(hole.check_epoch) && QDELETED(hole), "an old hole freezes over")
	fg_check(abs(fish_tool_chance(list(150, 30, FALSE, 1), FALSE, IG) - 30) < 0.01 && abs(fish_tool_chance(list(150, 30, FALSE, 1), TRUE, IG) - 60) < 0.01, "a pole on a full ground has 30%, 60% baited")

	// ---- Species ----
	season = "SUMMER"
	var/list/sp = list()
	for (var/i = 1 to 600)
		sp["river [fish_catch_type(river, "fresh", FALSE)]"] = TRUE
		sp["pool [fish_catch_type(pool, "fresh", FALSE)]"] = TRUE
		sp["shelf [fish_catch_type(shelf, "salt", FALSE)]"] = TRUE
		sp["ocean [fish_catch_type(ocean, "salt", FALSE)]"] = TRUE
		sp["baited [fish_catch_type(ocean, "salt", TRUE)]"] = TRUE
		sp["towed [fish_catch_type(ocean, "salt", FALSE, TRUE)]"] = TRUE
		sp["swamp [fish_catch_type(swamp, "swamp", FALSE)]"] = TRUE
		sp["jungle [fish_catch_type(jungle, "jungle", FALSE)]"] = TRUE
	var/fishes = "/obj/item/weapon/reagent_containers/food/snacks/rawfish"
	fg_check(sp["river [fishes]/trout"] && !sp["river [fishes]/catfish"] && sp["pool [fishes]/catfish"] && sp["pool [fishes]/trout"], "trout live in rivers and lakes, catfish only in their deep water")
	fg_check(sp["shelf [fishes]/herring"] && !sp["ocean [fishes]/herring"] && !sp["shelf [fishes]/tuna"], "herring shoal on the coast, not in the open sea")
	fg_check(!sp["ocean [fishes]/tuna"] && sp["baited [fishes]/tuna"] && sp["towed [fishes]/tuna"], "tuna take only a baited or towed line in the open sea")
	fg_check(sp["swamp [fishes]/catfish"] && sp["jungle [fishes]/catfish"] && !sp["swamp [fishes]/trout"] && !sp["jungle [fishes]/trout"], "swamps and jungle rivers hold catfish, no trout")
	for (var/kind_name in list("trout", "catfish", "herring", "tuna"))
		var/kind_path = text2path("[fishes]/[kind_name]")
		var/obj/item/weapon/reagent_containers/food/snacks/rawfish/specimen = new kind_path(land)
		fg_check((specimen.icon_state in icon_states(specimen.icon)) && (specimen.rotten_icon_state in icon_states(specimen.icon)) && fish_pen_stock_ok(specimen), "a [kind_name] has its fresh and rotten sprite and can stock a pen")
	var/obj/item/weapon/reagent_containers/food/snacks/rawfish/tuna/big = new(shelf)
	var/obj/item/weapon/reagent_containers/food/snacks/rawfish/small = new(shelf)
	fg_check(big.reagents.get_reagent_amount("protein") == 10 && small.reagents.get_reagent_amount("protein") == 4, "a tuna carries far more meat than an ordinary fish")
	big.cut_fillets(new /obj/item/weapon/material/kitchen/utensil/knife(shelf), null, big.fillets)
	var/fillet_count = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/fishfillet/FF in shelf)
		fillet_count++
	fg_check(fillet_count == 6 && QDELETED(big), "a knife cuts a tuna into six fillets ([fillet_count])")

	// ---- Trawl ----
	var/obj/item/weapon/fishing/trawl/trawl_net = new(land)
	var/list/trawl = fishing_tool_profile(trawl_net)
	fg_check(trawl[1] == 200 && trawl[2] == 35 && !trawl[3] && trawl[4] == 6, "a trawl takes 20 s and has six chances of 35%")
	fg_check((trawl_net.icon_state in icon_states(trawl_net.icon)) && trawl_net.w_class == ITEM_SIZE_LARGE, "the trawl has its sprite and is a large thing to carry")

	// ---- Shoals ----
	fg_check(fish_shoal_count() == 1, "a small level has one shoal")
	var/list/start = fish_shoal_position(1, 1, 0)
	var/list/midnight = fish_shoal_position(1, 1, 864000)
	fg_check(abs(start[1] - midnight[1]) <= 1 && abs(start[2] - midnight[2]) <= 1, "a shoal is back where it started after a day")
	var/list/later = fish_shoal_position(1, 1, 6000)
	var/moved = max(abs(later[1] - start[1]), abs(later[2] - start[2]))
	fg_check(moved >= 5 && moved <= 40, "in ten minutes it has moved on, but not far ([moved])")
	var/list/second = fish_shoal_position(1, 2, 0)
	fg_check(second[1] != start[1] || second[2] != start[2], "two shoals keep different stations")
	fg_check(!fish_shoal_at(shelf) && !fish_shoal_at(ocean) && fish_shoal_factor(shelf) == 1, "water away from the shoal fishes as usual")
	var/list/now = fish_shoal_position(1, 1, fish_shoal_clock)
	var/turf/under = fg_water(now[1], now[2], /turf/floor/beach/water/deep/saltwater)
	var/turf/beside = fg_water(now[1] - 10, now[2], /turf/floor/beach/water/shallowsaltwater)
	var/turf/lake = fg_water(now[1] + 1, now[2], /turf/floor/beach/water)
	fg_check(fish_shoal_at(under) && fish_shoal_at(beside) && fish_shoal_factor(under) == 1.5, "salt water within 12 tiles of the shoal fishes half as well again")
	fg_check(!fish_shoal_at(lake) && !fish_shoal_at(land), "a shoal is nothing to fresh water or to land")
	fg_check(fish_condition_factor_at(under, "salt") == 1.5 && fish_condition_factor_at(shelf, "salt") == 1, "the shoal is multiplied into the conditions")
	fg_check(findtext(fish_ground_reading(under), "great shoal") && !findtext(fish_ground_reading(shelf), "great shoal"), "the water under a shoal reads as one")
	var/shoal_herring = 0
	var/shoal_signs = 0
	for (var/i = 1 to 400)
		if (fish_catch_type(beside, "salt", FALSE, FALSE, TRUE) == /obj/item/weapon/reagent_containers/food/snacks/rawfish/herring)
			shoal_herring++
		if (fish_sign_state(under))
			shoal_signs++
	fg_check(shoal_herring >= 250 && shoal_herring <= 350, "most of a shoal's catch on the coast is herring ([shoal_herring] of 400)")
	fg_check(shoal_signs == 400, "a shoal always shows on the water")
	// A fished-out ground still gives fish while the shoal is over it.
	var/datum/fishing_ground/shoal_ground = fishing_ground_at(under)
	shoal_ground.take(shoal_ground.available())
	var/shoal_landed = 0
	for (var/i = 1 to 40)
		shoal_landed += fish_land(null, under, shoal_ground, "salt", 100, 1, FALSE, FALSE)
	fg_check(shoal_ground.available() < 1 && shoal_landed >= 8 && shoal_landed <= 32, "an empty ground under a shoal gives about half the fish hooked ([shoal_landed] of 40)")
	fg_check(findtext(fish_finder_line(under), "passing overhead"), "sonar hears a shoal overhead")
	var/turf/west = fg_water(max(1, now[1] - 30), now[2], /turf/floor/beach/water/deep/saltwater)
	fg_check(findtext(fish_finder_line(west), "great shoal bears east"), "and gives the bearing of one further off ([fish_finder_line(west)])")
	fish_shoal_clock = (fish_shoal_clock + 432000) % 864000
	fg_check(!fish_shoal_at(under) && fish_shoal_factor(under) == 1, "half a day later the shoal has gone from that water")

	// ---- Saving ----
	fishing_grounds = list()
	fishing_grounds_publish()
	fg_check(islist(map.fishing_grounds_state) && !map.fishing_grounds_state.len, "with every ground full nothing is saved")
	var/datum/fishing_ground/A = fishing_ground_at(shelf)
	var/datum/fishing_ground/B = fishing_ground_at(ocean)
	A.take(3)
	fg_check(map.fishing_grounds_state.len == 6 && fishing_grounds.len == 1 && !(B in fishing_grounds), "a catch saves the fished ground and forgets the full one")
	var/list/saved = map.fishing_grounds_state
	fg_check(saved[1] == "salt" && saved[2] == A.cx && saved[3] == A.cy && saved[4] == 1 && saved[5] == 12 && saved[6] == 9, "a saved ground is kind, cell, level, capacity and stock")
	// A save loaded later: the map carries a different list.
	map.fishing_grounds_state = list("salt", A.cx, A.cy, 1, 12, 2.5, "fresh", 0, 0, 1, 10, 0, "lava", 1, 1, 1, 5, 1, "salt", 9, 9, 1, 0, 0)
	var/datum/fishing_ground/R = fishing_ground_at(shelf)
	fg_check(R != A && R.stock == 2.5 && R.capacity == 12 && fishing_grounds.len == 2, "a loaded save brings its own grounds and drops bad rows ([fishing_grounds.len])")
	var/datum/fishing_ground/R2 = fishing_ground_at(river)
	fg_check(R2.stock == 0 && R2.capacity == 10 && findtext(fish_ground_reading(river), "fished out"), "a fished-out river is still fished out after the load")
	fg_check(fishing_ground_at(shelf) == R, "and the grounds are read from the save only once")
	map.fishing_grounds_state = list("salt", 1, 1)
	fg_check(isnull(fishing_ground_at(shelf, FALSE)) && !fishing_grounds.len, "a malformed save leaves every ground full")

// ---- Breaking ice (code/modules/1713/ice_breaking.dm) ----

/area/caribbean/ice_break_probe

// A marker whose air is set by the probe.
/obj/structure/broken_ice/probe
	var/probe_temp = -10

/obj/structure/broken_ice/probe/air_temp()
	return probe_temp

/proc/ib_area(climate, x1, x2, y1, y2)
	var/area/caribbean/ice_break_probe/A = new
	A.climate = climate
	A.location = AREA_OUTSIDE
	for (var/turf/T in block(locate(x1, y1, 1), locate(x2, y2, 1)))
		A.contents += T
	return A

/proc/ib_steps(obj/structure/broken_ice/M, n)
	for (var/i = 1 to n)
		if (QDELETED(M))
			return
		M.freeze_check()

/proc/ice_breaking_checks()
	season = "WINTER"
	time_of_day = "Night"
	ib_area("tundra", 1, 12, 40, 52)
	ib_area("jungle", 13, 24, 40, 52)
	var/turf/land = locate(60, 60, 1)
	fg_check(ice_break_tool_delay(new /obj/item/weapon/material/pickaxe(land)) == 120 && ice_break_tool_delay(new /obj/item/weapon/material/hatchet(land)) == 150 && ice_break_tool_delay(new /obj/item/weapon/crowbar(land)) == 150 && ice_break_tool_delay(new /obj/item/weapon/chisel(land)) == 250 && !ice_break_tool_delay(new /obj/item/weapon/fishing(land)) && !ice_break_tool_delay(null), "a pick breaks a tile of ice in 12 s, an axe or crowbar in 15, a chisel in 25, a pole or bare hands not at all")

	// Cold and warm ice.
	var/turf/cold_ice = fg_water(3, 45, /turf/floor/beach/water/ice)
	var/turf/warm_ice = fg_water(15, 45, /turf/floor/beach/water/ice)
	fg_check(get_temp(cold_ice) <= -2 && get_temp(warm_ice) > 1, "the fixture has a freezing tundra and a warm jungle ([get_temp(cold_ice)], [get_temp(warm_ice)])")
	fg_check(!ice_is_thin(cold_ice) && ice_is_thin(warm_ice), "ice in hard cold is thick, ice in a thaw is rotten and thin")
	fg_check(!ice_is_thin(land), "dry land is not thin ice")

	// What a broken tile becomes.
	fg_check(ice_open_water_type(cold_ice) == /turf/floor/beach/water, "river ice with no deep water beside it opens to shallow water")
	fg_water(4, 45, /turf/floor/beach/water/deep)
	fg_check(ice_open_water_type(cold_ice) == /turf/floor/beach/water/deep, "beside deep water it opens deep")
	var/turf/sea_ice = fg_water(3, 48, /turf/floor/beach/water/ice/salty)
	fg_check(ice_open_water_type(sea_ice) == /turf/floor/beach/water/shallowsaltwater, "sea ice opens to shallow salt water")
	fg_water(3, 49, /turf/floor/beach/water/deep/saltwater)
	fg_check(ice_open_water_type(sea_ice) == /turf/floor/beach/water/deep/saltwater, "and to deep salt water beside the deep sea")
	fg_check(isnull(ice_break_refusal(cold_ice, null)) && ice_break_refusal(land, null), "clear ice can be broken, land cannot")

	// Breaking a tile with a fishing hole in it.
	var/turf/hole_ice = fg_water(6, 42, /turf/floor/beach/water/ice)
	var/obj/structure/ice_hole/hole = new(hole_ice)
	var/turf/opened = ice_break_turf(hole_ice)
	var/obj/structure/broken_ice/mark = opened ? (locate(/obj/structure/broken_ice) in opened) : null
	fg_check(istype(opened, /turf/floor/beach/water) && is_liquid_water(opened) && QDELETED(hole), "breaking the ice opens the water and the fishing hole goes with it")
	fg_check(mark && !mark.thin && !mark.salty && mark.shallow && !mark.cold_minutes, "and leaves one marker that counts towards freezing again")
	fg_check(isnull(ice_break_turf(opened)), "open water does not break twice")
	qdel(mark)

	// Freezing, thickening and thawing.
	var/turf/pool = fg_water(8, 42, /turf/floor/beach/water)
	var/obj/structure/broken_ice/probe/M = new(pool)
	M.opened(FALSE, TRUE)
	fg_check((M in broken_ice_marks) && broken_ice_pass_due, "a marker joins the one shared pass")
	ib_steps(M, 5)
	fg_check(is_liquid_water(locate(8, 42, 1)) && M.cold_minutes == 25, "25 freezing minutes leave it open")
	ib_steps(M, 1)
	var/turf/skinned = locate(8, 42, 1)
	fg_check(istype(skinned, /turf/floor/beach/water/ice) && !istype(skinned, /turf/floor/beach/water/ice/salty) && M.thin && skinned.name == "thin ice", "30 freezing minutes skin it over with thin ice")
	fg_check(ice_is_thin(skinned), "newly frozen ice is thin even in hard cold")
	M.probe_temp = 5
	ib_steps(M, 1)
	fg_check(istype(locate(8, 42, 1), /turf/floor/beach/water) && is_liquid_water(locate(8, 42, 1)) && !M.thin && !QDELETED(M), "thin ice melts back to open water in a thaw")
	M.cold_minutes = 20
	ib_steps(M, 1)
	fg_check(!M.cold_minutes, "warm air starts the count again")
	M.probe_temp = -10
	ib_steps(M, 6)
	fg_check(M.thin && istype(locate(8, 42, 1), /turf/floor/beach/water/ice), "it freezes over again in the cold")
	ib_steps(M, 11)
	fg_check(!QDELETED(M) && M.thin, "thin ice is still thin after 55 more freezing minutes")
	ib_steps(M, 1)
	var/turf/thick = locate(8, 42, 1)
	fg_check(QDELETED(M) && thick.name == "ice" && !ice_is_thin(thick) && !(M in broken_ice_marks), "after an hour it bears like any ice and the marker leaves the pass")

	// Sea ice refreezes as sea ice; a marker whose tile changed under it goes.
	var/turf/sea = fg_water(10, 42, /turf/floor/beach/water/shallowsaltwater)
	var/obj/structure/broken_ice/probe/SM = new(sea)
	SM.opened(TRUE, TRUE)
	ib_steps(SM, 6)
	fg_check(istype(locate(10, 42, 1), /turf/floor/beach/water/ice/salty), "broken sea ice freezes back as sea ice")
	fg_water(10, 42, /turf/floor/beach/water/shallowsaltwater)
	ib_steps(SM, 1)
	fg_check(!QDELETED(SM) && !SM.thin && SM.cold_minutes == 5, "thin ice that something else melted counts towards freezing again from the start")
	var/turf/frozen_by_season = fg_water(11, 44, /turf/floor/beach/water)
	var/obj/structure/broken_ice/probe/FM = new(frozen_by_season)
	FM.opened(FALSE, TRUE)
	fg_water(11, 44, /turf/floor/beach/water/ice)
	ib_steps(FM, 1)
	fg_check(QDELETED(FM), "open water that something else froze forgets its marker")

	// Freezing waits for whatever floats in the water.
	var/turf/berth = fg_water(9, 46, /turf/floor/beach/water)
	var/obj/structure/broken_ice/probe/BM = new(berth)
	BM.opened(FALSE, TRUE)
	var/obj/structure/vehicle/raft/moored = new(berth)
	ib_steps(BM, 8)
	fg_check(is_liquid_water(locate(9, 46, 1)) && BM.cold_minutes >= 30, "water does not freeze around a boat in it")
	qdel(moored)
	ib_steps(BM, 1)
	fg_check(istype(locate(9, 46, 1), /turf/floor/beach/water/ice) && BM.thin, "it freezes once the boat has gone")

	// Small boats.
	var/obj/structure/vehicle/raft/R = new(land)
	var/turf/thick_ice = fg_water(2, 50, /turf/floor/beach/water/ice)
	fg_check(!R.small_craft_ice_ok(thick_ice) && istype(locate(2, 50, 1), /turf/floor/beach/water/ice), "thick ice stops a small boat")
	fg_check(R.small_craft_ice_ok(locate(15, 47, 1)) && R.small_craft_ice_ok(warm_ice) && is_liquid_water(locate(15, 45, 1)), "a small boat crunches through rotten ice and opens it")
	fg_check(R.small_craft_ice_ok(land) && R.small_craft_ice_ok(locate(15, 45, 1)) && R.small_craft_ice_ok(null), "and anything that is not ice is no concern of the ice")
	// The shared pass looks at every marker once.
	var/turf/p1 = fg_water(20, 42, /turf/floor/beach/water)
	var/obj/structure/broken_ice/probe/P1 = new(p1)
	P1.opened(FALSE, TRUE)
	broken_ice_pass()
	fg_check(P1.cold_minutes == 5 && broken_ice_pass_due, "one pass counts five minutes on each marker and books the next pass")

// ---- Ice that forms and melts (code/modules/1713/ice_dynamics.dm) ----

/proc/ib_sweep_reset()
	ice_front_changed = null
	ice_area_temps = null

// Up to n sweeps of one tile; TRUE once its type is no longer start_type.
/proc/ib_front_changes(turf/T, n = 40)
	var/x = T.x
	var/y = T.y
	var/start_type = T.type
	for (var/i = 1 to n)
		ib_sweep_reset()
		ice_front_look(locate(x, y, 1))
		if (locate(x, y, 1):type != start_type)
			return TRUE
	return FALSE

/proc/ice_dynamics_checks()
	var/turf/land = locate(60, 60, 1)
	map.persistence = TRUE
	fg_check(ice_dynamics_on(), "the weather moves the ice on a persistent map")
	fg_check(ice_type_for(FALSE, TRUE) == /turf/floor/beach/water/ice && ice_type_for(FALSE, FALSE) == /turf/floor/beach/water/ice/deep && ice_type_for(TRUE, TRUE) == /turf/floor/beach/water/ice/salty && ice_type_for(TRUE, FALSE) == /turf/floor/beach/water/ice/salty/deep, "ice remembers fresh or salt and deep or shallow water")
	var/turf/deep_ice = fg_water(30, 5, /turf/floor/beach/water/ice/deep)
	var/turf/deep_sea_ice = fg_water(32, 5, /turf/floor/beach/water/ice/salty/deep)
	fg_check(ice_open_water_type(deep_ice) == /turf/floor/beach/water/deep && ice_open_water_type(deep_sea_ice) == /turf/floor/beach/water/deep/saltwater, "and opens deep where it froze over deep water")

	// A tundra pond: shore at its edge, open water in its middle.
	for (var/turf/T in block(locate(2, 40, 1), locate(6, 44, 1)))
		fg_water(T.x, T.y, /turf/floor/beach/water)
	var/turf/middle = locate(4, 42, 1)
	var/turf/edge = locate(2, 42, 1)
	fg_check(ice_area_temp(middle) <= -15, "the pond lies in hard frost ([ice_area_temp(middle)])")
	fg_check(!ib_front_changes(middle), "open water with no shore or ice beside it does not freeze")
	fg_check(ib_front_changes(edge), "water against the shore freezes in hard frost")
	var/turf/frozen_edge = locate(2, 42, 1)
	var/obj/structure/broken_ice/young = locate() in frozen_edge
	fg_check(istype(frozen_edge, /turf/floor/beach/water/ice) && young && young.thin && frozen_edge.name == "thin ice" && young.shallow && !young.salty, "and the new ice is thin and remembers its water")
	ib_sweep_reset()
	ice_front_note(frozen_edge)
	fg_check(!ice_front_freeze_edges(locate(3, 42, 1)) || locate(3, 41, 1):type != /turf/floor/beach/water, "ice made this sweep is no edge until the next")
	var/turf/next = locate(3, 43, 1)
	ice_keep_open(next)
	fg_check(ice_is_kept_open(next) && !ib_front_changes(next), "a channel a boat keeps using stays open")
	ice_kept_open = null
	var/turf/cart_water = locate(5, 43, 1)
	new /obj/structure/vehicle/raft(cart_water)
	fg_check(!ib_front_changes(cart_water, 10), "water with a boat in it does not freeze")

	// Harder cold for deep, flowing and salt water.
	var/turf/deep = fg_water(8, 40, /turf/floor/beach/water/deep)
	var/turf/sea = fg_water(10, 40, /turf/floor/beach/water/deep/saltwater)
	fg_check(ice_freeze_threshold(locate(5, 5, 1)) == -2 && ice_freeze_threshold(deep) == -8 && ice_freeze_threshold(sea) == -15 && ice_freeze_threshold(fg_water(12, 40, /turf/floor/beach/water/shallowsaltwater)) == -6, "still shallow water freezes at -2, the shallow sea at -6, deep water at -8 and the deep sea at -15")
	fg_check(isnull(ice_freeze_threshold(fg_water(12, 41, /turf/floor/beach/water/swamp))) && isnull(ice_freeze_threshold(fg_water(12, 42, /turf/floor/beach/water/flooded))), "swamps and seasonal floods are left alone")
	fg_check(ib_front_changes(sea) && istype(locate(10, 40, 1), /turf/floor/beach/water/ice/salty/deep), "in tundra cold even the deep sea freezes at its shore, as deep sea ice")

	// A thaw: jungle ice melts from its edges.
	var/turf/jungle_ice = fg_water(16, 50, /turf/floor/beach/water/ice/deep)
	fg_check(ib_front_changes(jungle_ice) && locate(16, 50, 1):type == /turf/floor/beach/water/deep, "warm ice melts from its edge, deep where it froze deep")
	for (var/turf/T in block(locate(14, 40, 1), locate(18, 44, 1)))
		fg_water(T.x, T.y, /turf/floor/beach/water/ice)
	fg_check(!ib_front_changes(locate(16, 42, 1), 15), "but not from the middle of a sheet")

	// Salt.
	var/turf/salted_water = fg_water(8, 46, /turf/floor/beach/water)
	var/obj/structure/broken_ice/probe/S = new(salted_water)
	S.opened(FALSE, TRUE)
	S.salted_until = trap_now_minutes() + 120
	S.probe_temp = -8
	ib_steps(S, 8)
	fg_check(is_liquid_water(locate(8, 46, 1)) && !S.cold_minutes, "salted water stays open in a hard frost")
	S.probe_temp = -20
	ib_steps(S, 6)
	fg_check(istype(locate(8, 46, 1), /turf/floor/beach/water/ice), "but freezes in bitter cold")
	var/turf/salted_ice = fg_water(8, 48, /turf/floor/beach/water/ice)
	var/obj/structure/broken_ice/probe/SI = new(salted_ice)
	SI.salted_until = trap_now_minutes() + 120
	SI.probe_temp = -5
	fg_check(ice_is_thin(salted_ice), "salted ice is thin")
	ib_steps(SI, 1)
	fg_check(is_liquid_water(locate(8, 48, 1)), "and breaks up into open water in a frost")
	SI.salted_until = 0
	SI.probe_temp = 5
	ib_steps(SI, 1)
	fg_check(QDELETED(SI), "once the salt is spent, open water in a thaw is the front's again")
	var/obj/item/weapon/reagent_containers/food/condiment/saltpile/pile = new(land)
	fg_check(ice_salt_ok(pile) && !ice_salt_ok(new /obj/item/weapon/reagent_containers/food/condiment/sugar(land)) && !ice_salt_ok(new /obj/item/weapon/material/pickaxe(land)), "a salt pile has salt to scatter, sugar or a pick does not")

	// Thin ice cracks under a load.
	var/turf/thin_spot = fg_water(20, 46, /turf/floor/beach/water/ice)
	var/obj/structure/broken_ice/probe/TM = new(thin_spot)
	TM.thin = TRUE
	var/obj/structure/vehicle/raft/cart = new(land)
	fg_check(ice_load_cracks(cart) && !ice_load_cracks(new /obj/item/weapon/material/pickaxe(land)), "a vehicle is a load for thin ice, a dropped pick is not")
	cart.forceMove(thin_spot)
	fg_check(is_liquid_water(locate(20, 46, 1)), "thin ice cracks and gives way under a cart")
	var/turf/thick_spot = fg_water(5, 30, /turf/floor/beach/water/ice)
	var/obj/structure/vehicle/raft/cart2 = new(land)
	cart2.forceMove(thick_spot)
	fg_check(istype(locate(5, 30, 1), /turf/floor/beach/water/ice), "thick ice in hard frost bears it")

	// The sweep walks the registered water a batch at a time.
	ice_front_cursor = 1
	var/sweeps = ice_front_sweeps
	var/looked = 0
	for (var/i = 1 to 20)
		looked += ice_front_step(100)
	fg_check(looked >= water_turf_list.len && ice_front_sweeps > sweeps, "steps walk every water tile and start a new sweep ([looked] looked at, [water_turf_list.len] registered)")
	map.persistence = FALSE
