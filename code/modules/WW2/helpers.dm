/proc/radio2faction(msg, faction = GERMAN, var/channel = "High Command Announcements")
	switch (faction)
		if (GERMAN)
			return radio2germans(msg, channel)
		if (SOVIET)
			return radio2soviets(msg, channel)

/proc/radio2germans(msg, var/channel = "High Command Announcements")
	var/obj/item/radio/R = main_radios[GERMAN]
	if (R && R.loc)
		processes.callproc.queue(R, /obj/item/radio/proc/announce, list(msg, channel), 3)
		return TRUE
	return FALSE

/proc/radio2SS(msg)
	var/obj/item/radio/R = main_radios[GERMAN]
	if (R && R.loc)
		processes.callproc.queue(R, /obj/item/radio/proc/announce, list(msg, "SS Announcements"), 3)
		return TRUE
	return FALSE

/proc/radio2soviets(msg, var/channel = "High Command Announcements")
	var/obj/item/radio/R = main_radios[SOVIET]
	if (R && R.loc)
		processes.callproc.queue(R, /obj/item/radio/proc/announce, list(msg, channel), 3)
		return TRUE
	return FALSE

/proc/battlereport2faction(faction)
	switch (faction)
		if (GERMAN)
			radio2germans("Battle Status Report: [alive_germans.len] alive, [heavily_injured_germans.len] heavily injured or unconscious, [dead_germans.len] dead.<br>[alive_russians.len] enemies alive, [heavily_injured_russians.len] enemies heavily injured or unconscious, [dead_russians.len] enemies dead.")

		if (SOVIET)
			radio2soviets("Battle Status Report: [alive_russians.len] alive, [heavily_injured_russians.len] heavily injured or unconscious, [dead_russians.len] dead.<br>[alive_germans.len] enemies alive, [heavily_injured_germans.len] enemies heavily injured or unconscious, [dead_germans.len] enemies dead.")
