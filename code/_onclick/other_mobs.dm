// Generic damage proc (slimes and monkeys).
/atom/proc/attack_generic(mob/user as mob)
	return FALSE

/*
	Humans:
	Adds an exception for gloves, to allow special glove types like the ninja ones.

	Otherwise pretty standard.
*/
/mob/living/human/UnarmedAttack(var/atom/A, var/proximity, icon_x, icon_y)

	if (!..())
		return

	// Special glove functions:
	// If the gloves do anything, have them return TRUE to stop
	// normal attack_hand() here.
	var/obj/item/clothing/gloves/G = gloves // not typecast specifically enough in defines
	if (istype(G) && G.Touch(A,1))
		return

	A.attack_hand(src, icon_x, icon_y)

/atom/proc/attack_hand(mob/user as mob, icon_x, icon_y)
	return

/mob/living/human/RestrainedClickOn(var/atom/A)
	return

/mob/living/human/RangedAttack(var/atom/A)
	if (!gloves && !mutations.len) return
	var/obj/item/clothing/gloves/G = gloves


	if (istype(G) && G.Touch(A,0)) // for magic gloves
		return

/mob/living/RestrainedClickOn(var/atom/A)
	return

/mob/new_player/ClickOn()
	return

/*
	Animals
*/
/mob/living/simple_animal/UnarmedAttack(var/atom/A, var/proximity)

	if (!..())
		return

	if (melee_damage_upper == FALSE && istype(A,/mob/living))
		custom_emote(1,"[friendly] [A]!")
		return

	var/damage = rand(melee_damage_lower, melee_damage_upper)
	if (A.attack_generic(src,damage,attacktext,environment_smash) && loc && attack_sound)
		playsound(loc, attack_sound, 50, TRUE, TRUE)
