// Language flags.
#define WHITELISTED  1   // Language is available if the speaker is whitelisted.
#define RESTRICTED   2   // Language can only be acquired by spawning or an admin.
#define NONVERBAL	4   // Language has a significant non-verbal component. Speech is garbled without line-of-sight.
#define SIGNLANG	 8   // Language is completely non-verbal. Speech is displayed through emotes for those who can understand.
#define HIVEMIND	 16  // Broadcast to all mobs with this language.
#define NONGLOBAL	32  // Do not add to general languages list.
#define INNATE	   64  // All mobs can be assumed to speak and understand this language. (audible emotes)
#define NO_TALK_MSG  128 // Do not show the "\The [speaker] talks into \the [radio]" message
#define NO_STUTTER   256 // No stuttering, slurring, or other speech problems
#define COMMON_VERBS 512
// Language proficiency, a score from 0 to 100 (code/game/mob/language/proficiency.dm).
#define LANGUAGE_BROKEN 25			// can speak it, with gaps
#define LANGUAGE_CONVERSATIONAL 60	// nearly everything, with an accent
#define LANGUAGE_FLUENT 90			// everything
#define LANGUAGE_LEARN_COOLDOWN 200	// deciseconds between gains from hearing or speaking
#define LANGUAGE_HEAR_GAIN 0.033	// score per heard line: about 6 an hour among speakers
#define LANGUAGE_PRACTICE_GAIN 0.1	// score per line spoken to a better speaker
#define LANGUAGE_DAILY_CAP 12		// score a language can gain in one real day from hearing and speaking
#define LANGUAGE_LESSON_TIME 600	// deciseconds a lesson takes
#define LANGUAGE_LESSON_GAIN 6		// score per lesson from a fluent teacher: 15 one-minute lessons to Fluent
#define LANGUAGE_LESSON_DAILY_CAP 90	// score a language can gain in one real day from lessons: one long sitting can reach Fluent
#define LANGUAGE_STUDY_GAIN 5		// score per sitting with a language book
#define LANGUAGE_STUDY_DAILY_CAP 10	// score a language can gain in one real day from books and writing
// Language drift (code/game/mob/language/drift.dm).
#define LANGUAGE_DRIFT_TICK 18000		// deciseconds between drift updates: half an hour
#define LANGUAGE_DRIFT_HEAR_COOLDOWN 200	// deciseconds between counted lines for one listener
#define LANGUAGE_DRIFT_MIN_LINES 10		// lines from its own nation a community must hear in a tick to drift
#define LANGUAGE_DRIFT_GAIN 0.25		// drift an isolated community gains a tick: about 120 hours of talk to reach the split level
#define LANGUAGE_DRIFT_CONTACT_LINES 3	// lines from other nations in a tick that count as contact
#define LANGUAGE_DRIFT_CONTACT_LOSS 5	// drift a community loses in a tick with contact
#define LANGUAGE_SPLIT_DRIFT 60			// drift a community must hold to split off
#define LANGUAGE_SPLIT_MIN_NATIVES 5		// living native speakers a community needs to split off
#define LANGUAGE_SPLIT_HOLD 10080		// real minutes drift must stay at LANGUAGE_SPLIT_DRIFT with no contact: 7 days
#define LANGUAGE_DAUGHTERS_PER_ROOT 2	// daughter languages one built-in language can have on a world
#define LANGUAGE_DAUGHTER_KIN 80		// how much of each other parent and daughter follow at the split
#define LANGUAGE_DAUGHTER_KIN_STEP 10	// lost each time the daughter holds a far drift again
// Peoples (code/game/mob/living/carbon/human/peoples.dm).
#define PEOPLE_COMMUNITY_RANGE 40		// tiles around a new character's start that make up their community
#define PEOPLE_COMMUNITY_MIN 3			// living characters with a people there before a newcomer is born into it
#define PEOPLE_SPLIT_YEARS 180			// calendar years a nation's people must stay out of touch to split: about a month of real time
#define PEOPLE_SPLIT_MIN 5				// living members a split needs, and at least half of the nation
#define PEOPLE_CONTACT_RANGE 10			// tiles to someone of another faction that count as contact
#define PEOPLE_BLEND_MIN 4				// living members a nation needs before its peoples can blend
#define PEOPLE_BLEND_YEARS 30			// played years two peoples must each be a quarter of a nation to blend: about 5 real days
#define PEOPLE_RAISED_YEARS 20			// played years among another people before "Raised among": about 3 real days
#define PEOPLE_CONTACT_LINES 3			// lines heard from another faction in a year that count as contact
#define LANGUAGE_DAUGHTER_KIN_MIN 40		// parent and daughter never follow less of each other than this
