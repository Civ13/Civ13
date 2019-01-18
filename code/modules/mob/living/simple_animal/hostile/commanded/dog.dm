/mob/living/simple_animal/hostile/commanded/dog
	name = "dog"
	desc = "A friendly white dog."

	icon_state = "samoyed"
	icon_living = "samoyed"
	icon_dead = "samoyed_dead"
	icon_gib = "samoyed_dead"

	health = 55
	maxHealth = 55

	melee_damage_lower = 25
	melee_damage_upper = 35


	response_help = "pets"
	response_harm = "hits"
	response_disarm = "pushes"

	known_commands = list("stay", "stop", "attack", "follow")

/mob/living/simple_animal/hostile/commanded/dog/hit_with_weapon(obj/item/O, mob/living/user, var/effective_force, var/hit_zone)
	. = ..()
	if (!.)
		emote("barks and shows its teeth!")

/mob/living/simple_animal/hostile/commanded/dog/attack_hand(mob/living/carbon/human/M as mob)
	..()
	if (M.a_intent == I_HURT)
		emote("barks and shows its teeth!")