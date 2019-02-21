/obj/structure/marketplace
	name = "global marketplace"
	desc = "Use this to sell and buy products on the global market."
	icon = 'icons/obj/structures.dmi'
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = FALSE


/obj/structure/marketplace/attack_hand(var/mob/living/carbon/human/user as mob)

/obj/structure/marketplace/attackby(var/obj/item/W, var/mob/user)
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/ST = W
		if (ST.amount == 0 || ST.value == 0)
			user << "This isn't worth anything."
		return