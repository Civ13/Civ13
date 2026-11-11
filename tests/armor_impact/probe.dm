// Armor against projectiles and AP/HP round profiles on a synthetic 6x4x1 world.
/obj/map_metadata/armor_fixture/New()
	return
/obj/item/clothing/head/helmet/armor_fixture
	name = "fixture helmet"
	armor = list(melee = 0, arrow = 0, gun = 40, energy = 0, bomb = 0, bio = 0, rad = 0)
/proc/armor_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "armor_result.txt")
		del(world)
		sleep(1)
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Armor fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "armor_result.txt")
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
	map = new /obj/map_metadata/armor_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)

	// Residual damage: armor never adds damage and is monotonic.
	armor_check(projectile_armor_residual(60, 80, 0) == 60, "no armor takes the full hit")
	armor_check(projectile_armor_residual(60, 80, -10) == 60, "negative armor takes the full hit")
	armor_check(projectile_armor_residual(60, 80, 80) == 0, "armor equal to penetration stops the round")
	armor_check(projectile_armor_residual(60, 80, 95) == 0, "armor above penetration stops the round")
	armor_check(projectile_armor_residual(60, 0, 10) == 0, "a round without penetration is stopped by any armor")
	armor_check(projectile_armor_residual(0, 80, 10) == 0, "a harmless round stays harmless")
	var/last = 61
	for(var/armor_value in 0 to 80)
		var/residual = projectile_armor_residual(60, 80, armor_value)
		armor_check(residual >= 0 && residual <= 60, "armor [armor_value] keeps damage within 0..60 ([residual])")
		armor_check(residual <= last, "more armor never means more damage (armor [armor_value]: [residual] after [last])")
		last = residual
	armor_check(abs(projectile_armor_residual(60, 80, 10) - 52.5) < 0.01, "light armor absorbs its share (got [projectile_armor_residual(60, 80, 10)])")

	// AP/HP profiles apply once, from stable base values.
	var/obj/item/projectile/bullet/rifle/a762x39/normal = new(locate(1,1,1))
	var/base_damage = normal.damage
	var/base_pen = normal.armor_penetration
	var/obj/item/projectile/bullet/rifle/a762x39/ap = new(locate(1,1,1))
	ap.btype = "AP"
	ap.checktype()
	var/ap_damage = ap.damage
	var/ap_pen = ap.armor_penetration
	var/ap_through = ap.penetrating
	ap.checktype()
	ap.checktype()
	armor_check(ap.damage == ap_damage && ap.armor_penetration == ap_pen && ap.penetrating == ap_through, "repeated AP checktype does not compound ([ap.damage]/[ap.armor_penetration] vs [ap_damage]/[ap_pen])")
	armor_check(abs(ap_damage - base_damage * 0.7) < 0.01 && abs(ap_pen - base_pen * 3) < 0.01, "AP profile matches the authored multipliers")
	ap.btype = "HP"
	ap.checktype()
	armor_check(abs(ap.damage - base_damage * 1.3) < 0.01 && abs(ap.armor_penetration - base_pen / 3) < 0.01 && ap.penetrating == 0, "switching to HP starts from the base values")
	ap.btype = "normal"
	ap.checktype()
	armor_check(ap.damage == base_damage && ap.armor_penetration == base_pen && ap.penetrating == normal.penetrating, "switching back to normal restores the base values")

	var/obj/item/ammo_casing/a762x39/casing = new(locate(2,1,1))
	var/plain_name = casing.name
	casing.btype = "HP"
	casing.checktype()
	casing.checktype()
	armor_check(casing.name == "[plain_name] (HP)", "casing name gets one suffix ([casing.name])")
	var/hp_damage = casing.BB.damage
	casing.checktype()
	armor_check(casing.BB.damage == hp_damage, "casing checktype does not compound HP damage")

	// A human with a helmet: damage through armor and nonnegative wear.
	var/mob/living/human/H = new(locate(3,2,1))
	var/obj/item/clothing/head/helmet/armor_fixture/helmet = new(locate(3,2,1))
	H.equip_to_slot_or_del(helmet, slot_head)
	armor_check(H.head == helmet, "fixture human wears the helmet")
	armor_check(H.getarmor("head", "gun") == 40, "helmet gives 40 gun armor on the head ([H.getarmor("head", "gun")])")
	var/helmet_health = helmet.health
	var/obj/item/projectile/bullet/rifle/a762x39/shot = new(locate(1,2,1))
	shot.damage = 60
	shot.armor_penetration = 80
	shot.KD_chance = 0
	shot.embed = FALSE
	var/before = H.getBruteLoss()
	H.bullet_act(shot, "head")
	var/taken = H.getBruteLoss() - before
	armor_check(taken <= 60, "a helmet weaker than the round never raises damage (took [taken] from 60)")
	armor_check(taken > 0, "a helmet weaker than the round lets some damage through")
	armor_check(helmet.health <= helmet_health, "the helmet does not heal from being hit ([helmet.health] vs [helmet_health])")
	armor_check(helmet.health < helmet_health, "the helmet wears from the absorbed share")
	var/worn = helmet.health
	H.damage_armor("head", -5)
	armor_check(helmet.health == worn, "negative wear is ignored")

	text2file("PASS: armor never adds damage or heals, and round profiles apply once", "armor_result.txt")
	del(world)
