/datum/preferences

/datum/category_item/player_setup_item/general/basic
	name = "Basic"
	sort_order = 1

/datum/category_item/player_setup_item/general/basic/sanitize_character()
	var/list/valid_player_genders = list(MALE, FEMALE)
	var/datum/species/S = all_species[pref.species ? pref.species : "Human"]
	pref.age			= sanitize_integer(pref.age, S.min_age, S.max_age, initial(pref.age))
	pref.gender 		= sanitize_inlist(pref.gender, valid_player_genders, pick(valid_player_genders))
	pref.real_name		= sanitize_name(pref.real_name, pref.species)

	if (!pref.real_name)
		pref.real_name	= random_name(pref.gender, pref.species)

/proc/check_trait_points(var/list/traitlist = list())
	if (!islist(traitlist) || !traitlist.len)
		return 0
	var/count = 0
	for (var/i in traitlist)
		if (istext(i) && trait_list[i] && trait_list[i][1]!=0)
			count += trait_list[i][1]
	return count
