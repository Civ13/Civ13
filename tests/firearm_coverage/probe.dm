// Compiler-resolved defaults for every gun type, written to firearm_types.json.
/obj/map_metadata/firearm_fixture/New()
	return
/world
	hub = ""
	hub_password = ""
	maxx = 2
	maxy = 2
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Firearm fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "firearm_result.txt")
	del(world)
	sleep(1)
/world/New()
	var/list/rows = list()
	for(var/path in typesof(/obj/item/weapon/gun))
		var/obj/item/weapon/gun/G = path
		var/list/row = list(
			"path" = "[path]",
			"name" = initial(G.name),
			"gun_type" = initial(G.gun_type),
			"firearm_family" = initial(G.firearm_family),
			"firearm_fixed_reason" = initial(G.firearm_fixed_reason),
		)
		if(ispath(path, /obj/item/weapon/gun/projectile))
			var/obj/item/weapon/gun/projectile/P = path
			row["caliber"] = initial(P.caliber)
			row["load_method"] = initial(P.load_method)
			row["max_shells"] = initial(P.max_shells)
			row["magazine_type"] = initial(P.magazine_type) ? "[initial(P.magazine_type)]" : null
			row["ammo_type"] = initial(P.ammo_type) ? "[initial(P.ammo_type)]" : null
			row["is_laser_mg"] = initial(P.is_laser_mg)
		rows += list(row)
	text2file(json_encode(rows), "firearm_types.json")
	text2file("PASS: [rows.len] gun types", "firearm_result.txt")
	del(world)
