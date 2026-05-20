
// ============================================================
// MONSTERS
// Mythical and sci-fi hostile creatures
// ============================================================

// --------------------------------
// WENDIGO
// A powerful but slow supernatural predator from native legend.
// High health, very high damage, slower movement.
// Icons: wendigo / wendigo_Dead in animal_64.dmi
// --------------------------------

/mob/living/simple_animal/hostile/wendigo
	name = "wendigo"
	desc = "A gaunt, towering figure of hunger and winter. Run while you still can."
	icon = 'icons/mob/animal_64.dmi'
	icon_state = "wendigo"
	icon_living = "wendigo"
	icon_dead = "wendigo_Dead"
	icon_gib = "wendigo_Dead"
	speak = list("*inhuman screech*", "*bone-cracking howl*", "FLESH...", "HUNGRY...")
	speak_emote = list("shrieks", "wails")
	emote_hear = list("shrieks", "wails", "growls")
	emote_see = list("stares with empty black eyes", "sniffs the frozen air", "clicks its bones")
	speak_chance = TRUE
	// Slow but relentless hunter
	move_to_delay = 9
	see_in_dark = 8
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "prods"
	response_disarm = "shoves away"
	response_harm   = "strikes"
	stop_automated_movement_when_pulled = FALSE
	// Tanky and hits very hard — balanced by slow speed
	maxHealth = 220
	health = 220
	melee_damage_lower = 30
	melee_damage_upper = 45
	mob_size = MOB_LARGE
	can_bite_limbs_off = 1
	predatory_carnivore = 1
	carnivore = 1
	fat_penalty = 1
	break_stuff_probability = 30
	attacktext = "mauls"
	attack_sound = 'sound/weapons/demon_attack1.ogg'
	faction = "neutral"

/mob/living/simple_animal/hostile/wendigo/New()
	..()
	custom_emote(1, "lets out a bone-chilling wail as it materialises from the cold.")

/mob/living/simple_animal/hostile/wendigo/death()
	visible_message("\The [src] collapses with an ear-splitting shriek, its form dissolving into frost and shadow.")
	..()
// --------------------------------
// LIGHTSEEKER
// A fast but fragile eldritch hunter. Hunts light sources.
// Only targets mobs carrying an active light, or anyone within 1 tile.
// Icons: faithless / faithless_dead in monsters/monsters.dmi
// --------------------------------

/mob/living/simple_animal/hostile/lightseeker
	name = "lightseeker"
	desc = "A wretched, eyeless thing that moves with nauseating speed. It hunts light, so stay in the dark!"
	icon = 'icons/mob/monsters/monsters.dmi'
	icon_state = "faithless"
	icon_living = "faithless"
	icon_dead = "faithless_dead"
	icon_gib = "faithless_dead"
	speak = list("*skittering hiss*", "*wet clicking*", "*guttural screech*")
	speak_emote = list("hisses", "shrieks", "clicks")
	emote_hear = list("hisses", "clicks", "skitters")
	emote_see = list("cocks its head toward the light", "twitches violently", "sniffs the air")
	speak_chance = TRUE
	move_to_delay = 2
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "prods"
	response_disarm = "shoves away"
	response_harm   = "strikes"
	stop_automated_movement_when_pulled = FALSE
	maxHealth = 55
	health = 55
	melee_damage_lower = 8
	melee_damage_upper = 16
	mob_size = MOB_MEDIUM
	predatory_carnivore = 1
	carnivore = 1
	attacktext = "slashes"
	attack_sound = 'sound/weapons/demon_attack1.ogg'
	faction = "neutral"
	behaviour = "hunt" // use standard hunt engine; we gate targets via FindTarget()
	idle_vision_range = 9
	light_power = 1
	light_range = 1
	light_color = "#FF0000"

/mob/living/simple_animal/hostile/lightseeker/New()
	..()
	custom_emote(1, "slinks out of the darkness, twitching erratically.")

/mob/living/simple_animal/hostile/lightseeker/death()
	visible_message("\The [src] lets out one final, wet shriek before going still.")
	set_light(0)
	..()

// Returns TRUE if M is carrying an active (lit) light source.
// Checks hands (base mob), and belt + ID slot (human-only).
/mob/living/simple_animal/hostile/lightseeker/proc/is_carrying_light(var/mob/living/M)
	// Hands — defined on base /mob, works for all mobs
	for (var/obj/item/flashlight/FL in list(M.r_hand, M.l_hand))
		if (FL && FL.on)
			return TRUE
	// Belt and ID slot — human-only vars
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.phosphor_dye_timer > 0)
			return TRUE
		for (var/obj/item/flashlight/FL in list(H.belt, H.wear_id))
			if (FL && FL.on)
				return TRUE
	return FALSE

// Override FindTarget() — the standard hunt AI calls this to pick a target.
// We only allow mobs carrying an active light, or anyone already adjacent (1 tile).
/mob/living/simple_animal/hostile/lightseeker/FindTarget()
	stop_automated_movement = FALSE
	var/mob/living/best = null
	var/best_priority = 0 // 2 = light carrier (chase across room), 1 = adjacent (bumped into)

	for (var/mob/living/L in view(idle_vision_range, src))
		if (L == src || L.stat == DEAD)
			continue
		if (!ishuman(L) && (L.faction == faction || (L in friends)))
			continue
		var/priority = 0
		if (is_carrying_light(L))
			priority = 2
		else if (get_dist(src, L) <= 1)
			priority = 1
		if (priority > best_priority)
			best_priority = priority
			best = L

	if (best)
		custom_emote(1, "snaps its head toward [best].")
		stance = HOSTILE_STANCE_ATTACK
	return best

// Drop the current target if they extinguish their light and step away.
/mob/living/simple_animal/hostile/lightseeker/Life()
	..()
	if (stat == DEAD || stat == UNCONSCIOUS)
		return
	if (target_mob && stance == HOSTILE_STANCE_ATTACK)
		if (!is_carrying_light(target_mob) && get_dist(src, target_mob) > 1)
			LoseTarget()

// --------------------------------
// ALIEN XENOMORPH
// Based on the Alien franchise. A deadly, calculating hunter.
// High health, high damage, fast. The apex predator.
// Icons: alienh / alienh_dead in monsters/alien.dmi
// --------------------------------

/mob/living/simple_animal/hostile/alien
	name = "xenomorph"
	desc = "A sleek, chitinous nightmare. Acidic blood, razor claws, and absolutely no mercy."
	icon = 'icons/mob/monsters/alien.dmi'
	icon_state = "alienh"
	icon_living = "alienh"
	icon_dead = "alienh_dead"
	icon_gib = "alienh_dead"
	speak = list("*sharp hiss*", "*inner jaw clicks*")
	speak_emote = list("hisses", "snarls")
	emote_hear = list("hisses", "snarls", "skitters overhead")
	emote_see = list("tilts its elongated head", "coils its tail", "drools acid")
	speak_chance = TRUE
	// Fast, aggressive apex predator
	move_to_delay = 3
	see_in_dark = 10
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "prods"
	response_disarm = "shoves away"
	response_harm   = "strikes"
	stop_automated_movement_when_pulled = FALSE
	// Strong all-rounder — high HP, high damage, solid speed
	maxHealth = 175
	health = 175
	melee_damage_lower = 20
	melee_damage_upper = 35
	mob_size = MOB_LARGE
	can_bite_limbs_off = 1
	predatory_carnivore = 1
	carnivore = 1
	break_stuff_probability = 20
	attacktext = "claws"
	attack_sound = 'sound/weapons/alien_claw_flesh1.ogg'
	faction = "neutral"

/mob/living/simple_animal/hostile/alien/New()
	..()
	custom_emote(1, "emerges from the shadows, drooling acid onto the floor.")

/mob/living/simple_animal/hostile/alien/death()
	visible_message("\The [src] lets out a final screech as acid blood pools beneath it.")
	..()

// Drone subtype — lighter, faster scout variant
/mob/living/simple_animal/hostile/alien/drone
	name = "alien drone"
	desc = "A smaller, faster variant of the xenomorph. Still absolutely lethal."
	move_to_delay = 2
	maxHealth = 90
	health = 90
	melee_damage_lower = 12
	melee_damage_upper = 22
	mob_size = MOB_MEDIUM
	can_bite_limbs_off = 0
	icon_state = "Drone Front Half"
	icon_living = "Drone Front Half"
	icon_dead = "alienh_dead"
	icon_gib = "alienh_dead"

// ============================================================
// NEW MONSTERS & VARIABLES
// ============================================================

/mob/living/var/mob/living/simple_animal/hostile/canopy_strangler/choked_by = null

/mob/living/human/var/cold_protection_disabled_timer = 0
/mob/living/human/var/phosphor_dye_timer = 0
/mob/living/human/var/blizzard_time = 0

// --------------------------------
// FATA MORGANA (Blizzard Mirage)
// --------------------------------
/mob/living/simple_animal/hostile/fata_morgana
	name = "blizzard mirage"
	desc = "A shifting, translucent shape born of the ice."
	icon = 'icons/mob/monsters/monsters.dmi'
	icon_state = "fata_morgana"
	icon_living = "fata_morgana"
	icon_dead = "fata_morgana"
	icon_gib = "fata_morgana"
	maxHealth = 1
	health = 1
	alpha = 150
	faction = "neutral"
	stop_automated_movement = TRUE
	stance = HOSTILE_STANCE_IDLE
	behaviour = "none"
	var/mob/living/human/creator_player = null
	var/disguise_type = "crate"

/mob/living/simple_animal/hostile/fata_morgana/New()
	..()
	disguise_type = pick("crate", "loot")
	switch(disguise_type)
		if ("crate")
			name = "crate"
			desc = "A rectangular crate."
			icon = 'icons/obj/storage.dmi'
			icon_state = "wood_crate"
		if ("loot")
			name = "wooden plank"
			icon_state = "logs"
			icon = 'icons/obj/materials.dmi'
	icon_living = icon_state
	icon_dead = icon_state
	icon_gib = icon_state

/mob/living/simple_animal/hostile/fata_morgana/Life()
	..()
	if (stat == DEAD || !creator_player || creator_player.stat == DEAD)
		qdel(src)
		return

	var/dist = get_dist(src, creator_player)
	if (dist <= 1)
		visible_message("<span class='warning'>\The [src] vanishes in a freezing burst of wind!</span>")
		playsound(src, 'sound/effects/extinguish.ogg', 70, TRUE)
		creator_player.bodytemperature = 100
		creator_player.cold_protection_disabled_timer = 60 // 2 minutes (60 ticks of Life)
		qdel(src)
		return

	if (dist > 12)
		qdel(src)
		return

	var/step_dir = get_dir(creator_player, src)
	step(src, step_dir)

// --------------------------------
// BOREAS (Hearth-Eater)
// --------------------------------
/mob/living/simple_animal/hostile/boreas
	name = "boreas"
	desc = "A massive elemental beast of dark blue glacial ice."
	icon = 'icons/mob/monsters/monsters.dmi'
	icon_state = "ice_demon"
	icon_living = "ice_demon"
	icon_dead = "ice_demon_dead"
	maxHealth = 300
	health = 300
	melee_damage_lower = 20
	melee_damage_upper = 35
	move_to_delay = 12
	faction = "neutral"
	behaviour = "hunt"	

/mob/living/simple_animal/hostile/boreas/bullet_act(var/obj/item/projectile/P)
	return FALSE

/mob/living/simple_animal/hostile/boreas/apply_damage(var/damage = 0, var/damagetype = BRUTE, var/def_zone = null, var/blocked = FALSE, var/used_weapon = null, var/sharp = FALSE, var/edge = FALSE)
	if (damagetype == BURN)
		return ..(damage * 1.5, damagetype, def_zone, blocked, used_weapon, sharp, edge)
	else if (damagetype == BRUTE)
		return FALSE
	return ..()

/mob/living/simple_animal/hostile/boreas/FindTarget()
	stop_automated_movement = FALSE
	var/mob/living/best = null
	var/best_dist = 999
	for (var/mob/living/human/H in view(9, src))
		if (H.stat != DEAD)
			var/d = get_dist(src, H)
			if (d < best_dist)
				best_dist = d
				best = H
	if (best)
		stance = HOSTILE_STANCE_ATTACK
	return best

/mob/living/simple_animal/hostile/boreas/Life()
	..()
	if (stat == DEAD || stat == UNCONSCIOUS)
		return

	for (var/obj/structure/oven/O in range(3, src))
		if (O.on && O.fuel > 0 && prob(50))
			O.fuel = max(0, O.fuel - 1)
			if (O.fuel <= 0)
				O.on = FALSE
				O.set_light(0)
				O.update_icon()
				visible_message("<span class='danger'>\The [O]'s fire is being vacuumed by the freezing presence of [src]!</span>")

	if (!target_mob && stance == HOSTILE_STANCE_IDLE)
		var/obj/structure/oven/closest_oven = null
		var/closest_dist = 999
		for (var/obj/structure/oven/O in view(9, src))
			if (O.on && O.fuel > 0)
				var/d = get_dist(src, O)
				if (d < closest_dist)
					closest_dist = d
					closest_oven = O
		if (closest_oven)
			walk_to(src, closest_oven, TRUE, move_to_delay)

// --------------------------------
// ECHOFIEND (Jungle Sound Hunter)
// --------------------------------
/mob/living/simple_animal/hostile/echofiend
	name = "echofiend"
	desc = "A blind, hunched monstrosity with massive ears. It reacts to the slightest sound."
	icon = 'icons/mob/monsters/monsters.dmi'
	icon_state = "echofiend"
	icon_living = "echofiend"
	icon_dead = "echofiend_dead"
	icon_gib = "echofiend_dead"
	maxHealth = 120
	health = 120
	melee_damage_lower = 15
	melee_damage_upper = 25
	move_to_delay = 3
	faction = "neutral"
	var/turf/investigate_turf = null

/mob/living/simple_animal/hostile/echofiend/FindTarget()
	return null

/mob/living/simple_animal/hostile/echofiend/Life()
	..()
	if (stat == DEAD || stat == UNCONSCIOUS)
		return

	if (!target_mob)
		for (var/mob/living/human/H in range(1, src))
			if (H.stat != DEAD)
				target_mob = H
				stance = HOSTILE_STANCE_ATTACK
				walk_to(src, H, TRUE, move_to_delay)
				break

	if (target_mob)
		if (target_mob.stat == DEAD || get_dist(src, target_mob) > 6)
			target_mob = null
			stance = HOSTILE_STANCE_IDLE
			walk(src, 0)
		return

	if (investigate_turf)
		if (get_turf(src) == investigate_turf)
			investigate_turf = null
			walk(src, 0)
		else
			walk_to(src, investigate_turf, TRUE, move_to_delay)

/mob/living/simple_animal/hostile/echofiend/proc/hear_sound(var/turf/T)
	if (stat != CONSCIOUS || target_mob)
		return
	investigate_turf = T
	custom_emote(1, "twitches its ears and turns toward the sound.")

/mob/living/simple_animal/hostile/echofiend/hear_say(var/message, var/verb, var/datum/language/speaking, var/alt_name, var/italics, var/mob/speaker, var/sound/speech_sound, var/sound_vol, var/alt_message, var/animal, var/original_message)
	hear_sound(get_turf(speaker))
	..()

// --------------------------------
// CANOPY STRANGLER (Ambush Vine)
// --------------------------------
/mob/living/simple_animal/hostile/canopy_strangler
	name = "canopy strangler"
	desc = "A leafy, vertical vine hanging from the trees. Watch your head."
	icon = 'icons/mob/monsters/monsters.dmi'
	icon_state = "vine_strangler_static"
	icon_living = "vine_strangler_static"
	icon_dead = "vine_strangler_static"
	icon_gib = "vine_strangler_static"
	maxHealth = 80
	health = 80
	density = FALSE
	anchored = TRUE
	faction = "neutral"
	stop_automated_movement = TRUE
	stance = HOSTILE_STANCE_IDLE
	var/mob/living/human/choking_mob = null

/mob/living/simple_animal/hostile/canopy_strangler/Crossed(atom/movable/AM)
	..()
	if (choking_mob || stat == DEAD || stat == UNCONSCIOUS)
		return
	if (ishuman(AM))
		var/mob/living/human/H = AM
		if (H.stat == DEAD)
			return
		var/turf/T = get_turf(src)
		if (T && T.get_lumcount() < 0.25)
			choking_mob = H
			H.choked_by = src
			icon_state = "vine_strangler"
			visible_message("<span class='danger'>A loop of thick vine drops around [H]'s neck, lifting them slightly!</span>")
			to_chat(H, "<span class='userdanger'>A strangling vine tightens around your neck! You can't speak or move!</span>")

/mob/living/simple_animal/hostile/canopy_strangler/Life()
	..()
	if (stat == DEAD || stat == UNCONSCIOUS)
		if (choking_mob)
			release_mob()
			qdel(src)
		return

	var/turf/T = get_turf(src)
	if (T)
		if (choking_mob)
			alpha = 255
		else if (T.get_lumcount() < 0.25)
			alpha = 0
		else
			alpha = 255

	if (choking_mob)
		if (choking_mob.stat == DEAD || get_turf(choking_mob) != T)
			release_mob()
			return
		choking_mob.apply_damage(5, BURN, "head")
		choking_mob.Paralyse(3)

/mob/living/simple_animal/hostile/canopy_strangler/death()
	release_mob()
	qdel(src)
	..()

/mob/living/simple_animal/hostile/canopy_strangler/proc/release_mob()
	if (choking_mob)
		choking_mob.choked_by = null
		choking_mob.SetParalysis(0)
		choking_mob = null
	icon_state = "vine_strangler_static"

// --------------------------------
// PHOSPHOR BEETLE (Jungle Light Dye)
// --------------------------------
/mob/living/simple_animal/hostile/phosphor_beetle
	name = "phosphor beetle"
	desc = "A glowing green beetle that moves with skittering speed."
	icon = 'icons/mob/monsters/monsters.dmi'
	icon_state = "glowing_beetle"
	icon_living = "glowing_beetle"
	icon_dead = "glowing_beetle_dead"
	icon_gib = "glowing_beetle_dead"
	maxHealth = 40
	health = 40
	melee_damage_lower = 2
	melee_damage_upper = 5
	move_to_delay = 2
	faction = "neutral"
	density = FALSE

/mob/living/simple_animal/hostile/phosphor_beetle/Crossed(atom/movable/AM)
	..()
	if (stat == DEAD || stat == UNCONSCIOUS)
		return
	if (ishuman(AM))
		explode_dye(AM)

/mob/living/simple_animal/hostile/phosphor_beetle/AttackTarget()
	. = ..()
	if (.)
		explode_dye(target_mob)

/mob/living/simple_animal/hostile/phosphor_beetle/proc/explode_dye(var/mob/living/human/H)
	if (!istype(H) || H.stat == DEAD)
		return
	visible_message("<span class='warning'>\The [src] explodes in a splash of glowing green dye!</span>")
	playsound(src, 'sound/effects/extinguish.ogg', 60, TRUE)
	H.phosphor_dye_timer = 60
	H.set_light(3, 1, "#00FF00")
	H.apply_damage(5, BURN, "chest")
	qdel(src)

/mob/living/human/proc/spawn_fata_morgana()
	var/list/valid_turfs = list()
	for (var/turf/T in range(8, src))
		if (get_dist(src, T) >= 5)
			var/area/A = get_area(T)
			if (A && A.location == AREA_OUTSIDE && !T.density)
				valid_turfs += T
	if (valid_turfs.len)
		var/turf/spawn_turf = pick(valid_turfs)
		var/mob/living/simple_animal/hostile/fata_morgana/FM = new(spawn_turf)
		FM.creator_player = src