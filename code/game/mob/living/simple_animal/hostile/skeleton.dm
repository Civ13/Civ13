/mob/living/simple_animal/hostile/human/skeleton
	name = "\improper Skeleton"
	desc = "Scary, spooky skeletons!"
	icon_state = "skeleton1"
	icon_dead = "skeleton_remains1"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("...")
	speak_emote = list("rattles")
	emote_hear = list("spooks")
	emote_see = list("stares", "spooks","rattles")
	icon = 'icons/mob/animal.dmi'
	speak_chance = TRUE
	speed = 5
	maxHealth = 100
	health = 100
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 14
	melee_damage_lower = 8
	melee_damage_upper = 14
	move_to_delay = 5
	break_stuff_probability = 25
	attacktext = "scratched"
	attack_sound = 'sound/weapons/genhit1.ogg'
	behaviour = "hostile"

	faction = "neutral"
/mob/living/simple_animal/hostile/human/skeleton/attacker
	name = "\improper Skeleton"

/mob/living/simple_animal/hostile/human/skeleton/attacker_gods
	name = "\improper Skeleton"
	var/obj/structure/religious/totem/offerings/target_loc

/mob/living/simple_animal/hostile/human/skeleton/New()
	..()
	icon_state = pick("skeleton1","skeleton2","skeleton3",)
	attack_sound = pick('sound/weapons/genhit1.ogg', 'sound/weapons/genhit2.ogg', 'sound/weapons/genhit3.ogg')
	icon_dead = pick("skeleton_remains1","skeleton_remains2","skeleton_remains3",)

/mob/living/simple_animal/hostile/human/skeleton/death()
	..()
	new/obj/structure/religious/remains(src.loc)
	qdel(src)
	return

/mob/living/simple_animal/hostile/human/skeleton/pirate
	name = "Pirate Skeleton"
	desc = "Scary, spooky skeletons! This one was once a pirate."
	icon_state = "skeleton3_pir"
	icon_dead = "skeleton_remains1"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("...")
	speak_emote = list("rattles")
	emote_hear = list("spooks")
	emote_see = list("stares", "spooks","rattles")
	speak_chance = TRUE
	speed = 5
	maxHealth = 100
	health = 100
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 14
	melee_damage_lower = 8
	melee_damage_upper = 14
	move_to_delay = 5
	break_stuff_probability = 25
	attacktext = "scratched"
	attack_sound = 'sound/weapons/genhit1.ogg'
	behaviour = "hostile"

	faction = "neutral"
	New()
		..()
		icon_state = "skeleton[rand(1,4)]_pir"

/mob/living/simple_animal/hostile/human/skeleton/draugr
	name = "Draugr"
	desc = "an undead nordic warrior"
	icon_state = "draugr1"
	icon_dead = "skeleton_remains1"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("...")
	speak_emote = list("rattles")
	emote_hear = list("spooks")
	emote_see = list("stares", "spooks","rattles")
	speak_chance = TRUE
	speed = 3
	maxHealth = 100
	health = 100
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 14
	melee_damage_lower = 8
	melee_damage_upper = 14
	move_to_delay = 5
	break_stuff_probability = 25
	attacktext = "scratched"
	attack_sound = 'sound/weapons/genhit1.ogg'
	behaviour = "hostile"

	faction = "neutral"
	New()
		..()
		icon_state = "draugr[rand(1,4)]"