// AK modular parts on a synthetic 6x4x1 world, then a whole-world save/load.
/obj/map_metadata/firearm_parts_fixture/New()
	return
/obj/item/weapon/gun/wait_for_configuration(mob/living/human/H, delay)
	return TRUE
/proc/parts_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "parts_result.txt")
		del(world)
		sleep(1)
/proc/parts_count()
	var/n = 0
	for(var/obj/item/weapon/gun_component/P in world)
		if(!QDELETED(P)) n++
	return n
/proc/parts_unload(obj/item/weapon/gun/projectile/G)
	if(G.ammo_magazine)
		qdel(G.ammo_magazine)
		G.ammo_magazine = null
	if(G.chambered)
		qdel(G.chambered)
		G.chambered = null
	G.loaded.Cut()
/proc/parts_hold(mob/living/human/H, obj/item/I)
	H.drop_from_inventory(H.get_active_hand())
	H.put_in_active_hand(I)
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Firearm parts fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "parts_result.txt")
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
	makeDatumRefLists()
	map = new /obj/map_metadata/firearm_parts_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)

	var/mob/living/human/H = new(locate(2,2,1))
	var/obj/item/weapon/gun/projectile/submachinegun/ak74/G = new(locate(2,2,1))
	parts_unload(G)
	H.put_in_inactive_hand(G)
	parts_check(H.get_inactive_hand() == G, "human holds the rifle")
	parts_check(isnull(G.firearm_part_ids), "parts stay unbuilt until first use")
	parts_check(!G.firearm_fire_block(), "a preset AK-74 can fire ([G.firearm_fire_block()])")
	parts_check(G.firearm_part_ids.len == 4 && G.firearm_part_ids["barrel"] == "ak/barrel/545x39", "preset builds four parts")
	G.firearm_parts_ready()
	parts_check(G.firearm_part_ids.len == 4, "preset applies once")
	var/base_ergo = initial(G.ergonomics)
	parts_check(G.ergonomics == base_ergo, "fixed stock keeps base ergonomics ([G.ergonomics] vs [base_ergo])")

	// Field strip the magazine well by hand.
	var/obj/item/weapon/gun_component/feed545 = G.firearm_remove("feed", H)
	parts_check(istype(feed545) && feed545.component_id == "ak/feed/545x39" && parts_count() == 1, "magazine well comes off by hand")
	parts_check(G.firearm_fire_block() == "it has no feed", "no magazine well blocks firing ([G.firearm_fire_block()])")
	// The barrel needs a bench.
	parts_check(!G.firearm_remove("barrel", H) && parts_count() == 1 && G.firearm_part_ids["barrel"], "barrel needs a bench and nothing is created without one")
	var/obj/structure/repair/gun/bench = new(locate(3,2,1))
	bench.anchored = TRUE
	var/obj/item/weapon/gun_component/barrel545 = G.firearm_remove("barrel", H)
	parts_check(istype(barrel545) && barrel545.component_id == "ak/barrel/545x39" && parts_count() == 2, "barrel comes off at a bench")

	// Convert to 7.62x39: a 7.62 barrel with the old 5.45 well cannot fire.
	var/obj/item/weapon/gun_component/barrel762 = new /obj/item/weapon/gun_component/ak_barrel_762(locate(2,2,1))
	parts_hold(H, barrel762)
	parts_check(G.firearm_install(barrel762, H) && G.firearm_part_ids["barrel"] == "ak/barrel/762x39", "7.62 barrel installs")
	parts_check(QDELETED(barrel762) && !G.firearm_install(barrel762, H), "an installed part cannot be installed twice")
	parts_hold(H, feed545)
	parts_check(G.firearm_install(feed545, H), "5.45 well installs")
	parts_check(G.firearm_fire_block() == "its barrel and magazine well are for different cartridges", "mismatched conversion blocks firing")
	parts_check(G.firearm_remove("feed", H), "5.45 well removed again")
	var/obj/item/weapon/gun_component/feed762 = new /obj/item/weapon/gun_component/ak_feed_762(locate(2,2,1))
	parts_hold(H, feed762)
	parts_check(G.firearm_install(feed762, H), "7.62 well installs")
	parts_check(!G.firearm_fire_block() && G.caliber == "a762x39" && (/obj/item/ammo_magazine/ak47 in G.good_mags) && !(/obj/item/ammo_magazine/ak74 in G.good_mags), "converted rifle takes 7.62x39 and AKM magazines ([G.caliber])")
	var/obj/item/ammo_magazine/ak47/akm_mag = new(locate(2,2,1))
	parts_hold(H, akm_mag)
	G.load_ammo(akm_mag, H)
	parts_check(G.ammo_magazine == akm_mag, "converted rifle loads an AKM magazine")
	var/obj/item/weapon/gun_component/fixed = new /obj/item/weapon/gun_component/ak_furniture_fixed(locate(2,2,1))
	parts_hold(H, fixed)
	parts_check(!G.firearm_install(fixed, H) && !QDELETED(fixed), "a loaded rifle refuses work and keeps the part")
	parts_unload(G)
	qdel(fixed)

	// Wrong gun and filled slot.
	var/obj/item/weapon/gun/projectile/pistol/luger/pistol = new(locate(4,2,1))
	var/obj/item/weapon/gun_component/action = new /obj/item/weapon/gun_component/ak_action(locate(2,2,1))
	parts_check(pistol.firearm_install_block(action) == "this gun takes no modular parts", "non-modular guns refuse parts")
	parts_check(G.firearm_install_block(action) == "the action slot is already filled", "a filled slot refuses a second part")
	qdel(action)

	// Stock off: worse handling, but reapplying never compounds.
	var/obj/item/weapon/gun_component/stock = G.firearm_remove("furniture", H)
	parts_check(stock && abs(G.ergonomics - base_ergo * 0.75) < 0.001, "no stock lowers handling ([G.ergonomics])")
	G.firearm_apply_parts()
	G.firearm_apply_parts()
	parts_check(abs(G.ergonomics - base_ergo * 0.75) < 0.001, "reapplying parts does not compound")
	parts_hold(H, stock)
	parts_check(G.firearm_install(stock, H) && abs(G.ergonomics - base_ergo) < 0.001, "stock restores handling")

	// Barrel wear blocks firing and travels with the part.
	for(var/i in 1 to 1000)
		G.firearm_wear()
	parts_check(G.firearm_fire_block() == "its barrel is worn out", "a worn-out barrel blocks firing ([G.firearm_part_condition["barrel"]])")
	var/obj/item/weapon/gun_component/worn = G.firearm_remove("barrel", H)
	parts_check(worn && worn.condition == 0, "worn barrel keeps its condition when removed")
	parts_hold(H, worn)
	parts_check(G.firearm_install(worn, H) && G.firearm_part_condition["barrel"] == 0, "reinstalling a worn barrel does not repair it")
	G.firearm_part_condition["barrel"] = 0.5

	// Save/load: converted rifle, untouched legacy-shaped rifle, loose parts.
	H.drop_from_inventory(G)
	G.forceMove(locate(1,1,1))
	H.drop_from_inventory(H.get_active_hand())
	qdel(H)
	qdel(bench)
	qdel(pistol)
	var/obj/item/weapon/gun/projectile/submachinegun/ak47/untouched = new(locate(2,1,1))
	var/obj/item/weapon/gun_component/loose = barrel545
	loose.forceMove(locate(3,1,1))
	loose.condition = 0.4
	for(var/obj/item/weapon/gun_component/P in world)
		if(P != loose)
			qdel(P)
	sleep(10)
	parts_check(isnull(untouched.firearm_part_ids), "untouched rifle saves without parts")
	parts_check(map_storage.Save_World(), "production whole-world export succeeds")
	map_storage.ClearMap()
	parts_check(map_storage.Load_World(), "production whole-world import succeeds: [map_storage.last_error]")
	sleep(10)
	G = locate(/obj/item/weapon/gun/projectile/submachinegun/ak74) in locate(1,1,1)
	untouched = locate(/obj/item/weapon/gun/projectile/submachinegun/ak47) in locate(2,1,1)
	loose = locate(/obj/item/weapon/gun_component) in locate(3,1,1)
	parts_check(G && untouched && loose, "rifles and the loose part are restored")
	parts_check(G.firearm_part_ids["barrel"] == "ak/barrel/762x39" && G.firearm_part_ids["feed"] == "ak/feed/762x39" && G.firearm_part_ids.len == 4, "converted rifle keeps its parts")
	parts_check(G.firearm_part_condition["barrel"] == 0.5 && G.caliber == "a762x39" && !G.firearm_fire_block(), "converted rifle keeps wear and caliber")
	parts_check(abs(G.ergonomics - base_ergo) < 0.001, "loading does not compound handling ([G.ergonomics])")
	parts_check(isnull(untouched.firearm_part_ids) && !untouched.firearm_fire_block() && untouched.firearm_part_ids.len == 4 && untouched.caliber == "a762x39", "untouched rifle gets its preset once after load")
	parts_check(loose.component_id == "ak/barrel/545x39" && loose.condition == 0.4 && loose.name == "AK barrel (5.45x39mm)", "loose part keeps identity and condition")
	parts_check(parts_count() == 1, "no part is duplicated by save/load")

	text2file("PASS: AK parts strip, convert, wear and survive save/load without duplication", "parts_result.txt")
	del(world)
