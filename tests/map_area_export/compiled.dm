// Runs in the world compiled from export.dmm: reports every tile.

/world/New()
	..()
	spawn(0)
		var/list/found = list()
		for(var/y in 1 to world.maxy)
			for(var/x in 1 to world.maxx)
				found["[x],[y]"] = map_export_test_describe(locate(x, y, 1))
		text2file(json_encode(found), "found.json")
		shutdown()
