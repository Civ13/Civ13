/obj/structure/heatsource
	name = "iron furnace"
	desc = "A big iron furnace. Can be used to power external-powered engines."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "furnace_open_off"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	var/fuel = 0
	var/on = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/fuels = list("petroleum", "gasoline", "diesel", "pethanol", "biodiesel", "olive_oil", "fat_oil")

/obj/structure/heatsource/New()
	..()
	do_light()

/obj/structure/heatsource/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (user.a_intent == I_HELP)
		if (istype(W, /obj/item/weapon/wrench) || (istype(W, /obj/item/weapon/hammer)))
			if (istype(W, /obj/item/weapon/wrench))
				visible_message("<span class='warning'>[user] starts to [anchored ? "unsecure" : "secure"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
				playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
				if (do_after(user,50,src))
					visible_message("<span class='warning'>[user] [anchored ? "unsecures" : "secures"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
					anchored = !anchored
					return
			else if (istype(W, /obj/item/weapon/hammer))
				visible_message("<span class='warning'>[user] starts to deconstruct \the [src].</span>")
				playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
				if (do_after(user,50,src))
					visible_message("<span class='warning'>[user] deconstructs \the [src].</span>")
					qdel(src)
					return
		else if (istype(W, /obj/item/stack/ore/coal))
			fuel += (240)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/ore/charcoal))
			fuel += (80)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/material/wood) || istype(W, /obj/item/stack/material/woodplank))
			fuel += (60)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/weapon/branch))
			fuel += (60)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/material/bamboo))
			fuel += (60)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/material/leaf))
			fuel += (30)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/dung))
			fuel += (60)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/weapon/reagent_containers/glass) && !istype(W, /obj/item/weapon/reagent_containers/glass/rag))
			var/obj/item/weapon/reagent_containers/glass/fcont = W
			var/amt = 0
			for (var/F in fuels)
				if (fcont.reagents.has_reagent(F))
					amt += fcont.reagents.get_reagent_amount(F)
					fcont.reagents.remove_reagent(F, fcont.reagents.get_reagent_amount(F))
			fuel += (30)*amt
			user.visible_message(SPAN_NOTICE("[user] pours the fuel into \the [src], refueling it."), SPAN_NOTICE("You pour the fuel into \the [src], refueling it."))
			fcont.reagents.clear_reagents()
			return
		else if  (istype(W, /obj/item))
			if (W.flammable)
				if (istype(W, /obj/item/stack))
					var/obj/item/stack/ST = W
					fuel += 25*ST.amount
				else
					fuel += 25
				user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
				qdel(W)
				return
			else
				if (on)
					to_chat(user, SPAN_WARNING("You throw \the [W] into the [src], melting it."))
					qdel(W)
					return
	..()

/obj/structure/heatsource/proc/do_light()
	if (on)
		fuel--
		//change_global_pollution(0.015)
		if (fuel <= 0)
			on = FALSE
			icon_state = "furnace_open_off"
			visible_message(SPAN_WARNING("\The [src] runs out of fuel!"))
			set_light(0)
	spawn(10)
		do_light()

/obj/structure/heatsource/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user.visible_message(SPAN_NOTICE("[user] lights \the [src]."), SPAN_NOTICE("You light \the [src]."))
		on = TRUE
		icon_state = "furnace_open_on"
		set_light(5)
		return
	else if (on)
		user.visible_message(SPAN_NOTICE("[user] extinguishes \the [src]."), SPAN_NOTICE("You extinguish \the [src]."))
		on = FALSE
		icon_state = "furnace_open_off"
		set_light(0)
		return
	else
		to_chat(user, SPAN_WARNING("\The [src] is out of fuel!"))
		return
