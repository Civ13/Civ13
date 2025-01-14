/obj/structure/brazier
	name = "\improper brazier"
	desc = "Where you keep warm or light arrows and bolts on fire."
	icon_state = "brazier"
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
	ignition_source = TRUE
	icon_state = "[initial(icon_state)]-on"
	update_icon()

/obj/structure/brazier/attackby(obj/item/I as obj, mob/user as mob)
	if(user.a_intent == I_HELP && !istype(I, /obj/item/torch))
		// Toggle Anchor
		if (istype(I, /obj/item/weapon/wrench) || (istype(I, /obj/item/weapon/hammer)))
			if (istype(I, /obj/item/weapon/wrench))
				visible_message("<span class='warning'>[user] starts to [anchored ? "unsecure" : "secure"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
				playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
				if (do_after(user, 20, src))
					visible_message("<span class='warning'>[user] [anchored ? "unsecures" : "secures"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
					anchored = !anchored
					return
			else if (istype(I, /obj/item/weapon/hammer) || istype(I, /obj/item/weapon/hammer/modern))
				visible_message("<span class='warning'>[user] starts to deconstruct \the [src].</span>")
				playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
				if (do_after(user, 20, src))
					visible_message("<span class='warning'>[user] deconstructs \the [src].</span>")
					qdel(src)
					return
		// Ignite Crossbow Bolt
		else if (istype(I, /obj/item/ammo_casing/bolt) && on)
			var/obj/item/ammo_casing/bolt/B = I
			to_chat(user, "<span class='italics'>You start lighting \the [I] in \the [src]...</span>")
			if (do_after(user, 10, src))
				to_chat(user, "<span class='italics'>You light \the [I] in \the [src].</span>")
				B.name = "fire bolt"
				B.icon_state = "boltf"
				B.projectile_type = /obj/item/projectile/arrow/bolt/fire
				B.damtype = BURN
				B.BB = new/obj/item/projectile/arrow/bolt/fire(B)
				B.contents = list(B.BB)
		// Ignite Arrow
		else if (istype(I, /obj/item/ammo_casing/arrow) && on)
			var/obj/item/ammo_casing/arrow/A = I
			to_chat(user, "<span class='italics'>You start lighting \the [I] in \the [src]...</span>")
			if (do_after(user, 10, src))
				to_chat(user, "<span class='italics'>You light \the [I] in \the [src].</span>")
				A.name = "fire arrow"
				A.icon_state = "arrowf"
				A.projectile_type = /obj/item/projectile/arrow/arrow/fire
				A.damtype = BURN
				A.BB = new/obj/item/projectile/arrow/arrow/fire(A)
				A.contents = list(A.BB)
		// Refuel
		else if(I.fuel_value > 0)
			to_chat(user, "<span class='italics'>You fuel \the [src] with \the [I].</span>")
			fuel += I.fuel_value
			if(istype(I, /obj/item/stack))
				var/obj/item/stack/S = I
				S.use(1)
			else
				qdel(I)
		// Destroy Item
		else
			to_chat(user, "<span class='notice'>You begin throwing \the [I] into \the [src] to melt it.</span>")
			if(do_after(user, 10, src))
				to_chat(user, "<span class='notice'>You throw \the [I] into \the [src], melting it.</span>")
				qdel(I)
		return
	..()

/obj/structure/brazier/proc/do_light()
	if (on)
		fuel--
		//change_global_pollution(0.015)
		if (fuel <= 0)
			on = FALSE
			ignition_source = FALSE
			icon_state = initial(icon_state)
			visible_message(SPAN_WARNING("\The [src] runs out of fuel!"))
			set_light(0)
	spawn(10)
		do_light()

/obj/structure/brazier/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user.visible_message(SPAN_NOTICE("[user] lights \the [src]."), SPAN_NOTICE("You light \the [src]."))
		on = TRUE
		ignition_source = TRUE
		icon_state = "[initial(icon_state)]-on"
		set_light(5)
		return
	else if (on)
		user.visible_message(SPAN_NOTICE("[user] extinguishes \the [src]."), SPAN_NOTICE("You extinguish \the [src]."))
		on = FALSE
		ignition_source = FALSE
		icon_state = initial(icon_state)
		set_light(0)
		return
	else
		to_chat(user, SPAN_WARNING("\The [src] is out of fuel!"))
		return

// Other brazier type defines.

/obj/structure/brazier/stone
	name = "stone brazier"
	desc = "Where you keep warm or light arrows and bolts on fire."
	icon_state = "s_brazier"

/obj/structure/brazier/sandstone
	name = "sandstone brazier"
	desc = "Where you keep warm or light arrows and bolts on fire."
	icon_state = "sandstone_brazier"

/obj/structure/brazier/obsidian
	name = "obsidian brazier"
	desc = "Where you keep warm or light arrows and bolts on fire."
	icon_state = "obsidian_brazier"

/obj/structure/brazier/marble
	name = "marble brazier"
	desc = "Where you keep warm or light arrows and bolts on fire."
	icon_state = "marble_brazier"

/obj/structure/brazier/potbellystove // This is a stove not a brazier; todo: move this.
	name = "potbelly stove"
	desc = "Where you keep warm or light arrows and bolts on fire."
	icon_state = "potbelly"