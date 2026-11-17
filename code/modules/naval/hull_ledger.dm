// ============================================================
// The hull ledger (docs/hull-ledger.md): the condition of a hull afloat
// ------------------------------------------------------------
// Every hull the players built and commissioned on the water keeps one small
// record of her condition. It is plain numbers on the craft, like a
// submarine's air ledger: no water lies on any tile.
//
// What a crew has to do about it grows with her size:
//
//   - small craft (up to HULL_SMALL_MAX_TILES tiles of hull) take no water
//     from their seams;
//   - boats and ships built of wood seep. Water gathers in the bilge while
//     she is under way, and half as fast while she lies still with a player
//     aboard. A hull with nobody aboard that is not under way does not
//     change at all, so nobody comes back to a boat that filled while they
//     were away.
//
// Water in the bilge is weight her drives have to push (craft.mass()), so she
// loses way as it rises. Until holes and foundering arrive the water stops at
// awash: half of what she holds.
//
// Bailing: stand on her deck and use an empty bucket on a plank. Each
// bucketful takes HULL_BAIL_TIME and goes over the side; you keep bailing
// until the bilge is dry, you move, or you put the bucket away.
//
// One timer steps every ledger that is awake, every HULL_LEDGER_STEP. The
// ledger is saved by the tiller in its hull record and stores no world.time.
// Airships share the built body but never touch water: they get no ledger.
// ============================================================

#define HULL_CLASS_SMALL 1
#define HULL_CLASS_BOAT 2
#define HULL_CLASS_SHIP 3
#define HULL_SMALL_MAX_TILES 12
#define HULL_BOAT_MAX_TILES 40

// Bucketfuls of water a tile of hull holds before she is full.
#define HULL_BILGE_PER_TILE 4
// The share of that at which her deck is awash.
#define HULL_AWASH 0.5
// The share of it she carries without feeling the weight.
#define HULL_SLACK_WATER 0.1
// Bucketfuls a minute that seep through the seams of one wooden tile of a
// tight hull under way: a boat left alone is awash in about three quarters
// of an hour, and half an hour's seepage is two minutes' bailing for one
// person, whatever her size.
#define HULL_SEEP_PER_TILE_MINUTE 0.045
// Lying still she works her seams less.
#define HULL_SEEP_AT_REST 0.5
// Deciseconds between steps of the ledgers, and to bail one bucketful.
#define HULL_LEDGER_STEP 300
#define HULL_BAIL_TIME 30

// How deep the bilge is, for messages: the share of her capacity each begins at.
#define HULL_DEPTH_DRY 0
#define HULL_DEPTH_DAMP 1
#define HULL_DEPTH_ANKLE 2
#define HULL_DEPTH_KNEE 3
#define HULL_DEPTH_AWASH 4

var/global/list/hull_ledgers = list()
var/global/hull_ledger_timer = 0
// Set by a test that steps the ledgers by hand.
var/global/hull_ledger_timer_off = FALSE

/datum/craft
	var/datum/hull_ledger/ledger

/datum/hull_ledger
	var/datum/craft/craft
	// Bucketfuls of water in the bilge.
	var/water = 0
	// Tiles of hull, and how many of them are wood, as last surveyed.
	var/tiles = 1
	var/seep_tiles = 0
	// The depth her crew was last told of, so each is called out once.
	var/tmp/depth_told = HULL_DEPTH_DRY
	// A player was aboard at the last step.
	var/tmp/crewed = FALSE
	// Who is bailing now: mob = TRUE.
	var/tmp/list/bailers = list()

/datum/hull_ledger/New(datum/craft/new_craft)
	..()
	craft = new_craft
	hull_ledgers += src
	if (!hull_ledger_timer && !hull_ledger_timer_off)
		hull_ledger_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(hull_ledgers_tick)), HULL_LEDGER_STEP, TIMER_LOOP | TIMER_STOPPABLE)

/datum/hull_ledger/Destroy()
	hull_ledgers -= src
	if (craft && craft.ledger == src)
		craft.ledger = null
	craft = null
	bailers = null
	return ..()

// TRUE for a plank that lets no water through its seams.
/proc/hull_plank_tight(obj/covers/C)
	return lowertext("[C.material]") in list("steel", "iron", "aluminium", "aluminum")

// Counts her tiles again: after she is commissioned, refitted or loaded.
/datum/hull_ledger/proc/survey()
	tiles = 1
	seep_tiles = 0
	if (!craft || !craft.body)
		return
	var/list/cells = craft.body.cells()
	tiles = max(1, cells.len)
	for (var/turf/T in cells)
		var/tight = FALSE
		for (var/obj/covers/C in T)
			if (C.loc == T && hull_plank_tight(C))
				tight = TRUE
				break
		if (!tight)
			seep_tiles++
	water = min(water, limit())

/datum/hull_ledger/proc/hull_class()
	if (tiles <= HULL_SMALL_MAX_TILES)
		return HULL_CLASS_SMALL
	if (tiles <= HULL_BOAT_MAX_TILES)
		return HULL_CLASS_BOAT
	return HULL_CLASS_SHIP

/datum/hull_ledger/proc/class_name()
	switch (hull_class())
		if (HULL_CLASS_SMALL)
			return "small craft"
		if (HULL_CLASS_BOAT)
			return "boat"
	return "ship"

// Bucketfuls she holds when full, and the most the bilge takes now.
/datum/hull_ledger/proc/capacity()
	return tiles * HULL_BILGE_PER_TILE

/datum/hull_ledger/proc/limit()
	return capacity() * HULL_AWASH

// The share of her capacity that is water, 0 to 1.
/datum/hull_ledger/proc/fill()
	return clamp(water / capacity(), 0, 1)

/datum/hull_ledger/proc/depth()
	var/share = fill()
	if (water < 1)
		return HULL_DEPTH_DRY
	if (share < HULL_SLACK_WATER)
		return HULL_DEPTH_DAMP
	if (share < 0.25)
		return HULL_DEPTH_ANKLE
	if (share < HULL_AWASH - 0.001)
		return HULL_DEPTH_KNEE
	return HULL_DEPTH_AWASH

/proc/hull_depth_name(depth)
	switch (depth)
		if (HULL_DEPTH_DAMP)
			return "damp"
		if (HULL_DEPTH_ANKLE)
			return "ankle deep"
		if (HULL_DEPTH_KNEE)
			return "knee deep"
		if (HULL_DEPTH_AWASH)
			return "awash"
	return "dry"

// Tiles of hull the water in her weighs as much as. A damp bilge weighs
// nothing she would notice.
/datum/hull_ledger/proc/water_weight()
	return round(tiles * max(0, fill() - HULL_SLACK_WATER))

// Bucketfuls a minute through her seams, under way.
/datum/hull_ledger/proc/seep_rate()
	if (hull_class() == HULL_CLASS_SMALL)
		return 0
	return seep_tiles * HULL_SEEP_PER_TILE_MINUTE

/datum/hull_ledger/proc/under_way()
	return craft && craft.speed > 0 && !craft.anchored

// TRUE while she changes: under way, or with a player aboard.
/datum/hull_ledger/proc/awake()
	return crewed || under_way()

// TRUE when this turf is one of her deck tiles, on either deck.
/datum/hull_ledger/proc/deck_holds(turf/T)
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!T || !istype(B) || !B.placed())
		return FALSE
	if (T.z == B.z)
		return B.contains(T)
	if (T.z == B.upper_z())
		return B.contains(locate(T.x, T.y, B.z))
	return FALSE

// Takes water in. Her crew hears of it when the bilge is a step deeper.
/datum/hull_ledger/proc/add_water(amount)
	if (amount <= 0)
		return
	water = min(limit(), water + amount)
	var/now = depth()
	if (now > depth_told && craft)
		switch (now)
			if (HULL_DEPTH_ANKLE)
				craft.crew_message(SPAN_NOTICE("Water slops in the bilge of the [craft.name]: it is ankle deep. An empty bucket used on her planks bails it out."))
			if (HULL_DEPTH_KNEE)
				craft.crew_message(SPAN_WARNING("The bilge of the [craft.name] is knee deep. She is heavy with it and slow to answer."))
			if (HULL_DEPTH_AWASH)
				craft.crew_message(SPAN_DANGER("<b>The [craft.name] is awash!</b> Water washes over her planks and she wallows. Bail her out."))
	depth_told = max(depth_told, now)

// Takes water out. Returns what came out.
/datum/hull_ledger/proc/remove_water(amount)
	. = min(water, max(0, amount))
	water -= .
	if (water < 0.01)
		water = 0
	depth_told = min(depth_told, depth())

// One step of seconds.
/datum/hull_ledger/proc/step_ledger(seconds)
	if (!craft || !craft.body || !craft.body.placed())
		return
	var/rate = seep_rate()
	if (rate > 0)
		add_water(rate * (under_way() ? 1 : HULL_SEEP_AT_REST) * seconds / 60)

/datum/hull_ledger/proc/status_text()
	. = "She is a [class_name()]."
	var/now = depth()
	if (now == HULL_DEPTH_DRY)
		. += " Her bilge is dry."
	else
		. += " Her bilge is [hull_depth_name(now)]: [round(water)] bucketful\s of [round(limit())] before she is awash"
		var/weight = water_weight()
		. += weight > 0 ? ", weighing on her like [weight] more tile\s of hull." : "."
	if (seep_rate() <= 0)
		. += hull_class() == HULL_CLASS_SMALL ? " A hull this small keeps the sea out by herself." : " Her plating lets nothing through."
	else
		. += " Her seams seep while she works: bail her now and then."

// The ledger as plain numbers for a saved field, and back.
/datum/hull_ledger/proc/to_list()
	return list("water" = round(water, 0.01))

/datum/hull_ledger/proc/from_list(list/state)
	if (!islist(state))
		return
	if (isnum(state["water"]))
		water = clamp(state["water"], 0, limit())
	depth_told = depth()

// ---- The craft's side ----

// Gives a hull on the water her ledger, or surveys the one she has. An
// airship and a turf-built vessel have none.
/datum/craft/proc/fit_ledger(list/state = null)
	var/datum/craft_body/built/B = body
	if (!istype(B) || istype(B, /datum/craft_body/built/air) || !B.placed())
		return null
	if (!ledger)
		ledger = new /datum/hull_ledger(src)
	ledger.survey()
	if (state)
		ledger.from_list(state)
	return ledger

/datum/craft/Destroy()
	if (ledger)
		qdel(ledger)
		ledger = null
	return ..()

// ---- The step ----

// Steps every ledger that is awake. Players are found from the client list,
// so a harbour of empty boats costs one lookup a player and no deck walk.
/proc/hull_ledgers_tick()
	if (persistence_save_in_progress || !hull_ledgers.len)
		return 0
	for (var/datum/hull_ledger/L in hull_ledgers)
		L.crewed = FALSE
	for (var/client/C in clients)
		var/mob/living/M = C.mob
		if (!istype(M) || M.stat == DEAD)
			continue
		var/turf/T = get_turf(M)
		if (!T)
			continue
		for (var/datum/hull_ledger/L in hull_ledgers)
			if (!L.crewed && L.deck_holds(T))
				L.crewed = TRUE
				break
	. = 0
	for (var/datum/hull_ledger/L in hull_ledgers)
		if (L.awake())
			L.step_ledger(HULL_LEDGER_STEP / 10)
			.++

// ---- Bailing ----

// Why H cannot bail the hull under plank P with W, or null.
/proc/hull_bail_refusal(mob/living/human/H, obj/item/weapon/reagent_containers/glass/bucket/W, obj/covers/P)
	if (!istype(H) || !istype(W) || !P)
		return "nothing to bail with"
	var/turf/plank = get_turf(P)
	var/datum/craft/C = plank ? craft_at(plank) : null
	if (!C || !C.ledger)
		return "that is not a hull afloat"
	if (!C.body.contains(get_turf(H)))
		return "stand on her deck to bail her"
	if (H.stat || H.lying || H.restrained())
		return "you are in no state to bail"
	if (W.reagents && W.reagents.total_volume > 0)
		return "empty the bucket first"
	if (C.ledger.water < 1)
		return "her bilge is dry"
	return null

// H bails with bucket W until the bilge is dry or they stop. Returns the
// bucketfuls that went over the side.
/proc/hull_bail(mob/living/human/H, obj/item/weapon/reagent_containers/glass/bucket/W, obj/covers/P)
	. = 0
	var/why = hull_bail_refusal(H, W, P)
	if (why)
		to_chat(H, SPAN_WARNING("You cannot bail here: [why]."))
		return
	var/datum/craft/C = craft_at(get_turf(P))
	var/datum/hull_ledger/L = C.ledger
	if (L.bailers[H])
		return
	L.bailers[H] = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts bailing the [C.name] with \a [W]."), SPAN_NOTICE("You start bailing the [C.name]."))
	while (TRUE)
		var/off_x = H.x - P.x
		var/off_y = H.y - P.y
		var/began = world.time
		if (!do_after(H, HULL_BAIL_TIME, P))
			// A step of the hull carries bailer and plank together and breaks
			// the wait: that bucketful starts again. Anything else stops them.
			if (!QDELETED(L) && !QDELETED(P) && !QDELETED(H) && L.under_way() && world.time > began && H.x - P.x == off_x && H.y - P.y == off_y && H.get_active_hand() == W && !hull_bail_refusal(H, W, P))
				continue
			break
		if (QDELETED(L) || QDELETED(W) || QDELETED(P) || H.get_active_hand() != W || hull_bail_refusal(H, W, P))
			break
		. += L.remove_water(1)
		playsound(get_turf(H), 'sound/effects/slosh.ogg', 25, TRUE)
	if (!QDELETED(L))
		L.bailers -= H
		if (.)
			to_chat(H, SPAN_NOTICE("You bail [round(., 0.1)] bucketful\s over the side. Her bilge is [hull_depth_name(L.depth())]."))

// An empty bucket used on a plank of a hull with water in her bails. A full
// bucket, a dry bilge and a plank of anything else behave as they always did.
/obj/covers/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/glass/bucket) && ishuman(user))
		var/obj/item/weapon/reagent_containers/glass/bucket/B = W
		var/turf/plank = get_turf(src)
		var/datum/craft/C = plank ? craft_at(plank) : null
		if (C && C.ledger && C.ledger.water >= 1 && !(B.reagents && B.reagents.total_volume > 0) && C.body.contains(get_turf(user)))
			hull_bail(user, B, src)
			return TRUE
	return ..()

#undef HULL_SLACK_WATER
#undef HULL_SEEP_PER_TILE_MINUTE
#undef HULL_SEEP_AT_REST
#undef HULL_BAIL_TIME
