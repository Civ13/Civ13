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

// Hull classes, seam wear, fouling and bilge depth: code/__defines/naval.dm
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
#define HULL_PATCH_TIME 60
// Half minutes between foundering on deep water and going down.
#define HULL_SINK_WARNINGS 4


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

// TRUE when T is a hole on the outside of her hull: a floor lifted from her
// edge, which a refit cuts away from her shape (built_hull.dm). A hole with
// her own tiles on every side is in her bottom and must be patched.
/datum/hull_ledger/proc/edge_hole_at(turf/T)
	if (!hole_at(T))
		return FALSE
	for (var/d in cardinal)
		if (!craft.body.contains(get_step(T, d)))
			return TRUE
	return FALSE

// Holes a refit cannot cut away: holes inside her outline and breaches in her
// hold.
/datum/hull_ledger/proc/inner_holes()
	. = hold_breaches()
	if (!craft || !craft.body)
		return
	for (var/turf/T in craft.body.cells())
		if (hole_at(T) && !edge_hole_at(T))
			.++

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
	// Breaches in her hold let the sea in too (hull_breach.dm).
	holes += hold_breaches()
	water = min(water, capacity())
	// Her bulkheads are walked again at the next look (hull_compartments.dm).
	bays_dirty = TRUE

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
	return hull_bilge_capacity(tiles)

/proc/hull_bilge_capacity(tiles)
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
	return crewed || under_way() || depth_disabled

// TRUE when this turf is on one of her decks or in her hold.
/datum/hull_ledger/proc/deck_holds(turf/T)
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!T || !istype(B) || !B.placed())
		return FALSE
	if (T.z == B.z)
		return B.contains(T)
	if (T.z == B.lower_z())
		return B.carries(T)
	if (T.z == B.upper_z() || T.z == B.top_z())
		return B.contains(locate(T.x, T.y, B.z))
	return FALSE

// Takes water in, at turf at when it comes in at one place (a hole, a
// bucket emptied), or along her whole length. Her crew hears of it when the
// bilge is a step deeper.
/datum/hull_ledger/proc/add_water(amount, cap = null, turf/at = null)
	if (amount <= 0)
		return
	if (isnull(cap))
		cap = limit()
	if (bays_split())
		// Parted by bulkheads, each compartment fills on its own (hull_compartments.dm).
		bays_add(amount, cap, at)
	else
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

// Takes water out, from the compartment of turf at when it is pumped or
// bailed there. Returns what came out.
/datum/hull_ledger/proc/remove_water(amount, turf/at = null)
	if (bays_split())
		. = bays_remove(amount, at)
	else
		. = min(water, max(0, amount))
		water -= .
	if (water < 0.01)
		water = 0
	depth_told = min(depth_told, depth())

// One step of seconds.
/datum/hull_ledger/proc/step_ledger(seconds)
	if (!craft || !craft.body || !craft.body.placed() || sinking)
		return
	// Hauled out or in a drained dock she lies dry and nothing changes (berth.dm).
	if (lies_dry())
		water = 0
		return
	// Doors open and shut between steps: walk her compartments again.
	bays_dirty = TRUE
	var/rate = seep_rate()
	if (rate > 0)
		add_water(rate * (under_way() ? 1 : HULL_SEEP_AT_REST) * seconds / 60)
	if (under_way())
		wear_seams(seconds)
	if (patches > 0)
		add_water(patches * HULL_PATCH_PER_MINUTE * seconds / 60)
	if (holes > 0)
		// Each hole floods the compartment it opens into (hull_compartments.dm).
		flood_holes(holes * HULL_HOLE_PER_MINUTE * seconds / 60)
	// What the wind does to her sails (hull_rigging.dm).
	step_rigging(seconds)
	// Open gun ports on a deck awash ship water (hull_ports.dm).
	step_ports(seconds)
	// What her load lets over the side (hull_load.dm).
	step_load(seconds)
	if (step_storm(seconds))
		return
	step_waterlogged_engines()
	// Her powered pumps answer the water (hull_pumps.dm).
	pump_bilge(seconds)
	if (depth_disabled)
		if (pressure_air)
			pressure_scan()
		step_hull_depth()
		return
	check_founder()
	// Unheld and crewed, she drifts (hull_anchors.dm).
	step_drift()
	// Weed and shell grow on her bottom (hull_fouling.dm).
	step_fouling(seconds)
	// Her lookout calls what lies ahead (hull_watch.dm).
	step_watch()

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
	. += bays_text()
	. += " [capitalize(hold_text())]"
	if (!under_way())
		survey_load()
	. += load_text()
	. += fouling_text()
	. += rigging_text()
	. += pumps_text()
	if (depth_disabled)
		. += " She cannot make way until patched and pumped below 40% of bilge capacity."
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
	. = list("water" = round(water, 0.01), "holes" = holes, "patches" = patches, "grounded" = grounded ? 1 : 0, "depth_disabled" = depth_disabled ? 1 : 0, "seams" = round(seams, 0.001), "old_anchor" = old_anchor ? 1 : 0)
	var/list/bays = bays_to_list()
	if (bays)
		.["bays"] = bays
		.["bay_order_heading"] = bay_order_heading
	if (depth_disabled)
		var/list/air = pressure_to_list()
		if (length(air))
			.["pressure_air"] = air

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
	depth_disabled = state["depth_disabled"] ? TRUE : FALSE
	// A record from before anchors were things: she keeps the one she had.
	old_anchor = (isnull(state["old_anchor"]) || state["old_anchor"]) ? TRUE : FALSE
	if (isnum(state["seams"]))
		seams = clamp(state["seams"], 0, 1)
	seams_told = seams >= HULL_SEAMS_OPEN ? 2 : (seams >= HULL_SEAMS_WORKING ? 1 : 0)
	depth_told = depth()
	if (state["bay_order_heading"] in cardinal)
		bay_order_heading = state["bay_order_heading"]
	bays_from_list(state["bays"])
	pressure_from_list(depth_disabled ? state["pressure_air"] : null)

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
	if (islist(state))
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
	if (ledger?.depth_disabled)
		return VESSEL_SPEED_STOP
	if (ledger && ledger.fill() >= HULL_LISTING)
		. = min(., VESSEL_SPEED_SLOW)

/datum/craft/set_speed(new_speed)
	if (ledger && (ledger.grounded || ledger.depth_disabled) && new_speed > VESSEL_SPEED_STOP)
		crew_message(SPAN_WARNING("The [name] cannot make way. Check her bilge and patch her leaks."))
		new_speed = VESSEL_SPEED_STOP
	return ..(new_speed)

/datum/craft/order_turn(heading)
	if (ledger && (ledger.grounded || ledger.depth_disabled))
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
	// A floor of her hold blown out is a breach below the waterline (hull_breach.dm).
	if (hold_origin)
		hull_hold_breach(src)
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
// Water and flooded canal trenches (trench.dm) both ask it: TRUE when it did.
/proc/hull_patch_attack(obj/item/C, mob/user, turf/T)
	if (istype(C, /obj/item/stack/material/wood) && ishuman(user))
		var/datum/craft/aboard = craft_at(T)
		if (aboard && aboard.ledger && aboard.ledger.hole_at(T))
			hull_patch(user, C, T)
			return TRUE
	return FALSE

/turf/floor/beach/water/attackby(obj/item/C as obj, mob/user as mob)
	if (hull_patch_attack(C, user, src))
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
	// Full, or flooded through more than half her compartments (hull_compartments.dm).
	var/full = founders()
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
	if (persistence_save_active() || persistence_active_operation || persistence_load_recovery_required)
		return FALSE
	if (!founders(0.98) || !over_deep())
		stop_sinking()
		craft.crew_message(SPAN_NOTICE("<b>The [craft.name] holds.</b> Her crew is ahead of the water, for now."))
		return FALSE
	sink_left--
	if (sink_left > 0)
		craft.crew_message(SPAN_DANGER("<b>The [craft.name] is going down!</b> About [sink_left * HULL_LEDGER_STEP / 10] seconds are left to get ahead of the water or get off her."))
		return FALSE
	return sink()

// Loss of buoyancy stops travel, not the life of the hull or her crew.
/datum/hull_ledger/proc/sink(storm_lee = 0)
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!istype(B) || !B.placed() || depth_disabled || persistence_save_active() || persistence_active_operation || persistence_load_recovery_required)
		return FALSE
	var/obj/structure/hull_tiller/T = helm()
	if (T && T.crossing_hold_current())
		return FALSE
	depth_disabled = TRUE
	stop_sinking()
	craft.set_speed(VESSEL_SPEED_STOP)
	craft.turning_to = 0
	craft.clear_path()
	if (T)
		T.end_voyage(null)
	if (storm_lee in cardinal)
		// A roll ships water without assuming that it reached the roof of
		// every intact compartment. Already-flooded bays stay flooded.
		var/capsize_water = capacity() * 0.80
		add_water(capsize_water - water, capsize_water)
		craft.crew_message(SPAN_DANGER("The [craft.name] rolls to leeward in the beam seas!"))
		apply_storm_roll(storm_lee)
	craft.crew_message(SPAN_DANGER("The [craft.name] has lost buoyancy! Patch the leaks, pump her out, or abandon ship."))
	log_game("Built hull [craft.name] lost buoyancy at [B.px],[B.py],[B.z].")
	step_hull_depth()
	return TRUE

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
	if (sea_layer_cell(plank))
		return "use a pump to move water out of a submerged hull"
	if (!C.body.contains(get_turf(H)))
		return "stand on her deck to bail her"
	if (H.stat || H.lying || H.restrained())
		return "you are in no state to bail"
	if (W.reagents && W.reagents.total_volume > 0)
		return "empty the bucket first"
	if (C.ledger.water_at(plank) < 1)
		return C.ledger.water < 1 ? "her bilge is dry" : "this compartment is dry"
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
		. += L.remove_water(1, get_turf(P))
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
		if (C && C.ledger && C.ledger.water_at(plank) >= 1 && !(B.reagents && B.reagents.total_volume > 0) && C.body.contains(get_turf(user)))
			hull_bail(user, B, src)
			return TRUE
	return ..()

#undef HULL_HOLE_PER_MINUTE
#undef HULL_PATCH_PER_MINUTE
#undef HULL_PATCH_TIME
#undef HULL_SLACK_WATER
#undef HULL_SEEP_PER_TILE_MINUTE
#undef HULL_SEEP_AT_REST
#undef HULL_SEAM_LIFE
#undef HULL_BAIL_TIME
