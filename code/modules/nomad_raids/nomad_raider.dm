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
		projectiletype = /obj/item/projectile/bullet/pistol/a9x19
		gun = new /obj/item/weapon/gun/projectile/revolver/coltpolicepositive/standardized(src)
		gun.should_save = FALSE
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
