/mob/verb/create_faction()
	set name = "Create Faction"
	set category = "IC"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.ID == MAP_NOMADS)
		if (U.civilization != "none")
			usr << "<span class='danger'>You are already in a faction. Abandon it first.</span>"
			return
		else
			var/choosename = russian_to_cp1251(input(src, "Choose a name for the faction:") as text|null)
			create_faction_pr(choosename)
			return
	else
		usr << "<span class='danger'>You cannot create a faction in this map.</span>"
		return

/mob/verb/create_faction()
	set name = "Create Faction"
	set category = "IC"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.ID == MAP_NOMADS)
		if (U.civilization != "none")
			usr << "<span class='danger'>You are already in a faction. Abandon it first.</span>"
			return
		else
			var/choosename = russian_to_cp1251(input(src, "Choose a name for the faction:") as text|null)
			create_faction_pr(choosename)
			return
	else
		usr << "<span class='danger'>You cannot create a faction in this map.</span>"
		return

/mob/proc/create_faction_pr(var/newname = "none")
	if (!ishuman(src))
		return
	var/mob/living/carbon/human/H = src
	for(var/i = 1, i <= map.custom_faction_nr.len, i++)
		if (map.custom_faction_nr[i] == newname)
			usr << "<span class='danger'>That faction already exists. Choose another name.</span>"
			return
	if (newname != null && newname != "none")
		H.civilization = newname
		map.custom_faction_nr += newname
		var/newnamev = list("[newname]" = list(0,0,0))
		map.custom_civs += newnamev
		usr << "<big>You are now the leader of the <b>[newname]</b> faction.</big>"
		return
	else
		return


/mob/verb/abandon_faction()
	set name = "Abandon Faction"
	set category = "IC"
	var/mob/living/carbon/human/U

	if (istype(src, /mob/living/carbon/human))
		U = src
	else
		return
	if (map.ID == MAP_NOMADS)
		if (U.civilization == "none")
			usr << "You are not part of any faction."
			return
		else
			U.civilization = "none"
			usr << "You left your faction. You are now a Nomad."
	else
		usr << "<span class='danger'>You cannot leave a faction in this map.</span>"
		return