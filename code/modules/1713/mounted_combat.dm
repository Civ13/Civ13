// Mounted charges, braced spears and shield walls (docs/mounted-combat.md).
//
// A rider who keeps the horse going the same way builds up a charge. After
// CHARGE_STEPS straight steps, a spear, pike or halberd held couched in the
// active hand strikes the first man in the horse's path: a heavy blow that
// knocks him down. A shield can still turn it.
//
// A footman who braces a spear, pike or halberd (the Brace verb, or a
// deployed sarissa) and faces the charge breaks it instead: the horse runs
// onto the point and the rider is thrown.
//
// Shields held by men standing shoulder to shoulder, facing the same way,
// block better together: each such neighbour adds SHIELD_WALL_STEP to the
// block chance, up to SHIELD_WALL_CAP.

#define CHARGE_STEPS 4
#define CHARGE_STEP_GAP 8 // deciseconds between steps before the charge is lost
#define BRACE_TIME 100
#define SHIELD_WALL_STEP 15
#define SHIELD_WALL_CAP 30

/mob/living/human/var/tmp/charge_steps = 0
/mob/living/human/var/tmp/charge_dir = 0
/mob/living/human/var/tmp/charge_last = 0
/mob/living/human/var/tmp/braced_until = 0
/mob/living/human/var/tmp/turf/braced_at = null

/mob/living/human/persistence_runtime_var(key)
	return (key in list("charge_steps", "charge_dir", "charge_last", "braced_until", "braced_at")) || ..()

/proc/is_charge_polearm(obj/item/I)
	return istype(I, /obj/item/weapon/material/spear) || istype(I, /obj/item/weapon/material/pike) || istype(I, /obj/item/weapon/material/halberd)

// Called after every ridden step.
/mob/living/human/proc/ride_charge_step(turf/from)
	if (!riding_mob || !isturf(from) || get_turf(src) == from)
		return
	var/step_dir = get_dir(from, get_turf(src))
	if (step_dir == charge_dir && world.time - charge_last <= CHARGE_STEP_GAP)
		charge_steps++
	else
		charge_steps = 1
		charge_dir = step_dir
	charge_last = world.time
	if (charge_steps < CHARGE_STEPS - 1)
		return
	var/turf/ahead = get_step(src, charge_dir)
	if (!ahead)
		return
	// A braced point stops the horse before the rider's lance lands.
	for (var/mob/living/human/D in ahead)
		if (D != src && D.is_braced_against(src))
			D.break_charge(src)
			return
	if (charge_steps < CHARGE_STEPS)
		return
	var/obj/item/W = get_active_hand()
	if (!is_charge_polearm(W) || incapacitated())
		return
	for (var/mob/living/M in ahead)
		if (M == src || M == riding_mob || M.stat == DEAD || M.lying)
			continue
		lance_strike(M, W)
		return

/mob/living/human/proc/lance_strike(mob/living/M, obj/item/W)
	charge_steps = 0
	var/damage = round(W.force * 1.5) + 10
	if (M.check_shields(damage, W, src, "chest", "the charge"))
		visible_message(SPAN_WARNING("[M] turns \the [src]'s charge aside!"))
		return FALSE
	M.apply_damage(damage, BRUTE, "chest", 0, W, W.sharp, W.edge)
	M.Weaken(3)
	var/turf/back = get_step(M, charge_dir)
	if (back && !back.density)
		step(M, charge_dir)
	playsound(get_turf(M), 'sound/weapons/smash.ogg', 60, TRUE)
	visible_message(SPAN_DANGER("[src] rides [M] down with \the [W]!"))
	return TRUE

// ---- bracing --------------------------------------------------------------------

/mob/living/human/proc/is_braced_against(mob/living/human/rider)
	if (stat != CONSCIOUS || lying || incapacitated())
		return FALSE
	if (get_dir(src, rider) != dir)
		return FALSE
	var/obj/item/W = get_active_hand()
	if (istype(W, /obj/item/weapon/material/spear/sarissa))
		var/obj/item/weapon/material/spear/sarissa/S = W
		if (S.deployed)
			return TRUE
	if (!is_charge_polearm(W))
		return FALSE
	return braced_until > world.time && braced_at == get_turf(src)

/mob/living/human/proc/break_charge(mob/living/human/rider)
	var/mob/living/simple_animal/horse = rider.riding_mob
	rider.charge_steps = 0
	braced_until = 0
	visible_message(SPAN_DANGER("\The [horse] runs onto [src]'s braced point and [rider] is thrown!"))
	playsound(get_turf(src), 'sound/weapons/smash.ogg', 60, TRUE)
	if (horse)
		horse.adjustBruteLoss(rand(25, 40))
		horse_throw_rider(horse, rider)
	return TRUE

// Throws the rider off without the usual wait (death and pulling-off use the same steps).
/proc/horse_throw_rider(mob/living/simple_animal/A, mob/living/human/rider)
	if (!A || !rider || A.rider != rider)
		return FALSE
	A.npc_subtile_pending_intent = null
	rider.riding = FALSE
	rider.riding_mob = null
	A.ride = FALSE
	A.rider = null
	rider.pixel_x = 0
	rider.pixel_y = 0
	var/turf/T = get_step(A, reverse_direction(A.dir))
	if (!T || T.density)
		T = get_turf(A)
	rider.forceMove(T)
	rider.SpinAnimation(5, 1)
	rider.Weaken(5)
	A.update_icons()
	A.stop_automated_movement = FALSE
	return TRUE

/mob/living/human/verb/brace_polearm()
	set name = "Brace"
	set category = "IC"
	set desc = "Set the butt of your spear, pike or halberd against the ground to meet a charge."
	if (stat != CONSCIOUS || lying || riding)
		return
	if (!is_charge_polearm(get_active_hand()))
		to_chat(src, SPAN_WARNING("You need a spear, pike or halberd in your hand to brace."))
		return
	braced_until = world.time + BRACE_TIME
	braced_at = get_turf(src)
	visible_message(SPAN_WARNING("[src] braces \the [get_active_hand()] against the ground."), SPAN_NOTICE("You brace yourself to meet a charge. Stand still and face it."))

// ---- shield wall ----------------------------------------------------------------

/obj/item/weapon/shield/proc/shield_wall_bonus(mob/living/user)
	if (!istype(user) || !isturf(user.loc))
		return 0
	var/bonus = 0
	// A wall is shoulder to shoulder, not a file: only the two flank tiles
	// count, for a diagonal facing as well as a cardinal one.
	for (var/d in list(turn(user.dir, 90), turn(user.dir, -90)))
		var/turf/T = get_step(user, d)
		if (!T)
			continue
		for (var/mob/living/human/N in T)
			if (N == user || N.dir != user.dir || N.stat != CONSCIOUS || N.lying)
				continue
			if (istype(N.l_hand, /obj/item/weapon/shield) || istype(N.r_hand, /obj/item/weapon/shield))
				bonus += SHIELD_WALL_STEP
				break
	return min(bonus, SHIELD_WALL_CAP)

#undef CHARGE_STEPS
#undef CHARGE_STEP_GAP
#undef BRACE_TIME
#undef SHIELD_WALL_STEP
#undef SHIELD_WALL_CAP
