#define PORTUGUESE_SYLLABLES list("ad", "al", "am", "an", "ar", "as", "ca", "co", "da", "de", "do", "el", "em", "en", "er", "es", "in", "le", "ma", "me", "nt", "om", "or", "os", "pa", "po", "qu", "ra", "re", "ri", "sa", "se", "st", "ta", "te", "ti", "to", "ue", "um", "ve", "ão", "ra", "en", "de", "ar", "es", "er", "nt", "te", "do", "os", "as", "co", "qu", "se", "re", "ta", "ma", "to", "me", "pa", "el", "or", "ue", "em", "da", "ão", "an", "ad", "in", "st", "po", "um", "al", "ve", "ri", "am", "om", "sa", "le", "ca", "ti", "ada", "ado", "ame", "and", "ant", "ara", "com", "con", "dos", "ela", "ele", "ent", "era", "eri", "est", "ida", "inh", "ito", "mas", "men", "ndo", "nha", "nte", "nto", "não", "ocê", "par", "per", "por", "qua", "que", "res", "ria", "seu", "sta", "tos", "uma", "ver", "voc", "ent", "que", "nte", "par", "ara", "men", "com", "est", "ado", "ele", "não", "uma", "era", "voc", "sta", "nto", "ant", "ocê", "con", "ver", "ria", "seu", "nha", "ame", "por", "inh", "per", "mas", "tos", "ela", "ada", "res", "eri", "dos", "and", "qua", "ito", "ndo", "ida")
#define FRENCH_SYLLABLES list( "ai", "an", "ar", "au", "ce", "ch", "co", "de", "em", "en", "er", "es", "et", "eu", "ie", "il", "in", "is", "it", "la", "le", "ma", "me", "ne", "ns", "nt", "on", "ou", "pa", "qu", "ra", "re", "se", "te", "ti", "tr", "ue", "un", "ur", "us", "ve", "le", "en", "es", "de", "re", "ai", "ou", "nt", "on", "er", "ur", "it", "an", "te", "et", "me", "la", "is", "qu", "se", "il", "ue", "us", "eu", "co", "ra", "ne", "in", "ve", "pa", "ma", "au", "ar", "ns", "ch", "ie", "ti", "tr", "ce", "em", "un", "ain", "ais", "ait", "ans", "ant", "ati", "ava", "ave", "cha", "che", "com", "con", "dan", "des", "ell", "eme", "ent", "est", "eur", "eux", "fai", "ien", "ion", "ire", "les", "lle", "lus", "mai", "men", "mme", "nte", "omm", "ont", "our", "ous", "out", "ouv", "par", "pas", "plu", "pou", "que", "res", "son", "sur", "tai", "tio", "tou", "tre", "une", "ure", "ver", "vou", "éta", "ent", "que", "ait", "les", "our", "lle", "men", "ais", "tre", "est", "par", "ous", "mai", "ion", "ant", "eme", "tai", "ans", "pas", "ell", "vou", "tou", "pou", "res", "ont", "eur", "dan", "une", "éta", "sur", "ien", "son", "mme", "tio", "des", "ire", "ver", "omm", "com", "con", "che", "ave", "ain", "ure", "out", "plu", "cha", "eux", "ava", "ouv", "nte", "lus", "fai", "ati")
#define SPANISH_SYLLABLES list ("ad", "al", "an", "ar", "as", "ci", "co", "de", "do", "el", "en", "er", "es", "ie", "in", "la", "lo", "me", "na", "no", "nt", "on", "or", "os", "pa", "qu", "ra", "re", "ro", "se", "st", "ta", "te", "to", "ue", "un", "en", "de", "er", "es", "ue", "la", "ra", "os", "nt", "te", "ar", "qu", "el", "ta", "do", "co", "re", "as", "on", "an", "to", "lo", "st", "un", "or", "ad", "ie", "se", "ci", "al", "pa", "na", "ro", "no", "me", "in", "aci", "ada", "ado", "ant", "ara", "ció", "com", "con", "des", "dos", "ent", "era", "ero", "est", "ido", "ien", "ier", "ión", "las", "los", "men", "nte", "nto", "par", "per", "por", "que", "res", "sta", "ste", "ten", "tra", "una", "ver", "que", "ent", "nte", "con", "est", "ado", "par", "los", "era", "ien", "men", "per", "sta", "ara", "una", "por", "ión", "tra", "ant", "nto", "ero", "ció", "aci", "las", "com", "ste", "res", "ten", "ier", "ver", "dos", "des", "ido", "ada")
#define ENGLISH_SYLLABLES list("ing", "ti", "po", "tle", "fa", "li", "ern", "er", "ri", "sion", "day", "fe", "lo", "eve", "a", "be", "vi", "ny", "gen", "men", "ly", "per", "el", "pen", "min", "ies", "ed", "to", "est", "pre", "land", "i", "pro", "la", "tive", "light", "es", "lar", "car", "out", "main", "re", "ad", "pa", "of", "tion", "ar", "ture", "mo", "pos", "ro", "in", "ers", "for", "an", "tain", "my", "e", "ment", "is", "side", "nal", "con", "ings", "ness", "y", "tions", "pe", "se", "ning", "ments", "ties", "so", "tor", "set", "ward" , "ence", "up")

/datum/language/portuguese
	name = "Portuguese"
	desc = "Muito bom."
	key = "p"
	colour = "Portuguese"
	flags = RESTRICTED | COMMON_VERBS
	syllables = PORTUGUESE_SYLLABLES
	mutual_intelligibility = list(/datum/language/spanish = 75,
		/datum/language/french = 35)

/datum/language/spanish
	name = "Spanish"
	desc = "Muy bueno."
	key = "s"
	colour = "Spanish"
	flags = RESTRICTED | COMMON_VERBS
	syllables = SPANISH_SYLLABLES
	mutual_intelligibility = list(/datum/language/portuguese = 50,
		/datum/language/french = 35)

/datum/language/english
	name = "English"
	desc = "Very good."
	key = "e"
	colour = "English"
	flags = RESTRICTED | COMMON_VERBS
	syllables = ENGLISH_SYLLABLES
	mutual_intelligibility = list(/datum/language/french = 10)

/datum/language/french
	name = "Japanese"
	desc = "Trés bien."
	key = "f"
	colour = "French"
	flags = RESTRICTED | COMMON_VERBS
	syllables = FRENCH_SYLLABLES
	mutual_intelligibility = list(/datum/language/english = 10,
		/datum/language/spanish = 25,
		/datum/language/portuguese = 10)