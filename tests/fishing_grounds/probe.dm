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
