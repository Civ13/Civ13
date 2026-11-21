// Nations (docs/land-stages.md, "Nations"). A nation is a union of factions
// across the lands of a region group. Its factions keep their own leaders,
// research, treasuries and members, and may still oppose each other. The
// group coordinator keeps the registry (tools/transfer_storage/nations.py):
// a faction's leader asks through the Nation verb, the request waits with this
// world's agent, and the coordinator decides it on its next pass. The leader
// hears the outcome when this world next reads the registry.
//
// Only a faction's home land speaks for it, so a colony's leader cannot act
// for the nation; its members are citizens all the same. A nation holds
// NATION_CAPACITY factions by the best nation assembly (below) any member
// keeps standing in its own land.

#define NATION_REFRESH 600 // deciseconds between reads of the agent's copy
#define NATION_NAME_MAX 40

var/global/list/nation_registry = list() // nation id -> the coordinator's entry
var/global/list/nation_pending = list() // requests the coordinator has not decided yet
var/global/nations_checked = 0 // world.time of the last good read (0: never)
var/global/nations_refreshing = FALSE
var/global/list/nation_assemblies = list() // every nation assembly, designated or not

// Tier -> list(name, factions held, earliest ordinal age, indoors,
// list(material kind = list(stack type, amount, label))), as faction_hall_tiers.
// Without an assembly a nation holds 3 factions.
var/global/list/nation_assembly_tiers = list(
	list("meeting ground", 4, 1, FALSE, list(
		"wood" = list(/obj/item/stack/material/wood, 120, "wood"),
		"stone" = list(/obj/item/stack/material/stone, 120, "stone"))),
	list("assembly hall", 6, 2, TRUE, list(
		"stone" = list(/obj/item/stack/material/stone, 400, "stone"),
		"iron" = list(/obj/item/stack/material/iron, 80, "iron"),
		"glass" = list(/obj/item/stack/material/glass, 40, "glass"),
		"cloth" = list(/obj/item/stack/material/cloth, 60, "cloth"))),
	list("parliament", 8, 4, TRUE, list(
		"stone" = list(/obj/item/stack/material/stone, 800, "stone"),
		"steel" = list(/obj/item/stack/material/steel, 200, "steel"),
		"glass" = list(/obj/item/stack/material/glass, 100, "glass"),
		"gold" = list(/obj/item/stack/material/gold, 40, "gold"))))

/proc/nations_enabled()
	return shard_group.enabled && transfer_bridge && transfer_bridge.enabled()

// --- The registry -------------------------------------------------------------

// Reads the registry from this world's agent, tells leaders the outcome of
// their requests and reports this land's assemblies. Sleeps; keeps the last
// copy when the agent cannot answer.
/proc/nations_refresh()
	if (!nations_enabled() || nations_refreshing)
		return FALSE
	nations_refreshing = TRUE
	var/list/answer = transfer_bridge.request("/nations", list())
	nations_refreshing = FALSE
	if (!answer || !answer["ok"] || !islist(answer["result"]))
		return FALSE
	var/list/result = answer["result"]
	var/list/clean = list()
	var/list/old_registry = nation_registry
	var/list/nations = result["nations"]
	if (islist(nations))
		for (var/id in nations)
			var/list/N = nations[id]
			if (istext(id) && islist(N) && istext(N["name"]) && islist(N["members"]))
				clean[id] = N
	nation_registry = clean
	nation_pending = islist(result["pending"]) ? result["pending"] : list()
	nations_checked = world.time
	var/list/told = list()
	if (islist(result["results"]))
		for (var/list/R in result["results"])
			if (!islist(R) || !isnum(R["id"]) || !istext(R["text"]))
				continue
			var/mob/M = nation_actor_mob(R["actor"])
			if (!M)
				continue
			to_chat(M, "<big><b>Nation:</b> [html_encode(R["text"])]</big>")
			told += R["id"]
	if (told.len)
		transfer_bridge.request("/nation/seen", list("ids" = told))
	nation_government_announce(old_registry)
	nation_renames_send()
	nation_assemblies_report()
	nation_eras_report()
	nation_census_report()
	nation_succession_report()
	return TRUE

/proc/nations_refresh_due()
	if (nations_checked && world.time - nations_checked < NATION_REFRESH)
		return FALSE
	return nations_refresh()

// The online mob of the account that asked.
/proc/nation_actor_mob(actor)
	if (!istext(actor))
		return null
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (C.ckey == actor || (istype(H) && H.persistence_owner_ckey == actor))
			return C.mob
	return null

// The id a faction is known by across the lands: a colony goes by its parent.
/proc/nation_faction_id(name)
	if (!istext(name) || name == "none" || !map || !shard_group.enabled)
		return null
	var/list/row = map.faction_colonies()[name]
	if (islist(row) && colony_parent_valid(row[1]))
		return row[1]
	return party_train_faction_party(name)

// A faction founded in this land, which this world speaks for.
/proc/nation_home_faction(name)
	return istext(name) && map && (name in map.custom_civs) && !map.faction_colonies()[name]

/proc/nation_of_id(id)
	if (!id)
		return null
	for (var/nid in nation_registry)
		var/list/N = nation_registry[nid]
		if (id in N["members"])
			return nid
	return null

/proc/nation_name_of_faction(name)
	var/nid = nation_of_id(nation_faction_id(name))
	return nid ? nation_registry[nid]["name"] : null

// "Ash (North America)" for a faction id.
/proc/nation_faction_label(id)
	var/land = copytext(id, 5, findtext(id, ":", 5))
	var/list/peer = shard_group.peers[land]
	var/land_name = land == shard_group.region ? "here" : (islist(peer) && istext(peer["name"]) ? peer["name"] : land)
	return "[party_train_party_name(id)] ([land_name])"

/proc/nation_name_ok(name)
	if (!istext(name) || length(name) < 3 || length(name) > NATION_NAME_MAX || trim(name) != name)
		return FALSE
	for (var/i = 1, i <= length(name), i++)
		var/c = text2ascii(name, i)
		if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 32 || c == 39 || c == 45 || c == 46))
			return FALSE
	return TRUE

/proc/nation_pending_for(id, op)
	for (var/list/R in nation_pending)
		if (islist(R) && R["faction"] == id && R["op"] == op)
			return TRUE
	return FALSE

// Queues a request for the coordinator. Sleeps.
/proc/nation_send(list/body)
	if (!nations_enabled())
		return FALSE
	var/list/answer = transfer_bridge.request("/nation/request", body)
	if (!answer || !answer["ok"])
		return FALSE
	nation_pending += list(body)
	return TRUE

/mob/living/human/proc/nation_ask(list/body, faction)
	body["actor"] = faction_roster_account(src) || ckey
	// A leader (or a nation's ruler) speaks for the faction; anyone else asks
	// as a citizen, which only elective governments hear (nation_motions.py).
	var/nid = nation_of_id(nation_faction_id(faction))
	if (isnull(body["role"]))
		body["role"] = map.is_faction_leader(src, faction) || (nid && nation_rules(nid)) ? "leader" : "citizen"
	if (!nation_send(body))
		to_chat(src, SPAN_WARNING("The other lands cannot be reached right now. Try again later."))
		return FALSE
	log_game("Nation: [key_name(src)] asked to [body["op"]] for [faction].")
	map.recruitment_audit(faction, "[real_name] asked the nations to [body["op"]].", faction_roster_account(src) || "")
	to_chat(src, SPAN_NOTICE("Your word goes out to the other lands. You will hear the answer when they next confer, within a few minutes."))
	return TRUE

// A faction renamed in its own land keeps its place in its nation. Called by
// rename_faction, which must not sleep, so the rename waits in the map's saved
// recruitment state until the next registry read sends it.
/proc/nation_rename_faction(old_name, new_name)
	if (!nations_enabled() || !nation_home_faction(new_name))
		return
	var/list/S = map.recruitment_state()
	if (!islist(S["nation_renames"]))
		S["nation_renames"] = list()
	S["nation_renames"] += list(list(party_train_faction_party(old_name), party_train_faction_party(new_name)))

// Sends queued renames in order. Sleeps.
/proc/nation_renames_send()
	var/list/S = map ? map.recruitment_state() : null
	var/list/queue = S ? S["nation_renames"] : null
	while (islist(queue) && queue.len)
		var/list/R = queue[1]
		if (islist(R) && R.len == 2 && !nation_send(list("op" = "rename", "actor" = "world", "faction" = R[1], "to" = R[2])))
			return
		queue.Cut(1, 2)

// --- The Nation verb ------------------------------------------------------------

/mob/living/human/proc/nation_menu()
	set name = "Nation"
	set category = "Faction"
	set desc = "See the nations of the wider world, or found, join or leave one."

	if (!nations_enabled() || !map || !map.allows_custom_factions())
		to_chat(src, SPAN_WARNING("Nations unite factions across the lands of the wider world. There are none here."))
		return
	if (!nations_checked || world.time - nations_checked > NATION_REFRESH / 6)
		nations_refresh()
	var/faction = civilization
	var/list/choices = list("View nations")
	var/id = null
	var/nid = null
	var/text = "There are [nation_registry.len] nation\s in the wider world."
	if (faction && faction != "none")
		id = nation_faction_id(faction)
		nid = nation_of_id(id)
		text = nid ? "[faction] is part of [nation_registry[nid]["name"]]." : "[faction] is not part of a nation."
		if (nid)
			text += " [nation_government_line(nid)]"
		var/list/G = nid ? nation_government_of(nid) : null
		if (map.is_faction_leader(src, faction))
			if (!nation_home_faction(faction))
				text += " Its leaders in its own land speak for it among the nations."
			else if (nid)
				choices += list("Government", "Vote on an application")
				if (G["type"] == "confederation")
					choices += "Vote for a head"
				choices += "Vote on a common money"
				var/list/leaving = nation_registry[nid]["leaving"]
				choices += islist(leaving) && isnum(leaving[id]) ? "Stay" : "Secede"
			else
				choices += list("Found a nation", "Apply to a nation")
		else if (nid && nation_rules(nid))
			text += " You rule it as its [G["ruler"]]."
			choices += list("Government", "Vote on an application", "Vote on a common money")
		if (nid && G["body"] && nation_home_faction(faction))
			choices.Insert(2, "Motions and elections")
		if (nid && (G["type"] == "monarchy" || G["type"] == "republic") && nation_heads(nid))
			choices.Insert(2, G["type"] == "monarchy" ? "Name an heir" : "Name a deputy")
	choices += "Cancel"
	var/pick = WWinput(src, text, "Nation", "Cancel", choices)
	if (pick == "View nations")
		nation_view()
		return
	if (pick == "Cancel" || !pick)
		return
	// The dialog blocks; the faction and leadership must still hold.
	if (pick == "Name an heir" || pick == "Name a deputy")
		if (civilization == faction && nation_of_id(id) == nid)
			nation_name_successor(faction, id, nid)
		return
	if (pick == "Motions and elections")
		if (!stat && civilization == faction && nation_home_faction(faction) && nation_of_id(id) == nid)
			nation_motions_menu(faction, id, nid)
		return
	if (stat || civilization != faction || !(map.is_faction_leader(src, faction) || nation_rules(nid)) || !nation_home_faction(faction) || nation_of_id(id) != nid)
		return
	switch (pick)
		if ("Found a nation")
			nation_found(faction, id)
		if ("Apply to a nation")
			nation_apply(faction, id)
		if ("Vote on an application")
			nation_vote(faction, id, nid)
		if ("Vote for a head")
			nation_head(faction, id, nid)
		if ("Vote on a common money")
			nation_currency_vote(faction, id, nid)
		if ("Secede")
			nation_secede(faction, id, nid)
		if ("Stay")
			nation_stay(faction, id, nid)
		if ("Government")
			nation_government_menu(faction, id, nid)

/mob/living/human/proc/nation_view()
	if (!nation_registry.len)
		to_chat(src, "No nations have been founded yet.")
		return
	var/list/lines = list("<b>Nations of the wider world</b>")
	for (var/nid in nation_registry)
		var/list/N = nation_registry[nid]
		var/list/members = list()
		for (var/f in N["members"])
			members += html_encode(nation_faction_label(f))
		var/assembly = isnum(N["assembly"]) && N["assembly"] >= 1 && N["assembly"] <= nation_assembly_tiers.len ? ", a [nation_assembly_tiers[N["assembly"]][1]]" : ""
		lines += "<b>[html_encode(N["name"])]</b>: [jointext(members, ", ")]. Head: [istext(N["head"]) ? html_encode(nation_faction_label(N["head"])) : "none"]. Holds [length(N["members"])]/[N["capacity"]] factions[assembly]."
		lines += "&nbsp;&nbsp;[nation_government_line(nid)]"
		if (istext(N["currency"]) && length(N["currency"]))
			lines += "&nbsp;&nbsp;Common money: that struck by [html_encode(nation_faction_label(N["currency"]))]."
		if (islist(N["applications"]) && length(N["applications"]))
			var/list/applying = list()
			for (var/list/A in N["applications"])
				applying += html_encode(nation_faction_label(A["faction"]))
			lines += "&nbsp;&nbsp;Applying: [jointext(applying, ", ")]."
	to_chat(src, jointext(lines, "<br>"))

/mob/living/human/proc/nation_found(faction, id)
	var/list/partners = list()
	for (var/mob/living/human/H in view(3, src))
		if (H != src && H.client && !H.stat && H.civilization && H.civilization != faction && nation_home_faction(H.civilization) \
				&& map.is_faction_leader(H, H.civilization) && !nation_of_id(nation_faction_id(H.civilization)))
			partners["[H.real_name] of [H.civilization]"] = H
	if (!partners.len)
		to_chat(src, SPAN_WARNING("A nation is founded by two factions. Stand with the leader of another faction of this land that is not part of a nation."))
		return
	var/pick = WWinput(src, "Found a nation with which faction?", "Found a Nation", "Cancel", partners + "Cancel")
	var/mob/living/human/partner = partners[pick]
	if (!partner)
		return
	var/name = player_input(src, "Name the nation (3 to [NATION_NAME_MAX] letters, numbers, spaces, ' - .).", "Found a Nation", "", "text", null, TRUE)
	name = trim(sanitize(name, NATION_NAME_MAX + 1, FALSE))
	if (!nation_name_ok(name))
		to_chat(src, SPAN_WARNING("A nation's name takes 3 to [NATION_NAME_MAX] letters, numbers, spaces and ' - . only."))
		return
	var/other = partner.civilization
	to_chat(src, SPAN_NOTICE("You ask [partner.real_name] to found [name] with you."))
	var/answer = WWinput(partner, "[real_name], leader of [faction], asks [other] to found the nation of [name] together. Each faction keeps its own leaders, research and members, and may leave at any time.", "Found a Nation", "Decline", list("Found it together", "Decline"))
	if (answer != "Found it together")
		to_chat(src, SPAN_WARNING("[partner.real_name] declines."))
		return
	if (stat || partner.stat || civilization != faction || partner.civilization != other || get_dist(src, partner) > 3 \
			|| !map.is_faction_leader(src, faction) || !map.is_faction_leader(partner, other))
		return
	if (nation_ask(list("op" = "found", "faction" = id, "name" = name, "with" = list(nation_faction_id(other))), faction))
		to_chat(partner, SPAN_NOTICE("You join [real_name] in founding [name]. The other lands will soon know of it."))

/mob/living/human/proc/nation_apply(faction, id)
	var/list/options = list()
	for (var/nid in nation_registry)
		var/list/N = nation_registry[nid]
		options["[N["name"]] ([length(N["members"])]/[N["capacity"]] factions)"] = nid
	if (!options.len)
		to_chat(src, SPAN_WARNING("No nations have been founded yet."))
		return
	var/pick = WWinput(src, "Apply to join which nation? Its member factions vote, or its ruler decides.", "Apply to a Nation", "Cancel", options + "Cancel")
	var/nid = options[pick]
	if (!nid || civilization != faction || nation_of_id(id))
		return
	nation_ask(list("op" = "apply", "faction" = id, "nation" = nid), faction)

/mob/living/human/proc/nation_vote(faction, id, nid)
	var/list/N = nation_registry[nid]
	var/list/options = list()
	for (var/list/A in N["applications"])
		if (islist(A) && istext(A["faction"]))
			options["[nation_faction_label(A["faction"])]"] = A["faction"]
	if (!options.len)
		to_chat(src, SPAN_NOTICE("No faction is applying to [N["name"]] right now."))
		return
	var/pick = WWinput(src, "Vote on which application?", "Nation Vote", "Cancel", options + "Cancel")
	var/applicant = options[pick]
	if (!applicant)
		return
	var/answer = WWinput(src, "Admit [pick] into [N["name"]]?", "Nation Vote", "Cancel", list("Admit", "Refuse", "Cancel"))
	if ((answer != "Admit" && answer != "Refuse") || civilization != faction || nation_of_id(id) != nid)
		return
	nation_ask(list("op" = "vote", "faction" = id, "applicant" = applicant, "yes" = answer == "Admit"), faction)

/mob/living/human/proc/nation_head(faction, id, nid)
	var/list/N = nation_registry[nid]
	var/list/options = list()
	for (var/f in N["members"])
		options["[nation_faction_label(f)]"] = f
	var/pick = WWinput(src, "A head speaks for [N["name"]]; the factions keep their own rule. Vote for which faction?", "Nation Head", "Cancel", options + "Cancel")
	var/candidate = options[pick]
	if (!candidate || civilization != faction || nation_of_id(id) != nid)
		return
	nation_ask(list("op" = "head", "faction" = id, "candidate" = candidate), faction)

/mob/living/human/proc/nation_secede(faction, id, nid)
	var/list/N = nation_registry[nid]
	var/list/G = nation_government_of(nid)
	var/notice = isnum(G["notice"]) && G["notice"] > 0 ? " As a [lowertext(nation_government_name(nid))], the nation holds you for [round(G["notice"] / 3600)] hours after you give notice." : ""
	var/answer = WWinput(src, "Lead [faction] out of [N["name"]]?[notice] It cannot apply to rejoin for three days, and a nation left with one faction dissolves.", "Secede", "Cancel", list("Secede", "Cancel"))
	if (answer != "Secede" || civilization != faction || nation_of_id(id) != nid)
		return
	nation_ask(list("op" = "secede", "faction" = id), faction)

// --- The assembly ---------------------------------------------------------------

// The highest tier among the faction's standing assemblies here (0 = none).
/proc/nation_assembly_tier(faction)
	var/best = 0
	for (var/obj/structure/faction_hall/nation_assembly/A in nation_assemblies)
		if (!QDELETED(A) && A.faction == faction && isturf(A.loc) && A.anchored && A.tier > best && A.tier_stands(A.tier))
			best = A.tier
	return best

// Tells the coordinator when a member faction of this land has a different
// assembly standing than the registry shows. Sleeps.
/proc/nation_assemblies_report()
	var/prefix = "civ:[shard_group.region]:"
	for (var/nid in nation_registry)
		var/list/N = nation_registry[nid]
		var/list/known = islist(N["assemblies"]) ? N["assemblies"] : list()
		for (var/id in N["members"])
			if (!istext(id) || findtext(id, prefix) != 1 || nation_pending_for(id, "assembly"))
				continue
			var/name = copytext(id, length(prefix) + 1)
			if (!nation_home_faction(name))
				continue
			var/tier = nation_assembly_tier(name)
			if (tier != (isnum(known[id]) ? known[id] : 0))
				nation_send(list("op" = "assembly", "actor" = "world", "faction" = id, "tier" = tier))

/obj/structure/faction_hall/nation_assembly
	name = "nation assembly seat"
	desc = "The seat of a nation's assembly. A member faction's leader designates it in the faction's own land; its members raise it into a meeting ground, an assembly hall and a parliament, and each lets the nation hold more factions."
	icon_state = "banner_b"
	seat_name = "assembly seat"
	hall_word = "assembly"
	last_words = "It is a parliament, the greatest assembly."

/obj/structure/faction_hall/nation_assembly/New()
	..()
	faction_halls -= src
	nation_assemblies |= src

/obj/structure/faction_hall/nation_assembly/Destroy()
	nation_assemblies -= src
	return ..()

/obj/structure/faction_hall/nation_assembly/tiers()
	return nation_assembly_tiers

/obj/structure/faction_hall/nation_assembly/limit_text()
	var/nid = nation_of_id(nation_faction_id(faction))
	if (!nid)
		return "When [faction] is part of a nation, this assembly lets the nation hold more factions."
	var/list/N = nation_registry[nid]
	return "[N["name"]] may hold up to [N["capacity"]] factions; the lands learn of a new tier within a few minutes."

/obj/structure/faction_hall/nation_assembly/designate_block(mob/living/human/user)
	if (!nations_enabled())
		return "Nations unite factions across the lands of the wider world. There are none here."
	if (!map || !map.allows_custom_factions() || !user.civilization || user.civilization == "none" || !map.is_faction_leader(user, user.civilization))
		return "Only a faction's leader can designate an assembly."
	if (!nation_home_faction(user.civilization))
		return "An assembly counts only in its faction's own land."
	return null

/obj/structure/faction_hall/nation_assembly/designate_prompt(name)
	return "Make this the assembly of [name]? While it stands, the nation [name] belongs to may hold more factions, and raiders can burn it."

#undef NATION_REFRESH
#undef NATION_NAME_MAX
