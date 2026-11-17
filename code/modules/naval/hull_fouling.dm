// ============================================================
// Fouling and careening (docs/hull-ledger.md)
// ------------------------------------------------------------
// Weed and shell grow on the bottom of a boat or a ship while she is in use,
// and a foul bottom drags: it weighs on her drives like more tiles of hull.
//
// - Growth: from clean to foul over about a day of use, at anchor or under
//   way. A clean bottom drags nothing; a foul one is four tenths of her
//   tiles more to push.
// - Scraping: lay her in the shallows, let her lie still, and use a shovel or
//   a knife on one of her planks. Each go of four seconds cleans three tiles.
// - Copper sheathing: copper sheets hammered onto the clean bottom of a
//   wooden hull in the shallows, one sheet for two tiles. A fully coppered
//   bottom fouls a tenth as fast.
//
// Small craft are hauled out and never foul. A hull nobody is aboard does
// not change, like the rest of the ledger.
// ============================================================

// Seconds of use that take a bare bottom from clean to foul.
#define HULL_FOUL_LIFE 86400
// Tiles of weight a foul bottom adds for each tile of hull.
#define HULL_FOUL_DRAG 0.4
// How much of the growth a full sheathing of copper stops.
#define HULL_COPPER_STOPS 0.9
// Tiles one go with a scraper cleans, and the deciseconds it takes.
#define SCRAPE_TILES 3
#define SCRAPE_TIME 40
// Tiles one sheet of copper covers, and the deciseconds it takes.
#define COPPER_TILES_PER_SHEET 2
#define COPPER_TIME 30

/datum/hull_ledger
	// How foul her bottom is: 0 clean, 1 foul.
	var/fouling = 0
	// How much of her bottom is sheathed in copper: 0 to 1.
	var/coppered = 0
	var/tmp/fouling_told = 0
	// Who is scraping or sheathing now: mob = TRUE.
	var/tmp/list/bottom_hands = list()

// TRUE when her bottom fouls at all.
/datum/hull_ledger/proc/fouls()
	return hull_class() != HULL_CLASS_SMALL

// TRUE when she is a wooden hull that copper can be nailed to.
/datum/hull_ledger/proc/takes_copper()
	return fouls() && seep_tiles > 0

/datum/hull_ledger/proc/fouling_name()
	if (fouling >= HULL_FOUL_FOUL)
		return "foul"
	if (fouling >= HULL_FOUL_WEEDY)
		return "weedy"
	if (fouling >= HULL_FOUL_SLIMED)
		return "slimed"
	return "clean"

/datum/hull_ledger/proc/fouling_step_told()
	return fouling >= HULL_FOUL_FOUL ? 2 : (fouling >= HULL_FOUL_WEEDY ? 1 : 0)

// Tiles of weight her bottom drags.
/datum/hull_ledger/proc/foul_weight()
	if (!fouls() || fouling < HULL_FOUL_SLIMED)
		return 0
	return round(clamp(fouling, 0, 1) * tiles * HULL_FOUL_DRAG, 1)

// Growth on her bottom over seconds of use.
/datum/hull_ledger/proc/step_fouling(seconds)
	if (!fouls() || grounded || fouling >= 1)
		return
	fouling = min(1, fouling + seconds / HULL_FOUL_LIFE * (1 - HULL_COPPER_STOPS * clamp(coppered, 0, 1)))
	var/now = fouling_step_told()
	if (now > fouling_told && craft)
		if (now == 2)
			craft.crew_message(SPAN_WARNING("The bottom of the [craft.name] is foul with weed and shell and she drags badly. Lay her in the shallows and scrape her with a shovel or a knife."))
		else
			craft.crew_message(SPAN_NOTICE("Weed is growing on the bottom of the [craft.name] and she is slower for it."))
	fouling_told = now

/datum/hull_ledger/proc/fouling_text()
	if (!fouls())
		return ""
	. = " Her bottom is [fouling_name()]"
	var/weight = foul_weight()
	. += weight > 0 ? ", dragging like [weight] more tile\s of hull" : ""
	if (coppered >= 0.999)
		. += " and sheathed in copper."
	else if (coppered > 0.001)
		. += " and [round(coppered * 100)] parts in a hundred sheathed in copper."
	else
		. += "."

/datum/hull_ledger/to_list()
	. = ..()
	.["fouling"] = round(fouling, 0.001)
	.["coppered"] = round(coppered, 0.001)

/datum/hull_ledger/from_list(list/state)
	..()
	if (!islist(state))
		return
	if (isnum(state["fouling"]))
		fouling = clamp(state["fouling"], 0, 1)
	if (isnum(state["coppered"]))
		coppered = clamp(state["coppered"], 0, 1)
	fouling_told = fouling_step_told()

// ---- Work on her bottom ----

// Why H cannot get at the bottom of the hull under plank P, or null.
/proc/hull_bottom_refusal(mob/living/human/H, obj/covers/P)
	if (!istype(H) || !P)
		return "nothing to work with"
	var/turf/plank = get_turf(P)
	var/datum/craft/C = plank ? craft_at(plank) : null
	if (!C || !C.ledger)
		return "that is not a hull afloat"
	var/datum/hull_ledger/L = C.ledger
	if (!L.deck_holds(get_turf(H)))
		return "stand on her deck"
	if (H.stat || H.lying || H.restrained())
		return "you are in no state for it"
	if (!L.fouls())
		return "a hull this small is hauled out and kept clean"
	if (L.under_way())
		return "she must lie still"
	if (L.over_deep())
		return "her bottom is out of reach in deep water: lay her in the shallows"
	return null

// One go with the scraper. Returns how much cleaner she is.
/datum/hull_ledger/proc/scrape_go()
	var/was = fouling
	fouling = max(0, fouling - SCRAPE_TILES / max(1, tiles))
	fouling_told = fouling_step_told()
	return was - fouling

// H scrapes until she is clean or they stop. Returns the goes made.
/proc/hull_scrape(mob/living/human/H, obj/item/W, obj/covers/P)
	. = 0
	var/why = hull_bottom_refusal(H, P)
	var/datum/craft/C = craft_at(get_turf(P))
	var/datum/hull_ledger/L = C ? C.ledger : null
	if (!why && L.fouling <= 0.001)
		why = "her bottom is clean"
	if (why)
		to_chat(H, SPAN_WARNING("You cannot scrape her here: [why]."))
		return
	if (L.bottom_hands[H])
		return
	L.bottom_hands[H] = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts scraping the bottom of the [C.name]."), SPAN_NOTICE("You start scraping weed and shell off the bottom of the [C.name]."))
	while (TRUE)
		playsound(get_turf(H), 'sound/effects/wood_cutting.ogg', 30, TRUE)
		if (!do_after(H, SCRAPE_TIME, P))
			break
		if (QDELETED(L) || QDELETED(W) || QDELETED(P) || H.get_active_hand() != W || hull_bottom_refusal(H, P) || L.fouling <= 0.001)
			break
		L.scrape_go()
		.++
	if (!QDELETED(L))
		L.bottom_hands -= H
		if (.)
			to_chat(H, SPAN_NOTICE("You scrape her down. Her bottom is [L.fouling_name()][L.fouling > 0.001 ? ", with more to come off" : ""]."))

// One sheet nailed on. Returns how much more of her is sheathed.
/datum/hull_ledger/proc/copper_sheet()
	var/was = coppered
	coppered = min(1, coppered + COPPER_TILES_PER_SHEET / max(1, tiles))
	return coppered - was

// Sheets of copper it takes to finish her sheathing.
/datum/hull_ledger/proc/copper_wanted()
	return max(0, round((1 - coppered) * tiles / COPPER_TILES_PER_SHEET + 0.499))

// Why H cannot sheathe the hull under plank P, or null.
/proc/hull_sheathe_refusal(mob/living/human/H, obj/covers/P)
	. = hull_bottom_refusal(H, P)
	if (.)
		return
	var/datum/craft/C = craft_at(get_turf(P))
	var/datum/hull_ledger/L = C.ledger
	if (!L.takes_copper())
		return "copper is nailed to a wooden bottom, and she is plated"
	if (L.coppered >= 0.999)
		return "she is sheathed from stem to stern"
	if (L.fouling >= HULL_FOUL_SLIMED)
		return "scrape her bottom clean first"
	if (!is_tool(H.get_inactive_hand(), TOOL_HAMMER))
		return "you need a hammer in your other hand to nail it on"
	return null

// H sheathes until she is done, the copper is gone or they stop. Returns
// the sheets used.
/proc/hull_sheathe(mob/living/human/H, obj/item/stack/W, obj/covers/P)
	. = 0
	var/why = hull_sheathe_refusal(H, P)
	if (why)
		to_chat(H, SPAN_WARNING("You cannot sheathe her here: [why]."))
		return
	var/datum/craft/C = craft_at(get_turf(P))
	var/datum/hull_ledger/L = C.ledger
	if (L.bottom_hands[H])
		return
	L.bottom_hands[H] = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts nailing copper to the bottom of the [C.name]."), SPAN_NOTICE("You start sheathing the bottom of the [C.name] in copper. She wants [L.copper_wanted()] sheet\s more."))
	while (TRUE)
		playsound(get_turf(H), 'sound/items/Screwdriver.ogg', 40, TRUE)
		if (!do_after(H, COPPER_TIME, P))
			break
		if (QDELETED(L) || QDELETED(W) || QDELETED(P) || H.get_active_hand() != W || hull_sheathe_refusal(H, P))
			break
		if (!W.use(1))
			break
		L.copper_sheet()
		.++
	if (!QDELETED(L))
		L.bottom_hands -= H
		if (.)
			to_chat(H, SPAN_NOTICE("You nail on [.] sheet\s of copper. [L.coppered >= 0.999 ? "She is sheathed from stem to stern." : "She wants [L.copper_wanted()] more."]"))

// A shovel or a knife on a plank of a foul hull scrapes her, and copper
// sheathes her. Anything else behaves as it always did.
/obj/covers/attackby(obj/item/W as obj, mob/user as mob)
	if (W && ishuman(user) && user.a_intent != I_HARM)
		var/copper = istype(W, /obj/item/stack/material/copper)
		if (copper || is_tool(W, TOOL_SHOVEL) || is_tool(W, TOOL_KNIFE))
			var/turf/plank = get_turf(src)
			var/datum/craft/C = plank ? craft_at(plank) : null
			var/datum/hull_ledger/L = C ? C.ledger : null
			if (L && L.fouls())
				if (copper)
					hull_sheathe(user, W, src)
					return TRUE
				if (L.fouling >= HULL_FOUL_SLIMED)
					hull_scrape(user, W, src)
					return TRUE
	return ..()

#undef HULL_FOUL_LIFE
#undef HULL_FOUL_DRAG
#undef HULL_COPPER_STOPS
#undef SCRAPE_TILES
#undef SCRAPE_TIME
#undef COPPER_TILES_PER_SHEET
#undef COPPER_TIME
