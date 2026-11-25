// Gateway traps (docs/siege-engines.md#gateway-traps).
//
// - Drop trapdoor: planks over an open pit or over open air on an upper floor,
//   held shut by a pin. A trap lever within three tiles (on the same level or
//   the level above) pulls the pin: everyone on it drops into the pit or to the
//   level below. Pull the lever back to shut it again.
// - Crushing portcullis: a portcullis dropped on someone hurts and pins them.
// - Caltrops: iron spikes scattered on the ground wound feet and lame horses.
// - Ladder fork: pushes a deployed siege ladder off the wall from the top.

#define TRAPDOOR_INSTALL_TIME 50	// ds to fit a trapdoor over a hole
#define TRAP_LEVER_RANGE 3			// tiles a lever reaches
#define TRAP_LEVER_PULL_TIME 5		// ds to pull the pin
#define TRAP_LEVER_RESET_TIME 30	// ds to wind the trapdoor shut again
#define PORTCULLIS_CRUSH_MIN 30
#define PORTCULLIS_CRUSH_MAX 40
#define CALTROP_MIN 5
#define CALTROP_MAX 10
#define CALTROP_HOBBLE 15			// ds a step onto caltrops costs
#define CALTROP_LAME_TIME (30 SECONDS)
#define CALTROP_THROW_CHANCE 50		// % a lamed horse throws its rider
#define CALTROP_PICKUP_TIME 20
#define LADDER_FORK_TIME 30			// ds to push a ladder off with a fork or polearm

// ---- trapdoor ----------------------------------------------------------------------

/obj/item/castle_trapdoor_kit
	name = "drop trapdoor"
	desc = "Iron-hinged oak planks held up by a pin, made to fall open under whoever stands on them. Fit it over an open pit, or over a hole in an upper floor, then build a trap lever within three tiles to drop it."
	icon = 'icons/obj/castle_defences.dmi'
	icon_state = "trapdoor_shut"
	w_class = ITEM_SIZE_LARGE
	flammable = TRUE
	value = 6

// Why a trapdoor can't be fitted over T, or null.
/proc/trapdoor_site_refusal(turf/T)
	if (!T)
		return "There is nothing there to fit it over."
	if ((locate(/obj/structure/castle_trapdoor) in T) || trapdoor_at(T))
		return "There is already a trapdoor there."
	var/obj/structure/stone_age_trap/pit/P = locate() in T
	if (P)
		if (P.covered)
			return "Uncover the pit first."
		if (P.buckled_mob)
			return "Get [P.buckled_mob] out of the pit first."
		return null
	if (building_open_turf(T) && multiz_level_below(T.z) && !(locate(/obj/covers) in T))
		return null
	return "A trapdoor goes over an open pit (dig one with a pit cover and a shovel) or over a hole in an upper floor."

/obj/item/castle_trapdoor_kit/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!proximity_flag || !ishuman(user))
		return ..()
	var/turf/T = get_turf(target)
	if (!T || T == get_turf(user) || !user.Adjacent(T))
		return ..()
	var/refusal = trapdoor_site_refusal(T)
	if (refusal)
		to_chat(user, SPAN_WARNING(refusal))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts fitting \the [src]."), SPAN_NOTICE("You start fitting \the [src]."))
	if (!do_after(user, TRAPDOOR_INSTALL_TIME, T) || QDELETED(src) || loc != user || trapdoor_site_refusal(T))
		return TRUE
	user.drop_from_inventory(src)
	var/obj/structure/castle_trapdoor/D = new(T)
	D.setter_name = user.real_name
	qdel(src)
	user.visible_message(SPAN_NOTICE("[user] fits a trapdoor."), SPAN_NOTICE("You fit the drop trapdoor. Build a trap lever within three tiles to drop it."))
	return TRUE

/obj/structure/castle_trapdoor
	name = "drop trapdoor"
	desc = "Oak planks set flush in the floor on iron hinges, held shut by a pin. A trap lever pulls the pin."
	icon = 'icons/obj/castle_defences.dmi'
	icon_state = "trapdoor_shut"
	anchored = TRUE
	density = FALSE
	layer = TURF_LAYER + 0.2	// over the pit it covers
	not_movable = TRUE
	not_disassemblable = FALSE
	flammable = TRUE
	var/open = FALSE
	var/setter_name = null

/obj/structure/castle_trapdoor/after_load()
	..()
	update_icon()

/obj/structure/castle_trapdoor/update_icon()
	icon_state = open ? "trapdoor_open" : "trapdoor_shut"
	name = open ? "open drop trapdoor" : "drop trapdoor"

/obj/structure/castle_trapdoor/proc/pit()
	return locate(/obj/structure/stone_age_trap/pit) in loc

// Over open air with a level below: what drops falls a level.
/obj/structure/castle_trapdoor/proc/over_air()
	var/turf/T = get_turf(src)
	return T && building_open_turf(T) && multiz_level_below(T.z)

/obj/structure/castle_trapdoor/examine(mob/user)
	..()
	if (open)
		to_chat(user, SPAN_WARNING("It hangs open over [over_air() ? "the level below" : "a pit"]."))
	else if (get_dist(user, src) <= 1)
		to_chat(user, SPAN_NOTICE("A pin holds it shut. A trap lever within three tiles drops it."))

// Pull the pin: everyone on it drops.
/obj/structure/castle_trapdoor/proc/drop()
	if (open)
		return FALSE
	open = TRUE
	update_icon()
	flick("trapdoor_dropping", src)
	playsound(get_turf(src), 'sound/effects/thud.ogg', 70, TRUE)
	visible_message(SPAN_DANGER("\The [src] drops open!"))
	var/turf/T = get_turf(src)
	if (over_air())
		for (var/atom/movable/A in T.contents.Copy())
			if (A != src && (isliving(A) || isitem(A)) && A.loc == T)
				T.Entered(A)
	else
		for (var/mob/living/L in T)
			trapdoor_catch(L)
	return TRUE

/obj/structure/castle_trapdoor/proc/shut()
	if (!open)
		return FALSE
	open = FALSE
	update_icon()
	playsound(get_turf(src), 'sound/effects/rollermove.ogg', 50, TRUE)
	visible_message(SPAN_NOTICE("\The [src] swings shut."))
	return TRUE

// Someone on an open trapdoor over a pit falls in.
/obj/structure/castle_trapdoor/proc/trapdoor_catch(mob/living/L)
	var/obj/structure/stone_age_trap/pit/P = pit()
	if (!P || !open || L.stat == DEAD || L.buckled || L == P.buckled_mob || isobserver(L))
		return FALSE
	P.fall(L)
	return TRUE

/obj/structure/castle_trapdoor/Crossed(atom/movable/AM)
	. = ..()
	if (open && isliving(AM) && !over_air())
		trapdoor_catch(AM)

// A shut trapdoor is floor: nothing on it falls through open air (building_levels.dm,
// open_space.dm). The trapdoor itself never falls.
/proc/castle_trapdoor_holds(turf/T, atom/movable/A)
	if (istype(A, /obj/structure/castle_trapdoor))
		return TRUE
	// A lift platform standing in its shaft is floor too (lifts.dm).
	if (istype(A, /obj/structure/lift_platform) || (locate(/obj/structure/lift_platform) in T))
		return TRUE
	for (var/obj/structure/castle_trapdoor/D in T)
		if (!D.open)
			return TRUE
	return FALSE

// ---- trap lever --------------------------------------------------------------------

/obj/structure/castle_trap_lever
	name = "trap lever"
	desc = "A timber lever on an iron pin. Pull it to drop every trapdoor within three tiles, on this level or the one below; pull it back to shut them."
	icon = 'icons/obj/castle_defences.dmi'
	icon_state = "trap_lever"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	var/pulled = FALSE
	var/tmp/busy = FALSE

/obj/structure/castle_trap_lever/after_load()
	..()
	update_icon()

/obj/structure/castle_trap_lever/update_icon()
	icon_state = pulled ? "trap_lever_pulled" : "trap_lever"

// Trapdoors within reach, on this level and the one below.
/obj/structure/castle_trap_lever/proc/trapdoors()
	. = list()
	for (var/obj/structure/castle_trapdoor/D in range(TRAP_LEVER_RANGE, src))
		. += D
	var/below = multiz_level_below(z)
	if (!below)
		return
	var/turf/low = locate(max(1, x - TRAP_LEVER_RANGE), max(1, y - TRAP_LEVER_RANGE), below)
	var/turf/high = locate(min(world.maxx, x + TRAP_LEVER_RANGE), min(world.maxy, y + TRAP_LEVER_RANGE), below)
	if (!low || !high)
		return
	for (var/turf/T in block(low, high))
		for (var/obj/structure/castle_trapdoor/D in T)
			. += D

/obj/structure/castle_trap_lever/attack_hand(mob/living/user)
	if (!ishuman(user) || !Adjacent(user))
		return ..()
	if (busy)
		return
	var/list/doors = trapdoors()
	if (!doors.len)
		to_chat(user, SPAN_WARNING("There is no trapdoor within three tiles of \the [src]."))
		return
	busy = TRUE
	var/drop = !pulled
	user.visible_message(SPAN_WARNING("[user] [drop ? "hauls on" : "pushes back"] \the [src]."), SPAN_NOTICE("You [drop ? "haul on" : "push back"] \the [src]."))
	var/ok = do_after(user, drop ? TRAP_LEVER_PULL_TIME : TRAP_LEVER_RESET_TIME, src)
	busy = FALSE
	if (!ok || QDELETED(src))
		return
	work(drop)

/obj/structure/castle_trap_lever/proc/work(drop)
	pulled = drop
	update_icon()
	playsound(get_turf(src), 'sound/effects/rollermove.ogg', 40, TRUE)
	for (var/obj/structure/castle_trapdoor/D in trapdoors())
		if (drop)
			D.drop()
		else
			D.shut()

// ---- crushing portcullis ------------------------------------------------------------

/obj/structure/castle_gate/portcullis/set_open(state)
	. = ..()
	if (. && !open)
		crush_under()

// Whoever stands under it when it comes down is struck and pinned.
/obj/structure/castle_gate/portcullis/proc/crush_under()
	for (var/mob/living/L in loc)
		if (L.stat == DEAD || isobserver(L))
			continue
		var/damage = rand(PORTCULLIS_CRUSH_MIN, PORTCULLIS_CRUSH_MAX)
		if (ishuman(L))
			var/mob/living/human/H = L
			var/zone = pick("head", "chest", "l_arm", "r_arm")
			var/blocked = H.run_armor_check(zone, "melee")
			H.apply_damage(damage, BRUTE, zone, blocked, used_weapon = "a falling portcullis")
		else
			L.adjustBruteLoss(damage)
		L.Weaken(3)
		L.visible_message(SPAN_DANGER("\The [src] crashes down on [L], pinning them!"), SPAN_DANGER("\The [src] crashes down on you and pins you to the ground!"))
		playsound(get_turf(src), 'sound/weapons/smash.ogg', 80, TRUE)

// ---- caltrops ------------------------------------------------------------------------

/obj/item/weapon/caltrops
	name = "caltrops"
	desc = "Four-pointed iron spikes that always land with one point up. Scatter them on the ground in front of a gate: they wound feet and lame horses. Use them in hand to scatter them where you stand."
	icon = 'icons/obj/castle_defences.dmi'
	icon_state = "caltrops"
	gender = PLURAL
	w_class = ITEM_SIZE_SMALL
	force = 3
	throwforce = 5
	flags = CONDUCT
	value = 4

// A world.time mark, kept out of saves by world_time_stamps.dm.
/mob/living/simple_animal/horse/var/lamed_until = 0

/mob/living/simple_animal/horse/ride_delay()
	. = ..()
	if (lamed_until > world.time)
		. *= 2

/obj/item/weapon/caltrops/attack_self(mob/user)
	var/turf/T = get_turf(user)
	if (!T)
		return
	user.drop_from_inventory(src, T)
	user.visible_message(SPAN_WARNING("[user] scatters \the [src] on the ground."), SPAN_NOTICE("You scatter \the [src] where you stand. Watch your step."))

/obj/item/weapon/caltrops/attack_hand(mob/user)
	if (!isturf(loc) || !ishuman(user))
		return ..()
	to_chat(user, SPAN_NOTICE("You start gingerly gathering up \the [src]."))
	if (!do_after(user, CALTROP_PICKUP_TIME, src) || !isturf(loc))
		return
	return ..()

/obj/item/weapon/caltrops/Crossed(atom/movable/AM)
	. = ..()
	if (isturf(loc) && isliving(AM))
		caltrop_step(AM)

// Boots that turn a point: anything with a sole worth the name.
/proc/caltrop_proof_shoes(mob/living/human/H)
	var/obj/item/clothing/shoes/S = H.shoes
	if (!istype(S))
		return FALSE
	if (findtext(lowertext(S.name), "boot"))
		return TRUE
	return S.armor && S.armor["melee"] >= 10

/obj/item/weapon/caltrops/proc/caltrop_step(mob/living/L)
	if (L.stat == DEAD || L.buckled)
		return FALSE
	if (ishuman(L))
		var/mob/living/human/H = L
		if (H.riding && H.riding_mob)
			return lame_horse(H.riding_mob, H)
		var/damage = rand(CALTROP_MIN, CALTROP_MAX)
		if (caltrop_proof_shoes(H))
			damage = round(damage / 2)
		H.apply_damage(damage, BRUTE, pick("l_foot", "r_foot"), sharp = TRUE, used_weapon = "caltrops")
		H.setMoveCooldown(CALTROP_HOBBLE)
		to_chat(H, SPAN_DANGER("You step on \the [src]! A spike goes into your foot."))
		return TRUE
	if (istype(L, /mob/living/simple_animal))
		var/mob/living/simple_animal/A = L
		if (A.rider)
			return FALSE // the rider's step lames it
		if (istype(A, /mob/living/simple_animal/horse))
			return lame_horse(A, null)
		if (A.mob_size >= MOB_MEDIUM)
			A.adjustBruteLoss(rand(CALTROP_MIN, CALTROP_MAX) / 2)
	return FALSE

/obj/item/weapon/caltrops/proc/lame_horse(mob/living/simple_animal/A, mob/living/human/rider)
	if (!A)
		return FALSE
	A.adjustBruteLoss(rand(CALTROP_MIN, CALTROP_MAX))
	if (istype(A, /mob/living/simple_animal/horse))
		var/mob/living/simple_animal/horse/HR = A
		HR.lamed_until = world.time + CALTROP_LAME_TIME
	A.visible_message(SPAN_DANGER("\The [A] treads on \the [src] and screams, going lame!"))
	if (rider && prob(CALTROP_THROW_CHANCE))
		A.visible_message(SPAN_DANGER("\The [A] rears and throws [rider]!"))
		horse_throw_rider(A, rider)
	return TRUE

// ---- ladder fork -------------------------------------------------------------------

/obj/item/weapon/ladder_fork
	name = "ladder fork"
	desc = "A long pole with a two-pronged iron fork. From the top of a wall, use it on a siege ladder to push it off, with whoever is on it."
	icon = 'icons/obj/castle_defences.dmi'
	icon_state = "ladder_fork"
	w_class = ITEM_SIZE_LARGE
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_WEAK
	attack_verb = list("jabbed", "shoved", "prodded")
	flammable = TRUE
	value = 3

/proc/ladder_pusher(obj/item/I)
	return istype(I, /obj/item/weapon/ladder_fork) || is_charge_polearm(I)

/obj/item/weapon/siegeladder/attackby(obj/item/W, mob/user)
	if (deployed && ladder_pusher(W) && ishuman(user))
		push_off(user)
		return TRUE
	return ..()

// Throw a deployed ladder down off the wall, and whoever is climbing it.
/obj/item/weapon/siegeladder/proc/push_off(mob/living/human/user)
	if (!Adjacent(user))
		return FALSE
	user.visible_message(SPAN_DANGER("[user] sets \the [user.get_active_hand()] against \the [src] and starts to push!"), SPAN_DANGER("You set your weight against \the [src]."))
	if (!do_after(user, LADDER_FORK_TIME, src) || !deployed)
		return FALSE
	var/turf/T = get_turf(src)
	var/obj/structure/target = deployed_target()
	if (!retract())
		return FALSE
	var/list/fallers = list()
	// Climbers are tracked by structure, not per ladder. Only the loss of
	// their target's last usable route can make them fall with this ladder.
	if (target && !target.is_climbable_with_support())
		fallers = target.climbers.Copy()
		target.climbers.Cut()
	var/turf/away = get_step(T, get_dir(user, T))
	if (away && !away.density)
		forceMove(away)
	user.visible_message(SPAN_DANGER("[user] pushes \the [src] off the wall!"), SPAN_DANGER("You push \the [src] off the wall!"))
	playsound(T, 'sound/effects/thud.ogg', 60, TRUE)
	for (var/mob/living/M in fallers)
		M.visible_message(SPAN_DANGER("[M] falls with \the [src]!"), SPAN_DANGER("The ladder goes over and you fall!"))
		M.Weaken(3)
		if (ishuman(M))
			var/mob/living/human/H = M
			H.apply_damage(rand(5, 15), BRUTE, pick("l_leg", "r_leg", "chest"))
		else
			M.adjustBruteLoss(rand(5, 15))
	return TRUE

#undef TRAPDOOR_INSTALL_TIME
#undef TRAP_LEVER_RANGE
#undef TRAP_LEVER_PULL_TIME
#undef TRAP_LEVER_RESET_TIME
#undef PORTCULLIS_CRUSH_MIN
#undef PORTCULLIS_CRUSH_MAX
#undef CALTROP_MIN
#undef CALTROP_MAX
#undef CALTROP_HOBBLE
#undef CALTROP_LAME_TIME
#undef CALTROP_THROW_CHANCE
#undef CALTROP_PICKUP_TIME
#undef LADDER_FORK_TIME
