// ============================================================
// The spirit HUD.
// ------------------------------------------------------------
// A spirit (a player ghost on a persistent world, spirit_observe.dm) gets a
// small row along the bottom of the view:
//   * a status plate: "Bound to your body" (click to start moving on),
//     "Moving on mm:ss", "Free - Respawn" (click to respawn), "Out of body"
//     (click to return to a living body) or "Observing" for lobby observers;
//   * while leashed or lingering, a "N / 15 tiles" readout of how far the
//     spirit is from what holds it, turning warm near the edge;
//   * Haunt, Jump and, with a body to go back to, Return buttons.
// Staff and admin ghosts keep the plain observer screen. Ghosts have no other
// HUD, so nothing else shares these screen tiles.
//
// Art: icons/mob/screen/spirit_hud.dmi, drawn by spirit_hud_sprite.py.
// ============================================================

#define SPIRIT_HUD_TICK 10       // deciseconds between refreshes
#define SPIRIT_HUD_WARN 3        // tiles from the end of the leash that read as near
#define SPIRIT_HUD_INK "#e8f0ff"
#define SPIRIT_HUD_DIM "#b0c0e0"
#define SPIRIT_HUD_WARM "#ffb878"

/mob/observer/ghost
	var/tmp/list/spirit_hud = null       // name -> /obj/screen/spirit_hud
	var/tmp/spirit_hud_timer = null
	var/tmp/spirit_hud_busy = FALSE      // a prompt opened from the HUD is still up
	var/tmp/spirit_hud_until = 0         // the binding's "until" the countdown was set from
	var/tmp/spirit_hud_ends = 0          // world.time the countdown reaches zero

/proc/spirit_hud_span(text, px = 11, colour = SPIRIT_HUD_INK)
	return "<span style='font-family:Verdana,sans-serif;font-size:[px]px;-dm-text-outline:1px #0e1422;color:[colour]'>[text]</span>"

/proc/spirit_hud_text(title, hint = null, px = 11, colour = SPIRIT_HUD_INK)
	. = spirit_hud_span(title, px, colour)
	if (hint)
		. += "<br>" + spirit_hud_span(hint, 9, SPIRIT_HUD_DIM)
	return "<div style='text-align:center;vertical-align:middle'>[.]</div>"

/obj/screen/spirit_hud
	name = "spirit"
	icon = 'icons/mob/screen/spirit_hud.dmi'
	icon_state = "plate_m"
	should_save = FALSE
	appearance_flags = NO_CLIENT_COLOR | RESET_COLOR | RESET_TRANSFORM | RESET_ALPHA
	maptext_height = 32
	var/tmp/mob/observer/ghost/spirit = null
	var/tmp/shown_text = null

/obj/screen/spirit_hud/Destroy()
	spirit = null
	return ..()

// Adds the rest of a piece that is wider than one tile.
/obj/screen/spirit_hud/proc/extend(list/states)
	var/offset = 0
	for (var/state in states)
		offset += 32
		var/image/part = image(icon, icon_state = state)
		part.pixel_x = offset
		overlays += part

/obj/screen/spirit_hud/proc/show(text)
	if (text == shown_text)
		return
	shown_text = text
	maptext = text

/obj/screen/spirit_hud/Click(location, control, params)
	var/mob/observer/ghost/G = usr
	if (!istype(G) || G != spirit || !G.client || !G.is_spirit() || G.spirit_hud_busy)
		return TRUE
	G.spirit_hud_busy = TRUE
	pressed(G)
	if (!QDELETED(G))
		G.spirit_hud_busy = FALSE
		G.spirit_hud_refresh()
	return TRUE

/obj/screen/spirit_hud/proc/pressed(mob/observer/ghost/G)
	return

// ---- The status plate -----------------------------------------------------------

/obj/screen/spirit_hud/plate
	name = "Spirit"
	icon_state = "plate_observe"
	screen_loc = "CENTER-5,SOUTH:6"
	maptext_x = 26
	maptext_width = 130
	var/tmp/state = "observe"

/obj/screen/spirit_hud/plate/New()
	..()
	extend(list("plate_m", "plate_m", "plate_m", "plate_r"))

/obj/screen/spirit_hud/plate/pressed(mob/observer/ghost/G)
	switch (state)
		if ("bound", "moving")
			G.spirit_wait_blocks() // spirit_wait.dm: the Move on prompt, or the time left
		if ("free")
			G.abandon_mob()
		if ("away")
			G.reenter_corpse()

// ---- The reach readout ----------------------------------------------------------

/obj/screen/spirit_hud/reach
	name = "Reach"
	icon_state = "reach_l"
	screen_loc = "CENTER-5,SOUTH:24"
	mouse_opacity = FALSE
	maptext_y = 16
	maptext_width = 88
	maptext_height = 16

/obj/screen/spirit_hud/reach/New()
	..()
	extend(list("reach_m", "reach_r"))

// ---- Buttons --------------------------------------------------------------------

/obj/screen/spirit_hud/button
	maptext_x = 22
	maptext_width = 36
	var/label = ""

/obj/screen/spirit_hud/button/New()
	..()
	extend(list("button_r"))
	show(spirit_hud_text(label, null, 10))

/obj/screen/spirit_hud/button/haunt
	name = "Haunt - follow someone living"
	icon_state = "haunt"
	screen_loc = "CENTER:2,SOUTH:6"
	label = "Haunt"

/obj/screen/spirit_hud/button/haunt/pressed(mob/observer/ghost/G)
	var/mob/M = G.spirit_hud_pick("Haunt whom?", "Haunt")
	if (M)
		G.ManualFollow(M)

/obj/screen/spirit_hud/button/jump
	name = "Jump - go to someone living"
	icon_state = "jump"
	screen_loc = "CENTER+2:2,SOUTH:6"
	label = "Jump"

/obj/screen/spirit_hud/button/jump/pressed(mob/observer/ghost/G)
	var/mob/M = G.spirit_hud_pick("Jump to whom?", "Jump")
	var/turf/T = get_turf(M)
	if (!T)
		return
	G.stop_following()
	if (!G.forceMove(T) && G.arcane_anchor)
		to_chat(G, SPAN_NOTICE("They are beyond your reach."))

/obj/screen/spirit_hud/button/body
	name = "Return to your body"
	icon_state = "return"
	screen_loc = "CENTER+4:2,SOUTH:6"
	label = "Return"

/obj/screen/spirit_hud/button/body/pressed(mob/observer/ghost/G)
	G.reenter_corpse()

// ---- The ghost's side -----------------------------------------------------------

// The living player picked from the same list the Haunt and Jump verbs offer.
/mob/observer/ghost/proc/spirit_hud_pick(message, title)
	var/list/targets = observer_targets()
	if (!length(targets))
		to_chat(src, SPAN_NOTICE("There is no one living to go to."))
		return null
	var/choice = player_input(src, message, title, null, "anything", targets, TRUE)
	if (!choice || QDELETED(src) || !client)
		return null
	var/mob/M = targets[choice]
	if (!istype(M) || QDELETED(M) || !isturf(M.loc))
		return null
	return M

// TRUE while the Return button applies: the same test Re-enter Corpse makes.
/mob/observer/ghost/proc/spirit_hud_has_body()
	return mind && mind.current && can_reenter_corpse && !QDELETED(mind.current)

// What the plate shows: list(state, title, hint).
/mob/observer/ghost/proc/spirit_hud_status()
	var/list/B = spirit_binding(ckey) // spirit_wait.dm
	if (B)
		var/until = B["until"]
		if (!until)
			spirit_hud_until = 0
			return list("bound", "Bound to your body", "Click to move on")
		// world.realtime is too coarse to count seconds with, so the countdown
		// runs on world.time from the first refresh that sees this "until".
		if (until != spirit_hud_until)
			spirit_hud_until = until
			spirit_hud_ends = world.time + max(0, until - world.realtime)
		var/left = max(0, round((spirit_hud_ends - world.time) / 10))
		if (!left)
			return list("moving", "Moving on", "Any moment now")
		var/seconds = left % 60
		return list("moving", "Moving on [round(left / 60)]:[seconds < 10 ? "0" : ""][seconds]", "Then you may respawn")
	spirit_hud_until = 0
	if (spirit_hud_has_body() && mind.current.stat != DEAD)
		return list("away", "Out of body", "Click to return")
	if (started_as_observer)
		return list("observe", "Observing", "Haunt or jump to the living")
	return list("free", "Free - Respawn", "Click to respawn")

/mob/observer/ghost/proc/spirit_hud_build()
	spirit_hud = list(
		"plate" = new /obj/screen/spirit_hud/plate,
		"reach" = new /obj/screen/spirit_hud/reach,
		"haunt" = new /obj/screen/spirit_hud/button/haunt,
		"jump" = new /obj/screen/spirit_hud/button/jump,
		"body" = new /obj/screen/spirit_hud/button/body)
	for (var/key in spirit_hud)
		var/obj/screen/spirit_hud/S = spirit_hud[key]
		S.spirit = src

// Shows and updates the HUD for a spirit, removes it for anyone else. Called
// from spirit_update_sight() (Login) and then once a second by its own timer.
/mob/observer/ghost/proc/spirit_hud_refresh()
	if (QDELETED(src) || !client || !is_spirit())
		spirit_hud_remove()
		return
	if (!spirit_hud)
		spirit_hud_build()
	if (!spirit_hud_timer)
		spirit_hud_timer = addtimer(CALLBACK(src, PROC_REF(spirit_hud_refresh)), SPIRIT_HUD_TICK, TIMER_LOOP | TIMER_STOPPABLE)

	var/obj/screen/spirit_hud/plate/plate = spirit_hud["plate"]
	var/list/status = spirit_hud_status()
	plate.state = status[1]
	if (plate.icon_state != "plate_[plate.state]")
		plate.icon_state = "plate_[plate.state]"
	plate.show(spirit_hud_text(status[2], status[3]))
	plate.name = "[status[2]] - [lowertext(status[3])]"
	client.screen |= plate
	client.screen |= spirit_hud["haunt"]
	client.screen |= spirit_hud["jump"]

	var/obj/screen/spirit_hud/body = spirit_hud["body"]
	if (spirit_hud_has_body())
		client.screen |= body
	else
		client.screen -= body

	var/obj/screen/spirit_hud/reach = spirit_hud["reach"]
	spirit_refresh_leash() // spirit_wait.dm: the leash follows a carried body
	var/turf/here = get_turf(src)
	if (arcane_anchor && here && here.z == arcane_anchor.z)
		var/range = arcane_spirit_range() // arcane_spirits.dm
		var/far = get_dist(here, arcane_anchor)
		reach.show(spirit_hud_text("[far] / [range] tiles", null, 10, far >= range - SPIRIT_HUD_WARN ? SPIRIT_HUD_WARM : SPIRIT_HUD_INK))
		client.screen |= reach
	else
		client.screen -= reach

/mob/observer/ghost/proc/spirit_hud_remove()
	if (spirit_hud_timer)
		deltimer(spirit_hud_timer)
		spirit_hud_timer = null
	if (!spirit_hud)
		return
	for (var/key in spirit_hud)
		var/obj/screen/spirit_hud/S = spirit_hud[key]
		if (client)
			client.screen -= S
		qdel(S)
	spirit_hud = null

#undef SPIRIT_HUD_TICK
#undef SPIRIT_HUD_WARN
#undef SPIRIT_HUD_INK
#undef SPIRIT_HUD_DIM
#undef SPIRIT_HUD_WARM
