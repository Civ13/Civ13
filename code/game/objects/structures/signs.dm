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
		user << "You unfasten the sign with your [tool]."
		var/obj/item/sign/S = new(loc)
		S.name = name
		S.desc = desc
		S.icon_state = icon_state
		//var/icon/I = icon('icons/obj/decals.dmi', icon_state)
		//S.icon = I.Scale(24, 24)
		S.sign_state = icon_state
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