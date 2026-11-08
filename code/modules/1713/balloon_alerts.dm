// Balloon alerts: a short line of text that floats up from an atom and fades,
// shown only to the chosen viewer. Use it for small feedback ("empty",
// "locked") that would otherwise be one more line in chat.
// Adapted from CM-SS13's balloon_alerts.dm (cmss13-devs/cmss13, AGPL-3.0,
// originally from /tg/station); reimplemented without timers for Civ13.

#define BALLOON_TEXT_WIDTH 200
#define BALLOON_TEXT_SPAWN_TIME 2
#define BALLOON_TEXT_FADE_TIME 1
#define BALLOON_TEXT_VISIBLE_TIME 7
// Each character past the first 10 adds 5% to the visible time.
#define BALLOON_TEXT_CHAR_LIFETIME_INCREASE_MULT 0.05
#define BALLOON_TEXT_CHAR_LIFETIME_INCREASE_MIN 10
// The same text from the same atom is not repeated to a viewer within this time.
#define BALLOON_TEXT_REPEAT_DELAY 5

/client/var/tmp/list/balloon_alert_recent = null

/proc/balloon_alert_lifetime(text)
	var/mult = 1
	var/extra = length(text) - BALLOON_TEXT_CHAR_LIFETIME_INCREASE_MIN
	if (extra > 0)
		mult += extra * BALLOON_TEXT_CHAR_LIFETIME_INCREASE_MULT
	return BALLOON_TEXT_SPAWN_TIME + BALLOON_TEXT_VISIBLE_TIME * mult + BALLOON_TEXT_FADE_TIME

// Shows text over this atom to one viewer. Returns TRUE when it was shown.
/atom/proc/balloon_alert(mob/viewer, text, text_color)
	if (!viewer || !viewer.client || !text)
		return FALSE
	var/client/C = viewer.client
	if (!C.balloon_alert_recent)
		C.balloon_alert_recent = list()
	var/key = "\ref[src]|[text]"
	var/last = C.balloon_alert_recent[key]
	if (last && world.time - last < BALLOON_TEXT_REPEAT_DELAY)
		return FALSE
	C.balloon_alert_recent[key] = world.time
	if (C.balloon_alert_recent.len > 50)
		C.balloon_alert_recent.Cut(1, 26)
	balloon_alert_perform(C, text, text_color)
	return TRUE

// Shows text over this atom to every mob that can see it. self_message, if
// given, is what this atom itself sees instead.
/atom/proc/balloon_alert_to_viewers(message, self_message, max_distance = 7, list/ignored_mobs, text_color)
	var/count = 0
	for (var/mob/M in viewers(max_distance, get_turf(src)))
		if (!M.client || (ignored_mobs && (M in ignored_mobs)))
			continue
		if (M.sdisabilities & BLIND || M.blinded)
			continue
		if (balloon_alert(M, (M == src && self_message) ? self_message : message, text_color))
			count++
	return count

/atom/proc/balloon_alert_perform(client/C, text, text_color)
	set waitfor = FALSE
	var/atom/anchor = src
	while (anchor && anchor.loc && !isturf(anchor.loc))
		anchor = anchor.loc
	if (!anchor)
		return
	var/image/I = image(loc = anchor, layer = FLY_LAYER)
	I.plane = CHAT_PLANE
	I.alpha = 0
	if (text_color)
		I.color = text_color
	I.appearance_flags = NO_CLIENT_COLOR | KEEP_APART | RESET_COLOR | RESET_TRANSFORM | RESET_ALPHA
	I.maptext = "<span style=\"text-align: center; font-family: 'Small Fonts'; font-size: 7px; color: #ffffff; -dm-text-outline: 1px #000000;\">[html_encode(text)]</span>"
	I.maptext_width = BALLOON_TEXT_WIDTH
	I.maptext_height = 32
	I.maptext_x = (world.icon_size - BALLOON_TEXT_WIDTH) / 2
	I.maptext_y = world.icon_size - 8
	C.images += I

	var/lifetime = balloon_alert_lifetime(text)
	animate(I, pixel_y = world.icon_size * 1.2, time = lifetime, easing = SINE_EASING | EASE_OUT)
	animate(alpha = 255, time = BALLOON_TEXT_SPAWN_TIME, easing = CUBIC_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
	animate(alpha = 0, time = lifetime - BALLOON_TEXT_SPAWN_TIME, easing = CUBIC_EASING | EASE_IN)
	sleep(lifetime)
	if (C)
		C.images -= I

#undef BALLOON_TEXT_WIDTH
#undef BALLOON_TEXT_SPAWN_TIME
#undef BALLOON_TEXT_FADE_TIME
#undef BALLOON_TEXT_VISIBLE_TIME
#undef BALLOON_TEXT_CHAR_LIFETIME_INCREASE_MULT
#undef BALLOON_TEXT_CHAR_LIFETIME_INCREASE_MIN
#undef BALLOON_TEXT_REPEAT_DELAY
