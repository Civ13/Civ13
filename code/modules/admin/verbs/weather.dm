/client/proc/randomly_change_weather()
	set category = "Debug"
	set name = "Randomly Change the Weather"
	change_weather_somehow()
	src << "<span class = 'good'>Sucessfully changed the weather to [get_weather()]!</span>"
	message_admins("[key_name(src)] randomly changed the weather.")
	log_admin("[key_name(src)] randomly changed the weather.")

/client/proc/randomly_modify_weather()
	set category = "Debug"
	set name = "Randomly Modify the Weather"
	var/old_intensity = weather_intensity
	modify_weather_somehow()
	src << "<span class = 'good'>Sucessfully modified the weather from [old_intensity] to [weather_intensity]!</span>"
	message_admins("[key_name(src)] randomly modified the weather.")
	log_admin("[key_name(src)] randomly modified the weather.")