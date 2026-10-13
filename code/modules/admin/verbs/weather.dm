/client/proc/randomly_change_weather()
	set category = "Debug"
	set name = "Randomly Change the Weather"
	change_weather_somehow()
	to_chat(src, "<span class = 'good'>Sucessfully changed the weather!</span>")
	message_admins("[key_name(src)] randomly changed the weather.", key_name(src))
	log_admin("[key_name(src)] randomly changed the weather.")

/client/proc/randomly_modify_weather()
	set category = "Debug"
	set name = "Randomly Modify the Weather"
	var/old_intensity = weather_intensity
	modify_weather_somehow()
	to_chat(src, "<span class = 'good'>Sucessfully modified the weather from [old_intensity] to [weather_intensity]!</span>")
	message_admins("[key_name(src)] randomly modified the weather.", key_name(src))
	log_admin("[key_name(src)] randomly modified the weather.")

/client/proc/change_season()
	set category = "Debug"
	set name = "Change the Season"

	if (!map)
		return
	var/decay_choice = alert(src, "Should this forced season change also advance abandoned debris decay by one season?", "Change the Season", "Keep decay age", "Advance decay age", "Cancel")
	if (!decay_choice || decay_choice == "Cancel")
		return
	var/advance_decay = decay_choice == "Advance decay age"
	map.seasons(FALSE, TRUE, advance_decay)
	var/decay_action = advance_decay ? "with debris aging enabled" : "without advancing debris age"
	to_chat(src, "<span class = 'good'>Requested a season change [decay_action].</span>")
	message_admins("[key_name(src)] requested a season change [decay_action].", key_name(src))
	log_admin("[key_name(src)] requested a season change [decay_action].")

/client/proc/toggle_season()
	set category = "Debug"
	set name = "Toggle Season Change"

	if (config.seasons_on)
		config.seasons_on = FALSE
		to_chat(src, "<span class = 'good'>Seasons are now <b>disabled.</span>")
		log_admin("[key_name(src)] disabled season change.")
		
	else
		config.seasons_on = TRUE
		to_chat(src, "<span class = 'good'>Seasons are now <b>enabled.</span>")
		message_admins("[key_name(src)] enabled season change.", key_name(src))
