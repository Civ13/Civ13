// Original active-search prototype. No map enables this experimental feature.
#define FORAGING_CELL_SIZE 8
#define FORAGING_CELL_STOCK 4
#define FORAGING_CONTENT_LIMIT 64

/obj/map_metadata/var/foraging_enabled = FALSE

// Sparse, ordinary saved roots, not a global cache or mutable turf variable.
// No automatic regeneration in phase one: changing terrain or relogging cannot
// replenish a cell. Keep exhausted records until the world is deliberately reset.
/obj/foraging_cell
	name = "foraging depletion record"
	invisibility = 101
	mouse_opacity = 0
	anchored = TRUE
	density = FALSE
	sinkable = FALSE
	var/remaining = FORAGING_CELL_STOCK

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
	return saved

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
		if (found || !isnum(C.remaining) || C.remaining < 0 || C.remaining > FORAGING_CELL_STOCK || round(C.remaining) != C.remaining)
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
	return C.remaining

/proc/foraging_persistence_ready(expected_identity)
	return !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && expected_identity == persistence_admission_identity

/mob/living/human/verb/forage_nearby()
	set name = "Forage nearby (experimental)"
	set category = "Crafting"
	if (!map || !map.foraging_enabled)
		to_chat(src, SPAN_WARNING("Experimental foraging is not enabled on this map."))
		return
	var/turf/T = loc
	if (!isturf(loc) || !client || incapacitated(INCAPACITATION_DEFAULT) || !foraging_site(T))
		to_chat(src, SPAN_WARNING("Search on open outdoor grass, dirt or sand, away from structures and roofs."))
		return
	if (!foraging_available(T))
		to_chat(src, SPAN_NOTICE("This patch has already been picked clean."))
		return
	if (!T.sifting_identity)
		T.sifting_identity = new /datum
	var/datum/terrain_identity = T.sifting_identity
	var/epoch = persistence_admission_identity
	if (!foraging_persistence_ready(epoch))
		return
	to_chat(src, SPAN_NOTICE("You begin searching the ground. Moving or changing your held item cancels the search."))
	// Existing do_after owns repeated-action, movement, hand and incapacity guards.
	// No skill bonuses/XP until the finite-stock economy is tested in play.
	if (!do_after(src, 300, T))
		return
	if (!src || !client || !map || !map.foraging_enabled || loc != T || T.sifting_identity != terrain_identity || incapacitated(INCAPACITATION_DEFAULT) || !foraging_site(T) || !foraging_persistence_ready(epoch))
		return
	if (!foraging_commit(T, epoch))
		to_chat(src, SPAN_NOTICE("Nothing remains to collect here."))
	else
		to_chat(src, SPAN_NOTICE("You uncover a small useful material at your feet."))

// No input, sleeps or result previews between validation and debit. Every result
// costs one shared unit. Concurrent completions recheck the current stock here.
/proc/foraging_commit(turf/T, expected_identity)
	if (!map || !map.foraging_enabled || !foraging_site(T) || !foraging_persistence_ready(expected_identity))
		return FALSE
	var/turf/anchor = foraging_anchor(T)
	var/record = foraging_record(anchor)
	if (!isnull(record) && !record)
		return FALSE
	var/obj/foraging_cell/C = record
	if (!C)
		C = new(anchor)
	if (C.remaining <= 0)
		return FALSE
	C.remaining--
	var/ground = ecology_ground(T)
	var/output = /obj/item/stack/material/stone
	if ((ground == ECO_GRASS || ground == ECO_DIRT) && prob(50))
		output = /obj/item/stack/material/wood_piece
	// Existing stack constructor receives an explicit single unit. No ores,
	// poisonous foods, recipes or research gates are bypassed by this table.
	new output(T, 1)
	return TRUE
