// Bipods, ammo counts, floor exercises and the lockbox, adapted from CM-SS13
// (cmss13-devs/cmss13, AGPL-3.0): gun_attachables.dm (bipod), the gun ammo
// readouts, human/exercise.dm and storage/lockbox.dm. Reimplemented for Civ13.

//////////////////////////////////////////////////////////////////////////////
// BIPOD: an underbarrel rest. Prone, or still behind cover, it steadies the gun.
//////////////////////////////////////////////////////////////////////////////

#define BIPOD_SETTLE_TIME 10 // deciseconds standing still before the legs bite
#define BIPOD_RECOIL_MULT 0.4
#define BIPOD_ACCURACY_MULT 0.75

/obj/item/weapon/attachment/under/bipod
	name = "bipod"
	desc = "A folding two-legged rest for a rifle or machine gun. Lie prone, or stand still behind sandbags, a table, a barricade or a wall, and it steadies your aim and soaks up recoil. It only gets in the way on the move. Fit it at a firearm bench."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "bipod"
	fits = list("rifle", "mg", "machinegun")
	ergonomics = 0.95
	weight = 0.4
	value = 10

/obj/item/weapon/gun/proc/has_bipod()
	return istype(under, /obj/item/weapon/attachment/under/bipod)

// Something solid in front of the shooter to rest the legs on.
/proc/bipod_rest_ahead(mob/user)
	var/turf/here = get_turf(user)
	if (!here)
		return FALSE
	for (var/obj/structure/window/barrier/B in here)
		if (B.dir == user.dir)
			return TRUE
	var/turf/front = get_step(here, user.dir)
	if (!front)
		return FALSE
	if (front.density)
		return TRUE
	for (var/obj/structure/S in front)
		if (S.density || istype(S, /obj/structure/table) || istype(S, /obj/structure/window/barrier))
			return TRUE
	return FALSE

/obj/item/weapon/gun/proc/bipod_braced(mob/user)
	if (!has_bipod() || !user || !isturf(user.loc))
		return FALSE
	if (user.last_movement >= 0 && world.time - user.last_movement < BIPOD_SETTLE_TIME)
		return FALSE
	return user.lying || user.prone || bipod_rest_ahead(user)

/obj/item/weapon/gun/proc/bipod_recoil_mult(mob/user)
	return bipod_braced(user) ? BIPOD_RECOIL_MULT : 1

/obj/item/weapon/gun/proc/bipod_accuracy_mult(mob/user)
	return bipod_braced(user) ? BIPOD_ACCURACY_MULT : 1

/obj/item/weapon/gun/examine(mob/user)
	..()
	if (has_bipod())
		to_chat(user, "<span class='notice'>Its bipod [bipod_braced(user) && loc == user ? "is braced" : "steadies it when you lie prone or keep still behind cover"].</span>")

#undef BIPOD_SETTLE_TIME
#undef BIPOD_RECOIL_MULT
#undef BIPOD_ACCURACY_MULT

//////////////////////////////////////////////////////////////////////////////
// AMMO COUNT: the holder can count the rounds; reloading pops up the count.
//////////////////////////////////////////////////////////////////////////////

/obj/item/weapon/gun/projectile/proc/ammo_count_text()
	var/rounds = getAmmo()
	if (!rounds)
		return "empty"
	return "[rounds] round\s[chambered ? ", one chambered" : ""]"

/obj/item/weapon/gun/projectile/examine(mob/user)
	..()
	if (ismob(user) && loc == user)
		to_chat(user, "<span class='notice'>You count [ammo_count_text()].</span>")

/obj/item/weapon/gun/projectile/load_ammo(obj/item/A, mob/user)
	var/before = getAmmo()
	. = ..()
	var/after = getAmmo()
	if (user && after != before && loc == user)
		balloon_alert(user, "[after] round\s")

//////////////////////////////////////////////////////////////////////////////
// FLOOR EXERCISES: push-ups and sit-ups anywhere, on the same fatigue budget as
// the training equipment but with a lower ceiling.
//////////////////////////////////////////////////////////////////////////////

#define FLOOR_EXERCISE_CAP 100
#define FLOOR_EXERCISE_RATE 0.003
#define FLOOR_EXERCISE_REPS 3
#define FLOOR_EXERCISE_REP_TIME 80

/mob/living/human/var/tmp/floor_exercise_busy = FALSE

/mob/living/human/persistence_runtime_var(key)
	return key == "floor_exercise_busy" || ..()

/proc/floor_exercise_skill(kind)
	return kind == "sit-ups" ? "stamina" : "strength"

/mob/living/human/proc/floor_exercise_ready(kind, feedback = FALSE)
	if (stat != CONSCIOUS || !can_use_hands() || buckled)
		if (feedback)
			to_chat(src, "You must be conscious, free and able to use your hands to exercise.")
		return FALSE
	if (!istype(loc, /turf/floor) || istype(loc, /turf/floor/beach/water))
		if (feedback)
			to_chat(src, "You need dry floor or ground to exercise on.")
		return FALSE
	if (exercise_equipment)
		if (feedback)
			to_chat(src, "Finish your set on the training equipment or use Stop Exercise first.")
		return FALSE
	recover_exercise()
	if (exercise_fatigue >= 6)
		if (feedback)
			to_chat(src, "You are too fatigued to exercise. Rest; one fatigue point recovers per running-server minute.")
		return FALSE
	var/skill = floor_exercise_skill(kind)
	if (stats[skill][1] < 10)
		if (feedback)
			to_chat(src, "Your current [skill] is too low to train.")
		return FALSE
	if (stats[skill][1] >= FLOOR_EXERCISE_CAP || stats[skill][2] >= FLOOR_EXERCISE_CAP)
		if (feedback)
			to_chat(src, "Your [skill] is past what [kind] can build. Use training equipment to go further.")
		return FALSE
	return TRUE

/mob/living/human/proc/do_floor_exercise(kind)
	if (floor_exercise_busy || !floor_exercise_ready(kind, TRUE))
		return FALSE
	floor_exercise_busy = TRUE
	var/turf/start = loc
	visible_message("<span class='notice'>[src] drops to the ground and starts doing [kind].</span>", "<span class='notice'>You start a set of [kind]. Stay still for [FLOOR_EXERCISE_REPS] repetitions.</span>")
	for (var/rep = 1 to FLOOR_EXERCISE_REPS)
		if (!do_after(src, FLOOR_EXERCISE_REP_TIME, src) || loc != start || !floor_exercise_ready(kind))
			floor_exercise_busy = FALSE
			to_chat(src, "<span class='warning'>You stop your [kind]. An unfinished set gives no training.</span>")
			return FALSE
		if (rep < FLOOR_EXERCISE_REPS)
			to_chat(src, "Repetition [rep]/[FLOOR_EXERCISE_REPS] done.")
	var/skill = floor_exercise_skill(kind)
	var/list/values = stats[skill]
	var/rate = FLOOR_EXERCISE_RATE * (1 - exercise_fatigue / 8) * (values[2] >= 50 ? 0.5 : 1)
	var/steps = max(1, round(rate * 1000 + 0.00001))
	adaptStat(skill, (steps + 0.001) * 0.15)
	values[1] = min(FLOOR_EXERCISE_CAP, values[1])
	values[2] = min(FLOOR_EXERCISE_CAP, values[2])
	exercise_fatigue = min(6, exercise_fatigue + 2)
	floor_exercise_busy = FALSE
	to_chat(src, "<span class='notice'>Set of [kind] complete. Fatigue: [exercise_fatigue]/6.</span>")
	return TRUE

/mob/living/human/verb/floor_exercise()
	set name = "Floor Exercise"
	set desc = "Do a set of push-ups (strength) or sit-ups (stamina) wherever you stand."
	set category = "IC"
	if (usr != src)
		return
	var/choice = WWinput(src, "Push-ups train strength and sit-ups train stamina, up to [FLOOR_EXERCISE_CAP]. A set is three repetitions; stay still until it finishes.", "Floor Exercise", "Cancel", list("Push-ups", "Sit-ups", "Cancel"))
	if (choice == "Push-ups")
		do_floor_exercise("push-ups")
	else if (choice == "Sit-ups")
		do_floor_exercise("sit-ups")

#undef FLOOR_EXERCISE_CAP
#undef FLOOR_EXERCISE_RATE
#undef FLOOR_EXERCISE_REPS
#undef FLOOR_EXERCISE_REP_TIME

//////////////////////////////////////////////////////////////////////////////
// LOCKBOX: a small keyed box. The first key used on it becomes its key.
//////////////////////////////////////////////////////////////////////////////

/obj/item/weapon/storage/lockbox
	name = "lockbox"
	desc = "A small steel box with a key lock. The first key used on it becomes its key; use that key, or a keychain holding it, to lock and unlock it. A determined thief can still beat the lock off."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "lockbox"
	w_class = ITEM_SIZE_NORMAL
	max_w_class = ITEM_SIZE_SMALL
	max_storage_space = 8
	storage_slots = 4
	flammable = FALSE
	var/locked = FALSE
	var/broken = FALSE
	var/custom_code = 0
	var/lock_health = 4

/obj/item/weapon/storage/lockbox/after_load()
	..()
	update_icon()

/obj/item/weapon/storage/lockbox/update_icon()
	icon_state = broken ? "lockbox_broken" : (locked ? "lockbox_locked" : "lockbox")

/obj/item/weapon/storage/lockbox/examine(mob/user)
	..()
	if (broken)
		to_chat(user, "Its lock has been beaten off.")
	else if (locked)
		to_chat(user, "It is locked.")
	else if (!custom_code)
		to_chat(user, "No key has been fitted to it yet.")

/obj/item/weapon/storage/lockbox/proc/is_shut()
	return locked && !broken

/obj/item/weapon/storage/lockbox/proc/matching_key(obj/item/W)
	if (istype(W, /obj/item/weapon/key))
		var/obj/item/weapon/key/K = W
		if (!custom_code && K.code)
			custom_code = K.code
		return custom_code && K.code == custom_code
	if (istype(W, /obj/item/weapon/storage/belt/keychain) && custom_code)
		for (var/obj/item/weapon/key/K in W.contents)
			if (K.code == custom_code)
				return TRUE
	return FALSE

/obj/item/weapon/storage/lockbox/proc/toggle_lock(mob/user)
	locked = !locked
	if (locked)
		close_all()
	user.visible_message("<span class='notice'>[user] [locked ? "locks" : "unlocks"] \the [src].</span>")
	playsound(get_turf(src), 'sound/effects/door_lock_unlock.ogg', 50)
	update_icon()

/obj/item/weapon/storage/lockbox/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/key) || istype(W, /obj/item/weapon/storage/belt/keychain))
		if (broken)
			to_chat(user, "<span class='warning'>The lock is broken.</span>")
		else if (matching_key(W))
			toggle_lock(user)
		else
			to_chat(user, "<span class='warning'>No key there fits this lock.</span>")
		return TRUE
	if (is_shut())
		if (user.a_intent == I_HARM && W.force >= 10)
			user.do_attack_animation(src)
			playsound(get_turf(src), 'sound/weapons/smash.ogg', 60, TRUE)
			lock_health--
			if (lock_health <= 0)
				broken = TRUE
				locked = FALSE
				user.visible_message("<span class='danger'>[user] beats the lock off \the [src]!</span>")
				update_icon()
			else
				user.visible_message("<span class='warning'>[user] bashes the lock of \the [src].</span>")
			return TRUE
		to_chat(user, "<span class='warning'>\The [src] is locked.</span>")
		return TRUE
	return ..()

/obj/item/weapon/storage/lockbox/can_be_inserted(obj/item/W, stop_messages = FALSE)
	if (is_shut())
		if (!stop_messages)
			to_chat(usr, "<span class='warning'>\The [src] is locked.</span>")
		return FALSE
	return ..()

/obj/item/weapon/storage/lockbox/open(mob/user)
	if (is_shut())
		to_chat(user, "<span class='warning'>\The [src] is locked.</span>")
		return
	return ..()

//////////////////////////////////////////////////////////////////////////////
// WEAPON LIGHT (CM-SS13 rail flashlight): an underbarrel light, lit only while
// the gun is in your hands. Right-click the gun > Toggle Weapon Light.
//////////////////////////////////////////////////////////////////////////////

/obj/item/weapon/attachment/under/weapon_light
	name = "weapon light"
	desc = "A small flashlight that clamps under a rifle or machine gun. Fit it at a firearm bench, then right-click the gun and choose Toggle Weapon Light. It only shines while the gun is in your hands."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "weapon_light"
	fits = list("rifle", "mg", "machinegun", "smg", "shotgun")
	ergonomics = 1
	weight = 0.15
	value = 8
	var/light_on = FALSE
	var/beam_range = 5

/obj/item/weapon/gun/proc/weapon_light()
	return istype(under, /obj/item/weapon/attachment/under/weapon_light) ? under : null

/obj/item/weapon/gun/proc/weapon_light_shining()
	var/obj/item/weapon/attachment/under/weapon_light/L = weapon_light()
	if (!L || !L.light_on || !ismob(loc))
		return FALSE
	var/mob/M = loc
	return M.l_hand == src || M.r_hand == src

// Also called after a muzzle flash fades, so the beam comes back.
/obj/item/weapon/gun/proc/update_weapon_light()
	var/obj/item/weapon/attachment/under/weapon_light/L = weapon_light()
	if (weapon_light_shining())
		set_light(L.beam_range, 1, "#fff2d0")
	else
		set_light(0)

/obj/item/weapon/gun/verb/toggle_weapon_light()
	set name = "Toggle Weapon Light"
	set category = null
	set src in usr
	var/obj/item/weapon/attachment/under/weapon_light/L = weapon_light()
	if (!L)
		to_chat(usr, "<span class='warning'>\The [src] has no weapon light.</span>")
		return
	L.light_on = !L.light_on
	playsound(get_turf(src), 'sound/effects/Custom_flashlight.ogg', 40, TRUE)
	update_weapon_light()
	to_chat(usr, "<span class='notice'>You switch the weapon light [L.light_on ? "on" : "off"].</span>")

/obj/item/weapon/gun/equipped(mob/user, slot)
	. = ..()
	update_weapon_light()

/obj/item/weapon/gun/dropped(mob/user)
	. = ..()
	update_weapon_light()

/obj/item/weapon/gun/after_load()
	..()
	update_weapon_light()

//////////////////////////////////////////////////////////////////////////////
// GUN SLING (CM-SS13 magnetic harness): a strapped gun that falls from your
// hands while you are knocked down or out stays slung on your shoulder or back.
//////////////////////////////////////////////////////////////////////////////

/obj/item/weapon/gun/var/has_sling = FALSE

/obj/item/weapon/gun_sling
	name = "gun sling"
	desc = "A leather strap for a long gun. Hold it with the gun in your other hand and use it to fit it. A slung gun that you drop while knocked down or out stays on your shoulder or back, if that slot is free."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "gun_sling"
	w_class = ITEM_SIZE_SMALL
	weight = 0.2
	value = 4

/obj/item/weapon/gun_sling/attack_self(mob/living/human/user)
	if (!istype(user))
		return
	var/obj/item/weapon/gun/G = user.get_inactive_hand()
	if (!istype(G))
		to_chat(user, "<span class='warning'>Hold the gun in your other hand.</span>")
		return
	if (!G.fit_sling(user, src))
		return
	user.visible_message("<span class='notice'>[user] fits a sling to \the [G].</span>", "<span class='notice'>You fit the sling to \the [G].</span>")

/obj/item/weapon/gun/proc/fit_sling(mob/living/human/user, obj/item/weapon/gun_sling/S)
	if (has_sling)
		if (user)
			to_chat(user, "<span class='warning'>\The [src] already has a sling.</span>")
		return FALSE
	if (!sling_slot())
		if (user)
			to_chat(user, "<span class='warning'>\The [src] is too small to sling; only guns worn on the shoulder or back take one.</span>")
		return FALSE
	has_sling = TRUE
	weight += S.weight
	if (user)
		user.drop_from_inventory(S)
	qdel(S)
	return TRUE

/obj/item/weapon/gun/proc/sling_slot()
	if (slot_flags & SLOT_SHOULDER)
		return slot_shoulder
	if (slot_flags & SLOT_BACK)
		return slot_back
	return 0

/obj/item/weapon/gun/proc/sling_slot_free(mob/living/human/H)
	var/slot = sling_slot()
	if (slot == slot_shoulder)
		return !H.shoulder
	if (slot == slot_back)
		return !H.back
	return FALSE

// TRUE when this gun should catch on its sling rather than hit the floor.
/obj/item/weapon/gun/proc/sling_catches(mob/living/human/H)
	if (!has_sling || !istype(H) || !sling_slot_free(H))
		return FALSE
	return H.stat != CONSCIOUS || H.lying || H.weakened || H.stunned

/mob/living/human/drop_from_inventory(obj/item/W, atom/Target = null)
	var/obj/item/weapon/gun/G = W
	var/catch_gun = istype(G) && G.sling_catches(src) && (!Target || isturf(Target))
	. = ..()
	if (catch_gun && !QDELETED(G) && isturf(G.loc) && G.Adjacent(src) && G.sling_slot_free(src))
		if (equip_to_slot_if_possible(G, G.sling_slot(), FALSE, TRUE))
			visible_message("<span class='notice'>\The [G] swings back onto [src] on its sling.</span>")

/obj/item/weapon/gun/examine(mob/user)
	..()
	if (has_sling)
		to_chat(user, "<span class='notice'>It has a sling.</span>")
	if (weapon_light())
		var/obj/item/weapon/attachment/under/weapon_light/L = weapon_light()
		to_chat(user, "<span class='notice'>Its weapon light is [L.light_on ? "on" : "off"].</span>")

//////////////////////////////////////////////////////////////////////////////
// MOTION DETECTOR (CM-SS13 motion_detector.dm): held and switched on, it shows
// its holder a blip wherever something has moved nearby in the last moments.
//////////////////////////////////////////////////////////////////////////////

#define MOTION_DETECTOR_RANGE 7
#define MOTION_DETECTOR_WINDOW 25 // deciseconds: moved this recently shows up

/obj/item/weapon/motion_detector
	name = "motion detector"
	desc = "A handheld sensor. Switch it on and hold it: anything that has just moved within seven tiles shows as a blip, even through walls. Anything keeping still is invisible to it."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "motion_detector"
	w_class = ITEM_SIZE_SMALL
	weight = 0.6
	value = 40
	var/on = FALSE
	var/tmp/list/blips
	var/tmp/client/blip_client

/obj/item/weapon/motion_detector/persistence_runtime_var(key)
	return (key in list("blips", "blip_client")) || ..()

/obj/item/weapon/motion_detector/after_load()
	..()
	if (on)
		processing_objects |= src

/obj/item/weapon/motion_detector/Destroy()
	clear_blips()
	processing_objects -= src
	return ..()

/obj/item/weapon/motion_detector/attack_self(mob/user)
	on = !on
	if (on)
		processing_objects |= src
	else
		processing_objects -= src
		clear_blips()
	playsound(get_turf(src), 'sound/machines/computer/beep.ogg', 30, TRUE)
	to_chat(user, "<span class='notice'>You switch \the [src] [on ? "on" : "off"].</span>")

/obj/item/weapon/motion_detector/examine(mob/user)
	..()
	to_chat(user, "It is [on ? "on" : "off"].")

/obj/item/weapon/motion_detector/proc/holder()
	var/mob/living/human/H = loc
	if (istype(H) && (H.l_hand == src || H.r_hand == src) && H.stat == CONSCIOUS)
		return H
	return null

/obj/item/weapon/motion_detector/proc/clear_blips()
	if (blip_client && blips)
		blip_client.images -= blips
	blips = null
	blip_client = null

// The things the holder would see as blips right now.
/obj/item/weapon/motion_detector/proc/moving_contacts(mob/living/human/H)
	var/list/found = list()
	var/turf/T = get_turf(H)
	if (!T)
		return found
	for (var/mob/living/M in range(MOTION_DETECTOR_RANGE, T))
		if (M == H || M.stat == DEAD || M.last_movement < 0)
			continue
		if (world.time - M.last_movement <= MOTION_DETECTOR_WINDOW)
			found += M
	return found

/obj/item/weapon/motion_detector/process_interval(seconds)
	if (!on)
		clear_blips()
		return PROCESS_KILL
	clear_blips()
	var/mob/living/human/H = holder()
	if (!H || !H.client)
		return
	var/list/contacts = moving_contacts(H)
	if (!contacts.len)
		return
	blips = list()
	for (var/mob/living/M in contacts)
		var/image/I = image('icons/obj/cmss13_ports.dmi', get_turf(M), "motion_blip", FLY_LAYER)
		I.plane = CHAT_PLANE
		I.appearance_flags = RESET_COLOR | RESET_ALPHA | KEEP_APART
		blips += I
	blip_client = H.client
	blip_client.images += blips
	playsound(get_turf(src), 'sound/machines/computer/beep.ogg', 15, TRUE, -4)

#undef MOTION_DETECTOR_RANGE
#undef MOTION_DETECTOR_WINDOW

//////////////////////////////////////////////////////////////////////////////
// RANGEFINDER (CM-SS13 rangefinder binoculars): look through it and click a
// spot for its exact range, bearing and coordinates. Once the round allows
// coordinates, spotted points can be used for artillery and air support.
//////////////////////////////////////////////////////////////////////////////

/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars/rangefinder
	name = "rangefinder"
	desc = "Laser rangefinding binoculars. Look through them and click a spot for its exact range, bearing and coordinates."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "rangefinder"
	value = 40

/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars/rangefinder/rangecheck(mob/living/human/H, atom/target)
	if (checking || !H || !H.looking)
		return
	var/turf/T = get_turf(target)
	if (!T || T.z != H.z)
		return
	checking = TRUE
	if (!do_after(H, 15, src, can_move = FALSE))
		checking = FALSE
		return
	checking = FALSE
	to_chat(H, rangefinder_report(H, T))
	if (check_coords_check())
		valid_coordinates["[T.x],[T.y]"] = TRUE

/proc/rangefinder_report(mob/H, turf/T)
	var/dist = max(abs(H.x - T.x), abs(H.y - T.y))
	var/bearing = dist ? " [dir2text(get_dir(H, T))]" : ""
	return "<big><b><font color='#ADD8E6'>Range: [dist] meters[bearing]. Coordinates [T.x],[T.y]; offset [T.x - H.x],[T.y - H.y].</font></b></big>"
