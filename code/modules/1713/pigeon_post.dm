// One physical dispatch, one living bird, one fixed home. No tick processor,
// world scan, pending mail, or references to other atoms in persistence.
#define PIGEON_POST_TRAIN_TIME (5 SECONDS)
#define PIGEON_POST_RELEASE_TIME (3 SECONDS)

/obj/structure/pigeon_loft
	name = "pigeon loft"
	desc = "An outdoor roost for homing pigeons. Bring a live pigeon here and choose Train Homing Pigeon while pulling it. Returned letters land at the foot of the loft."
	icon = 'icons/obj/mail.dmi'
	icon_state = "wood_mailbox_closed"
	density = FALSE
	anchored = TRUE
	not_disassemblable = FALSE
	var/pigeon_loft_id

// Only open dry ground. A wall or roof built over a loft closes the route.
/proc/pigeon_post_open_ground(turf/T)
	if (!istype(T, /turf/floor) || T.density || building_open_turf(T) || is_open_water(T) || los_turf_roofed(T) || (locate(/obj/roof) in T))
		return FALSE
	var/area/A = T.loc
	if (!A || A.location != AREA_OUTSIDE)
		return FALSE
	for (var/obj/O in T)
		if (!QDELETED(O) && O.density)
			return FALSE
	return TRUE

/obj/structure/pigeon_loft/proc/pigeon_loft_open()
	return !QDELETED(src) && anchored && isturf(loc) && pigeon_post_open_ground(loc) && !vessel_building_deck_on(loc)

/obj/structure/pigeon_loft/verb/train_homing_pigeon()
	set name = "Train Homing Pigeon"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || !H.client || H.incapacitated() || !H.Adjacent(src))
		return
	var/mob/living/simple_animal/pigeon/P = H.pulling
	if (!istype(P) || !P.pigeon_post_handler(H) || !P.Adjacent(src) || !pigeon_loft_open())
		to_chat(H, SPAN_WARNING("Bring a live pigeon alongside the loft and keep pulling it. The loft must have clear, open ground."))
		return
	var/client/handler = H.client
	var/turf/training_site = loc
	to_chat(H, SPAN_NOTICE("You begin familiarizing the pigeon with its home loft."))
	if (!do_after(H, PIGEON_POST_TRAIN_TIME, src, needhand = FALSE) || H.client != handler || handler.mob != H || QDELETED(P) || loc != training_site || !H.Adjacent(src) || !P.Adjacent(src) || !P.pigeon_post_handler(H) || !pigeon_loft_open())
		return
	P.pigeon_post_train(src)
	to_chat(H, SPAN_NOTICE("The pigeon now recognizes this loft as home. Take it somewhere else to send a letter back here."))

/mob/living/simple_animal/pigeon
	var/pigeon_home_id
	var/pigeon_home_x
	var/pigeon_home_y
	var/pigeon_home_z

/mob/living/simple_animal/pigeon/proc/pigeon_post_handler(mob/living/human/H)
	return !QDELETED(src) && !QDELETED(H) && !H.incapacitated() && !stat && health > 0 && !client && !key && !buckled && !rider && H.pulling == src && pulledby == H && isturf(H.loc) && isturf(loc) && H.Adjacent(src)

/mob/living/simple_animal/pigeon/proc/pigeon_post_train(obj/structure/pigeon_loft/L)
	if (!L.pigeon_loft_id)
		L.pigeon_loft_id = new_extraction_item_id()
	pigeon_home_id = L.pigeon_loft_id
	pigeon_home_x = L.x
	pigeon_home_y = L.y
	pigeon_home_z = L.z

/mob/living/simple_animal/pigeon/proc/pigeon_post_destination()
	if (!pigeon_home_id || !isturf(loc) || z != pigeon_home_z)
		return null
	var/turf/destination = locate(pigeon_home_x, pigeon_home_y, pigeon_home_z)
	// The saved coordinates resolve only in this region; flight has no distance cap.
	if (!destination || destination == loc)
		return null
	for (var/obj/structure/pigeon_loft/L in destination)
		if (L.pigeon_loft_id == pigeon_home_id && L.pigeon_loft_open())
			return L
	return null

/proc/pigeon_post_letter(obj/item/I)
	if (QDELETED(I))
		return FALSE
	if (istype(I, /obj/item/weapon/paper))
		return TRUE
	var/obj/item/weapon/storage/envelope/E = I
	if (!istype(E) || E.opened || E.knifed || length(E.contents) != 1)
		return FALSE
	var/obj/item/weapon/paper/P = E.contents[1]
	return istype(P) && !QDELETED(P) && P.loc == E

/mob/living/simple_animal/pigeon/attackby(obj/item/I, mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || H.a_intent != I_HELP || (!istype(I, /obj/item/weapon/paper) && !istype(I, /obj/item/weapon/storage/envelope)))
		return ..()
	if (!H.client || !pigeon_post_handler(H) || !H.item_is_in_hands(I))
		to_chat(H, SPAN_WARNING("You must be pulling a live pigeon to send a letter."))
		return TRUE
	if (!pigeon_post_letter(I))
		to_chat(H, SPAN_WARNING("The pigeon can carry one sheet of paper, loose or in a closed envelope."))
		return TRUE
	var/obj/structure/pigeon_loft/L = pigeon_post_destination()
	var/turf/release_site = loc
	if (!L || !pigeon_post_open_ground(release_site))
		to_chat(H, SPAN_WARNING("The pigeon needs a trained home loft on this level and clear ground to take off and land."))
		return TRUE

	var/client/handler = H.client
	to_chat(H, SPAN_NOTICE("You secure the letter and ready the pigeon for release."))
	if (!do_after(H, PIGEON_POST_RELEASE_TIME, src) || H.client != handler || handler.mob != H || H.a_intent != I_HELP || !pigeon_post_handler(H) || loc != release_site || !pigeon_post_open_ground(release_site) || pigeon_post_destination() != L || !pigeon_post_letter(I) || !H.item_is_in_hands(I))
		return TRUE
	if (!pigeon_post_deliver(H, I, L))
		to_chat(H, SPAN_WARNING("The pigeon couldn't take the letter."))
		return TRUE
	visible_message(SPAN_NOTICE("A homing pigeon lands with a letter."))
	to_chat(H, SPAN_NOTICE("The pigeon takes your letter home."))
	return TRUE

// Resolve the flight as one synchronous move. If delivery refuses the
// item, return the bird and leave the letter in the sender's hand.
/mob/living/simple_animal/pigeon/proc/pigeon_post_deliver(mob/living/human/H, obj/item/I, obj/structure/pigeon_loft/L)
	if (!pigeon_post_handler(H) || !L || pigeon_post_destination() != L || !pigeon_post_open_ground(loc) || !pigeon_post_letter(I) || !H.item_is_in_hands(I) || I.loc != H || I.nodrop || I.nodrop_special_check())
		return FALSE
	var/turf/release_site = loc
	var/turf/destination = L.loc
	H.stop_pulling()
	if (!forceMove(destination) || QDELETED(src) || loc != destination)
		return FALSE
	if (!H.transfer_held_item_to(I, destination))
		forceMove(release_site)
		return FALSE
	return TRUE

#undef PIGEON_POST_TRAIN_TIME
#undef PIGEON_POST_RELEASE_TIME
