// ============================================================
// Provisions, speed and happenings on a voyage (docs/ship-voyage.md)
// ------------------------------------------------------------
// - Speed: a chart tile takes a minute under sail; a ship whose engines drive
//   her at full ahead takes 40 seconds.
// - Rations: each crew member eats one ration a chart tile. Any food aboard
//   counts, in the hold, in crates or carried. What the voyage needs is eaten
//   when she arrives; a ship that sailed short leaves her crew hungry, never
//   starving.
// - Happenings, at most one each a voyage: a storm (detour, or risk loose
//   deck cargo while pressing on), a sighting (the lookout charts water
//   near her course) and, sailing short, a warning that rations are low.
// ============================================================

#define VOYAGE_TILE_SAIL 600 // deciseconds a chart tile takes under sail
#define VOYAGE_TILE_ENGINE 400 // and driven at full ahead by engines
#define VOYAGE_STORM_CHANCE 8 // percent a chart tile
#define VOYAGE_STORM_DECISION 300 // deciseconds to stow cargo and choose
#define VOYAGE_SIGHTING_CHANCE 10
#define VOYAGE_HUNGER_PER_RATION 60 // nutrition a missing ration costs
#define VOYAGE_HUNGER_FLOOR 150 // short rations never take anyone below this

// Deciseconds a chart tile takes her now.
/obj/structure/hull_tiller/proc/voyage_tile_time()
	if (!craft)
		return VOYAGE_TILE_SAIL
	craft.fit_drives()
	// Oars tire (rowing_bench.dm): only engines keep up full ahead for a voyage.
	return craft.sustained_full_ahead() ? VOYAGE_TILE_ENGINE : VOYAGE_TILE_SAIL

// Every food item aboard, looking into crates, closets, bags and pockets.
/obj/structure/hull_tiller/proc/voyage_rations()
	. = list()
	var/datum/craft_body/built/B = body()
	if (!B)
		return
	var/list/open = B.aboard()
	var/depth = 0
	while (length(open) && depth < 4)
		var/list/next = list()
		for (var/atom/movable/M in open)
			if (istype(M, /obj/item/weapon/reagent_containers/food/snacks))
				. += M
			else if (length(M.contents))
				next += M.contents
		open = next
		depth++

// Asked at the tiller before she sets out: TRUE to sail.
/obj/structure/hull_tiller/proc/provisions_menu(mob/living/human/H, tiles)
	var/need = length(voyage_crew()) * tiles
	var/have = length(voyage_rations())
	if (have >= need)
		return TRUE
	return WWinput(H, "She carries [have] ration\s; [length(voyage_crew())] crew for [tiles] chart tile\s need [need] (one each a tile, any food). Set out on short rations? Nobody starves at sea, but her crew will land hungry.", craft.name, "Stay", list("Set out hungry", "Stay")) == "Set out hungry" && get_dist(H, src) <= 1 && craft

// The crew eat what the voyage needed, once, as she arrives.
/obj/structure/hull_tiller/proc/voyage_eat(list/mine)
	if (mine["fed"])
		return
	mine["fed"] = TRUE
	var/need = mine["rations"]
	var/eaten = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/S in voyage_rations())
		if (eaten >= need)
			break
		qdel(S)
		eaten++
	var/short = need - eaten
	var/list/crew = voyage_crew()
	if (short <= 0 || !length(crew))
		if (need)
			craft.crew_message(SPAN_NOTICE("The crew ate [eaten] ration\s on the way."))
		return
	var/hunger = round(short * VOYAGE_HUNGER_PER_RATION / length(crew))
	for (var/mob/living/human/H in crew)
		H.nutrition = max(min(H.nutrition, VOYAGE_HUNGER_FLOOR), H.nutrition - hunger)
	craft.crew_message(SPAN_WARNING("The crew ate the last of [eaten] ration\s and went [short] short: everyone aboard is hungry."))

// One happening this chart tile, or none. TRUE when one was told.
/obj/structure/hull_tiller/proc/voyage_event(list/mine)
	var/list/done = mine["events"]
	if (!islist(done))
		done = list()
		mine["events"] = done
	var/tiles_left = (mine["ends"] - world.time) / mine["tile"]
	if (!("short" in done) && mine["stores"] < mine["rations"] && tiles_left <= mine["tiles"] / 2)
		done += "short"
		craft.crew_message(SPAN_WARNING("Rations are running short: [mine["stores"]] for a voyage that needs [mine["rations"]]. Turn back at the tiller, or press on and land hungry."))
		return TRUE
	if (!("storm" in done) && prob(VOYAGE_STORM_CHANCE))
		done += "storm"
		voyage_storm(mine)
		return TRUE
	// A sea lane (sea_lanes.dm) crosses no chart: nothing to sight on it.
	if (!("sighting" in done) && mine["kind"] != "lane" && prob(VOYAGE_SIGHTING_CHANCE))
		done += "sighting"
		voyage_sighting(mine)
		return TRUE
	return FALSE

// Something loose on her deck, not carried, stowed or fixed, or null.
/obj/structure/hull_tiller/proc/voyage_loose_cargo()
	var/datum/craft_body/built/B = body()
	if (!B)
		return null
	var/list/loose = list()
	for (var/obj/item/I in B.aboard())
		if (I.anchored || !isturf(I.loc) || I.z < B.z)
			continue
		var/turf/T = I.loc
		if (!(locate(/obj/roof) in T))
			loose += I
	return length(loose) ? pick(loose) : null

// The voyage is a timed abstraction, not the hull's parked local weather.
/obj/structure/hull_tiller/proc/voyage_storm(list/mine)
	if (!craft || !mine || voyage != mine || mine["storm_until"] || mine["storm_passed"])
		return FALSE
	mine["storm_until"] = world.time + VOYAGE_STORM_DECISION
	craft.crew_message(SPAN_WARNING("Squall ahead! Stow loose deck cargo. Choose at the tiller within 30 seconds: take a slower detour or press on and risk loose cargo. Without orders, she detours."))
	return TRUE

// H answers the warning at the tiller. Recheck after the menu, not just when
// the choices were displayed.
/obj/structure/hull_tiller/proc/voyage_storm_can_choose(mob/living/human/H, list/mine)
	if (QDELETED(src) || !H || QDELETED(H) || !H.client || H.incapacitated() || persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return FALSE
	return craft && mine && voyage == mine && mine["storm_until"] > world.time && H.z == z && get_dist(H, src) <= 1 && (H in voyage_crew()) && craft.helm_access(H) == CRAFT_HELM_FREE && !crossing_hold_text()

/obj/structure/hull_tiller/proc/voyage_storm_resolve(list/mine, press_on = FALSE)
	if (!craft || !mine || voyage != mine || !mine["storm_until"])
		return FALSE
	mine["storm_until"] = null
	mine["storm_passed"] = TRUE
	if (!press_on)
		mine["ends"] = max(mine["ends"], world.time) + mine["tile"]
		log_game("Voyage: the [craft.name] took a storm detour of [mine["tile"] / 10] seconds (voyage [mine["id"]]).")
		craft.crew_message(SPAN_NOTICE("She takes the long way around the squall. The detour costs one chart tile's sailing time."))
		return TRUE
	var/obj/item/lost = prob(50) ? voyage_loose_cargo() : null
	if (lost)
		log_game("Voyage: a storm washed [lost] ([lost.type]) off the [craft.name] (voyage [mine["id"]]).")
		craft.crew_message(SPAN_WARNING("She presses on. Green water sweeps her deck and takes \the [lost] overboard."))
		qdel(lost)
	else
		craft.crew_message(SPAN_NOTICE("She presses on through the squall without losing any deck cargo."))
	return TRUE

// The lookout sees water a tile or two off her course: it goes on her owner's chart.
/obj/structure/hull_tiller/proc/voyage_sighting(list/mine)
	var/list/origin = voyage_origin()
	var/x = mine["x"]
	var/y = mine["y"]
	if (origin)
		x = round((origin[1] + x) / 2)
		y = round((origin[2] + y) / 2)
	x += rand(-2, 2)
	y += rand(-2, 2)
	var/w = isnum(world_chart["width"]) ? world_chart["width"] : 0
	var/h = isnum(world_chart["height"]) ? world_chart["height"] : 0
	if (w && h)
		x = clamp(x, 0, w - 1)
		y = clamp(y, 0, h - 1)
	transfer_bridge.request("/chart/request", list("op" = "scout", "x" = x, "y" = y, "owner" = mine["owner"], "admin" = mine["by"]))
	log_game("Voyage: the [craft.name]'s lookout sighted chart tile [x],[y] (voyage [mine["id"]]).")
	craft.crew_message(SPAN_NOTICE("The lookout calls: something on the horizon! What she sees off her course goes on your chart within a minute."))

#undef VOYAGE_TILE_SAIL
#undef VOYAGE_TILE_ENGINE
#undef VOYAGE_STORM_CHANCE
#undef VOYAGE_STORM_DECISION
#undef VOYAGE_SIGHTING_CHANCE
#undef VOYAGE_HUNGER_PER_RATION
#undef VOYAGE_HUNGER_FLOOR
