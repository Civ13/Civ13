// Door fittings (Val, 2026-11-16; plan https://claude.ai/artifact/76THBToa5HeVbgJRRNVnyU).
// Players design a door by fitting parts to it rather than picking from more
// recipes. A door takes at most one closing fitting:
//   counterweight / spring / hydraulic closer - shuts itself once the doorway
//     has been empty for a while (the hydraulic delay is set with a screwdriver);
//   spring hinge - must be held open: it swings shut a moment after nobody
//     stands in the doorway or holds it.
// A wedge keeps a self-closing door open until someone pulls or kicks it out.
// Nothing ticks: an open door with a closer runs one timer, re-armed only while
// someone stands in the doorway. Doors can also be taken down properly while
// unlocked, returning their fittings and most of their material.

#define DOOR_CLOSER_COUNTERWEIGHT "counterweight"
#define DOOR_CLOSER_SPRING "spring"
#define DOOR_CLOSER_HYDRAULIC "hydraulic"
#define DOOR_CLOSER_SPRING_HINGE "spring_hinge"

#define DOOR_HYDRAULIC_MIN 20
#define DOOR_HYDRAULIC_MAX 100
#define DOOR_BLOCKED_RETRY 15		// ds between checks while the doorway is occupied
#define DOOR_FIT_TIME 80
#define DOOR_TAKE_DOWN_TIME 150

/obj/structure/simple_door
	var/door_closer = null		// one of the DOOR_CLOSER_* kinds
	var/closer_delay = 50		// hydraulic closer delay in ds
	var/door_wedge = null		// "wood" or "iron" while wedged open
	var/tmp/close_token = 0
	var/tmp/obj/item/door_hold/door_hold = null
	var/tmp/list/fitting_images = null

// ---- sides and room sealing ------------------------------------------------

// Whether the door closes off its room: shut doors do, open or wedged ones
// leak (insulation and smoke use this).
/obj/structure/simple_door/proc/door_seals_room()
	return !state && density

// The axis people pass along: walls north and south mean an east-west passage.
// Returns NORTH or EAST (the positive direction of the axis).
/obj/structure/simple_door/proc/door_passage_axis()
	var/turf/T = get_turf(src)
	if (!T)
		return NORTH
	if (home_turf_bounds_room(get_step(T, NORTH)) && home_turf_bounds_room(get_step(T, SOUTH)))
		return EAST
	if (home_turf_bounds_room(get_step(T, EAST)) && home_turf_bounds_room(get_step(T, WEST)))
		return NORTH
	return (dir & (EAST|WEST)) ? EAST : NORTH

// Which side of the door an atom is on: the axis direction or its reverse, or
// 0 when standing in the doorway (both sides at once).
/obj/structure/simple_door/proc/door_side_of(atom/A)
	var/turf/T = get_turf(A)
	var/turf/D = get_turf(src)
	if (!T || !D || T == D)
		return 0
	var/axis = door_passage_axis()
	var/delta = (axis == EAST) ? (T.x - D.x) : (T.y - D.y)
	if (!delta)
		delta = (axis == EAST) ? (T.y - D.y) : (T.x - D.x)
	return delta > 0 ? axis : turn(axis, 180)

// ---- locked state, without the side effects of door_hand_locked() ----------

/obj/structure/simple_door/proc/door_lock_engaged()
	return locked

/obj/structure/simple_door/key_door/door_lock_engaged()
	if (istype(src, /obj/structure/simple_door/key_door/custom))
		return locked
	if (istype(src, /obj/structure/simple_door/key_door/anyone))
		return FALSE
	if (istype(src, /obj/structure/simple_door/key_door/faction_door))
		return TRUE
	return keyslot && keyslot.locked

// Fittings change and the door comes down only while it is open or unlocked.
/obj/structure/simple_door/proc/door_workable()
	return state || !door_lock_engaged()

// ---- closing on its own -----------------------------------------------------

/obj/structure/simple_door/proc/door_close_delay()
	switch (door_closer)
		if (DOOR_CLOSER_COUNTERWEIGHT)
			return 60
		if (DOOR_CLOSER_SPRING)
			return 40
		if (DOOR_CLOSER_HYDRAULIC)
			return clamp(closer_delay, DOOR_HYDRAULIC_MIN, DOOR_HYDRAULIC_MAX)
		if (DOOR_CLOSER_SPRING_HINGE)
			return 10
	return 0

/obj/structure/simple_door/proc/door_schedule_close(delay = null)
	if (!door_closer || door_wedge || !state || QDELETED(src))
		return FALSE
	if (isnull(delay))
		delay = door_close_delay()
	var/token = ++close_token
	spawn(max(1, delay))
		door_auto_close(token)
	return TRUE

// Someone or something solid in the doorway keeps the door from shutting.
/obj/structure/simple_door/proc/door_doorway_blocked()
	var/turf/T = get_turf(src)
	if (!T)
		return FALSE
	for (var/atom/movable/AM in T)
		if (AM == src)
			continue
		if (isliving(AM))
			return TRUE
		if (AM.density && isobj(AM) && !istype(AM, /obj/effect))
			return TRUE
	return FALSE

/obj/structure/simple_door/proc/door_held()
	if (door_hold && !door_hold.valid_hold())
		door_hold.release()
	return door_hold

/obj/structure/simple_door/proc/door_auto_close(token)
	if (token != close_token || QDELETED(src) || !state || door_wedge || !door_closer)
		return FALSE
	if (door_held())
		return FALSE	// letting go re-arms the closer
	if (isSwitchingStates || door_doorway_blocked())
		door_schedule_close(DOOR_BLOCKED_RETRY)
		return FALSE
	if (door_closer == DOOR_CLOSER_SPRING || door_closer == DOOR_CLOSER_SPRING_HINGE)
		visible_message(SPAN_NOTICE("\The [src] swings shut with a slam."))
	else if (door_closer == DOOR_CLOSER_COUNTERWEIGHT)
		visible_message(SPAN_NOTICE("\The [src] is pulled shut by its weight."))
	Close()
	return TRUE

// Called once a door has finished opening.
/obj/structure/simple_door/proc/door_opened()
	update_fitting_overlays()
	door_schedule_close()

/obj/structure/simple_door/proc/door_closed()
	close_token++
	if (door_hold)
		door_hold.release(TRUE)
	update_fitting_overlays()

// ---- overlays and examine ---------------------------------------------------

/obj/structure/simple_door/proc/update_fitting_overlays()
	if (fitting_images)
		overlays -= fitting_images
	fitting_images = null
	var/list/states = list()
	if (door_closer)
		states += state ? "closer_[door_closer]_open" : "closer_[door_closer]"
	if (door_wedge && state)
		states += "wedge_[door_wedge]_open"
	if (!states.len)
		return
	fitting_images = list()
	for (var/S in states)
		var/image/I = image('icons/obj/doors/door_fittings.dmi', S)
		I.appearance_flags = RESET_COLOR
		fitting_images += I
	overlays += fitting_images

/obj/structure/simple_door/proc/door_fitting_name(kind)
	switch (kind)
		if (DOOR_CLOSER_COUNTERWEIGHT)
			return "counterweight closer"
		if (DOOR_CLOSER_SPRING)
			return "spring closer"
		if (DOOR_CLOSER_HYDRAULIC)
			return "hydraulic closer"
		if (DOOR_CLOSER_SPRING_HINGE)
			return "spring hinges"
	return "fitting"

/obj/structure/simple_door/examine(mob/user, distance = -1)
	. = ..()
	if (!user || get_dist(user, src) > 3)
		return
	if (door_closer == DOOR_CLOSER_SPRING_HINGE)
		to_chat(user, SPAN_NOTICE("It hangs on spring hinges: it swings shut unless someone holds it open."))
	else if (door_closer == DOOR_CLOSER_HYDRAULIC)
		to_chat(user, SPAN_NOTICE("It has a hydraulic closer, set to shut it after [door_close_delay() / 10] seconds."))
	else if (door_closer)
		to_chat(user, SPAN_NOTICE("It has a [door_fitting_name(door_closer)] and shuts itself after [door_close_delay() / 10] seconds."))
	if (door_wedge && state)
		to_chat(user, SPAN_NOTICE("It is wedged open with a [door_wedge] wedge."))
	var/obj/item/door_hold/hold = door_held()
	if (hold)
		to_chat(user, SPAN_NOTICE("[hold.holder] is holding it open."))

// ---- hands on an open door ----------------------------------------------------

// Returns TRUE when a fitting handled the hand (pulling a wedge, holding the door).
/obj/structure/simple_door/proc/door_fitting_hand(mob/user)
	if (!state || !ishuman(user))
		return FALSE
	var/mob/living/human/H = user
	if (door_wedge)
		pull_door_wedge(H, H.a_intent == I_HARM)
		return TRUE
	if (door_closer && H.a_intent == I_GRAB)
		take_door_hold(H)
		return TRUE
	return FALSE

/obj/structure/simple_door/proc/pull_door_wedge(mob/living/human/user, kick = FALSE)
	if (!door_wedge)
		return FALSE
	var/obj/item/door_wedge/W = door_wedge == "iron" ? new /obj/item/door_wedge/iron(get_turf(src)) : new /obj/item/door_wedge(get_turf(src))
	door_wedge = null
	if (kick || !user || !user.put_in_hands(W))
		if (user)
			user.visible_message(SPAN_NOTICE("[user] kicks the wedge out from under \the [src]."), SPAN_NOTICE("You kick the wedge out."))
	else
		user.visible_message(SPAN_NOTICE("[user] pulls the wedge out from under \the [src]."), SPAN_NOTICE("You pull the wedge out."))
	update_fitting_overlays()
	door_schedule_close()
	return TRUE

/obj/structure/simple_door/proc/take_door_hold(mob/living/human/user)
	var/obj/item/door_hold/hold = door_held()
	if (hold)
		if (hold.holder == user)
			hold.release()
		else
			to_chat(user, SPAN_WARNING("[hold.holder] is already holding the door."))
		return FALSE
	if (user.get_active_hand())
		to_chat(user, SPAN_WARNING("You need a free hand to hold the door."))
		return FALSE
	if (user.stat != CONSCIOUS || user.restrained() || get_dist(user, src) > 1)
		return FALSE
	hold = new /obj/item/door_hold(get_turf(user))
	if (!hold.attach(user, src))
		qdel(hold)
		return FALSE
	close_token++
	user.visible_message(SPAN_NOTICE("[user] holds \the [src] open."), SPAN_NOTICE("You hold the door open. Let go or walk away and it shuts."))
	return TRUE

// The hand holding a door open. Dropping it lets go.
/obj/item/door_hold
	name = "door"
	desc = "You're holding a door open. Drop it or walk away to let it shut."
	icon = 'icons/mob/screen/1713Style.dmi'
	icon_state = "grabbed"
	item_state = "nothing"
	abstract = TRUE
	w_class = ITEM_SIZE_HUGE
	jostle_drop_chance = 100
	should_save = FALSE
	var/tmp/obj/structure/simple_door/door = null
	var/tmp/mob/living/human/holder = null
	var/tmp/released = FALSE

/obj/item/door_hold/proc/attach(mob/living/human/user, obj/structure/simple_door/D)
	if (!user || !D || !user.put_in_active_hand(src))
		return FALSE
	holder = user
	door = D
	D.door_hold = src
	name = D.name
	GLOB.moved_event.register(holder, src, /obj/item/door_hold/proc/holder_moved)
	return TRUE

/obj/item/door_hold/proc/valid_hold()
	if (released || !holder || !door || QDELETED(holder) || QDELETED(door))
		return FALSE
	if (!held_by(holder) || holder.stat != CONSCIOUS || holder.restrained())
		return FALSE
	return door.state && get_dist(holder, door) <= 1 && holder.z == door.z

/obj/item/door_hold/proc/holder_moved(atom/movable/mover, atom/old_loc, atom/new_loc)
	addtimer(CALLBACK(src, PROC_REF(check_hold)), 1)

/obj/item/door_hold/proc/check_hold()
	if (!released && !valid_hold())
		release()

/obj/item/door_hold/can_be_knocked_from_hand(mob/living/human/H)
	return held_by(H)

/obj/item/door_hold/knocked_from_hand(mob/living/human/H)
	release()
	return TRUE

/obj/item/door_hold/dropped(mob/user)
	..()
	release()

/obj/item/door_hold/attack_self(mob/user)
	release()

/obj/item/door_hold/proc/release(silent = FALSE)
	if (released)
		return
	released = TRUE
	var/mob/living/human/H = holder
	var/obj/structure/simple_door/D = door
	if (H)
		GLOB.moved_event.unregister(H, src, /obj/item/door_hold/proc/holder_moved)
	if (D && D.door_hold == src)
		D.door_hold = null
	holder = null
	door = null
	if (H && (H.l_hand == src || H.r_hand == src))
		H.remove_from_mob(src)
		if (!silent)
			to_chat(H, SPAN_NOTICE("You let go of the door."))
	if (D && !QDELETED(D))
		D.door_schedule_close()
	if (!QDELETED(src))
		qdel(src)

/obj/item/door_hold/Destroy()
	release(TRUE)
	return ..()

// ---- fitting items ------------------------------------------------------------

/obj/item/door_fitting
	name = "door fitting"
	desc = "Fits to a door."
	icon = 'icons/obj/doors/door_fittings.dmi'
	w_class = ITEM_SIZE_NORMAL
	var/fitting_kind = null
	var/fit_tool = TOOL_SCREWDRIVER
	var/fit_tool_name = "screwdriver"

/obj/item/door_fitting/counterweight
	name = "counterweight closer"
	desc = "A rope, a pulley and a stone weight. Hung on a door, it pulls the door shut a few seconds after it was opened. Fit it with a hammer."
	icon_state = "item_closer_counterweight"
	fitting_kind = DOOR_CLOSER_COUNTERWEIGHT
	fit_tool = TOOL_HAMMER
	fit_tool_name = "hammer"

/obj/item/door_fitting/spring_closer
	name = "spring closer"
	desc = "A sprung arm that slams a door shut a few seconds after it was opened. Fit it with a screwdriver."
	icon_state = "item_closer_spring"
	fitting_kind = DOOR_CLOSER_SPRING

/obj/item/door_fitting/hydraulic
	name = "hydraulic closer"
	desc = "An oil-damped closer that eases a door shut after a delay you set with a screwdriver. Fit it with a screwdriver."
	icon_state = "item_closer_hydraulic"
	fitting_kind = DOOR_CLOSER_HYDRAULIC

/obj/item/door_fitting/spring_hinge
	name = "spring hinges"
	desc = "Sprung hinges: a door hung on them swings shut as soon as nobody holds it open. Fit them with a screwdriver."
	icon_state = "item_spring_hinge"
	fitting_kind = DOOR_CLOSER_SPRING_HINGE

/proc/door_fitting_item_type(kind)
	switch (kind)
		if (DOOR_CLOSER_COUNTERWEIGHT)
			return /obj/item/door_fitting/counterweight
		if (DOOR_CLOSER_SPRING)
			return /obj/item/door_fitting/spring_closer
		if (DOOR_CLOSER_HYDRAULIC)
			return /obj/item/door_fitting/hydraulic
		if (DOOR_CLOSER_SPRING_HINGE)
			return /obj/item/door_fitting/spring_hinge
	return null

/obj/item/door_wedge
	name = "wooden wedge"
	desc = "A doorstop. Jam it under an open door and the door's closer can't shut it."
	icon = 'icons/obj/doors/door_fittings.dmi'
	icon_state = "item_wedge_wood"
	w_class = ITEM_SIZE_SMALL
	var/wedge_kind = "wood"

/obj/item/door_wedge/iron
	name = "iron wedge"
	icon_state = "item_wedge_iron"
	wedge_kind = "iron"

/proc/door_tool_in_hands(mob/living/human/H, quality)
	if (!H)
		return null
	for (var/obj/item/I in list(H.l_hand, H.r_hand))
		if (is_tool(I, quality))
			return I
	return null

// ---- fitting, removing, adjusting and taking down -------------------------------

// Every door attackby runs this first. TRUE means the item was used up here.
/obj/structure/simple_door/proc/door_fitting_attackby(obj/item/W, mob/living/human/user)
	if (!istype(user))
		return FALSE
	if (istype(W, /obj/item/door_fitting))
		fit_door_fitting(W, user)
		return TRUE
	if (istype(W, /obj/item/door_wedge))
		wedge_door(W, user)
		return TRUE
	if (user.a_intent == I_HARM)
		return FALSE
	if (is_tool(W, TOOL_SCREWDRIVER) || is_tool(W, TOOL_HAMMER) || is_tool(W, TOOL_WRENCH))
		return door_tool_work(W, user)
	return FALSE

/obj/structure/simple_door/proc/fit_door_fitting(obj/item/door_fitting/F, mob/living/human/user)
	if (door_closer)
		to_chat(user, SPAN_WARNING("\The [src] already has [door_fitting_name(door_closer)]. Take them off first."))
		return FALSE
	if (!door_workable())
		to_chat(user, SPAN_WARNING("\The [src] is locked. Unlock or open it first."))
		return FALSE
	if (!door_tool_in_hands(user, F.fit_tool))
		to_chat(user, SPAN_WARNING("Hold a [F.fit_tool_name] in your other hand to fit \the [F]."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts fitting \the [F] to \the [src]."), SPAN_NOTICE("You start fitting \the [F] to \the [src]."))
	if (!do_after(user, DOOR_FIT_TIME, src))
		return FALSE
	if (QDELETED(src) || QDELETED(F) || door_closer || user.get_active_hand() != F || !door_workable())
		return FALSE
	door_closer = F.fitting_kind
	user.drop_from_inventory(F)
	qdel(F)
	playsound(get_turf(src), 'sound/items/Screwdriver.ogg', 60, TRUE)
	user.visible_message(SPAN_NOTICE("[user] fits \the [door_fitting_name(door_closer)] to \the [src]."), SPAN_NOTICE("You fit the [door_fitting_name(door_closer)]."))
	update_fitting_overlays()
	door_schedule_close()
	return TRUE

/obj/structure/simple_door/proc/wedge_door(obj/item/door_wedge/W, mob/living/human/user)
	if (!state)
		to_chat(user, SPAN_WARNING("Open \the [src] first."))
		return FALSE
	if (door_wedge)
		to_chat(user, SPAN_WARNING("\The [src] is already wedged open."))
		return FALSE
	if (!door_closer)
		to_chat(user, SPAN_NOTICE("\The [src] stays open on its own."))
		return FALSE
	door_wedge = W.wedge_kind
	user.drop_from_inventory(W)
	qdel(W)
	close_token++
	if (door_hold)
		door_hold.release(TRUE)
	user.visible_message(SPAN_NOTICE("[user] wedges \the [src] open."), SPAN_NOTICE("You wedge the door open."))
	update_fitting_overlays()
	return TRUE

// Some mapped door types keep their material as a name.
/obj/structure/simple_door/proc/door_material_datum()
	if (istype(material, /material))
		return material
	if (istext(material))
		return get_material_by_name(material)
	return null

/obj/structure/simple_door/proc/door_take_down_tool()
	var/material/M = door_material_datum()
	if (!M || istype(M, /material/wood) || (M.name in list("bamboo", "bone", "paper", "stone", "sandstone", "marble", "cloth", "leather")))
		return TOOL_HAMMER
	return TOOL_WRENCH

/obj/structure/simple_door/proc/door_tool_work(obj/item/W, mob/living/human/user)
	if (door_closer == DOOR_CLOSER_HYDRAULIC && is_tool(W, TOOL_SCREWDRIVER))
		var/choice = player_input(user, "Adjust the closer or take it off?", "Hydraulic closer", null, "anything", list("Adjust delay", "Take it off"), TRUE)
		if (!choice || QDELETED(src) || user.get_active_hand() != W || get_dist(user, src) > 1)
			return TRUE
		if (choice == "Adjust delay")
			var/seconds = player_input(user, "Seconds before it shuts ([DOOR_HYDRAULIC_MIN / 10]-[DOOR_HYDRAULIC_MAX / 10]):", "Hydraulic closer", closer_delay / 10, "num", null, TRUE)
			if (isnull(seconds) || QDELETED(src) || get_dist(user, src) > 1)
				return TRUE
			closer_delay = clamp(round(seconds * 10), DOOR_HYDRAULIC_MIN, DOOR_HYDRAULIC_MAX)
			to_chat(user, SPAN_NOTICE("You set the closer to shut the door after [closer_delay / 10] seconds."))
			return TRUE
		return remove_door_fitting(W, user)
	if (door_closer)
		var/obj/item/door_fitting/kind = door_fitting_item_type(door_closer)
		if (kind && is_tool(W, initial(kind.fit_tool)))
			return remove_door_fitting(W, user)
	if (is_tool(W, door_take_down_tool()))
		return take_down_door(W, user)
	if (door_closer && (is_tool(W, TOOL_SCREWDRIVER) || is_tool(W, TOOL_HAMMER)))
		var/obj/item/door_fitting/fitting = door_fitting_item_type(door_closer)
		to_chat(user, SPAN_WARNING("The [door_fitting_name(door_closer)] come off with a [initial(fitting.fit_tool_name)]."))
		return TRUE
	return FALSE

/obj/structure/simple_door/proc/remove_door_fitting(obj/item/W, mob/living/human/user)
	if (!door_workable())
		to_chat(user, SPAN_WARNING("\The [src] is locked. Unlock or open it first."))
		return TRUE
	var/kind = door_closer
	user.visible_message(SPAN_NOTICE("[user] starts taking \the [door_fitting_name(kind)] off \the [src]."), SPAN_NOTICE("You start taking the [door_fitting_name(kind)] off."))
	if (!do_after(user, DOOR_FIT_TIME / 2, src))
		return TRUE
	if (QDELETED(src) || door_closer != kind || user.get_active_hand() != W || !door_workable())
		return TRUE
	door_closer = null
	close_token++
	if (door_hold)
		door_hold.release(TRUE)
	var/fitting_type = door_fitting_item_type(kind)
	if (fitting_type)
		var/obj/item/I = new fitting_type(get_turf(user))
		user.put_in_hands(I)
	if (door_wedge)
		pull_door_wedge(null)
	playsound(get_turf(src), 'sound/items/Screwdriver.ogg', 60, TRUE)
	to_chat(user, SPAN_NOTICE("You take the [door_fitting_name(kind)] off."))
	update_fitting_overlays()
	return TRUE

// Sheets a whole door is worth: double doors take twice the material.
/obj/structure/simple_door/proc/door_material_sheets()
	return findtext("[type]", "doubledoor") ? 10 : 5

/obj/structure/simple_door/proc/door_take_down_refund()
	var/health_share = initial_health > 0 ? clamp(health / initial_health, 0, 1) : 1
	return max(1, round(door_material_sheets() * 0.75 * health_share))

/obj/structure/simple_door/proc/take_down_door(obj/item/W, mob/living/human/user)
	if (!door_workable())
		to_chat(user, SPAN_WARNING("\The [src] is locked. Unlock it before taking it down."))
		return TRUE
	var/material/M = door_material_datum()
	if (istype(src, /obj/structure/simple_door/key_door/faction_door) || istype(src, /obj/structure/simple_door/blast) || !M)
		to_chat(user, SPAN_WARNING("\The [src] can't be taken down by hand."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts taking \the [src] off its hinges."), SPAN_NOTICE("You start taking the door down."))
	if (!do_after(user, DOOR_TAKE_DOWN_TIME, src))
		return TRUE
	if (QDELETED(src) || user.get_active_hand() != W || !door_workable())
		return TRUE
	var/turf/T = get_turf(src)
	var/sheets = door_take_down_refund()
	for (var/i in 1 to sheets)
		M.place_sheet(T)
	if (door_closer)
		var/fitting_type = door_fitting_item_type(door_closer)
		if (fitting_type)
			new fitting_type(T)
		door_closer = null
	if (door_wedge)
		pull_door_wedge(null)
	user.visible_message(SPAN_NOTICE("[user] takes \the [src] down."), SPAN_NOTICE("You take the door down and salvage [sheets] sheets."))
	qdel(src)
	return TRUE

// A smashed or burnt door drops its wedge; its closer is wrecked with it.
/obj/structure/simple_door/proc/door_fittings_destroyed()
	close_token++
	if (door_hold)
		door_hold.release(TRUE)
	if (door_wedge)
		var/turf/T = get_turf(src)
		if (T)
			if (door_wedge == "iron")
				new /obj/item/door_wedge/iron(T)
			else
				new /obj/item/door_wedge(T)
		door_wedge = null

#undef DOOR_CLOSER_COUNTERWEIGHT
#undef DOOR_CLOSER_SPRING
#undef DOOR_CLOSER_HYDRAULIC
#undef DOOR_CLOSER_SPRING_HINGE
#undef DOOR_HYDRAULIC_MIN
#undef DOOR_HYDRAULIC_MAX
#undef DOOR_BLOCKED_RETRY
#undef DOOR_FIT_TIME
#undef DOOR_TAKE_DOWN_TIME
