// Explicit durable document IDs. Never derive IDs from labels, say prefixes,
// runtime references or registry positions. Existing IDs are a save contract.
// Curated ordinary Earth/human language definitions; animal/fantasy/Binary and
// speech-only sign/nonverbal/innate/hivemind forms have no admitted written form.
/proc/paper_written_language_types()
	return list(\
		"civ13:portuguese:v1" = /datum/language/portuguese, \
		"civ13:spanish:v1" = /datum/language/spanish, \
		"civ13:english:v1" = /datum/language/english, \
		"civ13:french:v1" = /datum/language/french, \
		"civ13:dutch:v1" = /datum/language/dutch, \
		"civ13:afrikaans:v1" = /datum/language/afrikaans, \
		"civ13:carib:v1" = /datum/language/carib, \
		"civ13:greek:v1" = /datum/language/greek, \
		"civ13:latin:v1" = /datum/language/latin, \
		"civ13:arab:v1" = /datum/language/arab, \
		"civ13:dari:v1" = /datum/language/dari, \
		"civ13:tajik:v1" = /datum/language/tajik, \
		"civ13:farsi:v1" = /datum/language/farsi, \
		"civ13:pashto:v1" = /datum/language/pashto, \
		"civ13:kazakh:v1" = /datum/language/kazakh, \
		"civ13:kyrgyz:v1" = /datum/language/kyrgyz, \
		"civ13:turkmen:v1" = /datum/language/turkmen, \
		"civ13:uzbek:v1" = /datum/language/uzbek, \
		"civ13:uyghur:v1" = /datum/language/uyghur, \
		"civ13:chechen:v1" = /datum/language/chechen, \
		"civ13:hebrew:v1" = /datum/language/hebrew, \
		"civ13:japanese:v1" = /datum/language/japanese, \
		"civ13:ainu:v1" = /datum/language/ainu, \
		"civ13:mongolian:v1" = /datum/language/mongolian, \
		"civ13:russian:v1" = /datum/language/russian, \
		"civ13:ukrainian:v1" = /datum/language/ukrainian, \
		"civ13:polish:v1" = /datum/language/polish, \
		"civ13:chinese:v1" = /datum/language/chinese, \
		"civ13:german:v1" = /datum/language/german, \
		"civ13:zulu:v1" = /datum/language/zulu, \
		"civ13:swahili:v1" = /datum/language/swahili, \
		"civ13:armenian:v1" = /datum/language/armenian, \
		"civ13:vietnamese:v1" = /datum/language/vietnamese, \
		"civ13:scottishgaelic:v1" = /datum/language/scottishgaelic, \
		"civ13:italian:v1" = /datum/language/italian, \
		"civ13:inuit:v1" = /datum/language/inuit, \
		"civ13:cherokee:v1" = /datum/language/cherokee, \
		"civ13:oldnorse:v1" = /datum/language/oldnorse, \
		"civ13:finnish:v1" = /datum/language/finnish, \
		"civ13:norwegian:v1" = /datum/language/norwegian, \
		"civ13:swedish:v1" = /datum/language/swedish, \
		"civ13:danish:v1" = /datum/language/danish, \
		"civ13:egyptian:v1" = /datum/language/egyptian, \
		"civ13:korean:v1" = /datum/language/korean, \
		"civ13:iroquois:v1" = /datum/language/iroquois, \
		"civ13:sioux:v1" = /datum/language/sioux, \
		"civ13:apache:v1" = /datum/language/apache, \
		"civ13:navajo:v1" = /datum/language/navajo, \
		"civ13:chinook:v1" = /datum/language/chinook, \
		"civ13:comanche:v1" = /datum/language/comanche, \
		"civ13:mayan:v1" = /datum/language/mayan, \
		"civ13:aztec:v1" = /datum/language/aztec, \
		"civ13:hawaiian:v1" = /datum/language/hawaiian, \
		"civ13:filipino:v1" = /datum/language/filipino, \
		"civ13:welsh:v1" = /datum/language/welsh, \
		"civ13:scots:v1" = /datum/language/scots, \
		"civ13:gaelic:v1" = /datum/language/gaelic, \
		"civ13:redmenian:v1" = /datum/language/redmenian, \
		"civ13:blugoslavian:v1" = /datum/language/blugoslavian, \
		"civ13:greenistani:v1" = /datum/language/greenistani)

/proc/paper_written_language(language_id)
	if (!istext(language_id))
		return null
	var/list/types = paper_written_language_types()
	var/language_type = types[language_id]
	if (!language_type)
		return null
	for (var/name in all_languages)
		var/datum/language/L = all_languages[name]
		if (L.type == language_type && !(L.flags & (INNATE | SIGNLANG | NONVERBAL | HIVEMIND)))
			return L
	return null

// Writing knowledge is independent of voice/mute/silent status. Membership is
// required: neither dead/admin status nor universal understanding grants text.
/proc/paper_knows_written_language(mob/actor, language_id)
	var/datum/language/L = paper_written_language(language_id)
	if (!actor || !L)
		return FALSE
	// Rebind to the actor's real member after import; singleton object identity
	// is not a durable language ID. No knowledge is inferred from client labels.
	for (var/datum/language/known in actor.languages)
		if (known.type == L.type && actor.can_speak(known))
			return TRUE
	return FALSE

/proc/paper_written_language_choices(mob/actor)
	var/list/choices = list()
	var/list/types = paper_written_language_types()
	for (var/id in types)
		if (paper_knows_written_language(actor, id))
			var/datum/language/L = paper_written_language(id)
			choices += list(list("id" = id, "name" = L.name))
	return choices

/proc/paper_written_default_language(mob/actor)
	var/mob/living/L = actor
	if (!istype(L) || !L.default_language)
		return null
	var/list/types = paper_written_language_types()
	for (var/id in types)
		if (types[id] == L.default_language.type && paper_knows_written_language(actor, id))
			return id
	return null
