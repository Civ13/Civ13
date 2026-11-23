// Lifting: heavy things need a hoist, and the shear legs that hoist them.
//
// A ladder no longer carries an anvil, furnace, kiln, machine, cannon or
// vehicle part along with the climber. Shear legs - two timbers lashed at
// the head with a block and tackle - move one unfastened object between a
// level and the one above or below it, through open air beside the legs.
// Nothing is stored inside the legs and nothing ticks: a haul is one wait.


// Too heavy to drag up or down a ladder.
var/global/list/hoist_only_types = list(
	/obj/structure/anvil,
	/obj/structure/furnace,
	/obj/structure/oven,
	/obj/structure/sawmill,
	/obj/structure/mill,
	/obj/structure/workshop_machine,
	/obj/structure/engine,
	/obj/structure/vehicleparts,
	/obj/structure/cannon,
	/obj/structure/drill,
	/obj/structure/printingpress,
	/obj/structure/factory_fabricator,
	/obj/structure/tanning_drum,
	/obj/structure/research_forge,
	/obj/structure/rocket_section,
)
// Light enough to carry on a ladder although their parent type is listed.
var/global/list/hoist_exempt_types = list(
	/obj/structure/workshop_machine/bellows,
	/obj/structure/workshop_machine/shear_legs,
)

/proc/needs_hoist(atom/movable/A)
	if (!isobj(A))
		return FALSE
	for (var/light in hoist_exempt_types)
		if (istype(A, light))
			return FALSE
	for (var/heavy in hoist_only_types)
		if (istype(A, heavy))
			return TRUE
	return FALSE

// Wheeled loads roll on the flat and cannot be bumped up steps.
var/global/list/wheeled_load_types = list(
	/obj/structure/shopping_cart,
	/obj/structure/bed/chair/wheelchair,
	/obj/structure/closet/crate/cart,
	/obj/structure/vehicle/carriage,
)

/proc/is_wheeled_load(atom/movable/A)
	for (var/wheeled in wheeled_load_types)
		if (istype(A, wheeled))
			return TRUE
	return FALSE

// Why a pulled thing cannot come along between levels, or null when it can.
// Stairs take what a body can drag up steps: people, animals, crates and
// loose items, but not the hoist-only heavy things or wheeled carts. A ladder
// needs both hands on the rungs, so only a person, a small animal or a loose
// item can be hauled up or down one; crates, furniture and big animals cannot.
// A ramp (ramps.dm) carries what stairs do, and with carries at RAMP_WHEELS
// wheeled loads too; at RAMP_HEAVY a hoist-only load goes up with a helper
// beside the hauler.
/proc/level_change_load_problem(atom/movable/A, ladder = FALSE, carries = 0, mob/living/hauler = null)
	if (!A)
		return null
	if (isliving(A))
		var/mob/living/L = A
		if (ladder && L.mob_size > MOB_MEDIUM)
			return "\The [A] is too big to haul up or down a ladder. Lead it round by the stairs."
		return null
	if (!isobj(A))
		return null
	if (needs_hoist(A))
		if (carries >= RAMP_HEAVY)
			if (ramp_haul_helper(hauler, A))
				return null
			return "\The [A] is too heavy to haul up the ramp alone. Someone has to stand beside you or the load and help."
		return "\The [A] is far too heavy to haul [ladder ? "on a ladder" : "up or down stairs"]. Set up shear legs beside the drop and hoist it."
	if (is_wheeled_load(A) && carries < RAMP_WHEELS)
		return "\The [A] runs on wheels and can't be dragged up or down [ladder ? "a ladder" : "steps"]. Wheels need a timber or stone ramp."
	if (ladder && !isitem(A))
		return "You need both hands for the rungs, so you can't drag \the [A] up or down a ladder. Take it by the stairs, or hoist it with shear legs or a lift."
	return null

// Another person who can help haul a heavy load up a gentle ramp: awake,
// free and standing beside the hauler or the load.
/proc/ramp_haul_helper(mob/living/hauler, atom/movable/load)
	if (!hauler || !load || !isturf(hauler.loc))
		return null
	for (var/mob/living/human/H in range(1, hauler) | range(1, load))
		if (H == hauler || H == load || H.stat || H.lying || H.restrained() || H.buckled || H.z != hauler.z)
			continue
		return H
	return null

// TRUE, with the reason told to the climber, when what they pull cannot go
// on a ladder. Every ladder climb in multiz/structures.dm asks this before
// and after the wait.
/proc/ladder_refuses_load(mob/M)
	if (!M || !M.pulling)
		return FALSE
	var/problem = level_change_load_problem(M.pulling, TRUE)
	if (!problem)
		return FALSE
	to_chat(M, SPAN_WARNING("[problem] Let go of it to climb."))
	return TRUE

// Stairs or a ramp, before the climber moves: let go of what cannot come
// along, with the reason, and keep hold of what can.
/proc/stairs_check_load(mob/living/M, turf/destination, obj/covers/route = null)
	if (!M || !M.pulling)
		return
	var/atom/movable/load = M.pulling
	var/problem = isturf(load.loc) ? level_change_load_problem(load, FALSE, route ? route.ramp_carries : 0, M) : "You lose your hold on \the [load]."
	if (!problem && !persistence_movement_allowed(load, destination))
		problem = "\The [load] can't come with you there."
	if (!problem)
		return
	to_chat(M, SPAN_WARNING("[problem] You let go of it."))
	M.stop_pulling()

// Stairs, after the climber has moved: what they still pull lands on their
// tile, so the pull holds and the next step drags it on. Someone sitting in a
// pulled chair comes with it.
/proc/stairs_bring_load(mob/living/M)
	if (!M || !M.pulling || !isturf(M.loc) || QDELETED(M.pulling))
		return
	var/atom/movable/load = M.pulling
	var/mob/living/rider = isobj(load) ? load:buckled_mob : null
	if (!load.forceMove(M.loc))
		M.stop_pulling()
		return
	if (rider && rider.buckled == load && rider.loc != load.loc)
		rider.forceMove(load.loc)

//////////////////////////////////////////////////////////////////////////////
// Shear legs

/obj/structure/workshop_machine/shear_legs
	name = "shear legs"
	desc = "Two timbers lashed at the head, with a block and tackle. Drag an unfastened object next to them onto the legs to raise it to the level above or lower it to the level below, through open air. Click them with an empty hand to haul up something lying below. Anvils, furnaces, kilns, machines, cannon and vehicle parts cannot go on a ladder and need a hoist like this."
	icon = 'icons/obj/lifting_machines.dmi'
	icon_state = "shear_legs"
	var/reach = 2 // tiles from the legs a load can land or be picked up below
	var/haul_time = 60
	var/heavy_time = 100 // a hoist-only load
	var/base_state = "shear_legs"

// Why this cannot be slung, or null when it can.
/obj/structure/workshop_machine/shear_legs/proc/sling_problem(atom/movable/A)
	if (A == src || !isturf(A.loc) || !(istype(A, /obj/item) || istype(A, /obj/structure)))
		return "That cannot be slung from \the [src]."
	if (A.anchored)
		return "\The [A] is fastened down. Unfasten it first."
	if (locate(/mob/living) in A)
		return "Someone is inside \the [A]."
	return null

// How far from the hoist a load on its own level can be slung. A rail crane
// picks up anywhere under its jib (train_crane.dm).
/obj/structure/workshop_machine/shear_legs/proc/sling_reach()
	return 1

/obj/structure/workshop_machine/shear_legs/proc/hauler_ready(mob/living/human/H)
	return !QDELETED(src) && anchored && istype(H) && get_dist(src, H) <= 1 && H.z == z && !H.incapacitated() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required

// The nearest clear, supported turf within reach of the legs on that level.
// With below_open_air the tile over it on the legs' own level must be open
// air, so a load is never lowered through a floor.
/obj/structure/workshop_machine/shear_legs/proc/landing_on(level, below_open_air = FALSE)
	var/turf/centre = level ? locate(x, y, level) : null
	if (!centre)
		return null
	var/turf/best = null
	var/best_dist = 0
	for (var/turf/T in range(reach, centre))
		if (!ledge_landing_clear(T))
			continue
		if (below_open_air && !edge_open_air(locate(T.x, T.y, z)))
			continue
		var/d = get_dist(T, centre)
		if (!best || d < best_dist)
			best = T
			best_dist = d
	return best

// Where a load beside the legs would go: list("Raise ..." = turf, ...).
/obj/structure/workshop_machine/shear_legs/proc/haul_choices(atom/movable/load)
	var/list/choices = list()
	var/up = multiz_level_above(z)
	if (up && edge_open_air(locate(load.x, load.y, up)))
		var/turf/top = landing_on(up)
		if (top)
			choices["Raise it to the level above"] = top
	var/turf/bottom = landing_on(multiz_level_below(z), TRUE)
	if (bottom)
		choices["Lower it to the level below"] = bottom
	return choices

// Unfastened objects on the level below, under open air within reach.
/obj/structure/workshop_machine/shear_legs/proc/loads_below()
	var/list/found = list()
	var/down = multiz_level_below(z)
	var/turf/centre = down ? locate(x, y, down) : null
	if (!centre)
		return found
	for (var/turf/T in range(reach, centre))
		if (!edge_open_air(locate(T.x, T.y, z)))
			continue
		for (var/obj/O in T)
			if (!sling_problem(O))
				found["[O.name] ([length(found) + 1])"] = O
	return found

/obj/structure/workshop_machine/shear_legs/MouseDrop_T(atom/movable/dropping, mob/living/human/user)
	if (!istype(user) || !istype(dropping) || ismob(dropping) || user.incapacitated() || get_dist(src, user) > 1)
		return
	if (busy)
		to_chat(user, SPAN_WARNING("\The [src] are already hauling a load."))
		return
	if (!anchored)
		to_chat(user, SPAN_WARNING("Fasten \the [src] down first."))
		return
	if (get_dist(src, dropping) > sling_reach() || dropping.z != z)
		to_chat(user, SPAN_WARNING(sling_reach() > 1 ? "\The [dropping] is out of \the [src]'s reach. Bring it within [sling_reach()] tiles." : "Bring \the [dropping] right beside \the [src] first."))
		return
	var/problem = sling_problem(dropping)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	var/list/choices = haul_choices(dropping)
	if (!length(choices))
		to_chat(user, SPAN_WARNING("There is nowhere to hoist \the [dropping] to. Raising needs open air above the load and a clear floor within [reach] tiles of \the [src] on the level above; lowering needs open air beside \the [src] with clear ground under it."))
		return
	var/choice = length(choices) == 1 ? choices[1] : player_input(user, "Where should \the [dropping] go?", "Shear legs", null, "anything", choices, TRUE)
	if (!choice || busy || !hauler_ready(user) || sling_problem(dropping) || get_dist(src, dropping) > sling_reach() || dropping.z != z)
		return
	haul(user, dropping, choices[choice])

/obj/structure/workshop_machine/shear_legs/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	if (busy)
		to_chat(H, SPAN_WARNING("\The [src] are already hauling a load."))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down first."))
		return
	var/list/loads = loads_below()
	if (!length(loads))
		to_chat(H, SPAN_NOTICE("Nothing unfastened lies below within reach. To raise or lower something on this level, drag it onto \the [src]."))
		return
	var/turf/landing = landing_on(z)
	if (!landing)
		to_chat(H, SPAN_WARNING("Clear a floor tile within [reach] tiles of \the [src] to land the load on."))
		return
	var/choice = player_input(H, "What should the legs haul up?", "Shear legs", null, "anything", loads, TRUE)
	var/obj/load = choice ? loads[choice] : null
	if (!load || busy || !hauler_ready(H) || QDELETED(load) || sling_problem(load))
		return
	haul(H, load, landing)

/obj/structure/workshop_machine/shear_legs/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	return ..()

// One haul: the load leaves its tile only when the whole wait succeeds.
/obj/structure/workshop_machine/shear_legs/proc/haul(mob/living/human/H, obj/load, turf/destination)
	if (busy || !hauler_ready(H) || !destination || !persistence_movement_allowed(load, destination))
		return FALSE
	var/turf/start = load.loc
	busy = TRUE
	icon_state = "[base_state]_haul"
	visible_message(SPAN_NOTICE("[H] slings \the [load] from \the [src] and starts to haul on the tackle."))
	playsound(src, 'sound/effects/doorcreaky.ogg', 40, TRUE)
	var/done = do_after(H, driven_time(needs_hoist(load) ? heavy_time : haul_time), src)
	busy = FALSE
	if (QDELETED(src))
		return FALSE
	icon_state = base_state
	if (!done || !hauler_ready(H) || QDELETED(load) || load.loc != start || sling_problem(load) || !ledge_landing_clear(destination))
		to_chat(H, SPAN_WARNING("The load settles back where it was."))
		return FALSE
	if (load.pulledby)
		load.pulledby.stop_pulling()
	if (!load.persistence_set_loc(destination))
		to_chat(H, SPAN_WARNING("The load settles back where it was."))
		return FALSE
	playsound(destination, 'sound/effects/drop_wood.ogg', 60, TRUE)
	visible_message(SPAN_NOTICE("[H] hoists \the [load] [destination.z == z ? "up beside \the [src]" : "away on \the [src]"]."))
	load.visible_message(SPAN_NOTICE("\The [load] is set down from a hoist."))
	return TRUE

//////////////////////////////////////////////////////////////////////////////
// Treadwheel crane: the same hoist with a longer jib. Like the shear legs it
// hauls faster with a treadwheel, horse gin, mill wheel or windmill turning
// next to it (mechanical_power.dm).

/obj/structure/workshop_machine/shear_legs/crane
	name = "treadwheel crane"
	desc = "A timber crane with a long jib and a winding drum. It hoists like shear legs, but reaches three tiles: drag an unfastened object next to it onto the crane to raise or lower it one level through open air, or click it with an empty hand to haul up something lying below. A treadwheel or other prime mover turning next to it speeds the haul."
	icon_state = "treadwheel_crane"
	base_state = "treadwheel_crane"
	reach = 3
