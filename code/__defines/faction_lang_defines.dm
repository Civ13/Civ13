//factions only
#define PIRATES "PIRATES"
#define CIVILIAN "CIVILIAN"
#define INDIANS "INDIANS"
#define BRITISH "BRITISH"
#define ROMAN "ROMAN"

// used for languages only
#define ENGLISH "ENGLISH"
#define CARIB "CARIB"
#define LATIN "LATIN"

//used for languages & factions
#define SPANISH "SPANISH"
#define PORTUGUESE "PORTUGUESE"
#define FRENCH "FRENCH"
#define DUTCH "DUTCH"
#define GREEK "GREEK"
#define ARAB "ARAB"

/proc/faction_const2name(constant)

	if (constant == PIRATES)
		return "Pirates"

	if (constant == BRITISH)
		return "British Empire"

	if (constant == CIVILIAN)
		return "Colonists"

	if (constant == INDIANS)
		return "Native Tribe"

	if (constant == PORTUGUESE)
		return "Portuguese Empire"

	if (constant == SPANISH)
		return "Spanish Empire"

	if (constant == FRENCH)
		return "French Empire"

	if (constant == DUTCH)
		return "Dutch Republic"

	if (constant == ROMAN)
		return "Roman Republic"

	if (constant == GREEK)
		return "Greek States"

	if (constant == ARAB)
		return "Arabic Caliphate"