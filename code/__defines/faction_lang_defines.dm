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

//used for languages & factions
#define SPANISH "SPANISH"
#define PORTUGUESE "PORTUGUESE"
#define FRENCH "FRENCH"
#define DUTCH "DUTCH"
#define JAPANESE "JAPANESE"
#define RUSSIAN "RUSSIAN"
#define GREEK "GREEK"
#define ARAB "ARAB"
#define GERMAN "GERMAN"
#define VIETNAMESE "VIETNAMESE"
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
		else
			return "Colonists"

	if (constant == INDIANS)
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
		return "Dutch Republic"

	if (constant == JAPANESE)
		return "Japanese Empire"

	if (constant == RUSSIAN)
		if (age >= 6)
			return "Soviet Union"
		else
			if (map.ID == "TSARITSYN")
				return "White Army"
			else
				return "Russian Empire"
	if (constant == ROMAN)
		return "Roman Republic"

	if (constant == GERMAN)
		if (age >= 6)
			return "Third Reich"
		else
			return "German Empire"
	if (constant == GREEK)
		return "Greek States"

	if (constant == ARAB)
		if (age >= 6)
			if (map.ID == "ARAB_TOWN")
				return "Hezbollah"
			else
				return "Insurgents"
		else
			return "Arabic Caliphate"

	if (constant == AMERICAN)
		if (map.ID == "ARAB_TOWN")
			return "IDF"
		else
			return "United States"

	if (constant == VIETNAMESE)
		return "Vietnamese"