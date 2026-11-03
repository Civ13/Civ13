// Farmer's almanac: a farming-skill book that reads the local climate.
// Crop advice is derived at runtime from the seed types' biome and season
// lists, using the same climate rule as crop growth in farming.dm. The
// seasonal weather table mirrors apply_area_weather() and get_temp() in
// code/modules/1713/weather.dm; tests/farmers_almanac checks it stays aligned.

// climate = list(season = list(base temperature, wet-weather icon, storm icon))
var/global/list/farmers_almanac_climates = list(
	"tundra" = list(
		"WINTER" = list(-60, "snow2", "snow_storm"),
		"SPRING" = list(-35, "snow2", "snow_storm"),
		"SUMMER" = list(-25, "snow2", "snow1"),
		"FALL" = list(-50, "snow2", "snow_storm"),
		"Wet Season" = list(30, "snow2", "snow_storm"),
		"Dry Season" = list(45, "snow2", "snow1")),
	"taiga" = list(
		"WINTER" = list(-53, "snow2", "snow_storm"),
		"SPRING" = list(-15, "", "snow1"),
		"SUMMER" = list(-10, "", "snow1"),
		"FALL" = list(-35, "snow2", "snow_storm"),
		"Wet Season" = list(30, "snow2", "snow_storm"),
		"Dry Season" = list(45, "", "snow1")),
	"temperate" = list(
		"WINTER" = list(-29, "snow2", "snow_storm"),
		"SPRING" = list(10, "rain2", "rain2"),
		"SUMMER" = list(30, "", ""),
		"FALL" = list(7, "rain2", "rain2"),
		"Wet Season" = list(30, "snow2", "snow_storm"),
		"Dry Season" = list(45, "rain2", "rain2")),
	"sea" = list(
		"WINTER" = list(-11, "rain1", "monsoon"),
		"SPRING" = list(14, "rain2", "rain2"),
		"SUMMER" = list(23, "rain2", "rain2"),
		"FALL" = list(11, "rain1", "monsoon"),
		"Wet Season" = list(30, "rain1", "monsoon"),
		"Dry Season" = list(45, "rain2", "rain2")),
	"semiarid" = list(
		"WINTER" = list(0, "rain1", "rain3"),
		"SPRING" = list(28, "rain1", ""),
		"SUMMER" = list(35, "rain1", ""),
		"FALL" = list(12, "rain1", "rain3"),
		"Wet Season" = list(30, "rain1", "rain3"),
		"Dry Season" = list(45, "rain1", "")),
	"desert" = list(
		"WINTER" = list(32, "rain1", ""),
		"SPRING" = list(40, "rain1", ""),
		"SUMMER" = list(50, "", "sandstorm"),
		"FALL" = list(34, "", "sandstorm"),
		"Wet Season" = list(30, "rain1", ""),
		"Dry Season" = list(45, "", "sandstorm")),
	"savanna" = list(
		"WINTER" = list(27, "rain2", "rain3"),
		"SPRING" = list(29, "rain2", "rain3"),
		"SUMMER" = list(35, "", ""),
		"FALL" = list(29, "", ""),
		"Wet Season" = list(30, "rain2", "rain3"),
		"Dry Season" = list(45, "", "")),
	"jungle" = list(
		"WINTER" = list(30, "rain3", "monsoon"),
		"SPRING" = list(34, "rain3", "monsoon"),
		"SUMMER" = list(40, "", ""),
		"FALL" = list(32, "", ""),
		"Wet Season" = list(30, "rain3", "monsoon"),
		"Dry Season" = list(45, "", "")))

// Seed prototypes as list(name, biomes, seasons, plant path); built once.
var/global/list/farmers_almanac_seed_cache = null

/proc/farmers_almanac_seeds()
	if (farmers_almanac_seed_cache)
		return farmers_almanac_seed_cache
	var/list/entries = list()
	for (var/seed_type in typesof(/obj/item/stack/farming/seeds) - /obj/item/stack/farming/seeds - /obj/item/stack/farming/seeds/herbs)
		var/obj/item/stack/farming/seeds/S = new seed_type
		var/plant_path = text2path("/obj/structure/farming/plant/[S.plant]")
		// Skip seeds whose crop no longer exists, so the book never advises them.
		if (ispath(plant_path, /obj/structure/farming/plant) && S.biomes && S.biomes.len)
			entries += list(list(S.name, S.biomes.Copy(), S.seasons.Copy(), plant_path))
		qdel(S)
	farmers_almanac_seed_cache = entries
	return entries

// Mirrors the map list in /obj/structure/farming/plant/growth(): elsewhere
// crops ignore climate and season entirely.
/proc/farmers_almanac_climate_matters()
	return map && (map.ID in list(MAP_NOMADS_CONTINENTAL, MAP_NOMADS_PANGEA, MAP_NOMADS_NEW_WORLD, MAP_NOMADS_MEDITERRANEAN, MAP_NOMADS_EUROPE, MAP_NOMADS_GAIA))

// Same eligibility as crop growth: the climate must suit the crop, and the
// season must too unless the climate is tropical. Saplings always need both.
/proc/farmers_almanac_grows(list/entry, climate, season_name, inside)
	var/plant_path = entry[4]
	if (inside && (ispath(plant_path, /obj/structure/farming/plant/mushroom) || ispath(plant_path, /obj/structure/farming/plant/mushroompsy)))
		return TRUE
	var/list/biomes = entry[2]
	var/list/seasons = entry[3]
	if (!(climate in biomes))
		return FALSE
	if (!ispath(plant_path, /obj/structure/farming/plant/tree) && (climate in list("jungle", "desert", "savanna")))
		return TRUE
	return (season_name in seasons)

/proc/farmers_almanac_weather_phrase(icon)
	switch (icon)
		if ("snow1") return "light snow"
		if ("snow2") return "snow"
		if ("snow_storm") return "blizzards"
		if ("rain1") return "light rain"
		if ("rain2") return "rain"
		if ("rain3") return "heavy rain"
		if ("monsoon") return "monsoons"
		if ("sandstorm") return "sandstorms"
	return "clear skies"

/proc/farmers_almanac_season_name(season_name)
	if (season_name in list("WINTER", "SPRING", "SUMMER", "FALL"))
		return capitalize(lowertext(season_name))
	return season_name

/proc/farmers_almanac_climate_name(climate)
	switch (climate)
		if ("sea") return "Coastal"
		if ("semiarid") return "Semi-arid"
	return capitalize(climate)

/obj/item/weapon/farmers_almanac
	name = "farmer's almanac"
	desc = "A well-thumbed book of planting tables and weather lore. Read it to learn what the local climate brings and which crops will thrive here."
	icon = 'icons/obj/library.dmi'
	icon_state = "book5"
	item_state = "bible"
	slot_flags = SLOT_BELT | SLOT_POCKET
	force = TRUE
	throwforce = TRUE
	w_class = ITEM_SIZE_SMALL
	throw_speed = 5
	throw_range = 10
	attack_verb = list("slapped", "whacked")
	flammable = TRUE
	flags = FALSE

/obj/item/weapon/farmers_almanac/attack_self(mob/user)
	var/turf/T = get_turf(user)
	var/area/A = T ? get_area(T) : null
	if (!A)
		to_chat(user, SPAN_WARNING("You can't make out where you are to consult \the [src]."))
		return
	user.visible_message("<span class='notice'>[user] leafs through [src].</span>", "<span class='notice'>You leaf through [src].</span>")
	user << browse(almanac_text(A, get_temp(user)), "window=farmers_almanac;size=520x640")

/obj/item/weapon/farmers_almanac/proc/almanac_text(area/A, local_temp)
	var/climate = A.climate
	var/inside = (A.location == AREA_INSIDE)
	var/list/four_seasons = list("SPRING", "SUMMER", "FALL", "WINTER")
	var/list/shown_seasons = (season in four_seasons) ? four_seasons : list("Wet Season", "Dry Season")
	var/list/table = farmers_almanac_climates[climate]

	var/dat = "<html><head><title>Farmer's Almanac</title></head><body>"
	dat += "<h2>Farmer's Almanac</h2>"
	dat += "<p>Region: <b>[table ? farmers_almanac_climate_name(climate) : "Unrecorded lands"]</b>[inside ? " (under a roof)" : ""]<br>"
	dat += "Season: <b>[farmers_almanac_season_name(season)]</b><br>"
	dat += "Sky: <b>[(!inside && A.icon_state) ? farmers_almanac_weather_phrase(replacetext(A.icon_state, "rad_", "")) : (inside ? "sheltered" : "clear skies")]</b><br>"
	dat += "Temperature here: <b>[local_temp]&deg;C</b></p>"

	dat += "<h3>Weather through the year</h3>"
	if (!table)
		dat += "<p>The almanac has no tables for this land.</p>"
	else
		dat += "<table border='1' cellpadding='3' cellspacing='0'><tr><th>Season</th><th>Typical temp.</th><th>Wet spells</th><th>Storms</th></tr>"
		for (var/season_name in shown_seasons)
			var/list/row = table[season_name]
			var/current = (season_name == season)
			dat += "<tr><td>[current ? "<b>" : ""][farmers_almanac_season_name(season_name)][current ? " (now)</b>" : ""]</td><td>[row[1]]&deg;C</td><td>[farmers_almanac_weather_phrase(row[2])]</td><td>[farmers_almanac_weather_phrase(row[3])]</td></tr>"
		dat += "</table>"
		dat += "<p><i>Rain and monsoons water open fields. Blizzards kill crops that are not winter-hardy, and sandstorms destroy crops. Under a roof, crops are sheltered from storms but must be watered by hand.</i></p>"

	dat += "<h3>Crops for this land</h3>"
	if (!farmers_almanac_climate_matters())
		dat += "<p>This land is forgiving: any crop will grow in any season, as long as it is sown in ploughed soil and kept watered.</p>"
	else
		var/list/now = list()
		var/list/later = list()
		var/unsuited = 0
		for (var/list/entry in farmers_almanac_seeds())
			if (farmers_almanac_grows(entry, climate, season, inside))
				now += entry[1]
				continue
			var/list/good_seasons = list()
			for (var/season_name in shown_seasons)
				if (farmers_almanac_grows(entry, climate, season_name, inside))
					good_seasons += lowertext(farmers_almanac_season_name(season_name))
			if (good_seasons.len)
				later += "[entry[1]] ([jointext(good_seasons, ", ")])"
			else
				unsuited++
		dat += "<p><b>Thriving this season:</b> [now.len ? jointext(sortList(now), ", ") : "nothing, sadly"].</p>"
		if (later.len)
			dat += "<p><b>Wait for a better season:</b> [jointext(sortList(later), "; ")].</p>"
		if (unsuited)
			dat += "<p>[unsuited] other kind[unsuited == 1 ? "" : "s"] of seed will not take root in this climate at all.</p>"
	dat += "</body></html>"
	return dat
