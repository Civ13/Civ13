/proc/get_alive_list_for_faction(faction)
	switch (faction)
		if (BRITISH) return alive_british
		if (PIRATES) return alive_pirates
		if (CIVILIAN) return alive_civilians
		if (FRENCH) return alive_french
		if (SPANISH) return alive_spanish
		if (PORTUGUESE) return alive_portuguese
		if (INDIANS) return alive_indians
		if (DUTCH) return alive_dutch
		if (GREEK) return alive_greek
		if (ROMAN) return alive_roman
		if (ARAB) return alive_arab
		if (JAPANESE) return alive_japanese
		if (RUSSIAN) return alive_russian
		if (CHECHEN) return alive_chechen
		if (FINNISH) return alive_finnish
		if (NORWEGIAN) return alive_norwegian
		if (SWEDISH) return alive_swedish
		if (DANISH) return alive_danish
		if (GERMAN) return alive_german
		if (AMERICAN) return alive_american
		if (VIETNAMESE) return alive_vietnamese
		if (CHINESE) return alive_chinese
		if (FILIPINO) return alive_filipino
		if (POLISH) return alive_polish
		if (ITALIAN) return alive_italian
		if (BLUEFACTION) return alive_bluefaction
		if (REDFACTION) return alive_redfaction
		if (CAFR) return alive_cafr
		if (TSFSR) return alive_tsfsr
	return null

/proc/get_faction_autobalance_name(faction)
	switch (faction)
		if (BRITISH)
			if (map && istype(map, /obj/map_metadata/twotribes))
				return "Red Tribesmen"
			return "British"
		if (PORTUGUESE)
			return "Portuguese"
		if (FRENCH)
			if (map && istype(map, /obj/map_metadata/twotribes))
				return "Blue Tribesmen"
			return "French"
		if (SPANISH)
			return "Spanish"
		if (DUTCH)
			return "Dutch"
		if (ITALIAN)
			return "Italian"
		if (PIRATES)
			return "Pirates"
		if (INDIANS)
			if (map && istype(map, /obj/map_metadata/african_warlords))
				return "Blugisi"
			if (map && istype(map, /obj/map_metadata/tadojsville))
				return "Wartribe Mercenary"
			if (map && istype(map, /obj/map_metadata/east_los_santos))
				return "Ballas"
			return "Natives"
		if (CIVILIAN)
			if (map && istype(map, /obj/map_metadata/tsaritsyn))
				return "Soviets"
			if (map && istype(map, /obj/map_metadata/african_warlords))
				return "Yellowagwana"
			if (map && istype(map, /obj/map_metadata/tadojsville))
				return "UN Peacekeepers"
			if (map && istype(map, /obj/map_metadata/capitol_hill))
				return "Rioters"
			if (map && istype(map, /obj/map_metadata/yeltsin))
				return "Soviet Remnants"
			if (map && istype(map, /obj/map_metadata/missionary_ridge))
				return "Confederates"
			if (map && istype(map, /obj/map_metadata/tantiveiv))
				return "Rebels"
			if (map && istype(map, /obj/map_metadata/ruhr_uprising))
				return "Revolutionaries"
			if (map && istype(map, /obj/map_metadata/bank_robbery))
				return "Policemen"
			if (map && istype(map, /obj/map_metadata/drug_bust))
				return "Policemen and Federal Agents"
			if (map && istype(map, /obj/map_metadata/long_march))
				return "Chinese Red Army"
			if (map && istype(map, /obj/map_metadata/holdmadrid))
				return "Republican"
			return "Civilians"
		if (GREEK)
			return "Greeks"
		if (ROMAN)
			return "Romans"
		if (ARAB)
			if (map && (istype(map, /obj/map_metadata/kandahar) || istype(map, /obj/map_metadata/hill_3234) || istype(map, /obj/map_metadata/magistral)))
				return "Mujahideen"
			if (map && istype(map, /obj/map_metadata/syria))
				return "Syrian Government Soldiers"
			return "Arabs"
		if (JAPANESE)
			return "Japanese"
		if (RUSSIAN)
			if (map && istype(map, /obj/map_metadata/yeltsin))
				return "Russian Army"
			if (map && istype(map, /obj/map_metadata/bank_robbery))
				return "Robbers"
			if (map && istype(map, /obj/map_metadata/drug_bust))
				return "Rednikov Mobsters"
			if (map && istype(map, /obj/map_metadata/eft_factory))
				return "BEAR PMCs"
			if (map && (map.ordinal_age == 6 || map.ordinal_age == 7))
				return "Soviets"
			return "Russians"
		if (CHECHEN)
			return "Chechens"
		if (FINNISH)
			return "Finnish"
		if (NORWEGIAN)
			if (map && istype(map, /obj/map_metadata/clash))
				return "Bear Clan Vikings"
			return "Norwegians"
		if (SWEDISH)
			return "Swedes"
		if (DANISH)
			if (map && istype(map, /obj/map_metadata/clash))
				return "Raven Clan Vikings"
			return "Danes"
		if (GERMAN)
			if (map && istype(map, /obj/map_metadata/ruhr_uprising))
				return "Reactionaries"
			return "German"
		if (AMERICAN)
			if (map && istype(map, /obj/map_metadata/arab_town))
				return "Israeli"
			if (map && istype(map, /obj/map_metadata/capitol_hill))
				return "American Government"
			if (map && istype(map, /obj/map_metadata/missionary_ridge))
				return "Union Soldiers"
			if (map && istype(map, /obj/map_metadata/tantiveiv))
				return "Imperials"
			if (map && istype(map, /obj/map_metadata/east_los_santos))
				return "Grove Street"
			if (map && istype(map, /obj/map_metadata/eft_factory))
				return "USEC PMCs"
			if (map && istype(map, /obj/map_metadata/syria))
				return "Syrian Rebels"
			return "American"
		if (VIETNAMESE)
			return "Vietnamese"
		if (CHINESE)
			if (map && istype(map, /obj/map_metadata/long_march))
				return "Chinese National Army"
			return "Chinese"
		if (FILIPINO)
			return "Filipino"
		if (POLISH)
			return "Poles"
		if (BLUEFACTION)
			return "Blugoslavians"
		if (REDFACTION)
			return "Redmenians"
		if (CAFR)
			return "CAFR soldiers"
		if (TSFSR)
			if (map && istype(map, /obj/map_metadata/campaign_new))
				return "Turkestan SFSR soldiers"
			return "TSFSR soldiers"
	return faction

/proc/get_faction_custom_name(faction)
	var/temp_name = capitalize(lowertext(faction))
	if (!map)
		return temp_name

	switch (map.ID)
		if (MAP_ARAB_TOWN)
			if (faction == AMERICAN) return "Israeli"
		if (MAP_AFRICAN_WARLORDS)
			if (faction == INDIANS) return "Blugisi"
			if (faction == CIVILIAN) return "Yellowagwana"
		if (MAP_TADOJSVILLE)
			if (faction == INDIANS) return "Mercenary Warband"
			if (faction == CIVILIAN) return "United Nations Peacekeepers"
		if (MAP_MISSIONARY_RIDGE)
			if (faction == AMERICAN) return "Union"
			if (faction == CIVILIAN) return "Confederate"
		if (MAP_WHITERUN)
			if (faction == ROMAN) return "Imperials"
			if (faction == CIVILIAN) return "Stormcloaks"
		if (MAP_SYRIA)
			if (faction == AMERICAN) return "Free Syrian Army"
			if (faction == ARAB) return "Syrian Arab Republic"
		if (MAP_CAPITOL_HILL)
			if (faction == AMERICAN) return "American Government"
			if (faction == CIVILIAN) return "Rioters"
		if (MAP_YELTSIN)
			if (faction == RUSSIAN) return "Russian Army"
			if (faction == CIVILIAN) return "Soviet Militia"
		if (MAP_KANDAHAR, MAP_HILL_3234, MAP_MAGISTRAL)
			if (faction == RUSSIAN) return "Soviet Army"
			if (faction == ARAB) return "Mujahideen"
			if (faction == CIVILIAN) return "DRA and Civilians"
		if (MAP_RED_MENACE)
			if (faction == RUSSIAN) return "Soviets"
		if (MAP_TANTIVEIV)
			if (faction == CIVILIAN) return "Rebels"
			if (faction == AMERICAN) return "Imperials"
		if (MAP_RUHR_UPRISING)
			if (faction == GERMAN) return "Reactionaries"
			if (faction == CIVILIAN) return "Revolutionaries"
		if (MAP_BANK_ROBBERY)
			if (faction == CIVILIAN) return "Police Department"
			if (faction == RUSSIAN) return "Robbers"
		if (MAP_DRUG_BUST)
			if (faction == CIVILIAN) return "Police and Federal Agents"
			if (faction == RUSSIAN) return "Rednikov Mobsters"
		if (MAP_CLASH)
			if (faction == NORWEGIAN) return "Bear Clan"
			if (faction == DANISH) return "Raven Clan"
		if (MAP_EAST_LOS_SANTOS)
			if (faction == INDIANS) return "Ballas"
			if (faction == AMERICAN) return "Grove Street Families"
		if (MAP_LONG_MARCH)
			if (faction == CIVILIAN) return "Chinese Red Army"
			if (faction == CHINESE) return "Chinese National Army"
		if (MAP_ROTSTADT)
			if (faction == REDFACTION) return "Rotstadt People's Republic"
			if (faction == BLUEFACTION) return "Blugoslavian Armed Forces"
		if (MAP_HOLDMADRID)
			if (faction == CIVILIAN) return "Republican"
			if (faction == SPANISH) return "Spanish"

	return temp_name

/proc/is_faction_toggled_off(faction)
	switch (faction)
		if (CIVILIAN) return !civilians_toggled
		if (BRITISH) return !british_toggled
		if (PIRATES) return !pirates_toggled
		if (PORTUGUESE) return !portuguese_toggled
		if (FRENCH) return !french_toggled
		if (SPANISH) return !spanish_toggled
		if (DUTCH) return !dutch_toggled
		if (INDIANS) return !indians_toggled
		if (ROMAN) return !roman_toggled
		if (GREEK) return !greek_toggled
		if (ARAB) return !arab_toggled
		if (JAPANESE) return !japanese_toggled
		if (RUSSIAN) return !russian_toggled
		if (CHECHEN) return !chechen_toggled
		if (FINNISH) return !finnish_toggled
		if (NORWEGIAN) return !norwegian_toggled
		if (SWEDISH) return !swedish_toggled
		if (DANISH) return !danish_toggled
		if (GERMAN) return !german_toggled
		if (AMERICAN) return !american_toggled
		if (VIETNAMESE) return !vietnamese_toggled
		if (CHINESE) return !chinese_toggled
		if (FILIPINO) return !filipino_toggled
		if (POLISH) return !polish_toggled
		if (ITALIAN) return !italian_toggled
		if (BLUEFACTION) return !bluefaction_toggled
		if (REDFACTION) return !redfaction_toggled
		if (CAFR) return !cafr_toggled
		if (TSFSR) return !tsfsr_toggled
	return FALSE

/mob/new_player/proc/get_autobalance_status_html()
	var/list/parts = list()
	for (var/faction in map.faction_organization)
		var/list/alive_list = get_alive_list_for_faction(faction)
		if (alive_list)
			var/display_name = get_faction_autobalance_name(faction)
			parts += "[alive_list.len] [display_name]"
	return parts.Join(" ")

/mob/new_player/proc/show_latechoices_window(list/dat)
	var/data = ""
	for (var/line in dat)
		if (line != null)
			if (line != "<br>")
				data += "[line]"
			data += "<br>"

	data = {"
		<br>
		<html>
		<head>
		[common_browser_style]
		</head>
		<body>
		[data]
		</body>
		</html>
		<br>
	"}

	spawn (1)
		src << browse(data, "window=latechoices;size=600x640;can_close=1")
