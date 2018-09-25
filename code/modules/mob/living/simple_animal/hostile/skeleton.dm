/mob/living/simple_animal/hostile/skeleton
	name = "\improper Skeleton"
	desc = "Scary, spooky skeletons!"
	icon_state = "skeleton1"
	icon_dead = "skeleton_remains1"
	turns_per_move = 2
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
	harm_intent_damage = 15
	melee_damage_lower = 15
	melee_damage_upper = 20
	move_to_delay = 3
	break_stuff_probability = 25
	attacktext = "scratched"
	attack_sound = 'sound/weapons/genhit1.ogg'

	faction = PIRATES
/mob/living/simple_animal/hostile/skeleton/attacker
	name = "\improper Skeleton"
/mob/living/simple_animal/hostile/skeleton/New()
	..()
	icon_state = pick("skeleton1","skeleton2","skeleton3",)
	attack_sound = pick('sound/weapons/genhit1.ogg', 'sound/weapons/genhit2.ogg', 'sound/weapons/genhit3.ogg')
	icon_dead = pick("skeleton_remains1","skeleton_remains2","skeleton_remains3",)

/mob/living/simple_animal/hostile/skeleton/death()
	..()
	new/obj/structure/religious/remains(src.loc)
	qdel(src)
	return