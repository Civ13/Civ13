// Language proficiency.
//
// A human knows each language to a score from 0 to 100, kept in
// partial_languages as points out of the language's difficulty. A language
// given outright (a mother tongue, a job's language) is at 100. A learned one
// rises slowly: from hearing better speakers, from speaking to them, and from
// study. At LANGUAGE_BROKEN it joins the languages list and can be spoken; the
// share of words that comes through, heard or spoken, is the score, until
// LANGUAGE_FLUENT, where everything does.

/mob/proc/language_score(datum/language/L)
	if (universal_speak || universal_understand)
		return 100
	return knows_language(L) ? 100 : 0

/mob/living/human/language_score(datum/language/L)
	L = canonical_language(L)
	if (!L)
		return 0
	if (universal_speak || universal_understand)
		return 100
	var/score = L.difficulty > 0 ? min(100, partial_languages[L.name] * 100 / L.difficulty) : 0
	// In the list without the points to have earned it: it was given outright.
	if (score < LANGUAGE_BROKEN - 1 && knows_language(L))
		return 100
	return score

/proc/language_level_name(score)
	if (score >= LANGUAGE_FLUENT)
		return "Fluent"
	if (score >= LANGUAGE_CONVERSATIONAL)
		return "Conversational"
	if (score >= LANGUAGE_BROKEN)
		return "Broken"
	if (score >= 1)
		return "A few words"
	return "None"

// The language a character grew up with: their people's, else their default.
/mob/living/human/proc/mother_tongue()
	// Set when their people's language split off a daughter (daughter.dm).
	if (native_tongue)
		var/datum/language/N = canonical_language(all_languages[native_tongue])
		if (N)
			return N
	var/datum/origin/O = get_origin()
	if (O)
		var/datum/language/L = all_languages[O.language]
		if (L)
			return L
	return canonical_language(default_language)

// Saved with the character: how much each language has gained today.
/mob/living/human/var/language_gain_day = 0
/mob/living/human/var/list/language_gain_today = null
/mob/living/human/var/next_language_practice = -1

/proc/language_learnable(datum/language/L)
	return istype(L) && !(L.flags & (INNATE | NONVERBAL | SIGNLANG | HIVEMIND | NONGLOBAL))

// How much more of a language can be gained today. Each way of learning has
// its own allowance: TRUE for hearing and speaking, "lesson", "study".
/mob/living/human/proc/language_day_left(datum/language/L, daily_cap = TRUE)
	L = canonical_language(L)
	if (!L)
		return 0
	var/today = round(world.realtime / 864000)
	if (language_gain_day != today || !islist(language_gain_today))
		language_gain_day = today
		language_gain_today = list()
	var/limit = LANGUAGE_DAILY_CAP
	var/bucket = L.name
	if (daily_cap == "lesson")
		limit = LANGUAGE_LESSON_DAILY_CAP
		bucket = "lesson:[L.name]"
	else if (daily_cap == "study")
		limit = LANGUAGE_STUDY_DAILY_CAP
		bucket = "study:[L.name]"
	return max(0, limit - language_gain_today[bucket])

// Raise a language by up to `amount` score, never past `ceiling`. daily_cap
// names the allowance it draws on (FALSE for none); hearing and speaking are
// also slower once Conversational. Returns the score actually gained.
/mob/living/human/proc/gain_language(datum/language/L, amount, ceiling = 100, daily_cap = TRUE)
	L = canonical_language(L)
	if (!language_learnable(L) || amount <= 0)
		return 0
	var/score = language_score(L)
	ceiling = min(ceiling, 100)
	if (score >= ceiling)
		return 0
	if (daily_cap)
		if (daily_cap == TRUE && score >= LANGUAGE_CONVERSATIONAL)
			amount *= 0.5
		amount = min(amount, language_day_left(L, daily_cap), ceiling - score)
		if (amount <= 0)
			return 0
		var/bucket = istext(daily_cap) ? "[daily_cap]:[L.name]" : L.name
		language_gain_today[bucket] += amount
	amount = min(amount, ceiling - score)
	var/new_score = score + amount
	partial_languages[L.name] = new_score * L.difficulty / 100
	if (new_score >= LANGUAGE_BROKEN && !knows_language(L))
		if (add_language(L.name, FALSE, FALSE))
			add_note("Known Languages", L.name)
	var/level = language_level_name(new_score)
	if (level != language_level_name(score))
		switch (level)
			if ("A few words")
				to_chat(src, SPAN_NOTICE("You are starting to pick out a few words of <b>[L.name]</b>."))
			if ("Broken")
				to_chat(src, SPAN_NOTICE("You can now get by in broken <b>[L.name]</b>. You can speak it, though not every word will come out right."))
			if ("Conversational")
				to_chat(src, SPAN_NOTICE("You can now hold a conversation in <b>[L.name]</b>."))
			if ("Fluent")
				to_chat(src, SPAN_NOTICE("You are now fluent in <b>[L.name]</b>."))
	return amount

// Heard speech: the listener learns from anyone who speaks it better, and a
// learner who is understood by a better speaker gets practice.
/mob/living/human/proc/language_exposure(datum/language/L, mob/speaker)
	if (!language_learnable(L) || !speaker || speaker == src)
		return
	var/own = language_score(L)
	var/theirs = speaker.language_score(L)
	if (ishuman(speaker) && theirs < 100 && own > theirs)
		var/mob/living/human/learner = speaker
		if (world.time >= learner.next_language_practice)
			learner.next_language_practice = world.time + LANGUAGE_LEARN_COOLDOWN
			learner.gain_language(L, LANGUAGE_PRACTICE_GAIN)
	if (own >= 100 || theirs <= own || world.time < next_language_learn)
		return
	next_language_learn = world.time + LANGUAGE_LEARN_COOLDOWN
	gain_language(L, LANGUAGE_HEAR_GAIN)

// A word in the speaker's own tongue, about as long as the one it replaces.
/datum/language/proc/stand_in_word(length_wanted)
	if (!syllables || !syllables.len)
		return "..."
	var/word = ""
	while (length(word) < length_wanted)
		word += pick(syllables)
	if (copytext(word, 1, 2) == "'")
		word = copytext(word, 2)
	return word

// Speaking a language you only half know: each word comes out right with a
// chance equal to your score, otherwise it comes out in your mother tongue.
/mob/living/human/proc/garble_own_speech(message, datum/language/L)
	if (!message || !language_learnable(L))
		return message
	var/score = language_score(L)
	if (score >= LANGUAGE_FLUENT)
		return message
	var/datum/language/own = mother_tongue()
	if (own == canonical_language(L))
		own = null
	var/list/words = splittext(message, " ")
	for (var/i in 1 to words.len)
		var/word = words[i]
		if (!length(word) || prob(score))
			continue
		var/ending = copytext(word, length(word))
		var/stand_in = own ? own.stand_in_word(length(word)) : "..."
		if (ending in list("!", "?", ".", ","))
			stand_in += ending
		words[i] = stand_in
	return jointext(words, " ")

// ", Old Norse accent" for speech in a language that is not the speaker's
// mother tongue, until they are fluent in it.
/mob/living/human/proc/language_accent(datum/language/L)
	L = canonical_language(L)
	if (!language_learnable(L) || language_score(L) >= LANGUAGE_FLUENT)
		return ""
	var/datum/language/own = mother_tongue()
	if (!own || own == L)
		return ""
	return ", [own.name] accent"

// Related languages help each other equally: take the stronger of the two
// listed values for every pair, so the table cannot disagree with itself.
/proc/symmetrize_language_kinship()
	var/list/by_type = list()
	for (var/lname in all_languages)
		var/datum/language/L = all_languages[lname]
		by_type[L.type] = L
	for (var/lname in all_languages)
		var/datum/language/L = all_languages[lname]
		for (var/other_type in L.mutual_intelligibility)
			var/datum/language/other = by_type[other_type]
			if (!other || other == L)
				continue
			var/shared = max(L.mutual_intelligibility[other_type], other.mutual_intelligibility[L.type])
			L.mutual_intelligibility[other_type] = shared
			other.mutual_intelligibility[L.type] = shared
