// Smoke signals from a lit campfire or fire pit.
//
// Hit a burning fire with leather or cloth to send up puffs of smoke. Each
// signal uses one piece of the stack and the fire needs a short rest before
// the next one. Smoke only gets away from a fire under the open sky, and only
// people under the open sky can see it: a roof stops it both ways. Everyone
// awake, outdoors and on the same level within SIGNAL_FIRE_RANGE tiles is
// told which way the smoke is and roughly how far. A fire on a roof is seen
// further, and from the ground below as well.

#define SIGNAL_FIRE_RANGE 300
#define SIGNAL_FIRE_COOLDOWN 300 // deciseconds
#define SIGNAL_FIRE_NEAR 20
#define SIGNAL_FIRE_MIDDLE 80
#define SIGNAL_FIRE_FAR 160

/obj/structure/oven/fireplace
	var/next_signal = 0 // world.time when the fire can signal again; not saved.

/obj/structure/oven/fireplace/persistence_runtime_var(key)
	return key == "next_signal" || ..()

/proc/signal_fire_material(obj/item/I)
	return istype(I, /obj/item/stack/material/leather) || istype(I, /obj/item/stack/material/cloth)

// Smoke escapes, and can be seen, only under the open sky.
/proc/signal_fire_open_sky(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return FALSE
	var/area/AR = get_area(T)
	return AR && AR.location == AREA_OUTSIDE

// A fire on a roof, a storey or more above the ground, is seen further and
// from the ground below too.
#define SIGNAL_FIRE_STOREY_RANGE 100 // extra tiles per storey above the ground
#define SIGNAL_FIRE_MAX_STOREYS 4

/proc/signal_fire_flat_dist(atom/A, atom/B)
	return max(abs(A.x - B.x), abs(A.y - B.y))

// Storeys T stands above the ground: 0 on the ground.
/proc/signal_fire_storeys(turf/T)
	. = 0
	while (T && . < SIGNAL_FIRE_MAX_STOREYS && turf_is_above_ground(T))
		.++
		var/below = multiz_level_below(T.z)
		T = below ? locate(T.x, T.y, below) : null

/proc/signal_fire_range(turf/fire_turf)
	return SIGNAL_FIRE_RANGE + SIGNAL_FIRE_STOREY_RANGE * signal_fire_storeys(fire_turf)

// Whether someone on level z can see smoke rising from fire_turf: the same
// level, or any level below a rooftop fire.
/proc/signal_fire_level_sees(z, turf/fire_turf)
	if (z == fire_turf.z)
		return TRUE
	var/level = fire_turf.z
	for (var/i = 1 to signal_fire_storeys(fire_turf))
		level = multiz_level_below(level)
		if (!level)
			return FALSE
		if (level == z)
			return TRUE
	return FALSE

// "to the north-west, far off" as seen from viewer_turf: one of eight compass
// points by the true bearing, plus a vague distance. get_dir would call a fire
// 200 tiles north and 1 east "northeast".
/proc/signal_fire_bearing(turf/viewer_turf, turf/fire_turf)
	var/dist = signal_fire_flat_dist(viewer_turf, fire_turf)
	if (dist <= 1)
		return "right beside you"
	var/how_far = "very far off"
	if (dist <= SIGNAL_FIRE_NEAR)
		how_far = "close by"
	else if (dist <= SIGNAL_FIRE_MIDDLE)
		how_far = "some way off"
	else if (dist <= SIGNAL_FIRE_FAR)
		how_far = "far off"
	var/dx = fire_turf.x - viewer_turf.x
	var/dy = fire_turf.y - viewer_turf.y
	var/ns = dy > 0 ? "north" : "south"
	var/ew = dx > 0 ? "east" : "west"
	// tan(67.5) is about 2.414: steeper than that is straight N/S, flatter is E/W.
	var/dir_text = "[ns]-[ew]"
	if (abs(dy) * 1000 > abs(dx) * 2414)
		dir_text = ns
	else if (abs(dx) * 1000 > abs(dy) * 2414)
		dir_text = ew
	return "to the [dir_text], [how_far]"

/proc/signal_fire_can_see(mob/living/human/H)
	return H && H.stat == CONSCIOUS && !H.blinded && !H.paralysis && H.sleeping <= 0

// The people who see a signal from fire F (the signaller is told separately).
/obj/structure/oven/fireplace/proc/signal_fire_watchers(mob/signaller)
	. = list()
	var/turf/T = get_turf(src)
	if (!T || !signal_fire_open_sky(T))
		return
	// The whole human list, not range(): a turf scan this wide would be slow.
	for (var/mob/living/human/H in human_mob_list)
		// Match to_chat_wrapper's recipient routes for human mobs.
		if (!H.client && !agent_characters[H])
			continue
		if (H == signaller || !signal_fire_level_sees(H.z, T) || signal_fire_flat_dist(H, T) > signal_fire_range(T) || !signal_fire_can_see(H))
			continue
		if (!signal_fire_open_sky(H))
			continue
		. += H

// Returns TRUE when the attack was used up by the signal attempt.
/obj/structure/oven/fireplace/proc/send_smoke_signal(obj/item/stack/S, mob/living/human/user)
	if (!on || !istype(S) || !user)
		return FALSE
	if (!signal_fire_open_sky(src))
		to_chat(user, SPAN_WARNING("There is a roof over \the [name]. The smoke would just fill the room."))
		return TRUE
	if (world.time < next_signal)
		to_chat(user, SPAN_WARNING("The smoke from your last signal is still hanging over \the [name]. Give it a moment."))
		return TRUE
	next_signal = world.time + SIGNAL_FIRE_COOLDOWN
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	var/what = S.singular_name || S.name
	user.visible_message(SPAN_NOTICE("[user] waves \a [what] over \the [name], sending up puffs of smoke."), SPAN_NOTICE("You wave \a [what] over \the [name], sending up puffs of smoke. It scorches through."))
	S.use(1)
	show_signal_plume()
	player_activity.feature_used(user, "signal_fire")
	var/turf/T = get_turf(src)
	var/list/watchers = signal_fire_watchers(user)
	for (var/mob/living/human/H in watchers)
		to_chat(H, "<b>You see smoke signals rising [signal_fire_bearing(get_turf(H), T)]...</b>")
		// Once per visit: what a signal means and how to answer it.
		if (H.client && !H.client.signal_fire_hint_shown)
			H.client.signal_fire_hint_shown = TRUE
			to_chat(H, SPAN_NOTICE("Someone is calling from a fire. Walk that way to find them, or answer with a signal of your own: use leather or cloth on a lit campfire or fire pit under the open sky."))
	to_chat(user, SPAN_NOTICE(watchers.len ? "Someone out there can see it." : "Nobody seems to be in sight of it right now. Anyone outdoors within a long walk would have seen it."))
	// On the mainland the signaller may invite newcomers (immigration_fires.dm).
	addtimer(CALLBACK(src, PROC_REF(immigration_offer), user), 1)
	return TRUE

// Told once per connection what a smoke signal is (send_smoke_signal).
/client/var/signal_fire_hint_shown = FALSE

// A burning fire under the open sky says how to signal. An override, because
// the examine in oven.dm is byte-pinned by other tests.
/obj/structure/oven/fireplace/examine(mob/user)
	. = ..()
	if (on && signal_fire_open_sky(src))
		to_chat(user, SPAN_NOTICE("Use leather or cloth on it to send a smoke signal. People outdoors a long way off will see which way to walk to find you."))

// The visible column of smoke over the fire: a 32x96 icon whose bottom edge is
// the fire's tile. It fades in, drifts up a little and thins away. It is a
// passing effect, so it is never written to a save.
/obj/effect/signal_plume
	name = "smoke signal"
	icon = 'icons/effects/signal_smoke.dmi'
	icon_state = "signal_plume"
	mouse_opacity = FALSE
	anchored = TRUE
	density = FALSE
	layer = 6 // over mobs and trees, like other smoke
	alpha = 0
	should_save = FALSE
	var/time_to_live = 120 // deciseconds

/obj/effect/signal_plume/New()
	effect_lifetime = list()
	var/list/lifetime = effect_lifetime
	..()
	animate(src, alpha = 255, time = 15)
	animate(pixel_y = 6, time = time_to_live - 45)
	animate(alpha = 0, pixel_y = 12, time = 30)
	addtimer(CALLBACK(GLOBAL_PROC, .proc/retire_effect_lifetime, src, lifetime), time_to_live)

/obj/structure/oven/fireplace/proc/show_signal_plume()
	var/turf/T = get_turf(src)
	if (T)
		new /obj/effect/signal_plume(T)

#undef SIGNAL_FIRE_RANGE
#undef SIGNAL_FIRE_COOLDOWN
#undef SIGNAL_FIRE_NEAR
#undef SIGNAL_FIRE_MIDDLE
#undef SIGNAL_FIRE_FAR
#undef SIGNAL_FIRE_STOREY_RANGE
#undef SIGNAL_FIRE_MAX_STOREYS
