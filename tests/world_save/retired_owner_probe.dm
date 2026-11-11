// Only construction/startup is adapted; qdel, human Destroy, ClearMap and
// prepare_player_ownership are production methods.
/world
	hub = ""
	hub_password = ""
	visibility = 0
	maxx = 3
	maxy = 3
	maxz = 1
	turf = /turf
	area = /area
/world/OpenPort(port)
	return ..("none")
/client/New()
	return null
/mob/living/human/owner_fixture/New()
	return
/proc/owner_check(condition, message)
	if(!condition) throw EXCEPTION(message)
/world/Error(exception/error)
	text2file("FAIL: runtime [error] at [error.file]:[error.line]", "result.txt")
/world/New()
	try
		var/map_storage/storage = new
		var/mob/living/human/old_body = new /mob/living/human/owner_fixture(locate(1,1,1))
		old_body.persistence_owner_ckey = "fixtureowner"
		storage.prepare_player_ownership()
		storage.ClearMap()
		owner_check(old_body && QDELETED(old_body) && !old_body.loc, "ClearMap did not retain a retired null-loc body")
		owner_check(old_body.persistence_owner_ckey == "fixtureowner", "retired body did not retain ownership")
		var/visible_retired = FALSE
		for(var/mob/living/human/H in world)
			if(H == old_body) visible_retired = TRUE
		owner_check(visible_retired, "retired human missing from world scan")
		text2file("OBSERVED: ClearMap qdel retains owned null-loc human in world", "result.txt")
		var/mob/living/human/current = new /mob/living/human/owner_fixture(locate(1,1,1))
		current.persistence_owner_ckey = "fixtureowner"
		storage.prepare_player_ownership()
		owner_check(current.persistence_owner_ckey == "fixtureowner", "current ownership changed")
		var/mob/living/human/duplicate = new /mob/living/human/owner_fixture(locate(2,1,1))
		duplicate.persistence_owner_ckey = "fixtureowner"
		var/rejected = FALSE
		try
			storage.prepare_player_ownership()
		catch(var/exception/duplicate_error)
			rejected = duplicate_error.name == "Invalid or duplicate durable player ownership"
		owner_check(rejected, "live duplicate ownership accepted")
		duplicate.persistence_owner_ckey = "Test Account"
		rejected = FALSE
		try
			storage.prepare_player_ownership()
		catch(var/exception/malformed_error)
			rejected = malformed_error.name == "Invalid or duplicate durable player ownership"
		owner_check(rejected, "live malformed ownership accepted")
		qdel(duplicate)
		storage.prepare_player_ownership()
		// Exercise the legacy-only marker separately from synchronized qdel.
		duplicate.gc_destroyed = 0
		owner_check(duplicate.gcDestroyed && !QDELETED(duplicate), "legacy-only retirement not staged")
		storage.prepare_player_ownership()
		// A null location alone does not mean retirement.
		var/mob/living/human/null_body = new /mob/living/human/owner_fixture
		null_body.persistence_owner_ckey = "fixtureowner"
		rejected = FALSE
		try
			storage.prepare_player_ownership()
		catch(var/exception/null_error)
			rejected = null_error.name == "Invalid or duplicate durable player ownership"
		owner_check(rejected, "unretired null-loc duplicate accepted")
		qdel(null_body)
		storage.prepare_player_ownership()
		text2file("PASS: retired owners ignored; live duplicate, malformed and null-loc owners rejected", "result.txt")
	catch(var/exception/error)
		text2file("FAIL: [error]", "result.txt")
	del(world)
