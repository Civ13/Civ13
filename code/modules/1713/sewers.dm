// Sewers, phase S1 (docs/river-flood.md, "Sewers"). Drain pieces laid on
// adjacent tiles form a network. A plumbed toilet next to the network sends
// its waste along it, to an outfall (a drain piece beside open water) or into
// a cesspit. A plumbed toilet with nowhere to send waste backs up onto the
// floor. Open ditches and outfalls that have carried waste lately, and
// cesspits holding any, foul wells and puddles close by.
//
// The network is walked only when a toilet is used, at most SEWER_WALK_LIMIT
// pieces, so nothing runs while nobody flushes. This only applies on
// persistence maps; elsewhere plumbing still carries waste away by itself.
//
// Phase S2: a drain under rainwater in a hollow is an inlet and drains the
// hollow through its outfall each river tick, up to what the outfall can take
// (a storm can run a sewer full, and flushes then back up). A river in flood
// over an outfall pushes back up the drains into hollows and toilets unless a
// flap gate hangs on the outfall. Drains silt up now and then and must be dug
// clear. Brick sewers (Imperial) carry the most and clog the least.
//
// Phase S3: a pumping station on an outfall (steam, burning fuel, or electric,
// on a cable) lifts water and waste out over a river in flood, so a town in a
// hollow can stay dry behind its gate, and adds to what the outfall takes in
// a storm. A settling tank on an outfall keeps its waste from fouling the
// water downstream until it fills with sludge. A septic tank is a sealed
// cesspit that fouls nothing and slowly digests what it holds.

#define SEWER_WALK_LIMIT 600
// How long waste carried along an open ditch or out of an outfall fouls the
// water near it.
#define SEWER_FOUL_TIME 18000
#define SEWER_DITCH_FOUL_RANGE 2
#define SEWER_OUTFALL_FOUL_RANGE 4
#define CESSPIT_FOUL_RANGE 2
#define CESSPIT_CAPACITY 40
#define CESSPIT_COMPOST_PER 10
// Deciseconds a sewer that ran full keeps refusing waste.
#define SEWER_FULL_TIME 1200
#define SEPTIC_CAPACITY 120
// Real deciseconds a septic tank takes to digest one load, server up or down.
#define SEPTIC_DIGEST_TIME 18000
#define SETTLING_CAPACITY 60

var/global/sewer_revision = 0
// Every drain piece, for the once-a-minute hollow drainage.
var/global/list/sewer_drains = list()
// Set by the last sewer_carry_waste() that met a river pushing back.
var/global/sewer_last_backflow = FALSE
// Every pumping station, ticked once a minute with the hollows.
var/global/list/sewer_pumps = list()

/proc/sewers_apply()
	return map && map.persistence

// A drain or a cesspit: anything waste travels through or into.
/obj/structure/sewer_piece
	icon = 'icons/obj/sewers.dmi'
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.03
	not_movable = TRUE
	not_disassemblable = TRUE
	var/tmp/last_waste = -SEWER_FOUL_TIME

/obj/structure/sewer_piece/persistence_runtime_var(key)
	return key == "last_waste" || ..()

/obj/structure/sewer_piece/on_runtime_spawn()
	..()
	sewer_update_around(get_turf(src))

/obj/structure/sewer_piece/Destroy()
	var/turf/T = get_turf(src)
	. = ..()
	sewer_update_around(T, src)

/obj/structure/sewer_piece/proc/sewer_update_icon()
	return

// TRUE while it has carried waste recently.
/obj/structure/sewer_piece/proc/recently_fouled()
	return world.time - last_waste < SEWER_FOUL_TIME

// Tiles away within which this piece fouls a well, or 0.
/obj/structure/sewer_piece/proc/foul_range()
	return 0

/proc/sewer_piece_at(turf/T, obj/structure/sewer_piece/except)
	if (!T)
		return null
	for (var/obj/structure/sewer_piece/P in T)
		if (P != except && !QDELETED(P))
			return P
	return null

/proc/sewer_update_around(turf/T, obj/structure/sewer_piece/except)
	if (!T)
		return
	var/obj/structure/sewer_piece/P = sewer_piece_at(T, except)
	if (P)
		P.sewer_update_icon()
	for (var/d in cardinal)
		P = sewer_piece_at(get_step(T, d), except)
		if (P)
			P.sewer_update_icon()

// ---- drains ------------------------------------------------------------

/obj/structure/sewer_piece/drain
	name = "drain"
	icon_state = "stone_drain0"
	var/junction_prefix = "stone_drain"
	// Open channels foul water near them while they carry waste.
	var/open_channel = FALSE
	// Tile-levels of hollow water this piece takes in each minute as an inlet;
	// an outfall takes twice this from all its inlets together.
	var/inlet_rate = 2
	// Percent chance a load of waste through this network silts this piece up.
	var/clog_chance = 0.5
	var/clogged = FALSE
	var/tmp/hollow_id = null
	var/tmp/obj/structure/sewer_piece/drain/outfall_cache = null
	var/tmp/outfall_cache_revision = -1
	var/tmp/full_until = 0

/obj/structure/sewer_piece/drain/persistence_runtime_var(key)
	return key == "hollow_id" || key == "outfall_cache" || key == "outfall_cache_revision" || key == "full_until" || ..()

/obj/structure/sewer_piece/drain/New()
	..()
	sewer_drains |= src
	sewer_revision++

/obj/structure/sewer_piece/drain/Destroy()
	sewer_drains -= src
	sewer_revision++
	outfall_cache = null
	return ..()

/obj/structure/sewer_piece/drain/ditch
	name = "drain ditch"
	desc = "An open ditch dug to carry waste and water away. It needs to run to a river, a lake or a cesspit."
	icon_state = "ditch0"
	junction_prefix = "ditch"
	open_channel = TRUE
	inlet_rate = 1
	clog_chance = 2

/obj/structure/sewer_piece/drain/stone
	name = "stone drain"
	desc = "A drain channel covered with stone slabs. Covered drains keep waste away from wells; it needs to run to a river, a lake or a cesspit."
	icon_state = "stone_drain0"
	junction_prefix = "stone_drain"
	not_disassemblable = FALSE

/obj/structure/sewer_piece/drain/brick
	name = "brick sewer"
	desc = "An arched brick sewer, big enough to carry a town's waste and a storm's water. It needs to run to a river, a lake or a cesspit."
	icon_state = "brick_drain0"
	junction_prefix = "brick_drain"
	not_disassemblable = FALSE
	inlet_rate = 5
	clog_chance = 0.1

// The open water this drain spills into, or null.
/obj/structure/sewer_piece/drain/proc/outfall_dir()
	var/turf/T = get_turf(src)
	if (!T)
		return 0
	for (var/d in cardinal)
		if (istype(get_step(T, d), /turf/floor/beach/water))
			return d
	return 0

/obj/structure/sewer_piece/drain/sewer_update_icon()
	var/turf/T = get_turf(src)
	if (!T)
		return
	var/junction = 0
	for (var/d in cardinal)
		if (sewer_piece_at(get_step(T, d)))
			junction |= d
	icon_state = "[junction_prefix][junction]"
	overlays.Cut()
	var/d = outfall_dir()
	if (d)
		overlays += image(icon, "outfall", dir = d)
	if (clogged)
		overlays += image(icon, "clog")

/obj/structure/sewer_piece/drain/proc/set_clogged(state)
	if (clogged == state)
		return
	clogged = state
	sewer_revision++
	sewer_update_icon()

/obj/structure/sewer_piece/drain/proc/flap_gate()
	return locate(/obj/structure/sewer_flap_gate) in get_turf(src)

// A flap gate, or a pumping station's non-return valve, shuts this outfall
// against a river.
/obj/structure/sewer_piece/drain/proc/gated()
	return flap_gate() || (locate(/obj/structure/sewer_pump) in get_turf(src))

// The pumping station working on this outfall now, or null.
/obj/structure/sewer_piece/drain/proc/pump()
	var/obj/structure/sewer_pump/P = locate() in get_turf(src)
	return P && P.working() ? P : null

// The settling tank on this outfall, or null.
/obj/structure/sewer_piece/drain/proc/settling_tank()
	return locate(/obj/structure/sewer_settling_tank) in get_turf(src)

// The level floodwater stands at over this outfall, or null when it is dry.
/obj/structure/sewer_piece/drain/proc/outfall_flood_level()
	var/turf/T = get_turf(src)
	var/depth = flood_depth_at(T)
	return depth > 0 ? terrain_height_at(T) + depth : null

// A river in flood over an ungated outfall pushes back up the sewer.
/obj/structure/sewer_piece/drain/proc/backflowing()
	return !isnull(outfall_flood_level()) && !gated()

// An outfall that takes waste now: not backflowing, not run full in a storm.
/obj/structure/sewer_piece/drain/proc/outfall_open()
	return !clogged && outfall_dir() && !backflowing() && world.time >= full_until

/obj/structure/sewer_piece/drain/attackby(obj/item/I, mob/living/user)
	if (!clogged || !is_tool(I, TOOL_SHOVEL))
		return ..()
	user.visible_message(SPAN_NOTICE("[user] starts digging the silt out of \the [src]."), SPAN_NOTICE("You start digging the silt out of \the [src]."))
	playsound(src, 'sound/effects/shovelling.ogg', 100, TRUE)
	if (!do_after(user, 50, src) || !clogged)
		return
	set_clogged(FALSE)
	to_chat(user, SPAN_NOTICE("You clear \the [src]."))

/obj/structure/sewer_piece/drain/foul_range()
	if (outfall_dir())
		return SEWER_OUTFALL_FOUL_RANGE
	return open_channel ? SEWER_DITCH_FOUL_RANGE : 0

/obj/structure/sewer_piece/drain/examine(mob/user, distance = -1)
	. = ..()
	if (!. || get_dist(src, user) > 2)
		return
	if (clogged)
		to_chat(user, SPAN_WARNING("It is choked with silt. Dig it clear with a shovel."))
	if (outfall_dir())
		to_chat(user, SPAN_NOTICE("It spills into the water here."))
		if (backflowing())
			to_chat(user, SPAN_WARNING("The river has risen over it and is pushing back up the drain. A flap gate would stop that."))
		else if (!isnull(outfall_flood_level()) && !pump())
			to_chat(user, SPAN_NOTICE("The river stands over it and holds the drain shut. A pumping station would lift the water out over it."))
		else if (world.time < full_until)
			to_chat(user, SPAN_WARNING("It is running full."))
	if (recently_fouled() && foul_range())
		to_chat(user, SPAN_WARNING("It stinks of fresh sewage."))

// ---- cesspits -------------------------------------------------------------

/obj/structure/sewer_piece/cesspit
	name = "cesspit"
	desc = "A deep pit lined with planks that collects waste from the drains and privies around it. Dig it out with a shovel when it fills; the night soil makes compost."
	icon_state = "cesspit0"
	var/waste = 0
	var/capacity = CESSPIT_CAPACITY
	var/fill_prefix = "cesspit"

/obj/structure/sewer_piece/cesspit/sewer_update_icon()
	icon_state = "[fill_prefix][waste <= 0 ? 0 : (waste >= capacity ? 3 : (waste * 2 >= capacity ? 2 : 1))]"

/obj/structure/sewer_piece/cesspit/proc/is_full()
	return waste >= capacity

/obj/structure/sewer_piece/cesspit/proc/take_waste()
	if (is_full())
		return FALSE
	waste++
	sewer_update_icon()
	return TRUE

/obj/structure/sewer_piece/cesspit/foul_range()
	return CESSPIT_FOUL_RANGE

/obj/structure/sewer_piece/cesspit/recently_fouled()
	return waste > 0

/obj/structure/sewer_piece/cesspit/examine(mob/user, distance = -1)
	. = ..()
	if (!. || get_dist(src, user) > 2)
		return
	if (waste <= 0)
		to_chat(user, SPAN_NOTICE("It is empty."))
	else if (is_full())
		to_chat(user, SPAN_WARNING("It is full to the brim. Dig it out with a shovel before anything else drains here."))
	else
		to_chat(user, SPAN_NOTICE("It is [round(waste * 100 / capacity)]% full."))

/obj/structure/sewer_piece/cesspit/attackby(obj/item/I, mob/living/user)
	if (!is_tool(I, TOOL_SHOVEL))
		return ..()
	if (waste <= 0)
		to_chat(user, SPAN_NOTICE("\The [src] is empty."))
		return
	user.visible_message(SPAN_NOTICE("[user] starts digging the night soil out of \the [src]."), SPAN_NOTICE("You start digging the night soil out of \the [src]."))
	playsound(src, 'sound/effects/shovelling.ogg', 100, TRUE)
	if (!do_after(user, 100, src) || waste <= 0)
		return
	var/compost = round(waste / CESSPIT_COMPOST_PER)
	for (var/i in 1 to compost)
		new /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer(get_turf(user))
	waste = 0
	sewer_update_icon()
	user.visible_message(SPAN_NOTICE("[user] empties \the [src]."), SPAN_NOTICE("You empty \the [src][compost ? " and pile up the night soil as compost" : ""]."))

// ---- network -----------------------------------------------------------

// The pieces on T and next to it, where waste or water put in at T enters.
/proc/sewer_entry_pieces(turf/T)
	. = list()
	if (!T)
		return
	for (var/obj/structure/sewer_piece/P in T)
		. |= P
	for (var/d in cardinal)
		var/turf/N = get_step(T, d)
		if (N)
			for (var/obj/structure/sewer_piece/P in N)
				. |= P

// Walks the network from the pieces in queue: through drains that are not
// clogged, never on through a cesspit. Calls visit(P) on each piece in order;
// visit returns TRUE to stop. Returns the walked list.
/proc/sewer_walk(list/queue, datum/callback/visit)
	var/list/seen = list()
	for (var/P in queue)
		seen[P] = TRUE
	var/i = 1
	while (i <= queue.len && i <= SEWER_WALK_LIMIT)
		var/obj/structure/sewer_piece/P = queue[i++]
		if (visit.Invoke(P))
			break
		if (!istype(P, /obj/structure/sewer_piece/drain))
			continue
		var/obj/structure/sewer_piece/drain/D = P
		if (D.clogged)
			continue
		var/turf/PT = get_turf(D)
		for (var/d in cardinal)
			var/turf/N = get_step(PT, d)
			if (!N)
				continue
			for (var/obj/structure/sewer_piece/Q in N)
				if (!seen[Q])
					seen[Q] = TRUE
					queue += Q
		// Waste falls through a floor sleeve to the piece under it.
		var/turf/below = floor_sleeve_link(PT, FALSE)
		if (below)
			for (var/obj/structure/sewer_piece/Q in below)
				if (!seen[Q])
					seen[Q] = TRUE
					queue += Q
	return queue

/datum/sewer_carry
	var/obj/structure/sewer_piece/cesspit/pit = null
	var/obj/structure/sewer_piece/drain/outfall = null
	var/backflow = FALSE

/datum/sewer_carry/proc/visit(obj/structure/sewer_piece/P)
	if (istype(P, /obj/structure/sewer_piece/cesspit))
		var/obj/structure/sewer_piece/cesspit/C = P
		if (!pit && !C.is_full())
			pit = C
		return FALSE
	var/obj/structure/sewer_piece/drain/D = P
	if (D.clogged || !D.outfall_dir())
		return FALSE
	if (D.backflowing())
		backflow = TRUE
		return FALSE
	// A flap gate holds the waste in the sewer while the river is up.
	if (world.time >= D.full_until)
		outfall = D
		return TRUE
	return FALSE

// Where waste put in at turf T goes: an outfall drain, a cesspit with room,
// or null. Every open ditch the waste passes, and the outfall, are marked as
// carrying it, and now and then a drain silts up. sewer_last_backflow tells
// whether a river pushing back up an outfall stopped it.
/proc/sewer_carry_waste(turf/T)
	sewer_last_backflow = FALSE
	var/datum/sewer_carry/C = new
	var/list/walked = sewer_walk(sewer_entry_pieces(T), CALLBACK(C, /datum/sewer_carry/proc/visit))
	sewer_last_backflow = C.backflow && !C.outfall && !C.pit
	var/obj/structure/sewer_piece/target = C.outfall || C.pit
	if (!target)
		return null
	if (C.outfall)
		// Waste a pump lifts over a flood, or that runs out over dry ground,
		// fouls the water below unless a settling tank catches it first.
		if (isnull(C.outfall.outfall_flood_level()) || C.outfall.pump())
			var/obj/structure/sewer_settling_tank/S = C.outfall.settling_tank()
			if (!S || !S.take_sludge())
				C.outfall.last_waste = world.time
	else
		C.pit.take_waste()
	var/list/drains = list()
	for (var/obj/structure/sewer_piece/drain/D in walked)
		drains += D
		if (D.open_channel)
			D.last_waste = world.time
	if (drains.len)
		var/obj/structure/sewer_piece/drain/D = pick(drains)
		if (prob(D.clog_chance))
			D.set_clogged(TRUE)
	return target

/datum/sewer_find_outfall
	var/obj/structure/sewer_piece/drain/outfall = null

/datum/sewer_find_outfall/proc/visit(obj/structure/sewer_piece/P)
	var/obj/structure/sewer_piece/drain/D = P
	if (istype(D) && !D.clogged && D.outfall_dir())
		outfall = D
		return TRUE
	return FALSE

// The outfall this drain empties to, cached until the network changes.
/obj/structure/sewer_piece/drain/proc/find_outfall()
	if (outfall_cache_revision == sewer_revision && (!outfall_cache || !QDELETED(outfall_cache)))
		return outfall_cache
	var/datum/sewer_find_outfall/F = new
	sewer_walk(list(src), CALLBACK(F, /datum/sewer_find_outfall/proc/visit))
	outfall_cache = F.outfall
	outfall_cache_revision = sewer_revision
	return outfall_cache

// ---- hollows -------------------------------------------------------------

// Once a minute, after the hollows fill: drains standing in hollow water take
// it to their outfall, or a river in flood pushes up an ungated outfall into
// the hollow. Only drains on hollow tiles do anything.
/datum/river_flood/proc/drain_hollows()
	drain_hollow_water()
	// Pumps burn the minute they just ran.
	for (var/obj/structure/sewer_pump/P in sewer_pumps)
		if (P.z == z_level)
			P.pump_minute()
	// Cellar pumps and windmill pumps (flood_pumps.dm).
	var/cz = cellar_z()
	for (var/obj/structure/cellar_pump/C in cellar_pumps)
		if (C.z == cz)
			C.cellar_minute()
	for (var/obj/structure/water_lift/windmill/W in windmill_pumps)
		if (W.z == z_level)
			W.windmill_minute()

/datum/river_flood/proc/drain_hollow_water()
	if (!sewer_drains.len || !hollow_count)
		return
	var/list/taken = list()
	var/list/changed = list()
	for (var/obj/structure/sewer_piece/drain/D in sewer_drains)
		var/turf/T = D.loc
		if (!isturf(T) || T.z != z_level)
			continue
		if (isnull(D.hollow_id))
			D.hollow_id = hollow_at(T.x, T.y)
		var/h = D.hollow_id
		if (!h || D.clogged)
			continue
		var/obj/structure/sewer_piece/drain/O = D.find_outfall()
		if (!O)
			continue
		var/river = O.outfall_flood_level()
		var/obj/structure/sewer_pump/P = O.pump()
		if (!isnull(river) && !P)
			// The gate shuts against the river: nothing goes either way.
			if (!O.gated() && hollow_level[h] < river)
				hollow_volume[h] = min(hollow_capacity(h), hollow_volume[h] + D.inlet_rate)
				changed |= h
			continue
		if (hollow_volume[h] <= 0 || hollow_depth_at(T) <= 0)
			continue
		// Water runs out by itself over dry ground; over a flood only the pump
		// lifts it.
		var/room = (isnull(river) ? O.inlet_rate * 2 : 0) + (P ? P.pump_rate : 0) - (taken[O] || 0)
		var/want = min(D.inlet_rate, hollow_volume[h])
		if (want > room)
			// A storm runs the sewer full; toilets on it back up for a while.
			O.full_until = world.time + SEWER_FULL_TIME
			want = max(0, room)
		if (want <= 0)
			continue
		taken[O] = (taken[O] || 0) + want
		hollow_volume[h] -= want
		changed |= h
		if (prob(D.clog_chance * 0.2))
			D.set_clogged(TRUE)
	for (var/h in changed)
		hollow_level[h] = hollow_level_for(h, hollow_volume[h])

// ---- flap gates -------------------------------------------------------------

/obj/structure/sewer_flap_gate
	name = "flap gate"
	desc = "A hinged wooden flap hung over the end of a drain. Water and waste push it open on their way out, and a rising river presses it shut instead of running up the drain."
	icon = 'icons/obj/sewers.dmi'
	icon_state = "flap_gate"
	anchored = TRUE
	density = FALSE
	layer = 2.035
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/sewer_flap_gate/New()
	..()
	sewer_revision++

/obj/structure/sewer_flap_gate/on_runtime_spawn()
	..()
	var/obj/structure/sewer_piece/drain/D = locate() in get_turf(src)
	if (D && D.outfall_dir())
		dir = D.outfall_dir()

/obj/structure/sewer_flap_gate/Destroy()
	sewer_revision++
	return ..()

/obj/structure/sewer_flap_gate/examine(mob/user, distance = -1)
	. = ..()
	if (!. || get_dist(src, user) > 2)
		return
	var/obj/structure/sewer_piece/drain/D = locate() in get_turf(src)
	if (!D || !D.outfall_dir())
		to_chat(user, SPAN_WARNING("It hangs on nothing. Put it on the end of a drain where it spills into the water."))
	else if (!isnull(D.outfall_flood_level()))
		to_chat(user, SPAN_NOTICE("The river presses it shut."))

// ---- septic tanks ----------------------------------------------------------

/obj/structure/sewer_piece/cesspit/septic
	name = "septic tank"
	desc = "A sealed concrete tank that takes the drains and privies around it. Nothing seeps out to foul the wells, and what it holds slowly digests away; pump it out with a shovel if it ever fills."
	icon_state = "septic0"
	fill_prefix = "septic"
	capacity = SEPTIC_CAPACITY
	not_disassemblable = FALSE
	// world.realtime digestion has been counted up to.
	var/digested_at = 0

/obj/structure/sewer_piece/cesspit/septic/New()
	..()
	if (!digested_at)
		digested_at = world.realtime

// Counts what digested since it was last looked at: nothing ticks.
/obj/structure/sewer_piece/cesspit/septic/proc/digest()
	if (waste <= 0)
		digested_at = world.realtime
		return
	var/loads = round((world.realtime - digested_at) / SEPTIC_DIGEST_TIME)
	if (loads <= 0)
		return
	waste = max(0, waste - loads)
	digested_at += loads * SEPTIC_DIGEST_TIME
	sewer_update_icon()

/obj/structure/sewer_piece/cesspit/septic/is_full()
	digest()
	return ..()

/obj/structure/sewer_piece/cesspit/septic/examine(mob/user, distance = -1)
	digest()
	return ..()

/obj/structure/sewer_piece/cesspit/septic/foul_range()
	return 0

// ---- settling tanks --------------------------------------------------------

/obj/structure/sewer_settling_tank
	name = "settling tank"
	desc = "A brick basin set on the end of a drain. Waste settles out of the water as sludge before it runs over the weir, so the outfall no longer fouls the water downstream. Dig the sludge out with a shovel when it fills."
	icon = 'icons/obj/sewers.dmi'
	icon_state = "settling0"
	anchored = TRUE
	density = FALSE
	layer = 2.035
	not_movable = TRUE
	not_disassemblable = FALSE
	var/sludge = 0

/obj/structure/sewer_settling_tank/proc/sewer_update_icon()
	icon_state = "settling[sludge <= 0 ? 0 : (sludge >= SETTLING_CAPACITY ? 3 : (sludge * 2 >= SETTLING_CAPACITY ? 2 : 1))]"

// Catches one load of waste: FALSE when it is full and the waste runs through.
/obj/structure/sewer_settling_tank/proc/take_sludge()
	if (sludge >= SETTLING_CAPACITY)
		return FALSE
	sludge++
	sewer_update_icon()
	return TRUE

/obj/structure/sewer_settling_tank/examine(mob/user, distance = -1)
	. = ..()
	if (!. || get_dist(src, user) > 2)
		return
	var/obj/structure/sewer_piece/drain/D = locate() in get_turf(src)
	if (!D || !D.outfall_dir())
		to_chat(user, SPAN_WARNING("It catches nothing here. Set it on the end of a drain where it spills into the water."))
	if (sludge >= SETTLING_CAPACITY)
		to_chat(user, SPAN_WARNING("It is full of sludge, and the waste runs straight over the weir. Dig it out with a shovel."))
	else
		to_chat(user, SPAN_NOTICE("It is [round(sludge * 100 / SETTLING_CAPACITY)]% full of sludge."))

/obj/structure/sewer_settling_tank/attackby(obj/item/I, mob/living/user)
	if (!is_tool(I, TOOL_SHOVEL))
		return ..()
	if (sludge <= 0)
		to_chat(user, SPAN_NOTICE("\The [src] holds no sludge."))
		return
	user.visible_message(SPAN_NOTICE("[user] starts digging the sludge out of \the [src]."), SPAN_NOTICE("You start digging the sludge out of \the [src]."))
	playsound(src, 'sound/effects/shovelling.ogg', 100, TRUE)
	if (!do_after(user, 100, src) || sludge <= 0)
		return
	var/compost = round(sludge / CESSPIT_COMPOST_PER)
	for (var/i in 1 to compost)
		new /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer(get_turf(user))
	sludge = 0
	sewer_update_icon()
	user.visible_message(SPAN_NOTICE("[user] empties \the [src]."), SPAN_NOTICE("You empty \the [src][compost ? " and pile up the sludge as compost" : ""]."))

// ---- pumping stations ------------------------------------------------------

// Fuel a steam pump burns, in minutes of pumping per unit.
var/global/list/sewer_pump_fuel_rates = list(
	"coal" = 30, "charcoal" = 20, "wood" = 10, "plank" = 10, "bamboo" = 10)

/obj/structure/sewer_pump
	name = "pumping station"
	icon = 'icons/obj/sewers.dmi'
	anchored = TRUE
	density = TRUE
	layer = 2.04
	not_movable = TRUE
	not_disassemblable = FALSE
	var/on = FALSE
	// Tile-levels of water a minute it lifts out of the sewer, over a flood or
	// on top of what the outfall takes by itself.
	var/pump_rate = 6
	var/state_prefix = "pump_steam"

/obj/structure/sewer_pump/New()
	..()
	sewer_pumps |= src
	update_icon()

/obj/structure/sewer_pump/Destroy()
	sewer_pumps -= src
	return ..()

// The outfall drain this station stands on, or null.
/obj/structure/sewer_pump/proc/pump_drain()
	var/obj/structure/sewer_piece/drain/D = locate() in get_turf(src)
	return D && D.outfall_dir() ? D : null

// Whatever drives it: fuel or power. Electric pumps draw it here.
/obj/structure/sewer_pump/proc/driven()
	return FALSE

// Called when it is switched off.
/obj/structure/sewer_pump/proc/stopped()
	return

// Lifting water now.
/obj/structure/sewer_pump/proc/working()
	return on && pump_drain() && driven()

/obj/structure/sewer_pump/update_icon()
	icon_state = "[state_prefix][on && driven() ? "_on" : ""]"

// Once a minute with the hollows.
/obj/structure/sewer_pump/proc/pump_minute()
	update_icon()

/obj/structure/sewer_pump/proc/why_not_running()
	if (!pump_drain())
		return "It stands on no outfall. Build it on the end of a drain where it spills into the water."
	return null

/obj/structure/sewer_pump/attack_hand(mob/living/user)
	if (!istype(user))
		return ..()
	if (on)
		on = FALSE
		stopped()
		update_icon()
		user.visible_message(SPAN_NOTICE("[user] stops \the [src]."), SPAN_NOTICE("You stop \the [src]."))
		return
	var/problem = why_not_running()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	on = TRUE
	update_icon()
	user.visible_message(SPAN_NOTICE("[user] starts \the [src]."), SPAN_NOTICE("You start \the [src]. It lifts the drain's water out over the river, even in a flood."))

/obj/structure/sewer_pump/examine(mob/user, distance = -1)
	. = ..()
	if (!. || get_dist(src, user) > 2)
		return
	var/problem = why_not_running()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
	else
		to_chat(user, SPAN_NOTICE("It is [working() ? "running" : "stopped"]. Its valve shuts the drain against a rising river either way."))

/obj/structure/sewer_pump/steam
	name = "steam pumping engine"
	desc = "A coal-fired beam engine that lifts a drain's water and waste out over a river, flood or not. Its valve shuts the drain against the river while it stands idle. Feed it coal, charcoal or wood."
	icon_state = "pump_steam"
	state_prefix = "pump_steam"
	pump_rate = 6
	var/fuel = 0
	var/max_fuel = 240

/obj/structure/sewer_pump/steam/driven()
	return fuel > 0

/obj/structure/sewer_pump/steam/why_not_running()
	. = ..()
	if (!. && fuel <= 0)
		return "Its firebox is empty. Feed it coal, charcoal or wood."

/obj/structure/sewer_pump/steam/pump_minute()
	if (on)
		fuel = max(0, fuel - 1)
		if (fuel <= 0)
			on = FALSE
			visible_message(SPAN_WARNING("\The [src]'s fire burns out and it wheezes to a stop."))
	..()

/obj/structure/sewer_pump/steam/attackby(obj/item/I, mob/living/user)
	var/per = solid_fuel_unit_value(I, sewer_pump_fuel_rates)
	if (!per || !istype(I, /obj/item/stack))
		return ..()
	var/obj/item/stack/S = I
	var/take = min(S.amount, round((max_fuel - fuel) / per))
	if (take <= 0)
		to_chat(user, SPAN_WARNING("\The [src]'s firebox is full."))
		return
	S.use(take)
	fuel += take * per
	update_icon()
	to_chat(user, SPAN_NOTICE("You stoke \the [src]. It has fuel for [fuel] minute\s of pumping."))

/obj/structure/sewer_pump/steam/examine(mob/user, distance = -1)
	. = ..()
	if (. && get_dist(src, user) <= 2)
		to_chat(user, SPAN_NOTICE("It has fuel for [fuel] minute\s of pumping."))

/obj/structure/sewer_pump/electric
	name = "electric sewage pump"
	desc = "A motor-driven pump that lifts a drain's water and waste out over a river, flood or not, and lifts more than a steam engine. Its valve shuts the drain against the river while it stands idle. Lay a powered cable under it or run it from an outlet."
	icon_state = "pump_electric"
	state_prefix = "pump_electric"
	pump_rate = 10
	powerneeded = 20

/obj/structure/sewer_pump/electric/driven()
	return draw_cable_power()

// Gives back its share of the grid while it stands idle.
/obj/structure/sewer_pump/electric/stopped()
	var/need = powerneeded
	powerneeded = 0
	draw_cable_power()
	powerneeded = need

/obj/structure/sewer_pump/electric/why_not_running()
	. = ..()
	if (!. && !draw_cable_power())
		return "It has no power. Lay a powered cable under it or run it from an outlet, with [powerneeded] power to spare."

// TRUE when sewage close to A fouls its water.
/proc/sewer_fouls_near(atom/A)
	for (var/obj/structure/sewer_piece/P in range(max(SEWER_OUTFALL_FOUL_RANGE, SEWER_DITCH_FOUL_RANGE, CESSPIT_FOUL_RANGE), A))
		var/r = P.foul_range()
		if (r && get_dist(P, A) <= r && P.recently_fouled() && P.fouls_toward(A))
			return TRUE
	return FALSE

// ---- fixtures ------------------------------------------------------------

// Whether this plumbed fixture's waste is carried away from where it stands.
/obj/structure/toilet/proc/drains_away()
	if (!is_plumbed())
		return FALSE
	if (!sewers_apply())
		return TRUE
	var/turf/T = get_turf(src)
	if (sewer_piece_at(T))
		return TRUE
	for (var/d in cardinal)
		if (sewer_piece_at(get_step(T, d)))
			return TRUE
	return FALSE

// Send waste V down a plumbed fixture. Returns TRUE when it went; otherwise
// the fixture backs up and V is left on the floor.
/obj/structure/toilet/proc/flush_waste(obj/item/V)
	if (!sewers_apply() || sewer_carry_waste(get_turf(src)))
		qdel(V)
		return TRUE
	V.forceMove(get_turf(src))
	if (sewer_last_backflow)
		visible_message(SPAN_WARNING("Floodwater surges back up \the [src]: the river has risen over its drain."))
	else
		visible_message(SPAN_WARNING("\The [src] gurgles and backs up: its waste has nowhere to drain."))
	return FALSE

/obj/structure/toilet/examine(mob/user, distance = -1)
	. = ..()
	if (. && is_plumbed() && sewers_apply() && get_dist(src, user) <= 2 && !drains_away())
		to_chat(user, SPAN_WARNING("No drain runs from it. Lay a drain from it to a river, a lake or a cesspit."))

// ---- digging ---------------------------------------------------------------

/obj/item/weapon/material/shovel/proc/shovel_dig_sewer(mob/user, turf/floor/TB, cesspit)
	if (!istype(TB) || istype(TB, /turf/floor/wood) || istype(TB, /turf/floor/wood_broken) || istype(TB, /turf/floor/ship) || istype(TB, /turf/floor/carpet) || istype(TB, /turf/floor/broken_floor) || istype(TB, /turf/floor/plating/cobblestone) || istype(TB, /turf/floor/plating/concrete) || istype(TB, /turf/floor/plating/stone_old))
		to_chat(user, SPAN_WARNING("You can't dig that here."))
		return
	if (locate(/obj/structure/multiz) in TB)
		to_chat(user, SPAN_NOTICE("There is a tunnel entrance here!"))
		return
	if (sewer_piece_at(TB))
		to_chat(user, SPAN_WARNING("There is already a drain or a cesspit here."))
		return
	var/what = cesspit ? "a cesspit" : "a drain ditch"
	user.visible_message(SPAN_NOTICE("[user] starts digging [what]."), SPAN_NOTICE("You start digging [what]."), SPAN_NOTICE("You hear the ground being dug nearby."))
	playsound(src, 'sound/effects/shovelling.ogg', 100, TRUE)
	if (!do_after(user, work_delay(user, cesspit ? 150 : 40, WORK_DIG, src), src) || sewer_piece_at(TB))
		return
	if (cesspit)
		new /obj/structure/sewer_piece/cesspit(TB)
	else
		new /obj/structure/sewer_piece/drain/ditch(TB)
	to_chat(user, SPAN_NOTICE("You finish digging [what]."))

#undef SEWER_WALK_LIMIT
#undef SEWER_FOUL_TIME
#undef SEWER_DITCH_FOUL_RANGE
#undef SEWER_OUTFALL_FOUL_RANGE
#undef CESSPIT_FOUL_RANGE
#undef CESSPIT_CAPACITY
#undef CESSPIT_COMPOST_PER
#undef SEWER_FULL_TIME
#undef SEPTIC_CAPACITY
#undef SEPTIC_DIGEST_TIME
#undef SETTLING_CAPACITY
