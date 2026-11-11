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

	// Factory route: every part and the bare receiver are fabricator outputs,
	// and a receiver built from them fires.
	factory_load_recipes()
	parts_check(!factory_recipe_errors.len, "factory recipes load cleanly ([jointext(factory_recipe_errors, "; ")])")
	var/list/made = list()
	for(var/recipe_name in factory_recipes)
		var/datum/factory_recipe/R = factory_recipes[recipe_name]
		if(ispath(R.output_type, /obj/item/weapon/gun_component) || ispath(R.output_type, /obj/item/weapon/gun/projectile/submachinegun/ak74/receiver) || ispath(R.output_type, /obj/item/weapon/gun/projectile/submachinegun/m16/receiver))
			parts_check(R.node == "automatic_weapons", "[recipe_name] is gated by Automatic Weapons")
			made += R.output_type
	for(var/path in typesof(/obj/item/weapon/gun_component) - /obj/item/weapon/gun_component)
		parts_check(path in made, "a fabricator makes [path]")
	parts_check(/obj/item/weapon/gun/projectile/submachinegun/ak74/receiver in made, "a fabricator makes the AK receiver")
	parts_check(/obj/item/weapon/gun/projectile/submachinegun/m16/receiver in made, "a fabricator makes the AR receiver")
	var/obj/item/weapon/gun/projectile/submachinegun/ak74/receiver/R = new(locate(2,2,1))
	H.drop_from_inventory(G)
	G.forceMove(locate(1,1,1))
	H.put_in_inactive_hand(R)
	parts_check(!R.ammo_magazine && R.firearm_fire_block() == "it has no action" && R.name == "AK receiver", "a bare receiver cannot fire ([R.firearm_fire_block()])")
	for(var/part_type in list(/obj/item/weapon/gun_component/ak_action, /obj/item/weapon/gun_component/ak_barrel_762, /obj/item/weapon/gun_component/ak_feed_762, /obj/item/weapon/gun_component/ak_furniture_fixed))
		var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
		parts_hold(H, part)
		parts_check(R.firearm_install(part, H), "receiver takes [part_type]")
	parts_check(!R.firearm_fire_block() && R.caliber == "a762x39" && R.name == "AK rifle (7.62x39mm)", "a receiver built from factory parts fires as a 7.62 rifle ([R.name])")
	H.drop_from_inventory(R)
	qdel(R)

	// Phase 5: the AR family and the AK-100 series.
	var/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4/M4 = new(locate(2,2,1))
	parts_unload(M4)
	H.put_in_inactive_hand(M4)
	var/m4_ergo = initial(M4.ergonomics)
	parts_check(!M4.firearm_fire_block() && M4.firearm_part_ids["furniture"] == "ar/furniture/collapsible" && M4.caliber == "a556x45", "an M4 builds an AR carbine preset")
	parts_check((/obj/item/ammo_magazine/m16 in M4.good_mags) && (/obj/item/ammo_magazine/ar15 in M4.good_mags), "an AR magazine well takes M16 and AR-15 magazines")
	parts_check(abs(M4.ergonomics - m4_ergo * 0.95) < 0.001, "a collapsible stock handles like a folding one ([M4.ergonomics])")
	var/obj/item/weapon/gun_component/ar_feed = M4.firearm_remove("feed", H)
	parts_check(istype(ar_feed) && ar_feed.component_id == "ar/feed/556x45", "an AR magazine well comes off by hand")
	var/obj/item/weapon/gun_component/ak_feed556 = new /obj/item/weapon/gun_component/ak_feed_556(locate(2,2,1))
	parts_check(M4.firearm_install_block(ak_feed556) == "that part is for a different rifle family", "AK parts do not fit an AR")
	parts_hold(H, ar_feed)
	parts_check(M4.firearm_install(ar_feed, H) && !M4.firearm_fire_block(), "the AR magazine well goes back in")
	var/obj/item/weapon/gun/projectile/submachinegun/fallout_check = new /obj/item/weapon/gun/projectile/submachinegun/m16/fallout/service_rifle(locate(2,2,1))
	parts_check(!fallout_check.firearm_family && !fallout_check.firearm_parts_ready(), "the Service Rifle stays a fixed design")
	qdel(fallout_check)
	var/obj/item/weapon/gun/projectile/submachinegun/ak101/ak102/AK102 = new(locate(2,2,1))
	parts_check(!AK102.firearm_fire_block() && AK102.caliber == "a556x45" && (/obj/item/ammo_magazine/ak101 in AK102.good_mags), "an AK-102 builds a 5.56 AK preset")
	var/obj/item/weapon/gun/projectile/submachinegun/ak101/ak105/AK105 = new(locate(2,2,1))
	parts_check(AK105.caliber == "a545x39" && !AK105.firearm_fire_block() && (/obj/item/ammo_magazine/ak74 in AK105.good_mags), "an AK-105 builds a 5.45 AK preset")
	qdel(AK102)
	qdel(AK105)
	H.drop_from_inventory(M4)
	qdel(M4)
	var/obj/item/weapon/gun/projectile/submachinegun/m16/receiver/ARR = new(locate(2,2,1))
	H.put_in_inactive_hand(ARR)
	parts_check(!ARR.ammo_magazine && ARR.firearm_fire_block() == "it has no action" && ARR.name == "AR receiver", "a bare AR receiver cannot fire")
	for(var/part_type in list(/obj/item/weapon/gun_component/ar_action, /obj/item/weapon/gun_component/ar_barrel_556, /obj/item/weapon/gun_component/ar_feed_556, /obj/item/weapon/gun_component/ar_furniture_fixed))
		var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
		parts_hold(H, part)
		parts_check(ARR.firearm_install(part, H), "AR receiver takes [part_type]")
	parts_check(!ARR.firearm_fire_block() && ARR.caliber == "a556x45" && ARR.name == "AR rifle (5.56x45mm)", "an AR receiver built from factory parts fires ([ARR.name])")
	H.drop_from_inventory(ARR)
	qdel(ARR)
	qdel(ak_feed556)
	// An AK receiver can also be built for 5.56x45mm.
	var/obj/item/weapon/gun/projectile/submachinegun/ak74/receiver/AKR = new(locate(2,2,1))
	H.put_in_inactive_hand(AKR)
	for(var/part_type in list(/obj/item/weapon/gun_component/ak_action, /obj/item/weapon/gun_component/ak_barrel_556, /obj/item/weapon/gun_component/ak_feed_556))
		var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
		parts_hold(H, part)
		parts_check(AKR.firearm_install(part, H), "AK receiver takes [part_type]")
	parts_check(!AKR.firearm_fire_block() && AKR.name == "AK rifle (5.56x45mm)", "an AK receiver builds as a 5.56 rifle ([AKR.name])")
	H.drop_from_inventory(AKR)
	qdel(AKR)

	// Save/load: converted rifle, untouched legacy-shaped rifle, loose parts.
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

	text2file("PASS: AK and AR parts strip, convert, wear and survive save/load without duplication", "parts_result.txt")
	del(world)
