/* This is a bear.
	It eats berries and plants and mauls people who attack it
	It starts full but has to eat a lot due to high nutrition
	and it has more stamina than any human, allowing it to outrun them.
*/

/mob/living/simple_animal/complex_animal/bear
	base_type = /mob/living/simple_animal/complex_animal/bear
	stamina = 200
	nutrition = 750

// things we do every life tick
/mob/living/simple_animal/complex_animal/bear/onEveryLifeTick()
	..()

// things we do when someone touches us
/mob/living/simple_animal/complex_animal/bear/onTouchedBy(var/mob/living/human/H, var/intent = I_HELP)
	return

// things we do when someone attacks us
/mob/living/simple_animal/complex_animal/bear/onAttackedBy(var/mob/living/human/H, var/obj/item/weapon/W)
	return

/* things we do whenever a nearby human moves:
called after H added to knows_about_mobs() */
/mob/living/simple_animal/complex_animal/bear/onHumanMovement(var/mob/living/human/H)
	return

// things we do whenever a mob with our base_type moves
/mob/living/simple_animal/complex_animal/bear/onEveryBaseTypeMovement(var/mob/living/simple_animal/complex_animal/C)
	return

// things we do whenever a mob with type 'X' moves
/mob/living/simple_animal/complex_animal/bear/onEveryXMovement(var/mob/X)
	return