/obj/structure/brazier
	name = "brazier"
	desc = "Where you keep warm or light arrows on fire."
	icon_state = "brazier0"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	var/fuel = 0
	var/on = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/brazier/New()
	..()
	do_light()

/obj/structure/brazier/loaded/New()
	..()
	fuel = 5000
	set_light(5)
	on = TRUE
	icon_state = "brazier1"
	update_icon()

/obj/structure/brazier/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (user.a_intent == I_HELP)
		if (istype(W, /obj/item/weapon/wrench) || (istype(W, /obj/item/weapon/hammer)))
			if (istype(W, /obj/item/weapon/wrench))
				visible_message("<span class='warning'>[user] starts to [anchored ? "unsecure" : "secure"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
				playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
				if (do_after(user,50,src))
					visible_message("<span class='warning'>[user] [anchored ? "unsecures" : "secures"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
					anchored = !anchored
					return
			else if (istype(W, /obj/item/weapon/hammer) || istype(W, /obj/item/weapon/hammer/modern))
				visible_message("<span class='warning'>[user] starts to deconstruct \the [src].</span>")
				playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
				if (do_after(user,50,src))
					visible_message("<span class='warning'>[user] deconstructs \the [src].</span>")
					qdel(src)
					return
		else if (istype(W, /obj/item/stack/ore/coal))
			fuel += (220)*W.amount
			user << "You refuel the [src]."
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/ore/charcoal))
			fuel += (180)*W.amount
			user << "You refuel the [src]."
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/material/wood))
			fuel += (80)*W.amount
			user << "You refuel the [src]."
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/material/bamboo))
			fuel += (80)*W.amount
			user << "You refuel the [src]."
			qdel(W)
			return
		else if(istype(W, /obj/item/stack/dung))
			fuel += (90)*W.amount
			user << "You refuel the [src]."
			qdel(W)
			return
		else if (istype(W, /obj/item/weapon/branch))
			fuel += (60)*W.amount
			user << "You refuel the [src]."
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/material/leaf))
			fuel += (60)*W.amount
			user << "You refuel the [src]."
			qdel(W)
			return
		else if (istype(W, /obj/item/ammo_casing/arrow) && on)
			var/obj/item/ammo_casing/arrow/WW = W
			user << "You start lighting the arrow in \the [src]..."
			if (do_after(user, 30, src))
				user << "You light the arrow in \the [src]."
				WW.name = "fire arrow"
				WW.icon_state = "arrowf"
				WW.projectile_type = /obj/item/projectile/arrow/arrow/fire
				WW.damtype = BURN
				WW.BB = new/obj/item/projectile/arrow/arrow/fire(WW)
				WW.contents = list(WW.BB)
				return
		else if (istype(W, /obj/item/ammo_casing/bolt) && on)
			var/obj/item/ammo_casing/bolt/WW = W
			user << "You start lighting the bolt in \the [src]..."
			if (do_after(user, 30, src))
				user << "You light the bolt in \the [src]."
				WW.name = "fire bolt"
				WW.icon_state = "boltf"
				WW.projectile_type = /obj/item/projectile/arrow/bolt/fire
				WW.damtype = BURN
				WW.BB = new/obj/item/projectile/arrow/bolt/fire(WW)
				WW.contents = list(WW.BB)
				return
		else if  (istype(W, /obj/item))
			if (W.flammable)
				if (istype(W, /obj/item/stack))
					var/obj/item/stack/ST = W
					fuel += 25*ST.amount
				else
					fuel += 25
				user << "You place \the [W] in \the [src], refueling it."
				qdel(W)
				return
			else
				if (on)
					user << "You throw \the [W] into \the [src], melting it."
					qdel(W)
					return
	..()
/obj/structure/brazier/proc/do_light()
	if (on)
		fuel--
		change_global_pollution(0.015)
		if (fuel <= 0)
			on = FALSE
			icon_state = "brazier0"
			set_light(0)
	spawn(10)
		do_light()

/obj/structure/brazier/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user << "You light \the [src]."
		on = TRUE
		icon_state = "brazier1"
		set_light(5)
		return
	else
		user << "You put out \the [src]."
		on = FALSE
		icon_state = "brazier0"
		set_light(0)
		return

/obj/structure/brazier/stone
	name = "stone brazier"
	desc = "Where you keep warm or light arrows on fire."
	icon_state = "s_brazier0"

/obj/structure/brazier/sandstone
	name = "sandstone brazier"
	desc = "Where you keep warm or light arrows on fire."
	icon_state = "sandstone_brazier0"

/obj/structure/brazier/obsidian
	name = "obsidian brazier"
	desc = "Where you keep warm or light arrows on fire."
	icon_state = "obsidian_brazier0"

/obj/structure/brazier/marble
	name = "marble brazier"
	desc = "Where you keep warm or light arrows on fire."
	icon_state = "marble_brazier0"

/obj/structure/brazier/potbellystove
	name = "potbelly stove"
	desc = "Where you keep warm or light arrows on fire."
	icon_state = "potbelly"

/obj/structure/brazier/sandstone/do_light()
	if (on)
		fuel = (fuel-1)
		if (fuel <= 0)
			on = FALSE
			set_light(0)
			icon_state = "sandstone_brazier0"
	spawn(10)
		do_light()

/obj/structure/brazier/obsidian/do_light()
	if (on)
		fuel = (fuel-1)
		if (fuel <= 0)
			on = FALSE
			set_light(0)
			icon_state = "obsidian_brazier0"
	spawn(10)
		do_light()

/obj/structure/brazier/marble/do_light()
	if (on)
		fuel = (fuel-1)
		if (fuel <= 0)
			on = FALSE
			set_light(0)
			icon_state = "marble_brazier0"
	spawn(10)
		do_light()

/obj/structure/brazier/stone/do_light()
	if (on)
		fuel = (fuel-1)
		if (fuel <= 0)
			on = FALSE
			set_light(0)
			icon_state = "s_brazier0"
	spawn(10)
		do_light()

/obj/structure/brazier/potbellystove/do_light()
	if (on)
		fuel = (fuel-1)
		if (fuel <= 0)
			on = FALSE
			set_light(0)
			icon_state = "potbelly"
	spawn(10)
		do_light()

/obj/structure/brazier/stone/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user << "You light the stone brazier."
		on = TRUE
		set_light(5)
		icon_state = "s_brazier1"
		return
	else
		user << "You put out the stone brazier."
		on = FALSE
		set_light(0)
		icon_state = "s_brazier0"
		return

/obj/structure/brazier/potbellystove/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user << "You light the potbelly stove."
		on = TRUE
		set_light(5)
		icon_state = "potbelly-lit"
		return
	else
		user << "You put out the potbelly stove."
		on = FALSE
		set_light(0)
		icon_state = "potbelly"
		return

/obj/structure/brazier/sandstone/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user << "You light the sandstone brazier."
		on = TRUE
		set_light(5)
		icon_state = "sandstone_brazier1"
		return
	else
		user << "You put out the sandstone brazier."
		on = FALSE
		set_light(0)
		icon_state = "sandstone_brazier0"
		return

/obj/structure/brazier/obsidian/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user << "You light the obsidian brazier."
		on = TRUE
		set_light(5)
		icon_state = "obsidian_brazier1"
		return
	else
		user << "You put out the obsidian brazier."
		on = FALSE
		set_light(0)
		icon_state = "obsidian_brazier0"
		return

/obj/structure/brazier/marble/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user << "You light the marble brazier."
		on = TRUE
		set_light(5)
		icon_state = "marble_brazier1"
		return
	else
		user << "You put out the marble brazier."
		on = FALSE
		set_light(0)
		icon_state = "marble_brazier0"
		return