// ============================================================
// Voyages on the world chart (boat expeditions, docs/ship-voyage.md)
// ------------------------------------------------------------
// A built hull lying off the edge of a mainland region can set out on a
// voyage across the world chart (world_chart.dm). Her crew pick a land their
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
#define VOYAGE_TILE_TIME 600 // deciseconds a chart tile takes
#define VOYAGE_MIN_CREW 2
#define VOYAGE_SCOUT_RANGE 4 // chart tiles out; she comes back the same way
#define VOYAGE_WAIT_MAX 18000 // deciseconds she waits off an unready coast before turning back

/obj/structure/hull_tiller
	// The voyage she is on: id, kind ("course" or "scout"), x, y, owner,
	// label, ends (world.time), and for a course the region once known.
	var/tmp/list/voyage = null

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

// The chart tile this world sits on: its own pin, else the mainland's.
/proc/voyage_origin()
	var/list/pins = world_chart["pins"]
	if (!islist(pins))
		return null
	var/list/at = pins[shard_group.region]
	if (!islist(at))
		at = pins[shard_group.mainland]
	if (!islist(at) || length(at) != 2 || !isnum(at[1]) || !isnum(at[2]))
		return null
	return at

/proc/voyage_distance(list/from, x, y)
	return max(1, max(abs(from[1] - x), abs(from[2] - y)))

// Lands owner's chart shows that a ship can make for:
// "label" = list(x, y, tiles).
/proc/voyage_destinations(owner, list/origin)
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
		if (!isnum(x) || !isnum(y) || !voyage_seen(owner, x, y))
			continue
		var/tiles_away = voyage_distance(origin, x, y)
		.["[capitalize(world_chart_tile_label(template))] at [x],[y]: [tiles_away] tile\s, about [tiles_away] minute\s[found["region"] ? " (a land already opened)" : ""]"] = list(x, y, tiles_away)

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

// Why she cannot set out on a voyage now, or null.
/obj/structure/hull_tiller/proc/voyage_refusal(mob/living/human/H)
	if (voyage)
		return "She is already on a voyage."
	if (!shard_group || !shard_group.enabled || shard_group.kind == "EXPEDITION")
		return "No world chart reaches these waters."
	var/reason = crossing_refusal(H)
	if (reason)
		return reason
	if (length(voyage_crew()) < VOYAGE_MIN_CREW)
		return "A voyage needs at least [VOYAGE_MIN_CREW] of her crew aboard and awake."
	return null

/obj/structure/hull_tiller/proc/voyage_menu(mob/living/human/H)
	var/reason = voyage_refusal(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	world_chart_refresh()
	var/list/origin = voyage_origin()
	if (!origin)
		to_chat(H, SPAN_WARNING("These waters are not on the world chart yet."))
		return
	var/owner = voyage_owner(H)
	if (!owner)
		to_chat(H, SPAN_WARNING("You cannot keep a chart."))
		return
	var/list/lands = voyage_destinations(owner, origin)
	var/list/scouting = list("Scout the unknown water to the north" = NORTH, "Scout the unknown water to the east" = EAST,
		"Scout the unknown water to the south" = SOUTH, "Scout the unknown water to the west" = WEST)
	var/text = length(lands) ? "Where does she sail? A chart tile takes about a minute. Her crew are those aboard when she sets out." : "Your chart shows no land a ship can reach yet. Scout the unknown water to chart some: she sails [VOYAGE_SCOUT_RANGE] tiles out and back."
	var/choice = WWinput(H, text, craft.name, "Stay", lands + scouting + list("Stay"))
	if (!choice || choice == "Stay" || get_dist(H, src) > 1 || !craft)
		return
	reason = voyage_refusal(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	if (choice in scouting)
		var/list/target = voyage_scout_target(origin, scouting[choice])
		if (!target)
			return
		set_out(H, "scout", target[1], target[2], owner, VOYAGE_SCOUT_RANGE * 2, "the unknown water to the [dir2text(scouting[choice])]")
		return
	var/list/land = lands[choice]
	if (!islist(land))
		return
	if (WWinput(H, "Set out for [choice]? Everyone aboard sails with her; whoever stays ashore is left behind.", craft.name, "No", list("Yes", "No")) != "Yes" || get_dist(H, src) > 1 || !craft)
		return
	set_out(H, "course", land[1], land[2], owner, land[3], copytext(choice, 1, findtext(choice, ":")))

// Sets her on a voyage of minutes chart tiles' time. A course asks the world
// directory for the land at once, so it can be opened while she sails.
/obj/structure/hull_tiller/proc/set_out(mob/living/human/H, kind, x, y, owner, tiles_time, label)
	var/id = "[ckey(shard_group.region) || "world"]-[num2text(world.realtime, 20)]-[rand(1000, 9999)]"
	if (kind == "course")
		var/list/answer = transfer_bridge.request("/chart/request", list("op" = "course", "x" = x, "y" = y, "owner" = owner, "admin" = H.ckey, "voyage" = id))
		if (!answer || !answer["ok"])
			to_chat(H, SPAN_WARNING("No word can be sent across the sea right now[answer && istext(answer["error"]) ? ": [html_encode(answer["error"])]" : ""]. She stays."))
			return FALSE
	craft.set_speed(VESSEL_SPEED_STOP)
	craft.set_anchor(TRUE)
	voyage = list("id" = id, "kind" = kind, "x" = x, "y" = y, "owner" = owner, "label" = label, "by" = H.ckey, "ends" = world.time + tiles_time * VOYAGE_TILE_TIME, "minute" = world.time + VOYAGE_TILE_TIME, "said" = null)
	log_game("Voyage: [key_name(H)] set the [craft.name] on a [kind] voyage to chart tile [x],[y] for [owner] (voyage [id], [length(voyage_crew())] crew).")
	craft.crew_message(SPAN_NOTICE("[H] at the tiller: the [craft.name] sets out for [label]. About [tiles_time] minute\s at sea. Stay aboard: whoever leaves her is left behind."))
	addtimer(CALLBACK(src, PROC_REF(voyage_tick), voyage), VOYAGE_TICK)
	return TRUE

/obj/structure/hull_tiller/proc/voyage_status_text()
	if (!voyage)
		return ""
	var/left = round((voyage["ends"] - world.time) / VOYAGE_TILE_TIME, 1)
	if (left > 0)
		return "The [craft.name] is at sea, bound for [voyage["label"]]: about [left] minute\s to go."
	return voyage["kind"] == "course" ? "The [craft.name] stands off [voyage["label"]]. The coast is not yet in sight." : "The [craft.name] is coming back from [voyage["label"]]."

/obj/structure/hull_tiller/proc/voyage_status_menu(mob/living/human/H)
	var/choice = WWinput(H, voyage_status_text(), craft.name, "Cancel", list("Turn back", "Cancel"))
	if (choice != "Turn back" || !voyage || get_dist(H, src) > 1)
		return
	if (craft.helm_access(H) != CRAFT_HELM_FREE)
		to_chat(H, SPAN_WARNING("Only her crew can turn her back."))
		return
	log_game("Voyage: [key_name(H)] turned the [craft.name] back (voyage [voyage["id"]]).")
	end_voyage(SPAN_NOTICE("[H] at the tiller: the [craft.name] turns back. She lies off the coast where she set out."))

/obj/structure/hull_tiller/proc/end_voyage(text)
	voyage = null
	if (craft && text)
		craft.crew_message(text)

// Looks at the voyage every VOYAGE_TICK until she makes landfall, turns back
// or is gone. Landfall may wait on a waking world, so the timer never waits.
/obj/structure/hull_tiller/proc/voyage_tick(list/mine)
	set waitfor = FALSE
	if (voyage != mine || QDELETED(src) || !craft)
		return
	if (world.time < mine["ends"])
		if (world.time >= mine["minute"])
			mine["minute"] = world.time + VOYAGE_TILE_TIME
			craft.crew_message(SPAN_NOTICE(voyage_status_text()))
	else if (mine["kind"] == "scout")
		voyage_scouted(mine)
		return
	else if (voyage_landfall(mine))
		return
	if (voyage == mine && !QDELETED(src))
		addtimer(CALLBACK(src, PROC_REF(voyage_tick), mine), VOYAGE_TICK)

// A scouting voyage is home: what she saw goes on her owner's chart.
/obj/structure/hull_tiller/proc/voyage_scouted(list/mine)
	var/list/origin = voyage_origin()
	var/list/asked = list(list(mine["x"], mine["y"]))
	if (origin)
		asked.Insert(1, list(round((origin[1] + mine["x"]) / 2), round((origin[2] + mine["y"]) / 2)))
	for (var/list/at in asked)
		transfer_bridge.request("/chart/request", list("op" = "scout", "x" = at[1], "y" = at[2], "owner" = mine["owner"], "admin" = mine["by"]))
	log_game("Voyage: the [craft.name] came back from scouting chart tile [mine["x"]],[mine["y"]] (voyage [mine["id"]]).")
	end_voyage(SPAN_NOTICE("The [craft.name] is back from [mine["label"]]. What her crew saw goes on your chart within a minute."))

// TRUE when the voyage is over (she crossed or turned back); FALSE to wait.
/obj/structure/hull_tiller/proc/voyage_landfall(list/mine)
	world_chart_refresh()
	var/list/courses = world_chart["courses"]
	var/list/course = islist(courses) ? courses[mine["id"]] : null
	var/overdue = world.time > mine["ends"] + VOYAGE_WAIT_MAX
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
			problem = cross(id, null, mine["id"])
			if (!problem)
				return TRUE
	if (overdue)
		log_game("Voyage: the [craft.name] gave up waiting off chart tile [mine["x"]],[mine["y"]]: [problem] (voyage [mine["id"]]).")
		end_voyage(SPAN_WARNING("The [craft.name] turns back: [problem]"))
		return TRUE
	if (mine["said"] != problem)
		mine["said"] = problem
		craft.crew_message(SPAN_NOTICE("[problem] The [craft.name] stands off and waits."))
	return FALSE

#undef VOYAGE_TICK
#undef VOYAGE_TILE_TIME
#undef VOYAGE_MIN_CREW
#undef VOYAGE_SCOUT_RANGE
#undef VOYAGE_WAIT_MAX
