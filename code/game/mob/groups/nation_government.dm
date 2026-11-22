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

#define GOVERNMENT_TYPES list("confederation", "elders", "theocracy", "monarchy", "dictatorship", "republic", "democracy", "league", "feudal", "constitutional", "oneparty")

// Type -> name, ruler title, earliest ordinal age, extra factions, notice
// hours and what the type means for players. Mirrors GOVERNMENTS in
// nations.py, which decides; this is only for the prompts.
var/global/list/nation_government_info = nation_government_info_table()
/proc/nation_government_info_table()
	return list(
	"confederation" = list("Confederation", null, 0, 0, 0, "The member factions rule together: one vote each, a symbolic head, and any member may leave at once."),
	"theocracy" = list("Theocracy", "High Priest", 0, 0, 24, "The leader of a faith rules the nation alone. Members give a day's notice to leave."),
	"monarchy" = list("Monarchy", "Monarch", 1, 1, 48, "A monarch rules for life, admits new members and holds one more faction. Members give two days' notice to leave."),
	"dictatorship" = list("Dictatorship", "Dictator", 1, 2, 72, "A dictator rules alone and holds two more factions, but if the dictator's faction leaves, the nation falls back to a confederation. Members give three days' notice to leave."),
	"republic" = list("Republic", "Consul", 1, 1, 24, "A consul leads; the member factions still vote on admissions, money and changes. Holds one more faction."),
	"democracy" = list("Democracy", "Archon", 1, 0, 24, "An archon leads; the member factions still vote on admissions, money and changes."),
	"league" = list("Merchant league", "Doge", 2, 1, 24, "A doge leads a league of trading factions. Holds one more faction."),
	"elders" = list("Council of elders", "Eldest", 0, 0, 24, "The member factions' elders sit in council, weighted by their people, and choose an eldest to lead for two weeks. The eldest may be away a week before a new choice. Members give a day's notice to leave."),
	"feudal" = list("Feudal crown", "King", 2, 1, 48, "A king rules for life, names an heir and holds one more faction. The crown keeps up to eight vassal nations, which must serve four weeks before they may declare independence, but it is a little easier to overthrow. Members give two days' notice to leave."),
	"constitutional" = list("Constitutional monarchy", "Prime Minister", 4, 2, 24, "A parliament weighted by the people decides, and a prime minister leads for two weeks. Holds two more factions and is hard to overthrow, but the prime minister may be away only three days."),
	"oneparty" = list("One-party state", "Chairman", 7, 3, 72, "A chairman rules alone and holds three more factions, but a revolt needs only a quarter of the citizens to sign. If the chairman is away three days the seat goes empty until the factions choose again. Members give three days' notice to leave."))

// TRUE when the government's head names an heir and an empty seat can be claimed
// (HEREDITARY in nation_succession.py).
/proc/nation_hereditary(list/G)
	return islist(G) && (G["type"] in list("monarchy", "feudal"))

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
	if (G["personal"] && !istext(G["head_account"]))
		line += ", the seat empty"
	var/list/S = G["successor"]
	if (islist(S) && istext(S["name"]))
		line += " ([nation_hereditary(G) ? "heir" : "deputy"]: [html_encode(S["name"])])"
	var/list/P = G["pending"]
	if (islist(P) && istext(P["name"]))
		line += ". Becoming a [html_encode(lowertext(P["name"]))][istext(P["pname"]) && length(P["pname"]) ? " under [html_encode(P["pname"])]" : ""] within a day"
	var/list/N = nation_registry[nid]
	if (islist(N) && isnum(N["legitimacy"]) && G["type"] != "confederation")
		line += ". Legitimacy [N["legitimacy"]]/100"
	if (islist(N) && N["frozen"])
		line += ". Staff have paused changes to it for now"
	return line + "."

// Tells this land's citizens when their nation's government is changing or
// has changed, comparing the registry before and after a read.
/proc/nation_government_announce(list/old_registry)
	for (var/nid in nation_registry)
		var/list/N = nation_registry[nid]
		var/list/was = islist(old_registry) ? old_registry[nid] : null
		if (!islist(was))
			continue
		nation_revolt_announce(nid, was)
		nation_offices_announce(nid, was)
		nation_treaties_announce(nid, was)
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
		if ("treaty")
			var/list/T = subject
			if (islist(T) && T.len == 3)
				return nation_treaty_act_label(T)
		if ("office")
			var/list/O = subject
			if (islist(O) && O.len == 4)
				return "Confirm [O[3]] as [nation_office_title(O[1])]"
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

// --- Succession (nation_succession.py) ----------------------------------------

#define NATION_PRESENT_EVERY 36000 // a head's presence goes out at most hourly
#define NATION_FAITH_EVERY 6000
#define ASSEMBLY_HOLD_TIME 18000 // 30 minutes holding the assembly
#define ASSEMBLY_HOLD_RANGE 3
#define ASSEMBLY_HOLD_STEP 100

var/global/list/nation_present_sent = list() // nid -> world.time last sent
var/global/list/nation_faith_sent = list()
var/global/list/nation_assembly_holds = list() // nid -> list(holder, assembly, held deciseconds, "claim" or "revolt")

// TRUE when this character is the nation's head (any government with a
// person at its head) acting from a member faction's own land.
/mob/living/human/proc/nation_heads(nid)
	if (!nid || stat || !civilization || civilization == "none" || !nation_home_faction(civilization))
		return FALSE
	var/head = nation_head_account(nid)
	return head && head == nation_account() && nation_of_id(nation_faction_id(civilization)) == nid

// Tells the coordinator the head is playing here (so the seat does not pass
// on as if they were away), and in a theocracy who leads the state religion
// here. Sleeps.
/proc/nation_succession_report()
	for (var/nid in nation_registry)
		var/list/G = nation_government_of(nid)
		for (var/mob/living/human/H in player_list)
			if (!H.client || H.stat == DEAD || !H.civilization || !nation_home_faction(H.civilization))
				continue
			if (nation_of_id(nation_faction_id(H.civilization)) != nid)
				continue
			var/id = nation_faction_id(H.civilization)
			if (H.nation_heads(nid) && world.time - (nation_present_sent[nid] || -NATION_PRESENT_EVERY) >= NATION_PRESENT_EVERY)
				nation_present_sent[nid] = world.time
				nation_send(list("op" = "present", "actor" = H.nation_account(), "role" = "citizen", "faction" = id))
			if (G["type"] == "theocracy" && istext(G["religion"]) && H.religious_leader && H.religion == G["religion"] \
					&& H.nation_account() != G["head_account"] && account_verified(H.nation_account()) \
					&& world.time - (nation_faith_sent[nid] || -NATION_FAITH_EVERY) >= NATION_FAITH_EVERY)
				nation_faith_sent[nid] = world.time
				nation_send(list("op" = "faith", "actor" = H.nation_account(), "role" = "citizen", "faction" = id, \
					"pname" = copytext(H.real_name, 1, 65), "religion" = G["religion"]))

// The monarch names an heir; the consul names a deputy. Sleeps (prompts).
/mob/living/human/proc/nation_name_successor(faction, id, nid)
	var/list/G = nation_government_of(nid)
	var/what = nation_hereditary(G) ? "heir" : "deputy"
	var/list/S = G["successor"]
	var/current = islist(S) && istext(S["name"]) ? " Now: [S["name"]]." : ""
	to_chat(src, SPAN_NOTICE("[what == "heir" ? "Your heir takes the throne if you are away for [G["away"]] days." : "Your deputy acts for you if you are away for [G["away"]] days, while the citizens elect a new consul."][current]"))
	var/mob/living/human/H = nation_government_pick_head(nid, "monarchy", what)
	if (!H || H == src || civilization != faction || !nation_heads(nid))
		return
	nation_ask(list("op" = what, "faction" = id, "person" = H.nation_account(), "pname" = copytext(H.real_name, 1, 65), \
		"pfaction" = nation_faction_id(H.civilization)), faction)

// --- Holding the assembly: claiming an empty throne, leading a revolt -------------
//
// Both are held in play at a member faction's nation assembly for
// ASSEMBLY_HOLD_TIME. The count pauses while a citizen who opposes the hold
// stands within ASSEMBLY_HOLD_RANGE tiles: for a claim any other citizen, for
// a revolt any citizen who did not sign. A revolt also counts only in the
// land's defence window where the assembly stands in a province.

/obj/structure/faction_hall/nation_assembly/attack_hand(mob/living/human/user)
	if (ishuman(user) && faction && (user.throne_claim_offer(src) || user.revolt_hold_offer(src)))
		return
	return ..()

// The nation whose citizen this character is, when this assembly belongs to it
// and the character plays a member faction in its own land.
/mob/living/human/proc/assembly_nation(obj/structure/faction_hall/nation_assembly/A)
	var/nid = nation_of_id(nation_faction_id(A.faction))
	if (!nid || nation_of_id(nation_faction_id(civilization)) != nid || !nation_home_faction(civilization))
		return null
	return nid

/proc/nation_tell_citizens(nid, text, mob/except)
	for (var/mob/living/human/H in player_list)
		if (H != except && H.client && H.civilization && H.civilization != "none" && nation_of_id(nation_faction_id(H.civilization)) == nid)
			to_chat(H, "<big><b>Nation:</b> [html_encode(text)]</big>")

// Offers to claim an empty throne at this assembly. TRUE when it handled the click.
/mob/living/human/proc/throne_claim_offer(obj/structure/faction_hall/nation_assembly/A)
	var/nid = assembly_nation(A)
	if (!nid)
		return FALSE
	var/list/G = nation_government_of(nid)
	if (!nation_hereditary(G) || istext(G["head_account"]))
		return FALSE
	if (nation_hold_busy(nid))
		return TRUE
	if (!account_verified(nation_account()))
		to_chat(src, SPAN_WARNING("The throne of [nation_registry[nid]["name"]] is empty, but only a citizen with a verified account may claim it."))
		return TRUE
	if (WWinput(src, "The throne of [nation_registry[nid]["name"]] is empty. Claim it? You must hold this assembly for 30 minutes; the count pauses while another citizen stands within [ASSEMBLY_HOLD_RANGE] tiles.", "Claim the Throne", "Cancel", list("Claim it", "Cancel")) != "Claim it")
		return TRUE
	if (stat || get_dist(src, A) > 1 || nation_hold_busy(nid) || istext(nation_government_of(nid)["head_account"]))
		return TRUE
	visible_message(SPAN_DANGER("[src] claims the throne of [nation_registry[nid]["name"]]!"))
	nation_tell_citizens(nid, "[real_name] is claiming the empty throne at the assembly of [A.faction].", src)
	nation_hold_start(nid, "claim", A)
	return TRUE

// Offers a signer of a ready revolt petition to lead the revolt here. TRUE
// when it handled the click.
/mob/living/human/proc/revolt_hold_offer(obj/structure/faction_hall/nation_assembly/A)
	var/nid = assembly_nation(A)
	var/list/R = nid ? nation_revolt_of(nid) : null
	if (!R || !isnum(R["ripe"]) || !nation_revolt_signed(nid, nation_account()))
		return FALSE
	var/now = nation_unix_now()
	if (now < R["hold_from"])
		to_chat(src, SPAN_WARNING("Every citizen has been warned; the rebels may hold the assembly in [max(1, round((R["hold_from"] - now) / 3600))] hours."))
		return TRUE
	if (nation_hold_busy(nid))
		return TRUE
	if (!nation_revolt_window(A))
		to_chat(src, SPAN_WARNING("The assembly stands in a province: the rebels can hold it only in its defence window. [province_window_text(nation_assembly_province(A))]"))
		return TRUE
	if (WWinput(src, "Lead the revolt against the government of [nation_registry[nid]["name"]]? You must hold this assembly for 30 minutes; the count pauses while a citizen who did not sign stands within [ASSEMBLY_HOLD_RANGE] tiles.", "Lead the Revolt", "Cancel", list("Lead it", "Cancel")) != "Lead it")
		return TRUE
	if (stat || get_dist(src, A) > 1 || nation_hold_busy(nid) || !nation_revolt_of(nid))
		return TRUE
	visible_message(SPAN_DANGER("[src] raises the revolt against the government of [nation_registry[nid]["name"]]!"))
	nation_tell_citizens(nid, "Rebels are holding the assembly of [A.faction] to overthrow the government.", src)
	nation_hold_start(nid, "revolt", A)
	return TRUE

/mob/living/human/proc/nation_hold_busy(nid)
	var/list/C = nation_assembly_holds[nid]
	if (!islist(C))
		return FALSE
	to_chat(src, SPAN_WARNING("[C[1]] is already holding an assembly of the nation."))
	return TRUE

/mob/living/human/proc/nation_hold_start(nid, kind, obj/structure/faction_hall/nation_assembly/A)
	nation_assembly_holds[nid] = list(src, A, 0, kind)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(nation_hold_tick), nid), ASSEMBLY_HOLD_STEP)

// Whether the hold may go on, by kind.
/proc/nation_hold_valid(nid, kind, mob/living/human/holder)
	var/list/G = nation_government_of(nid)
	if (kind == "claim")
		return nation_hereditary(G) && !istext(G["head_account"])
	var/list/R = nation_revolt_of(nid)
	return R && isnum(R["ripe"]) && nation_unix_now() <= R["ends"] && nation_revolt_signed(nid, holder.nation_account())

// Whether this citizen at the assembly pauses the hold.
/proc/nation_hold_opposes(nid, kind, mob/living/human/H)
	return kind == "claim" || !nation_revolt_signed(nid, H.nation_account()) || nation_office_of(nid, H.nation_account()) == "marshal"

/proc/nation_hold_tick(nid)
	var/list/C = nation_assembly_holds[nid]
	if (!islist(C))
		return
	var/mob/living/human/holder = C[1]
	var/obj/structure/faction_hall/nation_assembly/A = C[2]
	var/kind = C[4]
	if (QDELETED(holder) || QDELETED(A) || holder.stat || !holder.client || get_dist(holder, A) > ASSEMBLY_HOLD_RANGE \
			|| nation_of_id(nation_faction_id(holder.civilization)) != nid || !nation_hold_valid(nid, kind, holder))
		nation_assembly_holds -= nid
		if (!QDELETED(holder))
			to_chat(holder, SPAN_WARNING(kind == "claim" ? "Your claim to the throne fails." : "You lose hold of the assembly; the revolt has not succeeded yet."))
		return
	var/contested = FALSE
	for (var/mob/living/human/H in range(ASSEMBLY_HOLD_RANGE, A))
		if (H != holder && H.client && !H.stat && nation_of_id(nation_faction_id(H.civilization)) == nid && nation_hold_opposes(nid, kind, H))
			contested = TRUE
			break
	if (kind == "revolt" && !nation_revolt_window(A))
		contested = TRUE
	if (!contested)
		C[3] += ASSEMBLY_HOLD_STEP
	if (C[3] >= ASSEMBLY_HOLD_TIME)
		nation_assembly_holds -= nid
		var/list/body = list("op" = kind == "claim" ? "claim" : "overthrow", "faction" = nation_faction_id(holder.civilization), "role" = "citizen")
		if (kind == "claim")
			body["pname"] = copytext(holder.real_name, 1, 65)
		holder.nation_ask(body, holder.civilization)
		return
	if (contested && C[3] % 600 == 0)
		to_chat(holder, SPAN_WARNING(kind == "revolt" && !nation_revolt_window(A) ? "The defence window has closed; the revolt waits for it." : "Another citizen stands at the assembly; your hold waits."))
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(nation_hold_tick), nid), ASSEMBLY_HOLD_STEP)

// --- Revolt petitions (nation_revolt.py) ---------------------------------------

/proc/nation_unix_now()
	return world.realtime / 10 + 946684800

// The nation's open revolt petition, or null.
/proc/nation_revolt_of(nid)
	var/list/N = nation_registry[nid]
	var/list/R = islist(N) ? N["revolt"] : null
	return islist(R) && istext(R["type"]) && islist(R["signers"]) ? R : null

/proc/nation_revolt_signed(nid, account)
	var/list/R = nation_revolt_of(nid)
	if (!R || !istext(account))
		return FALSE
	for (var/list/S in R["signers"])
		if (S["account"] == account)
			return TRUE
	return FALSE

/proc/nation_assembly_province(obj/structure/faction_hall/nation_assembly/A)
	var/datum/province_map/P = map ? map.province_map() : null
	return P && (!P.surface_z || A.z == P.surface_z) ? P.char_at(A.x, A.y) : null

// An assembly outside any province can be held at any hour.
/proc/nation_revolt_window(obj/structure/faction_hall/nation_assembly/A)
	var/c = nation_assembly_province(A)
	return !c || province_in_window(c)

/proc/nation_revolt_line(nid)
	var/list/R = nation_revolt_of(nid)
	if (!R)
		return null
	var/kind = islist(nation_government_info[R["type"]]) ? lowertext(nation_government_info[R["type"]][1]) : "new government"
	var/line = "A revolt petition calls for a [kind][istext(R["pname"]) && length(R["pname"]) ? " under [html_encode(R["pname"])]" : ""]"
	var/now = nation_unix_now()
	if (isnum(R["ripe"]))
		if (now < R["hold_from"])
			line += ". It has its signatures; the rebels may hold an assembly in [max(1, round((R["hold_from"] - now) / 3600))] hours"
		else
			line += ". It has its signatures; the rebels may hold an assembly for [max(1, round((R["ends"] - now) / 3600))] more hours"
	else
		line += ": [length(R["signers"])] of [R["needed"]] signatures, [max(1, round((R["ends"] - now) / 3600))] hours left"
	return line + "."

// The Revolt prompt: open a petition or sign one. Sleeps (prompts).
/mob/living/human/proc/nation_revolt_menu(faction, id, nid)
	var/list/R = nation_revolt_of(nid)
	var/list/lines = list("<b>Revolt in [html_encode(nation_registry[nid]["name"])]</b>", nation_government_line(nid))
	lines += "Citizens can overthrow their government: a petition needs the signatures of [nation_revolt_share(nid)] of the eligible citizens within 2 days (fewer the lower the government's legitimacy). Every citizen is then warned, and from a day later the signers have 3 days to hold a member faction's nation assembly for 30 minutes. Signing is not a crime in itself."
	var/account = nation_account()
	var/is_head = account == nation_head_account(nid)
	if (R)
		lines += nation_revolt_line(nid)
		if (nation_revolt_signed(nid, account))
			lines += "You have signed it."
	else
		var/list/N = nation_registry[nid]
		var/list/RS = N["revolt"]
		if (islist(RS) && isnum(RS["cooldown"]) && RS["cooldown"] > nation_unix_now())
			lines += "A revolt ended recently; the nation cannot be petitioned again for [max(1, round((RS["cooldown"] - nation_unix_now()) / 86400))] days."
	to_chat(src, jointext(lines, "<br>"))
	if (is_head)
		return
	if (!nation_eligible())
		to_chat(src, SPAN_WARNING("Only citizens with a verified account who have been members for 3 days and played this week can open or sign a petition."))
		return
	if (R)
		if (isnum(R["ripe"]) || nation_revolt_signed(nid, account))
			return
		if (WWinput(src, "Sign the petition?", "Revolt", "Cancel", list("Sign it", "Cancel")) != "Sign it")
			return
		if (stat || civilization != faction || nation_of_id(id) != nid)
			return
		nation_ask(list("op" = "sign", "faction" = id, "role" = "citizen", "sname" = copytext(real_name, 1, 65)), faction)
		return
	var/list/options = list()
	for (var/kind in GOVERNMENT_TYPES)
		options["[nation_government_info[kind][1]]: [nation_government_info[kind][6]]"] = kind
	var/pick = WWinput(src, "Open a petition to overthrow the government. Which government should replace it?", "Revolt", "Cancel", options + "Cancel")
	var/kind = options[pick]
	if (!kind)
		return
	var/list/body = list("op" = "revolt", "faction" = id, "role" = "citizen", "type" = kind, "sname" = copytext(real_name, 1, 65))
	if (kind != "confederation")
		var/title = nation_government_info[kind][2]
		var/mob/living/human/H = nation_government_pick_head(nid, kind, title)
		if (!H)
			return
		body["person"] = H.nation_account()
		body["pname"] = copytext(H.real_name, 1, 65)
		body["pfaction"] = nation_faction_id(H.civilization)
		if (kind == "theocracy")
			body["religion"] = copytext(H.religion, 1, 41)
	if (stat || civilization != faction || nation_of_id(id) != nid || nation_revolt_of(nid))
		return
	nation_ask(body, faction)

// "half", "a third" style share of eligible citizens, from the coordinator's count.
// The share of eligible citizens a petition needs, as the coordinator sets it
// from the government and its legitimacy.
/proc/nation_revolt_share(nid)
	var/list/G = nation_government_of(nid)
	return isnum(G["revolt"]) ? "[round(G["revolt"] * 100)]%" : "half"

// Tells this land's citizens when a revolt petition opens, fills or closes.
/proc/nation_revolt_announce(nid, list/was)
	var/list/R = nation_revolt_of(nid)
	var/list/old = islist(was) && islist(was["revolt"]) && istext(was["revolt"]["type"]) ? was["revolt"] : null
	var/text = null
	if (R && (!old || old["opened"] != R["opened"]))
		text = "A petition to overthrow the government of [nation_registry[nid]["name"]] is open. Eligible citizens can sign it from Nation > Revolt."
	else if (R && isnum(R["ripe"]) && !isnum(old["ripe"]))
		text = "The revolt petition has its signatures. From a day from now, the rebels have 3 days to hold a nation assembly and overthrow the government."
	else if (!R && old)
		text = "The revolt petition has closed."
	if (text)
		nation_tell_citizens(nid, text)

#undef NATION_PRESENT_EVERY
#undef NATION_FAITH_EVERY
#undef ASSEMBLY_HOLD_TIME
#undef ASSEMBLY_HOLD_RANGE
#undef ASSEMBLY_HOLD_STEP

/mob/living/human/proc/nation_stay(faction, id, nid)
	if (WWinput(src, "Withdraw [faction]'s notice and stay in [nation_registry[nid]["name"]]?", "Stay", "Cancel", list("Stay", "Cancel")) != "Stay")
		return
	if (civilization != faction || nation_of_id(id) != nid)
		return
	nation_ask(list("op" = "stay", "faction" = id), faction)

// --- Offices of state (nation_offices.py) -------------------------------------------

#define NATION_OFFICES list("treasurer", "chancellor", "marshal")

/proc/nation_office_title(office)
	switch (office)
		if ("treasurer")
			return "Treasurer"
		if ("chancellor")
			return "Chancellor"
		if ("marshal")
			return "Marshal"
	return "officer"

/proc/nation_office_power(office)
	switch (office)
		if ("treasurer")
			return "chooses the common money in the ruler's place, or brings one to a vote"
		if ("chancellor")
			return "admits or refuses applications in the ruler's place"
		if ("marshal")
			return "guards the nation's assemblies: standing at one pauses any claim or revolt held there"
	return ""

/proc/nation_offices_of(nid)
	var/list/N = nation_registry[nid]
	return islist(N) && islist(N["offices"]) ? N["offices"] : list()

// The office this account holds in the nation, or null.
/proc/nation_office_of(nid, account)
	if (!istext(account))
		return null
	var/list/O = nation_offices_of(nid)
	for (var/office in O)
		var/list/H = O[office]
		if (islist(H) && H["account"] == account)
			return office
	return null

/proc/nation_offices_line(nid)
	var/list/O = nation_offices_of(nid)
	var/list/parts = list()
	for (var/office in NATION_OFFICES)
		var/list/H = O[office]
		if (islist(H) && istext(H["name"]))
			parts += "[nation_office_title(office)] [html_encode(H["name"])]"
	return parts.len ? "Offices: [jointext(parts, ", ")]." : null

/proc/nation_offices_announce(nid, list/was)
	var/list/old = islist(was) && islist(was["offices"]) ? was["offices"] : list()
	var/list/O = nation_offices_of(nid)
	for (var/office in NATION_OFFICES)
		var/list/H = O[office]
		var/list/OH = old[office]
		if (islist(H) && (!islist(OH) || OH["account"] != H["account"]))
			nation_tell_citizens(nid, "[H["name"]] is now [nation_office_title(office)] of [nation_registry[nid]["name"]].")

// The Offices of state prompt: see the officers; the head appoints and
// dismisses, a holder resigns. Sleeps (prompts).
/mob/living/human/proc/nation_offices_menu(faction, id, nid)
	var/list/G = nation_government_of(nid)
	var/list/O = nation_offices_of(nid)
	var/list/lines = list("<b>Offices of state of [html_encode(nation_registry[nid]["name"])]</b>")
	for (var/office in NATION_OFFICES)
		var/list/H = O[office]
		lines += "<b>[nation_office_title(office)]</b>: [islist(H) ? html_encode(H["name"]) : "empty"]. The [lowertext(nation_office_title(office))] [nation_office_power(office)]."
	lines += G["body"] ? "The [G["ruler"]] appoints officers and the [G["body"] == "referendum" ? "citizens confirm" : "[G["body"]] confirms"] them by a majority. The [G["ruler"]] may dismiss an officer at any time." : "The [G["ruler"]] appoints and dismisses officers alone."
	to_chat(src, jointext(lines, "<br>"))
	var/account = nation_account()
	var/mine = nation_office_of(nid, account)
	var/list/choices = list()
	if (nation_heads(nid))
		choices += list("Appoint an officer", "Dismiss an officer")
	if (mine)
		choices += "Resign as [nation_office_title(mine)]"
	if (!choices.len)
		return
	var/pick = WWinput(src, "Offices of state", "Offices of state", "Cancel", choices + "Cancel")
	if (!pick || pick == "Cancel" || civilization != faction || nation_of_id(id) != nid)
		return
	if (pick == "Resign as [nation_office_title(mine)]")
		nation_ask(list("op" = "dismiss", "faction" = id, "role" = "citizen", "office" = mine), faction)
		return
	var/list/offices = list()
	for (var/office in NATION_OFFICES)
		offices[nation_office_title(office)] = office
	var/office = offices[WWinput(src, "Which office?", "Offices of state", "Cancel", offices + "Cancel")]
	if (!office || !nation_heads(nid))
		return
	if (pick == "Dismiss an officer")
		nation_ask(list("op" = "dismiss", "faction" = id, "role" = "citizen", "office" = office), faction)
		return
	var/mob/living/human/H = nation_government_pick_head(nid, "monarchy", nation_office_title(office))
	if (!H || H == src || civilization != faction || !nation_heads(nid))
		return
	nation_ask(list("op" = "appoint", "faction" = id, "role" = "citizen", "office" = office, "person" = H.nation_account(), \
		"pname" = copytext(H.real_name, 1, 65), "pfaction" = nation_faction_id(H.civilization)), faction)

#undef NATION_OFFICES

// --- Treaties (nation_treaties.py) ------------------------------------------------

/proc/nation_treaty_name(kind)
	switch (kind)
		if ("alliance")
			return "an alliance"
		if ("pact")
			return "a non-aggression pact"
		if ("trade")
			return "a trade treaty"
		if ("war")
			return "war"
		if ("peace")
			return "peace"
		if ("overlord", "vassal")
			return "vassalage"
		if ("impose")
			return "imposed vassalage"
		if ("independence")
			return "independence"
	return "a treaty"

// A treaty in force, as seen by the nation holding row R.
/proc/nation_treaty_phrase(list/R)
	var/other = html_encode(nation_name_of(R["other"]))
	switch (R["kind"])
		if ("war")
			return "at war with [other]"
		if ("vassal")
			return "vassal of [other]"
		if ("overlord")
			return "overlord of [other]"
	return "[nation_treaty_name(R["kind"])] with [other]"

// What a treaty subject list(act, other, kind) does, for motions and prompts.
/proc/nation_treaty_act_label(list/T)
	var/other = nation_name_of(T[2])
	if (T[1] == "renounce")
		return T[3] == "overlord" ? "Release [other] from vassalage" : "Renounce [nation_treaty_name(T[3])] with [other]"
	switch (T[3])
		if ("war")
			return "Declare war on [other]"
		if ("overlord")
			return "Take [other] as a vassal"
		if ("vassal")
			return "Become a vassal of [other]"
		if ("impose")
			return "Impose vassalage on [other]"
		if ("independence")
			return "Declare independence from [other]"
	return "Agree to [nation_treaty_name(T[3])] with [other]"

// Who decides a nation's treaties under its government, for prompts.
/proc/nation_treaty_rule(nid)
	var/list/G = nation_government_of(nid)
	if (G["personal"])
		return "The [G["ruler"]] decides alone."
	switch (G["body"])
		if ("senate")
			return "The senate decides by a majority of its weighted votes."
		if ("referendum")
			return "The citizens decide by a majority in a referendum."
		if ("council")
			return "The league council decides by a majority of its weighted votes."
	return "More than half of the member factions' leaders must agree."

/proc/nation_name_of(nid)
	var/list/N = nation_registry[nid]
	return islist(N) && istext(N["name"]) ? N["name"] : "a nation now gone"

/proc/nation_treaties_of(nid)
	var/list/N = nation_registry[nid]
	return islist(N) && islist(N["treaties"]) ? N["treaties"] : list("in_force" = list(), "offers" = list("made" = list(), "received" = list()))

/proc/nation_treaties_line(nid)
	var/list/T = nation_treaties_of(nid)
	var/list/parts = list()
	for (var/list/R in T["in_force"])
		parts += nation_treaty_phrase(R)
	return parts.len ? "Treaties: [jointext(parts, "; ")]." : null

/proc/nation_treaty_key(list/R)
	return "[R["other"]]|[R["kind"]]"

/proc/nation_treaties_announce(nid, list/was)
	var/list/old = list()
	if (islist(was) && islist(was["treaties"]) && islist(was["treaties"]["in_force"]))
		for (var/list/R in was["treaties"]["in_force"])
			old[nation_treaty_key(R)] = R
	var/list/now = list()
	for (var/list/R in nation_treaties_of(nid)["in_force"])
		now[nation_treaty_key(R)] = R
		if (!old[nation_treaty_key(R)])
			switch (R["kind"])
				if ("war")
					nation_tell_citizens(nid, "[nation_name_of(nid)] is at war with [nation_name_of(R["other"])].")
				if ("vassal")
					nation_tell_citizens(nid, "[nation_name_of(nid)] is now a vassal of [nation_name_of(R["other"])], and pays it tribute each week.")
				if ("overlord")
					nation_tell_citizens(nid, "[nation_name_of(R["other"])] is now a vassal of [nation_name_of(nid)].")
				else
					nation_tell_citizens(nid, "[nation_name_of(nid)] and [nation_name_of(R["other"])] are bound by [nation_treaty_name(R["kind"])].")
	for (var/key in old)
		if (!now[key])
			var/list/R = old[key]
			nation_tell_citizens(nid, R["kind"] == "war" ? "The war between [nation_name_of(nid)] and [nation_name_of(R["other"])] is over." : "[capitalize(nation_treaty_name(R["kind"]))] between [nation_name_of(nid)] and [nation_name_of(R["other"])] has ended.")

// The Foreign affairs prompt: see treaties and offers; whoever may propose
// under the nation's government agrees to or renounces one. Sleeps (prompts).
/mob/living/human/proc/nation_foreign_menu(faction, id, nid)
	var/list/T = nation_treaties_of(nid)
	var/list/lines = list("<b>Foreign affairs of [html_encode(nation_name_of(nid))]</b>")
	lines += nation_treaties_line(nid) || "No treaties are in force."
	for (var/list/O in T["offers"]["received"])
		lines += O["kind"] == "overlord" ? "[html_encode(nation_name_of(O["other"]))] offers to take this nation as its vassal." : (O["kind"] == "vassal" ? "[html_encode(nation_name_of(O["other"]))] offers to become this nation's vassal." : "[html_encode(nation_name_of(O["other"]))] offers [nation_treaty_name(O["kind"])].")
	for (var/list/O in T["offers"]["made"])
		lines += "This nation offers: [html_encode(nation_treaty_act_label(list("agree", O["other"], O["kind"])))]."
	lines += "A treaty needs both nations to agree under their own governments, and an offer stands for 7 days. War is declared by one nation alone and ends any alliance or pact; peace needs both. Either nation may renounce an alliance, pact or trade treaty alone. Allies and pact partners never contest each other's provinces, a siege on another nation needs war, and allies at a besieged seat fight on their ally's side. A vassal pays its overlord a tenth of each member faction's strongbox (at most 100 silver) each week, and the two count as allies. Vassalage is agreed by both, or imposed by a nation at war that has won 2 sieges against the other in 14 days. The overlord may release a vassal; after 14 days a vassal may declare independence, which means war. [nation_treaty_rule(nid)]"
	to_chat(src, jointext(lines, "<br>"))
	if (!nation_may_propose(nid))
		return
	var/pick = WWinput(src, "Foreign affairs", "Foreign affairs", "Cancel", list("Agree to a treaty", "Renounce a treaty", "Cancel"))
	var/list/body = list("op" = "treaty", "faction" = id)
	if (pick == "Renounce a treaty")
		var/list/options = list()
		for (var/list/R in T["in_force"])
			if (!(R["kind"] in list("war", "vassal")))
				options[nation_treaty_act_label(list("renounce", R["other"], R["kind"]))] = R
		if (!options.len)
			to_chat(src, SPAN_NOTICE("There is no treaty to renounce."))
			return
		var/list/R = options[WWinput(src, "Renounce which treaty?", "Foreign affairs", "Cancel", options + "Cancel")]
		if (!islist(R))
			return
		body["act"] = "renounce"
		body["other"] = R["other"]
		body["treaty"] = R["kind"]
	else if (pick == "Agree to a treaty")
		var/list/nations = list()
		for (var/other in nation_registry)
			if (other != nid)
				nations[nation_name_of(other)] = other
		var/other = nations[WWinput(src, "With which nation?", "Foreign affairs", "Cancel", nations + "Cancel")]
		if (!other)
			return
		var/list/kinds = list("Alliance" = "alliance", "Non-aggression pact" = "pact", "Trade treaty" = "trade", "Declare war" = "war", "Make peace" = "peace",
			"Take as a vassal" = "overlord", "Become their vassal" = "vassal", "Impose vassalage" = "impose", "Declare independence" = "independence")
		var/kind = kinds[WWinput(src, "What should [nation_name_of(nid)] agree to with [nation_name_of(other)]?", "Foreign affairs", "Cancel", kinds + "Cancel")]
		if (!kind)
			return
		body["act"] = "agree"
		body["other"] = other
		body["treaty"] = kind
	else
		return
	if (stat || civilization != faction || nation_of_id(id) != nid)
		return
	nation_ask(body, faction)

#undef GOVERNMENT_TYPES
