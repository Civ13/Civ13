// Peep-holes, judas hatches, mail slots and pet doors (Val, 2026-11-16).
// Each is fitted with a screwdriver in the other hand, from the side it
// serves, and every feature on a door serves the same side (normally the
// inside):
//   peep-hole   - from its side, look through at whoever is outside; the other
//                 side sees nothing.
//   judas hatch - a sliding hatch worked from its side. Open, both sides can
//                 see and talk through it, though the door stays shut.
//   mail slot   - letters, papers, photos and other tiny flat things posted
//                 from the far side drop through to the slot's side, into a
//                 basket or mailbox there if there is one.
//   pet door    - small animals (cats, dogs, poultry and the like) pass
//                 through the shut door; people never do. It locks from its
//                 side.
// A screwdriver from the features' side takes one off again. Windows and
// shutters don't take them.

#define DOOR_FEATURE_PEEPHOLE 1
#define DOOR_FEATURE_HATCH 2
#define DOOR_FEATURE_MAIL 4
#define DOOR_FEATURE_PET 8

/obj/structure/simple_door
	var/door_features = 0			// DOOR_FEATURE_* bits
	var/door_feature_side = 0		// the side they serve
	var/judas_open = FALSE
	var/pet_door_locked = FALSE

/obj/item/door_feature
	icon = 'icons/obj/doors/door_features.dmi'
	w_class = ITEM_SIZE_SMALL
	var/feature = 0

/obj/item/door_feature/peephole
	name = "peep-hole"
	desc = "A brass door viewer with a wide lens. Fitted to a door with a screwdriver, it lets you see who is on the other side without opening up, and they can't see you."
	icon_state = "item_peephole"
	feature = DOOR_FEATURE_PEEPHOLE

/obj/item/door_feature/judas_hatch
	name = "judas hatch"
	desc = "A small sliding hatch for a door. Fitted with a screwdriver, it slides open from your side so you can see and speak to a caller while the door stays shut."
	icon_state = "item_judas_hatch"
	feature = DOOR_FEATURE_HATCH

/obj/item/door_feature/mail_slot
	name = "mail slot"
	desc = "A brass letter plate with a sprung flap. Fitted with a screwdriver, it lets letters and papers be posted through the shut door to your side."
	icon_state = "item_mail_slot"
	feature = DOOR_FEATURE_MAIL

/obj/item/door_feature/pet_door
	name = "pet door"
	desc = "A small framed flap for the foot of a door. Fitted with a screwdriver, it lets cats, small dogs and fowl through the shut door, and locks from your side."
	icon_state = "item_pet_door"
	feature = DOOR_FEATURE_PET

/proc/door_feature_item_type(feature)
	switch (feature)
		if (DOOR_FEATURE_PEEPHOLE)
			return /obj/item/door_feature/peephole
		if (DOOR_FEATURE_HATCH)
			return /obj/item/door_feature/judas_hatch
		if (DOOR_FEATURE_MAIL)
			return /obj/item/door_feature/mail_slot
		if (DOOR_FEATURE_PET)
			return /obj/item/door_feature/pet_door
	return null

/proc/door_feature_name(feature)
	switch (feature)
		if (DOOR_FEATURE_PEEPHOLE)
			return "peep-hole"
		if (DOOR_FEATURE_HATCH)
			return "judas hatch"
		if (DOOR_FEATURE_MAIL)
			return "mail slot"
		if (DOOR_FEATURE_PET)
			return "pet door"
	return "fitting"

/obj/structure/simple_door/proc/door_has_feature(feature)
	return (door_features & feature) ? TRUE : FALSE

/obj/structure/simple_door/proc/door_on_feature_side(mob/user)
	return door_feature_side && user && door_side_of(user) == door_feature_side

// ---- fitting and removing ----------------------------------------------------------

/obj/structure/simple_door/proc/fit_door_feature(obj/item/door_feature/F, mob/living/human/user)
	if (is_window_door())
		to_chat(user, SPAN_WARNING("\The [F] is made for doors, not \the [src]."))
		return FALSE
	if (door_has_feature(F.feature))
		to_chat(user, SPAN_WARNING("\The [src] already has a [door_feature_name(F.feature)]."))
		return FALSE
	var/side = door_side_of(user)
	if (!side)
		to_chat(user, SPAN_WARNING("Stand on the side of \the [src] that \the [F] should serve."))
		return FALSE
	if (door_features && door_feature_side && side != door_feature_side)
		to_chat(user, SPAN_WARNING("The other fittings on \the [src] serve the far side. Fit this one from there too."))
		return FALSE
	if (!door_tool_in_hands(user, TOOL_SCREWDRIVER))
		to_chat(user, SPAN_WARNING("Hold a screwdriver in your other hand to fit \the [F]."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts fitting \a [F] to \the [src]."), SPAN_NOTICE("You start fitting \the [F] to your side of \the [src]."))
	if (!do_after(user, 60, src))
		return FALSE
	if (QDELETED(src) || QDELETED(F) || user.get_active_hand() != F || door_has_feature(F.feature) || door_side_of(user) != side)
		return FALSE
	door_features |= F.feature
	door_feature_side = side
	user.drop_from_inventory(F)
	qdel(F)
	playsound(get_turf(src), 'sound/items/Screwdriver.ogg', 60, TRUE)
	to_chat(user, SPAN_NOTICE("You fit the [door_feature_name(F.feature)]. [door_feature_hint(F.feature)]"))
	update_fitting_overlays()
	return TRUE

/obj/structure/simple_door/proc/door_feature_hint(feature)
	switch (feature)
		if (DOOR_FEATURE_PEEPHOLE)
			return "Alt-click the shut door, or use Look Through, to see out."
		if (DOOR_FEATURE_HATCH)
			return "Use Slide Hatch to open and shut it."
		if (DOOR_FEATURE_MAIL)
			return "Post goes through from the far side to yours."
		if (DOOR_FEATURE_PET)
			return "Use Lock Pet Door to keep animals in or out."
	return ""

/obj/structure/simple_door/proc/remove_door_feature(feature, obj/item/W, mob/living/human/user)
	if (!door_has_feature(feature))
		return FALSE
	if (!door_on_feature_side(user))
		to_chat(user, SPAN_WARNING("The screws of the [door_feature_name(feature)] are on the far side."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts taking the [door_feature_name(feature)] off \the [src]."), SPAN_NOTICE("You start taking the [door_feature_name(feature)] off."))
	if (!do_after(user, 40, src))
		return FALSE
	if (QDELETED(src) || !door_has_feature(feature) || user.get_active_hand() != W || !door_on_feature_side(user))
		return FALSE
	door_features &= ~feature
	if (feature == DOOR_FEATURE_HATCH)
		set_judas_open(FALSE)
	if (feature == DOOR_FEATURE_PET)
		pet_door_locked = FALSE
	if (!door_features)
		door_feature_side = 0
	var/item_type = door_feature_item_type(feature)
	user.put_in_hands(new item_type(get_turf(user)))
	playsound(get_turf(src), 'sound/items/Screwdriver.ogg', 60, TRUE)
	update_fitting_overlays()
	return TRUE

// A screwdriver from the features' side: pick which to take off. TRUE when handled.
/obj/structure/simple_door/proc/door_feature_screwdriver(obj/item/W, mob/living/human/user)
	if (!door_features || !door_on_feature_side(user))
		return FALSE
	var/list/choices = list()
	for (var/feature in list(DOOR_FEATURE_PEEPHOLE, DOOR_FEATURE_HATCH, DOOR_FEATURE_MAIL, DOOR_FEATURE_PET))
		if (door_has_feature(feature))
			choices[door_feature_name(feature)] = feature
	choices["Something else"] = 0
	var/choice = player_input(user, "Take which fitting off \the [src]?", "Door fittings", null, "anything", choices, TRUE)
	if (!choice || !choices[choice] || QDELETED(src) || user.get_active_hand() != W || get_dist(user, src) > 1)
		return choice == "Something else" ? FALSE : TRUE
	remove_door_feature(choices[choice], W, user)
	return TRUE

// Items used on a door: fitting a feature, posting through the slot. TRUE when handled.
/obj/structure/simple_door/proc/door_feature_attackby(obj/item/W, mob/living/human/user)
	if (istype(W, /obj/item/door_feature))
		fit_door_feature(W, user)
		return TRUE
	if (door_has_feature(DOOR_FEATURE_MAIL) && !state && door_mail_postable(W) && door_side_of(user) && !door_on_feature_side(user))
		post_through_door(W, user)
		return TRUE
	if (user.a_intent != I_HARM && is_tool(W, TOOL_SCREWDRIVER) && door_feature_screwdriver(W, user))
		return TRUE
	return FALSE

// ---- mail slot ------------------------------------------------------------------------

/proc/door_mail_postable(obj/item/I)
	if (!I)
		return FALSE
	if (istype(I, /obj/item/weapon/paper) || istype(I, /obj/item/weapon/paper_bundle) || istype(I, /obj/item/weapon/photo))
		return TRUE
	return I.w_class <= ITEM_SIZE_TINY

/obj/structure/simple_door/proc/post_through_door(obj/item/I, mob/living/human/user)
	var/turf/drop = get_step(src, door_feature_side)
	if (!drop || drop.density)
		to_chat(user, SPAN_WARNING("Something on the other side blocks the slot."))
		return FALSE
	user.drop_from_inventory(I)
	var/obj/receiver = door_mail_receiver(drop, I)
	if (receiver)
		I.forceMove(receiver)
	else
		I.forceMove(drop)
	playsound(get_turf(src), 'sound/machines/click.ogg', 30, TRUE)
	user.visible_message(SPAN_NOTICE("[user] posts \the [I] through \the [src]."), SPAN_NOTICE("You push \the [I] through the mail slot."))
	return TRUE

// A wall mailbox, crate or basket standing under the slot catches the post.
/proc/door_mail_receiver(turf/T, obj/item/I)
	for (var/obj/structure/closet/crate/C in T)
		if (C.opened || !closet_has_room(C, I, quiet = TRUE))
			continue
		return C
	for (var/obj/item/weapon/storage/S in T)
		if (S.contents.len < S.storage_slots || !S.storage_slots)
			return S
	return null

// ---- judas hatch ----------------------------------------------------------------------

/obj/structure/simple_door/proc/set_judas_open(open)
	judas_open = open ? TRUE : FALSE
	if (!state)
		opacity = (judas_open || override_opacity) ? FALSE : TRUE
	update_fitting_overlays()

/obj/structure/simple_door/proc/slide_judas_hatch(mob/user)
	if (!door_has_feature(DOOR_FEATURE_HATCH))
		return FALSE
	if (!door_on_feature_side(user))
		to_chat(user, SPAN_WARNING("The hatch slides from the other side."))
		return FALSE
	if (state)
		to_chat(user, SPAN_WARNING("The door is open; there is no need for the hatch."))
		return FALSE
	set_judas_open(!judas_open)
	playsound(get_turf(src), 'sound/machines/click.ogg', 40, TRUE)
	user.visible_message(SPAN_NOTICE("[user] slides the hatch in \the [src] [judas_open ? "open" : "shut"]."), SPAN_NOTICE("You slide the hatch [judas_open ? "open" : "shut"]."))
	return TRUE

// Shutting the door shuts out the view unless the hatch is open.
/obj/structure/simple_door/proc/door_features_closed()
	if (judas_open && !override_opacity)
		opacity = FALSE

// ---- pet door -------------------------------------------------------------------------

/proc/door_pet_sized(atom/movable/A)
	if (!isliving(A) || ishuman(A))
		return FALSE
	var/mob/living/L = A
	if (L.mob_size <= MOB_SMALL)
		return TRUE
	if (istype(L, /mob/living/simple_animal/pet/cat))
		return TRUE
	if (istype(L, /mob/living/simple_animal/complex_animal/dog) && !istype(L, /mob/living/simple_animal/complex_animal/dog/wolf))
		return TRUE
	return FALSE

/obj/structure/simple_door/proc/pet_door_admits(atom/movable/A)
	return door_has_feature(DOOR_FEATURE_PET) && !pet_door_locked && door_pet_sized(A)

/obj/structure/simple_door/proc/toggle_pet_door_lock(mob/user)
	if (!door_has_feature(DOOR_FEATURE_PET))
		return FALSE
	if (!door_on_feature_side(user))
		to_chat(user, SPAN_WARNING("The pet door's catch is on the other side."))
		return FALSE
	pet_door_locked = !pet_door_locked
	playsound(get_turf(src), 'sound/machines/click.ogg', 30, TRUE)
	to_chat(user, SPAN_NOTICE("You [pet_door_locked ? "lock" : "unlock"] the pet door."))
	update_fitting_overlays()
	return TRUE

// ---- looking through --------------------------------------------------------------

// Whether user can look through the shut door right now.
/obj/structure/simple_door/proc/door_can_look_through(mob/user)
	if (state || !user || get_dist(user, src) > 1)
		return FALSE
	if (judas_open)
		return door_side_of(user) != 0
	return door_has_feature(DOOR_FEATURE_PEEPHOLE) && door_on_feature_side(user)

// The tile a look through the door shows: the one beyond it from user.
/obj/structure/simple_door/proc/door_view_turf(mob/user)
	var/side = door_side_of(user)
	return side ? get_step(src, turn(side, 180)) : null

/mob/living/human/var/tmp/obj/structure/simple_door/peeping_through = null

/mob/living/human/persistence_runtime_var(key)
	return key == "peeping_through" || ..()

/mob/living/human/proc/start_peeping(obj/structure/simple_door/D)
	if (!client || !D || !D.door_can_look_through(src))
		to_chat(src, SPAN_WARNING("You can't see through \the [D]."))
		return FALSE
	if (looking_up_at)
		stop_looking_up(TRUE)
	if (looking)
		look_into_distance(src, FALSE)
	peeping_through = D
	client.perspective = EYE_PERSPECTIVE
	client.eye = D.door_view_turf(src)
	to_chat(src, SPAN_NOTICE("You look through \the [D]. Move to look away."))
	return TRUE

/mob/living/human/proc/stop_peeping()
	if (!peeping_through)
		return
	peeping_through = null
	if (client && client.eye != src && !looking_up_at && !laddervision)
		client.perspective = MOB_PERSPECTIVE
		client.eye = src

/mob/living/human/proc/peep_vision()
	if (!peeping_through)
		return
	if (!client || QDELETED(peeping_through) || stat || !peeping_through.door_can_look_through(src))
		stop_peeping()
		return
	client.perspective = EYE_PERSPECTIVE
	client.eye = peeping_through.door_view_turf(src)

/mob/living/human/handle_vision()
	. = ..()
	peep_vision()

// ---- hands and verbs -----------------------------------------------------------------

/obj/structure/simple_door/AltClick(mob/user)
	if (ishuman(user) && door_can_look_through(user))
		var/mob/living/human/H = user
		if (H.peeping_through == src)
			H.stop_peeping()
		else
			H.start_peeping(src)
		return
	return ..()

/obj/structure/simple_door/verb/door_look_through()
	set name = "Look Through"
	set category = null
	set src in view(1)
	if (ishuman(usr))
		var/mob/living/human/H = usr
		H.start_peeping(src)

/obj/structure/simple_door/verb/door_slide_hatch()
	set name = "Slide Hatch"
	set category = null
	set src in view(1)
	if (ishuman(usr) && !usr.incapacitated())
		if (!door_has_feature(DOOR_FEATURE_HATCH))
			to_chat(usr, SPAN_WARNING("\The [src] has no hatch."))
			return
		slide_judas_hatch(usr)

/obj/structure/simple_door/verb/door_pet_lock()
	set name = "Lock Pet Door"
	set category = null
	set src in view(1)
	if (ishuman(usr) && !usr.incapacitated())
		if (!door_has_feature(DOOR_FEATURE_PET))
			to_chat(usr, SPAN_WARNING("\The [src] has no pet door."))
			return
		toggle_pet_door_lock(usr)

// ---- display and wreckage ----------------------------------------------------------

/obj/structure/simple_door/proc/door_feature_overlay_states()
	. = list()
	if (state || !door_features)
		return
	if (door_has_feature(DOOR_FEATURE_PEEPHOLE))
		. += "peephole"
	if (door_has_feature(DOOR_FEATURE_HATCH))
		. += judas_open ? "judas_hatch_open" : "judas_hatch"
	if (door_has_feature(DOOR_FEATURE_MAIL))
		. += "mail_slot"
	if (door_has_feature(DOOR_FEATURE_PET))
		. += pet_door_locked ? "pet_door_locked" : "pet_door"

/obj/structure/simple_door/proc/door_feature_examine(mob/user)
	if (!door_features)
		return
	var/list/names = list()
	for (var/feature in list(DOOR_FEATURE_PEEPHOLE, DOOR_FEATURE_HATCH, DOOR_FEATURE_MAIL, DOOR_FEATURE_PET))
		if (door_has_feature(feature))
			names += door_feature_name(feature)
	to_chat(user, SPAN_NOTICE("It has [english_list(names)], serving [door_side_words(door_feature_side, user)]."))
	if (door_has_feature(DOOR_FEATURE_HATCH) && judas_open)
		to_chat(user, SPAN_NOTICE("The hatch is open."))
	if (door_has_feature(DOOR_FEATURE_PET) && pet_door_locked)
		to_chat(user, SPAN_NOTICE("The pet door is locked."))

/obj/structure/simple_door/proc/door_feature_parts_returned(turf/T)
	if (!T || !door_features)
		return
	for (var/feature in list(DOOR_FEATURE_PEEPHOLE, DOOR_FEATURE_HATCH, DOOR_FEATURE_MAIL, DOOR_FEATURE_PET))
		if (door_has_feature(feature))
			var/item_type = door_feature_item_type(feature)
			new item_type(T)
	door_features = 0
	door_feature_side = 0

#undef DOOR_FEATURE_PEEPHOLE
#undef DOOR_FEATURE_HATCH
#undef DOOR_FEATURE_MAIL
#undef DOOR_FEATURE_PET
