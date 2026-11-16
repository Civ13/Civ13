// Treaties (docs/faction-treaties.md). Anyone with a faction's diplomacy power
// (the leader, an office given it, or the bearer of such an office's seal,
// faction_offices.dm) drafts a treaty with other factions of this land: a
// title, its terms and the parties. The drafting faction signs at once; every
// other party's diplomacy power signs or refuses it through the Faction
// Treaties verb. When every party has signed, the treaty is in force and each
// party hears of it. A party may later renounce it; the register keeps every
// treaty, who signed, and who broke it and why, for anyone to read. Sealed
// copies can be written out on blank paper. The game enforces no treaty:
// players do, using the record.
//
// State in map.faction_recruitment["treaties"] (durable; party names follow a
// faction rename):
//   list("seq" = last id, "treaties" = list(id text -> list(
//       "title", "terms", "drafted by" (faction), "parties" = list(faction -> list(signer, time) or 0),
//       "status" ("draft", "in force", "refused", "renounced"), "made" (time), "history" = list(text))))
// Nothing sleeps except the prompts, which recheck after.

#define TREATY_TITLE_MAX 60
#define TREATY_TERMS_MAX 600
#define TREATY_PARTIES_MAX 6
#define TREATIES_MAX 60

var/global/list/treaty_statuses = list("draft", "in force", "refused", "renounced")

// --- State -------------------------------------------------------------------

/obj/map_metadata/proc/treaty_state()
	var/list/S = recruitment_state()
	var/list/R = S["treaties"]
	if (!islist(R))
		R = list()
		S["treaties"] = R
	if (!isnum(R["seq"]) || R["seq"] < 0 || R["seq"] != round(R["seq"]))
		R["seq"] = 0
	if (!islist(R["treaties"]))
		R["treaties"] = list()
	return R

/obj/map_metadata/proc/treaty_list()
	var/list/R = treaty_state()
	return R["treaties"]

/proc/treaty_valid(list/T)
	if (!islist(T) || !istext(T["title"]) || !istext(T["terms"]) || !istext(T["drafted by"]) || !islist(T["parties"]) || !(T["status"] in treaty_statuses) || !isnum(T["made"]) || !islist(T["history"]))
		return FALSE
	var/list/parties = T["parties"]
	if (parties.len < 2 || !(T["drafted by"] in parties))
		return FALSE
	for (var/faction in parties)
		var/list/sign = parties[faction]
		if (!istext(faction) || (sign != 0 && (!islist(sign) || sign.len != 2 || !istext(sign[1]) || !isnum(sign[2]))))
			return FALSE
	return TRUE

/obj/map_metadata/proc/treaty_normalize()
	var/list/treaties = treaty_list()
	for (var/id in treaties.Copy())
		if (!istext(id) || !treaty_valid(treaties[id]))
			treaties -= id

/obj/map_metadata/proc/treaty_rename(old_name, new_name)
	var/list/treaties = treaty_list()
	for (var/id in treaties)
		var/list/T = treaties[id]
		if (!islist(T))
			continue
		if (islist(T["parties"]))
			faction_rename_assoc_key(T["parties"], old_name, new_name)
		if (T["drafted by"] == old_name)
			T["drafted by"] = new_name

/obj/map_metadata/proc/treaty_get(id)
	var/list/treaties = treaty_list()
	var/list/T = treaties[id]
	return treaty_valid(T) ? T : null

/obj/map_metadata/proc/treaty_note(list/T, text)
	var/list/history = T["history"]
	history += "[faction_seal_date(recruitment_now())]: [text]"
	while (history.len > 20)
		history.Cut(1, 2)

/proc/treaty_text_clean(value, max_length)
	if (!istext(value))
		return ""
	var/clean = sanitize(value, max_length + 1, FALSE)
	if (!istext(clean))
		return ""
	clean = trim(clean)
	return length(clean) <= max_length ? clean : ""

// Drafts a treaty and signs it for the drafting faction. Returns its id, or null.
/obj/map_metadata/proc/treaty_draft(faction, list/others, title, terms, signer)
	title = treaty_text_clean(title, TREATY_TITLE_MAX)
	terms = treaty_text_clean(terms, TREATY_TERMS_MAX)
	if (!length(title) || !length(terms) || !istext(faction) || !istext(signer) || !islist(others))
		return null
	var/list/parties = list()
	parties[faction] = list(signer, recruitment_now())
	for (var/other in others)
		if (istext(other) && other != faction && !(other in parties))
			parties[other] = 0
	if (parties.len < 2 || parties.len > TREATY_PARTIES_MAX)
		return null
	var/list/R = treaty_state()
	var/list/treaties = R["treaties"]
	if (treaties.len >= TREATIES_MAX)
		// The oldest ended treaty makes room; a draft or one in force never does.
		for (var/id in treaties)
			var/list/old = treaties[id]
			if (!treaty_valid(old) || (old["status"] in list("refused", "renounced")))
				treaties -= id
				break
		if (treaties.len >= TREATIES_MAX)
			return null
	R["seq"]++
	var/id = "[R["seq"]]"
	var/list/T = list("title" = title, "terms" = terms, "drafted by" = faction, "parties" = parties, "status" = "draft", "made" = recruitment_now(), "history" = list())
	treaties[id] = T
	treaty_note(T, "[signer] drafted it and signed for [faction].")
	return id

// Signs for faction. Returns TRUE when this signature put the treaty in force.
/obj/map_metadata/proc/treaty_sign(id, faction, signer)
	var/list/T = treaty_get(id)
	if (!T || T["status"] != "draft" || !(faction in T["parties"]) || T["parties"][faction] != 0)
		return FALSE
	T["parties"][faction] = list(signer, recruitment_now())
	treaty_note(T, "[signer] signed for [faction].")
	for (var/party in T["parties"])
		if (T["parties"][party] == 0)
			return FALSE
	T["status"] = "in force"
	treaty_note(T, "In force.")
	return TRUE

/obj/map_metadata/proc/treaty_refuse(id, faction, who)
	var/list/T = treaty_get(id)
	if (!T || T["status"] != "draft" || !(faction in T["parties"]))
		return FALSE
	T["status"] = "refused"
	treaty_note(T, "[who] refused it for [faction].")
	return TRUE

/obj/map_metadata/proc/treaty_renounce(id, faction, who, reason)
	var/list/T = treaty_get(id)
	if (!T || T["status"] != "in force" || !(faction in T["parties"]))
		return FALSE
	T["status"] = "renounced"
	reason = treaty_text_clean(reason, TREATY_TITLE_MAX * 2)
	treaty_note(T, "[who] renounced it for [faction][length(reason) ? ": [reason]" : ""].")
	return TRUE

/obj/map_metadata/proc/treaty_announce(list/T, text)
	for (var/party in T["parties"])
		office_announce(party, text)

/proc/treaty_parties_text(list/T)
	var/list/names = list()
	for (var/party in T["parties"])
		names += party
	return english_list(names)

/proc/treaty_text(id, list/T)
	var/list/lines = list("<b>Treaty [id]: [html_encode(T["title"])]</b> ([T["status"]])", "Between [html_encode(treaty_parties_text(T))].", html_encode(T["terms"]))
	for (var/party in T["parties"])
		var/list/sign = T["parties"][party]
		lines += islist(sign) ? "Signed for [html_encode(party)] by [html_encode(sign[1])], [faction_seal_date(sign[2])]." : "Not yet signed for [html_encode(party)]."
	for (var/line in T["history"])
		lines += "<i>[html_encode(line)]</i>"
	return jointext(lines, "<br>")

// --- Faction Treaties verb ------------------------------------------------------------

/mob/living/human/proc/faction_treaties()
	set name = "Faction Treaties"
	set category = "Faction"
	if (!map)
		return
	var/faction = civilization
	var/member = faction && faction != "none" && (faction in map.custom_civs)
	var/envoy = member && map.faction_power(src, faction, "diplomacy")
	var/list/choices = list("Read the treaties")
	if (envoy)
		choices += list("Draft a treaty", "Sign or refuse a treaty", "Renounce a treaty", "Write out a copy")
	choices += "Cancel"
	var/choice = WWinput(src, "The treaties of this land", "Treaties", "Read the treaties", choices)
	if (!choice || choice == "Cancel" || !(choice in choices) || stat != CONSCIOUS)
		return
	if (choice == "Read the treaties")
		treaty_read()
		return
	if (civilization != faction || !map.faction_power(src, faction, "diplomacy"))
		return
	switch (choice)
		if ("Draft a treaty")
			treaty_draft_menu(faction)
		if ("Sign or refuse a treaty")
			var/list/options = treaty_options(faction, "draft", TRUE)
			if (!options.len)
				to_chat(src, SPAN_NOTICE("No draft treaty waits for [faction] to sign."))
				return
			var/pick = WWinput(src, "Which treaty?", "Sign a treaty", "Cancel", options + "Cancel")
			if (!pick || pick == "Cancel" || !(pick in options))
				return
			var/id = options[pick]
			var/list/T = map.treaty_get(id)
			if (!T)
				return
			to_chat(src, SPAN_NOTICE(treaty_text(id, T)))
			var/answer = WWinput(src, "Sign [T["title"]] for [faction]?", "Sign a treaty", "Cancel", list("Sign", "Refuse", "Cancel"))
			if (answer != "Sign" && answer != "Refuse")
				return
			if (civilization != faction || !map.faction_power(src, faction, "diplomacy"))
				return
			if (answer == "Refuse")
				if (map.treaty_refuse(id, faction, real_name))
					map.treaty_announce(T, "[faction] refuses the treaty [T["title"]].")
				return
			if (map.treaty_sign(id, faction, real_name))
				map.treaty_announce(T, "The treaty [T["title"]] between [treaty_parties_text(T)] is in force.")
			else if (T["status"] == "draft")
				map.treaty_announce(T, "[real_name] signs the treaty [T["title"]] for [faction].")
		if ("Renounce a treaty")
			var/list/options = treaty_options(faction, "in force", FALSE)
			if (!options.len)
				to_chat(src, SPAN_NOTICE("[faction] is party to no treaty in force."))
				return
			var/pick = WWinput(src, "Renounce which treaty? Every party hears of it, and the register keeps it.", "Renounce a treaty", "Cancel", options + "Cancel")
			if (!pick || pick == "Cancel" || !(pick in options))
				return
			var/reason = player_input(src, "Why (optional, up to [TREATY_TITLE_MAX * 2] letters)?", "Renounce a treaty", "", "text", null, TRUE)
			if (civilization != faction || !map.faction_power(src, faction, "diplomacy"))
				return
			var/list/T = map.treaty_get(options[pick])
			if (T && map.treaty_renounce(options[pick], faction, real_name, reason))
				map.treaty_announce(T, "[faction] renounces the treaty [T["title"]].")
		if ("Write out a copy")
			var/list/options = treaty_options(faction, null, FALSE)
			if (!options.len)
				to_chat(src, SPAN_NOTICE("[faction] is party to no treaty."))
				return
			var/pick = WWinput(src, "Write out which treaty?", "Copy a treaty", "Cancel", options + "Cancel")
			if (!pick || pick == "Cancel" || !(pick in options))
				return
			var/list/paper = bill_blank_supply(src)
			var/list/T = map.treaty_get(options[pick])
			if (!T || civilization != faction || !map.faction_power(src, faction, "diplomacy"))
				return
			if (!paper.len)
				to_chat(src, SPAN_WARNING("You need a blank sheet of paper in your hands or at your feet."))
				return
			var/obj/item/weapon/paper/P = paper[1]
			P.name = "treaty: [T["title"]]"
			P.info = treaty_text(options[pick], T)
			P.update_icon()
			to_chat(src, SPAN_NOTICE("You write out the treaty. Seal it to vouch for the copy."))

// "Treaty 3: Title (status)" -> id for faction's treaties; status null for any;
// unsigned_only for drafts faction has not signed yet.
/mob/living/human/proc/treaty_options(faction, status, unsigned_only)
	var/list/options = list()
	var/list/treaties = map.treaty_list()
	for (var/id in treaties)
		var/list/T = map.treaty_get(id)
		if (!T || !(faction in T["parties"]) || (status && T["status"] != status))
			continue
		if (unsigned_only && T["parties"][faction] != 0)
			continue
		options["Treaty [id]: [T["title"]] ([T["status"]])"] = id
	return options

/mob/living/human/proc/treaty_read()
	var/list/treaties = map.treaty_list()
	var/list/parts = list()
	for (var/id in treaties)
		var/list/T = map.treaty_get(id)
		if (T)
			parts += treaty_text(id, T)
	to_chat(src, SPAN_NOTICE(parts.len ? jointext(parts, "<hr>") : "No treaty has been made in this land."))

/mob/living/human/proc/treaty_draft_menu(faction)
	var/list/others = list()
	for (var/other in map.custom_civs)
		if (other != faction && other != "none")
			others += other
	if (!others.len)
		to_chat(src, SPAN_NOTICE("There is no other faction in this land to make a treaty with."))
		return
	var/list/parties = list()
	while (parties.len < TREATY_PARTIES_MAX - 1)
		var/list/left = others - parties
		if (!left.len)
			break
		var/pick = WWinput(src, parties.len ? "Parties so far: [english_list(parties)]. Add another?" : "Make a treaty with which faction?", "Draft a treaty", parties.len ? "Done" : "Cancel", left + (parties.len ? "Done" : "Cancel"))
		if (!pick || pick == "Cancel")
			return
		if (pick == "Done" || !(pick in left))
			break
		parties += pick
	if (!parties.len)
		return
	var/title = treaty_text_clean(player_input(src, "Title of the treaty (up to [TREATY_TITLE_MAX] letters):", "Draft a treaty", "", "text", null, TRUE), TREATY_TITLE_MAX)
	if (!length(title))
		return
	var/terms = treaty_text_clean(player_input(src, "The terms (up to [TREATY_TERMS_MAX] letters):", "Draft a treaty", "", "message", null, TRUE), TREATY_TERMS_MAX)
	if (!length(terms))
		to_chat(src, SPAN_WARNING("A treaty needs terms of at most [TREATY_TERMS_MAX] letters."))
		return
	if (civilization != faction || !map.faction_power(src, faction, "diplomacy"))
		return
	var/id = map.treaty_draft(faction, parties, title, terms, real_name)
	if (!id)
		to_chat(src, SPAN_WARNING("The register holds no more treaties in draft or in force."))
		return
	var/list/T = map.treaty_get(id)
	map.treaty_announce(T, "[faction] proposes a treaty, [title], to [treaty_parties_text(T)]. Use Faction Treaties to read and sign it.")
	log_game("[key_name(src)] drafted treaty [id] for [faction]: [title].")

#undef TREATY_TITLE_MAX
#undef TREATY_TERMS_MAX
#undef TREATY_PARTIES_MAX
#undef TREATIES_MAX
