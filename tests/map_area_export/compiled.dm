// Runs in a world compiled from an exported map: reports every tile of every level.

/world/New()
	..()
	spawn(0)
		var/list/found = list()
		for(var/z in 1 to world.maxz)
			for(var/y in 1 to world.maxy)
				for(var/x in 1 to world.maxx)
					found["[x],[y],[z]"] = map_export_test_describe(locate(x, y, z))
		text2file(json_encode(found), "found.json")
		shutdown()
