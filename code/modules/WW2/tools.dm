/*****************************Shovel********************************/

/obj/item/weapon/shovel
	name = "shovel"
	desc = "A large tool for digging and moving dirt."
	icon = 'icons/obj/items.dmi'
	icon_state = "shovel"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	force = 8.0
	throwforce = 4.0
	item_state = "shovel"
	w_class = 3.0
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("bashed", "bludgeoned", "thrashed", "whacked")
	sharp = FALSE
	edge = TRUE
	slot_flags = SLOT_BACK|SLOT_BELT

/obj/item/weapon/shovel/spade
	name = "spade"
	desc = "A small tool for digging and moving dirt."
	icon_state = "spade"
	item_state = "spade"
	force = 15.0
	throwforce = 20.0
	w_class = 2.0
	weight = 1.18

/obj/item/weapon/shovel/spade/foldable
	name = "foldable shovel"
	icon_state = "german_shovel2"
	item_state = "lopata"

/obj/item/weapon/shovel/spade/small
	name = "small shovel"
	icon_state = "lopata"
	item_state = "lopata"

/obj/item/weapon/wirecutters/boltcutters
	name = "boltcutters"
	desc = "This cuts bolts and other things."
	icon_state = "boltcutters"

/obj/item/weapon/crowbar/prybar
	name = "prybar"
	icon_state = "prybar"


/obj/item/weapon/shovel/attack_self(mob/user)
	var/turf/floor/TB = get_turf(user)
	if ((TB.is_diggable) && !(locate(/obj/structure/multiz/) in user.loc))
		var/digging_tunnel_time = 200
		if (ishuman(user))
			var/mob/living/carbon/human/H = user
			digging_tunnel_time /= H.getStatCoeff("strength")
			digging_tunnel_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
		if (WWinput(user, "This will start digging a tunnel entrance here.", "Tunnel Digging", "Continue", list("Continue", "Stop")) == "Continue")
			visible_message("<span class='danger'>[user] starts digging a tunnel entrance!</span>", "<span class='danger'>You start digging a tunnel entrance.</span>")
			if (do_after(user, digging_tunnel_time, user.loc))
				new/obj/structure/multiz/ladder/ww2/tunneltop(user.loc)
				var/obj/structure/multiz/ladder/ww2/tunnelbottom/bottomS = new/obj/structure/multiz/ladder/ww2/tunnelbottom(user.loc)
				bottomS.z = bottomS.z-1
				visible_message("<span class='danger'>[user] finishes digging the tunnel entrance.</span>")
				if (ishuman(user))
					var/mob/living/carbon/human/H = user
					H.adaptStat("crafting", 1)
					H.adaptStat("strength", 1)
			return
	else if (locate(/obj/structure/multiz/) in user.loc)
		user << "<span class='warning'>There already is something here.</span>"
		return
	else if (!TB.is_diggable)
		user << "<span class='warning'>You cannot dig a hole here!</span>"
		return