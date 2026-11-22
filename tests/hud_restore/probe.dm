// A character saved before a HUD control existed must get it after a restore
// (Gaia 2026-11-22: restored characters never showed the stance button).
/obj/map_metadata/hud_restore_fixture/New()
	return
/proc/hud_restore_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "hud_restore_result.txt")
		del(world)
		sleep(1)
/world
	hub = ""
	hub_password = ""
	maxx = 4
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "HUD restore fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "hud_restore_result.txt")
	del(world)
	sleep(1)
/world/New()
	generate_gameid()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	map = new /obj/map_metadata/hud_restore_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	if(!all_species.len)
		makeDatumRefLists()
	var/mob/living/human/H = new(locate(2,2,1))
	hud_restore_check(H.species && H.species.hud, "fixture human has a species HUD")
	// As saved before the stance button existed.
	H.species.hud.ProcessHUD -= "combat stance"
	sleep(10)
	hud_restore_check(map_storage.Save_World(), "whole-world export succeeds: [map_storage.last_error]")
	map_storage.ClearMap()
	hud_restore_check(map_storage.Load_World(), "import succeeds: [map_storage.last_error]")
	sleep(10)
	H = locate(/mob/living/human) in locate(2,2,1)
	hud_restore_check(H, "human is restored")
	hud_restore_check(H.species && H.species.hud, "restored human has a species HUD")
	hud_restore_check(("combat stance" in H.species.hud.ProcessHUD), "restored HUD list has the current controls ([jointext(H.species.hud.ProcessHUD, ", ")])")
	text2file("PASS: a restored character gets the current HUD controls", "hud_restore_result.txt")
	del(world)
