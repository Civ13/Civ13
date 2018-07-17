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
//	origin_tech = "materials=1;engineering=1"
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

/obj/item/weapon/shovel/spade/russia
	name = "lopata"
	icon_state = "lopata"
	item_state = "lopata"

/obj/item/weapon/shovel/spade/german
	name = "feldspaten"
	icon_state = "german_shovel2"
	item_state = "lopata"

/obj/item/weapon/shovel/spade/japan
	name = "japanese field shovel"
	icon_state = "lopata"
	item_state = "lopata"

/obj/item/weapon/shovel/spade/usa
	name = "american field shovel"
	icon_state = "german_shovel2"
	item_state = "lopata"

/obj/item/weapon/shovel/spade/mortar
	name = "spade mortar"
	icon_state = "spade_mortar"
	item_state = "lopata"
	desc = "A 37mm mortar that also functions as a shovel. Very heavy."
	weight = 20
	heavy = TRUE

/obj/item/weapon/shovel/spade/mortar/New()
	..()
	mortar_spade_list += src

/obj/item/weapon/shovel/spade/mortar/Destroy()
	mortar_spade_list -= src
	..()

/obj/item/weapon/shovel/spade/mortar/attack_self(var/mob/user as mob)
	var/target = get_step(user, user.dir)
	if (target)
		visible_message("<span class = 'warning'>[user] starts to deploy a spade mortar.</span>")
		if (do_after(user, 50, get_turf(user)))
			visible_message("<span class = 'warning'>[user] deploys a spade mortar.</span>")
			user.remove_from_mob(src)
			qdel(src)
			var/atom/A = new/obj/structure/mortar/spade(get_turf(user))
			A.dir = user.dir

/obj/item/weapon/wirecutters/boltcutters
	name = "boltcutters"
	desc = "This cuts bolts and other things."
	icon_state = "boltcutters"

/obj/item/weapon/crowbar/prybar
	name = "prybar"
	icon_state = "prybar"

/obj/item/weapon/weldingtool/ww2
	name = "welding tool"
	icon_state = "ww2_welder_off"
	on_state = "ww2_welder_on"
	off_state = "ww2_welder_off"
/*
/obj/item/flashlight/ww2
	name = "flashlight"
	icon_state = "ww2_welder_off"
	on_state = "ww2_welder_on"
	off_state = "ww2_welder_off"*/