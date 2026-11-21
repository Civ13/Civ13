// Whole-body motion. Character sprites stay static: a short animate() on the
// body's transform tilts, shifts and settles the whole character, and every
// clothing, hair and held-item overlay moves with it at no extra cost.
//
// Channel ownership: this file only animates `transform`, as the posture
// transform (posture_transform(): size scale plus the lying turn) times a
// motion matrix, and every motion ends back on the posture transform.
// pixel_x/pixel_y (attack lunge, grabs, tree climbing) and pixel_w/pixel_z
// (free movement glide) stay with their owners. Motions run as parallel
// animations so they never interrupt a lunge or a glide, and a running motion
// is never cut by a direct transform write (see update_posture_transform()).
//
// Amplitudes and timings are Fable's art direction: translate first, rotate
// only 5 degrees or more, pivot at the feet, fast out and slow back.

/mob/living/human
	// world.time the running motion ends; transform belongs to it until then.
	var/tmp/body_motion_until = 0
	var/tmp/body_motion_priority = 0
	var/tmp/body_motion_started = -100
	// Counts motion claims, so a caller can tell whether its motion still runs.
	var/tmp/body_motion_serial = 0
	// The posture transform the running motion returns to.
	var/tmp/matrix/body_motion_rest = null
	// Whether the last drawn posture was turned (lying or prone); null = never drawn.
	var/tmp/body_motion_drawn_turned = null
	var/tmp/body_motion_watch_checked = -100
	var/tmp/body_motion_watch_cached = FALSE
	// No swim stroke before this world.time (one per 12 ds at most).
	var/tmp/body_motion_stroke_next = 0

/proc/body_motion_level()
	return config ? config.body_motion : BODY_MOTION_FULL

// Whether a player can see this body: its own player, or one within range on
// this level, cached for 2 seconds. Unwatched bodies snap instead of animating.
/mob/living/human/proc/body_motion_watched()
	if (client)
		return TRUE
	if (world.time < body_motion_watch_checked + 20)
		return body_motion_watch_cached
	body_motion_watch_checked = world.time
	body_motion_watch_cached = FALSE
	var/turf/here = get_turf(src)
	if (here)
		for (var/client/C in clients)
			var/turf/there = get_turf(C.mob)
			if (there && there.z == here.z && get_dist(here, there) <= BODY_MOTION_WATCH_RANGE)
				body_motion_watch_cached = TRUE
				break
	return body_motion_watch_cached

/mob/living/human/proc/body_motion_turned()
	return (lying || prone) && !species.prone_icon

// Whether a motion of this priority and minimum level may start now.
/mob/living/human/proc/body_motion_can_play(priority, min_level = BODY_MOTION_REDUCED)
	if (body_motion_level() < min_level || QDELETED(src) || !isturf(loc))
		return FALSE
	if (!body_motion_watched())
		return FALSE
	if (world.time < body_motion_until && priority < body_motion_priority)
		return FALSE
	// At most one motion start per BODY_MOTION_MIN_GAP; posture changes always
	// play, and a higher priority motion cuts in (a hit during the stride bounce).
	if (priority < BODY_MOTION_PRIORITY_POSTURE && priority <= body_motion_priority && world.time < body_motion_started + BODY_MOTION_MIN_GAP)
		return FALSE
	return TRUE

/mob/living/human/proc/body_motion_claim(priority, duration, matrix/rest)
	body_motion_priority = priority
	body_motion_started = world.time
	body_motion_serial++
	body_motion_until = world.time + duration
	body_motion_rest = rest

/proc/body_motion_matrix_same(matrix/A, matrix/B)
	if (!A || !B)
		return FALSE
	return A.a == B.a && A.b == B.b && A.c == B.c && A.d == B.d && A.e == B.e && A.f == B.f

// A motion key: the rest transform, then a rotation pivoting at the feet, then
// a shift in screen pixels. Feet sit 16px below the centre at every size.
/proc/body_motion_matrix(matrix/rest, dx = 0, dy = 0, degrees = 0, squash_y = 1)
	var/matrix/M = matrix(rest)
	if (degrees || squash_y != 1)
		M.Translate(0, 16)
		if (squash_y != 1)
			M.Scale(1, squash_y)
		if (degrees)
			M.Turn(degrees)
		M.Translate(0, -16)
	if (dx || dy)
		M.Translate(dx, dy)
	return M

/mob/living/human/proc/body_motion_lying_by_choice()
	return resting || sleeping > 0 || buckled

// Eased fall or stand-up in place of the old instant turn. Both pass through
// a 45 degree lean pivoting at the feet, so the body topples over and rises
// from its feet instead of spinning about its middle. Fall: 4 ds, ease-in,
// 1px settle. Stand-up: 6 ds, ease-out.
/mob/living/human/proc/body_motion_posture_change(matrix/rest, turned)
	if (turned && body_motion_lying_by_choice())
		// Lying down on purpose (resting, sleeping, a bed) lowers the body
		// slowly through the same lean instead of toppling: 6 ds, no bump.
		var/matrix/upright = matrix(transform)
		var/lean = rest.b >= 0 ? 45 : -45
		body_motion_claim(BODY_MOTION_PRIORITY_POSTURE, 6, rest)
		animate(src, transform = body_motion_matrix(upright, 0, 0, lean), time = 3, easing = SINE_EASING, flags = ANIMATION_PARALLEL, tag = BODY_MOTION_TAG)
		animate(transform = rest, time = 3, easing = SINE_EASING | EASE_OUT)
	else if (turned)
		var/matrix/upright = matrix(transform)
		var/lean = rest.b >= 0 ? 45 : -45 // the side the lying turn goes
		body_motion_claim(BODY_MOTION_PRIORITY_POSTURE, 4, rest)
		animate(src, transform = body_motion_matrix(upright, 0, 0, lean), time = 2, easing = QUAD_EASING | EASE_IN, flags = ANIMATION_PARALLEL, tag = BODY_MOTION_TAG)
		animate(transform = body_motion_matrix(rest, 0, -1), time = 1)
		animate(transform = rest, time = 1)
	else
		var/lean = transform.b >= 0 ? 45 : -45
		body_motion_claim(BODY_MOTION_PRIORITY_POSTURE, 6, rest)
		animate(src, transform = body_motion_matrix(rest, 0, 0, lean), time = 3, flags = ANIMATION_PARALLEL, tag = BODY_MOTION_TAG)
		animate(transform = rest, time = 3, easing = SINE_EASING | EASE_OUT)

// Hit recoil: 3px away from the attacker with an 8 degree roll away, back over
// 3 ds. A body lying down only shifts.
/mob/living/human/proc/body_motion_recoil(atom/attacker, delay = 0)
	if (!attacker || attacker == src || stat == DEAD)
		return FALSE
	if (!body_motion_can_play(BODY_MOTION_PRIORITY_COMBAT))
		return FALSE
	var/direction = get_dir(attacker, src)
	if (!direction)
		return FALSE
	var/dx = (direction & EAST) ? 1 : ((direction & WEST) ? -1 : 0)
	var/dy = (direction & NORTH) ? 1 : ((direction & SOUTH) ? -1 : 0)
	var/matrix/rest = posture_transform()
	var/matrix/away
	if (body_motion_turned())
		away = body_motion_matrix(rest, dx * 2, dy * 2)
	else
		// Positive turns are clockwise: pushed east, the head leans east.
		away = body_motion_matrix(rest, dx * 3, dy * 3, dx * 8)
	body_motion_claim(BODY_MOTION_PRIORITY_COMBAT, 3 + delay, rest)
	if (delay)
		// A blunt swing lands on its drop, after the wind-up.
		animate(src, transform = rest, time = delay, flags = ANIMATION_PARALLEL, tag = BODY_MOTION_TAG)
		animate(transform = away, time = 1, easing = LINEAR_EASING)
	else
		animate(src, transform = away, time = 1, easing = LINEAR_EASING, flags = ANIMATION_PARALLEL, tag = BODY_MOTION_TAG)
	animate(transform = rest, time = 2, easing = SINE_EASING | EASE_IN)
	return TRUE

// Plays a list of keys, each list(dx, dy, degrees, squash_y, time, easing),
// from the current posture and back to it. The last key should be the rest
// (0, 0, 0, 1). Shifts are screen pixels, turns pivot at the feet.
/mob/living/human/proc/body_motion_play(priority, min_level, list/keys)
	if (!keys || !keys.len || body_motion_turned() || stat == DEAD)
		return FALSE
	if (!body_motion_can_play(priority, min_level))
		return FALSE
	var/matrix/rest = posture_transform()
	var/total = 0
	for (var/list/key in keys)
		total += key[5]
	body_motion_claim(priority, total, rest)
	var/first = TRUE
	for (var/list/key in keys)
		var/matrix/M = body_motion_matrix(rest, key[1], key[2], key[3], key[4])
		if (first)
			animate(src, transform = M, time = key[5], easing = key[6], flags = ANIMATION_PARALLEL, tag = BODY_MOTION_TAG)
			first = FALSE
		else
			animate(transform = M, time = key[5], easing = key[6])
	return TRUE

// Forward along a direction: list(x, y, roll). East and west lean by turning;
// north and south cannot show a lean, so they shift instead and never roll.
/proc/body_motion_forward(direction)
	var/x = (direction & EAST) ? 1 : ((direction & WEST) ? -1 : 0)
	var/y = (direction & NORTH) ? 1 : ((direction & SOUTH) ? -1 : 0)
	if (x)
		return list(x, 0, x)
	return list(0, y, 0)

// A tool strike on the existing 5 ds work tick (mining and chopping): wind up
// 1px back, strike 2px in with up to a 6 degree lean, slow recovery. 5 ds.
/mob/living/human/proc/body_motion_work(atom/target)
	var/direction = target ? get_dir(src, target) : 0
	if (!direction)
		direction = dir
	var/list/f = body_motion_forward(direction)
	return body_motion_play(BODY_MOTION_PRIORITY_LOW, BODY_MOTION_FULL, list(
		list(-f[1], -f[2], -4 * f[3], 1, 1, LINEAR_EASING),
		list(2 * f[1], 2 * f[2], 6 * f[3], 1, 2, QUAD_EASING | EASE_IN),
		list(0, 0, 0, 1, 2, SINE_EASING | EASE_OUT)))

// Sitting down on a seat: a 2px drop with a brief squash at the feet. 3 ds.
/mob/living/human/proc/body_motion_settle()
	return body_motion_play(BODY_MOTION_PRIORITY_LOW, BODY_MOTION_FULL, list(
		list(0, -2, 0, 0.9, 1, QUAD_EASING | EASE_IN),
		list(0, 0, 0, 1, 2, SINE_EASING | EASE_OUT)))

// Emotes that read as a whole-body gesture. Others stay text only. Rolls are
// kept for leaning actions (bow); head and arm gestures only shift or squash.
/mob/living/human/proc/body_motion_emote(act)
	var/list/f = body_motion_forward(dir)
	var/list/keys
	switch (act)
		if ("nod")
			keys = list(list(0, -1, 0, 1, 1, SINE_EASING), list(0, 0, 0, 1, 1, SINE_EASING),
				list(0, -1, 0, 1, 1, SINE_EASING), list(0, 0, 0, 1, 1, SINE_EASING))
		if ("shake")
			keys = list(list(-1, 0, 0, 1, 1, SINE_EASING), list(1, 0, 0, 1, 2, SINE_EASING),
				list(0, 0, 0, 1, 1, SINE_EASING))
		if ("bow")
			// North and south can't show the lean, so they squash at the feet.
			var/squash = f[3] ? 1 : 0.9
			keys = list(list(2 * f[1], 2 * f[2], 12 * f[3], squash, 2, SINE_EASING), list(2 * f[1], 2 * f[2], 12 * f[3], squash, 2, LINEAR_EASING),
				list(0, 0, 0, 1, 2, SINE_EASING | EASE_OUT))
		if ("shrug")
			keys = list(list(0, 2, 0, 1, 1, QUAD_EASING | EASE_OUT), list(0, 2, 0, 1, 1, LINEAR_EASING),
				list(0, 0, 0, 1, 2, SINE_EASING | EASE_IN))
		if ("wave")
			keys = list(list(0, 1, 0, 1, 1, QUAD_EASING | EASE_OUT), list(0, 1, 0, 1, 3, LINEAR_EASING),
				list(0, 0, 0, 1, 1, SINE_EASING))
		if ("salute")
			keys = list(list(0, 1, 0, 1, 1, QUAD_EASING | EASE_OUT), list(0, 1, 0, 1, 4, LINEAR_EASING),
				list(0, 0, 0, 1, 1, SINE_EASING))
	if (!keys)
		return FALSE
	return body_motion_play(BODY_MOTION_PRIORITY_LOW, BODY_MOTION_FULL, keys)

/proc/body_motion_blunt(obj/item/I)
	return istype(I) && !I.edge && !I.sharp && I.force >= 5

// Swing body: the existing 8px pixel lunge (do_attack_animation) carries the
// thrust; an edged weapon adds an 8 degree roll into the slash, a blunt one a
// short wind-up and an 8 degree drop (the victim's recoil waits 1 ds for it). East and west only: north and south
// already read through the lunge. 4 ds, matching the lunge.
/mob/living/human/do_attack_animation(atom/A)
	..()
	body_motion_swing(A, get_active_hand())

/mob/living/human/proc/body_motion_swing(atom/target, obj/item/I)
	if (!target || target == src || !istype(I))
		return FALSE
	var/list/f = body_motion_forward(get_dir(src, target))
	if (!f[3])
		return FALSE
	var/list/keys
	if (I.edge)
		// Peaks at 1 ds, with the victim's recoil.
		keys = list(list(0, 0, 8 * f[3], 1, 1, QUAD_EASING | EASE_OUT),
			list(0, 0, 0, 1, 3, SINE_EASING | EASE_IN))
	else if (body_motion_blunt(I))
		keys = list(list(0, 0, -4 * f[3], 1, 1, LINEAR_EASING),
			list(0, 0, 8 * f[3], 1, 1, QUAD_EASING | EASE_IN),
			list(0, 0, 0, 1, 2, SINE_EASING | EASE_OUT))
	if (!keys)
		return FALSE // thrusts and jabs keep the plain lunge
	return body_motion_play(BODY_MOTION_PRIORITY_COMBAT, BODY_MOTION_FULL, keys)

// Parry and block: 2px back from the attacker and return. 3 ds. Kept at the
// REDUCED level because it shows the attack was stopped.
/mob/living/human/proc/body_motion_parry(atom/attacker)
	if (!attacker || attacker == src)
		return FALSE
	var/list/f = body_motion_forward(get_dir(attacker, src))
	if (!f[1] && !f[2])
		return FALSE
	return body_motion_play(BODY_MOTION_PRIORITY_COMBAT, BODY_MOTION_REDUCED, list(
		list(2 * f[1], 2 * f[2], 0, 1, 1, LINEAR_EASING),
		list(0, 0, 0, 1, 2, SINE_EASING | EASE_IN)))

// Slip: a 4px sidestep across the line of the attack and back. 3 ds.
/mob/living/human/proc/body_motion_slip(atom/attacker)
	if (!attacker || attacker == src)
		return FALSE
	var/list/f = body_motion_forward(get_dir(attacker, src))
	var/side = pick(-1, 1)
	return body_motion_play(BODY_MOTION_PRIORITY_COMBAT, BODY_MOTION_REDUCED, list(
		list(4 * f[2] * side, 4 * f[1] * side, 0, 1, 1, QUAD_EASING | EASE_OUT),
		list(0, 0, 0, 1, 2, SINE_EASING | EASE_IN)))

// Sprawl: drop low and back from a grab, squashed at the feet. 4 ds.
/mob/living/human/proc/body_motion_sprawl(atom/attacker)
	if (!attacker || attacker == src)
		return FALSE
	var/list/f = body_motion_forward(get_dir(attacker, src))
	return body_motion_play(BODY_MOTION_PRIORITY_COMBAT, BODY_MOTION_REDUCED, list(
		list(2 * f[1], 2 * f[2] - 2, 0, 0.9, 1, QUAD_EASING | EASE_OUT),
		list(0, 0, 0, 1, 3, SINE_EASING | EASE_OUT)))

// Taking a stance: a one-shot 1px "set" dip. 3 ds.
/mob/living/human/proc/body_motion_stance_set()
	return body_motion_play(BODY_MOTION_PRIORITY_LOW, BODY_MOTION_FULL, list(
		list(0, -1, 0, 1, 1, QUAD_EASING | EASE_OUT),
		list(0, 0, 0, 1, 2, SINE_EASING)))

// Swimming stroke on a deep-water step: a 1px dip, no squash (the water mask
// already hides the lower half). At most one per 12 ds, so fast swimmers
// stroke every second step and it never reads as a walking bob. 5 ds.
/mob/living/human/proc/body_motion_swim_stroke()
	if (world.time < body_motion_stroke_next)
		return FALSE
	if (!body_motion_play(BODY_MOTION_PRIORITY_LOW, BODY_MOTION_FULL, list(
		list(0, -1, 0, 1, 2, SINE_EASING),
		list(0, 0, 0, 1, 3, SINE_EASING))))
		return FALSE
	body_motion_stroke_next = world.time + 12
	return TRUE

// Spent and slipping under: sink 3px, hold, then come back. The hold keeps it
// from reading as a hit recoil. Kept at REDUCED: it shows the swimmer is spent. 10 ds.
/mob/living/human/proc/body_motion_sink()
	return body_motion_play(BODY_MOTION_PRIORITY_COMBAT, BODY_MOTION_REDUCED, list(
		list(0, -3, 0, 1, 3, QUAD_EASING | EASE_IN),
		list(0, -3, 0, 1, 3, LINEAR_EASING),
		list(0, 0, 0, 1, 4, SINE_EASING | EASE_OUT)))

// Drowning: a 2px side struggle once a life tick. Low priority, so it never
// cuts the sink above. Kept at REDUCED: it shows the swimmer is drowning. 6 ds.
/mob/living/human/proc/body_motion_struggle()
	return body_motion_play(BODY_MOTION_PRIORITY_LOW, BODY_MOTION_REDUCED, list(
		list(-2, 0, 0, 1, 2, LINEAR_EASING),
		list(2, 0, 0, 1, 2, LINEAR_EASING),
		list(0, 0, 0, 1, 2, LINEAR_EASING)))

// Climbing: one 1px pull every 10 ds for the length of the wait, up or down,
// with a still beat between pulls. Nothing while another wait is running.
// Returns the motion's serial, for
// body_motion_stop() once the wait ends or is interrupted; 0 when none played.
/mob/living/human/proc/body_motion_climb(up, duration)
	// A second request while a wait already runs is refused by do_after; it
	// must not replace the running climb's pulls first.
	if (!may_do_after)
		return 0
	var/dy = up ? 1 : -1
	var/list/keys = list()
	for (var/i in 1 to max(1, round(duration / 10)))
		keys += list(list(0, dy, 0, 1, 2, QUAD_EASING | (up ? EASE_OUT : EASE_IN)))
		keys += list(list(0, 0, 0, 1, 4, SINE_EASING))
		keys += list(list(0, 0, 0, 1, 4, LINEAR_EASING))
	return body_motion_play(BODY_MOTION_PRIORITY_LOW, BODY_MOTION_FULL, keys) ? body_motion_serial : 0

// Ends motion number `serial` if it is still the running one, back to the
// posture transform over `time` ds.
/mob/living/human/proc/body_motion_stop(serial, time = 1)
	if (!serial || serial != body_motion_serial || world.time >= body_motion_until)
		return FALSE
	var/matrix/rest = posture_transform()
	body_motion_claim(body_motion_priority, time, rest)
	animate(src, transform = rest, time = time, easing = SINE_EASING | EASE_IN, flags = ANIMATION_PARALLEL, tag = BODY_MOTION_TAG)
	return TRUE

// Walking, running and sprinting: a vertical hop with no lean or squash, one
// cycle each time a moving body has no motion running, so the cycle sets the
// cadence. Walk 1px over 4 ds, run 2px over 3 ds, sprint a flatter, faster
// 1px over 2 ds. Upright bodies moving under their own power only. FULL only:
// it loops and carries no gameplay information.
//
// Terrain: shallow water, floodwater, flooded trenches, mud and snow drag the
// body down instead (a 1px sink on a slower beat) unless the footwear is made
// for it; ice glides flat; deep water has its own stroke.
/mob/living/human/proc/body_motion_stride()
	if (world.time < body_motion_until || lying || prone || buckled || riding || pulledby)
		return FALSE
	if (free_diving || swim_skill_applies(loc))
		return FALSE
	if (istype(loc, /turf/floor/beach/water/ice))
		return FALSE
	var/list/keys
	var/haul = body_motion_haul_dir()
	if (haul && (m_intent == "walk" || m_intent == "run"))
		// Hauling something heavy: an 8 degree heave away from the load on the
		// step, held, then eased back. North and south shift 1px instead. 7 ds.
		var/list/f = body_motion_forward(haul)
		return body_motion_play(BODY_MOTION_PRIORITY_STRIDE, BODY_MOTION_REDUCED, list(
			list(0, f[2], 8 * f[3], 1, 2, QUAD_EASING | EASE_OUT),
			list(0, f[2], 8 * f[3], 1, 3, LINEAR_EASING),
			list(0, 0, 0, 1, 2, SINE_EASING | EASE_IN)))
	var/drag = body_motion_terrain_drags()
	if (m_intent == "run")
		if (is_sprinting())
			keys = drag ? list(list(0, -1, 0, 1, 1.5, QUAD_EASING | EASE_IN), list(0, 0, 0, 1, 1.5, QUAD_EASING | EASE_OUT)) \
				: list(list(0, 1, 0, 1, 1, QUAD_EASING | EASE_OUT), list(0, 0, 0, 1, 1, QUAD_EASING | EASE_IN))
		else
			keys = drag ? list(list(0, -1, 0, 1, 2, QUAD_EASING | EASE_IN), list(0, 0, 0, 1, 2, QUAD_EASING | EASE_OUT)) \
				: list(list(0, 2, 0, 1, 1.5, QUAD_EASING | EASE_OUT), list(0, 0, 0, 1, 1.5, QUAD_EASING | EASE_IN))
	else if (m_intent == "walk")
		keys = drag ? list(list(0, -1, 0, 1, 3, SINE_EASING | EASE_IN), list(0, 0, 0, 1, 3, SINE_EASING | EASE_OUT)) \
			: list(list(0, 1, 0, 1, 2, SINE_EASING | EASE_OUT), list(0, 0, 0, 1, 2, SINE_EASING | EASE_IN))
	else
		return FALSE
	return body_motion_play(BODY_MOTION_PRIORITY_STRIDE, BODY_MOTION_FULL, keys)

// Whether the ground here drags at the feet: shallow or flood water, a flooded
// trench, mud or snow, unless the footwear is made for it (the same footwear
// that keeps its wearer on top of the snow, or wades and stays out of the mud).
/mob/living/human/proc/body_motion_terrain_drags()
	var/turf/floor/F = loc
	if (!istype(F))
		return FALSE
	if (istype(F, /turf/floor/beach/water) || istype(F, /turf/floor/trench/flooded))
		return footwear_terrain_mult(src, "wade") > 0.6
	if (!F.iscovered())
		var/band = flood_band_at(F)
		if (band >= FLOOD_BAND_ANKLE && band <= FLOOD_BAND_WAIST)
			return footwear_terrain_mult(src, "wade") > 0.6
	if (F.has_snow_cover())
		return footwear_terrain_mult(src, "snow") > 0.4
	if (F.muddy)
		return footwear_terrain_mult(src, "mud") > 0.6
	return FALSE

// The direction away from a heavy load being pulled, or 0. Heavy means the
// load adds a tile delay of 1 ds or more: a body, a mounted gun, a loaded cart.
/mob/living/human/proc/body_motion_haul_dir()
	if (!pulling || !isturf(pulling.loc))
		return 0
	var/added = 0
	if (ismob(pulling))
		added = 1.25
	else if (istype(pulling, /obj/item/weapon/gun/projectile/automatic/stationary))
		added = 1
	else if (istype(pulling, /obj/structure))
		var/obj/structure/S = pulling
		added = S.drag_delay(src)
	if (added * pull_drag_mult() < 1)
		return 0
	return get_dir(pulling, src)

// Firing a gun: kicked back 2px (3px for a large gun) with a 5 degree roll
// back, home over 2 ds. North and south shift only. Kept at REDUCED: it shows
// who fired. 3 ds.
/mob/living/human/proc/body_motion_fire(atom/target, obj/item/weapon/gun/G)
	var/direction = (target && get_turf(target) != get_turf(src)) ? get_dir(src, target) : dir
	var/list/f = body_motion_forward(direction)
	var/kick = (istype(G) && G.w_class >= ITEM_SIZE_LARGE) ? 3 : 2
	return body_motion_play(BODY_MOTION_PRIORITY_COMBAT, BODY_MOTION_REDUCED, list(
		list(-kick * f[1], -kick * f[2], -5 * f[3], 1, 1, QUAD_EASING | EASE_OUT),
		list(0, 0, 0, 1, 2, QUAD_EASING | EASE_IN)))

// Throwing: 1px back, then a 3px drive with a 6 degree roll into the throw
// (a squash at the feet north and south), home over 2 ds. Kept at REDUCED: it
// shows who threw. 4 ds.
/mob/living/human/proc/body_motion_throw(atom/target)
	var/direction = (target && get_turf(target) != get_turf(src)) ? get_dir(src, target) : dir
	var/list/f = body_motion_forward(direction)
	return body_motion_play(BODY_MOTION_PRIORITY_COMBAT, BODY_MOTION_REDUCED, list(
		list(-f[1], -f[2], 0, 1, 1, LINEAR_EASING),
		list(3 * f[1], 3 * f[2], 6 * f[3], f[3] ? 1 : 0.96, 1, QUAD_EASING | EASE_OUT),
		list(0, 0, 0, 1, 2, QUAD_EASING | EASE_IN)))

// Shoved: 4px and a 10 degree roll away from the shover (a squash north and
// south), back over 3 ds. Kept at REDUCED: it shows the shove. 5 ds.
/mob/living/human/proc/body_motion_knockback(atom/source)
	if (!source || source == src)
		return FALSE
	var/list/f = body_motion_forward(get_dir(source, src))
	if (!f[1] && !f[2])
		return FALSE
	return body_motion_play(BODY_MOTION_PRIORITY_COMBAT, BODY_MOTION_REDUCED, list(
		list(4 * f[1], 4 * f[2], 10 * f[3], f[3] ? 1 : 0.94, 2, QUAD_EASING | EASE_OUT),
		list(0, 0, 0, 1, 3, SINE_EASING | EASE_IN)))

// Picking something up off the ground: a stoop, squashed at the feet, 1px
// toward it, and back. 4 ds.
/mob/living/human/proc/body_motion_stoop(atom/target)
	var/turf/T = get_turf(target)
	var/direction = (T && T != get_turf(src)) ? get_dir(src, T) : dir
	var/list/f = body_motion_forward(direction)
	return body_motion_play(BODY_MOTION_PRIORITY_LOW, BODY_MOTION_FULL, list(
		list(f[1], f[2], 0, 0.88, 2, SINE_EASING | EASE_OUT),
		list(0, 0, 0, 1, 2, SINE_EASING | EASE_IN)))

// Kneeling to treat someone: squash lower than a stoop and 1px toward the patient over 3 ds,
// hold for the treatment, then rise over 3 ds. Kept at REDUCED: it shows who
// is treating. Returns the motion's serial for body_motion_stop(serial, 3),
// or 0 when none played.
/mob/living/human/proc/body_motion_kneel(atom/patient, duration)
	if (!may_do_after || !may_do_mob)
		return 0
	var/turf/T = get_turf(patient)
	var/direction = (T && T != get_turf(src)) ? get_dir(src, T) : dir
	var/list/f = body_motion_forward(direction)
	var/played = body_motion_play(BODY_MOTION_PRIORITY_LOW, BODY_MOTION_REDUCED, list(
		list(f[1], f[2], 0, 0.8, 3, SINE_EASING | EASE_OUT),
		list(f[1], f[2], 0, 0.8, max(1, duration), LINEAR_EASING),
		list(0, 0, 0, 1, 3, SINE_EASING | EASE_IN)))
	return played ? body_motion_serial : 0
