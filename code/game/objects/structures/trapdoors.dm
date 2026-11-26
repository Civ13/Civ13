// Trapdoors and hatches between levels (Val, 2026-11-16). A trapdoor lies flat
// in an opening between two levels: the stairwell over a flight of stairs, the
// top of a ladder, any hole in an upper floor, or a dug hole in the ground.
// Shut, it is floor: people walk across it, nothing falls through, the stairs
// and ladder under it lead nowhere and nobody climbs up through it. Open, the
// opening works as before.
//
// It is a door as far as fittings go, with above and below as its two sides:
// the inside is chosen when it is fitted, and it takes the same locks,
// latches, bar brackets, bars and slide bolts, with the same inside and
// outside rules and the same ways past a lock. From below, work it from the
// ladder or stairs under it: a hand pushes it open (or knocks, or bangs on it),
// and keys, locks, bars, brackets, bolts and a hammer are used on the ladder
// or stairs to reach it. It doesn't take closers, wedges, fusible links, panic
// bars, peep-holes, hatches, mail slots or pet doors.
//
// It is made as a kit and laid into an opening beside you, so nobody has to
// stand on open air to build it.

#define TRAPDOOR_FIT_TIME 40

/obj/structure/simple_door/proc/is_trapdoor()
	return FALSE

/obj/structure/simple_door/key_door/anyone/trapdoor
	name = "wooden trapdoor"
	desc = "A wooden trapdoor set into an opening between two levels. Shut, you can walk across it."
	icon = 'icons/obj/doors/trapdoors.dmi'
	icon_state = "trapdoor_wood"
	material = "wood"
	override_material = TRUE
	override_opacity = TRUE
	opacity = FALSE
	density = FALSE
	layer = 2.45 // over the ladder or stairwell it covers, under people and things on it
	var/kit_type = /obj/item/trapdoor_kit

/obj/structure/simple_door/key_door/anyone/trapdoor/iron
	name = "iron hatch"
	desc = "An iron hatch set into an opening between two levels. Shut, you can walk across it, and it takes a beating."
	icon_state = "hatch_iron"
	material = "iron"
	kit_type = /obj/item/trapdoor_kit/iron

/obj/structure/simple_door/key_door/anyone/trapdoor/is_trapdoor()
	return TRUE

/obj/structure/simple_door/key_door/anyone/trapdoor/New(_loc, _material = null)
	..(_loc, initial(material))
	basic_icon = initial(icon_state)
	health = (initial(material) == "iron") ? 250 : 120
	initial_health = health
	density = FALSE
	opacity = FALSE

// ---- finding trapdoors ----------------------------------------------------------

/proc/trapdoor_at(turf/T)
	if (!T)
		return null
	for (var/obj/structure/simple_door/D in T)
		if (D.is_trapdoor() && !QDELETED(D))
			return D
	return null

// A trapdoor on T that is shut (or swinging), or null.
/proc/trapdoor_shut_at(turf/T)
	var/obj/structure/simple_door/D = trapdoor_at(T)
	return (D && !D.state) ? D : null

// The trapdoor straight above T, on the next level up.
/proc/trapdoor_above(turf/T)
	if (!T)
		return null
	var/level = multiz_level_above(T.z)
	return level ? trapdoor_at(locate(T.x, T.y, level)) : null

// ---- a floor, not a wall -----------------------------------------------------------

/obj/structure/simple_door/key_door/anyone/trapdoor/Bumped(atom/user)
	return

/obj/structure/simple_door/key_door/anyone/trapdoor/door_opened()
	density = FALSE
	opacity = FALSE
	..()
	update_fitting_overlays()
	trapdoor_recheck_loose_cargo(loc)

// Opening and dismantling remove support without moving the cargo. Replay the
// turf's normal entry checks rather than bypassing covers, ladders or landings.
/proc/trapdoor_recheck_loose_cargo(turf/T)
	if (!istype(T))
		return
	for (var/obj/O in T.contents.Copy())
		if (QDELETED(O) || O.loc != T || O.anchored || (!isitem(O) && !istype(O, /obj/structure)))
			continue
		T.Entered(O)

/obj/structure/simple_door/key_door/anyone/trapdoor/door_closed()
	density = FALSE
	opacity = FALSE
	..()
	update_fitting_overlays()

// Opening it under someone would drop them, so it stays shut while anyone
// stands on it.
/obj/structure/simple_door/key_door/anyone/trapdoor/canOpen(mob/user)
	if (!state && (locate(/mob/living) in loc))
		if (user)
			to_chat(user, SPAN_WARNING((user.loc == loc) ? "You are standing on \the [src]. Step off it first." : "Someone is standing on \the [src]."))
		return FALSE
	return ..()

// ---- above and below ---------------------------------------------------------------

// UP for anyone on its own level, DOWN for anyone on the level below.
/obj/structure/simple_door/key_door/anyone/trapdoor/door_side_of(atom/A)
	var/turf/T = get_turf(A)
	var/turf/D = get_turf(src)
	if (!T || !D)
		return 0
	if (T.z == D.z)
		return UP
	if (T.z == multiz_level_below(D.z))
		return DOWN
	return 0

/obj/structure/simple_door/key_door/anyone/trapdoor/door_opposite_side(side)
	if (side == UP)
		return DOWN
	if (side == DOWN)
		return UP
	return 0

/obj/structure/simple_door/key_door/anyone/trapdoor/door_passage_axis()
	return UP

// Close enough to work: beside it on its own level, or on or beside the tile
// under it on the level below.
/obj/structure/simple_door/key_door/anyone/trapdoor/proc/trapdoor_within_reach(mob/user)
	var/turf/T = get_turf(user)
	var/turf/D = get_turf(src)
	if (!T || !D || max(abs(T.x - D.x), abs(T.y - D.y)) > 1)
		return FALSE
	return T.z == D.z || T.z == multiz_level_below(D.z)

/obj/structure/simple_door/key_door/anyone/trapdoor/door_inner_side()
	if (inner_dir == -1)
		return 0
	if (inner_dir)
		return inner_dir
	if (door_lock && door_lock.side)
		return door_opposite_side(door_lock.side)
	return 0

/obj/structure/simple_door/key_door/anyone/trapdoor/proc/trapdoor_side_name(side)
	return side == DOWN ? "below" : "above"

/obj/structure/simple_door/key_door/anyone/trapdoor/door_choose_inside(mob/user)
	if (!user || QDELETED(src))
		return
	var/above_label = "Above (your side)"
	var/below_label = "Below"
	var/neither_label = "Neither"
	var/choice = player_input(user, "Which side of \the [src] is the inside? Its hinges and fittings go on that side, and it can only be taken out from there.", "Trapdoor facing", above_label, "anything", list(above_label, below_label, neither_label), FALSE)
	if (QDELETED(src))
		return
	if (choice == below_label)
		inner_dir = DOWN
	else if (choice == neither_label)
		inner_dir = -1
	else
		inner_dir = UP
	to_chat(user, SPAN_NOTICE(door_facing_text(user)))

/obj/structure/simple_door/key_door/anyone/trapdoor/door_facing_text(mob/user)
	var/inner = door_inner_side()
	if (!inner)
		return "It has no inside or outside: it can be worked from above or below."
	var/where = ""
	if (user)
		var/side = door_side_of(user)
		if (side == inner)
			where = " You are on the inside."
		else if (side)
			where = " You are on the outside."
	return "Its inside is [trapdoor_side_name(inner)]; the hinges are on that side.[where]"

/obj/structure/simple_door/key_door/anyone/trapdoor/door_show_inside(mob/user)
	return

/obj/structure/simple_door/key_door/anyone/trapdoor/door_side_words(side, mob/user)
	var/mine = user ? door_side_of(user) : 0
	if (mine && mine == side)
		return "on your side"
	if (mine)
		return "on the far side"
	return "on its [side == DOWN ? "under" : "upper"] side"

// ---- fittings ----------------------------------------------------------------------

// Closers, wedges, fusible links, panic bars and door features are for doors.
/obj/structure/simple_door/key_door/anyone/trapdoor/window_door_attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/door_fitting) || istype(W, /obj/item/door_wedge) || istype(W, /obj/item/fusible_link) || istype(W, /obj/item/panic_bar) || istype(W, /obj/item/door_feature))
		to_chat(user, SPAN_WARNING("\The [W] is made for doors, not \the [src]."))
		return TRUE
	return FALSE

// Only what is fitted on the upper face shows from above.
/obj/structure/simple_door/key_door/anyone/trapdoor/update_fitting_overlays()
	if (fitting_images)
		overlays -= fitting_images
	fitting_images = null
	if (state)
		return
	var/list/states = list()
	if (door_lock)
		states += "lock"
	if (door_bar_on(UP))
		states += "bar_[door_bar_kind["[UP]"]]"
	else if (door_has_brackets(UP))
		states += "brackets"
	if (door_bolt_side == UP)
		states += door_bolt_shot ? "bolt_shut" : "bolt_open"
	if (!states.len)
		return
	fitting_images = list()
	for (var/S in states)
		var/image/I = image('icons/obj/doors/trapdoors.dmi', S)
		I.appearance_flags = RESET_COLOR
		fitting_images += I
	overlays += fitting_images

// Taken out whole, back into a kit, from its inside.
/obj/structure/simple_door/key_door/anyone/trapdoor/take_down_door(obj/item/W, mob/living/human/user)
	if (!door_workable())
		to_chat(user, SPAN_WARNING("\The [src] is locked. Unlock it before taking it out."))
		return TRUE
	var/inner = door_inner_side()
	if (inner && door_side_of(user) != inner)
		to_chat(user, SPAN_WARNING("The hinges of \the [src] are on the [trapdoor_side_name(inner)] side. From here you would have to break it."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts taking \the [src] out."), SPAN_NOTICE("You start taking \the [src] out."))
	if (!do_after(user, TRAPDOOR_FIT_TIME * 2, src))
		return TRUE
	if (QDELETED(src) || user.get_active_hand() != W || !door_workable() || (inner && door_side_of(user) != inner) || !trapdoor_within_reach(user))
		return TRUE
	var/turf/unsupported_site = state ? null : loc
	var/turf/T = get_turf(user)
	if (door_lock)
		lock_to_item(door_lock, T)
		door_lock = null
	door_bar_parts_returned(T)
	new kit_type(T)
	user.visible_message(SPAN_NOTICE("[user] takes \the [src] out."), SPAN_NOTICE("You take \the [src] out."))
	qdel(src)
	if (unsupported_site)
		trapdoor_recheck_loose_cargo(unsupported_site)
	return TRUE

/obj/structure/simple_door/key_door/anyone/trapdoor/examine(mob/user, distance = -1)
	. = ..()
	if (!user || get_dist(user, src) > 3)
		return
	if (state)
		to_chat(user, SPAN_NOTICE("It is open."))
	else
		to_chat(user, SPAN_NOTICE("It is shut. You can walk across it."))
	to_chat(user, SPAN_NOTICE(door_facing_text(user)))

// ---- working it from below -------------------------------------------------------

// Things used on the ladder or stairs under a trapdoor that are meant for it.
/proc/trapdoor_reaches_item(obj/item/W, mob/user)
	if (!W)
		return FALSE
	if (istype(W, /obj/item/weapon/key) || istype(W, /obj/item/weapon/storage/belt/keychain) || istype(W, /obj/item/fitted_lock) || istype(W, /obj/item/weapon/lockpick))
		return TRUE
	if (istype(W, /obj/item/door_bar) || istype(W, /obj/item/door_brackets) || istype(W, /obj/item/door_bolt))
		return TRUE
	return user && user.a_intent != I_HARM && (is_tool(W, TOOL_HAMMER) || is_tool(W, TOOL_WRENCH) || is_tool(W, TOOL_SCREWDRIVER) || is_tool(W, TOOL_WIRECUTTER) || is_tool(W, TOOL_KNIFE))

// A hand or an item from below. TRUE when the trapdoor took it.
/proc/trapdoor_from_below(turf/under, mob/user, obj/item/W = null)
	var/obj/structure/simple_door/key_door/anyone/trapdoor/TD = trapdoor_above(under)
	if (!istype(TD) || !ishuman(user) || !TD.trapdoor_within_reach(user))
		return FALSE
	if (W)
		if (!trapdoor_reaches_item(W, user))
			return FALSE
		TD.attackby(W, user)
		return TRUE
	if (TD.state)
		return FALSE
	TD.attack_hand(user)
	return TRUE

// Stairs under a trapdoor pass keys, bars and tools up to it.
/obj/covers/attackby(obj/item/W, mob/user)
	if (stairs && trapdoor_from_below(get_turf(src), user, W))
		return TRUE
	return ..()

// ---- the kit -------------------------------------------------------------------

/obj/item/trapdoor_kit
	name = "wooden trapdoor"
	desc = "A wooden trapdoor ready to lay into an opening between levels: open air over stairs or a ladder, a hole in an upper floor, or a dug hole. Use it on the opening beside you."
	icon = 'icons/obj/doors/trapdoors.dmi'
	icon_state = "kit_wood"
	w_class = ITEM_SIZE_LARGE
	flammable = TRUE
	var/trapdoor_type = /obj/structure/simple_door/key_door/anyone/trapdoor

/obj/item/trapdoor_kit/iron
	name = "iron hatch"
	desc = "An iron hatch ready to lay into an opening between levels: open air over stairs or a ladder, a hole in an upper floor, or a dug hole. Use it on the opening beside you."
	icon_state = "kit_iron"
	flammable = FALSE
	trapdoor_type = /obj/structure/simple_door/key_door/anyone/trapdoor/iron

// Why a trapdoor can't go on T for user, or null.
/proc/trapdoor_fit_refusal(turf/T, mob/user)
	var/turf/here = get_turf(user)
	if (!T || !here || T == here || T.z != here.z || get_dist(here, T) > 1)
		return "Stand beside the opening and use it there."
	if (trapdoor_at(T))
		return "There already is a trapdoor there."
	if (persistence_save_in_progress)
		return "You can't build while the world is saving."
	var/obj/structure/multiz/ladder/ww2/tunneltop/pit/P = locate() in T
	if (P)
		if (P.leaf_covered)
			return "Brush the leaves off the hole first."
		return null
	if (!edge_open_air(T) || !multiz_level_below(T.z))
		return "A trapdoor goes in an opening between levels: open air over stairs or a ladder, a hole in a floor, or a dug hole."
	if (edge_open_air(here))
		return "You need solid footing beside the opening to lay it."
	for (var/atom/movable/A in T)
		if (isliving(A))
			return "Someone is in the way."
	return null

/obj/item/trapdoor_kit/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	var/turf/T = get_turf(A)
	if (!ishuman(user) || !T || (!isturf(A) && !istype(A, /obj/structure/multiz)))
		return ..()
	var/refusal = trapdoor_fit_refusal(T, user)
	if (refusal)
		to_chat(user, SPAN_WARNING(refusal))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts laying \the [src] into the opening."), SPAN_NOTICE("You start laying \the [src] into the opening."))
	if (!do_after(user, TRAPDOOR_FIT_TIME, T))
		return TRUE
	if (QDELETED(src) || user.get_active_hand() != src)
		return TRUE
	refusal = trapdoor_fit_refusal(T, user)
	if (refusal)
		to_chat(user, SPAN_WARNING(refusal))
		return TRUE
	var/obj/structure/simple_door/key_door/anyone/trapdoor/TD = new trapdoor_type(T)
	user.drop_from_inventory(src)
	qdel(src)
	TD.add_fingerprint(user)
	playsound(T, 'sound/machines/door_close.ogg', 50, TRUE)
	user.visible_message(SPAN_NOTICE("[user] lays \a [TD] into the opening."), SPAN_NOTICE("You lay \the [TD] into the opening. Shut, it can be walked on."))
	trapdoor_ask_inside(TD, user)
	return TRUE

// Asked after the build returns, so the click isn't held up by the question.
/proc/trapdoor_ask_inside(obj/structure/simple_door/TD, mob/user)
	set waitfor = FALSE
	TD.door_choose_inside(user)

#undef TRAPDOOR_FIT_TIME
