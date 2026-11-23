// ============================================================
// Voyages on the world chart (boat expeditions, docs/ship-voyage.md)
// ------------------------------------------------------------
// A built hull lying off the edge of a mainland region, or of a land across
// the sea, can set out on a voyage across the world chart (world_chart.dm). Her crew pick a land their
// chart shows, or scout unknown water. About a minute a chart tile passes while
// she lies off the coast under way: nobody steers and nothing changes aboard.
//
// A course is sent to the world directory as soon as she sets out, so the
// land can be opened in a free expedition slot while she sails. At landfall,
// once the directory says the land is ready, she crosses to it like any ship
// leaving these waters (ship_crossing.dm). A scouting voyage charts the water
// she sailed through and ends where it began.
// ============================================================

#define VOYAGE_TICK 100 // deciseconds between looks at the voyage
#define VOYAGE_SCOUT_RANGE 4 // chart tiles out; she comes back the same way
#define VOYAGE_WAIT_MAX 18000 // deciseconds she waits off an unready coast before turning back
// Deciseconds a ship lies at anchor after a landfall before her next voyage or
// crossing. As long as an empty world takes to go to sleep (the host's
// freeze_idle_minutes, 15), so the land a crew left is asleep before they can
// wake a third: a crew hopping between lands keeps two worlds awake, not all.
#define VOYAGE_LANDFALL_REST 9000

/obj/structure/hull_tiller
	// The voyage she is on: id, kind ("course" or "scout"), x, y, owner,
	// label, ends (world.time), and for a course the region once known.
	var/tmp/list/voyage = null
	// world.time she made landfall here from another world (ship_crossing.dm); not saved.
	var/tmp/landfall_at = null

// Why she cannot put to sea for another world yet, or null: her crew rest
// after a landfall. Scouting wakes no world and needs no rest.
/obj/structure/hull_tiller/proc/landfall_rest_refusal()
	if (isnull(landfall_at) || world.time >= landfall_at + VOYAGE_LANDFALL_REST)
		return null
	var/minutes = max(1, round((landfall_at + VOYAGE_LANDFALL_REST - world.time) / 600, 1))
	return "Her crew have only just made landfall. She can put to sea for another land in about [minutes] minute\s."

// ---------------------------------------------------------------- the chart a crew sees

// The chart owner a crew sails for: the captain's faction, else the captain alone.
/proc/voyage_owner(mob/living/human/H)
	if (!istype(H))
		return null
	if (H.civilization && H.civilization != "none")
		var/faction = copytext(ckey(H.civilization), 1, 41)
		if (length(faction))
			return "faction:[faction]"
	var/who = copytext(ckey(H.ckey), 1, 41)
	return length(who) ? "crew:[who]" : null

// TRUE when owner's chart shows tile (x, y): a bit of the snapshot's seen mask.
/proc/voyage_seen(owner, x, y)
	var/list/masks = world_chart["seen"]
	var/width = world_chart["width"]
	if (!islist(masks) || !istext(masks[owner]) || !isnum(width))
		return FALSE
	var/mask = masks[owner]
	var/bit = y * width + x
	var/position = length(mask) - round(bit / 4)
	if (position < 1)
		return FALSE
	var/digit = text2num(copytext(mask, position, position + 1), 16)
	return (digit >> (bit % 4)) & 1

// The chart tile this world sits on: a land across the sea's own tile, else
// its own pin (the mainland is pinned when the chart is made). Other worlds
// (the Moon, Mars, the rail yard) are not on the chart.
/proc/voyage_origin()
	var/key = expedition_land_key()
	if (key)
		var/list/xy = splittext(key, ",")
		if (length(xy) == 2 && isnum(text2num(xy[1])) && isnum(text2num(xy[2])))
			return list(text2num(xy[1]), text2num(xy[2]))
		return null
	var/list/pins = world_chart["pins"]
	if (!islist(pins))
		return null
	var/list/at = pins[shard_group.region]
	if (!islist(at) || length(at) != 2 || !isnum(at[1]) || !isnum(at[2]))
		return null
	return at

/proc/voyage_distance(list/from, x, y)
	return max(1, max(abs(from[1] - x), abs(from[2] - y)))

// Lands owner's chart shows that a ship can make for:
// "label" = list(x, y, tiles).
/proc/voyage_destinations(owner, list/origin, mob/living/human/captain = null)
	. = list()
	var/list/tiles = world_chart["tiles"]
	if (!islist(tiles) || !owner || !origin)
		return
	for (var/key in tiles)
		var/list/found = tiles[key]
		if (!islist(found) || found["state"] == "LOST")
			continue
		var/list/template = found["template"]
		if (!islist(template) || !islist(template["coast"]) || !length(template["coast"]))
			continue
		var/list/xy = splittext(key, ",")
		if (length(xy) != 2)
			continue
		var/x = text2num(xy[1])
		var/y = text2num(xy[2])
		// A settled or claimed land is on everyone's chart; the land she lies off is not a voyage.
		if (!isnum(x) || !isnum(y) || (x == origin[1] && y == origin[2]))
			continue
		if (!voyage_seen(owner, x, y) && !(found["state"] in list("SETTLED", "CLAIMED")))
			continue
		// A faction's island shows only to a captain it lets land (island_access.dm).
		var/island = island_access_claimant_at(key)
		if (island && captain && !island_access_admits(captain, island))
			continue
		var/tiles_away = voyage_distance(origin, x, y)
		.["[capitalize(world_chart_tile_label(template))] at [x],[y]: [tiles_away] tile\s, about [tiles_away] minute\s[island ? " ([island_access_member(captain, island) ? "your faction's island" : "[party_train_party_name(island)]'s island"])" : ""][found["region"] ? " (a land already opened)" : (found["parked"] ? " (laid up: its harbour is made ready as she sails)" : "")]"] = list(x, y, tiles_away)

// The chart tile a scouting voyage turns round at, toward dir.
/proc/voyage_scout_target(list/origin, dir)
	var/width = world_chart["width"]
	var/height = world_chart["height"]
	if (!isnum(width) || !isnum(height))
		return null
	var/x = origin[1]
	var/y = origin[2]
	switch (dir)
		if (NORTH) y += VOYAGE_SCOUT_RANGE
		if (SOUTH) y -= VOYAGE_SCOUT_RANGE
		if (EAST) x += VOYAGE_SCOUT_RANGE
		if (WEST) x -= VOYAGE_SCOUT_RANGE
	return list(Clamp(x, 0, width - 1), Clamp(y, 0, height - 1))

// ---------------------------------------------------------------- at the tiller

/obj/structure/hull_tiller/proc/voyage_crew()
	. = list()
	var/datum/craft_body/built/B = body()
	if (!B)
		return
	for (var/mob/living/human/H in B.aboard())
		if (H.client && H.stat == CONSCIOUS)
			. += H

// Why she cannot set out on a voyage now, or null. One sailor aboard and
// awake is crew enough; she may carry as many as she holds.
/obj/structure/hull_tiller/proc/voyage_refusal(mob/living/human/H)
	if (voyage)
		return "She is already on a voyage."
	if (!shard_group || !shard_group.enabled)
		return "No world chart reaches these waters."
	var/reason = crossing_refusal(H)
	if (reason)
		return reason
	craft.fit_drives()
	if (craft.max_speed() < VESSEL_SPEED_SLOW)
		return "She cannot make a voyage without a way to sail: rig a mast or fit a running engine."
	if (!length(voyage_crew()))
		return "Somebody must be aboard and awake to sail her."
	// Whatever would stop her crossing at landfall stops her setting out (ship_crossing.dm).
	var/load = sea_crossing_load(src)
	if (istext(load))
		return load
	return null

/obj/structure/hull_tiller/proc/voyage_menu(mob/living/human/H)
	// Known lands across the sea (sea_lanes.dm) need no chart.
	// Over the map edges the continents are reached by sailing off them (ship_edge_crossing.dm).
	var/list/known = sea_edge_travel_on() ? list() : sea_lane_destinations()
	var/reason = voyage_refusal(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	world_chart_refresh()
	var/list/origin = voyage_origin()
	var/owner = voyage_owner(H)
	if (!length(known))
		if (!origin)
			to_chat(H, SPAN_WARNING("These waters are not on the world chart yet."))
			return
		if (!owner)
			to_chat(H, SPAN_WARNING("You cannot keep a chart."))
			return
	var/list/lands = list()
	var/list/scouting = list()
	if (origin && owner)
		lands = voyage_destinations(owner, origin, H)
		scouting = list("Scout the unknown water to the north" = NORTH, "Scout the unknown water to the east" = EAST,
			"Scout the unknown water to the south" = SOUTH, "Scout the unknown water to the west" = WEST)
	var/load = sea_crossing_load(src)
	var/text = isnum(load) ? "She is loaded to [load]% of what a crossing carries. " : ""
	if (length(known) || length(lands))
		text += "Where does she sail? A chart tile takes about a minute. Her crew are those aboard when she sets out."
	else
		text += "Your chart shows no land a ship can reach yet. Scout the unknown water to chart some: she sails [VOYAGE_SCOUT_RANGE] tiles out and back."
	var/choice = WWinput(H, text, craft.name, "Stay", known + lands + scouting + list("Stay"))
	if (!choice || choice == "Stay" || get_dist(H, src) > 1 || !craft)
		return
	if (choice in known)
		var/list/lane = known[choice]
		reason = landfall_rest_refusal() || voyage_refusal(H)
		if (reason)
			to_chat(H, SPAN_WARNING(reason))
			return
		var/place = copytext(choice, 1, findtext(choice, ","))
		if (WWinput(H, "Set out for [place]? Everyone aboard sails with her and makes their home there; whoever stays ashore is left behind.", craft.name, "No", list("Yes", "No")) != "Yes" || get_dist(H, src) > 1 || !craft)
			return
		if (!provisions_menu(H, lane[2]))
			return
		set_out(H, "lane", lane[1], 0, owner, lane[2], place)
		return
	reason = voyage_refusal(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	if (choice in scouting)
		var/list/target = voyage_scout_target(origin, scouting[choice])
		if (!target)
			return
		if (!provisions_menu(H, VOYAGE_SCOUT_RANGE * 2))
			return
		set_out(H, "scout", target[1], target[2], owner, VOYAGE_SCOUT_RANGE * 2, "the unknown water to the [dir2text(scouting[choice])]")
		return
	var/list/land = lands[choice]
	if (!islist(land))
		return
	reason = landfall_rest_refusal() || voyage_island_refusal(land[1], land[2])
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	if (WWinput(H, "Set out for [choice]? Everyone aboard sails with her; whoever stays ashore is left behind.", craft.name, "No", list("Yes", "No")) != "Yes" || get_dist(H, src) > 1 || !craft)
		return
	if (!provisions_menu(H, land[3]))
		return
	// Her crew may have changed while the prompts were open.
	reason = voyage_island_refusal(land[1], land[2])
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	// Sailing on from a land nobody settled or claimed, the captain may give it up (land_choices.dm).
	var/abandon = abandon_choice(H)
	if (set_out(H, "course", land[1], land[2], owner, land[3], copytext(choice, 1, findtext(choice, ":"))) && abandon && voyage)
		voyage["abandon"] = TRUE

// Sets her on a voyage of minutes chart tiles' time. A course asks the world
// directory for the land at once, so it can be opened while she sails. A
// "lane" voyage (sea_lanes.dm) sails for the region id x, already open.
/obj/structure/hull_tiller/proc/set_out(mob/living/human/H, kind, x, y, owner, tiles_time, label)
	// Her crew's prompts slept: another of them may have sent her somewhere meanwhile.
	var/reason = voyage ? "She is already on a voyage." : crossing_hold_refusal()
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return FALSE
	var/id = "[ckey(shard_group.region) || "world"]-[num2text(world.realtime, 20)]-[rand(1000, 9999)]"
	var/unconfirmed = FALSE
	if (kind == "course")
		// The directory may open a land for this course: nothing else sends her
		// anywhere while it is asked.
		var/list/hold = crossing_hold_take("plotting", null, id)
		var/list/answer = transfer_bridge.request("/chart/request", voyage_course_body(x, y, owner, H.ckey, id))
		if (!crossing_hold_is(hold))
			return FALSE
		crossing_hold_release(hold)
		if (voyage)
			return FALSE
		if (islist(answer) && !answer["ok"])
			to_chat(H, SPAN_WARNING("No word can be sent across the sea right now[istext(answer["error"]) ? ": [html_encode(answer["error"])]" : ""]. She stays."))
			return FALSE
		// No answer: the directory may have the course. She sails on it, asks
		// after it again under way with the same voyage, and never plots another.
		unconfirmed = !islist(answer)
	var/tile = voyage_tile_time() // read before she stops: engines sail faster
	var/crew = length(voyage_crew())
	craft.set_speed(VESSEL_SPEED_STOP)
	craft.set_anchor(TRUE)
	voyage = list("id" = id, "kind" = kind, "x" = x, "y" = y, "owner" = owner, "label" = label, "by" = H.ckey, "tile" = tile, "tiles" = tiles_time,
		"ends" = world.time + tiles_time * tile, "minute" = world.time + tile, "said" = null,
		"rations" = crew * tiles_time, "stores" = length(voyage_rations()), "events" = list(), "asked" = world.time + 300,
		"crew" = voyage_crew_accounts(), "course_body" = kind == "course" ? voyage_course_body(x, y, owner, H.ckey, id) : null, "unconfirmed" = unconfirmed)
	if (unconfirmed)
		log_game("Voyage: no answer to the [craft.name]'s course (voyage [id]); she sails on it and asks again under way.")
	log_game("Voyage: [key_name(H)] set the [craft.name] on a [kind] voyage to [kind == "lane" ? "the region [x]" : "chart tile [x],[y]"] for [owner || H.ckey] (voyage [id], [crew] crew, [voyage["stores"]]/[voyage["rations"]] rations).")
	var/minutes = round(tiles_time * tile / 600, 1)
	craft.crew_message(SPAN_NOTICE("[H] at the tiller: the [craft.name] sets out for [label]. About [max(1, minutes)] minute\s at sea. Stay aboard: whoever leaves her is left behind."))
	voyage_sea_show() // Her crew see the sea go by (voyage_sea.dm).
	addtimer(CALLBACK(src, PROC_REF(voyage_tick), voyage), VOYAGE_TICK)
	player_activity.voyage(H, kind)
	accolade_meet_mob(H, "sailor")
	return TRUE

// Why she cannot sail for the land at chart tile (x, y), or null: a faction's
// island takes only those it lets land, and all aboard sail (island_access.dm).
/obj/structure/hull_tiller/proc/voyage_island_refusal(x, y)
	var/island = island_access_claimant_at("[x],[y]")
	if (!island)
		return null
	var/datum/craft_body/built/B = body()
	if (!B)
		return null
	for (var/mob/living/human/M in B.aboard())
		var/reason = island_access_refusal(M, island)
		if (reason)
			return "She cannot sail there: [reason]. Put them ashore first."
	return null

/proc/voyage_course_body(x, y, owner, by, id)
	return list("op" = "course", "x" = x, "y" = y, "owner" = owner, "admin" = by, "voyage" = id)

// The accounts of her crew aboard and awake: who sailed with her.
/obj/structure/hull_tiller/proc/voyage_crew_accounts()
	. = list()
	for (var/mob/living/human/H in voyage_crew())
		if (H.client && !IsGuestKey(H.client.key))
			. |= H.client.ckey

// A course the directory never answered is asked again, with the same voyage:
// the directory gives back the course it has, or plots it now, never a second.
/obj/structure/hull_tiller/proc/voyage_confirm_course(list/mine, list/course)
	if (!mine["unconfirmed"])
		return
	if (islist(course))
		mine["unconfirmed"] = FALSE
		return
	var/list/answer = transfer_bridge.request("/chart/request", mine["course_body"])
	if (islist(answer) && answer["ok"])
		mine["unconfirmed"] = FALSE
		world_chart_refresh()

/obj/structure/hull_tiller/proc/voyage_status_text()
	if (!voyage)
		return ""
	var/left = round((voyage["ends"] - world.time) / 600, 1)
	if (left > 0)
		return "The [craft.name] is at sea, bound for [voyage["label"]]: about [left] minute\s to go."
	return (voyage["kind"] in list("course", "lane")) ? "The [craft.name] stands off [voyage["label"]]. The coast is not yet in sight." : "The [craft.name] is coming back from [voyage["label"]]."

/obj/structure/hull_tiller/proc/voyage_status_menu(mob/living/human/H)
	// Bound for a land that was asked to wake: she holds her course for it.
	var/held = crossing_hold_text()
	if (held)
		WWinput(H, held, craft.name, "Cancel", list("Cancel"))
		return
	var/choice = WWinput(H, voyage_status_text(), craft.name, "Cancel", list("Turn back", "Cancel"))
	if (choice != "Turn back" || !voyage || get_dist(H, src) > 1)
		return
	var/reason = voyage_turn_back(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))

// H turns her back. Null when she turned, else why not. Once word was sent
// ahead for her (ship_crossing.dm) she holds her course instead.
/obj/structure/hull_tiller/proc/voyage_turn_back(mob/living/human/H)
	if (!voyage || !craft)
		return "She is not on a voyage."
	if (craft.helm_access(H) != CRAFT_HELM_FREE)
		return "Only her crew can turn her back."
	var/held = crossing_hold_text()
	if (held)
		return "She cannot turn back now. [held]"
	log_game("Voyage: [key_name(H)] turned the [craft.name] back (voyage [voyage["id"]]).")
	end_voyage(SPAN_NOTICE("[H] at the tiller: the [craft.name] turns back. She lies off the coast where she set out."))
	return null

// Ends her voyage. What she was bound for on it ends too, unless a crossing is
// still at work on it.
/obj/structure/hull_tiller/proc/end_voyage(text)
	var/list/hold = crossing_hold
	if (hold && !hold["busy"] && islist(voyage) && hold["voyage"] == voyage["id"])
		crossing_hold_release(hold)
	voyage = null
	voyage_sea_stop()
	if (craft && text)
		craft.crew_message(text)

// Looks at the voyage every VOYAGE_TICK until she makes landfall, turns back
// or is gone. Landfall may wait on a waking world, so the timer never waits.
/obj/structure/hull_tiller/proc/voyage_tick(list/mine)
	set waitfor = FALSE
	if (voyage != mine || QDELETED(src) || !craft)
		if (!voyage && !QDELETED(src))
			voyage_sea_stop()
		return
	voyage_sea_show() // Whoever is aboard now sees the sea go by.
	if (world.time < mine["ends"])
		// A course refused (no harbour free, a land opened too lately) turns her back
		// within a minute or two, before she has sailed the whole way for nothing.
		if (mine["kind"] == "course" && voyage_refused_under_way(mine))
			return
		if (world.time >= mine["minute"])
			mine["minute"] = world.time + mine["tile"]
			if (!voyage_event(mine))
				craft.crew_message(SPAN_NOTICE(voyage_status_text()))
	else if (mine["kind"] == "scout")
		voyage_scouted(mine)
		return
	else if (mine["kind"] == "lane")
		if (voyage_lane_landfall(mine))
			return
	else if (voyage_landfall(mine))
		return
	if (voyage == mine && !QDELETED(src))
		addtimer(CALLBACK(src, PROC_REF(voyage_tick), mine), VOYAGE_TICK)

// TRUE when her course was refused while she is still at sea: she turned back.
/obj/structure/hull_tiller/proc/voyage_refused_under_way(list/mine)
	if (world.time < mine["asked"])
		return FALSE
	mine["asked"] = world.time + 600
	world_chart_refresh()
	var/list/courses = world_chart["courses"]
	var/list/course = islist(courses) ? courses[mine["id"]] : null
	voyage_confirm_course(mine, course)
	if (voyage != mine)
		return TRUE
	if (!islist(course) || course["state"] != "REFUSED")
		return FALSE
	log_game("Voyage: the [craft.name]'s course was refused under way: [course["reason"]] (voyage [mine["id"]]).")
	end_voyage(SPAN_WARNING("Word reaches the [craft.name] and she turns back: [course["reason"]]."))
	return TRUE

// A scouting voyage is home: what she saw goes on her owner's chart.
/obj/structure/hull_tiller/proc/voyage_scouted(list/mine)
	var/list/origin = voyage_origin()
	var/list/asked = list(list(mine["x"], mine["y"]))
	if (origin)
		asked.Insert(1, list(round((origin[1] + mine["x"]) / 2), round((origin[2] + mine["y"]) / 2)))
	for (var/list/at in asked)
		transfer_bridge.request("/chart/request", list("op" = "scout", "x" = at[1], "y" = at[2], "owner" = mine["owner"], "admin" = mine["by"]))
	voyage_eat(mine)
	log_game("Voyage: the [craft.name] came back from scouting chart tile [mine["x"]],[mine["y"]] (voyage [mine["id"]]).")
	end_voyage(SPAN_NOTICE("The [craft.name] is back from [mine["label"]]. What her crew saw goes on your chart within a minute."))

// TRUE when the voyage is over (she crossed or turned back); FALSE to wait.
/obj/structure/hull_tiller/proc/voyage_landfall(list/mine)
	world_chart_refresh()
	var/list/courses = world_chart["courses"]
	var/list/course = islist(courses) ? courses[mine["id"]] : null
	var/overdue = world.time > mine["ends"] + VOYAGE_WAIT_MAX
	voyage_confirm_course(mine, course)
	if (voyage != mine)
		return TRUE
	if (islist(course) && course["state"] == "REFUSED")
		log_game("Voyage: the [craft.name]'s course was refused: [course["reason"]] (voyage [mine["id"]]).")
		end_voyage(SPAN_WARNING("The [craft.name] turns back: [course["reason"]]."))
		return TRUE
	var/problem = null
	if (!islist(course) || course["state"] != "READY")
		problem = "The coast is not yet in sight."
	else
		var/id = course["region"]
		var/list/peer = shard_group.peers[id]
		if (!peer || !(peer["state"] == "UP" || shard_group.peer_wakeable(id)))
			problem = "The coast is not yet in sight."
		else
			voyage_eat(mine) // what she ate at sea stays behind
			problem = cross(id, null, mine["id"])
			if (!problem)
				if (mine["abandon"])
					expedition_land_ask("abandon", mine["by"])
				return TRUE
	if (overdue)
		log_game("Voyage: the [craft.name] gave up waiting off chart tile [mine["x"]],[mine["y"]]: [problem] (voyage [mine["id"]]).")
		end_voyage(SPAN_WARNING("The [craft.name] turns back: [problem]"))
		return TRUE
	if (mine["said"] != problem)
		mine["said"] = problem
		craft.crew_message(SPAN_NOTICE("[problem] The [craft.name] stands off and waits."))
	return FALSE

// A voyage along a sea lane (sea_lanes.dm) is over the sea: she crosses to the
// known land at once, or waits off its coast while its world wakes. TRUE when
// the voyage is over.
/obj/structure/hull_tiller/proc/voyage_lane_landfall(list/mine)
	var/id = mine["x"]
	var/list/peer = shard_group.peers[id]
	var/overdue = world.time > mine["ends"] + VOYAGE_WAIT_MAX
	var/problem = null
	if (!peer || shard_group.peer_closed(id) || !(peer["state"] == "UP" || shard_group.peer_wakeable(id)))
		problem = "The coast is not yet in sight."
	else
		voyage_eat(mine) // what she ate at sea stays behind
		problem = cross(id, null, mine["id"])
		if (!problem)
			return TRUE
	if (overdue)
		log_game("Voyage: the [craft.name] gave up waiting off [id]: [problem] (voyage [mine["id"]]).")
		end_voyage(SPAN_WARNING("The [craft.name] turns back: [problem]"))
		return TRUE
	if (mine["said"] != problem)
		mine["said"] = problem
		craft.crew_message(SPAN_NOTICE("[problem] The [craft.name] stands off and waits."))
	return FALSE

#undef VOYAGE_TICK
#undef VOYAGE_SCOUT_RANGE
#undef VOYAGE_WAIT_MAX
#undef VOYAGE_LANDFALL_REST
