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
// loses way as it rises. Her seams alone never take her past awash, half of
// what she holds: neglect makes her wallow, it does not sink her.
//
// Holes do. A tile of her hull whose floor is gone (shot away, blown out by a
// mine, broken on a reef, or cut out by her own crew) is a hole, whatever her
// size or her planking. Each one lets in HULL_HOLE_PER_MINUTE while she is
// awake, more than one bailer can keep up with. Three quarters full she lists
// and makes slow ahead at best. Full, she founders: in the shallows she
// settles on the bottom until she is patched and bailed below awash; on deep
// water she goes down HULL_SINK_WARNINGS half minutes later unless her crew
// gets ahead of the water, and the hull is lost. Her crew and loose things
// are left in the water.
//
// A patch: stand on her deck with a hammer in the other hand and use
// HULL_PATCH_PLANKS wood on the open water of the hole. A patch is a floor
// again and stops the hole, but weeps HULL_PATCH_PER_MINUTE.
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
// Seam wear runs from 0, freshly caulked, to 1, open. A hull starts sound, at
// a third, where she seeps at the rate above; tight she seeps half that and
// open twice. HULL_SEAM_LIFE seconds under way wear her from tight to open.
#define HULL_SEAMS_FAIR (1 / 3)
#define HULL_SEAMS_WORKING 0.6
#define HULL_SEAMS_OPEN 0.9
#define HULL_SEAM_LIFE 14400
// Deciseconds between steps of the ledgers, and to bail one bucketful.
#define HULL_LEDGER_STEP 300
#define HULL_BAIL_TIME 30
// Bucketfuls a minute through an open hole, and through a patched one.
#define HULL_HOLE_PER_MINUTE 25
#define HULL_PATCH_PER_MINUTE 1
// The share of her capacity at which she lists.
#define HULL_LISTING 0.75
// Wood and deciseconds a patch takes.
#define HULL_PATCH_PLANKS 2
#define HULL_PATCH_TIME 60
// Half minutes between foundering on deep water and going down.
#define HULL_SINK_WARNINGS 4

// How deep the bilge is, for messages: the share of her capacity each begins at.
#define HULL_DEPTH_DRY 0
#define HULL_DEPTH_DAMP 1
#define HULL_DEPTH_ANKLE 2
#define HULL_DEPTH_KNEE 3
#define HULL_DEPTH_AWASH 4
#define HULL_DEPTH_LISTING 5
#define HULL_DEPTH_FULL 6

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
	// How worn the caulking of her seams is: 0 tight, 1 open (hull_caulking.dm).
	var/seams = HULL_SEAMS_FAIR
	var/tmp/seams_told = 0
	// Tiles of her hull with no floor left, and tiles floored with a patch.
	var/holes = 0
	var/patches = 0
	// She sits on the bottom in the shallows.
	var/grounded = FALSE
	// Half minutes left before she goes down, while she is foundering.
	var/tmp/sink_left = 0
	var/tmp/sink_timer = 0
	// Set while she goes down, so her own planks leaving are not new holes.
	var/tmp/sinking = FALSE
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
	if (sink_timer)
		deltimer(sink_timer)
		sink_timer = 0
	if (craft && craft.ledger == src)
		craft.ledger = null
	craft = null
	bailers = null
	return ..()

// TRUE for a plank that lets no water through its seams.
/proc/hull_plank_tight(obj/covers/C)
	return lowertext("[C.material]") in list("steel", "iron", "aluminium", "aluminum")

// TRUE for a floor of a hull: a plank or plate, not a wall built aboard.
/proc/hull_floor_plank(obj/covers/C, turf/T)
	return C.loc == T && !C.wall && !QDELETED(C)

// TRUE when this tile of her hull has no floor left.
/datum/hull_ledger/proc/hole_at(turf/T, obj/covers/leaving = null)
	if (!craft || !craft.body || !craft.body.contains(T))
		return FALSE
	for (var/obj/covers/C in T)
		if (C != leaving && hull_floor_plank(C, T))
			return FALSE
	return TRUE

// Counts her tiles again: after she is commissioned, refitted or loaded.
/datum/hull_ledger/proc/survey()
	tiles = 1
	seep_tiles = 0
	holes = 0
	patches = 0
	if (!craft || !craft.body)
		return
	var/list/cells = craft.body.cells()
	tiles = max(1, cells.len)
	for (var/turf/T in cells)
		var/tight = FALSE
		var/floored = FALSE
		var/patched = FALSE
		for (var/obj/covers/C in T)
			if (!hull_floor_plank(C, T))
				continue
			floored = TRUE
			if (istype(C, /obj/covers/repairedfloor/ship/patch))
				patched = TRUE
			if (hull_plank_tight(C))
				tight = TRUE
		if (!floored)
			holes++
		else if (patched)
			patches++
		else if (!tight)
			seep_tiles++
	water = min(water, capacity())

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

// What her seams and patches fill her to. Holes fill her to the brim.
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
	if (share < HULL_LISTING)
		return HULL_DEPTH_AWASH
	if (share < 0.999)
		return HULL_DEPTH_LISTING
	return HULL_DEPTH_FULL

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
		if (HULL_DEPTH_LISTING)
			return "deep enough that she lists"
		if (HULL_DEPTH_FULL)
			return "full to the planks"
	return "dry"

// Tiles of hull the water in her weighs as much as. A damp bilge weighs
// nothing she would notice.
/datum/hull_ledger/proc/water_weight()
	return round(tiles * max(0, fill() - HULL_SLACK_WATER))

// Bucketfuls a minute through her seams, under way.
/datum/hull_ledger/proc/seep_rate()
	if (hull_class() == HULL_CLASS_SMALL)
		return 0
	return seep_tiles * HULL_SEEP_PER_TILE_MINUTE * seam_factor()

// How much faster or slower than fair seams hers let water in.
/datum/hull_ledger/proc/seam_factor()
	return 0.5 + 1.5 * clamp(seams, 0, 1)

// TRUE when she has seams that wear and can be caulked.
/datum/hull_ledger/proc/has_seams()
	return seep_tiles > 0 && hull_class() != HULL_CLASS_SMALL

/datum/hull_ledger/proc/seam_name()
	if (seams >= HULL_SEAMS_OPEN)
		return "open"
	if (seams >= HULL_SEAMS_WORKING)
		return "working loose"
	if (seams > HULL_SEAMS_FAIR + 0.01)
		return "fair"
	if (seams > 0.1)
		return "sound"
	return "tight"

// Sailing works the caulking out of her seams.
/datum/hull_ledger/proc/wear_seams(seconds)
	if (!has_seams() || seams >= 1)
		return
	seams = min(1, seams + seconds / HULL_SEAM_LIFE)
	var/now = seams >= HULL_SEAMS_OPEN ? 2 : (seams >= HULL_SEAMS_WORKING ? 1 : 0)
	if (now > seams_told && craft)
		if (now == 2)
			craft.crew_message(SPAN_DANGER("The seams of the [craft.name] are open: she takes water twice as fast as she should. She needs caulking with tarred oakum."))
		else
			craft.crew_message(SPAN_WARNING("The caulking of the [craft.name] is working loose and she seeps faster. Tarred oakum driven into her seams would tighten her."))
	seams_told = now

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
/datum/hull_ledger/proc/add_water(amount, cap = null)
	if (amount <= 0)
		return
	if (isnull(cap))
		cap = limit()
	// Water already past the cap (a hole since patched) stays until bailed.
	water = max(water, min(cap, water + amount))
	var/now = depth()
	if (now > depth_told && craft)
		switch (now)
			if (HULL_DEPTH_ANKLE)
				craft.crew_message(SPAN_NOTICE("Water slops in the bilge of the [craft.name]: it is ankle deep. An empty bucket used on her planks bails it out."))
			if (HULL_DEPTH_KNEE)
				craft.crew_message(SPAN_WARNING("The bilge of the [craft.name] is knee deep. She is heavy with it and slow to answer."))
			if (HULL_DEPTH_AWASH)
				craft.crew_message(SPAN_DANGER("<b>The [craft.name] is awash!</b> Water washes over her planks and she wallows. Bail her out."))
			if (HULL_DEPTH_LISTING)
				craft.crew_message(SPAN_DANGER("<b>The [craft.name] lists!</b> She is three quarters full and will make slow ahead at best. Patch her holes and bail, or get off her."))
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
	if (!craft || !craft.body || !craft.body.placed() || sinking)
		return
	var/rate = seep_rate()
	if (rate > 0)
		add_water(rate * (under_way() ? 1 : HULL_SEEP_AT_REST) * seconds / 60)
	if (under_way())
		wear_seams(seconds)
	if (patches > 0)
		add_water(patches * HULL_PATCH_PER_MINUTE * seconds / 60)
	if (holes > 0)
		add_water(holes * HULL_HOLE_PER_MINUTE * seconds / 60, capacity())
	// Her powered pumps answer the water (hull_pumps.dm).
	pump_bilge(seconds)
	check_founder()

/datum/hull_ledger/proc/status_text()
	. = "She is a [class_name()]."
	var/now = depth()
	if (now == HULL_DEPTH_DRY)
		. += " Her bilge is dry."
	else
		. += " Her bilge is [hull_depth_name(now)]: [round(water)] bucketful\s of [round(limit())] before she is awash"
		var/weight = water_weight()
		. += weight > 0 ? ", weighing on her like [weight] more tile\s of hull." : "."
	if (holes > 0)
		. += " <b>[holes] hole\s in her hull let[holes == 1 ? "s" : ""] the sea in:</b> use wood on the open water of a hole, hammer in the other hand, to patch it."
	if (patches > 0)
		. += " [patches] patch[patches == 1 ? "" : "es"] weep[patches == 1 ? "s" : ""] a little."
	. += pumps_text()
	if (grounded)
		. += " <b>She sits on the bottom.</b> Patch every hole and bail her below awash to float her."
	else if (sink_left > 0)
		. += " <b>She is going down.</b>"
	if (seep_rate() <= 0)
		. += hull_class() == HULL_CLASS_SMALL ? " A hull this small keeps the sea out by herself." : " Her plating lets nothing through."
	else
		. += " Her seams are [seam_name()] and seep while she works: bail her now and then."
		if (seams > HULL_SEAMS_FAIR + 0.01)
			. += " Tarred oakum used on her planks, with a chisel or hammer in the other hand, caulks her."

// The ledger as plain numbers for a saved field, and back.
/datum/hull_ledger/proc/to_list()
	return list("water" = round(water, 0.01), "holes" = holes, "patches" = patches, "grounded" = grounded ? 1 : 0, "seams" = round(seams, 0.001))

/datum/hull_ledger/proc/from_list(list/state)
	if (!islist(state))
		return
	if (isnum(state["water"]))
		water = clamp(state["water"], 0, capacity())
	// The saved counts stand: her floors may not all be back on the map yet.
	if (isnum(state["holes"]))
		holes = clamp(round(state["holes"]), 0, tiles)
	if (isnum(state["patches"]))
		patches = clamp(round(state["patches"]), 0, tiles)
	grounded = state["grounded"] ? TRUE : FALSE
	if (isnum(state["seams"]))
		seams = clamp(state["seams"], 0, 1)
	seams_told = seams >= HULL_SEAMS_OPEN ? 2 : (seams >= HULL_SEAMS_WORKING ? 1 : 0)
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

// A hull that lists makes slow ahead at best, and one on the bottom none.
/datum/craft/max_speed()
	. = ..()
	if (ledger && ledger.fill() >= HULL_LISTING)
		. = min(., VESSEL_SPEED_SLOW)

/datum/craft/set_speed(new_speed)
	if (ledger && ledger.grounded && new_speed > VESSEL_SPEED_STOP)
		crew_message(SPAN_WARNING("The [name] sits on the bottom and will not move. Patch every hole and bail her below awash."))
		new_speed = VESSEL_SPEED_STOP
	return ..(new_speed)

/datum/craft/order_turn(heading)
	if (ledger && ledger.grounded)
		last_refusal = "she sits on the bottom"
		return FALSE
	return ..()

// ---- Holes and patches ----

// A floor of her hull is gone: the tile under it is a hole, unless another
// floor still lies there.
/datum/hull_ledger/proc/plank_lost(obj/covers/C, turf/T)
	if (sinking || !craft)
		return
	if (istype(C, /obj/covers/repairedfloor/ship/patch))
		patches = max(0, patches - 1)
	if (!hole_at(T, C))
		return
	holes++
	craft.crew_message(SPAN_DANGER("<b>The [craft.name] is holed!</b> The sea comes in where her floor was at [T.x], [T.y]. Use wood on the open water there, with a hammer in your other hand, to patch it."))

/obj/covers/Destroy()
	if (afloat && !wall)
		var/turf/T = get_turf(src)
		var/datum/craft/C = T ? craft_at(T) : null
		if (C && C.ledger)
			C.ledger.plank_lost(src, T)
	return ..()

/obj/covers/repairedfloor/ship/patch
	name = "hull patch"
	desc = "Planks nailed over a hole in a hull. It keeps most of the sea out."
	icon_state = "wood_ship_repaired"
	afloat = TRUE

// Why H cannot patch the hole at T with W, or null.
/proc/hull_patch_refusal(mob/living/human/H, obj/item/stack/material/wood/W, turf/T)
	if (!istype(H) || !istype(W) || !T)
		return "nothing to patch with"
	var/datum/craft/C = craft_at(T)
	if (!C || !C.ledger || !C.ledger.hole_at(T))
		return "there is no hole in a hull here"
	var/turf/at = get_turf(H)
	if (!at || get_dist(at, T) > 1 || !C.body.contains(at) || at == T)
		return "stand on her deck beside the hole"
	if (H.stat || H.lying || H.restrained())
		return "you are in no state to patch her"
	if (!is_tool(H.get_inactive_hand(), TOOL_HAMMER))
		return "you need a hammer in your other hand"
	if (W.amount < HULL_PATCH_PLANKS)
		return "a patch takes [HULL_PATCH_PLANKS] pieces of wood"
	return null

// H nails a patch over the hole at T. Returns the patch.
/proc/hull_patch(mob/living/human/H, obj/item/stack/material/wood/W, turf/T)
	var/why = hull_patch_refusal(H, W, T)
	if (why)
		to_chat(H, SPAN_WARNING("You cannot patch her here: [why]."))
		return null
	var/datum/craft/C = craft_at(T)
	H.visible_message(SPAN_NOTICE("[H] starts nailing a patch over the hole in the [C.name]."), SPAN_NOTICE("You start nailing a patch over the hole."))
	playsound(T, 'sound/items/Screwdriver.ogg', 50, TRUE)
	if (!do_after(H, HULL_PATCH_TIME, T) || QDELETED(W) || H.get_active_hand() != W)
		return null
	if (hull_patch_refusal(H, W, T))
		return null
	return hull_patch_lay(C, W, T)

// Lays the patch and pays for it.
/proc/hull_patch_lay(datum/craft/C, obj/item/stack/material/wood/W, turf/T)
	W.use(HULL_PATCH_PLANKS)
	var/obj/covers/repairedfloor/ship/patch/P = new(T)
	P.updateturf()
	var/datum/hull_ledger/L = C.ledger
	L.holes = max(0, L.holes - 1)
	L.patches++
	C.crew_message(SPAN_NOTICE("A patch is nailed over the hole at [T.x], [T.y]. [L.holes ? "[L.holes] more hole\s let[L.holes == 1 ? "s" : ""] the sea in." : "No hole is left open."]"))
	return P

// Wood used on the open water of a hole patches it.
/turf/floor/beach/water/attackby(obj/item/C as obj, mob/user as mob)
	if (istype(C, /obj/item/stack/material/wood) && ishuman(user))
		var/datum/craft/aboard = craft_at(src)
		if (aboard && aboard.ledger && aboard.ledger.hole_at(src))
			hull_patch(user, C, src)
			return TRUE
	return ..()

// ---- Foundering ----

// TRUE when most of her lies over deep water.
/datum/hull_ledger/proc/over_deep()
	var/deep = 0
	var/list/cells = craft.body.cells()
	for (var/turf/T in cells)
		if (istype(T, /turf/floor/beach/water/deep))
			deep++
	return deep * 2 > cells.len

// Called after every step: a full hull founders, a grounded one may float.
/datum/hull_ledger/proc/check_founder()
	if (sinking || !craft || !craft.body || !craft.body.placed())
		return
	var/full = water >= capacity() - 0.01
	if (grounded)
		if (over_deep())
			// Pushed or carried off the shallows still full of water.
			grounded = FALSE
		else if (!holes && fill() < HULL_AWASH)
			grounded = FALSE
			craft.crew_message(SPAN_NOTICE("<b>The [craft.name] lifts off the bottom.</b> She floats again."))
			return
		else
			return
	if (!full || sink_timer)
		return
	if (over_deep())
		sink_left = HULL_SINK_WARNINGS
		craft.crew_message(SPAN_DANGER("<b>The [craft.name] is foundering!</b> She is full of water and going down. Bail and patch for your lives, or abandon ship."))
		log_game("Built hull [craft.name] is foundering on deep water ([holes] holes).")
		if (!hull_ledger_timer_off)
			sink_timer = addtimer(CALLBACK(src, PROC_REF(sink_tick)), HULL_LEDGER_STEP, TIMER_LOOP | TIMER_STOPPABLE)
		return
	grounded = TRUE
	craft.set_speed(VESSEL_SPEED_STOP)
	craft.crew_message(SPAN_DANGER("<b>The [craft.name] settles on the bottom.</b> She is full of water, but the shallows hold her. Patch every hole and bail her below awash to float her."))
	log_game("Built hull [craft.name] grounded in the shallows ([holes] holes).")

/datum/hull_ledger/proc/stop_sinking()
	sink_left = 0
	if (sink_timer)
		deltimer(sink_timer)
		sink_timer = 0

// One half minute of foundering. TRUE when she went down.
/datum/hull_ledger/proc/sink_tick()
	if (sinking || !craft || !craft.body || !craft.body.placed())
		stop_sinking()
		return FALSE
	if (persistence_save_in_progress)
		return FALSE
	if (water < capacity() * 0.98 || !over_deep())
		stop_sinking()
		craft.crew_message(SPAN_NOTICE("<b>The [craft.name] holds.</b> Her crew is ahead of the water, for now."))
		return FALSE
	sink_left--
	if (sink_left > 0)
		craft.crew_message(SPAN_DANGER("<b>The [craft.name] is going down!</b> About [sink_left * HULL_LEDGER_STEP / 10] seconds are left to get ahead of the water or get off her."))
		return FALSE
	sink()
	return TRUE

// She goes down: the hull and what is built on her are lost, her crew, loose
// things and chests are left in the water where she was.
/datum/hull_ledger/proc/sink()
	var/datum/craft/C = craft
	var/datum/craft_body/built/B = C ? C.body : null
	if (!istype(B) || !B.placed() || sinking)
		return FALSE
	sinking = TRUE
	stop_sinking()
	var/list/cells = B.cells()
	var/list/upper = B.upper_cells(cells)
	var/turf/pivot = locate(B.px, B.py, B.z)
	C.crew_message(SPAN_DANGER("<b>The [C.name] goes down!</b> You are in the water."))
	log_game("Built hull [C.name] ([cells.len] tiles) sank at [pivot.x],[pivot.y],[pivot.z].")
	message_admins("The built hull [html_encode(C.name)] ([cells.len] tiles) sank at [pivot.x],[pivot.y],[pivot.z].")
	// She is a ship no longer: her planks are plain planks, her voyage ends.
	var/obj/structure/hull_tiller/helm = null
	for (var/obj/structure/hull_tiller/T in pivot)
		if (T.craft == C)
			helm = T
	if (helm)
		helm.decommission()
	// What stood on her upper deck comes down to the water.
	for (var/i = 1, i <= upper.len, i++)
		var/turf/U = upper[i]
		if (!U)
			continue
		for (var/atom/movable/M in U)
			if (M.loc != U || QDELETED(M) || istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright))
				continue
			if (hull_floats_free(M))
				M.forceMove(cells[i])
			else if (istype(M, /obj))
				qdel(M)
	for (var/turf/T in cells)
		for (var/atom/movable/M in T)
			if (M.loc != T || QDELETED(M) || !istype(M, /obj) || hull_floats_free(M))
				continue
			if (istype(M, /obj/structure) || istype(M, /obj/covers) || istype(M, /obj/roof) || istype(M, /obj/machinery))
				qdel(M)
	// A few timbers come up.
	for (var/n = 1, n <= clamp(round(cells.len / 10), 1, 5), n++)
		new /obj/item/stack/material/wood(pick(cells))
	return TRUE

// TRUE for what a sinking hull leaves in the water: people, loose things and
// closed chests.
/proc/hull_floats_free(atom/movable/M)
	if (ismob(M))
		var/mob/living/L = M
		if (istype(L) && L.buckled)
			L.buckled.unbuckle_mob()
		return TRUE
	return istype(M, /obj/item) || istype(M, /obj/structure/closet)

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

#undef HULL_HOLE_PER_MINUTE
#undef HULL_PATCH_PER_MINUTE
#undef HULL_PATCH_PLANKS
#undef HULL_PATCH_TIME
#undef HULL_SLACK_WATER
#undef HULL_SEEP_PER_TILE_MINUTE
#undef HULL_SEEP_AT_REST
#undef HULL_SEAM_LIFE
#undef HULL_BAIL_TIME
