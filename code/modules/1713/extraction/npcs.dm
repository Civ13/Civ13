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
	// Assigned once at spawn. Neutral contacts become hostile only on attack.
	var/pmc_contact_hostile = FALSE
	var/tmp/obj/item/extraction_salvage/carried_salvage
	var/tmp/mob/living/aggressor
	var/tmp/list/hostile_entities = list()
	var/tmp/next_decision = 0
	var/tmp/next_step = 0
	var/tmp/next_shot = 0
	var/tmp/shots = 18
	var/tmp/death_registered = FALSE
	var/tmp/list/route = list()
	var/tmp/obj/item/loot_target
	var/tmp/next_scavenge = 0
	New()
		..()
		should_save = FALSE
		gun = new /obj/item/weapon/gun/projectile/pistol/m9beretta(src)
		var/datum/extraction_equipment_codec/provenance = new
		provenance.set_raid_provenance(gun, TRUE)
		gun.should_save = FALSE
		carried_salvage = new(src)
		provenance.set_raid_provenance(carried_salvage, TRUE)
		carried_salvage.should_save = FALSE
		projectiletype = /obj/item/projectile/bullet/pistol/a9x19
	Destroy()
		aggressor = null
		target_mob = null
		hostile_entities.Cut()
		route.Cut()
		carried_salvage = null
		loot_target = null
		var/obj/map_metadata/extraction_survival/M = map
		if (istype(M))
			M.npcs -= src
			M.npc_corpses -= src
		return ..()
	do_human_behaviour()
		return
	proc/scavenge_tick(obj/map_metadata/extraction_survival/M)
		if (stat != CONSCIOUS || z != 1 || world.time < next_scavenge) return FALSE
		next_scavenge = world.time + 2 SECONDS
		var/held = 0
		for (var/obj/item/I in contents) held++
		if (held >= 8) return FALSE
		if (loot_target && (!isturf(loot_target.loc) || loot_target.z != z || loot_target.anchored || !M.raid_items[loot_target])) loot_target = null
		if (!loot_target)
			var/best_distance = 13
			var/inspected = 0
			for (var/obj/item/I in view(12, src))
				if (++inspected > 128) break
				if (!isturf(I.loc) || I.z != z || I.anchored || !M.raid_items[I]) continue
				var/distance = get_dist(src, I)
				if (distance >= best_distance) continue
				// Unsupported graphs remain physically present for other actors.
				if (!M.codec.encode(I)) continue
				loot_target = I
				best_distance = distance
		if (!loot_target) return FALSE
		if (Adjacent(loot_target))
			loot_target.forceMove(src)
			loot_target = null
			route.Cut()
			return TRUE
		route = cirrAstar(get_turf(src), get_turf(loot_target), 5, 64)
		if (route.len) step_towards(src, route[1])
		return FALSE
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
			// Mode population is bounded to 32 participants and 12 NPCs.
			if (!(attacker in hostile_entities) && hostile_entities.len < 64) hostile_entities += attacker
			// Keep the original retaliation focus across brief visibility loss.
			if (!aggressor || !aggressor.loc || aggressor.stat == DEAD) aggressor = attacker
			target_mob = aggressor
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
			for (var/mob/living/enemy in hostile_entities.Copy())
				if (!enemy.loc || enemy.stat == DEAD) hostile_entities -= enemy
			if (aggressor && (!aggressor.loc || aggressor.stat == DEAD)) aggressor = null
			if (!aggressor && hostile_entities.len) aggressor = hostile_entities[1]
			if (aggressor) chosen = aggressor
			if (!chosen && (contractor || pmc_contact_hostile))
				var/best_distance = 13
				for (var/owner in M.accounts.sessions)
					var/datum/extraction_session/S = M.accounts.sessions[owner]
					var/mob/living/human/H = S.body
					if (S.profile["state"] != "raid" || !H || H.stat == DEAD || H.z != 1) continue
					if (!contractor && S.profile["raid_faction"] != "PMC") continue
					var/distance = get_dist(src, H)
					if (distance < best_distance && (H in view(12, src)))
						chosen = H
						best_distance = distance
				for (var/mob/living/simple_animal/hostile/human/extraction/N in M.npcs)
					if (N == src || N.stat == DEAD || N.z != 1 || (contractor ? N.contractor : !N.contractor)) continue
					var/distance = get_dist(src, N)
					if (distance < best_distance && (N in view(12, src)))
						chosen = N
						best_distance = distance
			if (chosen != target_mob) route = list()
			target_mob = chosen
			if (chosen && chosen.z == z && (chosen in view(12, src)) && get_dist(src, chosen) > 6) route = cirrAstar(get_turf(src), get_turf(chosen), 5, 64)
		if (!target_mob)
			scavenge_tick(M)
			return
		if (target_mob.stat == DEAD || target_mob.z != 1) return
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
		hostile_entities.Cut()
		target_mob = null
		route = list()
		loot_target = null
		var/obj/map_metadata/extraction_survival/M = map
		if (istype(M) && !death_registered)
			death_registered = TRUE
			M.npcs -= src
			M.npc_corpses[src] = world.time + 5 MINUTES
			if (gun)
				M.track_loot(gun)
				gun = null
			if (carried_salvage)
				carried_salvage.forceMove(get_turf(src))
				M.track_loot(carried_salvage)
				carried_salvage = null
			for (var/obj/item/I in contents.Copy())
				I.forceMove(get_turf(src))
				M.track_loot(I)

/mob/living/simple_animal/hostile/human/extraction/contractor
	name = "hostile contractor"
	desc = "An armed contractor hunting the district's raiders."
	icon_state = "pmc"
	icon_dead = "bandit_dead"
	contractor = TRUE
	faction = PIRATES
	health = 160
	maxHealth = 160
