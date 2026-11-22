// The classic storage strip (the default; a second click or the Settings choice
// opens the storage window) keeps
// the storage window's rules, so picking it never skips them:
// - Taking a thing out of a bag takes the window's move time
//   (storage_window_move_time, to your hands).
// - Things in a container someone else filled show as "?" tiles until you have
//   looked at each one. Looking starts when the strip opens, top first, at
//   storage_search_time per thing, while you stay put with the strip open.
//   Your own worn gear is always known.
// - Opening a crate or closet with unseen things inside (the classic lid tips
//   them onto the floor) takes the time searching them would.

/mob/living/human
	var/tmp/datum/strip_search/strip_search

/mob/living/human/persistence_runtime_var(key)
	return key == "strip_search" || ..()

/client
	// The one-time "you can switch to the storage window" line was shown.
	var/tmp/storage_strip_hint_shown = FALSE

/obj/screen/storage_unseen
	name = "something you haven't looked at"
	icon = 'icons/mob/screen/storage_unseen.dmi'
	icon_state = "unseen3"
	layer = 20
	plane = HUD_PLANE
	var/obj/item/weapon/storage/holder

/obj/screen/storage_unseen/Click()
	if (holder)
		to_chat(usr, SPAN_NOTICE("You haven't looked at that yet. Stay still with \the [holder] open to search it."))
	return TRUE

/obj/screen/storage_unseen/Destroy()
	holder = null
	return ..()

/datum/strip_search
	var/mob/living/human/viewer
	var/obj/item/weapon/storage/holder
	var/obj/item/looking
	var/turf/start_turf
	var/timer
	var/list/placeholders = list()

/datum/strip_search/New(mob/living/human/H)
	viewer = H

/datum/strip_search/Destroy()
	stop()
	clear_placeholders()
	if (viewer && viewer.strip_search == src)
		viewer.strip_search = null
	viewer = null
	return ..()

/datum/strip_search/proc/clear_placeholders()
	if (viewer && viewer.client)
		viewer.client.screen -= placeholders
	for (var/obj/screen/storage_unseen/U in placeholders)
		qdel(U)
	placeholders = list()

/datum/strip_search/proc/stop()
	if (timer)
		deltimer(timer)
	timer = null
	holder = null
	looking = null

/datum/strip_search/proc/begin(obj/item/weapon/storage/S)
	if (holder == S && timer)
		return
	if (holder != S)
		stop()
		holder = S
	start_turf = get_turf(viewer)
	look_next()

/datum/strip_search/proc/look_next()
	looking = null
	timer = null
	if (!holder || QDELETED(holder) || !viewer || QDELETED(viewer))
		stop()
		return
	for (var/obj/item/I in holder.contents)
		if (!storage_item_seen(I, viewer))
			looking = I
			break
	if (!looking)
		holder = null
		return
	timer = addtimer(CALLBACK(src, PROC_REF(finish_look)), storage_search_time(looking), TIMER_STOPPABLE)

/datum/strip_search/proc/finish_look()
	timer = null
	var/mob/living/human/H = viewer
	if (!H || QDELETED(H) || !holder || QDELETED(holder))
		stop()
		return
	if (H.s_active != holder || get_turf(H) != start_turf || H.stat || H.restrained() || H.incapacitated())
		stop()
		return
	var/obj/item/weapon/storage/S = holder
	if (looking && looking.loc == S)
		storage_mark_seen(looking, H)
	storage_strip_apply(H, S)

// Storage that is part of your own worn gear: never searched.
/proc/storage_strip_known(mob/living/human/H, obj/item/weapon/storage/S)
	return S in H.worn_storage_group("all")

// What the viewer hasn't looked at yet in a container the strip shows.
/proc/storage_strip_unseen(mob/living/human/H, obj/item/weapon/storage/S)
	. = list()
	if (storage_strip_known(H, S))
		return
	for (var/obj/item/I in S.contents)
		if (!storage_item_seen(I, H))
			. += I

// Called at the end of show_to(): hide what the viewer hasn't seen behind "?" tiles.
/proc/storage_strip_apply(mob/user, obj/item/weapon/storage/S)
	var/mob/living/human/H = user
	if (!istype(H) || !H.client || !S)
		return
	var/datum/strip_search/SS = H.strip_search
	if (SS)
		SS.clear_placeholders()
	if (storage_strip_known(H, S))
		for (var/obj/item/I in S.contents)
			if (!storage_item_seen(I, H))
				storage_mark_seen(I, H)
		if (SS && SS.holder == S)
			SS.stop()
		return
	var/list/unseen = storage_strip_unseen(H, S)
	if (H.s_active == S)
		for (var/obj/item/I in S.contents)
			if (!(I in unseen))
				H.client.screen |= I
	if (!unseen.len)
		if (SS && SS.holder == S)
			SS.stop()
		return
	if (!SS)
		SS = new /datum/strip_search(H)
		H.strip_search = SS
	for (var/obj/item/I in unseen)
		H.client.screen -= I
		if (!I.screen_loc)
			continue
		var/obj/screen/storage_unseen/U = new
		U.icon_state = "unseen[clamp(I.w_class, 1, 5)]"
		U.screen_loc = I.screen_loc
		U.holder = S
		H.client.screen += U
		SS.placeholders += U
	SS.begin(S)

// Called by hide_from(): the strip closed.
/proc/storage_strip_closed(mob/user, obj/item/weapon/storage/S)
	var/mob/living/human/H = user
	if (!istype(H) || !H.strip_search)
		return
	H.strip_search.clear_placeholders()
	if (H.strip_search.holder == S)
		H.strip_search.stop()

// Waits the storage window's move time before a thing leaves a bag through the
// strip (clicked into a hand or dragged out). FALSE when interrupted.
/proc/storage_strip_take_wait(mob/user, obj/item/I)
	var/obj/item/weapon/storage/S = I.loc
	var/mob/living/human/H = user
	if (istype(S) && !S.storage_contents_accessible())
		return FALSE
	if (!istype(S) || !istype(H) || !H.client)
		return TRUE
	if (!do_after(H, storage_strip_take_time(H, I), I))
		return FALSE
	return I.loc == S && S.storage_contents_accessible()

// Deciseconds to take a thing out of its bag into a hand.
/proc/storage_strip_take_time(mob/living/human/H, obj/item/I)
	var/obj/item/weapon/storage/S = I.loc
	var/from_quick = H.belt && (S == H.belt || S.loc == H.belt)
	var/atom/top = S.loc
	while (top && !ismob(top) && !isturf(top))
		top = top.loc
	var/from_body = ismob(top) && top != H
	return storage_window_move_time(I, from_quick, TRUE, from_body)

// Total look time of what the viewer hasn't seen in a closet.
/proc/storage_strip_closet_search_time(obj/structure/closet/C, mob/user)
	. = 0
	for (var/obj/item/I in C.contents)
		if (!storage_item_seen(I, user))
			. += storage_search_time(I)

// A strip player opening a crate or closet: the classic lid tips everything out,
// so they search first. FALSE when the search was interrupted (the lid stays shut).
/proc/closet_strip_search(obj/structure/closet/C, mob/user)
	var/mob/living/human/H = user
	if (!istype(C) || !C.item_window || C.opened || !istype(H) || !H.client)
		return TRUE
	var/wait = storage_strip_closet_search_time(C, H)
	if (wait <= 0)
		return TRUE
	to_chat(H, SPAN_NOTICE("You search through \the [C] before opening it up."))
	if (!do_after(H, wait, C))
		return FALSE
	for (var/obj/item/I in C.contents)
		storage_mark_seen(I, H)
	return TRUE

// One line, once per connection, the first time a bag opens in the strip.
/proc/storage_strip_hint(mob/user)
	var/client/C = user ? user.client : null
	if (!C || C.storage_strip_hint_shown || C.storage_window_classic || C.modern_ui_failed)
		return
	C.storage_strip_hint_shown = TRUE
	to_chat(user, SPAN_NOTICE("Bags open in the classic strip. Click the bag again to close it, or double-click it to open the storage window. To open the window for every bag, pick it in Character Setup > Settings."))
