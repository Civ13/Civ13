/proc/radio2faction(msg, faction = GERMAN, var/channel = "High Command Announcements")
	switch (faction)
		if (GERMAN)
			return radio2germans(msg, channel)
		if (SOVIET)
			return radio2soviets(msg, channel)
		if (SCHUTZSTAFFEL)
			return radio2SS(msg, channel)

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

		if (USA)
			radio2soviets("Battle Status Report: [alive_usa.len] alive, [heavily_injured_usa.len] heavily injured or unconscious, [dead_usa.len] dead.<br>[alive_japan.len] enemies alive, [heavily_injured_japan.len] enemies heavily injured or unconscious, [dead_japan.len] enemies dead.")

		if (JAPAN)
			radio2germans("Battle Status Report: [alive_japan.len] alive, [heavily_injured_japan.len] heavily injured or unconscious, [dead_japan.len] dead.<br>[alive_usa.len] enemies alive, [heavily_injured_usa.len] enemies heavily injured or unconscious, [dead_usa.len] enemies dead.")

		if (SCHUTZSTAFFEL)
			return battlereport2faction(GERMAN)