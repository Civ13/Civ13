
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