// Chat filter types. The browser chat files a message under a filter tab by the
// first chattype-<kind> class it contains; untagged messages are sorted by
// their existing classes (see interface/chat/chat.html).
#define CHAT_IC		"ic"
#define CHAT_RADIO	"radio"
#define CHAT_OOC	"ooc"
#define CHAT_DEAD	"dead"
#define CHAT_ADMIN	"admin"
#define CHAT_PM		"pm"
#define CHAT_WARNING	"warning"
#define CHAT_OTHER	"other"
#define CHAT_TYPED(kind, message) ("<span class='chattype-" + kind + "'>" + "[message]" + "</span>")
