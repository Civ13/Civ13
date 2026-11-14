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
// - Abandon (the captain, as the ship leaves): the land is lost for good and
//   its world is archived. Whoever was homed there starts on the mainland.
// A land nobody settles or claims is abandoned after 7 days with nobody on it
// (the world directory, world_chart.py). Until a land is settled, a death
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

// Asked as the ship leaves a land nobody settled or claimed: TRUE to abandon it.
/obj/structure/hull_tiller/proc/abandon_choice(mob/living/human/H)
	if (!expedition_land_unsettled() || !expedition_land_key())
		return FALSE
	return WWinput(H, "Abandon this land for good as she leaves? Nobody can ever sail here again, and everything left here is lost. Leave it standing and it waits 7 days for a ship.", craft.name, "Leave it standing", list("Abandon it", "Leave it standing")) == "Abandon it"

#undef LAND_SETTLE_BEDS
#undef LAND_SETTLE_RANGE
