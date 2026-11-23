// Voyages on the world chart (code/modules/naval/ship_voyage.dm,
// docs/ship-voyage.md): the chart a crew sees, setting out, and landfall
// waiting on the world directory's answer to her course; on a land across the
// sea, onward voyages and what settling takes (land_choices.dm).
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/probe_chart()
	// 8 x 4 chart. The owner has seen (1,2) and (5,0): bits 17 and 5.
	world_chart = list("key" = "probe:1", "width" = 8, "height" = 4, "rows" = list("........", "........", "........", "........"),
		"pins" = list("gaia" = list(4, 2)),
		"seen" = list("faction:romeempire" = "00020020"),
		"tiles" = list(
			"1,2" = list("state" = "CHARTED", "region" = null, "template" = list("biome" = "DESERT", "land_type" = "COASTAL_PLAIN", "size" = "TINY", "coast" = list("S"))),
			"5,0" = list("state" = "CHARTED", "region" = null, "template" = list("biome" = "SWAMP", "land_type" = "MARSH", "size" = "SMALL", "coast" = list())),
			"6,3" = list("state" = "CHARTED", "region" = null, "template" = list("biome" = "TUNDRA", "land_type" = "FJORD_COAST", "size" = "SMALL", "coast" = list("N")))),
		"courses" = list())

/proc/naval_checks()
	naval_fixture()
	// ---- The chart a crew sees ----
	var/mob/living/human/naval_probe/H = new(locate(10, 10, 2))
	H.civilization = "Rome Empire"
	naval_check(voyage_owner(H) == "faction:romeempire", "a crew sails for their faction ([voyage_owner(H)])")
	probe_chart()
	naval_check(voyage_seen("faction:romeempire", 1, 2) && voyage_seen("faction:romeempire", 5, 0), "the seen mask shows the tiles the owner saw")
	naval_check(!voyage_seen("faction:romeempire", 6, 3) && !voyage_seen("faction:romeempire", 0, 0) && !voyage_seen("faction:gaul", 1, 2), "and no others, nor to another owner")
	shard_group.region = "gaia"
	shard_group.mainland = "gaia"
	var/list/origin = voyage_origin()
	naval_check(islist(origin) && origin[1] == 4 && origin[2] == 2, "this world sits on its pinned tile")
	var/list/lands = voyage_destinations("faction:romeempire", origin)
	naval_check(lands.len == 1, "only a seen land with a coast can be sailed for ([lands.len])")
	var/label = lands.len ? lands[1] : ""
	var/list/land = lands.len ? lands[label] : null
	naval_check(islist(land) && land[1] == 1 && land[2] == 2 && land[3] == 3, "it lies 3 tiles away ([label])")
	naval_check(findtext(label, "Tiny desert, coastal plain at 1,2: 3 tiles, about 3 minutes"), "the crew read its size, biome and voyage time")
	var/list/north = voyage_scout_target(origin, NORTH)
	var/list/west = voyage_scout_target(origin, WEST)
	naval_check(north[1] == 4 && north[2] == 3 && west[1] == 0 && west[2] == 2, "scouting turns round within the chart")

	// ---- Setting out ----
	for (var/x = 62, x <= 65, x++)
		for (var/y = 30, y <= 32, y++)
			hull_lay(x, y)
	var/obj/structure/hull_tiller/tiller = new(locate(63, 31, 2))
	naval_check(isnull(tiller.commission("Tern", EAST)) && tiller.craft, "the Tern is commissioned off the east edge")
	shard_group.enabled = FALSE
	naval_check(findtext(tiller.voyage_refusal(H), "No world chart"), "a world outside a region group has no voyages")
	shard_group.enabled = TRUE
	shard_group.kind = "SURFACE"
	tiller.craft.set_anchor(FALSE)
	naval_check(tiller.set_out(H, "scout", 4, 3, "faction:romeempire", 8, "the unknown water to the north"), "she sets out to scout")
	naval_check(tiller.voyage && tiller.voyage["kind"] == "scout" && tiller.craft.anchored && !tiller.craft.speed, "she lies at anchor under way on the chart")
	naval_check(findtext(tiller.voyage_status_text(), "about 8 minutes to go"), "the tiller tells how long ([tiller.voyage_status_text()])")
	// Live report (2026-11-15): at anchor on a voyage she looked becalmed.
	// Her crew see the sea go by instead (voyage_sea.dm).
	var/datum/voyage_sea/sea = tiller.voyage_sea
	naval_check(sea && sea.heading == EAST && length(sea.images) > 100, "the water round her is drawn going by ([sea ? length(sea.images) : 0] tiles)")
	var/sea_ok = sea != null
	if (sea)
		for (var/image/I in sea.images)
			var/turf/T = I.loc
			if (!I.override || !is_liquid_water(T) || get_dist(T, tiller) > 30)
				sea_ok = FALSE
	var/under_ok = TRUE
	for (var/turf/T in tiller.craft.body.cells())
		var/found = FALSE
		for (var/image/I in sea.images)
			if (I.loc == T)
				found = TRUE
				break
		if (!found)
			under_ok = FALSE
	naval_check(sea_ok, "only water round her is drawn going by")
	naval_check(under_ok, "including the water under her planks, so none is missing behind her stern")
	naval_check(sea && !length(sea.watchers), "nobody without a client is shown it")
	tiller.end_voyage(null)
	naval_check(isnull(tiller.voyage), "a voyage ends at the tiller")
	naval_check(!tiller.voyage_sea && QDELETED(sea) && !length(sea.images), "and the sea stops going by")

	// ---- Provisions, speed and happenings (voyage_provisions.dm) ----
	naval_check(tiller.voyage_tile_time() == 600, "under sail a chart tile takes a minute")
	var/obj/structure/closet/crate/hold = new(locate(64, 30, 2))
	for (var/i = 1, i <= 3, i++)
		new /obj/item/weapon/reagent_containers/food/snacks/sliceable/bread(hold)
	new /obj/item/weapon/reagent_containers/food/snacks/sliceable/bread(locate(62, 30, 2))
	naval_check(length(tiller.voyage_rations()) == 4, "food in her hold and on her deck counts as rations ([length(tiller.voyage_rations())])")
	tiller.set_out(H, "scout", 4, 3, "faction:romeempire", 8, "the unknown water to the north")
	var/list/fed = tiller.voyage
	naval_check(fed["stores"] == 4 && fed["rations"] == fed["tiles"] * length(tiller.voyage_crew()), "she reckons the rations her crew need ([fed["stores"]] of [fed["rations"]])")
	fed["ends"] = world.time + 3 * fed["tile"]
	fed["rations"] = 10 // as if 2 crew sail 5 tiles on 4 rations
	naval_check(tiller.voyage_event(fed) && ("short" in fed["events"]), "past halfway on short rations the crew are warned")
	var/ends = fed["ends"]
	naval_check(tiller.voyage_storm(fed) && fed["storm_until"] > world.time, "a squall gives the crew time to stow cargo")
	naval_check(fed["ends"] == ends && length(tiller.voyage_rations()) == 4, "a warning alone changes no destination, time or cargo")
	var/obj/item/loose = tiller.voyage_loose_cargo()
	naval_check(loose && loose.loc == locate(62, 30, 2), "only exposed loose cargo can wash overboard")
	loose.forceMove(hold)
	naval_check(!tiller.voyage_loose_cargo(), "stowing the loose item protects it")
	naval_check(!tiller.voyage_storm_resolve(fed.Copy(), TRUE), "a stale squall choice changes nothing")
	naval_check(tiller.voyage_storm_resolve(fed) && !fed["storm_until"] && fed["ends"] == ends + fed["tile"], "detouring safely costs one chart tile's time")
	naval_check(!tiller.voyage_storm_resolve(fed, TRUE) && !tiller.voyage_storm(fed), "a resolved squall cannot be chosen or rolled again")
	naval_check(length(tiller.voyage_rations()) == 4, "detour leaves all cargo aboard")
	fed["rations"] = 2
	tiller.voyage_eat(fed)
	naval_check(length(tiller.voyage_rations()) <= 2, "at landfall the crew eat what the voyage needed")
	var/rations_left = length(tiller.voyage_rations())
	tiller.voyage_eat(fed)
	naval_check(length(tiller.voyage_rations()) == rations_left, "and only once")
	tiller.end_voyage(null)
	// ---- Her load is measured before she sails (ship_crossing.dm) ----
	var/load = tiller.craft ? sea_crossing_load(tiller) : null
	naval_check(isnum(load) && load >= 0 && load <= 100, "her load is measured as a share of what a crossing carries ([load])")
	// Beds, barrels and animals cross now (ship_crossing_cargo.dm); an animal
	// somebody plays never does.
	var/mob/living/simple_animal/chicken/cot = new(locate(65, 32, 2))
	cot.ckey = "voyageprobehen"
	load = sea_crossing_load(tiller)
	naval_check(istext(load) && findtext(load, "Put these ashore first"), "what would stop her at landfall stops her at the tiller ([load])")
	cot.ckey = null
	qdel(cot)

	// ---- Landfall waits on the world directory ----
	tiller.voyage = list("id" = "gaia-1-2", "kind" = "course", "x" = 1, "y" = 2, "owner" = "faction:romeempire", "label" = "a desert", "by" = "probe", "ends" = world.time - 10, "said" = null)
	var/list/mine = tiller.voyage
	naval_check(!tiller.voyage_landfall(mine) && tiller.voyage == mine && mine["said"] == "The coast is not yet in sight.", "with no answer yet she waits off the coast")
	world_chart["courses"] = list("gaia-1-2" = list("state" = "ASSIGNED", "region" = "far1"))
	naval_check(!tiller.voyage_landfall(mine) && tiller.voyage == mine, "and while the land is being opened")
	world_chart["courses"] = list("gaia-1-2" = list("state" = "READY", "region" = "far1"))
	naval_check(!tiller.voyage_landfall(mine) && tiller.voyage == mine, "and while its world does not answer")
	mine["ends"] = world.time - 18010
	naval_check(tiller.voyage_landfall(mine) && isnull(tiller.voyage), "she turns back after waiting too long")
	tiller.voyage = mine = list("id" = "gaia-3-4", "kind" = "course", "x" = 1, "y" = 2, "owner" = "faction:romeempire", "label" = "a desert", "by" = "probe", "ends" = world.time - 10, "said" = null)
	world_chart["courses"] = list("gaia-3-4" = list("state" = "REFUSED", "reason" = "every harbour master is busy"))
	naval_check(tiller.voyage_landfall(mine) && isnull(tiller.voyage), "a refused course turns her back at once")
	naval_check(tiller.craft && !QDELETED(tiller), "she is still here, off the coast where she set out")

	// ---- A course refused while she is still at sea turns her back early ----
	tiller.voyage = mine = list("id" = "gaia-5-6", "kind" = "course", "x" = 1, "y" = 2, "owner" = "faction:romeempire", "label" = "a desert", "by" = "probe", "ends" = world.time + 6000, "said" = null, "asked" = world.time + 300)
	world_chart["courses"] = list("gaia-5-6" = list("state" = "REFUSED", "reason" = "your crew opened a new land not long ago"))
	naval_check(!tiller.voyage_refused_under_way(mine) && tiller.voyage == mine, "she asks after her course only now and then")
	mine["asked"] = world.time
	world_chart["courses"] = list("gaia-5-6" = list("state" = "ASSIGNED", "region" = "far1"))
	naval_check(!tiller.voyage_refused_under_way(mine) && tiller.voyage == mine && mine["asked"] > world.time, "a course being opened keeps her sailing")
	mine["asked"] = world.time
	world_chart["courses"] = list("gaia-5-6" = list("state" = "REFUSED", "reason" = "your crew opened a new land not long ago"))
	naval_check(tiller.voyage_refused_under_way(mine) && isnull(tiller.voyage), "a course refused under way turns her back before landfall")

	// ---- Her crew rest after a landfall (as long as an empty world takes to sleep) ----
	naval_check(isnull(tiller.landfall_rest_refusal()), "a ship that made no landfall may sail")
	tiller.landfall_at = world.time
	naval_check(findtext(tiller.landfall_rest_refusal(), "about 15 minutes"), "after a landfall she lies 15 minutes ([tiller.landfall_rest_refusal()])")
	tiller.landfall_at = world.time - 8400
	naval_check(findtext(tiller.landfall_rest_refusal(), "about 1 minute."), "and is told how long is left")
	tiller.landfall_at = world.time - 9000
	naval_check(isnull(tiller.landfall_rest_refusal()), "then she may put to sea again")
	tiller.landfall_at = null

	// ---- Sea routes between the continents (sea_lanes.dm) ----
	naval_check(continent_distance("northamerica", "gaia") == 6 && continent_bearing("northamerica", "gaia") == "east", "Gaia lies 6 tiles east of North America")
	naval_check(continent_bearing("gaia", "southamerica") == "southwest" && continent_distance("gaia", "asia") == 12, "and Asia 12 tiles east of Gaia ([continent_bearing("gaia", "southamerica")])")
	naval_check(isnull(continent_distance("gaia", "far1")) && !continent_coastal("railyard") && continent_coastal("jungle") && continent_coastal("desert"), "unknown lands have no route; the Jungle and the Desert have coasts")
	shard_group.peers["northamerica"] = list("name" = "North America", "kind" = "SURFACE", "state" = "STOPPED")
	shard_group.peers["railyard"] = list("name" = "Rail Yard", "kind" = "RAILYARD", "state" = "UP")
	naval_check(!length(sea_lane_destinations()), "a stopped land and a world off the layout are not offered")
	shard_group.peers["northamerica"]["state"] = "UP"
	var/list/known = sea_lane_destinations()
	naval_check(known.len == 1 && findtext(known[1], "North America, across the sea to the west: 6 tiles, about 6 minutes"), "a continent across the sea is offered ([known.len ? known[1] : "none"])")
	var/list/lane_pick = known.len ? known[known[1]] : null
	naval_check(islist(lane_pick) && lane_pick[1] == "northamerica" && lane_pick[2] == 6, "with its region and sailing time")
	var/list/sides = sea_lane_sides("northamerica")
	naval_check(sides.len == 2 && sides[1] == WEST && sides[2] == EAST, "a ship from the Americas makes landfall off Gaia's west coast, else its east ([list2params(sides)])")
	sides = sea_crossing_sides("northamerica")
	naval_check(sides.len == 4 && sides[1] == WEST && sides[2] == EAST, "then any side ([list2params(sides)])")
	sides = sea_crossing_sides()
	naval_check(sides.len == 4 && sides[1] == NORTH, "without a known origin every side is tried in turn")
	tiller.voyage = null
	naval_check(tiller.set_out(H, "lane", "northamerica", 0, null, 6, "North America"), "she sets out along the lane with no chart owner")
	mine = tiller.voyage
	naval_check(islist(mine) && mine["kind"] == "lane" && mine["x"] == "northamerica", "the voyage names the land's region")
	naval_check(findtext(tiller.voyage_status_text(), "bound for North America: about 6 minutes to go"), "the tiller tells where and how long ([tiller.voyage_status_text()])")
	mine["stores"] = mine["rations"]
	var/sighted = FALSE
	for (var/i = 1, i <= 200, i++)
		mine["events"] = list()
		tiller.voyage_event(mine)
		if ("sighting" in mine["events"])
			sighted = TRUE
	naval_check(!sighted, "a lane crosses no chart, so the lookout sights nothing")
	mine["ends"] = world.time - 10
	shard_group.peers["northamerica"]["state"] = "STOPPED"
	naval_check(!tiller.voyage_lane_landfall(mine) && tiller.voyage == mine && mine["said"] == "The coast is not yet in sight.", "she waits off a coast whose world is down")
	naval_check(findtext(tiller.voyage_status_text(), "stands off North America"), "and the tiller says so ([tiller.voyage_status_text()])")
	mine["ends"] = world.time - 18010
	naval_check(tiller.voyage_lane_landfall(mine) && isnull(tiller.voyage), "she turns back after waiting too long")
	naval_check(tiller.craft && !QDELETED(tiller), "and is still here where she set out")
	shard_group.peers -= list("northamerica", "railyard")

	// ---- A land across the sea: onward voyages and settling ----
	shard_group.kind = "EXPEDITION"
	expedition_land_info = list("biome" = "DESERT", "land_type" = "COASTAL_PLAIN", "size" = "TINY", "key" = "1,2")
	world_chart["tiles"]["1,2"]["state"] = "LANDED"
	world_chart["tiles"]["1,2"]["region"] = "far1"
	world_chart["tiles"]["6,3"]["state"] = "SETTLED"
	var/list/here = voyage_origin()
	naval_check(islist(here) && here[1] == 1 && here[2] == 2, "a land across the sea sails from its own chart tile")
	lands = voyage_destinations("faction:romeempire", here)
	naval_check(lands.len == 1 && findtext(lands[1], "at 6,3"), "onward: a settled land is on every chart, the land she lies off is not offered")
	naval_check(!findtext(tiller.voyage_refusal(H), "No world chart"), "her ships may set out from a land too")
	naval_check(expedition_land_unsettled(), "the land is undecided")
	var/refusal = expedition_settle_refusal()
	naval_check(findtext(refusal, "mooring post"), "settling needs a mooring post ([refusal])")
	var/obj/structure/berth/quay/post = new(locate(18, 20, 2))
	var/list/owners = list("ann", "ann", "bob")
	for (var/i in 1 to owners.len)
		var/obj/structure/bed/B = new(locate(10 + i, 22, 2))
		B.persistence_bed_owner_ckey = owners[i]
	refusal = expedition_settle_refusal()
	naval_check(findtext(refusal, "the best has 2"), "and 3 beds slept in by different people ([refusal])")
	var/obj/structure/bed/far = new(locate(18 + 45, 20, 2))
	far.persistence_bed_owner_ckey = "cat"
	naval_check(findtext(expedition_settle_refusal(), "the best has 2"), "a bed far from the post does not count")
	var/obj/structure/bed/third = new(locate(15, 22, 2))
	third.persistence_bed_owner_ckey = "cat"
	naval_check(isnull(expedition_settle_refusal()), "with a third sleeper near the post she may settle")
	world_chart["tiles"]["1,2"]["state"] = "SETTLED"
	naval_check(!expedition_land_unsettled() && findtext(expedition_settle_refusal(), "already settled"), "a settled land is decided")
	// A land of one's own: any player, with a mooring post and their own bed near it.
	var/claimer = expedition_account_claimant("dee")
	naval_check(claimer == "crew:dee" && isnull(expedition_personal_claimant(null)), "a player claims as crew:ckey")
	naval_check(expedition_personal_claim_option(claimer) == "Claim this land", "the tiller offers her a land of her own")
	naval_check(findtext(expedition_personal_claim_refusal(claimer), "your own bed"), "which takes her own bed near the post")
	third.persistence_bed_owner_ckey = "dee"
	naval_check(isnull(expedition_personal_claim_refusal(claimer)), "with her bed near the post she may claim")
	world_chart["claims"] = list("crew:dee" = "6,3")
	naval_check(findtext(expedition_personal_claim_refusal(claimer), "already claim the land at 6,3"), "each person claims one land")
	world_chart["claims"] = list("crew:dee" = "1,2")
	world_chart["tiles"]["1,2"]["state"] = "CLAIMED"
	naval_check(expedition_personal_claim_option(claimer) == "Give up your claim", "her own land offers giving the claim up")
	world_chart["claims"] = list("crew:bob" = "1,2")
	naval_check(isnull(expedition_personal_claim_option(claimer)), "a land someone else claims offers her nothing")
	world_chart["claims"] = list()
	world_chart["tiles"]["1,2"]["state"] = "SETTLED"
	shard_group.kind = "SURFACE"
	naval_check(!expedition_land_unsettled() && isnull(expedition_land_key()), "the mainland is never an undecided land")
	qdel(post)
	// ---- The land's ore, rare find and game (land_resources.dm) ----
	expedition_land_info = list("biome" = "TUNDRA", "land_type" = "FJORD_COAST", "size" = "TINY", "key" = "1,2",
		"slot_world" = list("ore" = "rich", "ores" = list("copper", "iron", "coal"), "rare" = list("rich gold vein"), "game" = list("reindeer", "white wolf")))
	naval_check(expedition_lode_chance() == 12, "a rich land gives a lode on 12% of mined walls")
	var/old_age = map.ordinal_age
	map.ordinal_age = 0
	naval_check(list2params(expedition_lode_kinds()) == list2params(list("copper")), "a stone age miner finds only the land's copper ([list2params(expedition_lode_kinds())])")
	map.ordinal_age = 2
	naval_check(length(expedition_lode_kinds()) == 3, "a later miner finds all three")
	map.ordinal_age = old_age
	var/turf/rock = locate(30, 30, 1)
	var/bad = list()
	for (var/kind in expedition_lode_types + "flint")
		var/obj/item/I = rock.expedition_lode(kind)
		if (!I || I.loc != rock)
			bad += kind
	naval_check(!length(bad), "every ore kind the chart rolls leaves a lode ([jointext(bad, ", ")])")
	naval_check(isnull(rock.expedition_lode("amber")), "an unknown kind leaves nothing")
	var/list/table = ecology_default_species()
	var/datum/ecology_species/reindeer = null
	var/datum/ecology_species/deer = null
	for (var/datum/ecology_species/S in table)
		if (S.name == "reindeer")
			reindeer = S
		if (S.name == "deer")
			deer = S
	var/before = reindeer.density
	var/deer_before = deer.density
	naval_check(expedition_land_tune_species(table) == 2 && reindeer.density == before * 3 && deer.density == deer_before, "the land's own game is plentiful, other animals as usual")
	var/list/missing = list()
	for (var/name in list("polar bear", "penguin", "white wolf", "reindeer", "arctic fox", "elk", "brown bear", "wolf", "deer", "wild boar", "black bear", "turkey", "bison", "horse", "rabbit", "cattle", "camel", "lizard", "cobra", "goat", "dik-dik", "lion", "buffalo", "monkey", "parrot", "jaguar", "gorilla", "constrictor", "alligator", "frog", "leech"))
		var/found = FALSE
		for (var/datum/ecology_species/S in table)
			if (S.name == name)
				found = TRUE
		if (!found)
			missing += name
	naval_check(!length(missing), "every game name on the chart is an ecology species ([jointext(missing, ", ")])")
	// ---- Giving up a faction's claim at its charter (land_choices.dm) ----
	shard_group.kind = "EXPEDITION"
	expedition_land_info["key"] = "1,2"
	var/obj/structure/colony_charter/charter = new(get_step(H, EAST))
	charter.faction = "Rome Colony"
	map.faction_colonies()["Rome Colony"] = list("civ:gaia:Rome Empire", 0)
	world_chart["claims"] = list("civ:gaia:Rome Empire" = "1,2")
	H.civilization = "Rome Colony"
	H.leader = FALSE
	naval_check(isnull(charter.unclaim_parent(H)), "only the colony's leader may give its claim up")
	H.leader = TRUE
	naval_check(charter.unclaim_parent(H) == "civ:gaia:Rome Empire", "its leader may, for the parent faction that holds it")
	world_chart["claims"] = list("civ:gaia:Rome Empire" = "6,3")
	naval_check(isnull(charter.unclaim_parent(H)), "not when the faction's claim is on another land")
	H.civilization = null
	H.leader = FALSE
	shard_group.kind = "SURFACE"
	qdel(charter)
	expedition_land_info = null

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
