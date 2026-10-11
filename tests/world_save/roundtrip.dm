world
	name = "Civ13 LOCAL world-save roundtrip"
	sleep_offline = FALSE
	maxx = 8
	maxy = 6
	maxz = 2
	turf = /turf/test
	visibility = 0
/turf/test
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood"
	map_storage_saved_vars = "name;dir"
/turf/test/edge
	icon_state = "plating"
/obj/item/test
	var/number = 0
	var/list/items = list("constructor default")
	var/datum/test/reference
	var/list/complex
	var/list/alias
	var/turf/destination
	var/area/current_area
	var/obj/map_metadata/metadata
	var/obj/item/test/other_z
/datum/test
	var/value = 0
	var/datum/test/next
	var/obj/item/test/backlink
/proc/check(condition, message)
	if(!condition)
		throw EXCEPTION(message)
/world/New()
	..()
	try
		if(world.params["large"])
			world.maxx = 500
			world.maxy = 500
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
		A.reference.next = A.reference
		A.reference.backlink = A
		A.complex = list("literal **entry7", 7, 7, "key" = list("nested" = 42))
		A.alias = A.complex
		A.complex += list(A.complex)
		A.complex += list(null)
		A.destination = edge
		A.current_area = edge.loc
		A.metadata = map
		var/obj/item/test/C = new(edge)
		C.number = 314
		C.items = list("second level" = 271)
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
		check(A.reference.next == A.reference && A.reference.backlink == A, "datum/object cycle lost")
		check(islist(A.items) && !A.items.len, "empty list reverted to default")
		check(A.complex[1] == "literal **entry7", "literal marker string changed")
		check(A.complex[2] == 7 && A.complex[3] == 7, "duplicates lost")
		check(A.complex["key"]["nested"] == 42, "associative nested list lost")
		check(A.alias == A.complex && A.complex[A.complex.len-1] == A.complex, "list alias/cycle lost")
		check(isnull(A.complex[A.complex.len]), "null list element lost")
		check(A.destination == locate(world.maxx,world.maxy,2), "cross-level turf reference lost")
		check(A.current_area == A.destination.loc && A.metadata == map, "area or metadata identity lost")
		C = locate(/obj/item/test) in locate(world.maxx,world.maxy,2)
		check(C && C.number == 314 && C.items["second level"] == 271, "second-level objects/lists lost")
		check(map && map.loc == locate(1,1,1), "metadata deleted")
		check(!errors.len, "unexpected errors")
		// Large-map acceptance exercises the complete graph/grid round trip.
		// Fault injection and backup recovery use the focused fixture below.
		if(world.params["large"])
			world.log << "PASS: 500x500x2 world-save round trip and object/list/turf invariants"
			text2file("PASS", "result.txt")
			del(world)
			return
		check(map_storage.Save_World(), "second export failed")
		check(fexists("map_backups/save_complete.txt"), "backup completion marker missing")
		check(map_storage.validate_world_save(), "second export rejected")
		if(!world.params["large"])
			A.other_z = C
			var/datum/controller/gameticker/failed_export_ticker = new
			check(!failed_export_ticker.savemap(), "cross-level object silently duplicated")
			check(!fexists("map_saves/save_complete.txt") && !persistence_save_in_progress, "failed export retained completion marker or lock")
			check(fexists("map_backups/save_complete.txt"), "failed export lost completed backup")
			A.other_z = null
			check(map_storage.Save_World(), "recovery export failed")
		var/savefile/F1 = new("map_saves/1.sav")
		F1["/maxx"] << world.maxx + 1
		check(!map_storage.validate_world_save(), "dimension mismatch accepted")
		F1["/maxx"] << world.maxx
		var/object_path = map_storage.entry_path(F1, 2)
		var/original_reference = F1["[object_path]/reference"]
		F1["[object_path]/reference"] << list("kind" = "entry", "ref" = 999999999)
		check(!map_storage.validate_world_save(), "missing object reference accepted")
		F1["[object_path]/reference"] << original_reference
		fdel("map_saves/save_complete.txt")
		check(!map_storage.validate_world_save(), "interrupted save accepted")
		text2file("test completed", "map_saves/save_complete.txt")
		var/savefile/F = new("map_saves/2.sav")
		F.cd = "/map/2/[world.maxy]"
		F["[world.maxx]"] << null
		check(!map_storage.validate_world_save(), "missing turf accepted")
		check(A && A.number == 17, "preflight modified world")
		var/datum/controller/gameticker/ticker = new
		check(!ticker.loadmap(), "ticker accepted corrupt save")
		check(A && A.number == 17 && !persistence_save_in_progress, "failed import cleared world or retained lock")
		if(!world.params["large"])
			F = null
			F1 = null
			write_legacy_fixture()
			check(ticker.loadmap(), "legacy fixture import failed")
			A = locate(/obj/item/test) in locate(1,1,1)
			check(A && A.number == 88 && A.loc == locate(1,1,1), "legacy object location/value lost")
			check(A.items && !A.items.len, "legacy empty list lost")
		world.log << "PASS: world-save round trip, edges, multilevel, nested objects, datums, empty lists, corrupt-save rejection"
		text2file("PASS", "result.txt")
	catch(var/exception/e)
		world.log << "FAIL: [e] at [e.file]:[e.line]"
		text2file("FAIL: [e]", "result.txt")
	if(!world.params["visual"])
		del(world)

/proc/write_legacy_fixture()
	for(var/z = 1, z <= world.maxz, z++)
		fdel("map_saves/[z].sav")
		var/savefile/F = new("map_saves/[z].sav")
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++)
				var/ref = (y-1)*world.maxx+x
				F["/map/[z]/[y]/[x]"] << ref
				F["/entries/[ref]/type"] << /turf/test
				F["/entries/[ref]/content"] << ""
		if(z == 1)
			var/ref = world.maxx*world.maxy+1
			F["/entries/1/content"] << "[ref]"
			F["/entries/[ref]/type"] << /obj/item/test
			F["/entries/[ref]/number"] << 88
			F["/entries/[ref]/items"] << "**emptylist"
			F["/entries/[ref]/pixloc"] << null

/client/New()
	..()
	mob.loc = locate(4,3,1)
	var/status = file2text("result.txt")
	src << browse("<html><body><h2>Civ13 actual offline save/import regression world</h2><p>Result: [status]</p><p>8x6x2 fixture, using repository persistence procedures and isolated game adapters.</p><p>Checks: nested objects, datum references, empty lists, associative lists, duplicates, aliases, cycles, cross-level turf reference, edge coordinates, metadata survival, corrupt-save rejection.</p><p>This is fixture runtime evidence, not full playable-world acceptance.</p></body></html>", "window=world_save_result;size=620x350")
