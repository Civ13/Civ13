// A set of constants used to determine which type of mute an admin wishes to apply.
// Please read and understand the muting/automuting stuff before changing these. MUTE_IC_AUTO, etc. = (MUTE_IC << 1)
// Therefore there needs to be a gap between the flags for the automute flags.
#define MUTE_IC		0x1
#define MUTE_OOC	   0x2
#define MUTE_PRAY	  0x4
#define MUTE_ADMINHELP 0x8
#define MUTE_DEADCHAT  0x10
#define MUTE_MENTORHELP  0x20
#define MUTE_ALL	   0xFFFF

// Number of identical messages required to get the spam-prevention auto-mute thing to trigger warnings and automutes.
#define SPAM_TRIGGER_WARNING  5
#define SPAM_TRIGGER_AUTOMUTE 10

// Some constants for DB_Ban
#define BANTYPE_PERMA	   1
#define BANTYPE_TEMP		2
#define BANTYPE_JOB_PERMA   3
#define BANTYPE_JOB_TEMP	4
#define BANTYPE_ANY_FULLBAN 5 // Used to locate stuff to unban.