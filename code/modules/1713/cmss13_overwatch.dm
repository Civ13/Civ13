// Helmet cameras, the overwatch laptop and machine gun assistant gunners.
// The helmet camera and overwatch idea comes from CM-SS13 (cmss13-devs/cmss13,
// AGPL-3.0): marine helmet cameras watched from the Overwatch console.
// Reimplemented for Civ13 as a carried laptop. The assistant gunner is new.

//////////////////////////////////////////////////////////////////////////////
// HELMET CAMERA: clip it onto the hat or helmet you are wearing.
//////////////////////////////////////////////////////////////////////////////

/obj/item/clothing/head/var/helmet_camera_fitted = FALSE

/obj/item/helmet_camera
	name = "helmet camera"
	desc = "A small camera that clips onto a helmet. An overwatch laptop on your side can watch through it. Use it in hand while wearing headgear to fit it."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "helmet_camera"
	w_class = ITEM_SIZE_SMALL

/obj/item/helmet_camera/attack_self(mob/living/human/user)
	if (!istype(user))
		return
	if (user.fit_helmet_camera())
		qdel(src)

/mob/living/human/proc/fit_helmet_camera()
	var/obj/item/clothing/head/H = head
	if (!istype(H))
		to_chat(src, "<span class='warning'>Put on a hat or helmet first.</span>")
		return FALSE
	if (H.helmet_camera_fitted)
		to_chat(src, "<span class='warning'>\The [H] already has a camera.</span>")
		return FALSE
	H.helmet_camera_fitted = TRUE
	H.verbs |= /obj/item/clothing/head/proc/remove_helmet_camera
	to_chat(src, "<span class='notice'>You clip the camera onto \the [H].</span>")
	return TRUE

/obj/item/clothing/head/proc/remove_helmet_camera()
	set name = "Remove Helmet Camera"
	set category = null
	set src in usr
	if (!helmet_camera_fitted || usr.stat != CONSCIOUS)
		return
	helmet_camera_fitted = FALSE
	verbs -= /obj/item/clothing/head/proc/remove_helmet_camera
	var/obj/item/helmet_camera/C = new(get_turf(usr))
	usr.put_in_hands(C)
	to_chat(usr, "<span class='notice'>You unclip the camera from \the [src].</span>")

/obj/item/clothing/head/after_load()
	..()
	if (helmet_camera_fitted)
		verbs |= /obj/item/clothing/head/proc/remove_helmet_camera

/obj/item/clothing/head/examine(mob/user)
	. = ..()
	if (helmet_camera_fitted)
		to_chat(user, "<span class='notice'>A helmet camera is clipped to it.</span>")

/mob/living/human/proc/has_helmet_camera()
	var/obj/item/clothing/head/H = head
	return istype(H) && H.helmet_camera_fitted

//////////////////////////////////////////////////////////////////////////////
// OVERWATCH LAPTOP: leaders watch their own people's helmet cameras.
//////////////////////////////////////////////////////////////////////////////

/proc/can_use_overwatch(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS)
		return FALSE
	if (team_round_active())
		return H.original_job && (H.original_job.is_officer || H.original_job.is_commander || H.original_job.is_squad_leader)
	return map && H.civilization && H.civilization != "none" && map.is_faction_leader(H, H.civilization)

/proc/overwatch_feed_ok(mob/living/human/viewer, mob/living/human/H)
	return istype(H) && H != viewer && H.stat != DEAD && H.has_helmet_camera() && same_side(viewer, H)

/proc/overwatch_feeds(mob/living/human/viewer)
	var/list/out = list()
	for (var/mob/living/human/H in human_mob_list)
		if (overwatch_feed_ok(viewer, H))
			out += H
	return out

/obj/item/overwatch_laptop
	name = "overwatch laptop"
	desc = "A rugged laptop that shows what your own people's helmet cameras see. Leaders only. Keep it in hand and stand still while you watch."
	icon = 'icons/obj/computers.dmi'
	icon_state = "laptop_close"
	w_class = ITEM_SIZE_NORMAL
	var/tmp/mob/living/human/watcher = null
	var/tmp/mob/living/human/watching = null
	var/tmp/turf/watch_from = null

/obj/item/overwatch_laptop/persistence_runtime_var(key)
	return (key in list("watcher", "watching", "watch_from")) || ..()

/obj/item/overwatch_laptop/attack_self(mob/living/human/user)
	if (!istype(user))
		return
	if (watcher == user)
		stop_watching("You close the feed.")
		return
	if (!can_use_overwatch(user))
		to_chat(user, "<span class='warning'>Only officers, squad leaders and faction leaders can use overwatch.</span>")
		return
	var/list/feeds = overwatch_feeds(user)
	if (!feeds.len)
		to_chat(user, "<span class='warning'>None of your people is wearing a helmet camera.</span>")
		return
	var/list/names = list()
	for (var/mob/living/human/H in feeds)
		names["[H.real_name] ([get_area(H)])"] = H
	var/choice = input(user, "Whose helmet camera do you want to watch?", "Overwatch") as null|anything in names
	if (!choice || loc != user)
		return
	start_watching(user, names[choice])

/obj/item/overwatch_laptop/proc/start_watching(mob/living/human/user, mob/living/human/target)
	if (!overwatch_feed_ok(user, target) || !can_use_overwatch(user))
		return FALSE
	if (watcher && watcher != user)
		stop_watching()
	watcher = user
	watching = target
	watch_from = get_turf(user)
	icon_state = "laptop"
	user.set_using_object(src)
	user.reset_view(target)
	to_chat(user, "<span class='notice'>You watch through [target.real_name]'s helmet camera. Move, or use the laptop again, to stop.</span>")
	return TRUE

/obj/item/overwatch_laptop/proc/feed_ok()
	return watcher && loc == watcher && get_turf(watcher) == watch_from && can_use_overwatch(watcher) && overwatch_feed_ok(watcher, watching)

/obj/item/overwatch_laptop/proc/stop_watching(message = "The feed cuts out.")
	var/mob/living/human/user = watcher
	watcher = null
	watching = null
	watch_from = null
	icon_state = "laptop_close"
	if (user)
		if (user.using_object == src)
			user.unset_using_object()
		user.reset_view(null)
		if (message)
			to_chat(user, "<span class='notice'>[message]</span>")

// Called by the viewer's vision update every life tick.
/obj/item/overwatch_laptop/check_eye(mob/user)
	if (user == watcher && feed_ok())
		return 0
	if (user == watcher)
		stop_watching()
	return -1

/obj/item/overwatch_laptop/dropped(mob/user)
	if (watcher)
		stop_watching()
	return ..()

/obj/item/overwatch_laptop/Destroy()
	if (watcher)
		stop_watching(null)
	return ..()

//////////////////////////////////////////////////////////////////////////////
// ASSISTANT GUNNER: a second friendly soldier next to a crewed mounted gun
// feeds it, so it reloads twice as fast and its barrel heats half as fast.
//////////////////////////////////////////////////////////////////////////////

/proc/mg_crew_ok(mob/living/human/A, mob/living/human/B)
	if (same_side(A, B))
		return TRUE
	// Two people with no faction at all can still crew a gun together.
	if (team_round_active() || !istype(A) || !istype(B) || A == B)
		return FALSE
	return (!A.civilization || A.civilization == "none") && (!B.civilization || B.civilization == "none")

/obj/item/weapon/gun/projectile/automatic/stationary/proc/mg_assistant(mob/living/human/gunner)
	if (!istype(gunner) || !isturf(loc))
		return null
	for (var/mob/living/human/H in range(1, src))
		if (H == gunner || H.stat != CONSCIOUS || H.lying || H.restrained())
			continue
		if (mg_crew_ok(gunner, H))
			return H
	return null

/obj/item/weapon/gun/projectile/automatic/stationary/heat_per_shot()
	. = ..()
	if (. && mg_assistant(used_by_mob))
		. /= 2

/obj/item/weapon/gun/projectile/automatic/stationary/load_ammo(var/obj/item/A, mob/user)
	if (!load_delay || gun_work_busy || !user || world.time < user.next_load)
		return ..()
	if (!mg_assistant(used_by_mob ? used_by_mob : user))
		return ..()
	var/delay = load_delay
	if (!do_after(user, round(delay / 2), src, can_move = TRUE))
		return
	// The halved wait is done; load without a second wait. Nothing below
	// sleeps, so load_delay is back before anything else can read it.
	load_delay = 0
	. = ..()
	load_delay = delay

/obj/item/weapon/gun/projectile/automatic/stationary/examine(mob/user)
	. = ..()
	var/mob/living/human/helper = mg_assistant(used_by_mob)
	if (helper)
		to_chat(user, "<span class='notice'>[helper] is feeding the gun for [used_by_mob].</span>")
