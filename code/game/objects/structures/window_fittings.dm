// Opening windows and shutters (Val, 2026-11-16). Glazed windows used to be
// fixed panes that could only be broken, so there was nothing to lock. Now a
// window frame can take a casement (two glazed sashes that open) or shutters
// (two solid leaves); a shuttered frame can still be glazed with a fixed pane. Both
// are doors as far as fittings go: the inside is chosen when they are built,
// and they take the same locks, latches, bar brackets, bars and slide bolts,
// with the same inside and outside rules and the same ways past a lock.
// They don't take closers, wedges, fusible links or panic bars.
//
// A casement lets light and sight through while shut. Open, it lets air and
// thrown things through, and people climb through it rather than walk.
// Shutters block sight while shut; open, the window behind them decides.

/obj/structure/simple_door/proc/is_window_door()
	return FALSE

/obj/structure/simple_door/key_door/anyone/casement
	name = "casement window"
	desc = "A window whose two glazed sashes open outwards. Open, you can climb through it."
	icon = 'icons/obj/doors/window_fittings.dmi'
	icon_state = "casement"
	material = "glass"
	override_material = TRUE
	override_opacity = TRUE
	opacity = FALSE
	layer = MOB_LAYER + 0.02

/obj/structure/simple_door/key_door/anyone/window_shutters
	name = "wooden shutters"
	desc = "A pair of wooden shutters over a window. Shut, nobody sees in or out."
	icon = 'icons/obj/doors/window_fittings.dmi'
	icon_state = "shutters_wood"
	material = "wood"
	override_material = TRUE
	layer = MOB_LAYER + 0.02

/obj/structure/simple_door/key_door/anyone/window_shutters/iron
	name = "iron shutters"
	desc = "A pair of iron shutters over a window. Shut, nobody sees in or out, and they take a beating."
	icon_state = "shutters_iron"
	material = "iron"

/obj/structure/simple_door/key_door/anyone/casement/is_window_door()
	return TRUE

/obj/structure/simple_door/key_door/anyone/window_shutters/is_window_door()
	return TRUE

/obj/structure/simple_door/key_door/anyone/casement/New(_loc, _material = null)
	..(_loc, initial(material))
	basic_icon = initial(icon_state)
	health = 80
	initial_health = health
	opacity = FALSE

/obj/structure/simple_door/key_door/anyone/window_shutters/New(_loc, _material = null)
	..(_loc, initial(material))
	basic_icon = initial(icon_state)
	health = (initial(material) == "iron") ? 250 : 120
	initial_health = health

// Windows don't swing open when someone walks into them.
/obj/structure/simple_door/key_door/anyone/window_shutters/Bumped(atom/user)
	return

/obj/structure/simple_door/key_door/anyone/casement/Bumped(atom/user)
	if (state && ishuman(user) && !isSwitchingStates)
		window_climb_through(user)

// An open casement still stands in the way of people: they climb through it.
/obj/structure/simple_door/key_door/anyone/casement/door_opened()
	density = TRUE
	..()

/obj/structure/simple_door/key_door/anyone/casement/door_closed()
	opacity = FALSE
	..()

/obj/structure/simple_door/key_door/anyone/casement/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (!state)
		return FALSE
	if (air_group)
		return TRUE
	return !ismob(mover)

/obj/structure/simple_door/key_door/anyone/casement/MouseDrop_T(mob/target, mob/user)
	if (target == user && ishuman(user) && state && get_dist(user, src) <= 1)
		window_climb_through(user)
		return
	return ..()

// Climbing straight through an open casement to the tile beyond it.
/obj/structure/simple_door/key_door/anyone/casement/proc/window_climb_through(mob/living/human/user)
	if (!istype(user) || user.incapacitated() || user.restrained() || user.buckled)
		return FALSE
	var/side = door_side_of(user)
	var/turf/from = get_turf(user)
	if (!side || get_dist(from, src) != 1 || get_step(src, side) != from)
		to_chat(user, SPAN_WARNING("Face \the [src] squarely to climb through it."))
		return FALSE
	var/turf/landing = get_step(src, turn(side, 180))
	if (!window_landing_clear(landing))
		to_chat(user, SPAN_WARNING("Something on the other side is in the way."))
		return FALSE
	if (user in climbers)
		return FALSE
	climbers |= user
	user.visible_message(SPAN_NOTICE("[user] starts climbing through \the [src]."), SPAN_NOTICE("You start climbing through the window."))
	var/ok = do_after(user, issmall(user) ? 15 : 25, src)
	climbers -= user
	if (!ok || QDELETED(src) || !state || get_turf(user) != from || !window_landing_clear(landing))
		return FALSE
	user.forceMove(landing)
	user.visible_message(SPAN_NOTICE("[user] climbs through \the [src]."), SPAN_NOTICE("You climb through the window."))
	return TRUE

/proc/window_landing_clear(turf/T)
	if (!T || T.density)
		return FALSE
	for (var/atom/movable/A in T)
		if (A.density && !ismob(A))
			return FALSE
	return TRUE

// What a window door may stand in: a casement needs an empty window frame;
// shutters need a frame or a fixed glazed window (you build standing in the
// frame, so shutter a frame and glaze it afterwards). Returns why not, or null.
/proc/window_door_build_refusal(turf/T, new_type)
	if (!T)
		return "There is nothing here."
	for (var/obj/structure/simple_door/D in T)
		if (!QDELETED(D))
			return "There is already \a [D] here."
	var/obj/structure/window_frame/frame = locate() in T
	var/obj/structure/window/glass = locate() in T
	if (ispath(new_type, /obj/structure/simple_door/key_door/anyone/casement))
		if (glass)
			return "\The [glass] is a fixed pane. A casement goes in an empty window frame."
		if (!frame)
			return "A casement goes in an empty window frame."
		if (!(frame.type in casement_frame_types))
			return "\The [frame] has the wrong shape of opening for a casement. Shutters will fit it."
		return null
	if (!frame && !istype(glass, /obj/structure/window/classic))
		return "Shutters go on a window or a window frame."
	return null

// Frames with the square opening the casement sashes are drawn for.
var/global/list/casement_frame_types = list(
	/obj/structure/window_frame,
	/obj/structure/window_frame/metal,
	/obj/structure/window_frame/stone,
	/obj/structure/window_frame/sandstone,
	/obj/structure/window_frame/marble,
	/obj/structure/window_frame/redsandstone)

/proc/type_is_window_door(path)
	return ispath(path, /obj/structure/simple_door/key_door/anyone/casement) || ispath(path, /obj/structure/simple_door/key_door/anyone/window_shutters)

// Closers, wedges, fusible links and panic bars are for doors, not windows.
// Glass used on shutters goes to the frame behind them.
/obj/structure/simple_door/proc/window_door_attackby(obj/item/W, mob/user)
	if (!is_window_door())
		return FALSE
	if (istype(W, /obj/item/stack/material/glass))
		var/obj/structure/window_frame/frame = locate() in loc
		if (frame)
			frame.attackby(W, user)
		else
			to_chat(user, SPAN_WARNING("There is no empty frame behind \the [src] to glaze."))
		return TRUE
	if (istype(W, /obj/item/door_fitting) || istype(W, /obj/item/door_wedge) || istype(W, /obj/item/fusible_link) || istype(W, /obj/item/panic_bar))
		to_chat(user, SPAN_WARNING("\The [W] is made for doors, not \the [src]."))
		return TRUE
	return FALSE
