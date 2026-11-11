// Armor against projectiles, bounded AP/HP round profiles and the single impact
// result on a synthetic 6x4x1 world.
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
	armor_check(abs(ap_damage - base_damage * 0.7) < 0.01 && abs(ap_pen - min(base_pen * 1.5, base_pen + 40)) < 0.01, "AP profile is the bounded one ([ap_damage]/[ap_pen] from [base_damage]/[base_pen])")
	armor_check(ap_through == normal.penetrating + 1, "AP passes exactly one more layer of cover ([ap_through] vs [normal.penetrating])")
	ap.btype = "HP"
	ap.checktype()
	armor_check(abs(ap.damage - base_damage * 1.3) < 0.01 && abs(ap.armor_penetration - base_pen * 0.5) < 0.01 && ap.penetrating == 0, "switching to HP starts from the base values")
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

	// Matchup matrix: pistol, intermediate and full rifle rounds in each
	// profile against each protection tier, through the same residual rule
	// bullet_act uses.
	var/list/matrix = list()
	var/list/round_types = list(
		"9x19mm pistol" = /obj/item/projectile/bullet/pistol/a9x19,
		"7.62x39mm intermediate" = /obj/item/projectile/bullet/rifle/a762x39,
		"7.62x51mm full rifle" = /obj/item/projectile/bullet/rifle/a762x51,
		"12.7mm heavy" = /obj/item/projectile/bullet/rifle/a127)
	var/list/armor_values = list(0, 10, 30, 50, 70, 90, 130, 200)
	for (var/round_name in round_types)
		var/round_type = round_types[round_name]
		var/list/by_profile = list()
		var/list/stats = list()
		for (var/profile_id in list("normal", "AP", "HP"))
			var/obj/item/projectile/R = new round_type(locate(1,1,1))
			var/start_pen = R.armor_penetration
			var/start_through = R.penetrating
			R.btype = profile_id
			R.checktype()
			stats[profile_id] = list("damage" = R.damage, "armor_penetration" = R.armor_penetration, "cover_passage" = R.penetrating)
			armor_check(R.armor_penetration <= start_pen + 40, "[round_name] [profile_id] gains at most one tier of penetration ([R.armor_penetration] from [start_pen])")
			armor_check(R.penetrating <= start_through + 1, "[round_name] [profile_id] passes at most one more layer of cover")
			var/list/row = list()
			for (var/armor_value in armor_values)
				var/residual = projectile_armor_residual(R.damage, R.armor_penetration, armor_value)
				armor_check(residual >= 0 && residual <= R.damage, "[round_name] [profile_id] vs [armor_value] stays within its own damage")
				row["[armor_value]"] = round(residual, 0.1)
			by_profile[profile_id] = row
			qdel(R)
		var/list/normal_row = by_profile["normal"]
		var/list/ap_row = by_profile["AP"]
		var/list/hp_row = by_profile["HP"]
		armor_check(hp_row["0"] > normal_row["0"] && normal_row["0"] > ap_row["0"], "[round_name]: HP beats normal beats AP on unprotected targets")
		var/ap_wins = FALSE
		var/hp_loses = FALSE
		for (var/armor_value in armor_values)
			if (ap_row["[armor_value]"] > normal_row["[armor_value]"])
				ap_wins = TRUE
			if (armor_value > 0 && hp_row["[armor_value]"] < normal_row["[armor_value]"])
				hp_loses = TRUE
		armor_check(ap_wins, "[round_name]: AP beats normal against some armor")
		armor_check(hp_loses, "[round_name]: HP loses to normal against some armor")
		matrix[round_name] = list("profiles" = stats, "residual" = by_profile)
	text2file(json_encode(list("armor" = armor_values, "rounds" = matrix)), "ammo_matrix.json")

	// Secondary effects follow the impact: a round the armor stopped does no
	// wound, stun, embedding or instant kill.
	var/mob/living/human/stopped_target = new(locate(4,2,1))
	var/obj/item/clothing/head/helmet/armor_fixture/heavy = new(locate(4,2,1))
	heavy.armor = list(melee = 0, arrow = 0, gun = 300, energy = 0, bomb = 0, bio = 0, rad = 0)
	heavy.health = 10000
	stopped_target.equip_to_slot_or_del(heavy, slot_head)
	armor_check(stopped_target.head == heavy, "second fixture human wears the heavy helmet")
	for (var/i in 1 to 60)
		var/obj/item/projectile/bullet/rifle/a762x39/hit = new(locate(1,2,1))
		hit.KD_chance = 0
		hit.stun = 3
		hit.embed = TRUE
		stopped_target.bullet_act(hit, "eyes")
	var/shrapnel = 0
	for (var/obj/item/organ/external/E in stopped_target.organs)
		for (var/obj/item/weapon/material/shard/shrapnel/S in E)
			shrapnel++
	armor_check(stopped_target.getBruteLoss() == 0, "stopped rounds do no damage ([stopped_target.getBruteLoss()])")
	armor_check(!stopped_target.stunned, "stopped rounds do not stun ([stopped_target.stunned])")
	armor_check(!shrapnel, "stopped rounds do not embed shrapnel ([shrapnel])")
	armor_check(stopped_target.getBrainLoss() == 0, "stopped rounds to the eyes never reach the brain ([stopped_target.getBrainLoss()])")
	armor_check(heavy.health < 10000, "stopped rounds still wear the armor")

	// The same rider on an unprotected target does apply, and shrapnel lodges
	// in the organ that was hit.
	var/mob/living/human/open_target = new(locate(5,2,1))
	var/obj/item/projectile/bullet/rifle/a762x39/open_hit = new(locate(1,2,1))
	open_hit.KD_chance = 0
	open_hit.stun = 3
	open_hit.embed = FALSE
	open_target.bullet_act(open_hit, "l_leg")
	armor_check(open_target.stunned, "an unprotected hit applies the round's stun")
	armor_check(open_target.getBruteLoss() > 0, "an unprotected hit wounds")
	var/obj/item/organ/external/leg = open_target.get_organ("l_leg")
	var/obj/item/organ/external/chest = open_target.get_organ("chest")
	for (var/i in 1 to 20)
		var/obj/item/projectile/bullet/rifle/a762x39/leg_hit = new(locate(1,2,1))
		leg_hit.KD_chance = 0
		leg_hit.damage = 1
		leg_hit.embed = TRUE
		open_target.bullet_act(leg_hit, "l_leg")
	armor_check(locate(/obj/item/weapon/material/shard/shrapnel) in leg, "shrapnel lodges in the leg that was hit")
	armor_check(!(locate(/obj/item/weapon/material/shard/shrapnel) in chest), "shrapnel from leg hits does not appear in the chest")

	text2file("PASS: armor never adds damage or heals, round profiles are bounded and apply once, and stopped rounds have no secondary effects", "armor_result.txt")
	del(world)
