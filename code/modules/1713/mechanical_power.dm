// Mechanical power: prime movers that drive the workshop machines beside them.
//
// A treadwheel, horse gin, mill wheel or windmill turns the fastened workshop
// machines within one tile of it, and a driven machine finishes each step of
// its work sooner. Line shafts, gear boxes, clutches and rope drives
// (transmission.dm) carry a mover's drive further. There is no network object
// and nothing ticks: a machine asks mechanical_drive_factor() when it starts a
// step, and the answer is worked out from what stands around it at that
// moment. Each mover has a strength and each driven machine a draw; when the
// machines on a drive draw more than its movers' strength, they all slow.

#define MECHANICAL_DRIVE_REACH 1
#define MECHANICAL_MIN_TIME 5
#define MECHANICAL_DRIVE_SEARCH_LIMIT 64

/obj/structure/workshop_machine/mover
	name = "prime mover"
	icon = 'icons/obj/mechanical_power.dmi'
	drive_draw = 0
	var/drive_factor = 1 // a driven step takes this share of its hand time
	var/drive_capacity = 1 // how many machines' draw it turns at full speed
	var/base_state = ""

// Why the mover is standing still, or null when it turns.
/obj/structure/workshop_machine/mover/proc/idle_reason()
	return "It has nothing to turn it."

/obj/structure/workshop_machine/mover/proc/turning()
	return anchored && isturf(loc) && !idle_reason()

// The share of hand time a step takes right now; 1 when standing still.
/obj/structure/workshop_machine/mover/proc/current_factor()
	return turning() ? drive_factor : 1

// The draw it turns at full speed right now; 0 when standing still.
/obj/structure/workshop_machine/mover/proc/current_capacity()
	return turning() ? drive_capacity : 0

/obj/structure/workshop_machine/mover/update_icon()
	icon_state = turning() ? "[base_state]_on" : base_state

/obj/structure/workshop_machine/mover/examine(mob/user, distance)
	..(user, distance)
	update_icon()
	if (!anchored)
		to_chat(user, SPAN_WARNING("It is not fastened down."))
	else if (turning())
		var/list/load = mechanical_drive_load(src)
		to_chat(user, SPAN_NOTICE("It is turning, with a strength of [load[2]] against a draw of [load[3]]. The fastened machines it drives work in [round(mechanical_load_factor(load) * 100)]% of the usual time."))
		if (load[4])
			to_chat(user, SPAN_WARNING("The line shaft joined to it is too long to turn."))
	else
		to_chat(user, SPAN_WARNING(idle_reason()))

/obj/structure/workshop_machine/mover/attack_hand(mob/living/human/H)
	if (istype(H))
		examine(H, 1)

/obj/structure/workshop_machine/mover/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		update_icon()
		return
	return ..()

// Adds W to the drive search when it is a fastened mover or a transmission
// part that carries drive right now.
/proc/mechanical_drive_join(obj/structure/workshop_machine/W, list/movers, list/parts, list/queue)
	if (QDELETED(W) || !W.anchored || !isturf(W.loc))
		return
	if (istype(W, /obj/structure/workshop_machine/mover))
		if (!(W in movers))
			movers += W
			queue += W
		return
	if (istype(W, /obj/structure/workshop_machine/transmission))
		var/obj/structure/workshop_machine/transmission/P = W
		if (!(P in parts) && P.carries())
			parts += P
			queue += P

// What drives A right now: list(best share of hand time among the turning
// movers, their total strength, the total draw on them, TRUE when a joined
// line shaft is too long to turn). Movers within reach of A count, and so do
// movers joined to A through transmission parts.
/proc/mechanical_drive_load(atom/A)
	. = list(1, 0, 0, FALSE)
	var/turf/T = get_turf(A)
	if (!T)
		return
	var/list/movers = list()
	var/list/parts = list()
	var/list/queue = list()
	if (istype(A, /obj/structure/workshop_machine))
		mechanical_drive_join(A, movers, parts, queue)
	for (var/obj/structure/workshop_machine/W in range(MECHANICAL_DRIVE_REACH, T))
		if (W != A)
			mechanical_drive_join(W, movers, parts, queue)
	var/i = 1
	while (i <= queue.len && queue.len < MECHANICAL_DRIVE_SEARCH_LIMIT)
		var/obj/structure/workshop_machine/N = queue[i++]
		for (var/obj/structure/workshop_machine/W in range(1, N))
			mechanical_drive_join(W, movers, parts, queue)
		if (istype(N, /obj/structure/workshop_machine/transmission))
			var/obj/structure/workshop_machine/transmission/P = N
			for (var/obj/structure/workshop_machine/W in P.linked_parts())
				mechanical_drive_join(W, movers, parts, queue)
	if (parts.len && transmission_run_too_long(parts, queue.len >= MECHANICAL_DRIVE_SEARCH_LIMIT))
		.[4] = TRUE
		// The shaft binds: only the movers right beside A still drive it.
		parts = list()
		var/list/near = list()
		for (var/obj/structure/workshop_machine/mover/M in movers)
			if (M == A || get_dist(M, T) <= MECHANICAL_DRIVE_REACH)
				near += M
		movers = near
	var/best = 1
	var/capacity = 0
	for (var/obj/structure/workshop_machine/mover/M in movers)
		var/factor = M.current_factor()
		M.update_icon()
		if (factor < 1)
			best = min(best, factor)
			capacity += M.current_capacity()
	var/draw = 0
	var/list/counted = list()
	for (var/obj/structure/workshop_machine/N in movers + parts)
		for (var/obj/structure/S in range(MECHANICAL_DRIVE_REACH, N))
			if (S.drive_draw > 0 && S.anchored && !(S in counted))
				counted += S
				draw += S.drive_draw
	// Whatever asked is drawing on the drive too: a pump, a lift or a machine
	// that is not a driven workshop machine.
	if (!(A in counted) && !istype(A, /obj/structure/workshop_machine/mover) && !istype(A, /obj/structure/workshop_machine/transmission))
		var/obj/structure/S = A
		draw += (istype(S) && S.drive_draw > 0) ? S.drive_draw : 1
	.[1] = best
	.[2] = capacity
	.[3] = draw

// The share of hand time a step takes on a drive with this load: the best
// mover's share while strength covers the draw, closing on hand time as the
// draw outgrows it.
/proc/mechanical_load_factor(list/load)
	var/best = load[1]
	if (best >= 1)
		return 1
	var/share = min(1, load[2] / max(1, load[3]))
	return 1 - (1 - best) * share

// The best drive reaching A: the share of hand time a step takes, or 1 when
// nothing drives it.
/proc/mechanical_drive_factor(atom/A)
	return mechanical_load_factor(mechanical_drive_load(A))

// How long a step of base_time takes at this machine right now.
/obj/structure/workshop_machine/proc/driven_time(base_time)
	return max(MECHANICAL_MIN_TIME, round(base_time * mechanical_drive_factor(src)))

//////////////////////////////////////////////////////////////////////////////
// Treadwheel: someone walks inside it.

/obj/structure/workshop_machine/mover/treadwheel
	name = "treadwheel"
	desc = "A great wooden wheel a person walks inside. While someone stands in it and treads, the fastened workshop machines and hoists next to it work in two thirds of the time."
	icon_state = "treadwheel"
	base_state = "treadwheel"
	density = FALSE
	drive_factor = 0.65
	drive_capacity = 1

/obj/structure/workshop_machine/mover/treadwheel/idle_reason()
	for (var/mob/living/human/H in loc)
		if (!H.stat && !H.lying && !H.restrained())
			return null
	return "Nobody is treading it. Someone has to stand inside the wheel."

//////////////////////////////////////////////////////////////////////////////
// Horse gin: a horse or an ox walks round it.

var/global/list/horse_gin_animals = list(
	/mob/living/simple_animal/horse,
	/mob/living/simple_animal/cattle,
)

/obj/structure/workshop_machine/mover/horse_gin
	name = "horse gin"
	desc = "A capstan with a long sweep for a draught animal. While a living horse or head of cattle stands next to it, the fastened workshop machines and hoists next to it work in half the time."
	icon_state = "horse_gin"
	base_state = "horse_gin"
	drive_factor = 0.5
	drive_capacity = 2

/obj/structure/workshop_machine/mover/horse_gin/idle_reason()
	for (var/mob/living/simple_animal/A in range(1, src))
		if (A.stat == DEAD)
			continue
		for (var/kind in horse_gin_animals)
			if (istype(A, kind))
				return null
	return "No horse or ox is at the sweep. Lead one next to the gin."

//////////////////////////////////////////////////////////////////////////////
// Mill wheel: flowing water beside it.

/obj/structure/workshop_machine/mover/mill_wheel
	name = "mill wheel"
	desc = "An undershot water wheel on a timber frame. Fastened on the bank beside flowing water, it drives the workshop machines and hoists next to it in two fifths of the time."
	icon_state = "mill_wheel"
	base_state = "mill_wheel"
	drive_factor = 0.4
	drive_capacity = 3

/obj/structure/workshop_machine/mover/mill_wheel/idle_reason()
	if (race_fed_until > world.time) // a mill race off an aqueduct (aqueducts.dm)
		return null
	for (var/turf/T in range(1, src))
		if (river_current_direction(T))
			return null
	return "There is no flowing water beside it. Still water and ice will not turn the wheel."

// A mill race off an aqueduct gives a full head of water: one more machine.
/obj/structure/workshop_machine/mover/mill_wheel/current_capacity()
	if (!turning())
		return 0
	return race_fed_until > world.time ? drive_capacity + 1 : drive_capacity

//////////////////////////////////////////////////////////////////////////////
// Windmill: open sky and a wind.

/obj/structure/workshop_machine/mover/windmill
	name = "windmill"
	desc = "A post mill with four cloth sails. Fastened under open sky, it drives the workshop machines and hoists next to it whenever the wind blows: faster in a stronger wind, and not at all in a calm."
	icon_state = "windmill"
	base_state = "windmill"
	drive_factor = 0.5

/obj/structure/workshop_machine/mover/windmill/proc/wind_speed()
	return map ? clamp(round(weather_wind_at(src)), 0, 4) : 0

/obj/structure/workshop_machine/mover/windmill/idle_reason()
	var/area/A = get_area(src)
	if (!A || A.location != AREA_OUTSIDE)
		return "It needs open sky to catch the wind."
	if (!wind_speed())
		return "The air is calm and the sails hang still."
	return null

// Light wind 70%, moderate 50%, strong or gale 40% of hand time.
/obj/structure/workshop_machine/mover/windmill/current_factor()
	if (!turning())
		return 1
	switch (wind_speed())
		if (1)
			return 0.7
		if (2)
			return drive_factor
	return 0.4

// Light wind turns one machine, moderate two, strong or gale three.
/obj/structure/workshop_machine/mover/windmill/current_capacity()
	if (!turning())
		return 0
	return min(3, wind_speed())

//////////////////////////////////////////////////////////////////////////////
// Trip hammer: a driven hammer beside an anvil.
//
// It does nothing by hand. Fastened next to an anvil, with a prime mover
// turning next to the hammer, it does the heavy striking: forging at that
// anvil takes half the time. The anvil asks forge_time() when a job starts.

#define TRIP_HAMMER_FACTOR 0.5
#define FORGE_MIN_TIME 10

// Machines that help at an anvil. A "hammer" takes the heavy striking for
// every job; a "fitting" machine (machine_shop.dm) takes one class of work.
// The best hammer and the best fitting machine next to the anvil both count.
/obj/structure/workshop_machine
	var/forge_role = null

// The share of a forging job of this recipe category left to do by hand with
// this machine helping: 1 when it gives no help right now.
/obj/structure/workshop_machine/proc/forge_factor(category)
	return 1

// Called when a job this machine helps with starts.
/obj/structure/workshop_machine/proc/forge_used()
	flick("[initial(icon_state)]_on", src)

/obj/structure/workshop_machine/trip_hammer
	name = "trip hammer"
	desc = "A heavy iron hammer head on a pivoted beam, lifted and dropped by a cam shaft. Fasten it next to an anvil and next to a turning treadwheel, horse gin, mill wheel or windmill: forging at that anvil then takes half the time."
	icon = 'icons/obj/mechanical_power.dmi'
	icon_state = "trip_hammer"
	forge_role = "hammer"
	var/working_text = "The cam shaft is turning. Forging at an anvil next to it takes half the time."
	var/idle_text = "Nothing is turning its cam shaft. It needs a turning prime mover next to it."

// TRUE while a prime mover next to the fastened hammer is turning.
/obj/structure/workshop_machine/trip_hammer/proc/striking()
	return anchored && isturf(loc) && mechanical_drive_factor(src) < 1

/obj/structure/workshop_machine/trip_hammer/forge_factor(category)
	return striking() ? TRIP_HAMMER_FACTOR : 1

/obj/structure/workshop_machine/trip_hammer/examine(mob/user, distance)
	..(user, distance)
	if (!anchored)
		to_chat(user, SPAN_WARNING("It is not fastened down."))
	else if (striking())
		to_chat(user, SPAN_NOTICE(working_text))
	else
		to_chat(user, SPAN_WARNING(idle_text))

/obj/structure/workshop_machine/trip_hammer/attack_hand(mob/living/human/H)
	if (istype(H))
		examine(H, 1)

/obj/structure/workshop_machine/trip_hammer/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	return ..()

// How long a forging job of base_time takes at this anvil right now. category
// is the recipe's anvil category, or null for work that has none.
/obj/structure/anvil/proc/forge_time(base_time, category = null)
	var/list/best = list()
	var/list/share = list()
	for (var/obj/structure/workshop_machine/W in range(1, src))
		if (!W.forge_role)
			continue
		var/left = W.forge_factor(category)
		if (left < 1 && (!best[W.forge_role] || left < share[W.forge_role]))
			best[W.forge_role] = W
			share[W.forge_role] = left
	if (!length(best))
		return base_time
	var/time = base_time
	for (var/role in best)
		var/obj/structure/workshop_machine/W = best[role]
		W.forge_used()
		time *= share[role]
	return max(FORGE_MIN_TIME, round(time))

#undef TRIP_HAMMER_FACTOR
#undef FORGE_MIN_TIME
