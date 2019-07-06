/*****************************Shovel********************************/
/obj/item/weapon/plough
	name = "plough"
	desc = "A simple wood plough. Use it on dirt to create farming areas."
	icon = 'icons/obj/items.dmi'
	icon_state = "plough"
	flags = CONDUCT
	force = 4.0
	throwforce = 3.0
	item_state = "plough"
	w_class = 3.0
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	slot_flags = SLOT_BELT
	flammable = TRUE

/obj/item/weapon/shovel
	name = "shovel"
	desc = "A large tool for digging and moving dirt."
	icon = 'icons/obj/items.dmi'
	icon_state = "shovel"
	flags = CONDUCT
	force = 8.0
	throwforce = 4.0
	item_state = "shovel"
	w_class = 3.0
	matter = list(DEFAULT_WALL_MATERIAL = 50)
	attack_verb = list("bashed", "bludgeoned", "thrashed", "whacked")
	sharp = FALSE
	edge = TRUE
	slot_flags = SLOT_BACK|SLOT_BELT

/obj/item/weapon/shovel/bone
	name = "bone shovel"
	icon_state = "shovel_bone"

/obj/item/weapon/shovel/trench
	name = "Entrenching Tool"
	desc = "A shovel used specifically for digging trenches."
	icon_state = "german_shovel2"
	var/dig_speed = 7

/obj/item/weapon/pickaxe
	name = "pickaxe"
	desc = "Miner's favorite."
	icon = 'icons/obj/items.dmi'
	icon_state = "pickaxe"
	force = 9.0
	flags = CONDUCT
	throwforce = 4.0
	w_class = 3.0
	item_state = "pickaxe"
	attack_verb = list("bashed", "bludgeoned", "thrashed", "whacked")
	sharp = FALSE
	edge = TRUE
	slot_flags = SLOT_BACK|SLOT_BELT

/obj/item/weapon/pickaxe/bone
	name = "bone pickaxe"
	icon_state = "pickaxe_bone"

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
	var/display = list("Tunnel", "Grave", "Pit Latrine","Cancel")
	var/input =  WWinput(user, "What do you want to dig?", "Digging", "Cancel", display)
	if (input == "Cancel")
		return
	else if (input == "Tunnel")
		if ((TB.is_diggable) && !(locate(/obj/structure/multiz/) in user.loc))
			if (user.z < 2)
				user << "<span class='notice'>You can't dig a tunnel here, the bedrock is right below.</span>"
			else
				var/digging_tunnel_time = 200
				if (ishuman(user))
					var/mob/living/carbon/human/H = user
					digging_tunnel_time /= H.getStatCoeff("strength")
					digging_tunnel_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
				visible_message("<span class='danger'>[user] starts digging a tunnel entrance!</span>", "<span class='danger'>You start digging a tunnel entrance.</span>")
				if (do_after(user, digging_tunnel_time, user.loc))
					if (!TB.is_diggable)
						return
					new/obj/structure/multiz/ladder/ww2/tunneltop(user.loc)
					new/obj/structure/multiz/ladder/ww2/tunnelbottom(locate(user.x, user.y, user.z-1))
					var/turf/BL = get_turf(locate(user.x, user.y, user.z-1))
					if (istype(BL, /turf/floor/dirt/underground))
						BL.ChangeTurf(/turf/floor/dirt)
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
	else if  (input == "Grave")
		if (istype(TB, /turf/open) || istype(TB, /turf/wall) || istype(TB, /turf/floor/wood) || istype(TB, /turf/floor/wood_broken) || istype(TB, /turf/floor/ship) || istype(TB, /turf/floor/carpet) || istype(TB, /turf/floor/broken_floor) || istype(TB, /turf/floor/plating/cobblestone) || istype(TB, /turf/floor/plating/concrete) || istype(TB, /turf/floor/plating/stone_old))
			return
		else
			if (locate(/obj/structure/multiz) in user.loc)
				user << "<span class='notice'>There is a tunnel entrance here!</span>"
				return
			visible_message("[user] starts digging up a grave...","You start digging up a grave...")
			playsound(src,'sound/effects/shovelling.ogg',100,1)
			if (do_after(user, 100, src))
				user << "You finish digging the grave."
				new/obj/structure/religious/grave(user.loc)
				return
			else
				return
	else if  (input == "Pit Latrine")
		if (istype(TB, /turf/open) || istype(TB, /turf/wall) || istype(TB, /turf/floor/wood) || istype(TB, /turf/floor/wood_broken) || istype(TB, /turf/floor/ship) || istype(TB, /turf/floor/carpet) || istype(TB, /turf/floor/broken_floor) || istype(TB, /turf/floor/plating/cobblestone) || istype(TB, /turf/floor/plating/concrete) || istype(TB, /turf/floor/plating/stone_old))
			return
		else
			if (locate(/obj/structure/multiz) in user.loc)
				user << "<span class='notice'>There is a tunnel entrance here!</span>"
				return
			visible_message("[user] starts digging up a pit latrine...","You start digging up a pit latrine...")
			playsound(src,'sound/effects/shovelling.ogg',100,1)
			if (do_after(user, 150, src))
				user << "You finish digging the pit latrine."
				new/obj/structure/toilet/pit_latrine(user.loc)
				return
			else
				return