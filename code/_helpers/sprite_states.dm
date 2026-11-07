// Sprite state lookups. BYOND draws its error icon for a state that an icon
// file does not have, so code that builds state names (such as "[base]_open"
// for an unloaded gun) checks them here and falls back to a state that exists.

// Whether an icon file has the state. icon_states() reads the whole file, so
// the states of each icon file are cached. Icons built at runtime are not
// checked (reading them on every redraw costs too much) and count as having it.
/proc/icon_has_state(icon_file, state)
	var/static/list/states_by_file = list()
	if (!icon_file || isnull(state))
		return FALSE
	if (!isfile(icon_file))
		return TRUE
	var/key = "[icon_file]"
	var/list/states = states_by_file[key]
	if (!states)
		states = list()
		for (var/S in icon_states(icon_file))
			states[S] = TRUE
		states_by_file[key] = states
	return states["[state]"] == TRUE

// States to try, best first, when the one an item asks for is missing.
/obj/item/proc/fallback_sprite_states()
	return list(initial(item_state), initial(icon_state))

// The state to draw from icon_file: state when the file has it, otherwise
// state with its unloaded/opened suffixes dropped one at a time
// ("x_open_empty", "x_open", "x"), then the item's fallback states. Returns
// state unchanged when nothing fits.
/obj/item/proc/sprite_state_for(icon_file, state)
	var/static/list/suffixes = list("_empty", "-empty", "_open")
	if (!icon_file || !state || icon_has_state(icon_file, state))
		return state
	var/trimmed = "[state]"
	var/found = TRUE
	while (found)
		found = FALSE
		for (var/suffix in suffixes)
			var/cut = length(trimmed) - length(suffix)
			if (cut > 0 && copytext(trimmed, cut + 1) == suffix)
				trimmed = copytext(trimmed, 1, cut + 1)
				if (icon_has_state(icon_file, trimmed))
					return trimmed
				found = TRUE
				break
	for (var/candidate in fallback_sprite_states())
		if (candidate && icon_has_state(icon_file, candidate))
			return candidate
	return state

// Points icon_state at a state that the item's own icon has.
/obj/item/proc/settle_icon_state()
	icon_state = sprite_state_for(icon, icon_state)
