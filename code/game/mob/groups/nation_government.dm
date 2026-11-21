// Nation governments (docs/nation-government.md). A nation picks a system of
// government; the coordinator keeps it in the nation registry
// (tools/transfer_storage/nations.py, GOVERNMENTS) and every world reads it
// with the rest of the registry. Confederation is the default and is today's
// rules. Member factions keep their own leaders, offices and courts whatever
// the nation's government.
//
// From here a member faction's leader proposes or votes for a change (two
// thirds of the member factions carry it), and under a personal rule
// (theocracy, monarchy, dictatorship) the ruler decides alone, admits new
// members and chooses the common money. A change takes effect a day after it
// passes, at most once a week. The person who heads a nation must be a citizen
// with a Discord-verified account (account_verified()).
//
// Nothing here sleeps except the prompts, which recheck after.

#define GOVERNMENT_TYPES list("confederation", "theocracy", "monarchy", "dictatorship", "republic", "democracy", "league")

// Type -> name, ruler title, earliest ordinal age, extra factions, notice
// hours and what the type means for players. Mirrors GOVERNMENTS in
// nations.py, which decides; this is only for the prompts.
var/global/list/nation_government_info = list(
	"confederation" = list("Confederation", null, 0, 0, 0, "The member factions rule together: one vote each, a symbolic head, and any member may leave at once."),
	"theocracy" = list("Theocracy", "High Priest", 0, 0, 24, "The leader of a faith rules the nation alone. Members give a day's notice to leave."),
	"monarchy" = list("Monarchy", "Monarch", 1, 1, 48, "A monarch rules for life, admits new members and holds one more faction. Members give two days' notice to leave."),
	"dictatorship" = list("Dictatorship", "Dictator", 1, 2, 72, "A dictator rules alone and holds two more factions, but if the dictator's faction leaves, the nation falls back to a confederation. Members give three days' notice to leave."),
	"republic" = list("Republic", "Consul", 1, 1, 24, "A consul leads; the member factions still vote on admissions, money and changes. Holds one more faction."),
	"democracy" = list("Democracy", "Archon", 1, 0, 24, "An archon leads; the member factions still vote on admissions, money and changes."),
	"league" = list("Merchant league", "Doge", 2, 1, 24, "A doge leads a league of trading factions. Holds one more faction."))

/proc/nation_government_of(nid)
	var/list/N = nation_registry[nid]
	if (!islist(N) || !islist(N["government"]) || !(N["government"]["type"] in GOVERNMENT_TYPES))
		return list("type" = "confederation", "name" = "Confederation", "personal" = FALSE)
	return N["government"]

/proc/nation_government_name(nid)
	var/list/G = nation_government_of(nid)
	return istext(G["name"]) ? G["name"] : "Confederation"

// The account of the person who heads the nation, when there is one.
/proc/nation_head_account(nid)
	var/list/G = nation_government_of(nid)
	return istext(G["head_account"]) ? G["head_account"] : null

/mob/living/human/proc/nation_account()
	return faction_roster_account(src) || ckey

// TRUE when this character is the nation's ruler acting from a member
// faction's own land (the only place a world may speak for it).
/mob/living/human/proc/nation_rules(nid)
	var/list/G = nation_government_of(nid)
	if (!G["personal"] || !nid || stat || !civilization || civilization == "none" || !nation_home_faction(civilization))
		return FALSE
	return G["head_account"] == nation_account() && nation_of_id(nation_faction_id(civilization)) == nid

// "The Monarchy of Union, ruled by Queen Val" style line for the views.
/proc/nation_government_line(nid)
	var/list/G = nation_government_of(nid)
	var/line = "Government: [html_encode(nation_government_name(nid))]"
	if (istext(G["ruler"]) && istext(G["head_name"]))
		line += ", [html_encode(G["ruler"])] [html_encode(G["head_name"])]"
	if (istext(G["religion"]))
		line += " of the [html_encode(G["religion"])]"
	var/list/P = G["pending"]
	if (islist(P) && istext(P["name"]))
		line += ". Becoming a [html_encode(lowertext(P["name"]))][istext(P["pname"]) && length(P["pname"]) ? " under [html_encode(P["pname"])]" : ""] within a day"
	return line + "."

// Tells this land's citizens when their nation's government is changing or
// has changed, comparing the registry before and after a read.
/proc/nation_government_announce(list/old_registry)
	for (var/nid in nation_registry)
		var/list/N = nation_registry[nid]
		var/list/was = islist(old_registry) ? old_registry[nid] : null
		if (!islist(was))
			continue
		var/list/G = nation_government_of(nid)
		var/list/OG = islist(was["government"]) ? was["government"] : list("type" = "confederation")
		var/text = null
		if (G["type"] != OG["type"] || G["head_account"] != OG["head_account"])
			text = "[N["name"]] is now a [lowertext(nation_government_name(nid))][istext(G["head_name"]) ? ", headed by [G["head_name"]]" : ""]."
		else if (islist(G["pending"]) && !islist(OG["pending"]))
			var/list/P = G["pending"]
			text = "[N["name"]] will become a [lowertext(P["name"])][istext(P["pname"]) && length(P["pname"]) ? " under [P["pname"]]" : ""] within a day."
		if (!text)
			continue
		for (var/mob/living/human/H in player_list)
			if (H.client && H.civilization && H.civilization != "none" && nation_of_id(nation_faction_id(H.civilization)) == nid)
				to_chat(H, "<big><b>Nation:</b> [html_encode(text)]</big>")

// Tells the coordinator the ordinal age of this land for every member faction
// founded here whose recorded age differs. Sleeps.
/proc/nation_eras_report()
	if (!map)
		return
	var/prefix = "civ:[shard_group.region]:"
	for (var/nid in nation_registry)
		var/list/N = nation_registry[nid]
		var/list/known = islist(N["eras"]) ? N["eras"] : list()
		for (var/id in N["members"])
			if (!istext(id) || findtext(id, prefix) != 1 || nation_pending_for(id, "era"))
				continue
			if (!nation_home_faction(copytext(id, length(prefix) + 1)))
				continue
			if (map.ordinal_age != (isnum(known[id]) ? known[id] : 0))
				nation_send(list("op" = "era", "actor" = "world", "faction" = id, "age" = map.ordinal_age))

// --- The Government prompt -------------------------------------------------------

/mob/living/human/proc/nation_government_menu(faction, id, nid)
	var/list/N = nation_registry[nid]
	var/list/G = nation_government_of(nid)
	var/list/lines = list(nation_government_line(nid))
	var/list/votes = N["government_votes"]
	if (islist(votes) && votes.len)
		for (var/voter in votes)
			var/list/V = votes[voter]
			if (islist(V) && V.len == 5 && islist(nation_government_info[V[1]]))
				lines += "[nation_faction_label(voter)] votes for a [lowertext(nation_government_info[V[1]][1])][length(V[3]) ? " under [V[3]]" : ""]."
	var/is_ruler = nation_rules(nid)
	if (!G["personal"] && !nation_may_propose(nid))
		lines += G["body"] == "referendum" ? "Only citizens with a verified account who have been members for 3 days and played this week can propose a change." : "Only a member faction's leader can propose a change."
		to_chat(src, jointext(lines, "<br>"))
		return
	if (G["personal"] && !is_ruler)
		lines += "Only the [G["ruler"]] can change the government."
		to_chat(src, jointext(lines, "<br>"))
		return
	var/list/options = list()
	for (var/kind in GOVERNMENT_TYPES)
		var/list/I = nation_government_info[kind]
		options["[I[1]] ([ordinal_age_name(I[3])] or later)"] = kind
	var/pick = WWinput(src, "[jointext(lines, " ")] [nation_change_rule(nid)] Which government should the nation have?", "Nation Government", "Cancel", options + "Cancel")
	var/kind = options[pick]
	if (!kind)
		return
	var/list/I = nation_government_info[kind]
	if (WWinput(src, "[I[6]] [I[2] ? "It needs a [I[2]] who is a citizen with a verified account. " : ""]A change takes a day to take effect, and the nation can change at most once a week.", I[1], "Cancel", list("Propose it", "Cancel")) != "Propose it")
		return
	var/list/body = list("op" = "govern", "faction" = id, "type" = kind)
	if (I[2])
		var/mob/living/human/head = nation_government_pick_head(nid, kind, I[2])
		if (!head)
			return
		body["person"] = head.nation_account()
		body["pname"] = copytext(head.real_name, 1, 65)
		body["pfaction"] = nation_faction_id(head.civilization)
		if (kind == "theocracy")
			body["religion"] = copytext(head.religion, 1, 41)
	if (civilization != faction || nation_of_id(id) != nid || !nation_may_propose(nid))
		return
	nation_ask(body, faction)

// A citizen nearby or anywhere in this land to head the nation: online, a
// member of a member faction, with a verified account; for a theocracy, the
// leader of a faith. Sleeps (prompt).
/mob/living/human/proc/nation_government_pick_head(nid, kind, title)
	var/list/candidates = list()
	for (var/mob/living/human/H in player_list)
		if (!H.client || H.stat == DEAD || !H.civilization || H.civilization == "none")
			continue
		if (nation_of_id(nation_faction_id(H.civilization)) != nid || !account_verified(H.nation_account()))
			continue
		if (kind == "theocracy" && (!H.religious_leader || !istext(H.religion) || H.religion == "none"))
			continue
		candidates["[H.real_name] of [H.civilization][kind == "theocracy" ? ", leader of the [H.religion]" : ""]"] = H
	if (!candidates.len)
		to_chat(src, SPAN_WARNING(kind == "theocracy" ? "A theocracy needs the leader of a faith, a citizen with a verified account, playing in this land." : "The [title] must be a citizen with a verified account, playing in this land."))
		return null
	var/pick = WWinput(src, "Who should be [title]?", title, "Cancel", candidates + "Cancel")
	var/mob/living/human/H = candidates[pick]
	if (!H || !H.client || nation_of_id(nation_faction_id(H.civilization)) != nid)
		return null
	return H

// How a change of government passes under the nation's government, for prompts.
/proc/nation_change_rule(nid)
	var/list/G = nation_government_of(nid)
	if (G["personal"])
		return "As ruler you decide alone."
	switch (G["body"])
		if ("senate")
			return "The senate decides: each member faction's leader votes with the weight of its active citizens, and two thirds must agree."
		if ("referendum")
			return "The citizens decide by referendum: two thirds must agree and half of them must vote."
		if ("council")
			return "The league council decides: each member faction's leader votes with the weight of its strongbox, and two thirds must agree."
	return "Two thirds of the member factions must agree."

// --- Citizens and the census (elective governments) -------------------------------

#define CITIZEN_MEMBER_DAYS 3
#define CITIZEN_SEEN_DAYS 7

// Whether the account counts as an eligible citizen of the faction: a
// verified account on its roster for CITIZEN_MEMBER_DAYS that has played a
// member in the last CITIZEN_SEEN_DAYS.
/proc/nation_citizen_eligible(faction, account)
	if (!map || !istext(account) || !account_verified(account))
		return FALSE
	var/list/row = map.faction_roster(faction)[account]
	if (!islist(row) || row.len != 2 || !isnum(row[1]) || !isnum(row[2]))
		return FALSE
	return row[1] <= world.realtime - CITIZEN_MEMBER_DAYS * 864000 && row[2] >= world.realtime - CITIZEN_SEEN_DAYS * 864000

/proc/nation_citizen_count(faction)
	var/count = 0
	for (var/account in map.faction_roster(faction))
		if (nation_citizen_eligible(faction, account))
			count++
	return min(count, 1000)

/proc/nation_faction_wealth(faction)
	var/obj/structure/closet/crate/faction_strongbox/B = map.faction_strongbox(faction)
	return B ? clamp(round(B.coin_worth()), 0, 10000000) : 0

// Tells the coordinator each member faction of this land's eligible citizens
// and strongbox worth, when they differ from the registry. Sleeps.
/proc/nation_census_report()
	if (!map)
		return
	var/prefix = "civ:[shard_group.region]:"
	for (var/nid in nation_registry)
		var/list/N = nation_registry[nid]
		var/list/known = islist(N["census"]) ? N["census"] : list()
		for (var/id in N["members"])
			if (!istext(id) || findtext(id, prefix) != 1 || nation_pending_for(id, "census"))
				continue
			var/name = copytext(id, length(prefix) + 1)
			if (!nation_home_faction(name))
				continue
			var/citizens = nation_citizen_count(name)
			var/wealth = nation_faction_wealth(name)
			var/list/row = known[id]
			if (!islist(row) || row.len != 2 || row[1] != citizens || row[2] != wealth)
				nation_send(list("op" = "census", "actor" = "world", "faction" = id, "citizens" = citizens, "wealth" = wealth))

/mob/living/human/proc/nation_eligible()
	return nation_citizen_eligible(civilization, nation_account())

// Whether this character may propose a change of government or a common
// money: the ruler, a member faction's leader, or in a democracy any eligible
// citizen.
/mob/living/human/proc/nation_may_propose(nid)
	var/list/G = nation_government_of(nid)
	if (G["personal"])
		return nation_rules(nid)
	if (map.is_faction_leader(src, civilization))
		return TRUE
	return G["body"] == "referendum" && nation_eligible()

// --- Motions and elections -------------------------------------------------------

/proc/nation_motion_label(list/M)
	var/subject = M["subject"]
	switch (M["kind"])
		if ("admit")
			return "Admit [nation_faction_label(subject)]"
		if ("currency")
			return istext(subject) && length(subject) ? "Adopt the coin of [nation_faction_label(subject)]" : "Have no common money"
		if ("government")
			var/list/P = subject
			if (islist(P) && P.len == 5 && islist(nation_government_info[P[1]]))
				return "Become a [lowertext(nation_government_info[P[1]][1])][length(P[3]) ? " under [P[3]]" : ""]"
		if ("election")
			return "Elect the head of the nation"
	return "A motion"

/mob/living/human/proc/nation_motions_menu(faction, id, nid)
	var/list/N = nation_registry[nid]
	var/list/G = nation_government_of(nid)
	var/list/lines = list("<b>Motions and elections of [html_encode(N["name"])]</b>", nation_government_line(nid))
	if (isnum(N["term_ends"]))
		lines += "The [html_encode(G["ruler"])]'s term ends in [max(1, round((N["term_ends"] - world.realtime / 10 - 946684800) / 3600))] hours."
	var/eligible = nation_eligible()
	var/leader = map.is_faction_leader(src, faction)
	var/account = nation_account()
	var/list/options = list()
	for (var/list/M in N["motions"])
		if (!islist(M) || !isnum(M["id"]))
			continue
		var/label = nation_motion_label(M)
		var/voters = M["voters"]
		if (M["kind"] == "election")
			var/list/names = list()
			for (var/list/C in M["candidates"])
				names += "[html_encode(C["name"])] ([C["votes"]])"
			lines += "[label]: [names.len ? jointext(names, ", ") : "nobody has stood yet"]. Closes within a day of opening."
		else
			lines += "[label]: [M["yes"]] for, [M["no"]] against, of [M["possible"]]."
		var/can_vote = voters == "leader" ? leader : eligible
		if (can_vote)
			options["Vote: [label]"] = M
		if (M["kind"] == "election" && eligible)
			var/standing = FALSE
			for (var/list/C in M["candidates"])
				if (C["account"] == account)
					standing = TRUE
			if (!standing)
				options["Stand for election"] = M
	if (nation_may_propose(nid))
		options["Propose a common money"] = "currency"
		options["Propose a change of government"] = "government"
	if (!eligible)
		lines += "Citizens vote with a verified account after 3 days as members, if they have played this week."
	to_chat(src, jointext(lines, "<br>"))
	if (!options.len)
		return
	var/pick = WWinput(src, "What will you do?", "Motions and elections", "Cancel", options + "Cancel")
	var/choice = options[pick]
	if (!choice || civilization != faction || nation_of_id(id) != nid)
		return
	if (choice == "government")
		nation_government_menu(faction, id, nid)
		return
	if (choice == "currency")
		nation_currency_vote(faction, id, nid)
		return
	var/list/M = choice
	if (pick == "Stand for election")
		nation_ask(list("op" = "stand", "faction" = id, "pname" = copytext(real_name, 1, 65)), faction)
		return
	var/list/answers = list()
	if (M["kind"] == "election")
		for (var/list/C in M["candidates"])
			answers["[C["name"]] of [nation_faction_label(C["faction"])]"] = C["account"]
		if (!answers.len)
			to_chat(src, SPAN_NOTICE("Nobody has stood yet."))
			return
	else
		answers = list("For" = "yes", "Against" = "no")
	var/vote = WWinput(src, "[nation_motion_label(M)]: your vote?", "Vote", "Cancel", answers + "Cancel")
	if (!answers[vote] || civilization != faction || nation_of_id(id) != nid)
		return
	nation_ask(list("op" = "ballot", "faction" = id, "motion" = M["id"], "choice" = answers[vote]), faction)

#undef CITIZEN_MEMBER_DAYS
#undef CITIZEN_SEEN_DAYS

/mob/living/human/proc/nation_stay(faction, id, nid)
	if (WWinput(src, "Withdraw [faction]'s notice and stay in [nation_registry[nid]["name"]]?", "Stay", "Cancel", list("Stay", "Cancel")) != "Stay")
		return
	if (civilization != faction || nation_of_id(id) != nid)
		return
	nation_ask(list("op" = "stay", "faction" = id), faction)

#undef GOVERNMENT_TYPES
