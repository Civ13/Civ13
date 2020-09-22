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

	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	slot_flags = SLOT_BELT
	flammable = TRUE
	var/usespeed = 1

/obj/item/weapon/plough/attack_self(var/mob/living/L)
	var/turf/T = get_turf(L)
	T.attackby(src,L)
	return

/obj/item/weapon/plough/iron
	name = "iron plough"
	desc = "A sturdy iron plough, use it on dirt to plough the land."
	icon = 'icons/obj/items.dmi'
	icon_state = "iplough"
	item_state = "iplough"
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = TRUE
	usespeed = 1.3

/obj/item/weapon/material/shovel
	name = "shovel"
	desc = "A large tool for digging and moving dirt."
	icon = 'icons/obj/items.dmi'
	icon_state = "shovel"
	flags = CONDUCT
	force = 8.0
	throwforce = 4.0
	item_state = "shovel"
	w_class = 3.0

	attack_verb = list("bashed", "bludgeoned", "thrashed", "whacked")
	sharp = FALSE
	edge = TRUE
	slot_flags = SLOT_BACK|SLOT_BELT
	var/usespeed = 1.2
	default_material = "iron"
	force_divisor = 0.25
	thrown_force_divisor = 0.15

/obj/item/weapon/material/shovel/bone
	name = "bone shovel"
	icon_state = "shovel_bone"
	usespeed = 1
	default_material = "bone"

/obj/item/weapon/material/shovel/trench
	name = "Entrenching Tool"
	desc = "A shovel used specifically for digging trenches."
	icon_state = "german_shovel2"
	var/dig_speed = 7
	usespeed = 0.8

/obj/item/weapon/material/pickaxe/jackhammer
	name = "jackhammer"
	desc = "An effecient mining tool."
	icon = 'icons/obj/items.dmi'
	icon_state = "jackhammer"
	force = 12.0
	flags = CONDUCT
	throwforce = 1.0
	w_class = 6.0
	item_state = "jackhammer"
	attack_verb = list("drilled", "bludgeoned", "stabbed", "whacked")
	sharp = FALSE
	edge = TRUE
	slot_flags = SLOT_BACK
	usespeed = 1.4

//Needs two hands to use.
/obj/item/weapon/material/pickaxe/jackhammer/proc/special_check(mob/user)
	if (!(user.has_empty_hand(both = FALSE)))
		user << "<span class='warning'>You need both hands to use the [src]!</span>"
		return FALSE
	..()

/obj/item/weapon/material/pickaxe
	name = "pickaxe"
	desc = "Miner's favorite."
	icon = 'icons/obj/items.dmi'
	icon_state = "pickaxe"
	flags = CONDUCT
	w_class = 3.0
	item_state = "pickaxe"
	attack_verb = list("bashed", "bludgeoned", "thrashed", "whacked")
	sharp = FALSE
	edge = TRUE
	slot_flags = SLOT_BACK|SLOT_BELT
	default_material = "iron"
	var/usespeed = 1.2
	force_divisor = 0.35
	thrown_force_divisor = 0.25

/obj/item/weapon/material/pickaxe/bone
	name = "bone pickaxe"
	icon_state = "pickaxe_bone"
	usespeed = 1
	default_material = "bone"

/obj/item/weapon/material/pickaxe/stone
	name = "stone pickaxe"
	usespeed = 1.1
	icon_state = "spick"
	default_material = "stone"

/obj/item/weapon/material/shovel/spade
	name = "spade"
	desc = "A small tool for digging and moving dirt."
	icon_state = "spade"
	item_state = "spade"
	force = 15.0
	throwforce = 20.0
	w_class = 2.0
	weight = 1.18
	usespeed = 0.8

/obj/item/weapon/material/shovel/spade/foldable
	name = "foldable shovel"
	icon_state = "german_shovel2"
	item_state = "lopata"
	usespeed = 0.7

/obj/item/weapon/material/shovel/spade/small
	name = "small shovel"
	icon_state = "lopata"
	item_state = "lopata"
	usespeed = 0.7

/obj/item/weapon/wirecutters/boltcutters
	name = "boltcutters"
	desc = "This cuts bolts and other things."
	icon_state = "boltcutters"

/obj/item/weapon/crowbar/prybar
	name = "prybar"
	icon_state = "prybar"

/obj/item/weapon/berriesgatherer
	name = "berries gatherer"
	desc = "A simple berry gatherer. Use it on berry bushes to efficiently gather berries."
	icon = 'icons/obj/flora/berries.dmi'
	icon_state = "berriesgatherer"
	force = 2.0
	throwforce = 1.0
	item_state = "berriesgatherer"
	w_class = 1.0
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	flammable = TRUE

/obj/item/weapon/chisel
	name = "stone chisel"
	desc = "A stone chisel, for carving stone walls."
	icon = 'icons/obj/items.dmi'
	icon_state = "chisel"
	force = 2.0
	throwforce = 1.0
	w_class = 1.0
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	flammable = FALSE
	//Designs possible are "smooth", "cave", "brick", "cobbled", "tiled"
	var/design = "smooth"

/obj/item/weapon/chisel/attack_self(mob/user)
	var/display = list("Smooth", "Cave", "Brick", "Cobbled", "Tiled", "Cancel")
	var/input =  WWinput(user, "What design do you want to carve?", "Carving", "Cancel", display)
	if (input == "Cancel")
		return
	else if  (input == "Smooth")
		user << "<span class='notice'>You will now carve the smooth design!</span>"
		design = "smooth"
	else if  (input == "Cave")
		user << "<span class='notice'>You will now carve the cave design!</span>"
		design = "cave"
	else if  (input == "Brick")
		user << "<span class='notice'>You will now carve the brick design!</span>"
		design = "brick"
	else if  (input == "Cobbled")
		user << "<span class='notice'>You will now carve the cobbled design!</span>"
		design = "cobbled"
	else if  (input == "Tiled")
		user << "<span class='notice'>You will now carve the tiled design!</span>"
		design = "tiled"

/obj/item/weapon/chisel/metal
	name = "iron chisel"
	desc = "A iron chisel, for carving stone walls."
	icon = 'icons/obj/items.dmi'
	icon_state = "chisel_metal"
	force = 2.25
	throwforce = 1.25
	w_class = 1.0
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	flammable = FALSE
	//Designs possible are "smooth", "cave", "brick", "cobbled", "tiled"
	design = "smooth"

/obj/item/weapon/material/shovel/attack_self(mob/user)
	var/turf/floor/TB = get_turf(user)
	var/display = list("Tunnel", "Grave", "Irrigation Channel", "Pit Latrine","Cancel")
	var/input =  WWinput(user, "What do you want to dig?", "Digging", "Cancel", display)
	if (input == "Cancel")
		return
	else if (input == "Tunnel")
		/*if (!(locate(/obj/roof/, (user.x,user.y,user.z-1)))
			user << "<span class='notice'>You try to dig, but something hard is underneath!</span>"
			return*/ //TO DO TO STOP PEOPLE FROM DIGGING ITNO BUNKERS LATER, TAISLIN PLZ FIX K THX!
		if (!(locate(/obj/structure/multiz/) in user.loc) && user.z == 1)
			TB = locate(user.x,user.y,user.z+1)
			for (var/obj/OB in TB)
				if (istype(OB, /obj/covers) || OB.density == TRUE || istype(OB, /obj/structure/multiz) || istype(OB, /obj/structure/rails))
					user << "<span class='notice'>You can't dig up here, there is something blocking the way!</span>"
					return
			if ((istype(TB, /turf/floor/beach) && !istype(TB, /turf/floor/beach/sand)) || istype(TB, /turf/floor/plating) || istype(TB, /turf/floor/broken_floor) ||istype(TB, /turf/floor/mining) ||istype(TB, /turf/floor/ship) ||istype(TB, /turf/floor/wood) ||istype(TB, /turf/floor/wood_broken) ||!istype(TB, /turf/floor))
				user << "<span class='notice'>You can't dig up on that type of floor!</span>"
				return
			var/digging_tunnel_time = 400
			if (ishuman(user))
				var/mob/living/human/H = user
				digging_tunnel_time /= H.getStatCoeff("strength")
				digging_tunnel_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
			visible_message("<span class='danger'>[user] starts digging up!</span>", "<span class='danger'>You start digging up.</span>")
			if (do_after(user, digging_tunnel_time, user.loc))
				if (!TB.is_diggable)
					return
				new/obj/structure/multiz/ladder/ww2/tunneltop(locate(user.x, user.y, user.z+1))
				new/obj/structure/multiz/ladder/ww2/tunnelbottom(user.loc)
				visible_message("<span class='danger'>[user] finishes digging up.</span>")
				if (ishuman(user))
					var/mob/living/human/H = user
					H.adaptStat("crafting", 1)
					H.adaptStat("strength", 1)
			return
		if ((TB.is_diggable) && !(locate(/obj/structure/multiz/) in user.loc))
			if (user.z <= 1)
				user << "<span class='notice'>You can't dig a tunnel here, the bedrock is right below.</span>"
				return
			else
				var/digging_tunnel_time = 200
				if (ishuman(user))
					var/mob/living/human/H = user
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
						var/mob/living/human/H = user
						H.adaptStat("crafting", 1)
						H.adaptStat("strength", 1)
				return
		else if (locate(/obj/structure/multiz/) in user.loc)
			user << "<span class='warning'>There already is something here.</span>"
			return
		else if (!TB.is_diggable)
			user << "<span class='warning'>You cannot dig a hole here!</span>"
			return
	else if (input == "Irrigation Channel")
		visible_message("<span class = 'notice'>[user] starts to dig an irrigation channel.</span>")
		if (do_after(user, 25,src))
			visible_message("<span class = 'notice'>[user] makes a irrigation channel.</span>")
			TB.irrigate("empty")
			return
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
