// Mechanical power: prime movers that drive the workshop machines beside them.
//
// A treadwheel, horse gin, mill wheel or windmill turns the fastened workshop
// machines within one tile of it, and a driven machine finishes each step of
// its work sooner. There is no network and nothing ticks: a machine asks
// mechanical_drive_factor() when it starts a step, and each mover answers
// from what stands around it at that moment.

#define MECHANICAL_DRIVE_REACH 1
#define MECHANICAL_MIN_TIME 5

/obj/structure/workshop_machine/mover
	name = "prime mover"
	icon = 'icons/obj/mechanical_power.dmi'
	var/drive_factor = 1 // a driven step takes this share of its hand time
	var/base_state = ""

// Why the mover is standing still, or null when it turns.
/obj/structure/workshop_machine/mover/proc/idle_reason()
	return "It has nothing to turn it."

/obj/structure/workshop_machine/mover/proc/turning()
	return anchored && isturf(loc) && !idle_reason()

// The share of hand time a step takes right now; 1 when standing still.
/obj/structure/workshop_machine/mover/proc/current_factor()
	return turning() ? drive_factor : 1

/obj/structure/workshop_machine/mover/update_icon()
	icon_state = turning() ? "[base_state]_on" : base_state

/obj/structure/workshop_machine/mover/examine(mob/user, distance)
	..(user, distance)
	update_icon()
	if (!anchored)
		to_chat(user, SPAN_WARNING("It is not fastened down."))
	else if (turning())
		to_chat(user, SPAN_NOTICE("It is turning. Fastened workshop machines next to it work in [round(current_factor() * 100)]% of the usual time."))
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

// The best drive reaching A: the lowest time share among the turning movers
// next to it, or 1 when nothing drives it.
/proc/mechanical_drive_factor(atom/A)
	. = 1
	var/turf/T = get_turf(A)
	if (!T)
		return
	for (var/obj/structure/workshop_machine/mover/M in range(MECHANICAL_DRIVE_REACH, T))
		if (M == A)
			continue
		var/factor = M.current_factor()
		M.update_icon()
		if (factor < .)
			. = factor

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

/obj/structure/workshop_machine/mover/mill_wheel/idle_reason()
	for (var/turf/T in range(1, src))
		if (river_current_direction(T))
			return null
	return "There is no flowing water beside it. Still water and ice will not turn the wheel."

//////////////////////////////////////////////////////////////////////////////
// Windmill: open sky and a wind.

/obj/structure/workshop_machine/mover/windmill
	name = "windmill"
	desc = "A post mill with four cloth sails. Fastened under open sky, it drives the workshop machines and hoists next to it whenever the wind blows: faster in a stronger wind, and not at all in a calm."
	icon_state = "windmill"
	base_state = "windmill"
	drive_factor = 0.5

/obj/structure/workshop_machine/mover/windmill/proc/wind_speed()
	return map ? clamp(round(map.windspeedvar), 0, 4) : 0

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
