/datum/category_item/player_setup_item/general/loadout
	name = "Loadout"
	sort_order = 4
	var/list/loadout_items = list("Water", "Grenade", "Smoke grenade", "Flare", "Knife", "Cigarettes", "Lighter", "Crowbar", "Wrench", "Screwdriver", "Magazine")

/datum/category_item/player_setup_item/general/loadout/content()
	//name
	. = "<b>Pockets:</b> "
	. += "<br><br>"

	// although very rare, this may return FALSE. This check is needed to prevent runtimes
	if (pref.pockets.len == 2)
		. += "<b>1:</b> <a href='?src=\ref[src];pocket_1=1'>[pref.pockets[1]]</a><br>"
		. += "<b>2:</b> <a href='?src=\ref[src];pocket_2=2'>[pref.pockets[2]]</a><br>"

/datum/category_item/player_setup_item/general/loadout/OnTopic(var/href,var/list/href_list, var/mob/user)

	// neat stuff
	if (href_list["pocket_1"] || href_list["pocket_2"])
		var/one = href_list["pocket_1"]
		var/two = !one
		var/number = one ? "first" : "second"
		var/object = input(user, "Choose an object to start with in your [number] pocket. Note that this will stop you from spawning with an ammo magazine there.", "Custom Loadout") in loadout_items
		if (!isnull(object) && CanUseTopic(user))
			if (one)
				pref.pockets[1] = object
			else if (two)
				pref.pockets[2] = object
			return TOPIC_REFRESH
	return ..()
