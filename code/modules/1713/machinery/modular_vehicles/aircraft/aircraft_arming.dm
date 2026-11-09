// Arming the light plane: a machine gun fixed in the nose, bombs hung under
// the wings, and the bomb racks of a carrier's magazine.
//
// The forward gun is any light machine gun bolted into the nose section. The
// pilot fires it from the control column along the plane's heading; in low
// flight the burst goes down onto the ground ahead of the nose, so a plane
// can strafe, and at cruise height it is too high to aim. Bombs are steel
// casings filled with nitroglycerin, hung one to a wing, and dropped from the
// column onto the ground under the plane, where they burst. Bombs cook off
// when a blast reaches them, so a carrier's magazine racks are worth a hit.

#define AIRCRAFT_GUN_RANGE 7          // Tiles ahead of the nose the burst is aimed at.
#define AIRCRAFT_BOMBS_PER_WING 1
#define AIRCRAFT_BOMB_CHARGE 10        // Units of nitroglycerin a casing takes.
#define AIRCRAFT_BOMB_RACK_SLOTS 8

// ---- The bomb ----

/obj/item/weapon/aircraft_bomb
	name = "empty aircraft bomb casing"
	desc = "A finned steel casing for an aircraft bomb. Fill it with nitroglycerin, then hang it under a wing."
	icon = 'icons/obj/grenade.dmi'
	icon_state = "aircraft_bomb"
	item_state = "bomb"
	w_class = ITEM_SIZE_HUGE
	weight = 25
	flags = NOBLUDGEON
	var/filled = FALSE
	var/tmp/going_off = FALSE

/obj/item/weapon/aircraft_bomb/persistence_runtime_var(key)
	return key == "going_off" || ..()

/obj/item/weapon/aircraft_bomb/filled
	filled = TRUE

/obj/item/weapon/aircraft_bomb/New()
	..()
	update_names()

/obj/item/weapon/aircraft_bomb/proc/update_names()
	if (filled)
		name = "aircraft bomb"
		desc = "A finned steel bomb filled with nitroglycerin. Hang it under a wing and drop it from the control column. It goes off if a blast reaches it."
	else
		name = initial(name)
		desc = initial(desc)

/obj/item/weapon/aircraft_bomb/examine(mob/user)
	..()
	to_chat(user, filled ? "It is filled and fused." : "It is empty: it takes [AIRCRAFT_BOMB_CHARGE] units of nitroglycerin.")

/obj/item/weapon/aircraft_bomb/attackby(obj/item/W, mob/user)
	if (!filled && istype(W, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RG = W
		if (!RG.reagents || !RG.reagents.has_reagent("nitroglycerin", AIRCRAFT_BOMB_CHARGE))
			to_chat(user, SPAN_WARNING("The casing takes [AIRCRAFT_BOMB_CHARGE] units of nitroglycerin."))
			return
		RG.reagents.remove_reagent("nitroglycerin", AIRCRAFT_BOMB_CHARGE)
		filled = TRUE
		update_names()
		to_chat(user, SPAN_NOTICE("You fill \the [src] with the explosive charge."))
		return
	..()

// Bursts where it lies: a crater's worth on a deck, a breach's worth on a
// hull wall beside it. An empty casing just clangs.
/obj/item/weapon/aircraft_bomb/proc/detonate()
	if (going_off || QDELETED(src))
		return FALSE
	var/turf/T = get_turf(src)
	if (!T)
		return FALSE
	going_off = TRUE
	if (!filled)
		T.visible_message(SPAN_WARNING("\The [src] clangs onto \the [T]."))
		going_off = FALSE
		return FALSE
	T.visible_message(SPAN_DANGER("\The [src] bursts!"))
	// Lift it off the deck first so the blast does not find it again.
	forceMove(null)
	explosion(T, 1, 2, 4, 3, sound = 'sound/weapons/Explosives/Dynamite.ogg')
	qdel(src)
	return TRUE

// A blast that reaches a filled bomb sets it off: magazines are dangerous.
/obj/item/weapon/aircraft_bomb/ex_act(severity)
	if (filled && severity <= 2)
		detonate()
		return
	..()

// ---- Bomb racks ----

// The carrier magazine's rack: it keeps the bombs in one place, which is also
// where a hit on the magazine finds them.
/obj/structure/shellrack/bombs
	name = "bomb rack"
	desc = "A steel rack for aircraft bombs. A blast that reaches it sets off every filled bomb in it."
	anchored = TRUE
	not_movable = TRUE

/obj/structure/shellrack/bombs/New()
	..()
	storage.storage_slots = AIRCRAFT_BOMB_RACK_SLOTS
	storage.max_storage_space = AIRCRAFT_BOMB_RACK_SLOTS * ITEM_SIZE_HUGE
	storage.can_hold = list(/obj/item/weapon/aircraft_bomb)

/obj/structure/shellrack/bombs/proc/bombs()
	. = list()
	if (storage)
		for (var/obj/item/weapon/aircraft_bomb/B in storage.contents)
			. += B

/obj/structure/shellrack/bombs/ex_act(severity)
	if (severity > 2)
		return
	var/turf/T = get_turf(src)
	var/list/stored = bombs()
	for (var/obj/item/weapon/aircraft_bomb/B in stored)
		B.forceMove(T)
	for (var/obj/item/weapon/aircraft_bomb/B in stored)
		if (!QDELETED(B))
			B.ex_act(severity)
	update_icon()

/obj/structure/shellrack/bombs/update_icon()
	if (storage)
		icon_state = "shellrack[min(storage.contents.len, 16)]"

// ---- Mounting on the airframe ----

// The nose section holds the gun and the wings the bombs; both are found in
// the frames each time, so nothing on the axis has to be saved.
/obj/structure/vehicleparts/axis/aircraft/proc/nose_frame()
	for (var/obj/structure/vehicleparts/frame/car/aircraft/nose/center/N in frames())
		return N
	return null

/obj/structure/vehicleparts/axis/aircraft/proc/forward_gun()
	var/obj/structure/vehicleparts/frame/N = nose_frame()
	if (!N)
		return null
	for (var/obj/item/weapon/gun/projectile/automatic/G in N)
		return G
	return null

/obj/structure/vehicleparts/axis/aircraft/proc/bombs()
	. = list()
	for (var/obj/structure/vehicleparts/frame/car/aircraft/wing/W in frames())
		for (var/obj/item/weapon/aircraft_bomb/B in W)
			. += B

// The nose section: a light machine gun bolts in, its magazines go in through
// the section, and a wrench takes it out again.
/obj/structure/vehicleparts/frame/car/aircraft/nose/center/attackby(obj/item/I, mob/living/human/H)
	if (!I || !H || !axis)
		return ..()
	var/obj/structure/vehicleparts/axis/aircraft/A = axis
	var/obj/item/weapon/gun/projectile/automatic/mounted = istype(A) ? A.forward_gun() : null
	if (istype(I, /obj/item/weapon/gun/projectile/automatic) && !istype(I, /obj/item/weapon/gun/projectile/automatic/stationary))
		if (mounted)
			to_chat(H, SPAN_WARNING("\The [mounted] is already mounted in the nose."))
			return
		if (!H.drop_from_inventory(I, src))
			return
		I.forceMove(src)
		var/obj/item/weapon/gun/projectile/automatic/G = I
		G.safetyon = FALSE
		H.visible_message(SPAN_NOTICE("[H] bolts \the [I] into \the [src]."), SPAN_NOTICE("You bolt \the [I] into the nose, safety off. Fire it from the control column with your free hand."))
		return
	if (mounted && istype(I, /obj/item/ammo_magazine))
		mounted.attackby(I, H)
		return
	if (mounted && istype(I, /obj/item/weapon/wrench))
		mounted.forceMove(get_turf(H))
		H.put_in_hands(mounted)
		H.visible_message(SPAN_NOTICE("[H] unbolts \the [mounted] from \the [src]."), SPAN_NOTICE("You unbolt \the [mounted] from the nose."))
		return
	return ..()

/obj/structure/vehicleparts/frame/car/aircraft/nose/center/examine(mob/user)
	..()
	var/obj/structure/vehicleparts/axis/aircraft/A = axis
	var/obj/item/weapon/gun/projectile/automatic/G = istype(A) ? A.forward_gun() : null
	if (G)
		to_chat(user, "\A [G] is mounted in the nose, [G.getAmmo()] round\s left.")
	else
		to_chat(user, "A light machine gun could be bolted into the nose.")

// A wing: one bomb hangs under each, hung by hand and taken down with a wrench.
/obj/structure/vehicleparts/frame/car/aircraft/wing/attackby(obj/item/I, mob/living/human/H)
	if (!I || !H)
		return ..()
	var/list/hung = list()
	for (var/obj/item/weapon/aircraft_bomb/B in src)
		hung += B
	if (istype(I, /obj/item/weapon/aircraft_bomb))
		if (hung.len >= AIRCRAFT_BOMBS_PER_WING)
			to_chat(H, SPAN_WARNING("The wing already carries its bomb."))
			return
		if (!H.drop_from_inventory(I, src))
			return
		I.forceMove(src)
		H.visible_message(SPAN_NOTICE("[H] hangs \the [I] under \the [src]."), SPAN_NOTICE("You hang \the [I] under the wing. Drop it from the control column in the air."))
		return
	if (hung.len && istype(I, /obj/item/weapon/wrench))
		var/obj/item/weapon/aircraft_bomb/B = hung[1]
		B.forceMove(get_turf(H))
		H.put_in_hands(B)
		H.visible_message(SPAN_NOTICE("[H] takes \the [B] down from \the [src]."), SPAN_NOTICE("You take \the [B] down from the wing."))
		return
	return ..()

/obj/structure/vehicleparts/frame/car/aircraft/wing/examine(mob/user)
	..()
	var/n = 0
	for (var/obj/item/weapon/aircraft_bomb/B in src)
		n++
	to_chat(user, n ? "[n] bomb\s hang\s under the wing." : "A bomb could be hung under the wing.")

// ---- Firing and bombing ----

// The turf the gun fires from: under the nose on the ground in low flight,
// the nose's own tile on the ground. Null at cruise height.
/obj/structure/vehicleparts/axis/aircraft/proc/gun_turf()
	var/obj/structure/vehicleparts/frame/N = nose_frame()
	var/turf/here = N ? get_turf(N) : null
	if (!here)
		return null
	if (!airborne())
		return here
	if (flight_state == AIRCRAFT_CRUISE)
		return null
	var/ground = ground_z()
	return ground ? locate(here.x, here.y, ground) : null

// Fires the forward gun along the heading. Returns null when it fired, else
// why not.
/obj/structure/vehicleparts/axis/aircraft/proc/fire_guns(mob/living/user)
	var/obj/item/weapon/gun/projectile/automatic/G = forward_gun()
	if (!G)
		return "There is no gun in the nose."
	if (flight_state == AIRCRAFT_CRUISE)
		return "Too high to strafe: descend to low flight first."
	var/turf/from = gun_turf()
	if (!from)
		return "There is nothing below to fire at."
	var/turf/target = from
	for (var/i = 1, i <= AIRCRAFT_GUN_RANGE, i++)
		var/turf/next = get_step(target, dir)
		if (!next)
			break
		target = next
	if (target == from)
		return "The nose points at the edge of the world."
	if (!G.getAmmo())
		return "\The [G] is empty: load a magazine through the nose section."
	var/obj/structure/vehicleparts/frame/N = nose_frame()
	G.forceMove(from)
	G.dir = dir
	G.recoil = 1
	G.Fire(target, user)
	G.forceMove(N)
	return null

// Drops the first bomb hung under a wing onto the ground under the plane.
// Returns null when it fell, else why not.
/obj/structure/vehicleparts/axis/aircraft/proc/drop_bomb(mob/living/user)
	var/list/hung = bombs()
	if (!hung.len)
		return "There are no bombs under the wings."
	if (!airborne())
		return "Drop bombs from the air, not the ground."
	var/ground = ground_z()
	var/turf/centre = footprint_centre()
	var/turf/T = (ground && centre) ? locate(centre.x, centre.y, ground) : null
	if (!T)
		return "There is no ground below to bomb."
	var/obj/item/weapon/aircraft_bomb/B = hung[1]
	B.forceMove(T)
	visible_message(SPAN_WARNING("A bomb falls away from \the [src]!"))
	if (user)
		to_chat(user, SPAN_NOTICE("Bomb away, onto [T.name] at [T.x], [T.y]."))
	B.detonate()
	return null

/obj/item/vehicleparts/wheel/modular/aircraft/verb/fire_guns_verb()
	set name = "Fire guns"
	set category = null
	set src in usr
	var/obj/structure/vehicleparts/axis/aircraft/A = flown_aircraft(usr)
	if (!A)
		return
	var/refusal = A.fire_guns(usr)
	if (refusal)
		to_chat(usr, SPAN_WARNING(refusal))

/obj/item/vehicleparts/wheel/modular/aircraft/verb/drop_bomb_verb()
	set name = "Drop bomb"
	set category = null
	set src in usr
	var/obj/structure/vehicleparts/axis/aircraft/A = flown_aircraft(usr)
	if (!A)
		return
	var/refusal = A.drop_bomb(usr)
	if (refusal)
		to_chat(usr, SPAN_WARNING(refusal))

#undef AIRCRAFT_GUN_RANGE
#undef AIRCRAFT_BOMBS_PER_WING
#undef AIRCRAFT_BOMB_CHARGE
#undef AIRCRAFT_BOMB_RACK_SLOTS
