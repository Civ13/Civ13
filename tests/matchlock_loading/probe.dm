// Matchlocks load lead musket balls and paper cartridges (player report,
// 2026-11-17); flintlocks explain loose balls instead of ignoring them.
/obj/map_metadata/matchlock_fixture/New()
	return
/proc/matchlock_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "matchlock_result.txt")
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
	return "Matchlock fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "matchlock_result.txt")
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
	map = new /obj/map_metadata/matchlock_fixture
	var/turf/T = locate(1,1,1)
	var/mob/user = new /mob(T)
	var/obj/item/stack/ammopart/musketball/ball = new(T)
	var/obj/item/stack/ammopart/stoneball/stone = new(T)
	var/obj/item/stack/ammopart/musketball_pistol/pistol_ball = new(T)
	for(var/gun_type in list(/obj/item/weapon/gun/projectile/ancient/matchlock, /obj/item/weapon/gun/projectile/ancient/arquebus, /obj/item/weapon/gun/projectile/ancient/tanegashima, /obj/item/weapon/gun/projectile/ancient/jezailmatchlock, /obj/item/weapon/gun/projectile/ancient/handcannon))
		var/obj/item/weapon/gun/projectile/ancient/G = new gun_type(T)
		matchlock_check(G.ancient_ball_casing(ball) == /obj/item/ammo_casing/musketball, "[gun_type] takes a lead musket ball")
		matchlock_check(G.ancient_ball_casing(stone) == /obj/item/ammo_casing/stoneball, "[gun_type] still takes stone shot")
		matchlock_check(!G.ancient_ball_casing(pistol_ball), "[gun_type] refuses pistol balls")
		G.gunpowder = TRUE
		G.ancient_chamber(new /obj/item/ammo_casing/musketball, user)
		matchlock_check(G.bullet && G.loaded.len == 1, "[gun_type] holds the loaded ball")
		var/obj/item/projectile/shot = G.consume_next_projectile()
		matchlock_check(istype(shot, /obj/item/projectile/bullet/rifle/musketball), "[gun_type] fires a musket ball ([shot ? shot.type : null])")
	var/obj/item/weapon/gun/projectile/flintlock/musket/F = new(T)
	matchlock_check(F.loose_projectile_hint(ball, user), "flintlock explains loose musket balls")
	matchlock_check(!F.loose_projectile_hint(pistol_ball, user), "flintlock gives no musket hint for pistol balls")
	matchlock_check(F.ammo_casing_fits(new /obj/item/ammo_casing/musketball(T), user), "flintlock takes a musket cartridge")
	matchlock_check(!F.ammo_casing_fits(new /obj/item/ammo_casing/musketball_pistol(T), user), "flintlock refuses a pistol cartridge")
	text2file("PASS: matchlocks load musket balls and flintlocks explain loose balls", "matchlock_result.txt")
	del(world)
