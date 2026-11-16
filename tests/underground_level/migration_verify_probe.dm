// Check of a migrated save for tests/underground_level/migration.py. Inert
// unless the world runs with -params migration_probe=verify, so the same build
// also runs the migration (migrate_underground=1) and the outside validator
// (validate_save=1) unchanged. Test-only; never part of civ13.dme.
var/global/datum/underground_migration_verify/underground_migration_verify = new

/datum/underground_migration_verify
	var/list/result = list()
	var/list/checks = list()
	var/list/failures = list()

/datum/underground_migration_verify/New()
	if(islist(world.params) && world.params["migration_probe"] == "verify")
		spawn(10)
			drive()

/datum/underground_migration_verify/proc/check(condition, message)
	checks += message
	if(!condition)
		failures += message
		world.log << "MIGRATION FAIL: [message]"
	return !!condition

/datum/underground_migration_verify/proc/near(path, name, x, y)
	for(var/atom/movable/AM in range(16, locate(x, y, 2)))
		if(!istype(AM, path)) continue
		var/mob/living/human/H = AM
		if(AM.name == name || (istype(H) && H.real_name == name))
			return AM
	return null

/datum/underground_migration_verify/proc/drive()
	var/failure
	try
		var/seen_pending = FALSE
		while(TRUE)
			if(persistence_startup_recovery_status == "pending")
				seen_pending = TRUE
			else if(seen_pending || persistence_startup_recovery_status == "unresolved")
				break
			sleep(10)
		check(isnull(persistence_startup_recovery_status), "the migrated save restored ([persistence_startup_recovery_status])")
		result["map"] = map.ID
		var/z = map.underground_compiled_z
		check(z == 1 && underground_level_z() == 1, "the map's underground is its compiled level 1")
		check(map && map.loc && map.loc.z == 1, "the map metadata is still on level 1")
		var/formed = 0
		var/movables = 0
		var/outside = 0
		var/area/caves = dug_underground_area()
		var/admin = 0
		for(var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
			if(istype(T.loc, /area/caribbean/admin))
				admin++
				continue
			if(T.type != /turf/sky/building/unformed)
				formed++
			if(T.loc != caves)
				outside++
			for(var/atom/movable/AM in T)
				if(!istype(AM, /atom/movable/lighting_overlay) && !istype(AM, /atom/movable/lighting_fullbright) && !isobserver(AM) && !istype(AM, /obj/map_metadata))
					movables++
			TICK_CHECK
		result["admin_cells"] = admin
		result["formed"] = formed
		result["movables"] = movables
		result["outside_caves"] = outside
		check(!formed, "every cell of the old level is unformed rock ([formed] formed)")
		check(!movables, "nothing is left on the old level ([movables])")
		check(!outside, "every cell is in the cave area ([outside])")
		var/list/cells = list()
		for(var/text in splittext(world.params["cells"], "_"))
			var/list/xy = splittext(text, ",")
			cells += list(list(text2num(xy[1]), text2num(xy[2])))
		var/list/c = cells[1]
		// A new human picks its random name after New, so the seed's name does not stick;
		// a round with no players has no other human to find.
		var/body = locate(/mob/living/human) in range(16, locate(c[1], c[2], 2))
		check(body, "the body came up to the surface")
		c = cells[2]
		check(near(/obj/item/weapon/material/shovel, "migration seed shovel", c[1], c[2]), "the loose item came up")
		c = cells[3]
		var/obj/structure/closet/crate/crate = near(/obj/structure/closet/crate, "migration seed crate", c[1], c[2])
		var/inside = FALSE
		if(crate)
			for(var/obj/item/I in crate)
				if(I.name == "migration seed crate shovel") inside = TRUE
		check(crate && inside, "the crate came up with its contents")
		c = cells[4]
		check(!(locate(/obj/structure/multiz) in locate(c[1], c[2], 2)), "the ladder down above the old level is gone")
	catch(var/exception/e)
		failure = "[e] at [e.file]:[e.line]"
	result["passed"] = !failure && !failures.len
	result["failure"] = failure
	result["checks"] = checks
	result["failed_checks"] = failures
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	sleep(5)
	del(world)
