/obj/structure/barricade/wood_pole
	name = "wood pole"
	desc = "A simple wood pole. You can attach stuff to it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wood_pole_good"
	health = 50
	maxhealth = 50
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	var/attached = "none"
	var/obj/attached_ob = null
	flammable = TRUE
	protection_chance = 30

/obj/structure/barricade/wood_pole/New()
	..()
	name = "wood pole"
	desc = "A simple wood pole. You can attach stuff to it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wood_pole_good"

/obj/structure/grille/fence
	name = "fence"
	desc = "An old wooden fence."
	icon = 'icons/obj/fence.dmi'
	icon_state = "1"
	health = 16
	hitsound = 'sound/effects/wooddoorhit.ogg'
	flammable = TRUE

/obj/structure/grille/fence/New()
	..()
	icon_state = "[rand(1,3)]"
	color = "#c8c8c8"

/obj/structure/grille/fence/attackby(obj/O as obj, mob/user as mob)
	if (istype(O, /obj/item/weapon/leash))
		var/obj/item/weapon/leash/L = O
		if (L.onedefined == TRUE && (src in range(3,L.S1)))
			L.S2 = src
			L.S1.following_mob = src
			L.S1.stop_automated_movement = TRUE
			user << "You tie \the [L.S1] to \the [src] with the leash."
			qdel(L)
			return
	else
		..()

/obj/structure/barricade/wood_pole/attackby(obj/O as obj, mob/user as mob)
	if (istype(O, /obj/item/weapon/leash))
		var/obj/item/weapon/leash/L = O
		if (L.onedefined == TRUE && (src in range(3,L.S1)))
			L.S2 = src
			L.S1.following_mob = src
			L.S1.stop_automated_movement = TRUE
			user << "You tie \the [L.S1] to \the [src] with the leash."
			attached = "animal"
			qdel(L)
			return
	else if (istype(O, /obj/item/flashlight/lantern))
		var/obj/item/flashlight/lantern/LT = O
		user << "You tie \the [O] to \the [src]."
		LT.anchored = TRUE
		LT.on = TRUE
		LT.update_icon()
		LT.icon_state = "lantern-on_pole"
		LT.on_state = "lantern-on_pole"
		LT.off_state = "lantern_pole"
		attached_ob = O
		user.drop_from_inventory(O)
		O.forceMove(loc)
	else
		..()

/obj/structure/barricade/wood_pole/Destroy()
	..()
	if (attached_ob != null)
		if (istype(attached_ob, /obj/item/flashlight/lantern))
			var/obj/item/flashlight/lantern/LT = attached_ob
			LT.anchored = FALSE
			LT.icon_state = "lantern"
			LT.on = FALSE
			LT.on_state = "lantern-on"
			LT.off_state = "lantern"
			LT.update_icon()
			attached_ob = null

/obj/structure/grille/logfence
	name = "palisade"
	desc = "A wooden palisade."
	icon = 'icons/obj/structures.dmi'
	icon_state = "palisade"
	health = 32
	opacity = TRUE
	hitsound = 'sound/effects/wooddoorhit.ogg'
	flammable = TRUE

/obj/structure/grille/ironfence
	name = "iron fence"
	desc = "A wrought iron fence."
	icon = 'icons/obj/fence.dmi'
	icon_state = "iron_fence"
	health = 50
	hitsound = 'sound/weapons/blade_parry1.ogg'

/obj/structure/wallclock
	name = "wall clock"
	desc = "A classic wall clock."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wall_clock"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	anchored = TRUE
/obj/structure/props/junk
	name = "junk"
	desc = "A pile of junk."
	icon = 'icons/obj/junk.dmi'
	icon_state = "Junk_1"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE
/obj/structure/props/junk/New()
	..()
	icon_state = "Junk_[rand(1,14)]"

/obj/structure/props/stove
	name = "stove"
	desc = "A gas stove."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "stove"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE
/obj/structure/props/stove/old
	icon_state = "gasstove"

/obj/structure/props/bathtub
	name = "bathtub"
	desc = "A bathtub."
	icon = 'icons/obj/junk.dmi'
	icon_state = "bathtub"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE

/obj/structure/props/coatrack
	name = "coat rack"
	desc = "A coat rack."
	icon = 'icons/obj/junk.dmi'
	icon_state = "coatrack"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE

/obj/structure/props/sofa
	name = "sofa"
	desc = "A sofa."
	icon = 'icons/obj/junk.dmi'
	icon_state = "sofa"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE

/obj/structure/props/sofa/p2
	icon_state = "sofa2"

/obj/structure/props/sofa/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)//So bullets will fly over and stuff.
	if (istype(mover, /obj/item/projectile))
		return prob(75)
	else
		return FALSE

/obj/structure/props/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)//So bullets will fly over and stuff.
	if (istype(mover, /obj/item/projectile))
		return prob(50)
	else
		return FALSE


/obj/structure/potted_plant
	name = "potted plant"
	desc = "A potted plant."
	icon = 'icons/obj/structures.dmi'
	icon_state = "potted_plant"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/flag
	icon = 'icons/obj/flags.dmi'
	icon_state = "black"
	layer = MOB_LAYER + 0.01
	bound_width = 32
	bound_height = 32
	density = FALSE
	anchored = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE

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

/obj/structure/flag/french
	icon_state = "french"
	name = "French Flag"
	desc = "The French flag, white with golden fleur-de-lys"

/obj/structure/flag/spanish
	icon_state = "spanish"
	name = "Spanish Flag"
	desc = "The Spanish flag, white with a red cross of burgundy."

/obj/structure/flag/british
	icon_state = "british"
	name = "British Flag"
	desc = "The Union Jack."

/obj/structure/flag/portuguese
	icon_state = "portuguese"
	name = "Portuguese Flag"
	desc = "A white flag with the Portuguese Coat of Arms in the middle."

/obj/structure/flag/dutch
	icon_state = "dutch"
	name = "Dutch Flag"
	desc = "The tricolor Dutch flag."

/obj/structure/flag/japanese
	icon_state = "japanese"
	name = "Imperial Japanese Flag"
	desc = "The Imperial Japanese flag."

/obj/structure/flag/russian
	icon_state = "russian"
	name = "Russian Flag"
	desc = "The tricolor Russian flag."

/obj/structure/flag/russian
	icon_state = "russian"
	name = "Russian Flag"
	desc = "The tricolor Russian flag."

/obj/structure/flag/soviet
	icon_state = "soviet"
	name = "Soviet Union Flag"
	desc = "The Soviet flag."

/obj/structure/flag/us
	icon_state = "us"
	name = "USA Flag"
	desc = "The US flag."

/obj/structure/flag/reich
	icon_state = "reich"
	name = "Third Reich Flag"
	desc = "The Third Reich war flag."

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
		if (src)
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
			if (src)
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
