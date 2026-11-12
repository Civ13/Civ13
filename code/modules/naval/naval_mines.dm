// ============================================================
// Naval mines (docs/naval-mines.md)
// ------------------------------------------------------------
// A mine is carried as a heavy item and laid on open water: over the side of
// a ship or boat, or from the shore. Laid, it is a structure moored just under
// the surface, drawn as a shadow.
//
//   - A contact mine goes off when a hull comes onto its tile.
//   - A magnetic mine goes off when a hull's magnetic signature
//     (magnetic_signature.dm) is strong enough where it lies: the felt
//     signature over the distance squared must reach its threshold, out to
//     NAVAL_MINE_REACH tiles. A wooden hull never sets one off.
//
// Nothing ticks. A craft looks for mines after every move it makes
// (craft.on_hop() for ships and built hulls, the movement loop for modular
// boats), only on its own level and only near the box it swept, so a still
// sea and a sea with no mines cost nothing. Mines are never carried along by
// a hull that passes over them.
// ============================================================

#define NAVAL_MINE_REACH 4
#define NAVAL_MINE_THRESHOLD 15
#define NAVAL_MINE_LAY_TIME (5 SECONDS)
#define NAVAL_MINE_DISARM_TIME (8 SECONDS)

var/global/list/naval_mines = list()

// TRUE for things a moving hull leaves where they are (craft bodies and
// modular boats skip them when they gather what they carry).
/atom/movable/proc/craft_left_behind()
	return FALSE

// ---- The item ----

/obj/item/naval_mine
	name = "contact mine"
	desc = "A steel sphere of explosive with lead horns, a sinker and a mooring cable. Lay it on open water from a deck or the shore; any hull that runs onto it sets it off."
	icon = 'icons/obj/naval_mines.dmi'
	icon_state = "contact"
	w_class = ITEM_SIZE_HUGE
	force = 8
	throwforce = 2
	throw_range = 1
	flags = CONDUCT
	var/laid_type = /obj/structure/naval_mine/contact

/obj/item/naval_mine/magnetic
	name = "magnetic mine"
	desc = "A squat steel cylinder of explosive with a magnetic pistol in its nose. Lay it on open water from a deck or the shore; it waits for a steel hull and goes off under her keel. Wooden hulls do not set it off."
	icon_state = "magnetic"
	laid_type = /obj/structure/naval_mine/magnetic

/obj/item/naval_mine/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Click a tile of open water next to you with it in hand to lay it."))

// Why a mine cannot be laid here, or null.
/proc/naval_mine_lay_problem(turf/T)
	if (!T)
		return "There is nothing there."
	if (!istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/beach/water/ice))
		return "A mine can only be laid on open water."
	if (vessel_at(T) || craft_at(T))
		return "There is a hull there."
	for (var/atom/movable/M in T)
		if (istype(M, /obj/covers) || istype(M, /obj/structure/vehicleparts/frame))
			return "There is a hull there."
		if (istype(M, /obj/structure/naval_mine))
			return "There is already a mine there."
		if (M.density)
			return "[capitalize(M.name)] is in the way."
	return null

/obj/item/naval_mine/afterattack(atom/target, mob/user, proximity, params)
	if (!proximity || !ishuman(user))
		return ..()
	var/turf/T = get_turf(target)
	if (!T || T == get_turf(user))
		return ..()
	var/problem = naval_mine_lay_problem(T)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	user.visible_message(SPAN_NOTICE("[user] starts to lower \the [src] over the side."), SPAN_NOTICE("You start to lower \the [src] into the water."))
	if (!do_after(user, NAVAL_MINE_LAY_TIME, T) || QDELETED(src) || loc != user)
		return
	problem = naval_mine_lay_problem(T)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	user.drop_from_inventory(src)
	var/obj/structure/naval_mine/M = new laid_type(T)
	M.laid_by = user.real_name
	user.visible_message(SPAN_NOTICE("[user] lays \the [M]. It settles under the surface."), SPAN_NOTICE("You lay \the [M]. It settles under the surface and arms."))
	qdel(src)

// ---- The laid mine ----

/obj/structure/naval_mine
	name = "naval mine"
	desc = "A dark shape moored just under the water."
	icon = 'icons/obj/naval_mines.dmi'
	icon_state = "contact_laid"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	layer = TURF_LAYER + 0.1
	var/item_type = /obj/item/naval_mine
	var/magnetic = FALSE
	var/threshold = NAVAL_MINE_THRESHOLD
	var/reach = 0
	// The blast under the hull: explosion() ranges.
	var/list/blast = list(1, 2, 4)
	var/laid_by = ""
	var/tmp/fired = FALSE

/obj/structure/naval_mine/contact
	name = "contact mine"
	desc = "A horned steel sphere moored just under the water. Any hull that runs onto it sets it off."
	icon_state = "contact_laid"
	item_type = /obj/item/naval_mine

/obj/structure/naval_mine/magnetic
	name = "magnetic mine"
	desc = "A dark cylinder moored just under the water. It waits for the magnetic field of a steel hull."
	icon_state = "magnetic_laid"
	item_type = /obj/item/naval_mine/magnetic
	magnetic = TRUE
	reach = NAVAL_MINE_REACH
	blast = list(1, 3, 5)

/obj/structure/naval_mine/New()
	..()
	naval_mines += src

/obj/structure/naval_mine/Destroy()
	naval_mines -= src
	return ..()

/obj/structure/naval_mine/craft_left_behind()
	return TRUE

// TRUE when a craft with this felt signature, d tiles away (0 = over it),
// sets the mine off.
/obj/structure/naval_mine/proc/feels(signature, d)
	if (!magnetic)
		return d <= 0
	if (d > reach || signature <= 0)
		return FALSE
	var/r = max(1, d)
	return signature / (r * r) >= threshold

// Goes off: the blast is under the nearest hull tile of the craft that set it
// off (a magnetic mine breaks a keel from below), else where it lies.
/obj/structure/naval_mine/proc/detonate(datum/craft/C)
	if (fired)
		return
	fired = TRUE
	var/turf/hit = get_turf(src)
	if (C && C.body)
		var/best = INFINITY
		for (var/turf/T in C.body.cells())
			if (T.z != z)
				continue
			var/d = get_dist(T, src)
			if (d < best)
				best = d
				hit = T
	if (hit)
		hit.visible_message(SPAN_DANGER("A column of water bursts up with a roar[C ? " under \the [C.name]" : ""]!"))
		if (C)
			C.crew_message(SPAN_DANGER("A mine goes off under the hull!"))
			if (C.body)
				C.body.mine_damage(hit)
		blast_at(hit)
	qdel(src)

/obj/structure/naval_mine/proc/blast_at(turf/hit)
	explosion(hit, blast[1], blast[2], blast[3], blast[3] + 1)

// Caught in another blast: goes off a moment later, not inside that blast.
/obj/structure/naval_mine/ex_act(severity)
	if (!fired)
		addtimer(CALLBACK(src, PROC_REF(detonate), null), 1)

/obj/structure/naval_mine/bullet_act(obj/item/projectile/P, def_zone)
	if (!fired && P && P.damage > 0)
		detonate(null)
		return
	return ..()

/obj/structure/naval_mine/attackby(obj/item/W, mob/user)
	if (!ishuman(user) || !istype(W, /obj/item/weapon/wrench))
		user.visible_message(SPAN_DANGER("[user] hits \the [src]!"))
		detonate(null)
		return
	var/mob/living/human/H = user
	user.visible_message(SPAN_NOTICE("[user] starts to unscrew the firing gear of \the [src]."), SPAN_NOTICE("You start to unscrew the firing gear of \the [src]. Steady now."))
	if (!do_after(user, NAVAL_MINE_DISARM_TIME, src) || QDELETED(src))
		return
	if (prob(min(90 * H.getStatCoeff("dexterity"), 98)))
		user.visible_message(SPAN_NOTICE("[user] disarms \the [src] and hauls it out of the water."), SPAN_NOTICE("You disarm \the [src]."))
		var/obj/item/I = new item_type(get_turf(user))
		user.put_in_hands(I)
		qdel(src)
	else
		user.visible_message(SPAN_DANGER("Something clicks inside \the [src]!"))
		detonate(null)

// ---- What a mine does to each kind of body ----

// Damage a body takes beyond the explosion itself.
/datum/craft_body/proc/mine_damage(turf/hit)
	return

// Modular boats: the blast springs the frames by it, like an anti-tank mine
// under a tank, and a submarine takes leaks.
/datum/craft_body/axis/mine_damage(turf/hit)
	if (!axis)
		return
	for (var/obj/structure/vehicleparts/frame/F in range(1, hit))
		if (F.axis != axis)
			continue
		for (var/mob/M in axis.transporting)
			shake_camera(M, 6, 4)
		F.w_left[5] -= 25
		F.w_right[5] -= 25
		F.w_front[5] -= 25
		F.w_back[5] -= 25
		F.try_destroy()
		F.update_icon()
	var/obj/structure/vehicleparts/axis/ship/submarine/S = axis
	if (istype(S))
		S.spring_leaks(2)

// ---- The check ----

// The box a craft covers on its level: list(x1, y1, x2, y2, z), or null.
/datum/craft_body/proc/mine_box()
	var/list/B = null
	for (var/turf/T in cells())
		if (!B)
			B = list(T.x, T.y, T.x, T.y, T.z)
			continue
		if (T.z != B[5])
			continue
		B[1] = min(B[1], T.x)
		B[2] = min(B[2], T.y)
		B[3] = max(B[3], T.x)
		B[4] = max(B[4], T.y)
	return B

// A turf-built ship knows her box without walking every cell.
/datum/craft_body/template/mine_box()
	if (!placed())
		return null
	return list(vessel.ox, vessel.oy, vessel.ox + vessel.box_w() - 1, vessel.oy + vessel.box_h() - 1, vessel.base_z)

/datum/craft
	// The box she covered when she last looked for mines (runtime only).
	var/tmp/list/mine_box = null

// Called after every move. Looks for mines near the box she swept from her
// last place to this one and sets off any that feel her.
/datum/craft/proc/check_naval_mines()
	if (!naval_mines.len || !body || !body.placed())
		mine_box = null
		return 0
	var/list/now = body.mine_box()
	if (!now)
		mine_box = null
		return 0
	var/list/swept = now.Copy()
	if (mine_box && mine_box[5] == now[5])
		swept[1] = min(swept[1], mine_box[1])
		swept[2] = min(swept[2], mine_box[2])
		swept[3] = max(swept[3], mine_box[3])
		swept[4] = max(swept[4], mine_box[4])
	mine_box = now
	var/signature = -1
	. = 0
	for (var/obj/structure/naval_mine/M in naval_mines.Copy())
		if (QDELETED(M) || M.fired || M.z != swept[5])
			continue
		var/dx = max(swept[1] - M.x, 0, M.x - swept[3])
		var/dy = max(swept[2] - M.y, 0, M.y - swept[4])
		var/d = max(dx, dy)
		if (d > NAVAL_MINE_REACH)
			continue
		if (M.magnetic && signature < 0)
			signature = magnetic_signature()
		if (M.feels(signature, d))
			M.detonate(src)
			.++
			if (QDELETED(src) || !body || !body.placed())
				return
