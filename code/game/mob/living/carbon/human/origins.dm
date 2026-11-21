// Peoples of the Nomads lands.
//
// A new character belongs to one people for life. The people gives the mother
// tongue and the style of name. Looks come from the birthplace's climate, the
// same for everyone born there, never from the people. The people is
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
	// No looks here on purpose: a people never decides hair, eyes or skin
	// (birthplace_looks() below), so no look marks anyone as one people.

/datum/origin/northmen
	id = "northmen"
	name = "Northmen"
	language = "Old Norse"
	name_style = "oldnorse"

/datum/origin/gaels
	id = "gaels"
	name = "Gaels"
	language = "Gaelic"
	name_style = "gaelic"

/datum/origin/latins
	id = "latins"
	name = "Latins"
	language = "Latin"
	name_style = "roman"

/datum/origin/hellenes
	id = "hellenes"
	name = "Hellenes"
	language = "Greek"
	name_style = "greek"

/datum/origin/egyptians
	id = "egyptians"
	name = "Egyptians"
	language = "Egyptian"
	name_style = "egyptian"

/datum/origin/arabs
	id = "arabs"
	name = "Arabs"
	language = "Arabic"
	name_style = "arab"

/datum/origin/persians
	id = "persians"
	name = "Persians"
	language = "Farsi"
	name_style = "arab"

/datum/origin/swahili
	id = "swahili"
	name = "Swahili"
	language = "Swahili"
	name_style = "swahili"

/datum/origin/zulu
	id = "zulu"
	name = "Zulu"
	language = "Zulu"
	name_style = "zulu"

/datum/origin/han
	id = "han"
	name = "Han"
	language = "Chinese"
	name_style = "chinese"

/datum/origin/mongols
	id = "mongols"
	name = "Mongols"
	language = "Mongolian"
	name_style = "mongolian"

/datum/origin/koreans
	id = "koreans"
	name = "Koreans"
	language = "Korean"
	name_style = "korean"

/datum/origin/yamato
	id = "yamato"
	name = "Yamato"
	language = "Japanese"
	name_style = "japanese"

/datum/origin/viet
	id = "viet"
	name = "Viet"
	language = "Vietnamese"
	name_style = "vietnamese"

/datum/origin/inuit
	id = "inuit"
	name = "Inuit"
	language = "Inuktitut"
	name_style = "inuit"

/datum/origin/cherokee
	id = "cherokee"
	name = "Cherokee"
	language = "Cherokee"
	name_style = "cherokee"

/datum/origin/sioux
	id = "sioux"
	name = "Sioux"
	language = "Sioux"
	name_style = "sioux"

/datum/origin/navajo
	id = "navajo"
	name = "Navajo"
	language = "Navajo"
	name_style = "navajo"

/datum/origin/aztecs
	id = "aztecs"
	name = "Aztecs"
	language = "Aztec"
	name_style = "aztec"

/datum/origin/maya
	id = "maya"
	name = "Maya"
	language = "Mayan"
	name_style = "mayan"

/datum/origin/inca
	id = "inca"
	name = "Inca"
	language = "Quechua"
	name_style = "quechua"

/datum/origin/tupi
	id = "tupi"
	name = "Tupi"
	language = "Tupi"
	name_style = "tupi"

/datum/origin/caribs
	id = "caribs"
	name = "Caribs"
	language = "Carib"
	name_style = "carib"

// Gaia's own peoples (peoples.dm): Gaia is not Earth, so these roots carry
// names of the land. Each keeps the language and name style of the
// real-world root it replaces on Gaia (gaia_root_renames).

/datum/origin/fjordfolk
	id = "fjordfolk"
	name = "Fjordfolk"
	language = "Old Norse"
	name_style = "oldnorse"

/datum/origin/hearthlanders
	id = "hearthlanders"
	name = "Hearthlanders"
	language = "Latin"
	name_style = "roman"

/datum/origin/isleborn
	id = "isleborn"
	name = "Isleborn"
	language = "Greek"
	name_style = "greek"

/datum/origin/dunefolk
	id = "dunefolk"
	name = "Dunefolk"
	language = "Egyptian"
	name_style = "egyptian"

/datum/origin/grasslanders
	id = "grasslanders"
	name = "Grasslanders"
	language = "Swahili"
	name_style = "swahili"

/datum/origin/mistwood
	id = "mistwood"
	name = "Mistwood Folk"
	language = "Japanese"
	name_style = "japanese"

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
	if (!istext(id))
		return null
	// A root people, else one that formed in play (peoples.dm).
	. = origins_by_id[id]
	if (!.)
		. = world_people(id)

// Land (map ID) -> list(climate = origin id). "default" covers a climate the
// land has no people for, so nobody is left without an origin.
/proc/land_origin_tables()
	var/static/list/tables = null
	if (!tables)
		// Gaia's own peoples (peoples.dm): not Earth, so no real-world names.
		var/list/gaia = list(
			"tundra" = "fjordfolk", "taiga" = "fjordfolk",
			"temperate" = "hearthlanders", "semiarid" = "hearthlanders",
			"sea" = "isleborn",
			"desert" = "dunefolk",
			"savanna" = "grasslanders",
			"jungle" = "mistwood",
			"default" = "hearthlanders")
		var/list/europe = list(
			"tundra" = "northmen", "taiga" = "northmen",
			"temperate" = "gaels",
			"sea" = "hellenes",
			"semiarid" = "latins", "desert" = "latins",
			"default" = "latins")
		var/list/mediterranean = list(
			"temperate" = "latins", "semiarid" = "latins",
			"sea" = "hellenes",
			"desert" = "egyptians",
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
		var/list/greenland = list(
			"default" = "inuit")
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
			MAP_NOMADS_EARTH_MEDITERRANEAN = mediterranean,
			MAP_NOMADS_EARTH_AFRICA = africa,
			MAP_NOMADS_EARTH_ASIA = asia,
			MAP_NOMADS_EARTH_GREENLAND = greenland,
			MAP_NOMADS_AFRICA = africa,
			MAP_NOMADS_ASIA = asia,
			MAP_NOMADS_AMERICAS_NORTH = americas_north,
			MAP_NOMADS_AMERICAS_SOUTH = americas_south,
			MAP_NOMADS_JUNGLE = jungle,
			MAP_NOMADS_DESERT = desert)
	return tables

// Looks of someone born in a climate: list(eyes, hair, list(lightest, darkest
// s_tone)). Every climate keeps wide, overlapping ranges, and the same table
// serves every people, so looks say where someone was born at most, never who
// their people are. Character setup still wins when the player keeps it.
/proc/birthplace_looks(climate)
	var/static/list/looks = null
	if (!looks)
		var/list/all_eyes = list("Brown", "Black", "Green", "Blue")
		var/list/dark_eyes = list("Brown", "Black", "Green")
		var/list/all_hair = list("Black", "Dark Brown", "Brown", "Light Brown", "Dirty Blond", "Blond", "Light Blond", "Red", "Orange")
		var/list/dark_hair = list("Black", "Dark Brown", "Brown", "Light Brown")
		looks = list(
			"tundra" = list(all_eyes, all_hair, list(-10, -75)),
			"taiga" = list(all_eyes, all_hair, list(-10, -80)),
			"temperate" = list(all_eyes, all_hair, list(-10, -110)),
			"sea" = list(all_eyes, all_hair, list(-15, -140)),
			"semiarid" = list(dark_eyes, dark_hair, list(-25, -145)),
			"desert" = list(dark_eyes, dark_hair, list(-35, -170)),
			"savanna" = list(dark_eyes, dark_hair, list(-50, -180)),
			"jungle" = list(dark_eyes, dark_hair, list(-35, -175)),
			"default" = list(all_eyes, all_hair, list(-10, -175)))
	var/list/row = looks[climate]
	return row ? row : looks["default"]

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
// Not saved: the people of the account's last character, when this one
// returns close to where it died (death_legacy.dm).
/mob/living/human/var/tmp/legacy_people = null

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

// A new character on a land with peoples. One who starts among people is
// born into that community (peoples.dm): its most common people by default,
// or another people living there. One who starts in the wild belongs to the
// people of the birthplace, or another people of this land. Someone at the
// keyboard picks and may keep the name and looks from character setup.
/mob/living/human/proc/choose_origin(climate)
	if (!map || origin_id)
		return FALSE
	var/datum/origin/O = land_origin_for(map.ID, climate)
	var/list/community = community_peoples(get_turf(src), src)
	var/list/peoples = community.len ? community_people_choices(community) : land_peoples(map.ID)
	if (community.len && peoples.len)
		O = peoples[peoples[1]]
	// Returning where the last character died: the same people, if it lives here.
	if (legacy_people)
		var/datum/origin/kept = origin_by_id(legacy_people)
		if (kept && (!community.len || (kept.name in peoples)))
			O = kept
		legacy_people = null
	// A people asked for when the character was made (agent spawn), if this land has it.
	if (origin_wish)
		var/datum/origin/wished = origin_by_id(origin_wish)
		if (wished && (wished.name in peoples))
			O = wished
		origin_wish = null
	var/keep_setup = FALSE
	if (client)
		if (peoples.len > 1)
			var/by_birth = community.len ? "The people here[O ? " ([O.name])" : ""]" : "By birthplace[O ? " ([O.name])" : ""]"
			var/list/options = list(by_birth)
			for (var/people in peoples)
				options += people
			var/question = community.len ? "You were born among these peoples. Which do you belong to? Your people gives you your mother tongue." : "Which people do you belong to? Your people gives you your mother tongue."
			var/picked = WWinput(src, question, "Your People", by_birth, options)
			if (QDELETED(src) || origin_id)
				return FALSE
			if (picked && peoples[picked])
				O = peoples[picked]
		if (O && client)
			var/take = "A name of the [O.name] and looks of my birthplace"
			var/keep = "Keep my character setup"
			var/setup_random = client.prefs && (client.prefs.be_random_name || client.prefs.be_random_body)
			var/answer = WWinput(src, "Take a name of the [O.name] and looks of your birthplace, or keep the ones from your character setup?", "Your People", setup_random ? take : keep, list(take, keep))
			if (QDELETED(src) || origin_id)
				return FALSE
			keep_setup = (answer == keep)
	return apply_origin(O, land_display_name(map), keep_setup, climate)

// Give a freshly made character their people: mother tongue and, unless the
// player keeps their own setup, a name of that people and looks of their
// birthplace.
/mob/living/human/proc/apply_origin(datum/origin/O, land = null, keep_setup = FALSE, climate = null)
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
	var/list/looks = birthplace_looks(climate)
	update_character_appearance(looks[1], looks[2], looks[3])
	return TRUE
