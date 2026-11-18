// Peoples of the Nomads lands.
//
// A new character belongs to one people for life. The people gives the mother
// tongue, the style of name and the usual hair, eye and skin tones, and it is
// recorded on the character together with the land they were born on, so that
// later systems (language learning, travel, examine) can ask where someone is
// from rather than guessing it from the languages they happen to know.
//
// Each land lists its peoples by the climate of the birthplace. Adding a
// people to a land is one /datum/origin and one row in land_origin_tables().

/datum/origin
	var/id = null				// stable text id, saved on the character
	var/name = "Wanderers"		// what the people are called
	var/language = "English"	// mother tongue, a key of all_languages
	var/name_style = "english"	// species.get_random_[name_style]_name(gender)
	var/list/hair = list("Black")
	var/list/eyes = list("Black")
	var/list/skin = list(-10, -60)	// lightest, darkest s_tone

/datum/origin/northmen
	id = "northmen"
	name = "Northmen"
	language = "Old Norse"
	name_style = "oldnorse"
	hair = list("Light Blond", "Blond", "Dirty Blond", "Light Brown")
	eyes = list("Blue", "Green", "Brown")
	skin = list(-10, -40)

/datum/origin/gaels
	id = "gaels"
	name = "Gaels"
	language = "Gaelic"
	name_style = "gaelic"
	hair = list("Orange", "Light Brown", "Red", "Brown")
	eyes = list("Brown", "Green")
	skin = list(-15, -30)

/datum/origin/latins
	id = "latins"
	name = "Latins"
	language = "Latin"
	name_style = "roman"
	hair = list("Light Brown", "Dark Brown")
	eyes = list("Green", "Brown", "Black")
	skin = list(-40, -60)

/datum/origin/hellenes
	id = "hellenes"
	name = "Hellenes"
	language = "Greek"
	name_style = "greek"
	hair = list("Brown", "Dark Brown", "Black")
	eyes = list("Green", "Brown", "Black")
	skin = list(-40, -65)

/datum/origin/egyptians
	id = "egyptians"
	name = "Egyptians"
	language = "Egyptian"
	name_style = "egyptian"
	hair = list("Dark Brown", "Black")
	eyes = list("Brown", "Black")
	skin = list(-70, -105)

/datum/origin/arabs
	id = "arabs"
	name = "Arabs"
	language = "Arabic"
	name_style = "arab"
	hair = list("Dark Brown", "Black")
	eyes = list("Brown", "Black")
	skin = list(-70, -105)

/datum/origin/persians
	id = "persians"
	name = "Persians"
	language = "Farsi"
	name_style = "arab"
	hair = list("Black", "Light Brown", "Dark Brown")
	eyes = list("Green", "Brown", "Black")
	skin = list(-35, -80)

/datum/origin/swahili
	id = "swahili"
	name = "Swahili"
	language = "Swahili"
	name_style = "swahili"
	hair = list("Black")
	eyes = list("Brown", "Black")
	skin = list(-145, -175)

/datum/origin/zulu
	id = "zulu"
	name = "Zulu"
	language = "Zulu"
	name_style = "zulu"
	hair = list("Black")
	eyes = list("Black")
	skin = list(-145, -174)

/datum/origin/han
	id = "han"
	name = "Han"
	language = "Chinese"
	name_style = "chinese"
	hair = list("Dark Brown", "Black")
	eyes = list("Brown", "Black")
	skin = list(-15, -25)

/datum/origin/mongols
	id = "mongols"
	name = "Mongols"
	language = "Mongolian"
	name_style = "mongolian"
	hair = list("Black", "Dark Brown")
	eyes = list("Black", "Brown")
	skin = list(-25, -60)

/datum/origin/koreans
	id = "koreans"
	name = "Koreans"
	language = "Korean"
	name_style = "korean"
	hair = list("Dark Brown", "Black")
	eyes = list("Brown", "Black")
	skin = list(-15, -30)

/datum/origin/yamato
	id = "yamato"
	name = "Yamato"
	language = "Japanese"
	name_style = "japanese"
	hair = list("Dark Brown", "Black")
	eyes = list("Brown", "Black")
	skin = list(-15, -25)

/datum/origin/viet
	id = "viet"
	name = "Viet"
	language = "Vietnamese"
	name_style = "vietnamese"
	hair = list("Dark Brown", "Black")
	eyes = list("Brown", "Black")
	skin = list(-25, -50)

/datum/origin/inuit
	id = "inuit"
	name = "Inuit"
	language = "Inuktitut"
	name_style = "inuit"
	hair = list("Black", "Dark Brown")
	eyes = list("Brown", "Black")
	skin = list(-45, -70)

/datum/origin/cherokee
	id = "cherokee"
	name = "Cherokee"
	language = "Cherokee"
	name_style = "cherokee"
	hair = list("Black", "Dark Brown")
	eyes = list("Brown", "Black")
	skin = list(-50, -80)

/datum/origin/sioux
	id = "sioux"
	name = "Sioux"
	language = "Sioux"
	name_style = "sioux"
	hair = list("Black", "Dark Brown")
	eyes = list("Brown", "Black")
	skin = list(-50, -80)

/datum/origin/navajo
	id = "navajo"
	name = "Navajo"
	language = "Navajo"
	name_style = "navajo"
	hair = list("Black", "Dark Brown")
	eyes = list("Brown", "Black")
	skin = list(-55, -90)

/datum/origin/aztecs
	id = "aztecs"
	name = "Aztecs"
	language = "Aztec"
	name_style = "aztec"
	hair = list("Black", "Dark Brown")
	eyes = list("Brown", "Black")
	skin = list(-60, -95)

/datum/origin/maya
	id = "maya"
	name = "Maya"
	language = "Mayan"
	name_style = "mayan"
	hair = list("Black", "Dark Brown")
	eyes = list("Brown", "Black")
	skin = list(-60, -95)

/datum/origin/inca
	id = "inca"
	name = "Inca"
	language = "Quechua"
	name_style = "quechua"
	hair = list("Black", "Dark Brown")
	eyes = list("Brown", "Black")
	skin = list(-60, -95)

/datum/origin/tupi
	id = "tupi"
	name = "Tupi"
	language = "Tupi"
	name_style = "tupi"
	hair = list("Black", "Dark Brown")
	eyes = list("Brown", "Black")
	skin = list(-70, -105)

/datum/origin/caribs
	id = "caribs"
	name = "Caribs"
	language = "Carib"
	name_style = "carib"
	hair = list("Black", "Dark Brown")
	eyes = list("Brown", "Black")
	skin = list(-80, -115)

// Names of the peoples added with this file. They live here rather than in
// config/names so that the offline fixtures, which stage an exact pinned set
// of name files, are not affected by a new people.
var/global/list/first_names_male_quechua = list("Amaru", "Apu", "Atoc", "Auqui", "Cusi", "Guaman", "Inti", "Illapa", "Kunturi", "Manco", "Mayta", "Ninan", "Rumi", "Sinchi", "Titu", "Tupaq", "Wayra", "Yupanqui", "Ollanta", "Kusi", "Urqu", "Katari", "Sayri", "Waman", "Huascar", "Atauchi", "Paullu", "Roca", "Capac", "Yawar")
var/global/list/first_names_female_quechua = list("Chaska", "Illari", "Killa", "Nayra", "Ocllo", "Qori", "Quilla", "Sami", "Sisa", "Sumaq", "Tika", "Urpi", "Wayta", "Yachay", "Nusta", "Chimpu", "Kukuli", "Suyana", "Tamya", "Wara", "Yana", "Achiq", "Cori", "Anka", "Asiri", "Kusi", "Pacha", "Qoyllur", "Micay", "Cava")
var/global/list/first_names_male_tupi = list("Abaete", "Acir", "Aimbere", "Apoena", "Araribo", "Caua", "Guaraci", "Ibere", "Itagiba", "Jaguare", "Moacir", "Peri", "Piata", "Poti", "Raoni", "Ruda", "Tabajara", "Taua", "Tibirica", "Ubirajara", "Ubirata", "Upiara", "Cunhambebe", "Arati", "Coaraci", "Itauna", "Anhangu", "Pindobu", "Japi", "Cairu")
var/global/list/first_names_female_tupi = list("Iracema", "Jaci", "Jacira", "Janaina", "Jandira", "Jurema", "Moema", "Potira", "Yara", "Iara", "Araci", "Ceci", "Maiara", "Mayara", "Taina", "Jussara", "Iraci", "Indaia", "Bartira", "Anahi", "Kauane", "Tuane", "Yacy", "Guaraciaba", "Ibotira", "Jupira", "Aracema", "Jacui", "Irupe", "Paraguacu")

var/global/list/origins_by_id = null

/proc/origin_by_id(id)
	if (!origins_by_id)
		origins_by_id = list()
		for (var/origin_type in typesof(/datum/origin) - /datum/origin)
			var/datum/origin/O = new origin_type
			origins_by_id[O.id] = O
	return istext(id) ? origins_by_id[id] : null

// Land (map ID) -> list(climate = origin id). "default" covers a climate the
// land has no people for, so nobody is left without an origin.
/proc/land_origin_tables()
	var/static/list/tables = null
	if (!tables)
		var/list/gaia = list(
			"tundra" = "northmen", "taiga" = "northmen",
			"temperate" = "latins", "semiarid" = "latins",
			"sea" = "hellenes",
			"desert" = "egyptians",
			"savanna" = "swahili",
			"jungle" = "yamato",
			"default" = "latins")
		var/list/europe = list(
			"tundra" = "northmen", "taiga" = "northmen",
			"temperate" = "gaels",
			"sea" = "hellenes",
			"semiarid" = "latins", "desert" = "latins",
			"default" = "latins")
		var/list/africa = list(
			"jungle" = "swahili", "savanna" = "swahili",
			"temperate" = "zulu",
			"desert" = "egyptians",
			"semiarid" = "arabs", "sea" = "arabs",
			"default" = "swahili")
		var/list/asia = list(
			"tundra" = "mongols",
			"taiga" = "koreans",
			"temperate" = "han", "semiarid" = "han",
			"desert" = "persians",
			"sea" = "yamato",
			"jungle" = "viet", "savanna" = "viet",
			"default" = "han")
		var/list/americas_north = list(
			"tundra" = "inuit", "taiga" = "inuit",
			"temperate" = "cherokee", "sea" = "cherokee",
			"semiarid" = "sioux",
			"desert" = "navajo",
			"savanna" = "aztecs", "jungle" = "aztecs",
			"default" = "cherokee")
		var/list/americas_south = list(
			"tundra" = "inca", "taiga" = "inca", "temperate" = "inca",
			"semiarid" = "inca", "desert" = "inca",
			"jungle" = "tupi", "savanna" = "tupi",
			"sea" = "caribs",
			"default" = "inca")
		var/list/jungle = list(
			"sea" = "caribs",
			"default" = "maya")
		var/list/desert = list(
			"semiarid" = "arabs", "sea" = "arabs",
			"default" = "egyptians")
		tables = list(
			MAP_NOMADS_GAIA = gaia,
			MAP_NOMADS_CONTINENTAL = gaia,
			MAP_NOMADS_PANGEA = gaia,
			MAP_NOMADS_EUROPE = europe,
			MAP_NOMADS_EARTH_EUROPE = europe,
			MAP_NOMADS_EARTH_AFRICA = africa,
			MAP_NOMADS_EARTH_ASIA = asia,
			MAP_NOMADS_AFRICA = africa,
			MAP_NOMADS_ASIA = asia,
			MAP_NOMADS_AMERICAS_NORTH = americas_north,
			MAP_NOMADS_AMERICAS_SOUTH = americas_south,
			MAP_NOMADS_JUNGLE = jungle,
			MAP_NOMADS_DESERT = desert)
	return tables

/proc/land_has_origins(map_id)
	var/list/tables = land_origin_tables()
	return (map_id in tables)

/proc/land_origin_for(map_id, climate)
	var/list/tables = land_origin_tables()
	var/list/table = tables[map_id]
	if (!table)
		return null
	var/origin_id = table[climate]
	if (!origin_id)
		origin_id = table["default"]
	return origin_by_id(origin_id)

// Saved with the character: which people they belong to and where they were born.
/mob/living/human/var/origin_id = null
/mob/living/human/var/origin_land = null
// Not saved: a people requested before the character first picks one.
/mob/living/human/var/tmp/origin_wish = null

/mob/living/human/proc/get_origin()
	return origin_by_id(origin_id)

// One line for notes and, later, for examine and the languages window.
/mob/living/human/proc/origin_summary()
	var/datum/origin/O = get_origin()
	if (!O)
		return null
	if (origin_land)
		return "[O.name] of [origin_land], mother tongue [O.language]"
	return "[O.name], mother tongue [O.language]"

// "Nomads (Gaia)" -> "Gaia": the land's own name for notes and records.
/proc/land_display_name(obj/map_metadata/M)
	if (!M || !M.title)
		return null
	var/lp = findtext(M.title, "(")
	var/rp = findtext(M.title, ")", lp + 1)
	if (lp && rp > lp + 1)
		return copytext(M.title, lp + 1, rp)
	return M.title

// The peoples of a land, by name, in table order and without repeats.
/proc/land_peoples(map_id)
	var/list/tables = land_origin_tables()
	var/list/table = tables[map_id]
	var/list/peoples = list()
	for (var/climate in table)
		var/datum/origin/O = origin_by_id(table[climate])
		if (O && !(O.name in peoples))
			peoples[O.name] = O
	return peoples

// A new character on a land with peoples. Someone at the keyboard may pick a
// people of this land and may keep the name and looks from character setup;
// everyone else belongs to the people of their birthplace.
/mob/living/human/proc/choose_origin(climate)
	if (!map || origin_id)
		return FALSE
	var/datum/origin/O = land_origin_for(map.ID, climate)
	// A people asked for when the character was made (agent spawn), if this land has it.
	if (origin_wish)
		var/datum/origin/wished = origin_by_id(origin_wish)
		if (wished && (wished.name in land_peoples(map.ID)))
			O = wished
		origin_wish = null
	var/keep_setup = FALSE
	if (client)
		var/list/peoples = land_peoples(map.ID)
		if (peoples.len > 1)
			var/by_birth = "By birthplace[O ? " ([O.name])" : ""]"
			var/list/options = list(by_birth)
			for (var/people in peoples)
				options += people
			var/picked = WWinput(src, "Which people do you belong to? Your people gives you your mother tongue.", "Your People", by_birth, options)
			if (QDELETED(src) || origin_id)
				return FALSE
			if (picked && peoples[picked])
				O = peoples[picked]
		if (O && client)
			var/take = "Name and looks of the [O.name]"
			var/keep = "Keep my character setup"
			var/setup_random = client.prefs && (client.prefs.be_random_name || client.prefs.be_random_body)
			var/answer = WWinput(src, "Take a name and looks of the [O.name], or keep the ones from your character setup?", "Your People", setup_random ? take : keep, list(take, keep))
			if (QDELETED(src) || origin_id)
				return FALSE
			keep_setup = (answer == keep)
	return apply_origin(O, land_display_name(map), keep_setup)

// Give a freshly made character their people: mother tongue and, unless the
// player keeps their own setup, a name and looks of that people.
/mob/living/human/proc/apply_origin(datum/origin/O, land = null, keep_setup = FALSE)
	if (!istype(O))
		return FALSE
	if (O.language != "English" && add_language(O.language, TRUE))
		remove_language("English")
		remove_note("Known Languages", "English")
		add_note("Known Languages", O.language)
	var/datum/language/mother_tongue = all_languages[O.language]
	if (mother_tongue && knows_language(mother_tongue))
		default_language = mother_tongue
	origin_id = O.id
	origin_land = land
	add_note("Origin", origin_summary())
	if (keep_setup)
		return TRUE
	var/name_proc = "get_random_[O.name_style]_name"
	if (species && hascall(species, name_proc))
		name = call(species, name_proc)(gender)
		real_name = name
	update_character_appearance(O.eyes, O.hair, O.skin)
	return TRUE
