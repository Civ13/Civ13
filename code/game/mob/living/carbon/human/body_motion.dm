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
	// The posture transform the running motion returns to.
	var/tmp/matrix/body_motion_rest = null
	// Whether the last drawn posture was turned (lying or prone); null = never drawn.
	var/tmp/body_motion_drawn_turned = null
	var/tmp/body_motion_watch_checked = -100
	var/tmp/body_motion_watch_cached = FALSE

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
	// At most one motion start per BODY_MOTION_MIN_GAP; posture changes always play.
	if (priority < BODY_MOTION_PRIORITY_POSTURE && world.time < body_motion_started + BODY_MOTION_MIN_GAP)
		return FALSE
	return TRUE

/mob/living/human/proc/body_motion_claim(priority, duration, matrix/rest)
	body_motion_priority = priority
	body_motion_started = world.time
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
		animate(src, transform = body_motion_matrix(upright, 0, 0, lean), time = 3, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
		animate(transform = rest, time = 3, easing = SINE_EASING | EASE_OUT)
	else if (turned)
		var/matrix/upright = matrix(transform)
		var/lean = rest.b >= 0 ? 45 : -45 // the side the lying turn goes
		body_motion_claim(BODY_MOTION_PRIORITY_POSTURE, 4, rest)
		animate(src, transform = body_motion_matrix(upright, 0, 0, lean), time = 2, easing = QUAD_EASING | EASE_IN, flags = ANIMATION_PARALLEL)
		animate(transform = body_motion_matrix(rest, 0, -1), time = 1)
		animate(transform = rest, time = 1)
	else
		var/lean = transform.b >= 0 ? 45 : -45
		body_motion_claim(BODY_MOTION_PRIORITY_POSTURE, 6, rest)
		animate(src, transform = body_motion_matrix(rest, 0, 0, lean), time = 3, flags = ANIMATION_PARALLEL)
		animate(transform = rest, time = 3, easing = SINE_EASING | EASE_OUT)

// Hit recoil: 3px away from the attacker with an 8 degree roll away, back over
// 3 ds. A body lying down only shifts.
/mob/living/human/proc/body_motion_recoil(atom/attacker)
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
	body_motion_claim(BODY_MOTION_PRIORITY_COMBAT, 3, rest)
	animate(src, transform = away, time = 1, easing = LINEAR_EASING, flags = ANIMATION_PARALLEL)
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
			animate(src, transform = M, time = key[5], easing = key[6], flags = ANIMATION_PARALLEL)
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
