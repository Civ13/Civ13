// Discrete actions only. Movement and held-item activation retain their paired
// key-down/key-up macros. Commands and skin IDs are never supplied by players.
/proc/action_keybinding_catalog()
	var/static/list/catalog = list(
		"prone" = list("Prone / stand", "m-intent-prone", list(), list(",")),
		"aim" = list("Toggle aiming mode", "toggle-gun-mode", list(), list("J", "CTRL+J")),
		"sights" = list("Use sights / drone / tank gun", "on-press-spacebar", list("Space"), list("Space")),
		"run" = list("Toggle running", "m-intent-run", list(), list("M")),
		"movement" = list("Cycle movement mode", "m-intent-change", list(), list(".")),
		"defense" = list("Cycle defense intent", "defense-intent-change", list(), list("V")),
		"secondary" = list("Cycle secondary intent", "secondary-intent-change", list(), list("U")),
		"tactics" = list("Cycle tactics", "tactic-intent", list(), list("N")),
		"face" = list("Face direction", "Face-Direction", list("F"), list("F")),
		"buckle" = list("Buckle / unbuckle", "try_to_buckle", list(), list("B")),
		"equip" = list("Quick equip", "quick-equip", list("CTRL+E"), list("E", "CTRL+E")),
		"holster" = list("Holster", "holster", list(), list("H", "CTRL+H")),
		"attack" = list("Attack in facing direction", "attack-direction", list(), list("L", "CTRL+L")))
	return catalog

/proc/action_keybinding_modes()
	return list("macro", "hotkeymode")

/proc/action_keybinding_defaults(mode, action)
	var/list/entry = action_keybinding_catalog()[action]
	if (!entry || !(mode in action_keybinding_modes()))
		return list()
	var/list/keys = entry[mode == "macro" ? 3 : 4]
	return keys.Copy()

/proc/action_keybinding_candidates(mode)
	var/list/keys = list()
	// Reserve whole key families used for movement or held activation. In
	// particular a modified binding must not shadow their release macros.
	var/list/bases = list("B", "C", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "P", "U", "V", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ",", ".", "Space")
	for (var/base in bases)
		for (var/modifier in list("", "CTRL+", "SHIFT+", "CTRL+SHIFT+"))
			if (mode == "macro" && modifier == "SHIFT+")
				continue
			// Typing mode gains no new unmodified text shortcuts. Existing F
			// and Space defaults are retained, including when restoring them.
			if (mode == "macro" && !length(modifier) && !(base in list("F", "Space")))
				continue
			keys += "[modifier][base]"
	return keys

/proc/action_keybinding_reserved(mode)
	// Fixed macros whose base is also an available action key. The offline
	// skin audit fails if this set drifts. All other fixed key families are
	// excluded by action_keybinding_candidates().
	var/list/keys = list("CTRL+C", "CTRL+F", "CTRL+G", "CTRL+SHIFT+G", "CTRL+1", "CTRL+2", "CTRL+3", "CTRL+4", "5", "6", "7", "8", "9")
	if (mode == "hotkeymode")
		keys += list("C", "G", "1", "2", "3", "4")
	return keys

/datum/preferences
	// Flat, delimiter-safe records fit the existing account preferences format.
	// Missing records mean defaults; NONE explicitly unbinds a mode/action.
	var/list/action_keybindings = list()

/datum/preferences/proc/action_keybinding_map(list/records)
	var/list/bindings = list()
	for (var/mode in action_keybinding_modes())
		for (var/action in action_keybinding_catalog())
			bindings["[mode]/[action]"] = action_keybinding_defaults(mode, action)
	if (!islist(records) || records.len > bindings.len)
		return null
	var/list/seen = list()
	for (var/record in records)
		if (!istext(record) || length(record) > 100)
			return null
		var/list/parts = splittext(record, "/")
		if (parts.len != 3)
			return null
		var/mode = parts[1]
		var/action = parts[2]
		var/key = parts[3]
		var/slot = "[mode]/[action]"
		if (!(slot in bindings) || (slot in seen))
			return null
		seen += slot
		if (key != "NONE" && !(key in action_keybinding_candidates(mode)))
			return null
		bindings[slot] = key == "NONE" ? list() : list(key)
	for (var/mode in action_keybinding_modes())
		var/list/used = action_keybinding_reserved(mode)
		for (var/action in action_keybinding_catalog())
			for (var/key in bindings["[mode]/[action]"])
				if (key in used)
					return null
				used += key
	return bindings

/datum/preferences/proc/sanitize_action_keybindings()
	if (!action_keybinding_map(action_keybindings))
		action_keybindings = list()

/datum/preferences/proc/set_action_keybinding(mode, action, key)
	if (!(mode in action_keybinding_modes()) || !(action in action_keybinding_catalog()))
		return FALSE
	sanitize_action_keybindings()
	var/list/updated = action_keybindings.Copy()
	var/prefix = "[mode]/[action]/"
	for (var/record in action_keybindings)
		if (findtext(record, prefix) == 1)
			updated -= record
	// null restores defaults; NONE is an explicit unbind.
	if (!isnull(key))
		updated += "[prefix][key]"
	if (!action_keybinding_map(updated))
		return FALSE
	action_keybindings = updated
	return TRUE

/client/proc/apply_action_keybindings()
	if (!prefs)
		return
	prefs.sanitize_action_keybindings()
	var/list/bindings = prefs.action_keybinding_map(prefs.action_keybindings)
	// Disable every managed slot before assigning keys, so swaps never leave
	// duplicate active names. Never replace the macro set or change UI focus.
	for (var/mode in action_keybinding_modes())
		for (var/action in action_keybinding_catalog())
			for (var/i = 1, i <= 2, i++)
				winset(src, "[mode].action_[action]_[i]", list("name" = "", "is-disabled" = "true"))
	for (var/mode in action_keybinding_modes())
		for (var/action in action_keybinding_catalog())
			var/list/keys = bindings["[mode]/[action]"]
			for (var/i = 1, i <= keys.len, i++)
				winset(src, "[mode].action_[action]_[i]", list("name" = keys[i], "is-disabled" = "false"))

/client/verb/configure_action_keybindings()
	set name = "Keybindings"
	set category = "OOC"
	set desc = "Change and save action keys for typing and hotkey modes."
	var/datum/preferences/owner = prefs
	if (!owner)
		return
	while (src && prefs == owner)
		owner.sanitize_action_keybindings()
		var/mode_choice = input(src, "Choose the mode to edit. Changes save immediately. Movement, chat, menu and held activation keys are reserved.", "Keybindings") as null|anything in list("Hotkey mode", "Typing mode", "Restore all defaults")
		if (!src || prefs != owner || !mode_choice)
			return
		if (mode_choice == "Restore all defaults")
			if (alert(src, "Restore all action keys in both modes?", "Keybindings", "Restore", "Cancel") == "Restore" && src && prefs == owner)
				owner.action_keybindings = list()
				apply_action_keybindings()
				owner.save_preferences()
			continue
		var/mode = mode_choice == "Hotkey mode" ? "hotkeymode" : "macro"
		var/list/bindings = owner.action_keybinding_map(owner.action_keybindings)
		var/list/choices = list()
		for (var/action in action_keybinding_catalog())
			var/list/entry = action_keybinding_catalog()[action]
			var/list/keys = bindings["[mode]/[action]"]
			choices["[entry[1]] ([keys.len ? jointext(keys, ", ") : "Unbound"])"] = action
		var/choice = input(src, "Choose an action. Current keys are shown in parentheses.", "Keybindings: [mode_choice]") as null|anything in choices
		if (!src || prefs != owner || !choice)
			continue
		var/action = choices[choice]
		var/operation = input(src, "Changing a key replaces this action's aliases in this mode. Unbind another action first to free its key.", "[choice]") as null|anything in list("Change key", "Unbind", "Restore defaults")
		if (!src || prefs != owner || !operation)
			continue
		var/key = null
		if (operation == "Change key")
			var/list/available = action_keybinding_candidates(mode)
			available -= action_keybinding_reserved(mode)
			for (var/other in action_keybinding_catalog())
				if (other != action)
					available -= bindings["[mode]/[other]"]
			key = input(src, "Choose a key. Reserved keys and keys assigned to another action are omitted.", "[choice]") as null|anything in available
			if (!key)
				continue
		else if (operation == "Unbind")
			key = "NONE"
		if (!src || prefs != owner)
			return
		// Revalidate after all yielding prompts, including concurrent edits.
		if (!owner.set_action_keybinding(mode, action, key))
			to_chat(src, SPAN_WARNING("That key conflicts with another action. Unbind it first, or restore all defaults."))
			continue
		apply_action_keybindings()
		owner.save_preferences()
		to_chat(src, SPAN_NOTICE("Action keybindings saved. Use OOC > Keybindings to view or change them."))
