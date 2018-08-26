//factions only
#define PIRATES "PIRATES"
#define CIVILIAN "CIVILIAN"
#define INDIANS "INDIANS"
#define BRITISH "BRITISH"

// used for languages only
#define ENGLISH "ENGLISH"
#define CARIB "CARIB"

//used for languages & factions
#define SPANISH "SPANISH"
#define PORTUGUESE "PORTUGUESE"
#define FRENCH "FRENCH"
#define DUTCH "DUTCH"

/proc/faction_const2name(constant)

	if (constant == PIRATES)
		return "Pirates"

	if (constant == BRITISH)
		return "Royal Navy"

	if (constant == CIVILIAN)
		return "Colonists"

	if (constant == INDIANS)
		return "Native Tribe"

	if (constant == PORTUGUESE)
		return "Portuguese Navy"

	if (constant == SPANISH)
		return "Spanish Navy"

	if (constant == FRENCH)
		return "French Navy"

	if (constant == DUTCH)
		return "Dutch Navy"