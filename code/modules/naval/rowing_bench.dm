// ============================================================
// Rowing benches and the steering oar (docs/craft-core.md)
// ------------------------------------------------------------
// Galleys were rowed long before they were sailed far. A rowing bench set
// on the deck of a built hull is a drive once someone sits at it: each
// manned bench pushes CRAFT_OAR_THRUST tiles of hull and, unlike a sail,
// can make full ahead (ramming speed) when there are enough of them.
//
// The fuel is the rower. Every half minute she is rowed each rower spends
// OAR_STAMINA_PER_STEP stamina for each telegraph step: slow ahead can be
// kept up, half ahead tires a crew over a few minutes and full ahead in
// about two. A rower below OAR_MIN_STAMINA cannot pull, the bench stops
// pushing and she loses way until a fresh rower takes the seat.
//
// A voyage on the world chart (ship_voyage.dm) is paced only by drives
// that do not tire, so oars carry her across it no faster than sails.
//
// The steering oar is a tiller for the ages before the stern rudder: the
// same helm (built_hull.dm), cheaper, and taught with the benches.
// ============================================================

/obj/structure/bed/chair/wood/rowing_bench
	name = "rowing bench"
	desc = "A thwart with an oar shipped through a port beside it. Set it on the deck of a built hull and sit at it to row her."
	icon_state = "bleacher"
	applies_material_colour = FALSE

/obj/structure/bed/chair/wood/rowing_bench/examine(mob/user)
	..()
	var/mob/living/human/H = rower()
	if (H)
		to_chat(user, SPAN_NOTICE("[H] is at the oar[H.stats["stamina"][1] < OAR_MIN_STAMINA ? ", too spent to pull" : ""]."))
	else
		to_chat(user, SPAN_NOTICE("Nobody is at the oar. Drag yourself onto the bench to row."))

// Whoever sits at the oar and can pull it now, or null.
/obj/structure/bed/chair/wood/rowing_bench/proc/rower()
	var/mob/living/human/H = buckled_mob
	if (!istype(H) || H.buckled != src || H.loc != loc || H.stat != CONSCIOUS || H.restrained())
		return null
	return H

/obj/structure/bed/chair/wood/rowing_bench/post_buckle_mob(mob/living/M)
	..()
	if (M && M.buckled == src)
		to_chat(M, SPAN_NOTICE("You take the oar. When her tiller rings a speed, you row."))

/obj/structure/bed/chair/wood/rowing_bench/craft_drive()
	return isturf(loc) ? new /datum/craft_drive/fitted/oars(src) : null

/datum/craft_drive/fitted/oars
	kind = "oars"
	thrust = CRAFT_OAR_THRUST
	top_step = VESSEL_SPEED_FULL
	sustained = FALSE

/datum/craft_drive/fitted/oars/proc/rower()
	var/obj/structure/bed/chair/wood/rowing_bench/B = source
	return istype(B) ? B.rower() : null

/datum/craft_drive/fitted/oars/ready()
	if (!..())
		return FALSE
	var/mob/living/human/H = rower()
	return H && H.stats && H.stats["stamina"] && H.stats["stamina"][1] >= OAR_MIN_STAMINA

// The rower pays for the water she just covered, by the telegraph step.
/datum/craft_drive/fitted/oars/burn(share = 1)
	if (!ready())
		return 0
	var/mob/living/human/H = rower()
	var/steps = max(1, round(share * VESSEL_SPEED_FULL))
	var/list/stamina = H.stats["stamina"]
	stamina[1] = max(0, stamina[1] - OAR_STAMINA_PER_STEP * steps)
	if (stamina[1] < OAR_MIN_STAMINA)
		to_chat(H, SPAN_WARNING("Your arms are spent: you can pull no more until you have rested."))
	else if (stamina[1] < OAR_STAMINA_PER_STEP * steps)
		to_chat(H, SPAN_WARNING("You are tiring at the oar."))
	return 1

// ---- The steering oar ----

/obj/structure/hull_tiller/steering_oar
	name = "steering oar"
	desc = "A broad oar lashed over the quarter on its post. Set it on a floor built over water and commission the hull to steer her."
