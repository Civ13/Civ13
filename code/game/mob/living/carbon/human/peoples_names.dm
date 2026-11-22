// Name suggestions for a new people (docs/peoples.md). When a nation's people
// splits or blends, its leader picks the new name from words of the people's
// own tongue, each built from something the name means: the land they live
// in, a trait, or an elder of theirs. Every suggestion passes the same check
// as a typed name (people_name_problem, with the blocklist), and admins can
// still type a name with Force People Split or Rename People.

#define PEOPLE_NAME_SUGGESTIONS 3	// suggestions shown at once, one per meaning
#define PEOPLE_NAME_ROUNDS 5		// how many times a leader can ask for other suggestions

/mob/living/human/var/tmp/people_name_round = 0

// The tongue a split people will speak: what most of the nation's members of
// the parent people speak natively now (a daughter language counts).
/proc/people_split_tongue(nation, datum/origin/parent)
	var/list/tongues = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat == DEAD || H.civilization != nation || H.origin_id != parent.id)
			continue
		var/datum/language/L = H.mother_tongue()
		if (L)
			tongues[L.name] = (tongues[L.name] || 0) + 1
	. = parent.language
	for (var/lname in tongues)
		if (tongues[lname] > (tongues[.] || 0))
			. = lname

// The larger of a blend's two peoples in the nation, whose tongue the blend speaks.
/proc/people_blend_larger(nation, list/pair)
	var/list/result = people_nation_mix(nation)
	var/list/mix = result[1]
	return (mix[pair[2]] || 0) > (mix[pair[1]] || 0) ? pair[2] : pair[1]

// The tongue a waiting people would speak, or null.
/proc/people_pending_tongue(key)
	var/list/parts = people_community_parts(key)
	if (!parts)
		return null
	var/list/pair = people_blend_pair(parts[2])
	if (pair)
		var/datum/origin/L = origin_by_id(people_blend_larger(parts[1], pair))
		return L ? L.language : null
	var/datum/origin/parent = origin_by_id(parts[2])
	return parent ? people_split_tongue(parts[1], parent) : null

// What the land a nation lives in is called in a name, from the climate most
// of its members stand in.
/proc/people_place_meaning(nation)
	var/list/climates = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat == DEAD || H.civilization != nation)
			continue
		var/area/A = get_area(H)
		if (A && A.climate)
			climates[A.climate] = (climates[A.climate] || 0) + 1
	var/best = null
	for (var/climate in climates)
		if (!best || climates[climate] > climates[best])
			best = climate
	switch (best)
		if ("tundra")
			return "the people of the frost"
		if ("taiga")
			return "the people of the pine woods"
		if ("temperate")
			return "the people of the green valleys"
		if ("sea")
			return "the people of the shore"
		if ("semiarid")
			return "the people of the dry hills"
		if ("desert")
			return "the people of the sands"
		if ("savanna")
			return "the people of the tall grass"
		if ("jungle")
			return "the people of the deep forest"
	return "the people of the homeland"

/proc/people_trait_meaning(seed)
	switch (seed % 8)
		if (0)
			return "the steadfast"
		if (1)
			return "the far-walkers"
		if (2)
			return "the hearth-keepers"
		if (3)
			return "the watchful"
		if (4)
			return "the free"
		if (5)
			return "the patient"
		if (6)
			return "the dawn-risers"
	return "the open-handed"

// The eldest living member of the nation, whose children the people may call
// themselves. Only the first name is used.
/proc/people_ancestor_meaning(nation)
	var/mob/living/human/eldest = null
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat == DEAD || H.civilization != nation || !H.real_name)
			continue
		if (!eldest || H.age > eldest.age)
			eldest = H
	if (!eldest)
		return null
	var/first = eldest.real_name
	var/space = findtext(first, " ")
	if (space > 1)
		first = copytext(first, 1, space)
	return "the children of [first]"

// The meanings a waiting people's name can carry, in the order they are offered.
/proc/people_name_meanings(key)
	var/list/parts = people_community_parts(key)
	if (!parts)
		return list()
	. = list(people_place_meaning(parts[1]), people_trait_meaning(language_name_seed(key)))
	var/ancestor = people_ancestor_meaning(parts[1])
	if (ancestor)
		. += ancestor

// One word of a tongue for a meaning: two or three of its syllables, chosen by
// the meaning, so the same meaning always sounds alike in the same tongue.
/proc/people_word(language_name, meaning, attempt = 0)
	var/datum/language/L = all_languages[language_name]
	if (!L || !islist(L.syllables))
		return null
	var/list/usable = list()
	for (var/syllable in L.syllables)
		var/letters = people_word_letters(syllable)
		if (length(letters) >= 2 && findtext(letters, regex("\[aeiouy\]")))
			usable += letters
	if (!usable.len)
		return null
	var/seed = language_name_seed("[language_name]|[meaning]|[attempt]")
	var/count = 2 + seed % 2
	var/word = ""
	for (var/i in 1 to count)
		seed = (seed * 1103 + 12345) % 65521
		word += usable[seed % usable.len + 1]
	if (length(word) > 12)
		word = copytext(word, 1, 13)
	if (length(word) < 4)
		return null
	return uppertext(copytext(word, 1, 2)) + copytext(word, 2)

// Only the plain letters of a syllable, lower case.
/proc/people_word_letters(text)
	. = ""
	text = lowertext("[text]")
	for (var/i in 1 to length(text))
		var/c = text2ascii(text, i)
		if (c >= 97 && c <= 122)
			. += ascii2text(c)

// Name suggestions for a waiting people: name = meaning. Every name passes
// people_name_problem. round asks for other words for the same meanings.
/proc/people_name_suggestions(key, round = 0)
	var/list/suggestions = list()
	var/tongue = people_pending_tongue(key)
	if (!tongue)
		return suggestions
	for (var/meaning in people_name_meanings(key))
		if (suggestions.len >= PEOPLE_NAME_SUGGESTIONS)
			break
		for (var/attempt in (round * 6) to (round * 6 + 5))
			var/word = people_word(tongue, meaning, attempt)
			if (word && !(word in suggestions) && !people_name_problem(word))
				suggestions[word] = meaning
				break
	return suggestions

// The leader picks a name for a waiting people from the suggestions, or asks
// for others. Returns list(name, meaning), or null if they stopped.
/mob/living/human/proc/choose_people_name(key, question)
	while (TRUE)
		var/list/suggestions = people_name_suggestions(key, people_name_round)
		var/list/choices = list()
		for (var/word in suggestions)
			choices["[word] - [suggestions[word]]"] = word
		var/other = "Suggest other names"
		if (people_name_round < PEOPLE_NAME_ROUNDS)
			choices[other] = other
		if (!suggestions.len)
			if (people_name_round >= PEOPLE_NAME_ROUNDS)
				to_chat(src, SPAN_WARNING("No more names can be found for your people. Please adminhelp so an admin can name them."))
				return null
			people_name_round++
			continue
		var/picked = player_input(src, "[question] Each name is a word of your people's own tongue, and its meaning is shown beside it. The name cannot be changed later.", "Name Our People", null, "anything", choices, TRUE)
		if (!picked)
			return null
		if (choices[picked] == other)
			people_name_round++
			continue
		var/word = choices[picked]
		return list(word, suggestions[word])

#undef PEOPLE_NAME_SUGGESTIONS
#undef PEOPLE_NAME_ROUNDS
