/obj/structure/sign
	icon = 'icons/obj/decals.dmi'
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	layer = 3.5
	w_class = 3

/obj/structure/sign/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			qdel(src)
			return
		if (3.0)
			qdel(src)
			return
		else
	return

/obj/structure/sign/attackby(obj/item/tool as obj, mob/user as mob)	//deconstruction
	if (istype(tool, /obj/item/weapon/hammer))
		var/obj/item/sign/S = new(loc)
		S.name = name
		S.desc = desc
		S.icon_state = icon_state
		//var/icon/I = icon('icons/obj/decals.dmi', icon_state)
		//S.icon = I.Scale(24, 24)
		S.sign_state = icon_state
		user << "You unfasten \the [S] with your [tool]."
		qdel(src)
	else ..()

/obj/item/sign
	name = "sign"
	desc = ""
	icon = 'icons/obj/decals.dmi'
	w_class = 3		//big
	var/sign_state = ""
	value = 0
/obj/item/sign/attackby(obj/item/tool as obj, mob/user as mob)	//construction
	if (istype(tool, /obj/item/weapon/hammer) && isturf(user.loc))
		var/direction = WWinput(user, "Fasten it to which direction?", "Select a direction.", "North", WWinput_list_or_null(list("North", "East", "South", "West")))
		if (direction)
			var/obj/structure/sign/S = new(user.loc)
			switch(direction)
				if ("North")
					S.pixel_y = 32
				if ("East")
					S.pixel_x = 32
				if ("South")
					S.pixel_y = -32
				if ("West")
					S.pixel_x = -32
				else return
			S.name = name
			S.desc = desc
			S.icon_state = sign_state
			user << "You fasten \the [S] with your [tool]."
			qdel(src)
	else ..()

/obj/structure/sign/securearea
	name = "\improper SECURE AREA"
	desc = "A warning sign which reads 'SECURE AREA'."
	icon_state = "securearea"

/obj/structure/sign/redcross
	name = "medbay"
	desc = "The Intergalactic symbol of Medical institutions. You'll probably get help here."
	icon_state = "redcross"

/obj/structure/sign/greencross
	name = "medbay"
	desc = "The Intergalactic symbol of Medical institutions. You'll probably get help here."
	icon_state = "greencross"

/obj/structure/sign/goldenplaque
	name = "The Most Robust Men Award for Robustness"
	desc = "To be Robust is not an action or a way of life, but a mental state. Only those with the force of Will strong enough to act during a crisis, saving friend from foe, are truly Robust. Stay Robust my friends."
	icon_state = "goldenplaque"

/obj/structure/sign/kiddieplaque
	name = "\improper AI developers plaque"
	desc = "Next to the extremely long list of names and job titles, there is a drawing of a little child. The child appears to be retarded. Beneath the image, someone has scratched the word \"PACKETS\""
	icon_state = "kiddieplaque"

/obj/structure/sign/exit
	name = "Exit"
	desc = "Points to the exit."
	icon_state = "exit"

/obj/structure/sign/minefield
	name = "Minefield"
	desc = "Achtung! Minen."
	icon_state = "minefield"

/obj/structure/sign/exit/New()
	..()
	if (dir == WEST)
		desc = "Exit to the left."
	else if (dir == EAST)
		desc = "Exit to the right."
	else if (dir == NORTH)
		desc = "Exit to the north."
	else if (dir == SOUTH)
		desc = "Exit to the south."

/obj/structure/sign/custom
	name = "Sign"
	desc = "Signs something."
	icon_state = "woodsign2"

//numbers
/obj/structure/sign/n1
	desc = "A silver sign which reads 'I'."
	name = "ONE"
	icon_state = "n1"
/obj/structure/sign/n2
	desc = "A silver sign which reads 'II'."
	name = "TWO"
	icon_state = "n2"
/obj/structure/sign/n3
	desc = "A silver sign which reads 'III'."
	name = "THREE"
	icon_state = "n3"
/obj/structure/sign/n4
	desc = "A silver sign which reads 'IV'."
	name = "FOUR"
	icon_state = "n4"
/obj/structure/sign/n5
	desc = "A silver sign which reads 'V'."
	name = "FIVE"
	icon_state = "n5"
/obj/structure/sign/n6
	desc = "A silver sign which reads 'VI'."
	name = "SIX"
	icon_state = "n6"

/obj/structure/sign/torii
	desc = "A tall red gate structure."
	name = "torii gate"
	icon_state = "torii"
	icon = 'icons/turf/64x64.dmi'

/obj/structure/sign/painting1
	desc = "A large foamy wave crashes into the rocky shore. A bit of sunlight passes through the clouds, glistening on the sea surface and wet boulders."
	name = "painting"
	icon_state = "painting1"

/obj/structure/sign/painting2
	desc = "A serene city street with a few people on a summer day. Two- and three-storey houses stand to the left and right, separated by a cobblestone road. A massive building with spires could be seen in the distance."
	name = "painting"
	icon_state = "painting2"

/obj/structure/sign/painting3
	desc = "A blazing sunset seen from a steep cliff above the sea."
	name = "painting"
	icon_state = "painting3"

/obj/structure/sign/painting4
	desc = "A wooded mountain valley with a small pond at the clearing, where a group of horsemen could be seen. The mountains themselves loom farther ahead, obscured by a thin haze."
	name = "painting"
	icon_state = "painting4"

/obj/structure/sign/painting5
	desc = "A still life painting, depicting a table with a piece of white cloth, several fruits and a human skull."
	name = "painting"
	icon_state = "painting5"

/obj/structure/sign/painting6
	desc = "A long-tailed bird with black, olive green and white plumage, resembling a magpie, perches on a tree branch, surrounded by white cherry blossoms."
	name = "painting"
	icon_state = "painting6"

/obj/structure/sign/painting7
	desc = "A lone figure with a carrying pole on their shoulders stands under a tall pine on the sloping shore, gazing at the snow-peaked mountain across the strait. The sky is colored dark orange by the setting sun."
	name = "painting"
	icon_state = "painting7"

/obj/structure/sign/painting8
	desc = "A hilly landscape, where a large temple with red timber beams and sweeping roofs stands on the bank of a river."
	name = "painting"
	icon_state = "painting8"

/obj/structure/sign/painting9
	desc = "A small encampment in the desert, with a few tents, several horses and loaded camels. A faraway river crosses the expanse of barren dunes."
	name = "painting"
	icon_state = "painting9"

/obj/structure/sign/painting10
	desc = "A barque at sea, lit by the full moon."
	name = "painting"
	icon_state = "painting10"
