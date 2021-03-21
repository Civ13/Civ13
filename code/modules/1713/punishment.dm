
/obj/structure/noose
	icon = 'icons/obj/noose.dmi'
	icon_state = ""
	layer = MOB_LAYER + 1.0
	anchored = TRUE
	var/mob/living/human/hanging = null
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

	var/mob/living/human/target = dropping
	var/mob/living/human/hangman = user

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

/obj/structure/noose/attack_hand(var/mob/living/human/H)
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
	var/mob/living/human/hanging = null
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

	var/mob/living/human/target = dropping
	var/mob/living/human/hangman = user

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

/obj/structure/gallows/attack_hand(var/mob/living/human/H)
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

/obj/structure/gallows/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
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

//////////////////////////////////////////////////////////////
////////////////////////CRUCIFIXION///////////////////////////
/obj/structure/cross
	icon = 'icons/obj/obj32x64.dmi'
	name = "greek cross"
	desc = "a cross for hanging criminals."
	icon_state = "greekcross"
	var/base_icon = "greekcross"
	layer = MOB_LAYER - 0.1
	anchored = TRUE
	var/mob/living/human/hanging = null
	var/image/crossoverlay
	not_movable = FALSE
	not_disassemblable = FALSE
	New()
		..()
		crossoverlay = image(icon=src.icon, icon_state="[base_icon]_used")

/obj/structure/cross/tau
	name = "tau cross"
	icon_state = "taucross"
	base_icon = "taucross"

/obj/structure/cross/New()
	..()
	processing_objects |= src

/obj/structure/cross/Del()
	processing_objects -= src
	..()

/obj/structure/cross/bullet_act(var/obj/item/projectile/P)
	if (hanging)
		hanging.bullet_act(P)
		visible_message("<span class = 'danger'>[hanging] is hit by the [P.name]!</span>")
	else
		..()

/obj/structure/cross/process()
	fire()

// call this instead of process() if you want to do direct calls, I think its better - Kachnov
/obj/structure/cross/proc/fire()
	if (hanging)
		hanging.forceMove(get_turf(locate(x,y+1,z)))
		density = TRUE
		hanging.lying = 0
		hanging.dir = SOUTH

	else
		overlays.Cut()
		density = FALSE

/obj/structure/cross/MouseDrop_T(var/atom/dropping, var/mob/user as mob)
	if (!ismob(dropping))
		return

	if (hanging)
		return

	var/mob/living/human/target = dropping
	var/mob/living/human/hangman = user

	if (!istype(target) || !istype(hangman))
		return
	visible_message("<span class = 'danger'>[hangman] starts to nail [target == hangman ? "themselves" : target] to the cross...</span>")
	if (do_after(hangman, 80, target))
		if (src)
			visible_message("<span class = 'danger'>[hangman] nails [target == hangman ? "themselves" : target] to the cross!</span>")
			hanging = target
			target.loc = get_turf(src)
			target.dir = SOUTH
			var/dam_zone = list("l_foot", "r_foot", "l_hand", "r_hand")
			for (var/organ_p in dam_zone)
				var/obj/item/organ/external/affecting = target.get_organ(organ_p)
				target.apply_damage(rand(15,20), BRUTE, affecting, 0, sharp=1, edge=1)
			fire()
			spawn(10)
				target.update_icons()
				target.anchored = 1
			overlays += crossoverlay

/obj/structure/cross/attack_hand(var/mob/living/human/H)
	if (!istype(H))
		return

	if (!hanging)
		return

	if (hanging == H)
		return

	visible_message("<span class = 'danger'>[H] starts to free [hanging] from the cross...</span>")
	if (do_after(H, 100, src))
		if (src && hanging)
			visible_message("<span class = 'danger'>[H] frees [hanging] from the cross!</span>")
			hanging.pixel_x = 0
			hanging.pixel_y = 0
			hanging.anchored = 0
			hanging = null
			overlays.Cut()

//////////////////////////////////////////////////////////////
////////////////////////STOCK/PILLORY///////////////////////////
/obj/structure/pillory
	icon = 'icons/obj/structures.dmi'
	name = "pillory"
	desc = "a wood stock with three holes, for both hands and the head. Used to display criminals to the public."
	icon_state = "pillory"
	layer = MOB_LAYER - 0.1
	anchored = TRUE
	var/mob/living/human/hanging = null
	var/image/poverlay
	var/icon/hoverlay
	not_movable = FALSE
	not_disassemblable = FALSE
	New()
		..()
		poverlay = image(icon=src.icon, icon_state="pillory_lower0")
		hoverlay = icon(icon=src.icon, icon_state="pillory_handoverlay")
/obj/structure/pillory/New()
	..()
	processing_objects |= src

/obj/structure/pillory/Del()
	processing_objects -= src
	..()

/obj/structure/pillory/bullet_act(var/obj/item/projectile/P)
	if (hanging && prob(30))
		hanging.bullet_act(P)
		visible_message("<span class = 'danger'>[hanging] is hit by the [P.name]!</span>")
	else
		..()

/obj/structure/pillory/process()
	fire()

// call this instead of process() if you want to do direct calls, I think its better - Kachnov
/obj/structure/pillory/proc/fire()
	if (hanging)
		hanging.forceMove(loc)
		hanging.lying = 0
		hanging.dir = SOUTH

	else
		overlays.Cut()
		hoverlay = icon(icon=src.icon, icon_state="pillory_handoverlay")

/obj/structure/pillory/MouseDrop_T(var/atom/dropping, var/mob/user as mob)
	if (!ismob(dropping))
		return

	if (hanging)
		return

	var/mob/living/human/target = dropping
	var/mob/living/human/hangman = user

	if (!istype(target) || !istype(hangman))
		return
	visible_message("<span class = 'danger'>[hangman] starts to place [target == hangman ? "themselves" : target] in the pillory...</span>")
	if (do_after(hangman, 60, target))
		if (src)
			visible_message("<span class = 'danger'>[hangman] places [target == hangman ? "themselves" : target] in the pollory!</span>")
			hanging = target
			target.loc = get_turf(src)
			target.dir = SOUTH
			spawn(10)
				target.update_icons()
				target.anchored = 1
			overlays += poverlay
			if (target.s_tone)
				if (target.s_tone >= 0)
					hoverlay.Blend(rgb(target.s_tone, target.s_tone, target.s_tone), ICON_ADD)
				else
					hoverlay.Blend(rgb(-target.s_tone,  -target.s_tone,  -target.s_tone), ICON_SUBTRACT)
					overlays += hoverlay

/obj/structure/pillory/attack_hand(var/mob/living/human/H)
	if (!istype(H))
		return

	if (!hanging)
		return

	if (hanging == H)
		return

	visible_message("<span class = 'danger'>[H] starts to free [hanging] from the pillory...</span>")
	if (do_after(H, 60, src))
		if (src && hanging)
			visible_message("<span class = 'danger'>[H] frees [hanging] from the pillory!</span>")
			hanging.pixel_x = 0
			hanging.pixel_y = 0
			hanging.anchored = 0
			hanging = null
			overlays.Cut()
			desc = "a wood stock with three holes, for both hands and the head. Used to display criminals to the public."

/obj/structure/pillory/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/pen) && hanging)
		var/newtext = input("What do you want to write on the sign? (Up to 30 characters)","Sign", "") as text
		if (newtext == null || newtext == "")
			newtext = "There is nothing on the sign."
			desc = newtext
			poverlay.icon_state = "pillory_lower0"
			update_icon()
			return
		newtext = sanitize(newtext, 30, FALSE)
		desc = "It reads: <b>[newtext]</b>"
		poverlay.icon_state = "pillory_lower1"
		update_icon()
		return
	else
		..()

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////EXECUTION POST///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/obj/structure/post_execution
	icon = 'icons/obj/structures.dmi'
	name = "execution post"
	desc = "a wood stock with a rope to tie prisoners to in preparation for a firing squad."
	icon_state = "post_execution"
	layer = MOB_LAYER - 0.11
	anchored = TRUE
	var/mob/living/human/hanging = null
	var/image/poverlay
	var/icon/hoverlay
	not_movable = FALSE
	not_disassemblable = FALSE
	New()
		..()
		poverlay = image(icon=src.icon, icon_state="post_execution")
		hoverlay = icon(icon=src.icon, icon_state="post_execution_rope")
/obj/structure/post_execution/New()
	..()
	processing_objects |= src

/obj/structure/post_execution/Del()
	processing_objects -= src
	..()

/obj/structure/post_execution/bullet_act(var/obj/item/projectile/P)
	if (hanging && prob(30))
		hanging.bullet_act(P)
		visible_message("<span class = 'danger'>[hanging] is hit by the [P.name]!</span>")
	else
		..()

/obj/structure/post_execution/process()
	fire()

// call this instead of process() if you want to do direct calls, I think its better - Kachnov
/obj/structure/post_execution/proc/fire()
	if (hanging)
		hanging.forceMove(loc)
		hanging.lying = 0
		hanging.dir = NORTH

	else
		overlays.Cut()
		hoverlay = icon(icon=src.icon, icon_state="post_execution_rope")

/obj/structure/post_execution/MouseDrop_T(var/atom/dropping, var/mob/user as mob)
	if (!ismob(dropping))
		return

	if (hanging)
		return

	var/mob/living/human/target = dropping
	var/mob/living/human/hangman = user

	if (!istype(target) || !istype(hangman))
		return
	visible_message("<span class = 'danger'>[hangman] starts to tie [target == hangman ? "themselves" : target] to the post...</span>")
	if (do_after(hangman, 60, target))
		if (src)
			visible_message("<span class = 'danger'>[hangman] ties [target == hangman ? "themselves" : target] to the post!</span>")
			hanging = target
			target.loc = get_turf(src)
			target.dir = NORTH
			spawn(10)
				target.update_icons()
				target.anchored = 1
			overlays += poverlay
			if (target.s_tone)
				if (target.s_tone >= 0)
					hoverlay.Blend(rgb(target.s_tone, target.s_tone, target.s_tone), ICON_ADD)
				else
					hoverlay.Blend(rgb(-target.s_tone,  -target.s_tone,  -target.s_tone), ICON_SUBTRACT)
					overlays += hoverlay

/obj/structure/post_execution/attack_hand(var/mob/living/human/H)
	if (!istype(H))
		return

	if (!hanging)
		return

	if (hanging == H)
		return

	visible_message("<span class = 'danger'>[H] starts to untie [hanging] from the post...</span>")
	if (do_after(H, 60, src))
		if (src && hanging)
			visible_message("<span class = 'danger'>[H] unties [hanging] from the post!</span>")
			hanging.pixel_x = 0
			hanging.pixel_y = 0
			hanging.anchored = 0
			hanging = null
			overlays.Cut()