// Ammunition across a whole-world save/load on a synthetic 6x4x1 world.
// Projectiles are never saved, so loaded rounds must be rebuilt on import.
/obj/map_metadata/ammo_fixture/New()
	return
/obj/item/ammo_magazine/ammo_fixture
	name = "fixture magazine"
	caliber = "a762x39"
	ammo_type = /obj/item/ammo_casing/a762x39
	max_ammo = 3
// Writes the pre-fix save shape: a BB field (encoded as a null entry) only
// while loaded, and no saved bullet type.
/obj/item/ammo_casing/a762x39/legacy_fixture
/obj/item/ammo_casing/a762x39/legacy_fixture/before_save()
	saved_bullet_type = null
/obj/item/ammo_casing/a762x39/legacy_fixture/persistence_runtime_var(key)
	if (key == "BB")
		return FALSE
	return ..()
/proc/ammo_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "ammo_result.txt")
		del(world)
		sleep(1)
/proc/ammo_live(obj/item/ammo_casing/C, bullet_type)
	return C && C.BB && C.BB.type == bullet_type && C.BB.loc == C && !C.BB.gcDestroyed
/proc/ammo_bullets(obj/item/ammo_casing/C)
	var/count = 0
	for(var/obj/item/projectile/P in C)
		count++
	return count
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Ammo fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "ammo_result.txt")
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
	map = new /obj/map_metadata/ammo_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/obj/item/ammo_magazine/ammo_fixture/mag = new(locate(1,1,1))
	var/obj/item/ammo_casing/a762x39/live = new(locate(2,1,1))
	var/obj/item/ammo_casing/a762x39/spent = new(locate(3,1,1))
	qdel(spent.expend())
	var/obj/item/ammo_casing/a762x39/ap = new(locate(4,1,1))
	ap.btype = "AP"
	ap.checktype()
	var/ap_damage = ap.BB.damage
	var/obj/item/ammo_casing/arrow/fire_arrow = new(locate(5,1,1))
	qdel(fire_arrow.BB)
	fire_arrow.BB = new /obj/item/projectile/arrow/arrow/fire(fire_arrow)
	var/obj/item/ammo_casing/a762x39/legacy_fixture/legacy_live = new(locate(1,2,1))
	var/obj/item/ammo_casing/a762x39/legacy_fixture/legacy_spent = new(locate(2,2,1))
	qdel(legacy_spent.expend())
	sleep(10)
	ammo_check(mag.stored_ammo.len == 3, "fixture magazine is filled ([mag.stored_ammo.len])")
	ammo_check(map_storage.Save_World(), "production whole-world export succeeds")
	ammo_check(map_storage.validate_world_save(), "production preflight accepts the save: [map_storage.last_error]")
	map_storage.ClearMap()
	ammo_check(map_storage.Load_World(), "production whole-world import succeeds: [map_storage.last_error]")
	sleep(10)
	mag = locate(/obj/item/ammo_magazine/ammo_fixture) in locate(1,1,1)
	live = locate(/obj/item/ammo_casing/a762x39) in locate(2,1,1)
	spent = locate(/obj/item/ammo_casing/a762x39) in locate(3,1,1)
	ap = locate(/obj/item/ammo_casing/a762x39) in locate(4,1,1)
	fire_arrow = locate(/obj/item/ammo_casing/arrow) in locate(5,1,1)
	legacy_live = locate(/obj/item/ammo_casing/a762x39/legacy_fixture) in locate(1,2,1)
	legacy_spent = locate(/obj/item/ammo_casing/a762x39/legacy_fixture) in locate(2,2,1)
	ammo_check(mag && live && spent && ap && fire_arrow && legacy_live && legacy_spent, "ammunition is restored")
	ammo_check(mag.stored_ammo.len == 3, "magazine keeps three rounds ([mag.stored_ammo.len])")
	for(var/obj/item/ammo_casing/C in mag.stored_ammo)
		ammo_check(ammo_live(C, /obj/item/projectile/bullet/rifle/a762x39) && ammo_bullets(C) == 1, "magazine round is still loaded")
	ammo_check(ammo_live(live, /obj/item/projectile/bullet/rifle/a762x39) && ammo_bullets(live) == 1, "loose loaded round is still loaded")
	ammo_check(!spent.BB && !ammo_bullets(spent), "spent casing stays spent")
	ammo_check(ammo_live(ap, /obj/item/projectile/bullet/rifle/a762x39) && ap.BB.btype == "AP" && ap.BB.damage == ap_damage, "AP round keeps its bullet ([ap.BB ? ap.BB.damage : null] vs [ap_damage])")
	ammo_check(ammo_live(fire_arrow, /obj/item/projectile/arrow/arrow/fire), "fire arrow keeps its fire head")
	ammo_check(ammo_live(legacy_live, /obj/item/projectile/bullet/rifle/a762x39) && ammo_bullets(legacy_live) == 1, "older-save loaded round is rebuilt")
	ammo_check(!legacy_spent.BB && !ammo_bullets(legacy_spent), "older-save spent casing stays spent")
	text2file("PASS: loaded rounds stay loaded and spent casings stay spent across save/load", "ammo_result.txt")
	del(world)
