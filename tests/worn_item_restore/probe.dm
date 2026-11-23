// A worn pack must stay drawn on the HUD across a save and load (2026-11-22:
// a hide sling bag showed an empty back slot after a restart). A bedroll put
// in a pack without a bedroll sprite switched it to a missing state, and a
// save taken while looking into the distance kept HUD items hidden.
/obj/map_metadata/worn_item_restore_fixture/New()
	return
/proc/worn_item_restore_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "worn_item_restore_result.txt")
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
	return "Worn item restore fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "worn_item_restore_result.txt")
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
	map = new /obj/map_metadata/worn_item_restore_fixture
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
	// A bedroll goes into a worn sling bag, which has no bedroll sprite.
	var/mob/living/human/H = new(locate(1,2,1))
	var/obj/item/weapon/storage/backpack/sling_bag/B = new(locate(1,2,1))
	H.equip_to_slot_or_del(B, slot_back)
	var/obj/item/weapon/bedroll/R = new(locate(1,2,1))
	H.put_in_hands(R)
	usr = H
	B.handle_item_insertion(R)
	usr = null
	worn_item_restore_check(R.loc == B, "the bedroll went into the sling bag")
	worn_item_restore_check(icon_has_state(B.icon, B.icon_state), "a sling bag holding a bedroll keeps a drawable state ([B.icon_state])")
	// A pack saved by the old code with the missing bedroll state.
	var/mob/living/human/H2 = new(locate(2,2,1))
	var/obj/item/weapon/storage/backpack/sling_bag/B2 = new(locate(2,2,1))
	H2.equip_to_slot_or_del(B2, slot_back)
	B2.icon_state = "sling_bag1"
	// A pack saved while its owner looked into the distance.
	var/mob/living/human/H3 = new(locate(3,2,1))
	var/obj/item/weapon/storage/backpack/sling_bag/B3 = new(locate(3,2,1))
	H3.equip_to_slot_or_del(B3, slot_back)
	B3.scoped_invisible = TRUE
	B3.invisibility = 100
	sleep(10)
	worn_item_restore_check(map_storage.Save_World(), "whole-world export succeeds: [map_storage.last_error]")
	map_storage.ClearMap()
	worn_item_restore_check(map_storage.Load_World(), "import succeeds: [map_storage.last_error]")
	sleep(20)
	H = locate(/mob/living/human) in locate(1,2,1)
	H2 = locate(/mob/living/human) in locate(2,2,1)
	H3 = locate(/mob/living/human) in locate(3,2,1)
	worn_item_restore_check(H && istype(H.back, /obj/item/weapon/storage/backpack/sling_bag), "the bedroll carrier is restored wearing the sling bag")
	worn_item_restore_check(icon_has_state(H.back.icon, H.back.icon_state), "the restored bedroll bag is drawable ([H.back.icon_state])")
	worn_item_restore_check(H2 && istype(H2.back, /obj/item/weapon/storage/backpack/sling_bag), "the old-save carrier is restored wearing the sling bag")
	worn_item_restore_check(H2.back.icon_state == "sling_bag", "an old save's missing bag state is repaired on load ([H2.back.icon_state])")
	worn_item_restore_check(H3 && istype(H3.back, /obj/item/weapon/storage/backpack/sling_bag), "the looking carrier is restored wearing the sling bag")
	worn_item_restore_check(!H3.back.invisibility && !H3.back.scoped_invisible, "a bag saved mid-look is visible after load (invisibility [H3.back.invisibility])")
	text2file("PASS: worn packs stay drawn across a save and load", "worn_item_restore_result.txt")
	del(world)
