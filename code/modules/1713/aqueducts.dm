// Aqueducts (docs/aqueducts.md). Water runs by gravity along channel pieces
// laid on adjacent tiles, from an intake on fresh water (or a noria lifting it
// out of a river) to the town below.
//
// The water carries a level: the height it stands at, from the terrain heights
// (terrain_height.dm). An intake starts it at its water's height; a noria
// lifts it NORIA_LIFT higher. A channel on the ground can only take water
// that stands as high as the ground it lies on, and the water then sits at
// that ground. Arches and flumes are raised: they keep the water's level
// across lower ground, so a hollow or a valley can be crossed. A qanat runs
// under a hill and keeps the level through higher ground. Water never climbs.
//
// Clay and lead pipes carry it under pressure to taps (lead slowly poisons
// it). What the water reaches, next to a wet piece: a public fountain or a tap
// fills; a public bath fills; a cistern fills; a mill wheel turns on the mill race; a sewer drain is
// flushed clear of silt. A dead body or waste lying in a channel, or an
// intake on fouled water, fouls the water from there on, and every fountain
// below gives foul water. Breaking a piece cuts everything below it.
//
// The network is walked once a minute from each intake, at most
// AQUEDUCT_WALK_LIMIT pieces, so a town's water costs a few hundred steps a
// minute and nothing in between.

#define AQUEDUCT_WALK_LIMIT 800
// Levels a noria lifts river water above the river.
#define NORIA_LIFT 2
// Units of water an intake sends to each fountain and cistern a minute.
#define AQUEDUCT_FEED 200
#define AQUEDUCT_FOUNTAIN_CAPACITY 600
#define AQUEDUCT_FOUL_COLOR "#8a6a3a"

var/global/aqueduct_revision = 0
var/global/list/aqueduct_intakes = list()
var/global/list/aqueduct_wet_pieces = list()
var/global/aqueduct_last_flow = -600

// ---- pieces ---------------------------------------------------------------

/obj/structure/aqueduct
	name = "aqueduct channel"
	icon = 'icons/obj/aqueducts.dmi'
	icon_state = "channel0"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.04
	not_movable = TRUE
	not_disassemblable = FALSE
	var/junction_prefix = "channel"
	// Raised pieces keep the water's level over lower ground.
	var/raised = FALSE
	// Underground pieces keep it through higher ground as well.
	var/underground = FALSE
	// Whether this piece joins to its neighbours (single pieces like a qanat
	// shaft still join; the icon just doesn't show it).
	var/junction_icon = TRUE
	var/tmp/wet = FALSE
	var/tmp/foul = FALSE
	var/tmp/wet_level = 0

/obj/structure/aqueduct/persistence_runtime_var(key)
	return (key in list("wet", "foul", "wet_level")) || ..()

/obj/structure/aqueduct/New()
	..()
	aqueduct_revision++
	if (!restoring)
		aqueduct_update_around(get_turf(src))

// Junctions follow the neighbours, which a load places one by one: join up
// once the level is in.
/obj/structure/aqueduct/after_load()
	..()
	aqueduct_update_around(get_turf(src))

/obj/structure/aqueduct/on_runtime_spawn()
	..()
	aqueduct_update_around(get_turf(src))

/obj/structure/aqueduct/Destroy()
	var/turf/T = get_turf(src)
	aqueduct_revision++
	aqueduct_wet_pieces -= src
	. = ..()
	aqueduct_update_around(T, src)

/obj/structure/aqueduct/proc/aqueduct_update_icon()
	overlays.Cut()
	var/junction = 0
	var/turf/T = get_turf(src)
	if (T)
		for (var/d in cardinal)
			if (aqueduct_piece_at(get_step(T, d)))
				junction |= d
	if (junction_icon)
		icon_state = "[junction_prefix][junction]"
	if (wet && junction_icon)
		var/image/I = image(icon, "water[junction]")
		if (foul)
			I.color = AQUEDUCT_FOUL_COLOR
		overlays += I

/obj/structure/aqueduct/proc/set_wet(state, is_foul, level)
	wet_level = level
	if (wet == state && foul == is_foul)
		return
	wet = state
	foul = is_foul
	aqueduct_update_icon()

// The level of water this piece carries on, given water arriving at `level`,
// or null if the water can't enter it.
/obj/structure/aqueduct/proc/carry_level(level)
	return aqueduct_route_level(get_turf(src), level, raised, underground)

/proc/aqueduct_route_level(turf/T, level, raised, underground)
	var/h = terrain_height_at(T)
	if (underground)
		return level
	if (h > level)
		return null
	return raised ? level : h

// Something lying in the channel that fouls the water from here on.
/obj/structure/aqueduct/proc/fouled_here()
	var/turf/T = get_turf(src)
	if (!T)
		return FALSE
	for (var/mob/living/L in T)
		if (L.stat == DEAD)
			return TRUE
	for (var/obj/item/weapon/reagent_containers/food/snacks/poo/P in T)
		if (!istype(P, /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer))
			return TRUE
	return FALSE

/obj/structure/aqueduct/examine(mob/user, distance = -1)
	. = ..()
	if (get_dist(src, user) > 2)
		return
	if (!wet)
		to_chat(user, SPAN_NOTICE("It is dry. Water only runs downhill to it from an intake or a noria."))
	else if (foul)
		to_chat(user, SPAN_WARNING("The water in it is brown and stinks."))
	else
		to_chat(user, SPAN_NOTICE("Clean water runs along it."))

/obj/structure/aqueduct/channel
	name = "aqueduct channel"
	desc = "A stone-lined channel laid on the ground. Water from an intake runs along it, but only downhill: it can't be laid higher than the water that feeds it."

/obj/structure/aqueduct/flume
	name = "timber flume"
	desc = "A wooden trough on trestle legs. It carries water level across lower ground, so a channel can cross a dip."
	icon_state = "flume0"
	junction_prefix = "flume"
	raised = TRUE
	layer = 4.4

/obj/structure/aqueduct/arch
	name = "aqueduct arches"
	desc = "Stone arches carrying the channel high over the ground. Water keeps its level across a hollow or a valley, and people walk underneath."
	icon_state = "arch0"
	junction_prefix = "arch"
	raised = TRUE
	layer = 4.45

/obj/structure/aqueduct/qanat
	name = "qanat shaft"
	desc = "An access shaft over an underground water channel. A qanat keeps the water's level through a hill, where an open channel would have to climb."
	icon_state = "qanat"
	underground = TRUE
	junction_icon = FALSE

/obj/structure/aqueduct/qanat/aqueduct_update_icon()
	overlays.Cut()
	icon_state = wet ? "qanat_wet" : "qanat"

// Pipes carry the water under pressure: down a valley and up the far side to
// the level it came in at, like a siphon. A lead pipe poisons the water it
// feeds a tap or a fountain next to it now and then.
/obj/structure/aqueduct/pipe
	name = "clay water pipe"
	desc = "A terracotta pipe that carries aqueduct water under pressure: down a dip and up again to the height it came in at, but never higher. Run it to a tap or a bath."
	icon_state = "pipe_clay0"
	junction_prefix = "pipe_clay"
	underground = TRUE
	// Percent chance a minute's water through it picks up lead.
	var/lead_chance = 0

/obj/structure/aqueduct/pipe/lead
	name = "lead water pipe"
	desc = "A soldered lead pipe that carries aqueduct water under pressure to a house. It holds more than clay and never cracks in frost, but water that stands in lead picks up its poison."
	icon_state = "pipe_lead0"
	junction_prefix = "pipe_lead"
	lead_chance = 25

/proc/aqueduct_piece_at(turf/T, obj/structure/aqueduct/except)
	if (!T)
		return null
	for (var/obj/structure/aqueduct/P in T)
		if (P != except && !QDELETED(P))
			return P
	return null

/proc/aqueduct_update_around(turf/T, obj/structure/aqueduct/except)
	if (!T)
		return
	var/obj/structure/aqueduct/P = aqueduct_piece_at(T, except)
	if (P)
		P.aqueduct_update_icon()
	for (var/d in cardinal)
		P = aqueduct_piece_at(get_step(T, d), except)
		if (P)
			P.aqueduct_update_icon()

// ---- intakes --------------------------------------------------------------

/proc/aqueduct_fresh_water(turf/T)
	if (!istype(T, /turf/floor/beach/water))
		return FALSE
	if (istype(T, /turf/floor/beach/water/coastwater) || istype(T, /turf/floor/beach/water/shallowsaltwater) || istype(T, /turf/floor/beach/water/deep/saltwater) || istype(T, /turf/floor/beach/water/ice))
		return FALSE
	return TRUE

// An intake: the head of an aqueduct, set on the bank of fresh water.
/obj/structure/aqueduct_intake
	name = "aqueduct intake"
	desc = "A stone intake head with a grate, set on the bank of a river or a lake. Fresh water runs from it into the channels laid next to it."
	icon = 'icons/obj/aqueducts.dmi'
	icon_state = "intake"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	layer = 2.05
	not_movable = TRUE
	not_disassemblable = FALSE
	var/tmp/flow_seconds = 0
	var/tmp/last_flow_tick = 0
	var/tmp/last_reached = 0

/obj/structure/aqueduct_intake/persistence_runtime_var(key)
	return (key in list("flow_seconds", "last_flow_tick", "last_reached")) || ..()

/obj/structure/aqueduct_intake/New()
	..()
	last_flow_tick = world.time
	aqueduct_intakes |= src
	processing_objects |= src
	aqueduct_revision++
	face_water()

/obj/structure/aqueduct_intake/on_runtime_spawn()
	..()
	aqueduct_intakes |= src
	processing_objects |= src

/obj/structure/aqueduct_intake/Destroy()
	aqueduct_intakes -= src
	processing_objects -= src
	aqueduct_revision++
	return ..()

/obj/structure/aqueduct_intake/proc/face_water()
	var/turf/W = water_turf()
	if (W)
		dir = get_dir(src, W)

// The fresh water this intake draws from, or null.
/obj/structure/aqueduct_intake/proc/water_turf()
	return aqueduct_bank_water(get_turf(src))

/proc/aqueduct_bank_water(turf/T)
	if (!T)
		return null
	for (var/d in cardinal)
		var/turf/W = get_step(T, d)
		if (aqueduct_fresh_water(W))
			return W
	return null

// Why no water comes in, or null.
/obj/structure/aqueduct_intake/proc/idle_reason()
	var/turf/W = water_turf()
	if (!W)
		return "It isn't beside fresh water. Set it on the bank of a river or a lake; seawater is no good."
	if (get_temp(src) <= 0 && istype(W, /turf/floor/beach/water/ice))
		return "The water is frozen."
	if (weather_heat_at(W))
		return "The water has dried up in the heat."
	return null

// Height the water stands at as it leaves the intake.
/obj/structure/aqueduct_intake/proc/head_level()
	return terrain_height_at(water_turf())

/obj/structure/aqueduct_intake/proc/source_fouled()
	var/turf/W = water_turf()
	if (!W)
		return FALSE
	if (istype(W, /turf/floor/beach/water/swamp))
		return TRUE
	return (sewers_apply() && sewer_fouls_near(W)) || river_fouled_at(W)

/obj/structure/aqueduct_intake/process_interval(configured_seconds = 2)
	if (QDELETED(src) || !isturf(loc))
		return PROCESS_KILL
	var/elapsed = min(2, max(0, configured_seconds), max(0, (world.time - last_flow_tick) / 10))
	last_flow_tick = world.time
	flow_seconds += elapsed
	if (flow_seconds < 60)
		return
	flow_seconds = 0
	flow_minute()

// One minute of water down every network, from every intake at once: wet what
// the water reaches, dry what it no longer does, and feed what stands beside it.
/obj/structure/aqueduct_intake/proc/flow_minute()
	if (world.time - aqueduct_last_flow < 550)
		return
	aqueduct_flow_all()

/proc/aqueduct_flow_all()
	aqueduct_last_flow = world.time
	var/list/reached = list()
	for (var/obj/structure/aqueduct_intake/I in aqueduct_intakes)
		if (QDELETED(I) || !isturf(I.loc))
			continue
		var/list/mine = I.idle_reason() ? list() : aqueduct_walk(I)
		I.last_reached = mine.len
		I.flow_icon()
		for (var/obj/structure/aqueduct/P in mine)
			var/list/state = mine[P]
			var/list/known = reached[P]
			if (!known)
				reached[P] = state
			else
				reached[P] = list(max(known[1], state[1]), known[2] || state[2])
	for (var/obj/structure/aqueduct/P in aqueduct_wet_pieces)
		if (!(P in reached))
			P.set_wet(FALSE, FALSE, 0)
	aqueduct_wet_pieces = list()
	var/list/fed = list()
	for (var/obj/structure/aqueduct/P in reached)
		var/list/state = reached[P]
		P.set_wet(TRUE, state[2], state[1])
		aqueduct_wet_pieces += P
		for (var/atom/A in range(1, P))
			if (A in fed)
				continue
			if (aqueduct_feed(A, P))
				fed += A
	return reached

/obj/structure/aqueduct_intake/proc/flow_icon()
	return

/obj/structure/aqueduct_intake/examine(mob/user, distance = -1)
	. = ..()
	if (get_dist(src, user) > 2)
		return
	var/why = idle_reason()
	if (why)
		to_chat(user, SPAN_WARNING(why))
	else
		to_chat(user, SPAN_NOTICE("Water runs in[source_fouled() ? ", brown and foul" : ""]. Last it reached [last_reached] piece\s of channel."))

/obj/structure/aqueduct_intake/noria
	name = "noria"
	desc = "A great timber water wheel with clay pots on its rim. Set on the bank of a flowing river, the current turns it and the pots lift water two levels above the river into the channels next to it."
	icon_state = "noria"
	layer = 4.3

/obj/structure/aqueduct_intake/noria/idle_reason()
	. = ..()
	if (.)
		return
	if (!river_current_direction(water_turf()))
		return "The water beside it doesn't flow. A noria needs a river's current to turn it."
	return null

/obj/structure/aqueduct_intake/noria/head_level()
	return ..() + NORIA_LIFT

/obj/structure/aqueduct_intake/noria/flow_icon()
	icon_state = idle_reason() ? "noria" : "noria_on"

// Walk the network from intake I. Returns piece = list(level, foul) for every
// piece the water reaches.
/proc/aqueduct_walk(obj/structure/aqueduct_intake/I)
	. = list()
	var/turf/start = get_turf(I)
	if (!start)
		return
	var/head = I.head_level()
	var/start_foul = I.source_fouled()
	var/list/queue = list()
	for (var/d in cardinal)
		var/obj/structure/aqueduct/P = aqueduct_piece_at(get_step(start, d))
		if (P)
			queue += P
			queue[P] = list(head, start_foul)
	var/steps = 0
	while (queue.len && steps < AQUEDUCT_WALK_LIMIT)
		var/obj/structure/aqueduct/P = queue[1]
		var/list/arriving = queue[P]
		queue.Cut(1, 2)
		steps++
		var/level = P.carry_level(arriving[1])
		if (isnull(level))
			continue
		var/is_foul = arriving[2] || P.fouled_here()
		var/list/known = .[P]
		if (known && known[1] >= level && (known[2] || !is_foul))
			continue
		.[P] = list(level, is_foul)
		var/turf/T = get_turf(P)
		for (var/d in cardinal)
			var/obj/structure/aqueduct/N = aqueduct_piece_at(get_step(T, d))
			if (N && !(N in queue))
				queue += N
				queue[N] = list(level, is_foul)
		// Water falls through a floor sleeve to the piece under it, with head
		// enough to enter it; it never climbs one.
		var/turf/below = floor_sleeve_link(T, FALSE)
		var/obj/structure/aqueduct/D = aqueduct_piece_at(below)
		if (D && !(D in queue))
			queue += D
			queue[D] = list(max(level, terrain_height_at(below)), is_foul)

// Feed what stands next to a wet piece. Returns TRUE if A took water.
/proc/aqueduct_feed(atom/A, obj/structure/aqueduct/P)
	// A dry canal cut beside the channel floods, if it lies no higher than the water.
	if (istype(A, /turf/floor/trench))
		if (!istype(A, /turf/floor/trench/flooded) && P.wet_level >= terrain_height_at(A))
			var/turf/floor/trench/TR = A
			TR.ChangeTurf(/turf/floor/trench/flooded)
		return TRUE
	if (istype(A, /obj/structure/sink/aqueduct_fountain))
		var/obj/structure/sink/aqueduct_fountain/F = A
		F.fed_minute(P.foul)
		return TRUE
	if (istype(A, /obj/structure/aqueduct_bath))
		var/obj/structure/aqueduct_bath/BA = A
		BA.fed_minute(P.foul)
		return TRUE
	if (istype(A, /obj/structure/reagent_dispensers/cistern))
		var/obj/structure/reagent_dispensers/cistern/C = A
		if (C.reagents && C.reagents.total_volume < C.reagents.maximum_volume)
			C.reagents.add_reagent("water", min(AQUEDUCT_FEED, C.reagents.maximum_volume - C.reagents.total_volume))
		return TRUE
	if (istype(A, /obj/structure/workshop_machine/mover/mill_wheel))
		var/obj/structure/workshop_machine/mover/mill_wheel/M = A
		M.race_fed_until = world.time + 900
		return TRUE
	if (istype(A, /obj/structure/sewer_piece/drain))
		var/obj/structure/sewer_piece/drain/D = A
		if (D.clogged)
			D.set_clogged(FALSE)
		return TRUE
	return FALSE

// ---- mill race --------------------------------------------------------------

/obj/structure/workshop_machine/mover/mill_wheel/var/tmp/race_fed_until = 0

/obj/structure/workshop_machine/mover/mill_wheel/persistence_runtime_var(key)
	return key == "race_fed_until" || ..()

// ---- fountains --------------------------------------------------------------

/obj/structure/sink/aqueduct_fountain
	name = "public fountain"
	desc = "A stone basin with a carved spout. It fills only from an aqueduct channel next to it; draw water with a bucket or drink from it."
	icon = 'icons/obj/aqueducts.dmi'
	icon_state = "fountain"
	density = TRUE
	not_disassemblable = FALSE
	volume = 0
	max_volume = AQUEDUCT_FOUNTAIN_CAPACITY
	var/tmp/last_fed = -1200
	// Lead from the pipes that fed it, in units, given with what's drawn.
	var/lead = 0
	var/full_state = "fountain_full"
	var/dry_state = "fountain"

/obj/structure/sink/aqueduct_fountain/persistence_runtime_var(key)
	return key == "last_fed" || ..()

// Only the aqueduct fills it.
/obj/structure/sink/aqueduct_fountain/refill()
	return

/obj/structure/sink/aqueduct_fountain/proc/fed_minute(is_foul)
	last_fed = world.time
	dirty = is_foul
	if (prob(25))
		for (var/obj/structure/aqueduct/pipe/lead/LP in range(1, src))
			if (LP.wet)
				lead = min(10, lead + 1)
				break
	volume = min(max_volume, volume + AQUEDUCT_FEED)
	update_icon()

/obj/structure/sink/aqueduct_fountain/update_icon()
	var/flowing = world.time - last_fed < 1200
	icon_state = volume > 0 && flowing ? full_state : dry_state
	color = dirty && volume > 0 ? AQUEDUCT_FOUL_COLOR : null

/obj/structure/sink/aqueduct_fountain/has_nearby_fecal_waste()
	return dirty

// Foul water carries its germs into what is drawn from it.
/obj/structure/sink/aqueduct_fountain/attackby(obj/item/O, mob/living/user)
	var/obj/item/weapon/reagent_containers/RG = O
	if (dirty && istype(RG) && RG.is_open_container() && RG.reagents && volume > 0)
		if (RG.reagents.total_volume >= RG.volume)
			to_chat(user, SPAN_WARNING("\The [RG] is full."))
			return TRUE
		if (!do_after(user, 15, src, check_for_repeats = FALSE) || QDELETED(RG))
			return TRUE
		draw_foul(RG)
		user.visible_message(SPAN_NOTICE("[user] fills \the [RG] at \the [src]."), SPAN_NOTICE("You fill \the [RG] at \the [src]. The water is brown."))
		playsound(loc, 'sound/effects/watersplash.ogg', 100, TRUE)
		return TRUE
	var/before = istype(RG) && RG.reagents ? RG.reagents.total_volume : 0
	. = ..()
	if (lead > 0 && istype(RG) && RG.reagents && RG.reagents.total_volume > before)
		give_lead(RG)
	update_icon()

// Water that stood in lead pipes carries a little of it.
/obj/structure/sink/aqueduct_fountain/proc/give_lead(obj/item/weapon/reagent_containers/RG)
	if (lead <= 0 || !RG.reagents)
		return
	RG.reagents.add_reagent("lead", 1)
	RG.note_food_toxin("water from \the [name] fed by lead pipes at ([x],[y],[z])")
	lead--

// Fill RG with foul water, germs and all. Returns the units drawn.
/obj/structure/sink/aqueduct_fountain/proc/draw_foul(obj/item/weapon/reagent_containers/RG)
	var/amount = min(volume, RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)
	if (amount <= 0)
		return 0
	RG.reagents.add_reagent("cholera", amount * 0.05)
	RG.note_food_toxin("unboiled water from a fouled [name] at ([x],[y],[z])")
	RG.reagents.add_reagent("water", amount * 0.95)
	give_lead(RG)
	volume -= amount
	update_icon()
	return amount

/obj/structure/sink/aqueduct_fountain/attack_hand(mob/user)
	if (dirty && ishuman(user) && volume > 0 && Adjacent(user))
		var/mob/living/human/H = user
		if (H.a_intent == I_GRAB)
			. = ..()
			H.catch_dirty_water_illness(30)
			return
	return ..()

/obj/structure/sink/aqueduct_fountain/examine(mob/user, distance = -1)
	. = ..()
	if (get_dist(src, user) > 2)
		return
	if (volume <= 0)
		to_chat(user, SPAN_NOTICE("It is dry. An aqueduct channel running past it fills it."))
	else
		to_chat(user, SPAN_NOTICE("It holds [round(volume)] of [max_volume] units of water[dirty ? ", brown and foul" : ""]."))

// A tap on the end of a pipe: a fountain for one house.
/obj/structure/sink/aqueduct_fountain/tap
	name = "water tap"
	desc = "A bronze standpipe over a stone trough. Fed by a water pipe from an aqueduct, it runs while the aqueduct does."
	icon_state = "tap"
	full_state = "tap_running"
	dry_state = "tap"
	density = FALSE
	max_volume = 300

// ---- public baths -----------------------------------------------------------

/obj/structure/aqueduct_bath
	name = "public bath"
	desc = "A stone-lined pool of a public bathhouse, filled from an aqueduct channel next to it. Undress and bathe to get properly clean; with a fire or a brazier close by the water is warm."
	icon = 'icons/obj/aqueducts.dmi'
	icon_state = "bath"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.06
	not_movable = TRUE
	not_disassemblable = FALSE
	var/full = FALSE
	var/dirty = FALSE
	var/tmp/last_fed = -1200
	var/tmp/busy = FALSE

/obj/structure/aqueduct_bath/persistence_runtime_var(key)
	return key == "last_fed" || key == "busy" || ..()

/obj/structure/aqueduct_bath/proc/fed_minute(is_foul)
	last_fed = world.time
	full = TRUE
	dirty = is_foul
	update_icon()

// Water drains away a few minutes after the aqueduct stops.
/obj/structure/aqueduct_bath/proc/has_water()
	if (full && world.time - last_fed > 3000)
		full = FALSE
		update_icon()
	return full

/obj/structure/aqueduct_bath/update_icon()
	icon_state = full ? "bath_full" : "bath"
	color = full && dirty ? AQUEDUCT_FOUL_COLOR : null

/obj/structure/aqueduct_bath/proc/warm()
	return nearby_heat_source(src)

/obj/structure/aqueduct_bath/attack_hand(mob/living/user)
	if (!ishuman(user) || !Adjacent(user))
		return ..()
	var/mob/living/human/H = user
	if (!has_water())
		to_chat(H, SPAN_WARNING("\The [src] is empty. An aqueduct channel next to it fills it."))
		return
	if (busy)
		to_chat(H, SPAN_WARNING("Someone is already bathing here."))
		return
	H.visible_message(SPAN_NOTICE("[H] climbs into \the [src] to bathe."), SPAN_NOTICE("You climb into \the [src] and start to bathe."))
	busy = TRUE
	var/done = do_after(H, 100, src)
	busy = FALSE
	if (!done || QDELETED(src))
		return
	bathe(H)

// What a full soak does. Returns TRUE if the bather got clean.
/obj/structure/aqueduct_bath/proc/bathe(mob/living/human/H)
	if (!has_water())
		return FALSE
	H.ExtinguishMob()
	H.clean_blood()
	if (dirty)
		H.catch_dirty_water_illness(30)
		to_chat(H, SPAN_WARNING("The water is brown and stinks. You don't feel any cleaner."))
		return FALSE
	var/warm = warm()
	if (warm)
		H.bodytemperature = max(H.bodytemperature, H.species.body_temperature)
	if (H.is_nude())
		H.set_hygiene(HYGIENE_LEVEL_CLEAN)
		H.adjust_mood(warm ? 15 : 8, "a bath")
		to_chat(H, SPAN_NOTICE(warm ? "You soak in the warm water and come out clean and at ease." : "You scrub yourself in the cool water and come out clean."))
		return TRUE
	to_chat(H, SPAN_NOTICE("You splash about, but you don't get clean with your clothes on."))
	return FALSE

/obj/structure/aqueduct_bath/examine(mob/user, distance = -1)
	. = ..()
	if (get_dist(src, user) > 2)
		return
	if (!has_water())
		to_chat(user, SPAN_NOTICE("It is empty. An aqueduct channel next to it fills it."))
	else
		to_chat(user, SPAN_NOTICE("It is full of [dirty ? "foul, brown" : (warm() ? "warm" : "cool")] water."))

#undef AQUEDUCT_FEED
#undef AQUEDUCT_FOUNTAIN_CAPACITY
