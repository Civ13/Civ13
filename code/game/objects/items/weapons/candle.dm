/obj/item/weapon/flame/candle
	name = "red candle"
	desc = "A small pillar candle."
	icon = 'icons/obj/candle.dmi'
	icon_state = "candle1"
	item_state = "candle1"
	w_class = ITEM_SIZE_TINY
	light_color = "#E09D37"
	var/wax = 1000
	flammable = TRUE

/obj/item/weapon/flame/candle/on_runtime_spawn()
	..()
	wax = rand(900, 1050) //30-40 minutes on average.
	pixel_x = rand(-8, 8)
	pixel_y = rand(-8, 8)

/obj/item/weapon/flame/candle/on
	New()
		..()
		light()

/obj/item/weapon/flame/candle/update_icon()
	var/i
	if (wax > 800)
		i = TRUE
	else if (wax > 500)
		i = 2
	else i = 3
	icon_state = "candle[i][lit ? "_lit" : ""]"


// Any open flame lights a candle: a lit candle, match, lighter, torch, tiki
// torch, oil lamp, flare, campfire, stove or brazier (see isflamesource()).
/obj/item/weapon/flame/candle/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!lit && isflamesource(W))
		light_from(W, user)
		return TRUE
	return ..()

// Holding the candle against a flame: a placed tiki torch, a campfire, a lit
// candle on a table. Checked before the target's own attackby so a lit oven
// or torch mount does not take the candle as an ingredient or a light.
// The click code only calls this for things in reach or on the user.
/obj/item/weapon/flame/candle/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (!lit && A != src && isflamesource(A))
		light_from(A, user)
		return TRUE
	return ..()

/obj/item/weapon/flame/candle/proc/light_from(atom/source, mob/user)
	if (lit)
		return FALSE
	if (user)
		light("<span class='notice'>\The [user] lights \the [src] from \the [source].</span>", user)
	else
		light()
	update_icon()
	return TRUE

/obj/item/weapon/flame/candle/proc/light(var/flavor_text = "<span class='notice'>\The [usr] lights the [name].</span>", mob/user = usr)
	if (!lit)
		lit = TRUE
		var/atom/viewer_center = user ? user : src
		for (var/mob/O in viewers(viewer_center, null))
			O.show_message(flavor_text, TRUE)
		set_light(CANDLE_LUM)
		processing_objects += src
		update_icon()


/obj/item/weapon/flame/candle/process()
	return process_interval(2)

/obj/item/weapon/flame/candle/process_interval(configured_seconds = 2)
	if (!lit)
		return
	// Wax remains in legacy two-second units for save compatibility.
	wax = max(0, wax - configured_seconds / 2)
	if (wax <= 0)
		create_candle_remains()
		if (istype(loc, /mob))
			dropped()
		qdel(src)
	update_icon()

/obj/item/weapon/flame/candle/proc/create_candle_remains()
	new/obj/item/trash/candle(loc)

/obj/item/weapon/flame/candle/attack_self(mob/user as mob)
	if (lit)
		lit = FALSE
		update_icon()
		set_light(0)

/obj/item/weapon/flame/candle/lard
	name = "lard candle"
	desc = "A poorly shaped small pillar candle. A bit stinky and oily."
	icon = 'icons/obj/candle.dmi'
	icon_state = "candle1_lard"
	item_state = "candle1_lard"

/obj/item/weapon/flame/candle/lard/update_icon()
	var/i
	if (wax > 800)
		i = TRUE
	else if (wax > 500)
		i = 2
	else i = 3
	icon_state = "candle[i][lit ? "_lit" : ""]_lard"

/obj/item/weapon/flame/candle/lard/create_candle_remains()
	new/obj/item/trash/candle/lard(loc)

/obj/item/weapon/flame/candle/lard/on
	New()
		..()
		light()
