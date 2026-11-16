// Nearsighted and Farsighted traits.
//
// Nearsighted draws one fixed fog vignette on the player's screen: clear near
// the centre, grey and darker toward the edges. It is a single screen object
// per client, set up once and only touched again when the view size or the
// squint state changes, so it costs the client one extra draw and the server
// nothing per tile. Standing still lets the player squint, which thins it.
//
// Farsighted squints before a paper or book opens and reads/writes slower.
// Corrective glasses or a monocle remove both. Neither trait ever blocks play.

// Existing full-screen haze art (480x480), tinted grey and stretched to the view.
#define SIGHT_FOG_ICON 'icons/mob/screen1_full.dmi'
#define SIGHT_FOG_STATE "passage7"
#define SIGHT_FOG_COLOR "#353a42"
#define SIGHT_FOG_ALPHA 255
// Fog alpha after standing still on the same tile for a life tick.
#define SIGHT_FOG_SQUINT_ALPHA 130
// Stretch a little past the view so the art's edge never shows.
#define SIGHT_FOG_OVERSCAN 1.06

#define FARSIGHT_SQUINT_TIME 20
// Re-reading the same page soon after needs no second squint.
#define FARSIGHT_FOCUS_TIME 600
#define FARSIGHT_READING_MULT 1.5

/obj/item/clothing/glasses
	// Prescription lenses: cancel the Nearsighted and Farsighted traits.
	var/corrects_vision = FALSE

/obj/item/clothing/glasses/regular
	corrects_vision = TRUE

/obj/item/clothing/glasses/monocle
	corrects_vision = TRUE

/obj/screen/sight_fog
	name = ""
	icon = SIGHT_FOG_ICON
	icon_state = SIGHT_FOG_STATE
	color = SIGHT_FOG_COLOR
	alpha = SIGHT_FOG_ALPHA
	mouse_opacity = FALSE
	plane = HUD_PLANE
	layer = 1 // under every HUD button
	appearance_flags = NO_CLIENT_COLOR | RESET_COLOR

/client
	var/tmp/obj/screen/sight_fog/sight_fog = null
	var/tmp/sight_fog_view = null
	var/tmp/turf/sight_fog_turf = null
	var/tmp/sight_fog_squinting = FALSE
	// page ref -> world.time its squint stops covering it
	var/tmp/list/farsight_focus = null

/client/proc/fit_sight_fog()
	var/list/V = getviewsize(view)
	var/w = V[1] * world.icon_size
	var/h = V[2] * world.icon_size
	sight_fog.screen_loc = "WEST:[round((w - 480) / 2)],SOUTH:[round((h - 480) / 2)]"
	sight_fog.transform = matrix(w / 480 * SIGHT_FOG_OVERSCAN, 0, 0, 0, h / 480 * SIGHT_FOG_OVERSCAN, 0)
	sight_fog_view = view

/client/proc/clear_sight_fog()
	if (sight_fog)
		// Back to full strength, so the next showing is not stuck mid-squint.
		animate(sight_fog, alpha = SIGHT_FOG_ALPHA, time = 0)
		screen -= sight_fog
	sight_fog_turf = null
	sight_fog_squinting = FALSE

/mob/living/human/proc/has_corrective_eyewear()
	var/obj/item/clothing/glasses/G = eyes
	return istype(G) && G.corrects_vision

/mob/living/human/proc/needs_sight_fog()
	if (stat == DEAD)
		return FALSE
	if (!find_trait("Nearsighted") && !(disabilities & NEARSIGHTED))
		return FALSE
	return !has_corrective_eyewear()

// Called from handle_vision() every life tick; cheap when nothing changed.
/mob/living/human/proc/update_sight_fog()
	if (!client)
		return
	if (!needs_sight_fog())
		client.clear_sight_fog()
		return
	if (!client.sight_fog)
		client.sight_fog = new /obj/screen/sight_fog
	if (client.sight_fog_view != client.view)
		client.fit_sight_fog()
	if (!(client.sight_fog in client.screen))
		client.screen += client.sight_fog
	var/turf/T = get_turf(src)
	var/squint = (T && T == client.sight_fog_turf)
	client.sight_fog_turf = T
	if (squint != client.sight_fog_squinting)
		client.sight_fog_squinting = squint
		animate(client.sight_fog, alpha = squint ? SIGHT_FOG_SQUINT_ALPHA : SIGHT_FOG_ALPHA, time = squint ? 10 : 3)

/mob/living/human/proc/farsight_reading_mult()
	if (!find_trait("Farsighted") || has_corrective_eyewear())
		return 1
	return FARSIGHT_READING_MULT

// Farsighted readers squint at a page before it opens. Never refuses for
// good: a short wait, then the page opens as normal.
/proc/farsight_can_read(mob/user, atom/target)
	if (!ishuman(user))
		return TRUE
	var/mob/living/human/H = user
	if (!H.find_trait("Farsighted") || H.has_corrective_eyewear())
		return TRUE
	var/client/C = H.client
	var/focus = "\ref[target]"
	if (C && C.farsight_focus)
		for (var/page in C.farsight_focus.Copy())
			if (C.farsight_focus[page] <= world.time)
				C.farsight_focus -= page
		if (C.farsight_focus[focus])
			return TRUE
	to_chat(H, SPAN_NOTICE("You hold \the [target] at arm's length and squint at the writing..."))
	if (!do_after(H, FARSIGHT_SQUINT_TIME, target))
		return FALSE
	if (C)
		if (!C.farsight_focus)
			C.farsight_focus = list()
		C.farsight_focus[focus] = world.time + FARSIGHT_FOCUS_TIME
	return TRUE

#undef SIGHT_FOG_ICON
#undef SIGHT_FOG_STATE
#undef SIGHT_FOG_COLOR
#undef SIGHT_FOG_ALPHA
#undef SIGHT_FOG_SQUINT_ALPHA
#undef SIGHT_FOG_OVERSCAN
#undef FARSIGHT_SQUINT_TIME
#undef FARSIGHT_FOCUS_TIME
