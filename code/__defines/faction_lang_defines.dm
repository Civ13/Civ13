// used for factions and sometimes languages
#define CIVILIAN "CIVILIAN"
#define PARTISAN "PARTISAN" // ukrainian but not with ruskies
#define ITALIAN "ITALIAN"


#define PIRATES "PIRATES"
#define BRITISH "BRITISH"

// used for languages only
#define GERMAN "GERMAN"
#define RUSSIAN "RUSSIAN"
#define POLISH "POLISH"
#define UKRAINIAN "UKRAINIAN"
#define ENGLISH "ENGLISH"
#define JAPANESE "JAPANESE"

/proc/faction_const2name(constant)

	if (constant == PIRATES)
		return "Pirates"

	if (constant == BRITISH)
		return "Royal Navy"