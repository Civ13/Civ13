//factions only
#define PIRATES "PIRATES"
#define CIVILIAN "CIVILIAN"
#define INDIANS "INDIANS"
#define BRITISH "BRITISH"
#define ROMAN "ROMAN"
#define AMERICAN "AMERICAN"

// used for languages only
#define ENGLISH "ENGLISH"
#define CARIB "CARIB"
#define LATIN "LATIN"
#define UKRAINIAN "UKRAINIAN"
#define CHINESE "CHINESE"
#define HEBREW "HEBREW"
#define SWAHILI "SWAHILI"
#define ZULU "ZULU"
#define AINU "AINU"
#define GAELIC "GAELIC"
#define ITALIAN "ITALIAN"
#define CHEROKEE "CHEROKEE"
#define INUIT "INUIT"
#define OLDNNORSE "OLDNORSE"
#define EGYPTIAN "EGYPTIAN"
#define IROQUOIS "IROQUOIS"

//used for languages & factions
#define SPANISH "SPANISH"
#define PORTUGUESE "PORTUGUESE"
#define FRENCH "FRENCH"
#define DUTCH "DUTCH"
#define JAPANESE "JAPANESE"
#define RUSSIAN "RUSSIAN"
#define CHECHEN "CHECHEN"
#define FINNISH "FINNISH"
#define NORWEGIAN "NORWEGIAN"
#define SWEDISH "SWEDISH"
#define DANISH "DANISH"
#define GREEK "GREEK"
#define ARAB "ARAB"
#define GERMAN "GERMAN"
#define VIETNAMESE "VIETNAMESE"
#define KOREAN "KOREAN"
#define FILIPINO "FILIPINO"
#define POLISH "POLISH"

/proc/faction_const2name(constant,age = 0)

	if (constant == PIRATES)
		return "Pirates"

	if (constant == BRITISH)
		if (age >= 6)
			return "United Kingdom"
		else
			return "British Empire"

	if (constant == CIVILIAN)
		if (map.ID == "TSARITSYN")
			return "Red Army"
		else if (map.ID == "YELTSIN")
			return "Militia"
		else if (map.ID == "AFRICAN_WARLORDS")
			return "Yellowagwana Wartribe"
		else if (map.ID == "TADOJSVILLE")
			return "United Nations Peacekeepers"
		else if (map.ID == "WHITERUN")
			return "Stormcloaks"
		else if (map.ID == "CAPITOL_HILL")
			return "Rioters"
		else if (map.ID == "WACO")
			return "Branch Davidians"
		else if (map.ID == "MISSIONARY_RIDGE")
			return "Confederates"
		else if (map.ID == "TANTIVEIV")
			return "Rebels"
		else if (map.ID == "RUHR_UPRISING")
			return "Ruhr Red Army"
		else if (map.ID == "MAGISTRAL")
			return "DRA Army"
		else if (map.ID == "BANK_ROBBERY" || map.ID == "DRUG_BUST")
			return "Police Department"
		else if (map.ID == "LONG_MARCH")
			return "Red Army"
		else if (map.ID == "EFT_FACTORY")
			return "Scavs"
		else
			if (age >= 6)
				return "Civilians"
			else
				return "Colonists"

	if (constant == INDIANS)
		if (map.ID == "AFRICAN_WARLORDS")
			return "Blugisi Wartribe"
		else if (map.ID == "TADOJSVILLE")
			return "Mercenary Warbands"
		else if (map.ID == "EAST_LOS_SANTOS")
			return "Ballas"
		else
			return "Native Tribe"

	if (constant == PORTUGUESE)
		return "Portuguese Empire"

	if (constant == SPANISH)
		return "Spanish Empire"

	if (constant == FRENCH)
		if (age >= 4)
			return "French Republic"
		else
			return "French Empire"

	if (constant == DUTCH)
		if (age >= 6)
			return "Dutch Monarchy"
		else
			return "Dutch Republic"

	if (constant == JAPANESE)
		return "Japanese Empire"

	if (constant == RUSSIAN)
		if (map.ID == "YELTSIN")
			return "Russian Army"
		else if (map.ID == "GROZNY")
			return "Russian Federal Forces"
		else if (map.ID == "TSARITSYN")
			return "White Army"
		else if (map.ID == "BANK_ROBBERY")
			return "Robbers"
		else if (map.ID == "DRUG_BUST")
			return "Rednikov Mobsters"
		else if (map.ID == "EFT_FACTORY")
			return "BEAR"
		else
			if (age == 6 || age == 7)
				return "Soviet Union"
			else if (age >= 8)
				return "Russian Federation"
			else
				return "Russian Empire"

	if (constant == ROMAN)
		if (map.ID == "WHITERUN")
			return "Imperial Army"
		else
			return "Roman Republic"

	if (constant == CHECHEN)
		return "Chechen Republic of Ichkeria"

	if (constant == FINNISH)
		return "Republic of Finland"

	if (constant == NORWEGIAN)
		if (map.ID == "CLASH")
			return "Bear Clan"
		else
			return "Kingdom of Norway"

	if (constant == SWEDISH)
		return "Kingdom of Sweden"

	if (constant == DANISH)
		if (map.ID == "CLASH")
			return "Raven Clan"
		else
			return "Kingdom of Denmark"

	if (constant == GERMAN)
		if (age == 6)
			return "Third Reich"
		else if (age >= 7)
			return "Federal Republic of Germany"
		else if (map.ID == "RUHR_UPRISING")
			return "Weimar Republic"
		else
			return "German Empire"
	if (constant == GREEK)
		return "Greek States"

	if (constant == ARAB)
		if (age >= 6)
			if (map.ID == "ARAB_TOWN")
				return "Hezbollah"
			else if (map.ID == "SOVAFGHAN" || map.ID == "HILL_3234" || map.ID == "MAGISTRAL")
				return "Mujahideen"
			else if (map.ID == "SYRIA")
				return "Syrian Armed Forces"
			else
				return "Insurgents"
		else
			return "Arabic Caliphate"

	if (constant == AMERICAN)
		if (map.ID == "ARAB_TOWN")
			return "IDF"
		else if (map.ID == "CAPITOL_HILL")
			return "American Government"
		else if (map.ID == "WACO")
			return "ATF"
		else if (map.ID == "TANTIVEIV")
			return "Imperials"
		else if (map.ID == "EAST_LOS_SANTOS")
			return "Grove Street Families"
		else if (map.ID == "EFT_FACTORY")
			return "USEC"
		else if (map.ID == "SYRIA")
			return "Free Syrian Army"
		else
			return "United States"

	if (constant == VIETNAMESE)
		return "Vietnamese"

	if (constant == POLISH)
		if (map.ID == "WARSAW")
			return "Polish Home Army"
		else
			return "Polish"

	if (constant == CHINESE)
		if (map.ID == "LONG_MARCH")
			return "National Army"
		else
			return "Chinese"

	if (constant == EGYPTIAN)
		return "Egyptian"

	if (constant == KOREAN)
		return "Korean"

	if (constant == IROQUOIS)
		return "Iroquois"

	if (constant == FILIPINO)
		return "Filipino"
