// used to be called "reset_view" before we realized it already existed, but its
// only purpose was to reset the eye and HUD overlays - what the fuck guys?
// you really need to get better at nomenclature, I guess
// The view this client returns to: widescreen unless the player chose square.
/client/proc/default_view()
	return is_preference_enabled(/datum/client_preference/square_view) ? SQUARE_VIEW : WORLD_VIEW

// Widens the default view by n tiles on every side (scope and look zoom).
/client/proc/widen_view(n)
	var/list/V = getviewsize(default_view())
	view = "[V[1] + 2 * n]x[V[2] + 2 * n]"

// Puts the client on its default view, lays the HUD out for it again and
// refits the map pane so the side panel takes the rest of the window.
/client/proc/apply_default_view()
	view = default_view()
	if (ishuman(mob))
		var/mob/living/human/H = mob
		if (H.hud_used)
			H.apply_hud_layout()
	fit_viewport_soon()

/mob/proc/reset_zoom()
	if (client)
		client.view = client.default_view()
		client.pixel_x = FALSE
		client.pixel_y = FALSE
		return TRUE
	return FALSE
