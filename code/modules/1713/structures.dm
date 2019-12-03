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

/obj/structure/grille/fence/picket
	name = "picket fence"
	desc = "A traditional wooden fence."
	icon = 'icons/obj/fence.dmi'
	icon_state = "p1"
	health = 30
	hitsound = 'sound/effects/wooddoorhit.ogg'
	flammable = TRUE

/obj/structure/grille/fence/picket/New()
	..()
	icon_state = "p[rand(1,3)]"
	color = "#c8c8c8"

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
	..()
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

/obj/structure/grille/chainlinkfence
	name = "chain-link fence"
	desc = "A woven steel fence."
	icon = 'icons/obj/fence.dmi'
	icon_state = "chainlinkfence"
	health = 80
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

/obj/structure/flag/german
	icon_state = "german"
	name = "German Flag"
	desc = "The German flag."

/obj/structure/flag/confed
	icon_state = "confed"
	name = "Confederate flag"
	desc = "The Confederate flag"

/obj/structure/flag/reich
	icon_state = "reich"
	name = "Third Reich Flag"
	desc = "The Third Reich war flag."

/obj/structure/flag/chinese
	icon_state = "chinese"
	name = "Republic of China Flag"
	desc = "The Republic of China flag."

/obj/structure/wallframe
	name = "wall frame"
	desc = "A wooden wall frame, add something like paper or wood to it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wall_frame"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	anchored = TRUE
	density = FALSE
	opacity = FALSE

/obj/structure/wallframe/attackby(obj/item/W as obj, var/mob/living/carbon/human/H)
	if(istype(W, /obj/item/stack/material/wood))
		var/input
		var/display = list("Medieval Window - 4", "Medieval Wall - 6", "Medieval Crossbraced Wall (X) - 6", "Medieval Braced Wall (\\) - 6", "Medieval Braced Wall (/) - 6", "Cancel")
		input =  WWinput(H, "What wall would you like to make?", "Building", "Cancel", display)
		playsound(src.loc,'sound/items/ratchet.ogg',40) //rip_pack.ogg
		if (input == "Cancel")
			return
		else if(input == "Medieval Window - 4")
			if(W.amount >= 4)
				if (do_after(H, 40, src))
					new/obj/structure/window_frame/medieval(src.loc)
					qdel(src)
					W.amount -= 4
		else if(input == "Medieval Wall - 6")
			if(W.amount >= 6)
				if (do_after(H, 41, src))
					new/obj/covers/wood_wall/medieval(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Medieval Crossbraced Wall (X) - 6")
			if(W.amount >= 6)
				if (do_after(H, 43, src))
					new/obj/covers/wood_wall/medieval/x(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Medieval Braced Wall (\\) - 6")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/medieval/y/r(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Medieval Braced Wall (/) - 6")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/medieval/y/l(src.loc)
					qdel(src)
					W.amount -= 6
		else
			H << "<span class='notice'>That does not exist!</span>"
	else if(istype(W, /obj/item/weapon/paper))
		var/input
		var/display = list("Shoji Door - 1", "Shoji Wall - 1", "Shoji Divider - 1", "Shoji Window - 1", "Cancel")
		input =  WWinput(H, "What wall would you like to make?", "Building", "Cancel", display)
		playsound(src.loc,'sound/effects/rip_pack.ogg',40)
		if (input == "Cancel")
			return
		else if(input == "Shoji Door - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/structure/simple_door/key_door/anyone/shoji(src.loc)
					qdel(src)
					qdel(W)
		else if(input == "Shoji Wall - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/covers/wood_wall/shoji(src.loc)
					qdel(src)
					qdel(W)
		else if(input == "Shoji Divider - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/covers/wood_wall/shoji_divider(src.loc)
					qdel(src)
					qdel(W)
		else if(input == "Shoji Window - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/structure/window_frame/shoji(src.loc)
					qdel(src)
					qdel(W)
		else
			H << "<span class='notice'>That does not exist!</span>"
	else
		..()