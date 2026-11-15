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
#define LANGUAGE_LESSON_TIME 1200	// deciseconds a lesson takes
#define LANGUAGE_LESSON_GAIN 1		// score per lesson from a fluent teacher
#define LANGUAGE_LESSON_DAILY_CAP 8	// score a language can gain in one real day from lessons
#define LANGUAGE_STUDY_GAIN 5		// score per sitting with a language book
#define LANGUAGE_STUDY_DAILY_CAP 10	// score a language can gain in one real day from books and writing
