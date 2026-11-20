// Siege engines and castle defences (docs/siege-engines.md).
//
// - A battering ram is pushed up to a gate, door or wall; its crew swing it
//   together, and every crew member beside it adds to the blow.
// - A ballista looses a heavy bolt straight down the line it faces.
// - A siege tower is pushed against a wall; once its drop bridge is lowered,
//   attackers cross over the wall from it.
// - A trebuchet is a bigger, slower catapult (catapult.dm) for walls far off.
// - A portcullis and a drawbridge are worked from a winch beside them; a
//   murder hole over a gateway lets defenders pour and drop through it
//   (castle_pour.dm).

#define RAM_BLOW 60
#define RAM_MAX_CREW 4
#define RAM_SWING_TIME 30
#define BALLISTA_RANGE 24
#define TOWER_CROSS_TIME 20
#define TOWER_BRIDGE_TIME 30

// ---- shared ----------------------------------------------------------------

// The wall, gate or door standing on T that siege engines work against.
/proc/siege_wall_at(turf/T)
	if (!T)
		return null
	for (var/atom/A in T)
		if (QDELETED(A))
			continue
		if (istype(A, /obj/structure/gate) || istype(A, /obj/structure/simple_door) || istype(A, /obj/structure/barricade) || istype(A, /obj/structure/castle_gate))
			return A
		if (istype(A, /obj/covers))
			var/obj/covers/C = A
			if (C.wall)
				return C
	if (istype(T, /turf/wall))
		return T
	return null

// Damage a wall, gate or door. Returns TRUE if it is gone. Siege numbers are
// tuned against each part's health, so they pass through unscaled by material
// (structure_impact.dm).
/proc/siege_hit(atom/A, damage)
	if (!A || QDELETED(A))
		return TRUE
	if (!is_structure_impact_part(A))
		return FALSE
	A.structure_impact(damage, IMPACT_RAW)
	if (isturf(A))
		return !istype(A, /turf/wall)
	return QDELETED(A)

/proc/siege_can_fight()
	return !map || map.faction1_can_cross_blocks() || map.faction2_can_cross_blocks()

/obj/structure/siege_engine
	icon = 'icons/obj/siege_engines.dmi'
	density = TRUE
	anchored = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	layer = MOB_LAYER + 0.1

/obj/structure/siege_engine/verb/rotate_left()
	set category = null
	set name = "Rotate Left"
	set src in range(1)
	if (anchored)
		to_chat(usr, SPAN_NOTICE("Unfasten it first."))
		return
	set_dir(turn(dir, 90))
	siege_rotated()

/obj/structure/siege_engine/verb/rotate_right()
	set category = null
	set name = "Rotate Right"
	set src in range(1)
	if (anchored)
		to_chat(usr, SPAN_NOTICE("Unfasten it first."))
		return
	set_dir(turn(dir, -90))
	siege_rotated()

/obj/structure/siege_engine/proc/siege_rotated()
	return

// ---- battering ram ---------------------------------------------------------------

/obj/structure/siege_engine/ram
	name = "battering ram"
	desc = "An iron-capped log slung under a hide roof on four wheels. Push it up to a gate, door or wall, face it at it, and swing it: everyone standing beside it adds to the blow."
	icon_state = "ram"
	var/tmp/swinging = FALSE

// Able hands beside the ram, up to RAM_MAX_CREW.
/obj/structure/siege_engine/ram/proc/crew()
	. = 0
	for (var/mob/living/human/H in range(1, src))
		if (H.stat || H.lying || H.restrained())
			continue
		.++
		if (. >= RAM_MAX_CREW)
			return

/obj/structure/siege_engine/ram/proc/target()
	return siege_wall_at(get_step(src, dir))

/obj/structure/siege_engine/ram/attack_hand(mob/living/user)
	if (!ishuman(user) || !Adjacent(user))
		return ..()
	var/atom/T = target()
	if (!T)
		to_chat(user, SPAN_WARNING("There is no gate, door or wall in front of \the [src]. Push it up to one and face it there."))
		return
	if (!siege_can_fight())
		to_chat(user, SPAN_WARNING("You can't attack yet."))
		return
	if (swinging)
		return
	swinging = TRUE
	user.visible_message(SPAN_WARNING("[user] hauls back \the [src]..."), SPAN_NOTICE("You haul back \the [src]."))
	var/ok = do_after(user, RAM_SWING_TIME, src)
	swinging = FALSE
	if (!ok || QDELETED(src) || target() != T)
		return
	swing(T)

// One blow against T. Returns the damage done.
/obj/structure/siege_engine/ram/proc/swing(atom/T)
	var/n = max(1, crew())
	var/damage = RAM_BLOW * n
	flick("ram_swing", src)
	playsound(get_turf(src), 'sound/weapons/smash.ogg', 100, TRUE)
	visible_message(SPAN_DANGER("\The [src] slams into \the [T][n > 1 ? " with [n] at the ropes" : ""]!"))
	for (var/mob/M in range(7, src))
		if (M.client)
			shake_camera(M, 2, 1)
	siege_hit(T, damage)
	return damage

// ---- ballista -------------------------------------------------------------------

/obj/item/ballista_bolt
	name = "ballista bolt"
	desc = "A long iron-headed wooden bolt for a ballista."
	icon = 'icons/obj/siege_engines.dmi'
	icon_state = "ballista_bolt"
	w_class = ITEM_SIZE_LARGE
	force = 8

/obj/item/projectile/arrow/ballista_bolt
	name = "ballista bolt"
	icon = 'icons/obj/siege_engines.dmi'
	icon_state = "bolt_flight"
	damage = 90
	penetrating = 2
	armor_penetration = 30
	embed = FALSE

/obj/structure/siege_engine/ballista
	name = "ballista"
	desc = "A great torsion crossbow on a timber stand. Fasten it with a hammer, load a bolt and loose it straight down the line it faces; a bolt goes through more than one man."
	icon_state = "ballista"
	var/obj/item/ballista_bolt/loaded = null
	var/tmp/winding = FALSE

/obj/structure/siege_engine/ballista/update_icon()
	icon_state = loaded ? "ballista_loaded" : "ballista"

/obj/structure/siege_engine/ballista/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/ballista_bolt))
		if (loaded)
			to_chat(user, SPAN_WARNING("\The [src] is already loaded."))
			return
		user.remove_from_mob(W)
		W.forceMove(src)
		loaded = W
		update_icon()
		to_chat(user, SPAN_NOTICE("You set \the [W] in \the [src]."))
		return
	if (is_tool(W, TOOL_HAMMER))
		toggle_anchor(user)
		return
	return ..()

// The tile a bolt is aimed at.
/obj/structure/siege_engine/ballista/proc/aim_turf()
	var/turf/T = get_turf(src)
	for (var/i in 1 to BALLISTA_RANGE)
		var/turf/N = get_step(T, dir)
		if (!N)
			break
		T = N
	return T

/obj/structure/siege_engine/ballista/attack_hand(mob/living/user)
	if (!ishuman(user) || !Adjacent(user))
		return ..()
	if (!loaded)
		to_chat(user, SPAN_WARNING("\The [src] isn't loaded."))
		return
	if (!anchored)
		to_chat(user, SPAN_WARNING("Fasten \the [src] down with a hammer before you loose it."))
		return
	if (!siege_can_fight())
		to_chat(user, SPAN_WARNING("You can't attack yet."))
		return
	if (winding)
		return
	winding = TRUE
	var/ok = do_after(user, 15, src)
	winding = FALSE
	if (!ok || QDELETED(src) || !loaded)
		return
	loose(user)

/obj/structure/siege_engine/ballista/proc/loose(mob/user)
	var/turf/target = aim_turf()
	if (!target || target == get_turf(src))
		return FALSE
	QDEL_NULL(loaded)
	update_icon()
	playsound(get_turf(src), 'sound/weapons/punchmiss.ogg', 100, TRUE)
	visible_message(SPAN_DANGER("\The [src] looses a bolt with a crack!"))
	var/obj/item/projectile/arrow/ballista_bolt/P = new(get_turf(src))
	P.launch(target, user, src)
	return TRUE

/obj/structure/siege_engine/ballista/Destroy()
	QDEL_NULL(loaded)
	return ..()

// ---- siege tower -----------------------------------------------------------------

/obj/structure/siege_engine/tower
	name = "siege tower"
	desc = "A tall wheeled timber tower clad in wet hides. Push it against a wall, face it there and lower its drop bridge; then the attackers beside it cross over the wall, covered from the arrows on the far side."
	icon = 'icons/obj/siege_tower.dmi'
	icon_state = "siege_tower"
	opacity = TRUE
	layer = MOB_LAYER + 0.2
	var/bridge = FALSE
	var/tmp/busy = FALSE

/obj/structure/siege_engine/tower/update_icon()
	icon_state = bridge ? "siege_tower_bridge" : "siege_tower"

/obj/structure/siege_engine/tower/proc/set_bridge(state)
	if (bridge == state)
		return
	bridge = state
	update_icon()

/obj/structure/siege_engine/tower/Move()
	. = ..()
	if (.)
		set_bridge(FALSE)

/obj/structure/siege_engine/tower/siege_rotated()
	set_bridge(FALSE)

// The wall the bridge rests on, or null.
/obj/structure/siege_engine/tower/proc/wall()
	return siege_wall_at(get_step(src, dir))

// Where a man crossing lands: the first clear tile beyond the wall.
/obj/structure/siege_engine/tower/proc/landing()
	var/turf/W = get_step(src, dir)
	if (!W)
		return null
	var/turf/L = get_step(W, dir)
	if (!L || L.density)
		return null
	for (var/atom/movable/AM in L)
		if (AM.density && !ismob(AM))
			return null
	return L

/obj/structure/siege_engine/tower/attack_hand(mob/living/user)
	if (!ishuman(user) || !Adjacent(user))
		return ..()
	if (busy)
		return
	if (bridge && !wall())
		set_bridge(FALSE)
	if (!bridge)
		if (!wall())
			to_chat(user, SPAN_WARNING("There is no wall in front of \the [src] for its bridge. Push it against one and face it there."))
			return
		if (!siege_can_fight())
			to_chat(user, SPAN_WARNING("You can't attack yet."))
			return
		busy = TRUE
		user.visible_message(SPAN_WARNING("[user] lowers the drop bridge of \the [src]!"), SPAN_NOTICE("You lower the drop bridge."))
		var/ok = do_after(user, TOWER_BRIDGE_TIME, src)
		busy = FALSE
		if (ok && !QDELETED(src) && wall())
			set_bridge(TRUE)
			playsound(get_turf(src), 'sound/weapons/smash.ogg', 70, TRUE)
		return
	cross(user)

// Climb the tower and cross the bridge over the wall. Returns TRUE on landing.
/obj/structure/siege_engine/tower/proc/cross(mob/living/human/user, skip_wait = FALSE)
	var/turf/L = landing()
	if (!L)
		to_chat(user, SPAN_WARNING("There's nowhere clear to land beyond the wall."))
		return FALSE
	if (!skip_wait)
		user.visible_message(SPAN_WARNING("[user] climbs \the [src]!"), SPAN_NOTICE("You climb \the [src] and run for the bridge."))
		if (!do_after(user, TOWER_CROSS_TIME, src) || QDELETED(src) || !bridge || landing() != L)
			return FALSE
	user.forceMove(L)
	user.visible_message(SPAN_DANGER("[user] leaps down from the siege tower's bridge!"))
	return TRUE

// ---- trebuchet ---------------------------------------------------------------------

/obj/structure/catapult/trebuchet
	name = "trebuchet"
	desc = "A counterweight trebuchet. Slower to wind than a catapult, it throws a heavier stone twice as far: it is built to break walls from beyond bowshot."
	icon = 'icons/obj/trebuchet.dmi'
	icon_state = "trebuchet0"
	bound_width = 32
	bound_height = 64
	min_range = 30
	max_range = 140
	blast = list(1, 3, 3)
	state_prefix = "trebuchet"
	loose_time = 60

// ---- castle defences -----------------------------------------------------------------

// A portcullis or a drawbridge: a gate worked from a winch, not by hand.
/obj/structure/castle_gate
	icon = 'icons/obj/siege_engines.dmi'
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	health = 900
	maxhealth = 900
	var/open = FALSE
	var/open_state = ""
	var/closed_state = ""
	var/tmp/moving = FALSE

/obj/structure/castle_gate/New()
	..()
	update_state()

/obj/structure/castle_gate/proc/update_state()
	density = !open
	icon_state = open ? open_state : closed_state

/obj/structure/castle_gate/proc/set_open(state)
	if (open == state || moving)
		return FALSE
	open = state
	update_state()
	playsound(get_turf(src), 'sound/effects/rollermove.ogg', 80, TRUE)
	visible_message(SPAN_WARNING("\The [src] [open ? "rises" : "comes down"]!"))
	return TRUE

/obj/structure/castle_gate/attack_hand(mob/user)
	to_chat(user, SPAN_NOTICE("\The [src] is far too heavy to move by hand. It is worked from a winch beside it."))

/obj/structure/castle_gate/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon) && W.force > 0)
		user.do_attack_animation(src)
		playsound(get_turf(src), 'sound/weapons/smash.ogg', 70, TRUE)
		siege_hit(src, W.force * 0.25)
		return
	return ..()

/obj/structure/castle_gate/ex_act(severity)
	siege_hit(src, severity == 1 ? maxhealth : (severity == 2 ? rand(150, 350) : rand(50, 100)))

/obj/structure/castle_gate/bullet_act(obj/item/projectile/P)
	siege_hit(src, max(1, P.damage * 0.05))

/obj/structure/castle_gate/portcullis
	name = "portcullis"
	desc = "An iron-shod oak grid that drops into a gateway. Arrows and spears pass through it, men do not. It is raised and dropped from a winch. Build sections side by side to close a wider gateway: they join into one grid, and one winch works them all."
	icon_state = "portcullis_closed"
	open_state = "portcullis_open"
	closed_state = "portcullis_closed"
	opacity = FALSE

/obj/structure/castle_gate/portcullis/CanPass(atom/movable/mover, turf/target, height = 0, air_group = 0)
	if (open)
		return TRUE
	if (istype(mover, /obj/item/projectile))
		return TRUE
	return FALSE

/obj/structure/castle_gate/portcullis/set_open(state)
	. = ..()
	if (. && open) // the frames run from shut to raised
		flick("portcullis_moving[join_suffix]", src)

/obj/structure/castle_gate/drawbridge
	name = "drawbridge"
	desc = "A plank bridge on chains across a ditch or a moat. Lowered, it can be walked over; raised, it shuts the gateway like a wall. It is worked from a winch."
	icon_state = "drawbridge_up"
	open_state = "drawbridge_down"
	closed_state = "drawbridge_up"
	opacity = TRUE
	layer = 2.1

/obj/structure/castle_gate/drawbridge/update_state()
	..()
	opacity = !open
	layer = open ? 2.1 : 3.2

// Lowered across water, men walk over it dry-shod.
/obj/structure/castle_gate/drawbridge/proc/spans_water()
	return open && istype(get_turf(src), /turf/floor/beach/water)

/obj/structure/castle_winch
	name = "gate winch"
	desc = "A timber windlass with a rope drum. Work it to raise or drop every portcullis and drawbridge within two tiles."
	icon = 'icons/obj/siege_engines.dmi'
	icon_state = "winch"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	not_disassemblable = FALSE
	var/tmp/busy = FALSE

// Gates within two tiles, and every section of a wide portcullis they belong to.
/obj/structure/castle_winch/proc/gates()
	. = list()
	for (var/obj/structure/castle_gate/G in range(2, src))
		if (G in .)
			continue
		if (istype(G, /obj/structure/castle_gate/portcullis))
			var/obj/structure/castle_gate/portcullis/P = G
			for (var/obj/structure/castle_gate/portcullis/S in P.portcullis_run())
				if (!(S in .))
					. += S
		else
			. += G
	for (var/obj/structure/gate/I in range(2, src))
		if (QDELETED(I) || !I.is_iron_grid_gate() || I in .)
			continue
		. |= I.iron_grid_run()

/obj/structure/castle_winch/attack_hand(mob/living/user)
	if (!ishuman(user) || !Adjacent(user))
		return ..()
	var/list/G = gates()
	if (!G.len)
		to_chat(user, SPAN_WARNING("There is no portcullis, drawbridge, or arched iron gate within two tiles of \the [src]."))
		return
	if (busy)
		return
	var/raise = FALSE
	var/obj/structure/castle_gate/first = G[1]
	if (istype(first))
		raise = !first.open
	else
		// Synchronize a mixed iron run by opening all sections first.
		for (var/obj/structure/gate/I in G)
			if (!I.open)
				raise = TRUE
				break
	busy = TRUE
	user.visible_message(SPAN_NOTICE("[user] [raise ? "winds" : "lets out"] \the [src]."), SPAN_NOTICE("You [raise ? "wind" : "let out"] \the [src][raise && G.len > 1 ? ", taking the weight of [G.len] sections" : ""]."))
	var/ok = do_after(user, wind_time(G, raise, user), src)
	busy = FALSE
	if (!ok || QDELETED(src))
		return
	work(raise)

// Raise (open) or drop (shut) every gate on this winch.
/obj/structure/castle_winch/proc/work(raise)
	var/list/targets = gates()
	for (var/obj/structure/castle_gate/G in targets)
		G.set_open(raise)
	for (var/obj/structure/gate/I in targets)
		I.set_iron_grid_open(raise)

// A murder hole: an opening in a floor. What is poured or dropped through it
// lands on the tile below (castle_pour.dm), and the level below shows through it.
/obj/structure/murder_hole
	name = "murder hole"
	desc = "An opening in the floor over a gateway. Heat oil, water, pitch, sand or lead over a fire and pour it through, or drop stones, onto whoever stands below."
	icon = 'icons/obj/castle_defences.dmi'
	icon_state = "murder_hole_rim"
	anchored = TRUE
	density = FALSE
	layer = 2.15
	not_movable = TRUE
	not_disassemblable = FALSE
	var/tmp/obj/effect/open_air_view/below_view = null

/obj/structure/murder_hole/New()
	..()
	addtimer(CALLBACK(src, PROC_REF(show_below)), 1)

/obj/structure/murder_hole/after_load()
	..()
	show_below()

/obj/structure/murder_hole/Destroy()
	if (below_view)
		vis_contents -= below_view
		open_air_views_fixed -= below_view
		qdel(below_view)
		below_view = null
	return ..()

// The tile below shows through the hole, darkened like open air (open_air_view.dm).
/obj/structure/murder_hole/proc/show_below()
	if (below_view || QDELETED(src))
		return
	var/turf/T = get_turf(src)
	var/turf/below = T ? GetBelow(T) : null
	if (!below)
		return
	var/obj/effect/open_air_view/V = new
	V.loc = null
	// Drawn as an underlay of the hole, so the rim stays on top.
	V.vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID | VIS_UNDERLAY
	V.open_air_show(below)
	open_air_views_fixed += V
	below_view = V
	vis_contents += V

// The tile under the hole: the level below on a multi-level castle,
// otherwise the gateway tile in front of it (the way it faces).
/obj/structure/murder_hole/proc/drop_turf()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	var/turf/below = GetBelow(T)
	if (below)
		return below
	return get_step(T, dir)

/obj/structure/murder_hole/pour_target()
	return drop_turf()

/obj/structure/murder_hole/attackby(obj/item/W, mob/user)
	if (castle_opening_attackby(src, W, user))
		return
	return ..()


// ---- undermining -------------------------------------------------------------------

// Digging out the ground right under a wall, gate or door on the level above
// brings it down half a minute later, unless a mine support is propped in the
// tunnel by then. Burning or pulling out that prop brings it down at once.
#define UNDERMINE_DELAY 300

/turf/change_the_turf()
	var/tx = x
	var/ty = y
	var/tz = z
	..()
	var/turf/T = locate(tx, ty, tz)
	if (siege_undermine_target(T))
		T.visible_message(SPAN_WARNING("The roof of the tunnel creaks under the weight of the wall above. Prop it with a mine support or get out!"))
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(siege_undermine), T), UNDERMINE_DELAY)

// The wall standing over T, if T is an open, unpropped tunnel tile.
/proc/siege_undermine_target(turf/T)
	if (!T || T.density)
		return null
	var/turf/above = GetAbove(T)
	if (!above)
		return null
	var/atom/W = siege_wall_at(above)
	if (!W || isturf(W))
		return null
	for (var/obj/structure/mine_support/S in range(1, T))
		if (!QDELETED(S))
			return null
	return W

// Bring down the wall over T if nothing holds it up. Returns TRUE if it fell.
/proc/siege_undermine(turf/T)
	var/atom/W = siege_undermine_target(T)
	if (!W)
		return FALSE
	var/turf/above = get_turf(W)
	above.visible_message(SPAN_DANGER("The ground gives way and \the [W] collapses into the mine below!"))
	T.visible_message(SPAN_DANGER("The tunnel roof caves in with a roar!"))
	playsound(above, 'sound/weapons/smash.ogg', 100, TRUE)
	siege_hit(W, 100000)
	return TRUE

/obj/structure/mine_support/Destroy()
	var/turf/T = get_turf(src)
	. = ..()
	if (T)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(siege_undermine), T), 1)

#undef UNDERMINE_DELAY

#undef RAM_BLOW
#undef RAM_MAX_CREW
#undef RAM_SWING_TIME
#undef BALLISTA_RANGE
#undef TOWER_CROSS_TIME
#undef TOWER_BRIDGE_TIME
