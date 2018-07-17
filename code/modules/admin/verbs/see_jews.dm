/client/proc/see_jews()
	set name = "See Jews"
	set category = "WW2 (Admin)"

	if(!check_rights(R_MOD))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return
	if (!istype(ticker.mode, /datum/game_mode/ww2))
		src << "<span class = 'danger'>What (((jews)))?</span>"
		return

	print_jews(src, TRUE)

/proc/print_jews(whomst, var/notroundend = FALSE)

	var/list/jews = list()
	for (var/mob/living/carbon/human/H in mob_list)
		if (istype(H) && H.is_jew)
			jews += H

	if (!jews.len && !notroundend)
		return

	if (notroundend)
		whomst << "<big>Jews:</big><br><br>"
	else
		whomst << "<big>Jews at the end of the round:</big><br><br>"

	var/list/mobs = dead_mob_list
	mobs |= living_mob_list

	for (var/mob/living/carbon/human/H in mobs)
		if (istype(H) && H.is_jew)
			var/H_stat = (H.stat == DEAD ? "DEAD" : H.stat == UNCONSCIOUS ? "UNCONSCIOUS" : "ALIVE")
			var/is_ghosted = (H.client ? "IN BODY" : "GHOSTED OR LOGGED OUT")
			var/spanstyle = (H.stat == DEAD ? "warning" : "notice")
			if (istype(H.original_job, /datum/job/german))
				whomst << "<span class = '[spanstyle]'>[H.real_name][notroundend ? "/" : ""][notroundend ? H.ckey : ""] - German soldier jew. ([H_stat]) ([is_ghosted])</span><br>"
			else if (istype(H.original_job, /datum/job/soviet))
				whomst << "<span class = '[spanstyle]'>[H.real_name][notroundend ? "/" : ""][notroundend ? H.ckey : ""] - Soviet soldier jew. ([H_stat]) ([is_ghosted])</span><br>"
			if (!notroundend && H.stat == CONSCIOUS && !H.restrained())
				whomst << "<span class = 'notice'>The Jew survived!</span><br>"