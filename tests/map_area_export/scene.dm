// Builds a small scene, exports part of it with the real exporter, and writes
// what the exported area should look like once the map is compiled.

/world
	turf = /turf/floor/wood
	area = /area/hall
	maxx = 7
	maxy = 6
	maxz = 2

/world/New()
	..()
	spawn(0)
		map_export_test_scene()

/proc/map_export_test_scene()
	// Garden in the middle row, a wall, objects with mapper-set fields.
	var/area/garden/G = locate(/area/garden) || new /area/garden
	for(var/x in 2 to 5)
		var/turf/T = locate(x, 3, 1)
		T = new /turf/floor/grass(T)
		G.contents += T
	var/turf/grass = locate(3, 3, 1)
	grass.icon_state = "grass3"
	new /turf/wall/stone(locate(5, 4, 1))
	var/obj/structure/chair/C = new(locate(2, 2, 1))
	C.dir = EAST
	C.pixel_x = 4
	C.pixel_y = -3
	var/obj/structure/table/table = new(locate(3, 2, 1))
	table.icon_state = "odd\"\[name]\\x"
	var/obj/item/stack/material/wood/W = new(locate(4, 2, 1))
	W.amount = 17
	var/obj/item/box/B = new(locate(4, 4, 1))
	new /obj/item/apple(B)
	new /obj/item/apple(B)
	var/obj/structure/sign/S = new(locate(2, 4, 1))
	S.name = "player text"
	S.desc = "more player text"
	var/mob/dummy/M = new(locate(3, 4, 1))
	new /obj/item/apple(M)
	new /atom/movable/lighting_overlay(locate(2, 2, 1))
	// Outside the exported rectangle: must not appear in the area export.
	new /obj/structure/chair(locate(6, 5, 1))
	// The second level only shows up in the whole-world export.
	new /turf/wall/stone(locate(1, 1, 2))
	var/obj/structure/table/far_table = new(locate(7, 6, 2))
	far_table.dir = WEST
	new /mob/dummy(locate(4, 3, 2))

	var/list/report = list()
	var/dmm = map_export_dmm(locate(5, 4, 1), locate(2, 2, 1), report)
	text2file(dmm, "export.dmm")
	text2file(json_encode(report), "report.json")
	// Corners on different levels are refused.
	text2file(isnull(map_export_dmm(locate(1, 1, 1), null, list())) ? "refused" : "accepted", "refusal.txt")
	var/list/world_report = list()
	map_export_world("world.dmm", world_report)
	text2file(json_encode(world_report), "world_report.json")

	// Expected tiles after compiling: mobs and contents gone, names reset.
	var/list/expected = list()
	for(var/y in 2 to 4)
		for(var/x in 2 to 5)
			var/turf/T = locate(x, y, 1)
			map_export_test_clean(T)
			expected["[x - 1],[y - 1],1"] = map_export_test_describe(T)
	text2file(json_encode(expected), "expected.json")
	var/list/expected_world = list()
	for(var/z in 1 to world.maxz)
		for(var/y in 1 to world.maxy)
			for(var/x in 1 to world.maxx)
				var/turf/T = locate(x, y, z)
				map_export_test_clean(T)
				expected_world["[x],[y],[z]"] = map_export_test_describe(T)
	text2file(json_encode(expected_world), "expected_world.json")
	shutdown()

// Removes what the exporter leaves out, so the tile matches its compiled copy.
/proc/map_export_test_clean(turf/T)
	for(var/mob/mob in T)
		mob.loc = null
	for(var/obj/O in T)
		for(var/atom/movable/inner in O)
			inner.loc = null
		O.name = initial(O.name)
		O.desc = initial(O.desc)
	for(var/atom/movable/lighting_overlay/L in T)
		L.loc = null
