// This mode uses the existing Life scheduler, with capped perception/path work.
// Neutral scavengers retaliate only against an actual attacker; contractors hunt.
/mob/living/simple_animal/hostile/human/extraction
	name = "district scavenger"
	desc = "A scavenger who keeps to himself until attacked."
	icon_state = "pirate_friendly1"
	icon_dead = "pirate_friendly_dead"
	corpse = null
	faction = CIVILIAN
	behaviour = "defends"
	health = 100
	maxHealth = 100
	melee_damage_lower = 10
	melee_damage_upper = 15
	starves = FALSE
	speak_chance = 0
	var/contractor = FALSE
	var/tmp/mob/living/aggressor
	var/tmp/next_decision = 0
	var/tmp/next_step = 0
	var/tmp/next_shot = 0
	var/tmp/shots = 18
	var/tmp/death_registered = FALSE
	var/tmp/list/route = list()
	New()
		..()
		should_save = FALSE
		gun = new /obj/item/weapon/gun/projectile/pistol/m9beretta(src)
		var/datum/extraction_equipment_codec/provenance = new
		provenance.set_raid_provenance(gun, TRUE)
		gun.should_save = FALSE
		projectiletype = /obj/item/projectile/bullet/pistol/a9x19
	do_human_behaviour()
		return
	Shoot(atom/target)
		if (!gun || stat != CONSCIOUS || !target) return
		var/obj/item/projectile/P = gun.consume_next_projectile()
		if (!P)
			shots = 0
			return
		gun.process_projectile(P, src, target, "chest")
		gun.handle_post_fire(src)
	proc/provoke(mob/living/attacker)
		if (attacker && attacker != src && attacker.z == 1 && attacker.stat != DEAD)
			aggressor = attacker
			target_mob = attacker
			next_decision = 0
	bullet_act(obj/item/projectile/P)
		if (P && !P.nodamage) provoke(P.firer)
		return ..()
	attack_hand(mob/living/human/H)
		if (H && (H.a_intent == I_HARM || H.a_intent == I_DISARM)) provoke(H)
		return ..()
	attackby(obj/item/I, mob/user)
		if (I && I.force > 0 && isliving(user)) provoke(user)
		return ..()
	handle_ai()
		if (stat != CONSCIOUS || z != 1) return
		var/obj/map_metadata/extraction_survival/M = map
		if (!istype(M)) return
		if (world.time >= next_decision)
			next_decision = world.time + 2 SECONDS
			var/mob/living/chosen
			if (aggressor && aggressor.stat != DEAD && aggressor.z == z && (aggressor in view(12, src))) chosen = aggressor
			else aggressor = null
			if (!chosen && contractor)
				var/best_distance = 13
				for (var/owner in M.accounts.sessions)
					var/datum/extraction_session/S = M.accounts.sessions[owner]
					var/mob/living/human/H = S.body
					if (S.profile["state"] != "raid" || !H || H.stat == DEAD || H.z != 1) continue
					var/distance = get_dist(src, H)
					if (distance < best_distance && (H in view(12, src)))
						chosen = H
						best_distance = distance
				for (var/mob/living/simple_animal/hostile/human/extraction/N in M.npcs)
					if (N == src || N.contractor || N.stat == DEAD || N.z != 1) continue
					var/distance = get_dist(src, N)
					if (distance < best_distance && (N in view(12, src)))
						chosen = N
						best_distance = distance
			if (chosen != target_mob) route = list()
			target_mob = chosen
			if (chosen && get_dist(src, chosen) > 6) route = cirrAstar(get_turf(src), get_turf(chosen), 5, 64)
		if (!target_mob || target_mob.stat == DEAD || target_mob.z != 1) return
		if (get_dist(src, target_mob) <= 1)
			if (world.time >= next_shot)
				next_shot = world.time + 2 SECONDS
				AttackingTarget()
		else if (shots > 0 && world.time >= next_shot && (target_mob in view(8, src)))
			next_shot = world.time + 2 SECONDS
			shots--
			Shoot(target_mob)
		else if (world.time >= next_step && route?.len)
			next_step = world.time + 1 SECOND
			var/turf/T = route[1]
			route.Cut(1, 2)
			if (!step_towards(src, T)) route = list()
	death()
		if (stat == DEAD) return
		..()
		aggressor = null
		target_mob = null
		route = list()
		var/obj/map_metadata/extraction_survival/M = map
		if (istype(M) && !death_registered)
			death_registered = TRUE
			M.npcs -= src
			M.corpses[src] = world.time + 5 MINUTES
			if (gun)
				M.track_loot(gun)
				gun = null
			M.spawn_loot(get_turf(src), /obj/item/extraction_salvage)

/mob/living/simple_animal/hostile/human/extraction/contractor
	name = "hostile contractor"
	desc = "An armed contractor hunting the district's raiders."
	icon_state = "pmc"
	icon_dead = "bandit_dead"
	contractor = TRUE
	faction = PIRATES
	health = 160
	maxHealth = 160
