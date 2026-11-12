// Original active search. Persistence worlds have it on; other maps opt in.
// Design and phase notes: docs/foraging.md.
#define FORAGING_CELL_SIZE 8
#define FORAGING_CELL_STOCK 4
#define FORAGING_CONTENT_LIMIT 64
#define FORAGING_SEARCH_TIME 300
// One unit grows back per hour of active server time (phase 5).
#define FORAGING_RENEW_TIME (60 MINUTES)

/obj/map_metadata/var/foraging_enabled = FALSE

// Persistence worlds forage (Val, 2026-11-10); round maps opt in with foraging_enabled.
/obj/map_metadata/proc/foraging_active()
	return foraging_enabled || persistence

// Sparse, ordinary saved roots, not a global cache or mutable turf variable.
// Changing terrain or relogging cannot replenish a cell; only renewal can.
/obj/foraging_cell
	name = "foraging depletion record"
	invisibility = 101
	mouse_opacity = 0
	anchored = TRUE
	density = FALSE
	sinkable = FALSE
	var/remaining = FORAGING_CELL_STOCK
	// Renewal clock reading when the next unit started growing back; null at
	// full stock or for a record saved before renewal existed.
	var/renew_from = null

// Anchoring alone does not stop broken floors or forceMove callers. These
// records describe coordinates and must never travel with actors or vehicles.
/obj/foraging_cell/Move(NewLoc, Dir = 0, step_x = 0, step_y = 0)
	return FALSE

/obj/foraging_cell/forceMove(atom/destination, special_event, list/throw_hop_token = null)
	if (isnull(destination))
		return ..()
	return FALSE

/obj/foraging_cell/persistence_set_loc(atom/destination)
	if (isnull(destination))
		return ..()
	return FALSE

/obj/foraging_cell/get_saved_vars()
	var/list/saved = ..()
	// /obj is a partial-save type; explicitly include even the initial value.
	saved |= "remaining"
	saved |= "renew_from"
	return saved

//////// Renewal (phase 5)
// Clock policy: the durable active-server clock, the same one that drives the
// round timer. It is saved with the world and restored on load, so downtime adds
// nothing and a world.time reset after a reboot changes nothing. No timer or
// worker per patch: stock is worked out lazily when someone looks or searches.
// A clock reading behind the stamp (a legacy save without its round clock, or a
// clock moved back) restamps without granting anything. Ground, focus or season
// changes never touch the stock; only time does, at one unit per period, capped.
/proc/foraging_clock()
	return roundduration2text_in_ticks

/obj/foraging_cell/proc/valid_renewal()
	return isnull(renew_from) || (isnum(renew_from) && renew_from >= 0 && renew_from <= 1e15)

// Stock at clock reading now, without changing anything.
/obj/foraging_cell/proc/units_at(now)
	if (remaining >= FORAGING_CELL_STOCK || !isnum(renew_from) || now < renew_from)
		return remaining
	return min(FORAGING_CELL_STOCK, remaining + round((now - renew_from) / FORAGING_RENEW_TIME))

// Brings the stored stock and stamp up to now. Callers fence saves first.
/obj/foraging_cell/proc/settle(now)
	if (remaining >= FORAGING_CELL_STOCK)
		renew_from = null
		return
	if (!isnum(renew_from) || now < renew_from)
		renew_from = now
		return
	var/grown = round((now - renew_from) / FORAGING_RENEW_TIME)
	if (grown <= 0)
		return
	remaining = min(FORAGING_CELL_STOCK, remaining + grown)
	renew_from = remaining >= FORAGING_CELL_STOCK ? null : renew_from + grown * FORAGING_RENEW_TIME

/proc/foraging_anchor(turf/T)
	if (!T)
		return null
	return locate(1 + FORAGING_CELL_SIZE * round((T.x - 1) / FORAGING_CELL_SIZE), 1 + FORAGING_CELL_SIZE * round((T.y - 1) / FORAGING_CELL_SIZE), T.z)

/proc/foraging_site(turf/T)
	if (!T || !ecology_outdoor_climate(T) || T.contents.len > FORAGING_CONTENT_LIMIT)
		return FALSE
	var/ground = ecology_ground(T)
	if (!(ground == ECO_GRASS || ground == ECO_DIRT || ground == ECO_BEACH || ground == ECO_SAND))
		return FALSE
	if (locate(/obj/roof) in T)
		return FALSE
	for (var/obj/O in T)
		if (O.density || istype(O, /obj/structure) || istype(O, /obj/covers))
			return FALSE
	return TRUE

// Null means no previous search. FALSE means corrupt/overcrowded: fail closed.
/proc/foraging_record(turf/anchor)
	if (!anchor || anchor.contents.len > FORAGING_CONTENT_LIMIT)
		return FALSE
	var/obj/foraging_cell/found
	for (var/obj/foraging_cell/C in anchor)
		if (found || !isnum(C.remaining) || C.remaining < 0 || C.remaining > FORAGING_CELL_STOCK || round(C.remaining) != C.remaining || !C.valid_renewal())
			return FALSE
		found = C
	return found

/proc/foraging_available(turf/T)
	var/record = foraging_record(foraging_anchor(T))
	if (isnull(record))
		return FORAGING_CELL_STOCK
	if (!record)
		return 0
	var/obj/foraging_cell/C = record
	var/now = foraging_clock()
	// Looking starts the clock on a record from before renewal, outside saves.
	if (!isnum(C.renew_from) && C.remaining < FORAGING_CELL_STOCK && foraging_persistence_ready(persistence_admission_identity))
		C.settle(now)
	return C.units_at(now)

/proc/foraging_persistence_ready(expected_identity)
	return !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && expected_identity == persistence_admission_identity

//////// What the ground can give (phase 4)
// Every find is one item from an existing gathering path and costs one shared
// unit. Seeds come from wild crops that already grow in these biomes; the only
// food is the ordinary edible mushroom. Berries keep their own smell-based
// identification and are never a foraging find. No ores, research or recipes.

#define FORAGE_ANY "anything"
#define FORAGE_STONE "stone"
#define FORAGE_WOOD "wood"
#define FORAGE_SEEDS "seeds"
#define FORAGE_FOOD "food"

/proc/foraging_focuses()
	return list(FORAGE_ANY, FORAGE_STONE, FORAGE_WOOD, FORAGE_SEEDS, FORAGE_FOOD)

// Weight of each category when searching for anything.
/proc/foraging_category_weights()
	return list(FORAGE_STONE = 3, FORAGE_WOOD = 3, FORAGE_SEEDS = 2, FORAGE_FOOD = 2)

// Wild seed finds: seed path -> climates. Biomes match each crop's own plant.
/proc/foraging_seed_table()
	return list(
		/obj/item/stack/farming/seeds/wheat = list("temperate", "tundra", "taiga", "sea", "desert", "semiarid"),
		/obj/item/stack/farming/seeds/oat = list("temperate", "tundra", "taiga", "sea"),
		/obj/item/stack/farming/seeds/barley = list("semiarid", "temperate", "taiga", "sea"),
		/obj/item/stack/farming/seeds/rice = list("jungle", "savanna", "sea"),
		/obj/item/stack/farming/seeds/turnip = list("temperate", "sea", "tundra", "taiga"),
		/obj/item/stack/farming/seeds/potato = list("temperate", "taiga", "semiarid"),
		/obj/item/stack/farming/seeds/beans = list("temperate", "savanna", "desert", "sea", "semiarid", "taiga"),
		/obj/item/stack/farming/seeds/flax = list("temperate", "taiga", "tundra"),
		/obj/item/stack/farming/seeds/cotton = list("temperate", "desert", "sea", "semiarid"),
		/obj/item/stack/farming/seeds/parsley = list("temperate", "semiarid", "sea"),
		/obj/item/stack/farming/seeds/celery = list("temperate", "semiarid", "sea", "jungle"),
	)

// Mushrooms grow where the mushroom crop does, outside the cold and dry seasons.
/proc/foraging_mushroom_climates()
	return list("temperate", "sea", "tundra", "taiga", "jungle", "savanna")

// path -> weight for one category on T in the current season; empty if none.
/proc/foraging_finds(turf/T, category)
	. = list()
	var/climate = ecology_outdoor_climate(T)
	if (!climate)
		return
	var/ground = ecology_ground(T)
	var/soil = ground == ECO_GRASS || ground == ECO_DIRT
	switch (category)
		if (FORAGE_STONE)
			.[/obj/item/stack/material/stone] = 1
		if (FORAGE_WOOD)
			if (soil && climate != "desert")
				.[/obj/item/stack/material/wood_piece] = 1
		if (FORAGE_SEEDS)
			if (soil && season != "WINTER")
				var/list/table = foraging_seed_table()
				for (var/path in table)
					var/list/climates = table[path]
					if (climate in climates)
						.[path] = 1
		if (FORAGE_FOOD)
			if (soil && season != "WINTER" && season != "Dry Season" && (climate in foraging_mushroom_climates()))
				.[/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom] = 1

// Categories this tile can give, each with its weight for an open search.
/proc/foraging_categories(turf/T)
	. = list()
	var/list/weights = foraging_category_weights()
	for (var/category in weights)
		var/list/finds = foraging_finds(T, category)
		if (finds.len)
			.[category] = weights[category]

/proc/foraging_offers(turf/T, focus)
	var/list/categories = foraging_categories(T)
	if (focus == FORAGE_ANY)
		return categories.len > 0
	return (focus in categories)

// The item type one search turns up. Null when the tile offers nothing.
/proc/foraging_roll(turf/T, focus)
	var/category = focus
	if (focus == FORAGE_ANY)
		var/list/categories = foraging_categories(T)
		if (!categories.len)
			return null
		category = pickweight(categories)
	var/list/finds = foraging_finds(T, category)
	if (!finds.len)
		return null
	return pickweight(finds)

//////// Search time (phase 4)
// Farming skill and daylight change the time only, never the amount: every
// find still costs one shared unit. Bounded between 20 and 45 seconds.
/mob/living/human/proc/foraging_search_time(turf/T)
	var/skill = clamp(getStatCoeff("farming"), 1, 1.5)
	var/time = FORAGING_SEARCH_TIME / skill
	if (T && T.get_lumcount() < 0.2)
		time *= 1.5
	return round(clamp(time, 200, 450))

/proc/foraging_abundance_text(units)
	switch (units)
		if (4 to INFINITY)
			return "untouched"
		if (3)
			return "plenty left"
		if (2)
			return "some left"
		if (1)
			return "almost bare"
	return "picked clean"

/proc/foraging_ground_text(turf/T)
	switch (ecology_ground(T))
		if (ECO_GRASS)
			return "grass"
		if (ECO_DIRT)
			return "dirt"
		if (ECO_BEACH)
			return "beach"
		if (ECO_SAND)
			return "sand"
	return "ground"

//////// Search panel (phase 3)
// One small window: where you are, how much the patch has left, and a button
// per focus. Nothing is created per tick and nothing shows other players.

/mob/living/human/verb/forage_nearby()
	set name = "Forage nearby"
	set category = "Crafting"
	foraging_show_panel()

// Classic fallback and macro target: "forage-for seeds" searches without the window.
/mob/living/human/verb/forage_for(focus as text)
	set name = "Forage For"
	set hidden = TRUE
	focus = lowertext(trim(focus))
	if (!(focus in foraging_focuses()))
		to_chat(src, SPAN_WARNING("Forage for one of: [english_list(foraging_focuses(), and_text = " or ")]."))
		return
	forage(focus)

// A full document: the 516 browser shows a bare fragment as plain text.
/mob/living/human/proc/foraging_panel_html(turf/T)
	return "<!DOCTYPE html><html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'>[common_browser_style]<title>Foraging</title></head><body>[foraging_panel_body(T)]</body></html>"

/mob/living/human/proc/foraging_panel_body(turf/T)
	var/list/rows = list("<h3>Foraging</h3>")
	if (!isturf(T) || !foraging_site(T))
		rows += "<p>Stand on open outdoor grass, dirt or sand, away from structures and roofs.</p>"
		return jointext(rows, "")
	var/units = foraging_available(T)
	rows += "<p>[capitalize(ecology_outdoor_climate(T))] [foraging_ground_text(T)], [lowertext(season)].<br>This patch: <b>[foraging_abundance_text(units)]</b>.</p>"
	rows += "<p>A search takes about [round(foraging_search_time(T) / 10)] seconds. Moving or changing your held item cancels it.</p>"
	var/list/labels = list(FORAGE_ANY = "Anything", FORAGE_STONE = "Stones", FORAGE_WOOD = "Sticks", FORAGE_SEEDS = "Wild seeds", FORAGE_FOOD = "Mushrooms")
	for (var/focus in foraging_focuses())
		if (units && foraging_offers(T, focus))
			rows += "<a href='byond://?src=\ref[src];forage_focus=[focus]'>[labels[focus]]</a> "
		else
			rows += "<span style='color:#888'>[labels[focus]]</span> "
	return jointext(rows, "")

/mob/living/human/proc/foraging_show_panel()
	if (!map || !map.foraging_active())
		to_chat(src, SPAN_WARNING("Foraging is not available on this map."))
		return FALSE
	if (!client)
		return FALSE
	show_browse(src, foraging_panel_html(loc), "window=foraging;size=360x240")
	return TRUE

/mob/living/human/Topic(href, href_list)
	if (href_list["forage_focus"])
		if (usr != src)
			return
		var/focus = href_list["forage_focus"]
		if (!(focus in foraging_focuses()))
			return
		show_browse(src, null, "window=foraging")
		forage(focus)
		return
	return ..()

// Seams for the native probe; production keeps the real client and do_after.
/mob/living/human/proc/foraging_connected()
	return client != null

/mob/living/human/proc/foraging_wait(delay, turf/T)
	// Existing do_after owns repeated-action, movement, hand and incapacity guards.
	return do_after(src, delay, T)

// One search of the tile underfoot. Returns TRUE only when a unit was found.
/mob/living/human/proc/forage(focus = FORAGE_ANY)
	if (!map || !map.foraging_active())
		to_chat(src, SPAN_WARNING("Foraging is not available on this map."))
		return FALSE
	if (!(focus in foraging_focuses()))
		return FALSE
	var/turf/T = loc
	if (!isturf(loc) || !foraging_connected() || incapacitated(INCAPACITATION_DEFAULT) || !foraging_site(T))
		to_chat(src, SPAN_WARNING("Search on open outdoor grass, dirt or sand, away from structures and roofs."))
		return FALSE
	if (!foraging_available(T))
		to_chat(src, SPAN_NOTICE("This patch has already been picked clean."))
		return FALSE
	if (!foraging_offers(T, focus))
		to_chat(src, SPAN_NOTICE("You will not find [focus] on this ground [season == "WINTER" ? "in winter" : "here"]."))
		return FALSE
	if (!T.sifting_identity)
		T.sifting_identity = new /datum
	var/datum/terrain_identity = T.sifting_identity
	var/epoch = persistence_admission_identity
	if (!foraging_persistence_ready(epoch))
		return FALSE
	to_chat(src, SPAN_NOTICE("You begin searching the ground[focus == FORAGE_ANY ? "" : " for [focus]"]. Moving or changing your held item cancels the search."))
	if (!foraging_wait(foraging_search_time(T), T))
		return FALSE
	if (QDELETED(src) || !foraging_connected() || !map || !map.foraging_active() || loc != T || T.sifting_identity != terrain_identity || incapacitated(INCAPACITATION_DEFAULT) || !foraging_site(T) || !foraging_persistence_ready(epoch))
		return FALSE
	var/obj/item/found = foraging_commit(T, epoch, focus)
	if (!found)
		to_chat(src, SPAN_NOTICE("Nothing remains to collect here."))
		return FALSE
	to_chat(src, SPAN_NOTICE("You find something at your feet: [initial(found.name)]."))
	adaptStat("farming", 1)
	note_field_work(src, "forage")
	return TRUE

// No input, sleeps or result previews between validation and debit. Every result
// costs one shared unit. Concurrent completions recheck the current stock here.
// Returns the found type (stacks may merge into one already there), or null.
/proc/foraging_commit(turf/T, expected_identity, focus = FORAGE_ANY)
	if (!map || !map.foraging_active() || !foraging_site(T) || !foraging_persistence_ready(expected_identity))
		return null
	if (!foraging_offers(T, focus))
		return null
	var/turf/anchor = foraging_anchor(T)
	var/record = foraging_record(anchor)
	if (!isnull(record) && !record)
		return null
	var/obj/foraging_cell/C = record
	var/now = foraging_clock()
	if (C)
		C.settle(now)
		if (C.remaining <= 0)
			return null
	var/output = foraging_roll(T, focus)
	if (!output)
		return null
	if (!C)
		C = new(anchor)
	if (C.remaining >= FORAGING_CELL_STOCK)
		C.renew_from = now
	C.remaining--
	// Existing constructors receive an explicit single unit for stacks.
	if (ispath(output, /obj/item/stack))
		new output(T, 1)
	else
		new output(T)
	return output
