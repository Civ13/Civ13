world
	maxx = 8
	maxy = 6
	maxz = 2
	turf = /turf/test
	visibility = 0
/turf/test
	map_storage_saved_vars = "name;dir"
/turf/test/edge
/obj/item/test
	var/number = 0
	var/list/items = list("constructor default")
	var/datum/test/reference
/datum/test
	var/value = 0
/proc/check(condition, message)
	if(!condition)
		throw EXCEPTION(message)
/world/New()
	..()
	try
		map = new /obj/map_metadata(locate(1,1,1))
		var/turf/edge = new /turf/test/edge(locate(world.maxx,world.maxy,2))
		edge.name = "far corner"
		var/obj/item/test/A = new(locate(1,1,1))
		var/obj/item/test/B = new(A)
		A.number = 17
		B.number = 99
		A.items = list()
		A.reference = new /datum/test
		A.reference.value = 123
		check(map_storage.Save_World(), "export failed")
		check(map_storage.validate_world_save(), "valid export rejected")
		map_storage.ClearMap()
		check(map_storage.Load_World(), "import failed")
		check(istype(locate(world.maxx,world.maxy,2), /turf/test/edge), "edge turf lost")
		check(locate(world.maxx,world.maxy,2):name == "far corner", "turf name lost")
		A = locate(/obj/item/test) in locate(1,1,1)
		check(A && A.number == 17, "object lost")
		B = locate(/obj/item/test) in A
		check(B && B.number == 99, "nested contents lost")
		check(A.reference && A.reference.value == 123, "datum reference lost")
		check(islist(A.items) && !A.items.len, "empty list reverted to default")
		check(map && map.loc == locate(1,1,1), "metadata deleted")
		check(!errors.len, "unexpected errors")
		var/savefile/F = new("map_saves/2.sav")
		F.cd = "/map/2/[world.maxy]"
		F["[world.maxx]"] << null
		check(!map_storage.validate_world_save(), "missing turf accepted")
		check(A && A.number == 17, "preflight modified world")
		world.log << "PASS: world-save round trip, edges, multilevel, nested objects, datums, empty lists, corrupt-save rejection"
		text2file("PASS", "result.txt")
	catch(var/exception/e)
		world.log << "FAIL: [e] at [e.file]:[e.line]"
		text2file("FAIL: [e]", "result.txt")
	del(world)
