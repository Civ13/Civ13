
/obj/structure/noose
	icon = 'icons/obj/noose.dmi'
	icon_state = ""
	layer = MOB_LAYER + 1.0
	anchored = TRUE
	var/mob/living/carbon/human/hanging = null
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

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
		hanging.lying = 0
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
			target.anchored = TRUE
			spawn(10)
				target.update_icons()

/obj/structure/noose/attack_hand(var/mob/living/carbon/human/H)
	if (!istype(H))
		return

	if (!hanging)
		return

	if (hanging == H)
		return

	visible_message("<span class = 'danger'>[H] starts to free [hanging] from the noose...</span>")
	if (do_after(H, 75, src))
		if (src && hanging)
			visible_message("<span class = 'danger'>[H] frees [hanging] from the noose!</span>")
			hanging.pixel_x = 0
			hanging.pixel_y = 0
			hanging.anchored = TRUE
			hanging = null


/obj/structure/gallows
	icon = 'icons/obj/gallows.dmi'
	icon_state = "gallows0"
	layer = MOB_LAYER + 1.0
	anchored = TRUE
	var/mob/living/carbon/human/hanging = null
	var/roped = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/gallows/New()
	..()
	processing_objects |= src

/obj/structure/gallows/Del()
	processing_objects -= src
	..()

/obj/structure/gallows/bullet_act(var/obj/item/projectile/P)
	if (hanging)
		hanging.bullet_act(P)
		visible_message("<span class = 'danger'>[hanging] is hit by the [P.name]!</span>")
	else
		..()

/obj/structure/gallows/process()
	fire()

// call this instead of process() if you want to do direct calls, I think its better - Kachnov
/obj/structure/gallows/proc/fire()
	if (hanging)
		hanging.forceMove(loc)
		density = TRUE
		hanging.lying = 0
		hanging.dir = SOUTH
		hanging.pixel_y = 3 // because getting punched resets it
		icon_state = "gallows2"

		if (pixel_x == 0)
			if (prob(50))
				pixel_x = -1
				icon_state = "gallows2a"
			else
				pixel_x = 1
				icon_state = "gallows2b"
		else if (pixel_x == -1)
			pixel_x = 0
			icon_state = "gallows2"
		else if (pixel_x == 1)
			pixel_x = 0
			icon_state = "gallows2"
		else // somehow
			pixel_x = 0
			icon_state = "gallows2"

		hanging.pixel_x = pixel_x

		if (hanging.stat != DEAD)
			hanging.adjustOxyLoss(5)
			if (prob(5))
				visible_message("<span class = 'danger'>[hanging]'s neck snaps.</span>")
				playsound(loc, 'sound/effects/gore/bullethit3.ogg')
				hanging.death()
			else if (prob(33))
				hanging << "<span class = 'danger'>You're suffocating!</span>"
	else if (roped == FALSE)
		icon_state = "gallows0"
		density = FALSE
	else
		icon_state = "gallows1"
		density = FALSE

/obj/structure/gallows/MouseDrop_T(var/atom/dropping, var/mob/user as mob)
	if (!ismob(dropping))
		return

	if (hanging)
		return

	var/mob/living/carbon/human/target = dropping
	var/mob/living/carbon/human/hangman = user

	if (!istype(target) || !istype(hangman))
		return
	if (roped)
		visible_message("<span class = 'danger'>[hangman] starts to hang [target == hangman ? "themselves" : target]...</span>")
		if (do_after(hangman, 50, target))
			if (src)
				visible_message("<span class = 'danger'>[hangman] hangs [target == hangman ? "themselves" : target]!</span>")
				hanging = target
				target.loc = get_turf(src)
				target.dir = SOUTH
				fire()
				spawn(10)
					target.update_icons()
					target.anchored = 1

/obj/structure/gallows/attack_hand(var/mob/living/carbon/human/H)
	if (!istype(H))
		return
	if (!hanging && roped)
		if (roped == TRUE)
			visible_message("[H] starts taking out the noose...", "You start taking out the noose...")
			if (do_after(H, 65, src) && roped == TRUE)
				visible_message("[H] finishes taking the rope from the gallows.", "You finish taking the rope from the gallows.")
				roped = FALSE
				icon_state = "gallows0"
				new/obj/item/stack/material/rope(H.loc)
				return
	if (!hanging)
		return

	if (hanging == H)
		return

	if (roped)
		visible_message("<span class = 'danger'>[H] starts to free [hanging] from the noose...</span>")
		if (do_after(H, 100, src))
			if (src && hanging)
				visible_message("<span class = 'danger'>[H] frees [hanging] from the noose!</span>")
				hanging.pixel_x = 0
				hanging.pixel_y = 0
				hanging.anchored = 0
				hanging = null
				icon_state = "gallows1"

/obj/structure/gallows/attackby(var/obj/item/W as obj, var/mob/living/carbon/human/H as mob)
	if (istype(W, /obj/item/weapon))
		if (W.sharp == TRUE && hanging && roped)
			visible_message("<span class = 'danger'>[H] starts to cut the noose with the [W]...</span>")
			if (do_after(H, 45, src))
				if (src)
					visible_message("<span class = 'danger'>[H] frees [hanging] from the noose!</span>")
					hanging.pixel_x = 0
					hanging.pixel_y = 0
					hanging.anchored = 0
					hanging = null
					icon_state = "gallows0"
					roped = FALSE
	if (istype(W, /obj/item/stack/material/rope))
		if (roped == FALSE)
			visible_message("[H] starts making a noose...", "You start making a noose...")
			if (do_after(H, 45, src))
				visible_message("[H] finishes attaching the noose to the gallows.", "You finish attaching the noose to the gallows.")
				roped = TRUE
				var/obj/item/stack/material/rope/R = W
				if (R.amount > 1)
					R.amount--
				else
					qdel(W)
				icon_state = "gallows1"
				return
		else
			H << "There already is a noose here."
			return
	else
		..()