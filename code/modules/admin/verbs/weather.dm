/client/proc/randomly_change_weather()
	set category = "Debug"
	set name = "Randomly Change the Weather"
	change_weather_somehow()
	src << "<span class = 'good'>Sucessfully changed the weather!</span>"
	message_admins("[key_name(src)] randomly changed the weather.", key_name(src))
	log_admin("[key_name(src)] randomly changed the weather.")

/client/proc/randomly_modify_weather()
	set category = "Debug"
	set name = "Randomly Modify the Weather"
	var/old_intensity = weather_intensity
	modify_weather_somehow()
	src << "<span class = 'good'>Sucessfully modified the weather from [old_intensity] to [weather_intensity]!</span>"
	message_admins("[key_name(src)] randomly modified the weather.", key_name(src))
	log_admin("[key_name(src)] randomly modified the weather.")

/client/proc/change_season()
	set category = "Debug"
	set name = "Change the Season"

	map.seasons(FALSE,TRUE)
	src << "<span class = 'good'>Sucessfully changed the season.</span>"
	message_admins("[key_name(src)] changed the season.", key_name(src))
	log_admin("[key_name(src)] changed the season.")

/client/proc/toggle_season()
	set category = "Debug"
	set name = "Toggle Season Change"

	if (config.seasons_on)
		config.seasons_on = FALSE
		src << "<span class = 'good'>Seasons are now <b>disabled.</span>"
		log_admin("[key_name(src)] disabled season change.")
		
	else
		config.seasons_on = TRUE
		src << "<span class = 'good'>Seasons are now <b>enabled.</span>"
		message_admins("[key_name(src)] enabled season change.", key_name(src))
	