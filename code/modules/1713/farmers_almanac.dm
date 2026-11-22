// Farmer's almanac: a farming-skill book that reads the local climate.
// Crop advice is derived at runtime from the seed types' biome and season
// lists, using the same climate rule as crop growth in farming.dm. The
// seasonal weather table mirrors climate_weather_state() in
// code/modules/1713/weather.dm, and its temperatures are the climate normals
// (climate_normals.dm); tests/farmers_almanac checks it stays aligned.

// climate = list(season = list(wet-weather icon, storm icon))
var/global/list/farmers_almanac_climates = farmers_almanac_climates_table()
/proc/farmers_almanac_climates_table()
	return list(
	"tundra" = list(
		"WINTER" = list("snow2", "snow_storm"),
		"SPRING" = list("snow2", "snow_storm"),
		"SUMMER" = list("snow2", "snow1"),
		"FALL" = list("snow2", "snow_storm"),
		"Wet Season" = list("snow2", "snow_storm"),
		"Dry Season" = list("snow2", "snow1")),
	"taiga" = list(
		"WINTER" = list("snow2", "snow_storm"),
		"SPRING" = list("", "snow1"),
		"SUMMER" = list("", "snow1"),
		"FALL" = list("snow2", "snow_storm"),
		"Wet Season" = list("snow2", "snow_storm"),
		"Dry Season" = list("", "snow1")),
	"temperate" = list(
		"WINTER" = list("snow2", "snow_storm"),
		"SPRING" = list("rain2", "rain2"),
		"SUMMER" = list("rain2", "rain2"),
		"FALL" = list("rain2", "rain2"),
		"Wet Season" = list("snow2", "snow_storm"),
		"Dry Season" = list("rain2", "rain2")),
	"sea" = list(
		"WINTER" = list("rain1", "monsoon"),
		"SPRING" = list("rain2", "rain2"),
		"SUMMER" = list("rain2", "rain2"),
		"FALL" = list("rain1", "monsoon"),
		"Wet Season" = list("rain1", "monsoon"),
		"Dry Season" = list("rain2", "rain2")),
	"semiarid" = list(
		"WINTER" = list("rain1", "rain3"),
		"SPRING" = list("rain1", ""),
		"SUMMER" = list("rain1", ""),
		"FALL" = list("rain1", "rain3"),
		"Wet Season" = list("rain1", "rain3"),
		"Dry Season" = list("rain1", "")),
	"desert" = list(
		"WINTER" = list("rain1", ""),
		"SPRING" = list("rain1", ""),
		"SUMMER" = list("", "sandstorm"),
		"FALL" = list("", "sandstorm"),
		"Wet Season" = list("rain1", ""),
		"Dry Season" = list("", "sandstorm")),
	"savanna" = list(
		"WINTER" = list("rain2", "rain3"),
		"SPRING" = list("rain2", "rain3"),
		"SUMMER" = list("", ""),
		"FALL" = list("", ""),
		"Wet Season" = list("rain2", "rain3"),
		"Dry Season" = list("", "")),
	"jungle" = list(
		"WINTER" = list("rain3", "monsoon"),
		"SPRING" = list("rain3", "monsoon"),
		"SUMMER" = list("", ""),
		"FALL" = list("", ""),
		"Wet Season" = list("rain3", "monsoon"),
		"Dry Season" = list("", "")))

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
	return map && (map.ID in list(MAP_NOMADS_CONTINENTAL, MAP_NOMADS_PANGEA, MAP_NOMADS_NEW_WORLD, MAP_NOMADS_MEDITERRANEAN, MAP_NOMADS_EUROPE, MAP_NOMADS_GAIA, MAP_NOMADS_AMERICAS_NORTH, MAP_NOMADS_AMERICAS_SOUTH, MAP_NOMADS_ASIA, MAP_NOMADS_EARTH_EUROPE, MAP_NOMADS_EARTH_MEDITERRANEAN, MAP_NOMADS_EARTH_AFRICA, MAP_NOMADS_EARTH_ASIA, MAP_NOMADS_EARTH_OCEANIA, MAP_NOMADS_EARTH_GREENLAND, MAP_NOMADS_EARTH_ANTARCTICA))

// Same eligibility as crop growth: the climate must suit the crop, and the
// season must too unless the climate is tropical. Saplings always need both.
/proc/farmers_almanac_grows(list/entry, climate, season_name, inside)
	var/plant_path = entry[4]
	if (inside && (ispath(plant_path, /obj/structure/farming/plant/mushroom) || ispath(plant_path, /obj/structure/farming/plant/mushroompsy)))
		return TRUE
	// Cave wheat grows in any climate and season, but only out of the sun.
	if (ispath(plant_path, /obj/structure/farming/plant/cave_wheat))
		return inside
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
	show_browse(user, almanac_text(A, get_temp(user), T), "window=farmers_almanac;size=520x640")

/obj/item/weapon/farmers_almanac/proc/almanac_text(area/A, local_temp, turf/sky_at)
	var/climate = A.climate
	var/inside = (A.location == AREA_INSIDE)
	var/list/four_seasons = list("SPRING", "SUMMER", "FALL", "WINTER")
	var/list/shown_seasons = (season in four_seasons) ? four_seasons : list("Wet Season", "Dry Season")
	var/list/table = farmers_almanac_climates[climate]

	var/dat = "<html><head><title>Farmer's Almanac</title></head><body>"
	dat += "<h2>Farmer's Almanac</h2>"
	dat += "<p>Region: <b>[table ? farmers_almanac_climate_name(climate) : "Unrecorded lands"]</b>[inside ? " (under a roof)" : ""]<br>"
	dat += "Season: <b>[farmers_almanac_season_name(season)]</b><br>"
	// The weather over the reader's own tile: a storm covers part of a zone.
	var/sky = sky_at ? weather_look_at(sky_at) : replacetext(A.icon_state, "rad_", "")
	dat += "Sky: <b>[inside ? "sheltered" : farmers_almanac_weather_phrase(sky)]</b><br>"
	if (sky_at && !inside)
		dat += "Outlook: <b>[weather_forecast_line(sky_at)]</b><br>"
	dat += "Temperature here: <b>[local_temp]&deg;C</b></p>"

	dat += "<h3>Weather through the year</h3>"
	if (!table)
		dat += "<p>The almanac has no tables for this land.</p>"
	else
		dat += "<table border='1' cellpadding='3' cellspacing='0'><tr><th>Season</th><th>Typical temp.</th><th>Wet spells</th><th>Storms</th></tr>"
		for (var/season_name in shown_seasons)
			var/list/row = table[season_name]
			var/current = (season_name == season)
			dat += "<tr><td>[current ? "<b>" : ""][farmers_almanac_season_name(season_name)][current ? " (now)</b>" : ""]</td><td>[climate_season_mean(climate, season_name)]&deg;C</td><td>[farmers_almanac_weather_phrase(row[1])]</td><td>[farmers_almanac_weather_phrase(row[2])]</td></tr>"
		dat += "</table>"
		dat += "<p><i>Rain and monsoons water open fields. Blizzards kill crops that are not winter-hardy, and sandstorms destroy crops. Under a roof, crops are sheltered from storms but must be watered by hand. Under a glass roof, crops suited to this land keep growing out of season, at half speed.</i></p>"

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
