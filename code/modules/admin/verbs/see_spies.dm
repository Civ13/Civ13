/client/proc/see_spies()
	set name = "See Spies"
	set category = "WW2 (Admin)"

	if(!check_rights(R_MOD))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return
	if (!istype(ticker.mode, /datum/game_mode/ww2))
		src << "<span class = 'danger'>What spies?</span>"
		return

	print_spies(src, TRUE)

/proc/print_spies(whomst, var/notroundend = FALSE)

	var/list/spies = list()
	for (var/mob/living/carbon/human/H in mob_list)
		if (istype(H) && H.is_spy)
			spies += H

	if (!spies.len && !notroundend)
		return

	if (notroundend)
		whomst << "<big>Spies:</big><br><br>"
	else
		whomst << "<big>Spies at the end of the round:</big><br><br>"

	var/list/mobs = dead_mob_list
	mobs |= living_mob_list

	for (var/mob/living/carbon/human/H in mobs)
		if (istype(H) && H.is_spy)
			var/H_stat = (H.stat == DEAD ? "DEAD" : H.stat == UNCONSCIOUS ? "UNCONSCIOUS" : "ALIVE")
			var/is_ghosted = (H.client ? "IN BODY" : "GHOSTED OR LOGGED OUT")
			var/spanstyle = H.stat == DEAD ? "warning" : "notice"
			if (istype(H.original_job, /datum/job/german))
				whomst << "<span class = '[spanstyle]'>[H.real_name][notroundend ? "/" : ""][notroundend ? H.ckey : ""] - German soldier spying for the Soviets. ([H_stat]) ([is_ghosted])</span><br>"
			else if (istype(H.original_job, /datum/job/soviet))
				whomst << "<span class = '[spanstyle]'>[H.real_name][notroundend ? "/" : ""][notroundend ? H.ckey : ""] - Russian soldier spying for the Germans. ([H_stat]) ([is_ghosted])</span><br>"
			if (!notroundend && H.stat != DEAD && !H.restrained())
				whomst << "<span class = 'notice'>The Spy survived!</span><br>"