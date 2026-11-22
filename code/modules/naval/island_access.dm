// ============================================================
// Who may land on a faction's claimed island (docs/ship-voyage.md, "Island borders")
// ------------------------------------------------------------
// Val (2026-11-22): every faction can claim an island of its own (its colony
// charter on a land across the sea, island_claim.dm) that only it decides
// who reaches. Its leader and officers holding the papers power, in any land,
// set the island's border:
// - OPEN: anyone may land.
// - GUESTS (the default): members, the people the faction names and anyone
//   holding a visitor pass. Passes are granted at a recruitment station of
//   the faction, for 1 hour to 7 days, and can be taken back.
// - MEMBERS: the border is closed. Only members land, whatever passes say.
// A member is anyone who travels as the faction (colony_faction_id): its own
// members and its colonies' members.
//
// The world directory keeps the border (world_chart.py chart_access; ops
// "access" and "pass"), so every land knows it. Nobody can set out for the
// island without leave: the voyage menu shows the island only to those who
// may land, the tiller refuses a crew with anyone aboard who may not, and
// every trail, crossing and flight out of any land refuses them too
// (region_gate/depart_party). An admin's send is never stopped. On the island
// itself, whoever is ashore without leave (the border closed, a pass ran out,
// a member was expelled) is told to go, and after ISLAND_EXILE_GRACE is put
// ashore in the start land. Restrained captives are left where they are.
// Enemies never reach the island while the claim stands; a claim given up or
// lapsed (island_claim.dm) drops its border with it.
// Nothing here sleeps except the prompts, which recheck after, and the
// directory requests.
// ============================================================

#define ISLAND_EXILE_GRACE 6000 // deciseconds a visitor without leave has to go
#define ISLAND_UNIX_2000 946684800

// How long a visitor pass may run (a proc, not a global list: world init is at its limit).
/proc/island_pass_hours()
	return list("1 hour" = 1, "6 hours" = 6, "1 day" = 24, "3 days" = 72, "7 days" = 168)

// When a visitor without leave was first told to go (world.time); not saved.
/mob/living/human/var/tmp/island_unwelcome_since = null

// ---------------------------------------------------------------- the border

/proc/island_access_unix()
	return round(world.realtime / 10) + ISLAND_UNIX_2000

// The faction (civ:<land>:<name>) claiming the chart tile key, or null. A
// player's own land (crew:<ckey>) has no border.
/proc/island_access_claimant_at(key)
	if (!istext(key))
		return null
	var/list/claims = islist(world_chart["claims"]) ? world_chart["claims"] : list()
	for (var/claimant in claims)
		if (claims[claimant] == key && findtext(claimant, "civ:") == 1 && colony_parent_valid(claimant))
			return claimant
	return null

// The chart tile key of the land opened in region id, or null.
/proc/island_access_key_of(id)
	var/list/tiles = world_chart["tiles"]
	if (!istext(id) || !islist(tiles))
		return null
	for (var/key in tiles)
		var/list/tile = tiles[key]
		if (islist(tile) && tile["region"] == id)
			return key
	return null

/proc/island_access_claimant_of(id)
	return island_access_claimant_at(island_access_key_of(id))

// The border the directory keeps for claimant: mode, people (accounts) and
// passes (account = unix time it runs out).
/proc/island_access_policy(claimant)
	var/list/all = world_chart["access"]
	var/list/row = islist(all) ? all[claimant] : null
	if (!islist(row) || !(row["mode"] in list("OPEN", "GUESTS", "MEMBERS")))
		return list("mode" = "GUESTS", "people" = list(), "passes" = list())
	return list("mode" = row["mode"], "people" = islist(row["people"]) ? row["people"] : list(), "passes" = islist(row["passes"]) ? row["passes"] : list())

/proc/island_access_member(mob/living/human/H, claimant)
	return istype(H) && claimant && colony_faction_id(H) == claimant

// Hours left on account's pass to claimant's island, or 0.
/proc/island_access_pass_hours(claimant, account)
	var/list/passes = island_access_policy(claimant)["passes"]
	var/until = account ? passes[account] : null
	if (!isnum(until))
		return 0
	var/left = until - island_access_unix()
	return left > 0 ? max(1, round(left / 3600, 1)) : 0

// TRUE when H may land on claimant's island.
/proc/island_access_admits(mob/living/human/H, claimant)
	if (!claimant)
		return TRUE
	if (island_access_member(H, claimant))
		return TRUE
	var/list/policy = island_access_policy(claimant)
	switch (policy["mode"])
		if ("OPEN")
			return TRUE
		if ("MEMBERS")
			return FALSE
	var/account = faction_roster_account(H)
	if (!account)
		return FALSE
	var/list/people = policy["people"]
	return (account in people) || island_access_pass_hours(claimant, account) > 0

// Why H may not land on claimant's island, or null.
/proc/island_access_refusal(mob/living/human/H, claimant)
	if (island_access_admits(H, claimant))
		return null
	var/name = party_train_party_name(claimant)
	if (island_access_policy(claimant)["mode"] == "MEMBERS")
		return "[H.real_name] may not land on [name]'s island: its border is closed to all but its members"
	return "[H.real_name] may not land on [name]'s island: only its members, the guests it names and holders of its visitor passes may"

// Why H may not set off for region id, or null: only a claimed island across the sea has a border.
/proc/island_access_departure_refusal(id, mob/living/human/H)
	var/list/peer = shard_group && shard_group.enabled ? shard_group.peers[id] : null
	if (!peer || peer["kind"] != "EXPEDITION")
		return null
	return island_access_refusal(H, island_access_claimant_of(id))

// TRUE when the departure checks for region id need a fresh chart.
/proc/island_access_destination(id)
	var/list/peer = shard_group && shard_group.enabled ? shard_group.peers[id] : null
	return peer && peer["kind"] == "EXPEDITION"

/obj/structure/region_gate/var/tmp/admin_sent = FALSE

// Whether a trip through this gate keeps to island borders: never an admin's send.
/obj/structure/region_gate/proc/island_access_checks()
	return !admin_sent

/obj/structure/region_gate/admin_send/island_access_checks()
	return FALSE

// ---------------------------------------------------------------- setting it

// The island claimant H's faction holds, or null: the claim is on the chart.
/proc/island_access_claim_of(mob/living/human/H)
	var/claimant = colony_faction_id(H)
	if (!claimant)
		return null
	var/list/claims = islist(world_chart["claims"]) ? world_chart["claims"] : list()
	return istext(claims[claimant]) ? claimant : null

// TRUE when H keeps its faction's island border here: its leader, or an
// officer with the papers power (faction_offices.dm).
/proc/island_access_keeper(mob/living/human/H)
	return istype(H) && map && H.civilization && H.civilization != "none" && map.faction_power(H, H.civilization, "papers")

// The identity of this particular claim, not just its owner and coordinates.
/proc/island_access_incarnation(claimant)
	var/list/incarnations = world_chart["claim_incarnations"]
	return islist(incarnations) ? incarnations[claimant] : null

// Queues a change only for the claim shown when the officer opened the menu.
/proc/island_access_ask(op, claimant, by, list/data, incarnation)
	var/list/claims = islist(world_chart["claims"]) ? world_chart["claims"] : list()
	var/key = claims[claimant]
	if (!istext(key) || !istext(incarnation) || incarnation != island_access_incarnation(claimant) || !transfer_bridge || !transfer_bridge.enabled())
		return FALSE
	data["incarnation"] = incarnation
	var/list/xy = splittext(key, ",")
	if (length(xy) != 2)
		return FALSE
	var/list/answer = transfer_bridge.request("/chart/request", list("op" = op, "x" = text2num(xy[1]), "y" = text2num(xy[2]),
		"admin" = by || "world", "owner" = claimant, "data" = data))
	if (!answer || !answer["ok"])
		return FALSE
	log_game("Island access: [by || "the world"] asked to [op] [claimant]'s island border: [json_encode(data)].")
	return TRUE

// Names this world knows for guest accounts, so the list reads as people.
/proc/island_guest_names()
	if (!map)
		return list()
	var/list/S = map.recruitment_state()
	if (!islist(S["island_guest_names"]))
		S["island_guest_names"] = list()
	return S["island_guest_names"]

/proc/island_guest_label(account)
	var/list/names = island_guest_names()
	return istext(names[account]) ? names[account] : "someone named in another land"

/proc/island_access_mode_text(mode)
	switch (mode)
		if ("OPEN")
			return "open to visitors: anyone may land"
		if ("MEMBERS")
			return "closed: only members may land, whatever their passes say"
	return "members and guests: members, the guests it names and holders of its visitor passes may land"

/proc/island_access_status_text(claimant)
	var/list/policy = island_access_policy(claimant)
	var/list/lines = list("The border is [island_access_mode_text(policy["mode"])].")
	var/list/people = policy["people"]
	var/list/named = list()
	for (var/account in people)
		named += island_guest_label(account)
	lines += named.len ? "Named guests: [english_list(named)]." : "No guests are named."
	var/list/passes = policy["passes"]
	var/list/held = list()
	for (var/account in passes)
		var/hours = island_access_pass_hours(claimant, account)
		if (hours)
			held += "[island_guest_label(account)] ([hours] hour\s left)"
	lines += held.len ? "Visitor passes: [english_list(held)]." : "No visitor passes are running."
	return jointext(lines, " ")

/mob/living/human/proc/faction_island()
	set name = "Faction Island"
	set category = "Faction"
	set desc = "See your faction's island across the sea, and who may land there."
	if (!shard_group || !shard_group.enabled || !map)
		to_chat(src, SPAN_WARNING("This land is not part of the wider world."))
		return
	world_chart_refresh()
	var/claimant = island_access_claim_of(src)
	if (!claimant)
		var/list/how = list("Every faction may claim one island across the sea as its own safe haven, and decide who may land there.")
		how += "To claim one, its leader sails a ship with a mast or engine and at least 2 crew from the coast (her tiller's voyage menu) to a land across the sea, then plants a colony charter there."
		how += "The claim stands while at least 3 members keep a bed there; nobody else can take it. Offline sleepers in their own beds there are protected."
		if (!civilization || civilization == "none")
			how += "You belong to no faction yet."
		to_chat(src, SPAN_NOTICE(jointext(how, " ")))
		return
	var/name = party_train_party_name(claimant)
	to_chat(src, SPAN_NOTICE("<b>[html_encode(name)]'s island.</b> [html_encode(island_access_status_text(claimant))]"))
	if (!island_access_keeper(src))
		to_chat(src, "Your faction's leader and officers who issue papers keep its border.")
		return
	island_access_menu(claimant)

/mob/living/human/proc/island_access_menu(claimant)
	var/incarnation = island_access_incarnation(claimant)
	var/list/choices = list("Open to visitors" = "OPEN", "Members and guests" = "GUESTS", "Members only (close the border)" = "MEMBERS",
		"Name a guest beside you", "Remove a guest", "Done")
	var/choice = WWinput(src, "Who may land on your faction's island? Visitor passes are granted at your recruitment stations.", "Faction Island", "Done", choices)
	if (!choice || choice == "Done" || !island_access_keeper(src) || island_access_claim_of(src) != claimant)
		return
	var/list/change
	var/action_text
	if (choices[choice])
		var/mode = choices[choice]
		change = list("mode" = mode)
		action_text = "set the border to [island_access_mode_text(mode)]"
	else if (choice == "Name a guest beside you")
		var/list/near = list()
		for (var/mob/living/human/M in range(1, src))
			if (M != src && M.stat != DEAD && faction_roster_account(M) && !island_access_member(M, claimant))
				near["[M.real_name]"] = M
		if (!near.len)
			to_chat(src, SPAN_NOTICE("A guest is named while they stand beside you."))
			return
		var/pick = WWinput(src, "Name whom as a guest of your island?", "Faction Island", "Cancel", near + "Cancel")
		var/mob/living/human/M = near[pick]
		if (!M || get_dist(M, src) > 1 || !island_access_keeper(src))
			return
		var/account = faction_roster_account(M)
		if (!account || M.stat == DEAD || island_access_member(M, claimant))
			return
		change = list("add_guest" = account)
		action_text = "name [M.real_name] as a guest"
		island_guest_names()[account] = M.real_name
	else if (choice == "Remove a guest")
		var/list/policy = island_access_policy(claimant)
		var/list/people = policy["people"]
		var/list/named = list()
		for (var/account in people)
			named["[island_guest_label(account)] ([length(named) + 1])"] = account
		if (!named.len)
			to_chat(src, SPAN_NOTICE("No guests are named."))
			return
		var/pick = WWinput(src, "Remove which guest?", "Faction Island", "Cancel", named + "Cancel")
		if (!named[pick] || !island_access_keeper(src))
			return
		var/account = named[pick]
		change = list("remove_guest" = account)
		action_text = "remove [island_guest_label(account)] as a guest"
	if (!change || !island_access_keeper(src) || island_access_claim_of(src) != claimant)
		return
	if (!island_access_ask("access", claimant, faction_roster_account(src), change, incarnation))
		to_chat(src, SPAN_WARNING("No word can be sent to the world directory right now. Try again in a minute."))
		return
	map.recruitment_audit(civilization, "[real_name] asked the world directory to [action_text].", faction_roster_account(src) || "")
	to_chat(src, SPAN_NOTICE("Request queued to [html_encode(action_text)]. Check Faction Island in a minute or two for the current policy."))

// ---------------------------------------------------------------- visitor passes

/obj/structure/recruitment_station/verb/grant_island_pass()
	set name = "Grant Island Visitor Pass"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat != CONSCIOUS || !Adjacent(H))
		return
	if (!faction || H.civilization != faction || !island_access_keeper(H))
		to_chat(H, SPAN_WARNING("Only this station's faction leader or its officers who issue papers can grant visitor passes here."))
		return
	world_chart_refresh()
	var/claimant = island_access_claim_of(H)
	if (!claimant)
		to_chat(H, SPAN_WARNING("[faction] claims no island across the sea yet. Its leader claims one with a colony charter on a land across the sea."))
		return
	var/incarnation = island_access_incarnation(claimant)
	var/list/near = list()
	for (var/mob/living/human/M in range(1, src))
		if (M != H && M.stat != DEAD && faction_roster_account(M) && !island_access_member(M, claimant))
			var/hours = island_access_pass_hours(claimant, faction_roster_account(M))
			near["[M.real_name][hours ? " (pass: [hours] hour\s left)" : ""]"] = M
	if (!near.len)
		to_chat(H, SPAN_NOTICE("A visitor pass is granted to someone standing beside the station who is not a member."))
		return
	var/pick = WWinput(H, "Grant a visitor pass to your island to whom? It lets them land while the border admits guests.", "Island visitor pass", "Cancel", near + "Cancel")
	var/mob/living/human/M = near[pick]
	if (!M)
		return
	var/list/lengths = island_pass_hours()
	if (island_access_pass_hours(claimant, faction_roster_account(M)))
		lengths["Take the pass back"] = 0
	var/how = WWinput(H, "For how long?", "Island visitor pass", "Cancel", lengths + "Cancel")
	if (isnull(lengths[how]) || get_dist(M, src) > 1 || get_dist(H, src) > 1 || !island_access_keeper(H) || island_access_claim_of(H) != claimant)
		return
	var/account = faction_roster_account(M)
	if (!island_access_ask("pass", claimant, faction_roster_account(H), list("account" = account, "hours" = lengths[how]), incarnation))
		to_chat(H, SPAN_WARNING("No word can be sent to the world directory right now. Try again in a minute."))
		return
	island_guest_names()[account] = M.real_name
	if (lengths[how])
		map.recruitment_audit(faction, "[H.real_name] granted [M.real_name] a visitor pass to the island for [how].", faction_roster_account(H) || "")
		to_chat(H, SPAN_NOTICE("You grant [M] a visitor pass to [faction]'s island for [how]."))
		to_chat(M, SPAN_NOTICE("[H] grants you a visitor pass to [faction]'s island for [how]. While its border admits guests, a ship can take you there."))
	else
		map.recruitment_audit(faction, "[H.real_name] took back [M.real_name]'s visitor pass to the island.", faction_roster_account(H) || "")
		to_chat(H, SPAN_NOTICE("You take back [M]'s visitor pass."))
		to_chat(M, SPAN_WARNING("[H] takes back your visitor pass to [faction]'s island."))

// ---------------------------------------------------------------- on the island

/obj/structure/region_gate/island_exile
	name = "island border"
	desc = "Someone without leave is being put ashore elsewhere."
	invisibility = 101
	icon = null
	mouse_opacity = 0
	should_save = FALSE

/obj/structure/region_gate/island_exile/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/island_exile/island_access_checks()
	return FALSE

/obj/structure/region_gate/island_exile/attack_hand(mob/living/human/user)
	return

/obj/structure/region_gate/island_exile/attack_ghost(mob/user)
	return

// Runs with the land's chart refresh (island_claim_check): whoever is ashore
// without leave is told to go, and after ISLAND_EXILE_GRACE is put ashore in
// the start land.
/proc/island_access_sweep(claimant)
	if (!claimant || !shard_group || !shard_group.start_region || shard_group.start_region == shard_group.region)
		return
	var/name = party_train_party_name(claimant)
	for (var/mob/living/human/H in human_mob_list)
		if (QDELETED(H) || H.stat == DEAD || !H.client || !H.persistence_owner_ckey || !isturf(H.loc))
			continue
		if (island_access_admits(H, claimant))
			if (H.island_unwelcome_since)
				H.island_unwelcome_since = null
				to_chat(H, SPAN_NOTICE("You have leave to stay on [name]'s island again."))
			continue
		// A captive held by the faction stays where they are held.
		if (H.restrained())
			continue
		if (!H.island_unwelcome_since)
			H.island_unwelcome_since = world.time
			to_chat(H, SPAN_DANGER("You have no leave to be on [name]'s island. Leave within [ISLAND_EXILE_GRACE / 600] minutes, or you are put ashore in [html_encode(shard_group.peers[shard_group.start_region] ? shard_group.peers[shard_group.start_region]["name"] : "the start land")]."))
			continue
		if (world.time - H.island_unwelcome_since < ISLAND_EXILE_GRACE)
			continue
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(island_access_exile), H, claimant), 1)

/proc/island_access_exile(mob/living/human/H, claimant)
	set waitfor = FALSE
	if (QDELETED(H) || !isturf(H.loc) || island_access_admits(H, claimant))
		return
	H.stop_pulling()
	if (H.buckled)
		H.buckled.unbuckle_mob()
	region_admin_send_leave_behind(H) // what cannot travel stays on the island
	if (H.client)
		H.record_persistence_owner()
	var/obj/structure/region_gate/island_exile/gate = new(get_turf(H))
	gate.destination = shard_group.start_region
	var/result = gate.depart(H)
	qdel(gate)
	if (result == "departed")
		log_game("Island access: [H.persistence_owner_ckey] was put ashore in [shard_group.start_region] from [claimant]'s island.")
	else if (!QDELETED(H))
		H.island_unwelcome_since = world.time - ISLAND_EXILE_GRACE + 600 // try again in a minute
		to_chat(H, SPAN_WARNING("You cannot be put ashore elsewhere yet ([result]). Leave the island."))

#undef ISLAND_EXILE_GRACE
#undef ISLAND_UNIX_2000
