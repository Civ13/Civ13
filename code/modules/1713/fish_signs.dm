// Signs of fish on the water (docs/fishing-grounds.md, "Signs").
//
// Well-stocked water shows it: rings where fish rise, now and then a fish
// leaping clear, gulls wheeling over a shoal on the coast. Thin water shows
// few signs and fished-out water none, so a stretch can be read from the bank
// or the deck without casting into it.
//
// The signs are images only the viewer's client holds
// (icons/effects/fish_signs.dmi, drawn by tests/sprites/create_fishing_signs.py),
// not objects: a hull cannot carry them off, nothing saves them and nobody can
// click them. Every few seconds a client with a living human looks at a handful
// of random tiles in view and asks the fishing ground under each; water nobody
// is looking at costs nothing.

#define FISH_SIGN_RADIUS 9
#define FISH_SIGN_TRIES 14
// Two loops of a rising ring, one of a leap (create_fishing_signs.py).
#define FISH_SIGN_PERIOD 80
#define FISH_SIGN_LAYER 2.03
#define FISH_SIGN_GULL_LAYER 5

/client
	var/tmp/list/fish_sign_candidates = null
	var/tmp/fish_signs_next = 0

// The sign to show on T just now, or null. Chance follows how full the ground is.
/proc/fish_sign_state(turf/T)
	var/kind = fish_water_kind(T)
	if (!kind || kind == FISH_WATER_FLOODED)
		return null
	if (T.iscovered() || (locate(/obj/structure/vehicleparts/frame) in T))
		return null
	if (fish_shoal_at(T))
		// A shoal shows itself whatever the ground under it holds.
		return prob(35) ? "gulls" : (prob(40) ? pick("jump_a", "jump_b") : pick("rise_a", "rise_b", "rise_c"))
	var/datum/fishing_ground/G = fishing_ground_at(T, FALSE)
	if (G && G.available() < 1)
		return null
	if (!prob(round(100 * (G ? G.fullness() : 1))))
		return null
	if (kind == FISH_WATER_SALT && !fish_water_deep(T) && prob(12))
		return "gulls"
	if (prob(kind == FISH_WATER_FRESH && fish_run_season() ? 50 : 20))
		return pick("jump_a", "jump_b")
	return pick("rise_a", "rise_b", "rise_c")

/proc/fish_sign_image(turf/T, state)
	var/image/I = image('icons/effects/fish_signs.dmi', T, state, state == "gulls" ? FISH_SIGN_GULL_LAYER : FISH_SIGN_LAYER)
	I.mouse_opacity = 0
	return I

/client/proc/fish_signs_refresh()
	if (world.time < fish_signs_next)
		return
	fish_signs_next = world.time + FISH_SIGN_PERIOD
	fish_sign_candidates = null
	var/turf/centre = get_turf(eye)
	if (!centre)
		return TRUE
	var/list/drawn = list()
	var/list/seen = list()
	for (var/i = 1 to FISH_SIGN_TRIES)
		var/turf/T = locate(centre.x + rand(-FISH_SIGN_RADIUS, FISH_SIGN_RADIUS), centre.y + rand(-FISH_SIGN_RADIUS, FISH_SIGN_RADIUS), centre.z)
		if (!T || seen[T])
			continue
		seen[T] = TRUE
		var/state = fish_sign_state(T)
		if (state)
			drawn += fish_sign_image(T, state)
	if (drawn.len)
		fish_sign_candidates = drawn
	return TRUE

#undef FISH_SIGN_RADIUS
#undef FISH_SIGN_TRIES
#undef FISH_SIGN_PERIOD
#undef FISH_SIGN_LAYER
#undef FISH_SIGN_GULL_LAYER
