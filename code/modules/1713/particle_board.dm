// Particle board (Val, 2026-11-22).
//
// The large and powered saw mills leave sawdust beside the planks they cut:
// one pile for every two logs. The hot press (resin_laminate.dm) bonds
// PARTICLE_SAWDUST piles of it with PARTICLE_RESIN units of resin into
// particle board: 3 sheets with phenolic resin, 2 with plain pine resin. A
// pressing is quicker than a laminate pressing.
//
// Particle board is cheap and quick to build with, but weaker than planks, and
// it is for indoor work only: shelves, cabinets, wardrobes, bookcases, tables,
// partition walls and floors (config/crafting/material_recipes_global.txt).
// It is never a tool handle or boat material, and nothing of it may be built
// aboard a vessel.
//
// Water ruins it. Once a minute every particle board sheet or build lying on a
// tile that is flooded, puddled, open water or rained on soaks a little more.
// After PARTICLE_SWELL wet minutes it swells: sheets turn into swollen boards
// nobody can build with, and builds sag and weaken. After PARTICLE_CRUMBLE wet
// minutes it falls apart. Swelling never dries out. The worker visits only the
// particle board things in particle_board_things, never the map.
//
// Sprites by Fable (icons/obj/particle_board.dmi, tests/sprites/create_particle_board.py).

#define PARTICLE_SAWDUST 4
#define PARTICLE_RESIN 10
#define PARTICLE_PRESS_TIME 50
#define PARTICLE_SOAK_STEP 600 // one wet check a minute
#define PARTICLE_SWELL 2
#define PARTICLE_CRUMBLE 5

// Every particle board sheet, swollen board and build in the world (lazy).
var/global/list/particle_board_things
var/global/particle_board_timer
// Set by test fixtures to stop the minute worker from starting.
var/global/particle_board_timer_off

/proc/particle_board_track(obj/O)
	if (!particle_board_things)
		particle_board_things = list()
	particle_board_things |= O
	if (!particle_board_timer && !particle_board_timer_off)
		particle_board_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(particle_board_tick)), PARTICLE_SOAK_STEP, TIMER_LOOP | TIMER_STOPPABLE)

/proc/particle_board_untrack(obj/O)
	if (particle_board_things)
		particle_board_things -= O

// TRUE when water reaches what lies on T: floodwater, a puddle, a flooded
// deck, open water, or rain falling on an open tile.
/proc/particle_board_wet_at(turf/T)
	if (!T)
		return FALSE
	if (istype(T, /turf/floor/beach/water))
		return TRUE
	if (flood_depth_at(T) > 0)
		return TRUE
	if (locate(/obj/effect/flooding) in T)
		return TRUE
	if (istype(T, /turf/floor/sub_deck))
		var/turf/floor/sub_deck/SD = T
		if (SD.water_depth > 0)
			return TRUE
	// Roofed tiles answer WEATHER_NONE (weather_systems.dm).
	var/class = weather_at(T)
	if (class != WEATHER_WET && class != WEATHER_EXTREME)
		return FALSE
	var/look = weather_look_at(T)
	if (!findtext(look, "rain") && look != "monsoon")
		return FALSE
	return !under_canopy(T)

// One wet check for every tracked thing.
/proc/particle_board_tick()
	if (!particle_board_things || !particle_board_things.len || persistence_save_in_progress)
		return
	for (var/obj/O in particle_board_things.Copy())
		if (QDELETED(O))
			particle_board_things -= O
			continue
		if (!isturf(O.loc) || !particle_board_wet_at(O.loc))
			continue
		O.particle_board_soak()

// Called once per wet minute on a tracked thing. Each kind overrides it.
/obj/proc/particle_board_soak()
	return

// Tell those nearby that the board fell apart, and spill what it held.
/proc/particle_board_crumble(obj/O)
	O.visible_message(SPAN_WARNING("\The [O] swells, splits and falls apart into wet crumbs."))
	particle_board_crumble_quietly(O)

/proc/particle_board_swell_text()
	return " It has soaked up water and swollen out of true; it will not take much more."

// ---- sawdust ----------------------------------------------------

/obj/item/stack/sawdust
	name = "sawdust"
	singular_name = "pile of sawdust"
	desc = "Fine pale sawdust swept up from a saw mill. Bonded with resin in a hot press, it makes particle board."
	icon = 'icons/obj/particle_board.dmi'
	icon_state = "sawdust"
	w_class = ITEM_SIZE_SMALL
	max_amount = 50
	can_stack = TRUE
	stacktype = /obj/item/stack/sawdust
	value = 0
	flammable = TRUE

/obj/item/stack/sawdust/New()
	..()
	update_icon()

/obj/item/stack/sawdust/update_icon()
	icon_state = "sawdust[pile_suffix(amount, list(10, 25, 40))]"

// Saw mill hook (production.dm finish_work): the large and powered mills
// leave one pile of sawdust for every two logs cut.
/obj/structure/sawmill/proc/sawmill_sawdust(obj/item/stack/W)
	if (is_primitive_mill() || !istype(W, /obj/item/stack/material/wood) || W.amount <= 0)
		return null
	var/piles = ceil(W.amount / 2)
	var/turf/T = get_turf(src)
	for (var/obj/item/stack/sawdust/existing in T)
		if (existing.amount + piles <= existing.max_amount)
			existing.amount += piles
			existing.update_icon()
			existing.update_strings()
			return existing
	return new /obj/item/stack/sawdust(T, piles)

// ---- the board ----------------------------------------------------

/material/particle_board
	name = "particle_board"
	display_name = "particle board"
	use_name = "particle board"
	icon_colour = "#C9A66B"
	hardness = 15
	weight = 6
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/particle_board
	integrity = 40
	resilience = 0.2
	density = 7
	firmness = 20
	toughness = 10
	wear = 25
	heat_limit = 160
	shaping = SHAPE_MOULDED

/obj/item/stack/material/particle_board
	name = "particle board"
	desc = "Flat sheets of sawdust pressed in resin. Cheap and quick to build shelves, cabinets, tables, partition walls and floors with, but weaker than planks. Keep it dry: water swells it until it falls apart."
	icon = 'icons/obj/particle_board.dmi'
	icon_state = "particle_board"
	default_type = "particle_board"
	apply_colour = FALSE
	value = 2
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE
	var/particle_soak = 0

/obj/item/stack/material/particle_board/New()
	..()
	update_icon()
	particle_board_track(src)

/obj/item/stack/material/particle_board/Destroy()
	particle_board_untrack(src)
	return ..()

/obj/item/stack/material/particle_board/update_icon()
	icon_state = "particle_board[pile_suffix(amount, list(13, 26, 39))]"

/obj/item/stack/material/particle_board/particle_board_soak()
	particle_soak++
	if (particle_soak < PARTICLE_SWELL)
		return
	var/turf/T = get_turf(src)
	var/obj/item/stack/swollen_particle_board/S = new(T, amount)
	S.particle_soak = particle_soak
	visible_message(SPAN_WARNING("\The [src] soaks up the water and swells."))
	qdel(src)

// What is left of particle board after a soaking: no use but as kindling.
/obj/item/stack/swollen_particle_board
	name = "swollen particle board"
	singular_name = "swollen sheet"
	desc = "Particle board that has soaked up water. It has puffed up and gone soft at the edges, and it crumbles in the hand. Nothing can be built with it."
	icon = 'icons/obj/particle_board.dmi'
	icon_state = "particle_board_swollen"
	w_class = ITEM_SIZE_NORMAL
	max_amount = 50
	can_stack = TRUE
	stacktype = /obj/item/stack/swollen_particle_board
	value = 0
	flammable = TRUE
	var/particle_soak = 0

/obj/item/stack/swollen_particle_board/New()
	..()
	particle_board_track(src)

/obj/item/stack/swollen_particle_board/Destroy()
	particle_board_untrack(src)
	return ..()

/obj/item/stack/swollen_particle_board/particle_board_soak()
	particle_soak++
	if (particle_soak >= PARTICLE_CRUMBLE)
		particle_board_crumble(src)

// ---- the hot press ------------------------------------------------

// Sheets of particle board one pressing gives with this resin.
/proc/particle_board_yield(resin_id)
	if (resin_id == "phenolic_resin")
		return 3
	if (resin_id == "resin")
		return 2
	return 0

/obj/structure/hot_press/proc/press_particle_board(obj/item/stack/sawdust/S, mob/living/human/H)
	var/resin_id = press_resin()
	if (!resin_id)
		to_chat(H, SPAN_WARNING("\The [src] needs [PARTICLE_RESIN] units of phenolic or pine resin first."))
		return FALSE
	if (S.amount < PARTICLE_SAWDUST)
		to_chat(H, SPAN_WARNING("You need [PARTICLE_SAWDUST] piles of sawdust for one pressing."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] spreads resined sawdust between the platens of \the [src] and screws it down."), SPAN_NOTICE("You spread the resined sawdust between the platens and screw \the [src] down."))
	icon_state = "hot_press_on"
	var/done = particle_press_wait(H)
	icon_state = initial(icon_state)
	if (!done || persistence_save_in_progress || QDELETED(src) || QDELETED(S) || S.amount < PARTICLE_SAWDUST || press_resin() != resin_id)
		return FALSE
	var/sheets = particle_board_yield(resin_id)
	if (!sheets || !S.use(PARTICLE_SAWDUST))
		return FALSE
	reagents.remove_reagent(resin_id, PARTICLE_RESIN)
	var/obj/item/stack/material/particle_board/P = new(get_turf(src), sheets)
	H.put_in_hands(P)
	to_chat(H, SPAN_NOTICE("You unscrew \the [src]: [sheets] sheet\s of particle board."))
	return TRUE

// The wait, as a proc so a test fixture can stand in for do_after.
/obj/structure/hot_press/proc/particle_press_wait(mob/living/human/H)
	return do_after(H, PARTICLE_PRESS_TIME, src)

// ---- builds ----------------------------------------------------
// Each build swells after PARTICLE_SWELL wet minutes and falls apart after
// PARTICLE_CRUMBLE. Refunds come from their own recipes (dismantle_refund.dm).

// TRUE for a recipe product made of particle board (craft guard below).
/proc/particle_board_path(path)
	return ispath(path, /obj/structure/table/rack/shelf/wooden/particle_board) || ispath(path, /obj/structure/table/modern/table/particle_board) || ispath(path, /obj/structure/closet/cabinet/particle_board) || ispath(path, /obj/structure/bookcase/particle_board) || ispath(path, /obj/covers/wood_wall/particle_board) || ispath(path, /obj/covers/wood/particle_board)

// Particle board drinks in sea spray and bilge water: nothing of it is built aboard.
/datum/craft_guard/particle_board_afloat
	order = 85
	after_wait = TRUE

/datum/craft_guard/particle_board_afloat/refusal(mob/living/human/H, datum/stack_recipe/R, phase)
	if (!particle_board_path(R.result_type))
		return null
	if (!vessel_building_deck_at(H))
		return null
	return phase == CRAFT_GUARD_START ? SPAN_WARNING("Particle board would soak up the bilge and spray and fall apart. Build it ashore, indoors.") : ""

/obj/structure/table/rack/shelf/wooden/particle_board
	name = "particle board shelf"
	desc = "A cheap shelf of particle board. Keep it dry."
	framestack = /obj/item/stack/material/particle_board
	buildstack = /obj/item/stack/material/particle_board
	framestackamount = 0
	var/particle_soak = 0

/obj/structure/table/modern/table/particle_board
	name = "particle board table"
	desc = "A cheap flat-pack table of particle board. Keep it dry."
	framestack = /obj/item/stack/material/particle_board
	buildstack = /obj/item/stack/material/particle_board
	framestackamount = 0
	var/particle_soak = 0

// Taking either apart leaves no wooden frame (2 is TBL_DISASSEMBLE, 3 is
// TBL_DECONSTRUCT in table.dm): particle board was never a plank frame.
/obj/structure/table/rack/shelf/wooden/particle_board/table_destroy(destroy_type, mob/user)
	return ..(destroy_type == 2 ? 3 : destroy_type, user)

/obj/structure/table/modern/table/particle_board/table_destroy(destroy_type, mob/user)
	return ..(destroy_type == 2 ? 3 : destroy_type, user)

/obj/structure/closet/cabinet/particle_board
	name = "particle board wardrobe"
	desc = "A cheap flat-pack wardrobe of particle board. Keep it dry."
	var/particle_soak = 0

/obj/structure/closet/cabinet/particle_board/wall
	name = "particle board wall cabinet"
	desc = "A cheap wall cabinet of particle board. Keep it dry."
	icon_state = "cabinet_closed_ceiling"
	icon_closed = "cabinet_closed_ceiling"
	icon_opened = "cabinet_open_ceiling"
	anchored = TRUE
	store_mobs = FALSE

/obj/structure/bookcase/particle_board
	name = "particle board bookcase"
	desc = "A cheap bookcase of particle board. Keep it dry."
	var/particle_soak = 0

// The plain bookcase hands back a plank when knocked apart; this one gives a sheet.
/obj/structure/bookcase/particle_board/attackby(obj/O, mob/living/human/user)
	if (!is_tool(O, TOOL_HAMMER))
		return ..()
	playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
	to_chat(user, SPAN_NOTICE("You begin knocking \the [src] apart."))
	if (!do_after(user, 25, src) || QDELETED(src))
		return
	to_chat(user, SPAN_NOTICE("You knock \the [src] apart."))
	new /obj/item/stack/material/particle_board(get_turf(src))
	particle_board_crumble_quietly(src)

// Spill what it held and remove it.
/proc/particle_board_crumble_quietly(obj/O)
	var/turf/T = get_turf(O)
	for (var/atom/movable/AM in O.contents)
		AM.forceMove(T)
	qdel(O)

/obj/covers/wood_wall/particle_board
	name = "particle board partition"
	desc = "A light indoor partition wall of particle board panels on timber studs. Quick to put up, easy to break through, and ruined by water."
	icon = 'icons/obj/particle_board.dmi'
	icon_state = "particle_wall"
	base_icon_state = "particle_wall"
	adjusts = FALSE
	health = 120
	maxhealth = 120
	hardness = 35
	explosion_resistance = 2
	var/particle_soak = 0

/obj/covers/wood/particle_board
	name = "particle board floor"
	desc = "Square sheets of particle board laid as a floor. Smooth and cheap; keep it dry."
	icon = 'icons/obj/particle_board.dmi'
	icon_state = "particle_floor"
	var/particle_soak = 0

// New/Destroy/soak for each build. The tables, closets and bookcases share
// these bodies through the procs below.
/proc/particle_build_soak(obj/O, soak, swollen_state)
	if (soak == PARTICLE_SWELL)
		O.name = "swollen [O.name]"
		O.desc += particle_board_swell_text()
		if (swollen_state)
			O.icon_state = swollen_state
		O.visible_message(SPAN_WARNING("\The [O] soaks up the water and swells."))
	else if (soak >= PARTICLE_CRUMBLE)
		particle_board_crumble(O)

/obj/structure/table/rack/shelf/wooden/particle_board/New()
	..()
	particle_board_track(src)
/obj/structure/table/rack/shelf/wooden/particle_board/Destroy()
	particle_board_untrack(src)
	return ..()
/obj/structure/table/rack/shelf/wooden/particle_board/particle_board_soak()
	particle_build_soak(src, ++particle_soak)

/obj/structure/table/modern/table/particle_board/New()
	..()
	particle_board_track(src)
/obj/structure/table/modern/table/particle_board/Destroy()
	particle_board_untrack(src)
	return ..()
/obj/structure/table/modern/table/particle_board/particle_board_soak()
	particle_build_soak(src, ++particle_soak)

/obj/structure/closet/cabinet/particle_board/New()
	..()
	particle_board_track(src)
/obj/structure/closet/cabinet/particle_board/Destroy()
	particle_board_untrack(src)
	return ..()
/obj/structure/closet/cabinet/particle_board/particle_board_soak()
	particle_build_soak(src, ++particle_soak)

/obj/structure/bookcase/particle_board/New()
	..()
	particle_board_track(src)
/obj/structure/bookcase/particle_board/Destroy()
	particle_board_untrack(src)
	return ..()
/obj/structure/bookcase/particle_board/particle_board_soak()
	particle_build_soak(src, ++particle_soak)

/obj/covers/wood_wall/particle_board/New()
	..()
	particle_board_track(src)
/obj/covers/wood_wall/particle_board/Destroy()
	particle_board_untrack(src)
	return ..()
/obj/covers/wood_wall/particle_board/particle_board_soak()
	particle_soak++
	if (particle_soak == PARTICLE_SWELL)
		health = min(health, round(maxhealth / 2))
	particle_build_soak(src, particle_soak, "particle_wall_swollen")

/obj/covers/wood/particle_board/New()
	..()
	particle_board_track(src)
/obj/covers/wood/particle_board/Destroy()
	particle_board_untrack(src)
	return ..()
/obj/covers/wood/particle_board/particle_board_soak()
	particle_build_soak(src, ++particle_soak, "particle_floor_swollen")

#undef PARTICLE_SAWDUST
#undef PARTICLE_RESIN
#undef PARTICLE_PRESS_TIME
#undef PARTICLE_SOAK_STEP
#undef PARTICLE_SWELL
#undef PARTICLE_CRUMBLE
