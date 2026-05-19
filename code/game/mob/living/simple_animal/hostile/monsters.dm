
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
// FAITHLESS
// A fast but fragile eldritch hunter. Unnerving and quick.
// Icons: faithless / faithless_dead in monsters/monsters.dmi
// --------------------------------

/mob/living/simple_animal/hostile/faithless
	name = "faithless one"
	desc = "A wretched, eyeless thing that moves with nauseating speed. It hunts by sound and scent."
	icon = 'icons/mob/monsters/monsters.dmi'
	icon_state = "faithless"
	icon_living = "faithless"
	icon_dead = "faithless_dead"
	icon_gib = "faithless_dead"
	speak = list("*skittering hiss*", "*wet clicking*", "*guttural screech*")
	speak_emote = list("hisses", "shrieks", "clicks")
	emote_hear = list("hisses", "clicks", "skitters")
	emote_see = list("cocks its eyeless head", "twitches violently", "sniffs the air")
	speak_chance = TRUE
	// Fast hunter, lightly built
	move_to_delay = 2
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "prods"
	response_disarm = "shoves away"
	response_harm   = "strikes"
	stop_automated_movement_when_pulled = FALSE
	// Fast and aggressive but dies relatively easily
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

/mob/living/simple_animal/hostile/faithless/New()
	..()
	custom_emote(1, "slinks out of the darkness, twitching erratically.")

/mob/living/simple_animal/hostile/faithless/death()
	visible_message("\The [src] lets out one final, wet shriek before going still.")
	..()


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