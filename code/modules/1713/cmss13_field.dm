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
