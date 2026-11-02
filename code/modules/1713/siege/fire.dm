/obj/structure/brazier
	name = "brazier"
	desc = "Where you keep warm or light arrows and bolts on fire."
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
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/ore/charcoal))
			fuel += (180)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/material/wood || /obj/item/stack/material/woodplank))
			fuel += (80)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/material/bamboo))
			fuel += (80)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if(istype(W, /obj/item/stack/dung))
			fuel += (90)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/weapon/branch))
			fuel += (60)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/stack/material/leaf))
			fuel += (60)*W.amount
			user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
			qdel(W)
			return
		else if (istype(W, /obj/item/ammo_casing/arrow) && on)
			var/obj/item/ammo_casing/arrow/WW = W
			to_chat(user, SPAN_NOTICE("You start lighting the arrow in \the [src]..."))
			if (do_after(user, 30, src))
				to_chat(user, SPAN_NOTICE("You light the arrow in \the [src]."))
				WW.name = "fire arrow"
				WW.icon_state = "arrowf"
				WW.projectile_type = /obj/item/projectile/arrow/arrow/fire
				WW.damtype = BURN
				WW.BB = new/obj/item/projectile/arrow/arrow/fire(WW)
				WW.contents = list(WW.BB)
				return
		else if (istype(W, /obj/item/ammo_casing/bolt) && on)
			var/obj/item/ammo_casing/bolt/WW = W
			to_chat(user, SPAN_NOTICE("You start lighting the bolt in \the [src]..."))
			if (do_after(user, 30, src))
				to_chat(user, SPAN_NOTICE("You light the bolt in \the [src]."))
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
				user.visible_message(SPAN_NOTICE("[user] places \the [W] in \the [src], refueling it."), SPAN_NOTICE("You place \the [W] in the [src], refueling it."))
				qdel(W)
				return
			else
				if (on)
					to_chat(user, SPAN_NOTICE("You throw \the [W] into \the [src], melting it."))
					qdel(W)
					return
	..()

/obj/structure/brazier/proc/do_light()
	if (on)
		fuel--
		//change_global_pollution(0.015)
		if (fuel <= 0)
			on = FALSE
			icon_state = "brazier0"
			visible_message(SPAN_WARNING("\The [src] runs out of fuel!"))
			set_light(0)
	spawn(10)
		do_light()

/obj/structure/brazier/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user.visible_message(SPAN_NOTICE("[user] lights \the [src]."), SPAN_NOTICE("You light \the [src]."))
		on = TRUE
		icon_state = "brazier1"
		set_light(5)
		return
	else if (on)
		user.visible_message(SPAN_NOTICE("[user] extinguishes \the [src]."), SPAN_NOTICE("You extinguish \the [src]."))
		on = FALSE
		icon_state = "brazier0"
		set_light(0)
		return
	else
		to_chat(user, SPAN_WARNING("\The [src] is out of fuel!"))
		return

// Other brazier type defines.

/obj/structure/brazier/stone
	name = "stone brazier"
	desc = "Where you keep warm or light arrows and bolts on fire."
	icon_state = "s_brazier0"

// Only items produced as food or butchered animal materials are disposable.
// Keep the list explicit: it must never include mobs or general containers.
/obj/structure/brazier/stone/proc/is_disposable_organic(obj/item/I)
	return istype(I, /obj/item/weapon/reagent_containers/food/snacks) || istype(I, /obj/item/weapon/chicken_carcass) || istype(I, /obj/item/weapon/pigleg) || istype(I, /obj/item/stack/sinew) || istype(I, /obj/item/stack/material/bone) || istype(I, /obj/item/stack/material/rawhide) || istype(I, /obj/item/stack/material/pelt)

/obj/structure/brazier/stone/attackby(obj/item/W, mob/user)
	if (!is_disposable_organic(W))
		return ..()
	if (user.a_intent != I_HELP)
		return
	if (!on)
		to_chat(user, SPAN_WARNING("You need to light \the [src] before disposing of food or animal remains."))
		return
	// Refuse nested items, live contents, and items the user cannot release.
	if (QDELETED(W) || W.loc != user || user.get_active_hand() != W || length(W.contents) || !user.canUnEquip(W) || W.nodrop || W.nodrop_special_check())
		to_chat(user, SPAN_WARNING("You cannot safely dispose of \the [W]."))
		return
	var/item_name = "\the [W]"
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/stack = W
		if (!stack.use(1))
			return
	else
		var/turf/drop_site = get_turf(user)
		var/atom/brazier_loc = loc
		if (!drop_site || user.loc != drop_site || !user.unEquip(W))
			return
		// Drop callbacks may move or fill the item, move an actor, or extinguish the fire.
		if (QDELETED(src) || !on || loc != brazier_loc || QDELETED(user) || user.loc != drop_site || QDELETED(W) || W.loc != drop_site || length(W.contents))
			return
		qdel(W)
	// Five seconds of fuel per item or stack unit, versus 80 for one wood.
	fuel += 5
	user.visible_message(SPAN_NOTICE("[user] disposes of [item_name] in \the [src]."), SPAN_NOTICE("You dispose of [item_name] in \the [src]."))

/obj/structure/brazier/sandstone
	name = "sandstone brazier"
	desc = "Where you keep warm or light arrows and bolts on fire."
	icon_state = "sandstone_brazier0"

/obj/structure/brazier/obsidian
	name = "obsidian brazier"
	desc = "Where you keep warm or light arrows and bolts on fire."
	icon_state = "obsidian_brazier0"

/obj/structure/brazier/marble
	name = "marble brazier"
	desc = "Where you keep warm or light arrows and bolts on fire."
	icon_state = "marble_brazier0"

/obj/structure/brazier/potbellystove // This is a stove not a brazier; todo: move this.
	name = "potbelly stove"
	desc = "Where you keep warm or light arrows and bolts on fire."
	icon_state = "potbelly"

// Other lit brazier procedures. - todo: call parent proc which handles all of this, save for the icon states, condensifying code as a result.

/obj/structure/brazier/sandstone/do_light()
	if (on)
		fuel--
		if (fuel <= 0)
			on = FALSE
			set_light(0)
			visible_message(SPAN_WARNING("\The [src] runs out of fuel!"))
			icon_state = "sandstone_brazier0"
	spawn(10)
		do_light()

/obj/structure/brazier/obsidian/do_light()
	if (on)
		fuel--
		if (fuel <= 0)
			on = FALSE
			set_light(0)
			visible_message(SPAN_WARNING("\The [src] runs out of fuel!"))
			icon_state = "obsidian_brazier0"
	spawn(10)
		do_light()

/obj/structure/brazier/marble/do_light()
	if (on)
		fuel--
		if (fuel <= 0)
			on = FALSE
			set_light(0)
			visible_message(SPAN_WARNING("\The [src] runs out of fuel!"))
			icon_state = "marble_brazier0"
	spawn(10)
		do_light()

/obj/structure/brazier/stone/do_light()
	if (on)
		fuel--
		if (fuel <= 0)
			on = FALSE
			set_light(0)
			visible_message(SPAN_WARNING("\The [src] runs out of fuel!"))
			icon_state = "s_brazier0"
	spawn(10)
		do_light()

/obj/structure/brazier/potbellystove/do_light() // This is a stove not a brazier; todo: move this.
	if (on)
		fuel--
		if (fuel <= 0)
			on = FALSE
			set_light(0)
			visible_message(SPAN_WARNING("\The [src] runs out of fuel!"))
			icon_state = "potbelly"
	spawn(10)
		do_light()

// Other brazier hand lighting procs - todo: call parent proc which handles all of this, save for the icon states, condensifying code as a result.

/obj/structure/brazier/stone/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user.visible_message(SPAN_NOTICE("[user] lights \the [src]."), SPAN_NOTICE("You light \the [src]."))
		on = TRUE
		set_light(5)
		icon_state = "s_brazier1"
		return
	else if (on)
		user.visible_message(SPAN_NOTICE("[user] extinguishes \the [src]."), SPAN_NOTICE("You extinguish \the [src]."))
		on = FALSE
		set_light(0)
		icon_state = "s_brazier0"
		return
	else
		to_chat(user, SPAN_WARNING("\The [src] is out of fuel!"))
		return

/obj/structure/brazier/potbellystove/attack_hand(mob/user as mob) // This is a stove not a brazier; todo: move this.
	if (!on && fuel > 0)
		user.visible_message(SPAN_NOTICE("[user] lights \the [src]."), SPAN_NOTICE("You light \the [src]."))
		on = TRUE
		set_light(5)
		icon_state = "potbelly-lit"
		return
	else if (on)
		user.visible_message(SPAN_NOTICE("[user] extinguishes \the [src]."), SPAN_NOTICE("You extinguish \the [src]."))
		on = FALSE
		set_light(0)
		icon_state = "potbelly"
		return
	else
		to_chat(user, SPAN_WARNING("\The [src] is out of fuel!"))
		return

/obj/structure/brazier/sandstone/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user.visible_message(SPAN_NOTICE("[user] lights \the [src]."), SPAN_NOTICE("You light \the [src]."))
		on = TRUE
		set_light(5)
		icon_state = "sandstone_brazier1"
		return
	else if (on)
		user.visible_message(SPAN_NOTICE("[user] extinguishes \the [src]."), SPAN_NOTICE("You extinguish \the [src]."))
		on = FALSE
		set_light(0)
		icon_state = "sandstone_brazier0"
		return
	else
		to_chat(user, SPAN_WARNING("\The [src] is out of fuel!"))
		return

/obj/structure/brazier/obsidian/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user.visible_message(SPAN_NOTICE("[user] lights \the [src]."), SPAN_NOTICE("You light \the [src]."))
		on = TRUE
		set_light(5)
		icon_state = "obsidian_brazier1"
		return
	else if (on)
		user.visible_message(SPAN_NOTICE("[user] extinguishes \the [src]."), SPAN_NOTICE("You extinguish \the [src]."))
		on = FALSE
		set_light(0)
		icon_state = "obsidian_brazier0"
		return
	else
		to_chat(user, SPAN_WARNING("\The [src] is out of fuel!"))
		return

/obj/structure/brazier/marble/attack_hand(mob/user as mob)
	if (!on && fuel > 0)
		user.visible_message(SPAN_NOTICE("[user] lights \the [src]."), SPAN_NOTICE("You light \the [src]."))
		on = TRUE
		set_light(5)
		icon_state = "marble_brazier1"
		return
	else if (on)
		user.visible_message(SPAN_NOTICE("[user] extinguishes \the [src]."), SPAN_NOTICE("You extinguish \the [src]."))
		on = FALSE
		set_light(0)
		icon_state = "marble_brazier0"
		return
	else
		to_chat(user, SPAN_WARNING("\The [src] is out of fuel!"))
		return
