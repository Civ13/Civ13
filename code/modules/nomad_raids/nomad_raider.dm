// A nomad party member: a human NPC whose fights run on the shared NPC
// combat AI (FindTarget, AttackTarget, cover, retreat, call_for_backup,
// do_movement pathfinding). Its party only decides when it may fight and
// where it walks; see nomad_visit.dm.

/mob/living/simple_animal/hostile/human/nomad_raider
	name = "nomad raider"
	desc = "A hard-faced wanderer, armed and looking for easy pickings."
	icon_state = "bandit2"
	icon_dead = "bandit2_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	faction = NOMAD_RAID_FACTION
	behaviour = "defends"
	use_generated_appearance = TRUE
	corpse_job = "Nomad"
	corpse = null
	role = "soldier"
	maxHealth = 100
	health = 100
	melee_damage_lower = 12
	melee_damage_upper = 20
	attacktext = "strikes"
	mob_size = MOB_MEDIUM
	starves = FALSE
	speak_chance = 0
	move_to_delay = 4
	var/tmp/datum/nomad_raid/party
	var/tmp/list/carried = list() // loot and payments, inside the mob until dropped
	var/tmp/is_leader = FALSE
	var/tmp/reload_at = 0

/mob/living/simple_animal/hostile/human/nomad_raider/persistence_runtime_var(key)
	return key == "reload_at" || ..()

/mob/living/simple_animal/hostile/human/nomad_raider/New()
	..()
	should_save = FALSE
	messages["injured"] = list("!!I'm hit!", "!!They cut me!")
	messages["backup"] = list("!!To me, clan!", "!!Over here!")
	messages["enemy_sighted"] = list("!!There!", "!!One of them!")

// Weapons by era: melee before firearms, then a sidearm like the bandits'.
/mob/living/simple_animal/hostile/human/nomad_raider/proc/arm_for_age(age)
	if (age >= 6)
		ranged = TRUE
		rapid = FALSE
		projectiletype = /obj/item/projectile/bullet/pistol/a32
		gun = new /obj/item/weapon/gun/projectile/revolver/coltpolicepositive/standardized(src)
		gun.should_save = FALSE
		reload_at = 0
		load_sidearm() // Civilization maps normally create empty guns.
		weapon = null
		attacktext = "pistol-whips"
	else if (age >= 4)
		weapon = /obj/item/weapon/material/sword/smallsword
		attacktext = "slashes"
	else if (age >= 1)
		weapon = /obj/item/weapon/material/spear/iron
		attacktext = "jabs"
	else
		weapon = /obj/item/weapon/material/spear
		attacktext = "jabs"

// The shared human AI's suppression bursts are for other NPC weapons. A
// raider's revolver fires once, and never aims at an unseen foe's current turf.
/mob/living/simple_animal/hostile/human/nomad_raider/OpenFire(target, suppress = FALSE)
	if (suppress)
		return FALSE
	return Shoot(target)

/mob/living/simple_animal/hostile/human/nomad_raider/Shoot(target)
	if (QDELETED(src) || stat != CONSCIOUS || !ranged || !gun || QDELETED(gun) || gun.loc != src)
		return FALSE
	if (!party || !party.hostile || QDELETED(target) || target != target_mob || !party.foe_ok(target))
		return FALSE
	// Recheck here, including delayed peeks and direct Shoot callers. Visibility
	// at target acquisition does not authorize firing after someone takes cover.
	if (!(target in view(aggro_vision_range, src)) || get_dist(src, target) > 12 || check_friendly_fire(target))
		return FALSE
	if (world.time < last_fire + firedelay || world.time < gun.next_fire_time)
		return FALSE
	if (reload_at)
		if (world.time < reload_at)
			return FALSE
		load_sidearm()
		reload_at = 0

	var/obj/item/projectile/projectile = gun.consume_next_projectile()
	if (!projectile)
		gun.handle_click_empty(src)
		// Keep the NPC's replenishing reserve, but pay for a full cylinder reload.
		reload_at = world.time + max(4 SECONDS, gun.load_delay * gun.max_shells)
		visible_message(SPAN_NOTICE("\The [src] starts reloading \the [gun]."))
		return FALSE
	last_fire = world.time
	gun.next_fire_time = world.time + gun.fire_delay
	var/target_zone = "chest"
	if (prob(20))
		target_zone = "head"
	else if (prob(15))
		target_zone = pick("l_arm", "r_arm", "r_leg", "l_leg")
	if (gun.process_projectile(projectile, src, target, target_zone))
		return FALSE
	gun.handle_post_fire(src)
	addtimer(CALLBACK(gun, /atom/proc/set_light, 0), 5)
	return TRUE

// Refill only the raider's own revolver, retaining any unfired rounds. Spent
// casings cycle in revolvers, so loaded.len alone cannot tell whether it is empty.
/mob/living/simple_animal/hostile/human/nomad_raider/proc/load_sidearm()
	var/obj/item/weapon/gun/projectile/revolver/coltpolicepositive/standardized/G = gun
	if (!istype(G) || QDELETED(G) || G.loc != src)
		return FALSE
	G.chambered = null
	G.chamber_offset = 0
	for (var/obj/item/ammo_casing/C in G.loaded.Copy())
		if (!C.BB)
			G.loaded -= C
			qdel(C)
	while (G.loaded.len < G.max_shells)
		G.loaded += new G.ammo_type(G)
	G.update_icon()
	return TRUE

// Only fights while its party allows it. Downed people are left alone, and
// a coordinator's focus target is preferred.
/mob/living/simple_animal/hostile/human/nomad_raider/FindTarget()
	if (!party || !party.hostile)
		return null
	var/mob/living/best
	var/best_score = -1e9
	for (var/mob/living/L in ListTargets(aggro_vision_range))
		if (!party.foe_ok(L))
			continue
		var/score = 100 - get_dist(src, L) * 5
		if (L == party.focus)
			score += 80
		if (ishuman(L))
			var/obj/item/held = L.get_active_hand()
			if (istype(held, /obj/item/weapon/gun))
				score += 60
			else if (held)
				score += 20
		if (score > best_score)
			best = L
			best_score = score
	return best

/mob/living/simple_animal/hostile/human/nomad_raider/death()
	if (stat == DEAD)
		return
	if (party)
		party.member_fell(src)
	..()

/mob/living/simple_animal/hostile/human/nomad_raider/Destroy()
	if (party)
		party.members -= src
		if (party.leader == src)
			party.leader = null
	party = null
	carried = null
	lose_cuffs()
	return ..()

// The leader hears players for the coordinator. Player text is data only.
/mob/living/simple_animal/hostile/human/nomad_raider/hear_say(var/message, var/verb = "says", var/datum/language/s_language = null, var/alt_name = "",var/italics = FALSE, var/mob/speaker = null, var/sound/speech_sound, var/sound_vol, var/alt_message = null, var/animal = FALSE, var/original_message = "")
	..()
	if (is_leader && party && stat == CONSCIOUS && ishuman(speaker) && speaker.client)
		party.heard(speaker, original_message ? original_message : message)

// Room left for loot, by total item size.
/mob/living/simple_animal/hostile/human/nomad_raider/proc/carry_space()
	var/used = 0
	for (var/obj/item/I in carried)
		used += I.w_class
	return NOMAD_RAID_CARRY - used

/mob/living/simple_animal/hostile/human/nomad_raider/proc/take_item(obj/item/I)
	if (!istype(I) || !isturf(I.loc) || I.anchored || I.w_class > carry_space())
		return FALSE
	if (!persistence_movement_allowed(I, src))
		return FALSE
	I.forceMove(src)
	carried += I
	return TRUE

// Everything carried goes to the ground where the member stands.
/mob/living/simple_animal/hostile/human/nomad_raider/proc/drop_carried()
	var/turf/T = get_turf(src)
	var/dropped = 0
	for (var/obj/item/I in carried)
		if (!QDELETED(I) && I.loc == src && T)
			I.forceMove(T)
			dropped++
	carried.Cut()
	return dropped
