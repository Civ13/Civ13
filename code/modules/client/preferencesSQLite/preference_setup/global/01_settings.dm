/datum/category_item/player_setup_item/player_global/settings
	name = "Settings"
	sort_order = 2

/datum/category_item/player_setup_item/player_global/settings/sanitize_preferences()
	// Ensure our preferences are lists.
	if (!istype(pref.preferences_enabled, /list))
		pref.preferences_enabled = list()
	if (!istype(pref.preferences_disabled, /list))
		pref.preferences_disabled = list()
	pref.client_fps = sanitize_client_fps(pref.client_fps)

	// Arrange preferences that have never been enabled/disabled.
	var/list/client_preference_keys = list()
	for (var/cp in get_client_preferences())
		var/datum/client_preference/client_pref = cp
		client_preference_keys += client_pref.key
		if ((client_pref.key in pref.preferences_enabled) || (client_pref.key in pref.preferences_disabled))
			continue

		if (client_pref.enabled_by_default)
			pref.preferences_enabled += client_pref.key
		else
			pref.preferences_disabled += client_pref.key

	// Clean out preferences that no longer exist.
	for (var/key in pref.preferences_enabled)
		if (!(key in client_preference_keys))
			pref.preferences_enabled -= key
	for (var/key in pref.preferences_disabled)
		if (!(key in client_preference_keys))
			pref.preferences_disabled -= key

//	pref.lastchangelog	= sanitize_text(pref.lastchangelog, initial(pref.lastchangelog))
//	pref.default_slot	= sanitize_integer(pref.default_slot, TRUE, config.character_slots, initial(pref.default_slot))
