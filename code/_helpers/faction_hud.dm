// Faction HUD icons in one place: which icon a player's faction shows above them.
//
// A player's icon is chosen once, when they first get a job:
// 1. A few job rules come first (nomads show none, UPA fighters show the UPA icon).
// 2. The map decides next. A map lists icons by faction in `faction_hud_icons`
//    (for example list(RUSSIAN = "robbers")), or overrides faction_hud_icon()
//    when the icon depends on the job or nationality. null means "no say".
// 3. Otherwise default_faction_hud_icon() picks the faction's icon for the era.
// Maps add extra marks (roles, ranks) with add_faction_hud_overlays().
//
// So a new map changes its faction icons in its own file, not in Life code.

/obj/map_metadata
	var/list/faction_hud_icons = null

// The icon state this map gives the faction, or null to use the default.
/obj/map_metadata/proc/faction_hud_icon(mob/living/human/H, faction_flag)
	if (faction_hud_icons && (faction_flag in faction_hud_icons))
		return faction_hud_icons[faction_flag]
	return null

// Add this map's extra marks to a player's faction icon.
/obj/map_metadata/proc/add_faction_hud_overlays(mob/living/human/H, image/holder)
	return

// The faction icon state for H, or null to leave the icon as it is.
/proc/faction_hud_icon_state(mob/living/human/H)
	var/datum/job/J = H.original_job
	if (!J)
		return null
	var/faction_flag = J.base_type_flag()
	if (faction_flag == CIVILIAN)
		if (H.original_job_title == "Nomad")
			return ""
		if (J.is_upa && map.ID != MAP_OCCUPATION)
			return "upa_basic"
	var/state = map ? map.faction_hud_icon(H, faction_flag) : null
	if (!isnull(state))
		return state
	return default_faction_hud_icon(H, faction_flag)

// The faction's own icon for the map's era.
/proc/default_faction_hud_icon(mob/living/human/H, faction_flag)
	var/datum/job/J = H.original_job
	var/age = map.ordinal_age
	switch (faction_flag)
		if (PIRATES)
			if (!map.battleroyale)
				return "pirate_basic"
		if (BRITISH)
			if (age >= 4)
				return "brit_basic"
			if (age >= 3)
				return "rn_basic"
			return "eng_basic"
		if (FRENCH)
			return age >= 4 ? "fr2_basic" : "fr_basic"
		if (SPANISH)
			return age <= 3 ? "sp_basic" : "spn_basic"
		if (PORTUGUESE)
			return age <= 4 ? "pt_basic" : "pt2_basic"
		if (INDIANS)
			return "ind_basic"
		if (DUTCH)
			return age >= 6 ? "nl_basic" : "nl_old_basic"
		if (ITALIAN)
			return "it_basic"
		if (ARAB)
			return age >= 6 ? "isis_basic" : "arab_basic"
		if (GREEK)
			return "greek_basic"
		if (ROMAN)
			return "roman_basic"
		if (CHECHEN)
			return "chechen_basic"
		if (FINNISH)
			return "finnish_basic"
		if (NORWEGIAN)
			return "norway_basic"
		if (SWEDISH)
			return "swedish_basic"
		if (DANISH)
			return "danish_basic"
		if (JAPANESE)
			if (J.is_yakuza && J.is_yama)
				return "yamaguchi"
			if (J.is_yakuza && J.is_ichi)
				return "ichiwa"
			if (J.is_samurai && J.is_eastern)
				return "eastern"
			if (J.is_samurai && J.is_western)
				return "western"
			return "jp_basic"
		if (RUSSIAN)
			return age <= 5 ? "ru_basic" : "sov_basic"
		if (GERMAN)
			if (age <= 1)
				return "ger0_basic"
			if (age <= 5)
				return "ger_basic"
			if (age == 6)
				return "ger2_basic"
			return "ger3_basic"
		if (AMERICAN)
			return "us_basic"
		if (VIETNAMESE)
			return J.is_nva ? "vn_basic" : "vc_basic"
		if (FILIPINO)
			return "fp_basic"
		if (CHINESE)
			return age >= 7 ? "sov_basic" : "roc_basic"
		if (POLISH)
			return "pol_basic"
		if (CIVILIAN)
			switch (H.original_job_title)
				if ("Civilization A Citizen")
					return "civ1"
				if ("Civilization B Citizen")
					return "civ2"
				if ("Civilization C Citizen")
					return "civ3"
				if ("Civilization D Citizen")
					return "civ4"
				if ("Civilization E Citizen")
					return "civ5"
				if ("Civilization F Citizen")
					return "civ6"
			return ""
		if (BLUEFACTION)
			return "blugoslavia"
		if (REDFACTION)
			return "redmenia"
		if (CAFR)
			return "civ1"
		if (TSFSR)
			return "sov_basic"
	return null
