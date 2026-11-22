// ============================================================
// Bilge pumps (docs/hull-ledger.md)
// ------------------------------------------------------------
// The pumps that keep a cellar dry (code/modules/1713/flood_pumps.dm) pump a
// hull's bilge when they stand on her deck: nothing new to build or learn.
//
// - Lever pump: worked by hand. Each stroke of three seconds lifts two
//   bucketfuls over the side, twice what a bucket does, and one hand at the
//   pump keeps ahead of one hole.
// - Steam mine pump: 80 bucketfuls a minute while its fire burns.
// - Sump pump: 40 bucketfuls a minute on cable power or its battery. Its
//   float switch runs it only while there is water in the bilge.
//
// The powered pumps are stepped with the ledger, every half minute while the
// hull is awake, and burn fuel and battery only then. Ashore and in a cellar
// the pumps behave as they always did.
// ============================================================

#define BILGE_LEVER_STROKE 2
#define BILGE_LEVER_TIME 30
#define BILGE_STEAM_PER_MINUTE 80
#define BILGE_SUMP_PER_MINUTE 40
#define BILGE_SUMP_CHARGE 5

// The ledger of the hull whose deck holds T, on either of her decks.
/proc/hull_ledger_at(turf/T)
	if (!T)
		return null
	for (var/datum/hull_ledger/L in hull_ledgers)
		if (L.deck_holds(T))
			return L
	return null

// The pumps standing on her decks.
/datum/hull_ledger/proc/pumps()
	. = list()
	for (var/obj/structure/cellar_pump/P in cellar_pumps)
		if (!QDELETED(P) && deck_holds(get_turf(P)))
			. += P

// One step of her powered pumps. Returns the bucketfuls they lifted.
/datum/hull_ledger/proc/pump_bilge(seconds)
	. = 0
	if (!cellar_pumps.len)
		return
	// Each lifts the water of the compartment it stands in (hull_compartments.dm).
	for (var/obj/structure/cellar_pump/P in pumps())
		var/lift = P.bilge_step(src, seconds)
		if (lift > 0)
			. += remove_water(lift, get_turf(P))

// What this pump can lift in a step of seconds aboard a hull, having burned
// what that costs it.
/obj/structure/cellar_pump/proc/bilge_step(datum/hull_ledger/L, seconds)
	return 0

/obj/structure/cellar_pump/steam/bilge_step(datum/hull_ledger/L, seconds)
	if (!on || fuel <= 0)
		set_running(FALSE)
		return 0
	fuel = max(0, fuel - seconds / 60)
	if (fuel <= 0)
		on = FALSE
		visible_message(SPAN_WARNING("\The [src]'s fire burns out and the beam stops."))
	set_running(on && fuel > 0)
	return BILGE_STEAM_PER_MINUTE * seconds / 60

/obj/structure/cellar_pump/sump/bilge_step(datum/hull_ledger/L, seconds)
	if (!on || !isturf(loc))
		release_power()
		set_running(FALSE)
		return 0
	if (L.water_at(get_turf(src)) < 1)
		// Idle on the float switch: draws only to keep the battery up.
		if (battery < initial(battery) && draw_cable_power())
			battery = min(initial(battery), battery + BILGE_SUMP_CHARGE * seconds / 60)
		else
			release_power()
		set_running(FALSE)
		return 0
	if (draw_cable_power())
		battery = min(initial(battery), battery + BILGE_SUMP_CHARGE * seconds / 60)
		set_running(TRUE)
		return BILGE_SUMP_PER_MINUTE * seconds / 60
	if (battery > 0)
		battery = max(0, battery - seconds / 60)
		set_running(TRUE)
		return BILGE_SUMP_PER_MINUTE * seconds / 60
	set_running(FALSE)
	return 0

// ---- The lever pump aboard ----

// Why H cannot work this pump on the hull of L, or null.
/obj/structure/cellar_pump/lever/proc/bilge_refusal(mob/living/H, datum/hull_ledger/L)
	if (!istype(H) || H.stat || H.lying || H.restrained())
		return "you are in no state to pump"
	if (get_dist(H, src) > 1)
		return "you are too far from it"
	if (QDELETED(L) || !L.deck_holds(get_turf(src)))
		return "it is not aboard a hull"
	if (L.water_at(get_turf(src)) < 0.01)
		return L.water < 0.01 ? "her bilge is dry" : "its compartment is dry"
	return null

// H works the handle until the bilge is dry or they stop. Returns the
// bucketfuls that went over the side.
/obj/structure/cellar_pump/lever/proc/bilge_pump(mob/living/H, datum/hull_ledger/L)
	. = 0
	var/why = bilge_refusal(H, L)
	if (why)
		to_chat(H, SPAN_WARNING("You cannot pump her out: [why]."))
		return
	if (busy)
		to_chat(H, SPAN_WARNING("Someone is already working \the [src]."))
		return
	busy = TRUE
	update_icon()
	H.visible_message(SPAN_NOTICE("[H] starts working the handle of \the [src]."), SPAN_NOTICE("You start pumping out the bilge of the [L.craft.name]."))
	while (TRUE)
		var/off_x = H.x - x
		var/off_y = H.y - y
		var/began = world.time
		if (!do_after(H, BILGE_LEVER_TIME, src))
			// A step of the hull carries pump and hand together and breaks
			// the wait: that stroke starts again. Anything else stops them.
			if (!QDELETED(src) && !QDELETED(L) && !QDELETED(H) && L.under_way() && world.time > began && H.x - x == off_x && H.y - y == off_y && !bilge_refusal(H, L))
				continue
			break
		if (QDELETED(src) || bilge_refusal(H, L))
			break
		. += L.remove_water(BILGE_LEVER_STROKE, get_turf(src))
		playsound(get_turf(src), 'sound/effects/slosh.ogg', 25, TRUE)
	if (QDELETED(src))
		return
	busy = FALSE
	update_icon()
	if (. && !QDELETED(L))
		to_chat(H, SPAN_NOTICE("You pump [round(., 0.1)] bucketful\s over the side. [L.water_at(get_turf(src)) < 0.01 ? "The pump sucks air: [L.water < 0.01 ? "her bilge" : "its compartment"] is dry." : "Her bilge is [hull_depth_name(L.depth())]."]"))

/obj/structure/cellar_pump/lever/attack_hand(mob/living/user)
	var/datum/hull_ledger/L = istype(user) ? hull_ledger_at(get_turf(src)) : null
	if (L)
		bilge_pump(user, L)
		return
	return ..()

// ---- What a look tells ----

/obj/structure/cellar_pump/examine(mob/user, distance = -1)
	. = ..()
	if (. && get_dist(src, user) <= 2)
		var/datum/hull_ledger/L = hull_ledger_at(get_turf(src))
		if (L)
			to_chat(user, SPAN_NOTICE("Aboard the [L.craft.name] it pumps her bilge, which is [hull_depth_name(L.depth())]."))

// The tiller counts her pumps.
/datum/hull_ledger/proc/pumps_text()
	var/list/aboard = pumps()
	if (!aboard.len)
		return ""
	var/working = 0
	for (var/obj/structure/cellar_pump/P in aboard)
		if (P.cellar_pumping())
			working++
	return " [aboard.len] pump\s stand[aboard.len == 1 ? "s" : ""] on her deck[working ? ", [working] of them working" : ""]."

#undef BILGE_LEVER_STROKE
#undef BILGE_LEVER_TIME
#undef BILGE_STEAM_PER_MINUTE
#undef BILGE_SUMP_PER_MINUTE
#undef BILGE_SUMP_CHARGE
