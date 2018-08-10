/obj/structure/grille/fence
	name = "fence"
	desc = "An old wooden fence."
	icon = 'icons/obj/fence.dmi'
	icon_state = "1"
	health = 16
	hitsound = 'sound/effects/wooddoorhit.ogg'

/obj/structure/grille/fence/New()
	..()
	icon_state = "[rand(1,3)]"
	color = "#c8c8c8"


/obj/structure/flag
	icon = 'icons/obj/flags.dmi'
	icon_state = "black"
	layer = MOB_LAYER + 0.01
	bound_width = 32
	bound_height = 32
	density = TRUE
	anchored = TRUE

/obj/structure/flag/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(66))
				qdel(src)
				return
		if (3.0)
			return

/obj/structure/flag/pirates
	icon_state = "pirates"
	name = "Pirate Flag"
	desc = "A black and white pirate flags with skull and bones."


/obj/structure/flag/black
	icon_state = "black"
	name = "Black Flag"
	desc = "A black flag. That's it."


/obj/structure/noose
	icon = 'icons/obj/noose.dmi'
	icon_state = ""
	layer = MOB_LAYER + 1.0
	anchored = TRUE
	var/mob/living/carbon/human/hanging = null

/obj/structure/noose/New()
	..()
	processing_objects |= src

/obj/structure/noose/Del()
	processing_objects -= src
	..()

/obj/structure/noose/bullet_act(var/obj/item/projectile/P)
	if (hanging)
		hanging.bullet_act(P)
		visible_message("<span class = 'danger'>[hanging] is hit by the [P.name]!</span>")
	else
		..()

/obj/structure/noose/process()
	fire()

// call this instead of process() if you want to do direct calls, I think its better - Kachnov
/obj/structure/noose/proc/fire()
	if (hanging)
		hanging.forceMove(loc)
		density = TRUE
		hanging.dir = SOUTH
		hanging.pixel_y = 3 // because getting punched resets it
		icon_state = "noose-hanging"

		if (pixel_x == 0)
			pixel_x = 1
		else if (pixel_x == 1)
			pixel_x = 0
		else if (pixel_x == 0)
			pixel_x = -1
		else // somehow
			pixel_x = 0

		hanging.pixel_x = pixel_x

		if (hanging.stat != DEAD)
			hanging.adjustOxyLoss(5)
			if (prob(5))
				visible_message("<span class = 'danger'>[hanging]'s neck snaps.</span>")
				playsound(loc, 'sound/effects/gore/bullethit3.ogg')
				hanging.death()
			else if (prob(33))
				hanging << "<span class = 'danger'>You're suffocating!</span>"
	else
		icon_state = ""
		density = FALSE

/obj/structure/noose/MouseDrop_T(var/atom/dropping, var/mob/user as mob)
	if (!ismob(dropping))
		return

	if (hanging)
		return

	var/mob/living/carbon/human/target = dropping
	var/mob/living/carbon/human/hangman = user

	if (!istype(target) || !istype(hangman))
		return

	visible_message("<span class = 'danger'>[hangman] starts to hang [target == hangman ? "themselves" : target]...</span>")
	if (do_after(hangman, 50, target))
		if (src)
			visible_message("<span class = 'danger'>[hangman] hangs [target == hangman ? "themselves" : target]!</span>")
			hanging = target
			target.loc = get_turf(src)
			target.dir = SOUTH
			fire()

/obj/structure/noose/attack_hand(var/mob/living/carbon/human/H)
	if (!istype(H))
		return

	if (!hanging)
		return

	if (hanging == H)
		return

	visible_message("<span class = 'danger'>[H] starts to free [hanging] from the noose...</span>")
	if (do_after(H, 75, src))
		if (src)
			visible_message("<span class = 'danger'>[H] frees [hanging] from the noose!</span>")
			hanging.pixel_x = 0
			hanging.pixel_y = 0
			hanging = null