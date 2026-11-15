// ============================================================
// Settle, claim or abandon a land across the sea (docs/ship-voyage.md)
// ------------------------------------------------------------
// A land opened for a ship (an EXPEDITION region, expedition_land.dm) is
// undecided until its crew choose:
// - Settle (any crew member, at the tiller): a mooring post that takes ships
//   and LAND_SETTLE_BEDS claimed beds near it. The land stays for good, is on
//   everyone's chart and becomes a frontier land: beds keep homes.
// - Claim: a faction's leader plants its colony charter (colony_charter.dm).
//   One claim per faction, one faction per land. The land becomes a colony.
//   The colony's leader may give the claim up at the charter: it comes down
//   and the land drops back to the frontier, settled.
// - Claim for oneself (any player, at the tiller): a mooring post and their
//   own bed near it. One land each, besides any land their faction claims.
// - Abandon (the captain, as the ship leaves): the land is lost for good and
//   its world is archived. Whoever was homed there starts on the mainland.
// A land nobody settles or claims is abandoned after 7 days with nobody on it
// (the world directory, world_chart.py), and its crew can open no other new
// land while it stands. A land that stands empty may be laid up (parked on the
// host's disk) to free its slot for another; a ship sailing for it, or somebody
// who lives there coming back, has it made ready again (region_home.dm). Until a land is settled, a death
// there always sends the character home to the mainland: a bed does not count.
// ============================================================

#define LAND_SETTLE_BEDS 3
#define LAND_SETTLE_RANGE 40

// "x,y" of the chart tile this world's land was made from, or null.
/proc/expedition_land_key()
	if (!shard_group || shard_group.kind != "EXPEDITION")
		return null
	var/list/info = expedition_land()
	return (islist(info) && istext(info["key"])) ? info["key"] : null

// The chart's record of this land (state, region, template), or null.
/proc/expedition_land_tile()
	var/key = expedition_land_key()
	var/list/tiles = world_chart["tiles"]
	return (key && islist(tiles) && islist(tiles[key])) ? tiles[key] : null

// TRUE on a land across the sea nobody has settled or claimed yet.
/proc/expedition_land_unsettled()
	if (!shard_group || shard_group.kind != "EXPEDITION")
		return FALSE
	var/list/tile = expedition_land_tile()
	return !tile || !(tile["state"] in list("SETTLED", "CLAIMED"))

// Asks the world directory to settle, claim or abandon this land for the
// account by. owner: the claiming faction. TRUE when the request was taken.
/proc/expedition_land_ask(op, by, owner = null)
	var/key = expedition_land_key()
	if (!key || !transfer_bridge || !transfer_bridge.enabled())
		return FALSE
	var/list/xy = splittext(key, ",")
	if (length(xy) != 2)
		return FALSE
	var/list/body = list("op" = op, "x" = text2num(xy[1]), "y" = text2num(xy[2]), "admin" = by || "world")
	if (owner)
		body["owner"] = owner
	var/list/answer = transfer_bridge.request("/chart/request", body)
	if (!answer || !answer["ok"])
		return FALSE
	log_game("Expedition land: [by || "the world"] asked to [op] this land (chart tile [key][owner ? ", [owner]" : ""]).")
	return TRUE

// Why this land cannot be settled now, or null.
/proc/expedition_settle_refusal()
	if (!expedition_land_key())
		return "Only a land across the sea can be settled."
	var/list/tile = expedition_land_tile()
	if (tile && tile["state"] != "LANDED")
		return "This land is already [lowertext(tile["state"])]."
	var/best = 0
	for (var/obj/structure/berth/quay/Q in sea_harbours)
		if (QDELETED(Q) || !Q.takes_ships || !isturf(Q.loc))
			continue
		var/list/owners = list()
		for (var/obj/structure/bed/B in range(LAND_SETTLE_RANGE, Q))
			if (B.persistence_bed_owner_ckey && B.anchored && isturf(B.loc))
				owners |= B.persistence_bed_owner_ckey
		best = max(best, length(owners))
		if (best >= LAND_SETTLE_BEDS)
			return null
	if (!length(sea_harbours))
		return "Settling a land takes a mooring post on its coast and [LAND_SETTLE_BEDS] beds slept in by different people near it."
	return "Settling a land takes [LAND_SETTLE_BEDS] beds slept in by different people within [LAND_SETTLE_RANGE] tiles of a mooring post; the best has [best]."

/obj/structure/hull_tiller/proc/settle_menu(mob/living/human/H)
	world_chart_refresh()
	var/reason = expedition_settle_refusal()
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	if (WWinput(H, "Settle this land for good? It stays on everyone's chart for any ship to reach, and beds here keep their sleepers' homes.", craft.name, "No", list("Yes", "No")) != "Yes" || get_dist(H, src) > 1)
		return
	reason = expedition_settle_refusal()
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	if (!expedition_land_ask("settle", H.ckey))
		to_chat(H, SPAN_WARNING("No word can be sent to the world directory right now. Try again in a minute."))
		return
	to_chat(world, "<big><b>[html_encode(H.real_name)] settles this land.</b> It stays on every chart, for any ship to reach.</big>")

// ---------------------------------------------------------------- a land of one's own
// Every player may claim one land across the sea for themself, at the tiller:
// it takes a mooring post that takes ships and their own bed near it. The land
// is kept like a settled one and beds there keep homes. A faction's claim
// (its colony charter) is separate: a player may hold a land of their own and
// their faction another. One claimant a land.

// The chart's name for H's own claim.
/proc/expedition_personal_claimant(mob/living/human/H)
	if (!istype(H) || !H.ckey || IsGuestKey(H.key))
		return null
	return "crew:[H.ckey]"

// The same for a bare account (guests have none worth keeping).
/proc/expedition_account_claimant(account)
	return (istext(account) && length(account)) ? "crew:[account]" : null

// "Claim this land", "Give up your claim" or null: what the claimant me (crew:ckey) may do here at a tiller.
/proc/expedition_personal_claim_option(me)
	var/key = expedition_land_key()
	if (!key || !me)
		return null
	var/list/claims = islist(world_chart["claims"]) ? world_chart["claims"] : list()
	if (claims[me] == key)
		return "Give up your claim"
	var/list/tile = expedition_land_tile()
	if (islist(tile) && tile["state"] == "CLAIMED")
		return null
	return "Claim this land"

// Why the claimant me (crew:ckey) cannot claim this land for themself now, or null.
/proc/expedition_personal_claim_refusal(me)
	var/key = expedition_land_key()
	if (!key || !me)
		return "Only a land across the sea can be claimed."
	var/list/tile = expedition_land_tile()
	if (!islist(tile))
		return "The world directory does not know this land yet. Try again in a minute."
	if (tile["state"] == "CLAIMED")
		return "This land is already claimed."
	var/list/claims = islist(world_chart["claims"]) ? world_chart["claims"] : list()
	if (claims[me])
		return "You already claim the land at [claims[me]]. Each person claims one; give that claim up at a tiller there first."
	for (var/obj/structure/berth/quay/Q in sea_harbours)
		if (QDELETED(Q) || !Q.takes_ships || !isturf(Q.loc))
			continue
		for (var/obj/structure/bed/B in range(LAND_SETTLE_RANGE, Q))
			if ("crew:[B.persistence_bed_owner_ckey]" == me && B.anchored && isturf(B.loc))
				return null
	return "Claiming a land takes a mooring post on its coast and your own bed, slept in, within [LAND_SETTLE_RANGE] tiles of it."

/obj/structure/hull_tiller/proc/personal_claim_menu(mob/living/human/H)
	world_chart_refresh()
	var/me = expedition_personal_claimant(H)
	if (expedition_personal_claim_option(me) == "Give up your claim")
		if (WWinput(H, "Give up your claim on this land? It stays on every chart, settled, for anyone to claim, and you may claim another.", craft.name, "Keep the claim", list("Give up the claim", "Keep the claim")) != "Give up the claim" || get_dist(H, src) > 1)
			return
		if (!expedition_land_ask("unclaim", H.ckey, me))
			to_chat(H, SPAN_WARNING("No word can be sent to the world directory right now. Try again in a minute."))
			return
		to_chat(world, "<big><b>[html_encode(H.real_name)]</b> gives up their claim on this land.</big>")
		return
	var/reason = expedition_personal_claim_refusal(me)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	if (WWinput(H, "Claim this land as your own? It is kept for good and stays on every chart, and beds here keep their sleepers' homes. Each person claims one land.", craft.name, "No", list("Yes", "No")) != "Yes" || get_dist(H, src) > 1)
		return
	reason = expedition_personal_claim_refusal(me)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	if (!expedition_land_ask("claim", H.ckey, me))
		to_chat(H, SPAN_WARNING("No word can be sent to the world directory right now. Try again in a minute."))
		return
	to_chat(world, "<big><b>[html_encode(H.real_name)] claims this land as their own.</b> It stays on every chart.</big>")

// The parent faction whose claim on this land user may give up at this
// charter: the colony's leader, while the colony's parent holds the claim. Or null.
/obj/structure/colony_charter/proc/unclaim_parent(mob/living/human/user)
	var/key = expedition_land_key()
	if (!key || !faction || !map || user.civilization != faction || !user.leader || get_dist(user, src) > 1)
		return null
	var/list/row = map.faction_colonies()[faction]
	if (!islist(row) || !colony_parent_valid(row[1]))
		return null
	var/list/claims = islist(world_chart["claims"]) ? world_chart["claims"] : list()
	return claims[row[1]] == key ? row[1] : null

// A faction claims one land across the sea; to claim another it gives this
// one up. The charter comes down and the land stays, settled, on every chart.
/obj/structure/colony_charter/proc/unclaim_menu(mob/living/human/user)
	if (WWinput(user, "Give up [faction]'s claim on this land? The charter comes down and the land stays on every chart, open to any faction's claim. Your faction may then claim another land across the sea.", "Colony Charter", "Keep the claim", list("Give up the claim", "Keep the claim")) != "Give up the claim")
		return FALSE
	var/parent = unclaim_parent(user)
	if (!parent)
		return FALSE
	if (!expedition_land_ask("unclaim", user.ckey, parent))
		to_chat(user, SPAN_WARNING("No word can be sent to the world directory right now. Try again in a minute."))
		return FALSE
	map.recruitment_audit(faction, "[user.real_name] gave up the claim on this land and took the charter down.", faction_roster_account(user) || "")
	log_game("Colony: [key_name(user)] gave up [faction]'s claim ([parent]) on this land and took the charter down.")
	to_chat(world, "<big><b>[html_encode(faction)]</b> gives up its claim on this land.</big>")
	faction = null
	update_icon()
	return TRUE

// Asked as the ship leaves a land nobody settled or claimed: TRUE to abandon it.
/obj/structure/hull_tiller/proc/abandon_choice(mob/living/human/H)
	if (!expedition_land_unsettled() || !expedition_land_key())
		return FALSE
	return WWinput(H, "Abandon this land for good as she leaves? Nobody can ever sail here again, and everything left here is lost. Leave it standing and it waits 7 days for a ship, and your crew can open no other new land while it stands undecided.", craft.name, "Leave it standing", list("Abandon it", "Leave it standing")) == "Abandon it"

#undef LAND_SETTLE_BEDS
#undef LAND_SETTLE_RANGE
