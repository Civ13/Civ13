// ============================================================
// Module pods and docking (orbital stations, stage C)
// ------------------------------------------------------------
// A module pod is a habitat module packed into one object. In orbit a module
// kit can be released as a pod in front of the person holding it, and an
// undocked module can be folded back into one. A pod has a 5x5 footprint
// (the module it unfolds into) that it checks itself, and moves one tile at
// a time on its RCS thrusters, burning rocket propellant.
//
// Docking: steer the pod until its centre lines up four tiles from a module
// core (HABITAT_MODULE_SPACING, the pitch docked modules already use), then
// hard dock it with a wrench. It unfolds in place with habitat_unfold(), and
// the shared wall's hatch joins the two modules; opening it equalises their
// air, and cable runs through it as on any module. Folding a module back is
// the undock: every hatch shut, nobody else inside, no cables and no bunk
// someone keeps as home. Its machines, furniture and air go into the pod.
//
// On a station plane only the station's party may steer, dock or fold; a pod
// released by a party answers only to that party. A pod that runs into
// something stops and is damaged itself: pods are not battering rams.
//
// Nothing here stores world.time; a burn in progress is process-local.
// ============================================================

#define ORBIT_POD_RADIUS 2
#define ORBIT_POD_TANK 60
#define ORBIT_POD_KIT_PROPELLANT 20
#define ORBIT_POD_STEP_DELAY 5
#define ORBIT_POD_MAX_BURN 8
#define ORBIT_POD_RAM_DAMAGE 25
#define ORBIT_POD_RELEASE_DISTANCE 3
#define ORBIT_POD_CONSOLE_RANGE 12
#define ORBIT_POD_DOCK_DELAY 50
#define ORBIT_POD_FOLD_DELAY 100

var/global/list/orbit_pods = list()

/obj/structure/orbit_pod
	name = "module pod"
	desc = "A habitat module packed tight, with RCS thrusters at its corners. Steer it until it lines up four tiles from a module, then hard dock it with a wrench."
	icon = 'icons/obj/storage.dmi'
	icon_state = "densecrate"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	flammable = FALSE
	var/kind = "quarters"
	var/core_type = /obj/structure/habitat_core
	// A pod straight from a kit is furnished when it unfolds; a folded one
	// carries its own furniture and machines in its contents.
	var/fresh = TRUE
	var/air_oxygen = 0
	var/air_co2 = 0
	var/air_inert = 0
	var/air_temperature = HABITAT_ROOM_C
	var/propellant = ORBIT_POD_KIT_PROPELLANT
	var/integrity = 100
	var/party = null
	var/tmp/burn_left = 0
	var/tmp/burn_dir = 0

/obj/structure/orbit_pod/New()
	..()
	orbit_pods |= src

/obj/structure/orbit_pod/Destroy()
	orbit_pods -= src
	burn_left = 0
	return ..()

/obj/structure/orbit_pod/ex_act(severity)
	return

/obj/structure/orbit_pod/proc/set_kind(new_kind, new_core_type)
	kind = new_kind
	core_type = new_core_type
	name = "[kind] module pod"

// ---------------------------------------------------------------- footprint

// Null when a pod centred on T has room, otherwise "edge", "pod" or "hull".
/proc/orbit_pod_blocker(turf/T, obj/structure/orbit_pod/self)
	var/r = ORBIT_POD_RADIUS
	if (!T || !orbit_clear_of_seams(T, r))
		return "edge"
	for (var/obj/structure/orbit_pod/P in orbit_pods)
		if (P != self && !QDELETED(P) && P.z == T.z && abs(P.x - T.x) <= r * 2 && abs(P.y - T.y) <= r * 2)
			return "pod"
	// Lined up to dock, the pod's hull ring takes the shared wall.
	var/obj/structure/habitat_core/port = orbit_pod_dock_core_at(T)
	for (var/turf/F in block(locate(T.x - r, T.y - r, T.z), locate(T.x + r, T.y + r, T.z)))
		if (port && (abs(F.x - T.x) == r || abs(F.y - T.y) == r) && istype(F, /turf/wall/habitat_shell) && orbit_other_ring_core(F, null) == port)
			continue
		if (!istype(F, /turf/floor/space/orbit) || F.density)
			return "hull"
		for (var/obj/O in F)
			if (O != self && (O.density || istype(O, /obj/structure/habitat_core)))
				return "hull"
	return null

// The core a pod centred on T lines up with to dock, or null.
/proc/orbit_pod_dock_core_at(turf/T)
	if (!T)
		return null
	for (var/obj/structure/habitat_core/C in habitat_cores)
		if (QDELETED(C) || C.z != T.z)
			continue
		if ((C.x == T.x && abs(C.y - T.y) == HABITAT_MODULE_SPACING) || (C.y == T.y && abs(C.x - T.x) == HABITAT_MODULE_SPACING))
			return C
	return null

/obj/structure/orbit_pod/proc/dock_core()
	return orbit_pod_dock_core_at(get_turf(src))

// ---------------------------------------------------------------- control

// Null when user may steer, dock or fold here, otherwise why not.
/proc/orbit_pod_party_refusal(mob/user, party, z)
	var/station = orbit_station_party(z)
	if (station && !party_train_may_board(user, station))
		return "This plane belongs to [party_train_party_name(station)]."
	if (party && !party_train_may_board(user, party))
		return "This pod answers only to [party_train_party_name(party)]."
	return null

/obj/structure/orbit_pod/proc/burn_refusal(mob/user)
	if (!orbit_world())
		return "\The [src] can only fly in orbit."
	. = orbit_pod_party_refusal(user, party, z)
	if (.)
		return
	if (integrity <= 0)
		return "\The [src]'s thrusters are wrecked. Patch its frame with steel first."
	if (burn_left > 0)
		return "\The [src] is already under way."
	if (propellant < 1)
		return "\The [src] is out of propellant."
	return null

// Starts a burn of up to tiles in direction. Returns null or a reason.
/obj/structure/orbit_pod/proc/burn(direction, tiles, mob/user)
	. = burn_refusal(user)
	if (.)
		return
	if (!(direction in cardinal))
		return "Pick a direction."
	burn_left = clamp(round(tiles), 1, ORBIT_POD_MAX_BURN)
	burn_dir = direction
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(orbit_pod_step), src), ORBIT_POD_STEP_DELAY)
	return null

// One tile of a burn. Each tile costs one unit of propellant.
/proc/orbit_pod_step(obj/structure/orbit_pod/P)
	if (!P || QDELETED(P) || P.burn_left <= 0)
		return
	if (P.move_one(P.burn_dir))
		if (P.burn_left > 0)
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(orbit_pod_step), P), ORBIT_POD_STEP_DELAY)
			return
	P.burn_left = 0
	if (P.dock_core())
		P.visible_message(SPAN_NOTICE("\The [P] comes to rest lined up with a docking port."))

// Moves one tile, or stops (and takes damage when it hit something).
/obj/structure/orbit_pod/proc/move_one(direction)
	var/turf/T = get_step(src, direction)
	var/blocker = orbit_pod_blocker(T, src)
	if (blocker)
		burn_left = 0
		if (blocker == "edge")
			visible_message(SPAN_WARNING("\The [src] stops short of the edge of the plane."))
			return FALSE
		integrity = max(0, integrity - ORBIT_POD_RAM_DAMAGE)
		visible_message(SPAN_DANGER("\The [src] bumps into something and stops, its frame buckling[integrity <= 0 ? " and its thrusters wrecked" : ""]."))
		return FALSE
	propellant = max(0, propellant - 1)
	burn_left--
	loc = T
	if (propellant <= 0)
		burn_left = 0
		visible_message(SPAN_WARNING("\The [src]'s thrusters sputter out of propellant."))
	return TRUE

// ---------------------------------------------------------------- docking

/obj/structure/orbit_pod/proc/dock_refusal(mob/user)
	if (!orbit_world())
		return "\The [src] can only dock in orbit."
	. = orbit_pod_party_refusal(user, party, z)
	if (.)
		return
	if (burn_left > 0)
		return "Wait for \the [src] to stop."
	if (persistence_save_active())
		return "The world is saving. Try again in a moment."
	if (!dock_core())
		return "\The [src] is not lined up with a module. Steer it so its centre sits four tiles straight out from a module's core."
	return habitat_module_refusal(get_turf(src), user)

// Unfolds into a module docked to the core it lines up with. Returns the core.
/obj/structure/orbit_pod/proc/hard_dock(mob/user)
	var/turf/T = get_turf(src)
	loc = null
	var/obj/structure/habitat_core/C = habitat_unfold(T, kind, core_type, user ? user.dir : SOUTH, fresh)
	if (!C)
		loc = T
		return null
	if (!fresh)
		C.ledger = null
		C.air_oxygen = air_oxygen
		C.air_co2 = air_co2
		C.air_inert = air_inert
		C.air_temperature = air_temperature
	orbit_pod_unpack(src, C)
	log_game("Orbit pod: [user ? key_name(user) : "nobody"] docked a [kind] pod at [C.x],[C.y],[C.z].")
	qdel(src)
	return C

// Lays a folded pod's contents out in its new module: furniture and machines
// one to a floor tile around the core, everything else on the core's tile.
/proc/orbit_pod_unpack(obj/structure/orbit_pod/P, obj/structure/habitat_core/C)
	var/list/slots = list()
	for (var/turf/T in C.interior())
		if (T != get_turf(C))
			slots += T
	var/turf/middle = get_turf(C)
	var/i = 0
	for (var/atom/movable/A in P.contents)
		if (istype(A, /obj/structure) && slots.len)
			A.forceMove(slots[(i % slots.len) + 1])
			i++
		else
			A.forceMove(middle)

/obj/structure/orbit_pod/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/wrench))
		var/reason = dock_refusal(user)
		if (reason)
			to_chat(user, SPAN_WARNING(reason))
			return
		to_chat(user, SPAN_NOTICE("You latch the collars and start driving the docking bolts home..."))
		if (!do_after(user, ORBIT_POD_DOCK_DELAY, src))
			return
		reason = dock_refusal(user)
		if (reason)
			to_chat(user, SPAN_WARNING(reason))
			return
		var/obj/structure/habitat_core/C = hard_dock(user)
		if (C)
			user.visible_message(SPAN_NOTICE("[user] hard docks \the [C.kind] module. Open the hatch to equalise."))
		return
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents)
		var/amount = min(ORBIT_POD_TANK - propellant, W.reagents.get_reagent_amount("rocket_propellant"))
		if (amount <= 0)
			to_chat(user, SPAN_WARNING(propellant >= ORBIT_POD_TANK ? "\The [src]'s tank is full." : "\The [src] takes only rocket propellant."))
			return
		W.reagents.remove_reagent("rocket_propellant", amount)
		propellant += amount
		to_chat(user, SPAN_NOTICE("You fill \the [src]'s RCS tank ([round(propellant)]/[ORBIT_POD_TANK])."))
		return
	if (istype(W, /obj/item/stack/material/steel))
		var/obj/item/stack/material/steel/S = W
		if (integrity >= 100)
			to_chat(user, SPAN_NOTICE("\The [src]'s frame is sound."))
			return
		if (!S.use(2))
			to_chat(user, SPAN_WARNING("You need two sheets of steel."))
			return
		integrity = min(100, integrity + 50)
		to_chat(user, SPAN_NOTICE("You brace \the [src]'s frame ([integrity]%)."))
		return
	return ..()

/obj/structure/orbit_pod/attack_hand(mob/living/human/user)
	if (!istype(user) || !user.client)
		return
	orbit_pod_steer(src, user)

/obj/structure/orbit_pod/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("RCS propellant: [round(propellant)]/[ORBIT_POD_TANK]. Frame: [integrity]%."))
	if (party)
		to_chat(user, SPAN_NOTICE("It answers to [party_train_party_name(party)]."))
	if (dock_core())
		to_chat(user, SPAN_NOTICE("It is lined up with a docking port. Hard dock it with a wrench."))

// Asks user for a direction and a number of tiles, then burns.
/proc/orbit_pod_steer(obj/structure/orbit_pod/P, mob/living/human/user)
	var/reason = P.burn_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	var/list/dirs = list("North" = NORTH, "East" = EAST, "South" = SOUTH, "West" = WEST)
	var/choice = WWinput(user, "Fire \the [P]'s thrusters. Each tile costs a unit of propellant ([round(P.propellant)] left).", "RCS", "Cancel", list("North", "East", "South", "West", "Cancel"))
	if (!dirs[choice])
		return
	var/tiles = player_input(user, "How many tiles (1 to [ORBIT_POD_MAX_BURN])?", "RCS", 1, "num", null, TRUE)
	if (!tiles || QDELETED(P))
		return
	reason = P.burn(dirs[choice], tiles, user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	to_chat(user, SPAN_NOTICE("\The [P]'s thrusters fire."))

// ---------------------------------------------------------------- release

// Where a kit held by user is released as a pod: a few tiles in front.
/proc/orbit_pod_release_site(mob/user)
	var/turf/T = get_turf(user)
	for (var/i in 1 to ORBIT_POD_RELEASE_DISTANCE)
		T = T ? get_step(T, user.dir) : null
	return T

// Releases kit as a pod. Returns the pod, or null and tells user why not.
/proc/orbit_pod_release(obj/item/habitat_kit/K, mob/user)
	var/turf/T = orbit_pod_release_site(user)
	var/blocker = orbit_pod_blocker(T, null)
	if (blocker)
		to_chat(user, SPAN_WARNING(blocker == "edge" ? "There is no room before the edge of the plane. Face open space." : "Something is in the way. Face open space with five clear tiles across, a few tiles out."))
		return null
	var/obj/structure/orbit_pod/P = new(T)
	P.set_kind(K.kind, K.core_type)
	P.party = party_train_party_of(user)
	log_game("Orbit pod: [key_name(user)] released a [K.kind] pod at [T.x],[T.y],[T.z].")
	user.visible_message(SPAN_NOTICE("[user] releases \a [P] into open space."))
	qdel(K)
	return P

// In orbit a kit can be unfolded where it is or released as a pod. TRUE when
// the choice was handled here.
/proc/orbit_kit_offer_pod(obj/item/habitat_kit/K, mob/user)
	if (!orbit_world() || !ishuman(user) || !isturf(user.loc))
		return FALSE
	var/choice = WWinput(user, "Unfold \the [K] where you stand, or release it as a pod to steer and dock?", "Module kit", "Cancel", list("Unfold here", "Release as a pod", "Cancel"))
	if (choice == "Unfold here")
		return FALSE
	if (choice == "Release as a pod" && !QDELETED(K) && K.loc == user)
		orbit_pod_release(K, user)
	return TRUE

// ---------------------------------------------------------------- folding

// Null when user may fold this module back into a pod, otherwise why not.
/obj/structure/habitat_core/proc/fold_refusal(mob/user)
	if (!orbit_world())
		return "Modules only fold back into pods in orbit."
	. = orbit_pod_party_refusal(user, null, z)
	if (.)
		return
	if (persistence_save_active())
		return "The world is saving. Try again in a moment."
	for (var/turf/T in ring())
		var/obj/structure/simple_door/habitat_hatch/H = locate() in T
		if (H && !QDELETED(H) && H.is_open())
			return "Shut every hatch first."
		if (locate(/obj/structure/cable) in T)
			return "Take up the cables through the hull first."
	for (var/turf/T in interior())
		for (var/mob/living/M in T)
			if (M != user && M.stat != DEAD)
				return "Everyone else must leave the module first."
		for (var/obj/O in T)
			if (istype(O, /obj/structure/cable))
				return "Take up the cables inside first."
			if (istype(O, /obj/structure/region_gate) || (O != src && istype(O, /obj/structure/habitat_core)))
				return "\The [O] is fixed here and cannot be packed."
			var/obj/structure/bed/B = O
			if (istype(B) && B.persistence_bed_owner_ckey)
				return "Someone keeps a bunk here as their home."
	return null

// Folds this module into a pod on its centre and opens its site to vacuum;
// a docked neighbour keeps the shared wall, sealed. Returns the pod.
/obj/structure/habitat_core/proc/fold(mob/user)
	var/turf/centre = get_turf(src)
	store_air()
	var/obj/structure/orbit_pod/P = new(centre)
	P.set_kind(kind, type)
	P.fresh = FALSE
	P.air_oxygen = air_oxygen
	P.air_co2 = air_co2
	P.air_inert = air_inert
	P.air_temperature = air_temperature
	P.propellant = 0
	P.party = orbit_station_party(z) || (user ? party_train_party_of(user) : null)
	for (var/turf/T in interior())
		for (var/obj/O in T)
			if (O == src || O == P || istype(O, /obj/effect))
				continue
			O.forceMove(P)
	for (var/turf/T in ring())
		var/obj/structure/simple_door/habitat_hatch/H = locate() in T
		var/obj/structure/habitat_core/N = neighbour_through(T)
		if (H)
			qdel(H)
		if (N || orbit_other_ring_core(T, src))
			T.ChangeTurf(/turf/wall/habitat_shell, FALSE, FALSE)
		else
			T.ChangeTurf(/turf/floor/space/orbit, FALSE, FALSE)
	for (var/turf/T in interior())
		T.ChangeTurf(/turf/floor/space/orbit, FALSE, FALSE)
	log_game("Orbit pod: [user ? key_name(user) : "nobody"] folded a [kind] module at [centre.x],[centre.y],[centre.z].")
	qdel(src)
	return P

// Another core whose hull ring T belongs to.
/proc/orbit_other_ring_core(turf/T, obj/structure/habitat_core/self)
	for (var/obj/structure/habitat_core/C in range(HABITAT_MODULE_RADIUS, T))
		if (C != self && !QDELETED(C) && max(abs(C.x - T.x), abs(C.y - T.y)) == HABITAT_MODULE_RADIUS)
			return C
	return null

/obj/structure/habitat_core/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/weapon/wrench) || !orbit_world())
		return ..()
	var/reason = fold_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	var/warn = (user in breathers_list()) ? " You will be left in open space where you stand." : ""
	if (WWinput(user, "Fold this [kind] module back into a pod?[warn]", "Fold module", "Cancel", list("Fold", "Cancel")) != "Fold")
		return
	to_chat(user, SPAN_NOTICE("You start unbolting the module and packing it down..."))
	if (!do_after(user, ORBIT_POD_FOLD_DELAY, src))
		return
	reason = fold_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	var/obj/structure/orbit_pod/P = fold(user)
	user.visible_message(SPAN_NOTICE("[user] folds the module into \a [P]."))

/obj/structure/habitat_core/proc/breathers_list()
	var/list/found = list()
	for (var/turf/T in interior())
		for (var/mob/living/M in T)
			found += M
	return found

// ---------------------------------------------------------------- console

// Pods a console on this plane can steer, by name.
/obj/structure/orbit_console/proc/steerable_pods(mob/user)
	var/list/found = list()
	for (var/obj/structure/orbit_pod/P in orbit_pods)
		if (!QDELETED(P) && P.z == z && get_dist(P, src) <= ORBIT_POD_CONSOLE_RANGE && !P.burn_refusal(user))
			found["[P.name] ([P.x],[P.y])"] = P
	return found
