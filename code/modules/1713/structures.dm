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
/obj/structure/barricade/wood_pole/attack_hand(mob/living/user as mob)
	if (!isliving(user))
		return
	if (attached_ob && istype(attached_ob, /obj/item/flashlight/lantern))
		user << "You remove \the [attached_ob] from \the [src]."
		var/obj/item/flashlight/lantern/O = attached_ob
		O.anchored = FALSE
		O.forceMove(user.loc)
		user.put_in_hands(O)
		attached_ob = null
		return
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
	name = "standing clock"
	desc = "A classic standing clock."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wall_clock"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	anchored = TRUE
/obj/structure/wallclock/examine(mob/user)
	..()
	user << "<big>It is now [clock_time()].</big>"

/obj/structure/props/junk
	name = "junk"
	desc = "A pile of junk."
	icon = 'icons/obj/junk.dmi'
	icon_state = "Junk_1"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = TRUE
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
	icon_state = "sofa_forward_left"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE

/obj/structure/props/sofa/p2
	icon_state = "sofa_forward_right"

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

/obj/structure/props/hookah
	name = "hookah"
	desc = "A glass pipe used to smoke tobacco or other substances."
	icon = 'icons/obj/items.dmi'
	icon_state = "hookah1"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE

/obj/structre/props/hookah/New()
	..()
	var/pickhookah = pick("hookah1", "hookah2", "hookah3")
	icon_state = pickhookah

/obj/structure/broken_hind
	name = "Mi-24 remains"
	desc = "The remains of a Soviet helicopter."
	icon = 'icons/obj/decals_huge.dmi'
	icon_state = "brokenhind"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	anchored = TRUE
	density = TRUE
	layer = MOB_LAYER + 0.01
	bound_width = 128
	bound_height = 128
	bound_x = 32

/obj/structure/props/marketstall
	name = "market stall"
	desc = "A market stall."
	icon = 'icons/obj/structures.dmi'
	icon_state = "propstall1"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	density = TRUE
	opacity = TRUE
	anchored = TRUE
	New()
		..()
		icon_state ="propstall[rand(1,4)]"

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
	desc = "The French flag, white with golden fleur-de-lys."

/obj/structure/flag/french_modern
	icon_state = "french2"
	name = "French Flag"
	desc = "The modern french tricoleur."

/obj/structure/flag/french_monarchist
	icon_state = "french3"
	name = "French Flag"
	desc = "The french monarchist flag."


/obj/structure/flag/spanish
	icon_state = "spanish"
	name = "Spanish Flag"
	desc = "The Spanish flag, white with a red cross of burgundy."

/obj/structure/flag/spanish_modern
	icon_state = "spanish2"
	name = "Spanish Flag"
	desc = "The modern yellow and red spanish flag."

/obj/structure/flag/italian
	icon_state = "italian"
	name = "Italian Flag"
	desc = "The modern italian flag."

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

/obj/structure/flag/german_modern
	icon_state = "german2"
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

/obj/structure/flag/filipino
	icon_state = "filipino"
	name = "Philippines Republic"
	desc = "The Republic of the Philippines flag."

/obj/structure/flag/filipino_war
	icon_state = "filipino_wartime"
	name = "Philippines Republic"
	desc = "The Republic of the Philippines flag. This one flipped for wartime."

/obj/structure/flag/nva
	icon_state = "nva"
	name = "North Vietnam Flag"
	desc = "The flag of North Vietnam."

/obj/structure/flag/vietcong
	icon_state = "vietcong"
	name = "Vietcong Flag"
	desc = "The flag of the National Liberation Front of Vietnam."

/obj/structure/flag/redmenia
	icon_state = "redmenia"
	name = "Redmenia Flag"
	desc = "The flag of Redmenia."

/obj/structure/flag/blugoslavia
	icon_state = "blugoslavia"
	name = "Blugoslavia Flag"
	desc = "The flag of Blugoslavia."

/obj/structure/flag/pole
	icon_state = "flagpole_blank"
	name = "Flagpole"
	desc = "Flagless, apply cloth or a flag."

/obj/structure/flag/pole/attackby(obj/item/W as obj, var/mob/living/human/H)
	if(istype(W, /obj/item/stack/material/cloth))
		if(W.amount >= 5)
			W.amount -= 5
			new /obj/structure/flag/pole/custom(src.loc)
			if(W.amount <= 0)
				qdel(W)
			qdel(src)
		else
			H << "You need atleast five cloth to do that!"
	else if(istype(W, /obj/item/flagmaker))
		new /obj/structure/flag/pole/custom(src.loc)
		qdel(src)
	else
		..()
	..()
/obj/structure/flag/pole/custom
	icon_state = "cust_flag"
	name = "Flag"
	desc = "A flag."
	var/uncolored = TRUE
	var/flagcolor = null
	var/symbol = "Moon"
	var/symbolcolor = null


/obj/structure/flag/pole/custom/attackby(obj/item/W as obj, var/mob/living/human/H)
	if(istype(W, /obj/item/weapon))
		if(W.sharp)
			H << "You tear down the flag!"
			new/obj/structure/flag/pole(src.loc)
			qdel(src)
/obj/structure/flag/pole/custom/attack_hand(var/mob/living/human/H)
	if (uncolored)
		var/input = WWinput(H, "Flag Color - Choose a color:", "Flag Color" , "#FFFFFF", "color")
		if (input == null || input == "")
			return
		else

			flagcolor= input
	if (!symbol)
		var/display = list("Moon", "Cross", "Star", "Sun", "Plus", "Saltire", "None", "Cancel")
		var/input =  WWinput(H, "What symbol would you like?", "Flag Making", "Cancel", display)
		playsound(src.loc,'sound/items/ratchet.ogg',40) //rip_pack.ogg
		if (input == "Cancel")
			return
		else if(input == "Moon")
			symbol = "cust_f_moon"
		else if(input == "Cross")
			symbol = "cust_f_cross"
		else if(input == "Star")
			symbol = "cust_f_star"
		else if(input == "Sun")
			symbol = "cust_f_sun"
		else if(input == "Plus")
			symbol = "cust_f_plus"
		else if(input == "Saltire")
			symbol = "cust_f_saltire"
		else if(input == "None")
			symbol = "cust_f_blank"
		else
			H << "<span class='notice'>That does not exist!</span>"
	if (!symbolcolor)
		var/input = WWinput(H, "Symbol Color - Choose a color:", "Symbol Color" , "#000000", "color")
		if (input == null || input == "")
			return
		else

			symbolcolor= input
	if (flagcolor && symbol && symbolcolor)
		uncolored = FALSE
		var/image/flag = image("icon" = 'icons/obj/flags.dmi', "icon_state" = "cust_flag_cloth")
		flag.color = flagcolor
		var/image/border = image("icon" = 'icons/obj/flags.dmi', "icon_state" = "cust_flag_outline")
		var/image/csymbol = image("icon" = 'icons/obj/flags.dmi', "icon_state" = symbol)
		csymbol.color = symbolcolor
		overlays += flag
		overlays += border
		overlays += csymbol
		return
	else
		..()
	..()

/obj/structure/wallframe
	name = "wall frame"
	desc = "A wooden wall frame, add something like paper, bamboo bundles or wood to it.."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wall_frame"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	anchored = TRUE
	density = FALSE
	opacity = FALSE

/obj/structure/wallframe/attackby(obj/item/W as obj, var/mob/living/human/H)
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
	else if(istype(W, /obj/item/stack/material/bamboo))
		var/input = WWinput(H, "What wall would you like to make?", "Building", "Cancel",list ("Bamboo Wall - 3", "Bamboo Doorway - 2", "Bamboo Window - 2", "Cancel"))
		if (input == "Cancel")
			return
		if(input == "Bamboo Wall - 3")
			if(W.amount >= 3)
				if (do_after(H, 40, src))
					new/obj/covers/wood_wall/bamboo(src.loc)
					qdel(src)
					W.amount -= 3
		else if(input == "Bamboo Doorway - 2")
			if(W.amount >= 2)
				if (do_after(H, 40, src))
					var/obj/covers/wood_wall/bamboo/S = new /obj/covers/wood_wall/bamboo(loc)
					S.icon_state = "bamboo-door"
					S.name = "bamboo doorway"
					S.desc = "A doorway made from bamboo."
					S.density = FALSE
					S.opacity = FALSE
					qdel(src)
					W.amount -= 2
		else if(input == "Bamboo Window - 2")
			if(W.amount >= 2)
				if (do_after(H, 40, src))
					new/obj/structure/window_frame/bamboo(src.loc)
					qdel(src)
					W.amount -= 2
		else
			H << "<span class='notice'>That does not exist!</span>"

/* Bamboo Wall-Frame*/

/obj/structure/wallframe/bamboo
	name = "bamboo wall frame"
	desc = "A bamboo wall frame, add something like paper, bamboo bundles or wood to it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wall_frame_bamboo"

/obj/structure/wallframe/bamboo/attackby(obj/item/W as obj, var/mob/living/human/H)
	if(istype(W, /obj/item/stack/material/wood))
		var/input
		var/display = list("Oriental Window - 4", "Oriental Wall - 6","Oriental Braced Wall (--) - 6", "Oriental Doorway - 6", "Oriental Two Panelled Wall (|) - 6", "Oriental Two Panelled Braced Wall (-|-)", "Oriental Three Panelled Wall (||) - 6",  "Oriental Three Panelled Braced Wall (-|-|-) - 6", "Cancel")
		input =  WWinput(H, "What wall would you like to make?", "Building", "Cancel", display)
		playsound(src.loc,'sound/items/ratchet.ogg',40) //rip_pack.ogg
		if (input == "Cancel")
			return
		else if(input == "Oriental Window - 4")
			if(W.amount >= 4)
				if (do_after(H, 40, src))
					new/obj/structure/window_frame/oriental(src.loc)
					qdel(src)
					W.amount -= 4
		else if(input == "Oriental Wall - 6")
			if(W.amount >= 6)
				if (do_after(H, 41, src))
					new/obj/covers/wood_wall/oriental(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Braced Wall (--) - 6")
			if(W.amount >= 6)
				if (do_after(H, 43, src))
					new/obj/covers/wood_wall/oriental/b(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Doorway - 6")
			if(W.amount >= 6)
				if (do_after(H, 40, src))
					var/obj/covers/wood_wall/oriental/S = new /obj/covers/wood_wall/oriental(loc)
					S.icon_state = "oriental-door"
					S.name = "oriental doorway"
					S.desc = "A east-oriental style doorway."
					S.density = FALSE
					S.opacity = FALSE
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Two Panelled Wall (|) - 6")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/oriental/twop(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Two Panelled Braced Wall (-|-)")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/oriental/twop/b(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Three Panelled Wall (||) - 6")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/oriental/threep(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Three Panelled Braced Wall (-|-|-) - 6")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/oriental/threep/b(src.loc)
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
	else if(istype(W, /obj/item/stack/material/bamboo))
		var/input = WWinput(H, "What wall would you like to make?", "Building", "Cancel",list ("Bamboo Wall - 3", "Bamboo Doorway - 2", "Bamboo Window - 2", "Cancel"))
		if (input == "Cancel")
			return
		if(input == "Bamboo Wall - 3")
			if(W.amount >= 3)
				if (do_after(H, 40, src))
					new/obj/covers/wood_wall/bamboo(src.loc)
					qdel(src)
					W.amount -= 3
		else if(input == "Bamboo Doorway - 2")
			if(W.amount >= 2)
				if (do_after(H, 40, src))
					var/obj/covers/wood_wall/bamboo/S = new /obj/covers/wood_wall/bamboo(loc)
					S.icon_state = "bamboo-door"
					S.name = "bamboo doorway"
					S.desc = "A doorway made from bamboo."
					S.density = FALSE
					S.opacity = FALSE
					qdel(src)
					W.amount -= 2
		else if(input == "Bamboo Window - 2")
			if(W.amount >= 2)
				if (do_after(H, 40, src))
					new/obj/structure/window_frame/bamboo(src.loc)
					qdel(src)
					W.amount -= 2
		else
			H << "<span class='notice'>That does not exist!</span>"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////SHIP////////////////////////////////////////////////////////////////////////////////////////////////////////
/obj/structure/ship_bow
	name = "bowstir"
	desc = "A large bow mast, for the front of a ship."
	icon = 'icons/obj/vehicles/bow.dmi'
	icon_state = "bowstir"
	layer = 5
	density = FALSE
	anchored = TRUE


//////////////////////////////////////////////////////////////////////////////
//////////////////////TORCH STAND/////////////////////////////////////////////
/obj/structure/torch_stand
	name = "torch mount"
	desc = "A mount to affix torches or lanterns to the wall"
	icon = 'icons/obj/structures.dmi'
	icon_state = "torch_stand"
	item_state = "torch_stand"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	var/obj/item/weapon/storage/internal/storage
	var/max_storage = 3
	var/brightness_on = 5 //luminosity when on

/obj/structure/torch_stand/update_icon()
	if (dir == 1)
		pixel_y = 32
	else
		pixel_y = 0
	if (storage.contents.len > 0)
		for (var/obj/item/flashlight/torch/TOR in src.storage.contents)
			if (TOR.on == TRUE)
				icon_state = "torch_stand1_on"
				set_light(1)
				light_color = "#FCDA7C"
				light_range = 4
				return
			else
				icon_state = "torch_stand1"
				set_light(0)
				light_color = null
				light_range = 0
				return
		for (var/obj/item/flashlight/lantern/LAN in src.storage.contents)
			if (LAN.on == TRUE)
				icon_state = "torch_stand_lantern_on"
				set_light(1)
				light_color = "#FCDA7C"
				light_range = 6
				return
			else
				icon_state = "torch_stand_lantern"
				set_light(0)
				return

	else
		icon_state = "torch_stand"

/obj/structure/torch_stand/New()
	..()
	storage = new/obj/item/weapon/storage/internal(src)
	storage.storage_slots = 1
	storage.max_w_class = 2
	storage.max_storage_space = max_storage*3
	storage.can_hold = list(/obj/item/flashlight/torch, /obj/item/flashlight/lantern)
	update_icon()

/obj/structure/torch_stand/Destroy()
	qdel(storage)
	storage = null
	..()

/obj/structure/torch_stand/attack_hand(mob/user as mob)
	if (istype(user, /mob/living/human) && user in range(1,src))
		storage.open(user)
		update_icon()
	else
		return

/obj/structure/torch_stand/MouseDrop(obj/over_object as obj)
	if (storage.handle_mousedrop(usr, over_object))
		..(over_object)
		update_icon()

/obj/structure/torch_stand/attackby(obj/item/W as obj, mob/user as mob)
	..()
	storage.attackby(W, user)
	update_icon()

/obj/structure/torch_stand/full

/obj/structure/torch_stand/full/New()
	..()
	new /obj/item/flashlight/torch/on(src.storage)
	update_icon()

//////////////////////////CAMONET/////////////////////////////////

/obj/structure/camonet
	name ="camonet"
	icon = 'icons/obj/structures.dmi'
	icon_state ="camonet"
	layer = MOB_LAYER + 8
	alpha = 175
	density = FALSE
	anchored = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	mouse_opacity = FALSE