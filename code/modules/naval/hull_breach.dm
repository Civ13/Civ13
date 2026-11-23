// ============================================================
// Breaches in the hold (docs/hull-ledger.md "Breaches below the waterline")
// ------------------------------------------------------------
// Damage control below decks. A floor of a ship's hold that is blown out or
// cut away does not just vanish: the tile stays part of her hold as a breach,
// open to the sea, and counts as a hole in her hull like a hole in her deck
// (hull_ledger.dm), letting the water in until it is shut.
//
// Shutting a breach: stand beside it in her hold with steel in one hand and a
// welding tool in the other and use the steel on it. It takes
// HULL_BREACH_STEEL sheets and HULL_BREACH_TIME, and the hold floor is
// whole again.
//
// The breach keeps the ground its hold floor hollowed out (hold_origin), so
// her hold sails on with it and gives the ground back as she leaves. A blast
// cannot open a breach any wider.
// ============================================================

#define HULL_BREACH_STEEL 2
#define HULL_BREACH_TIME 50

/obj/covers/steelplating/hold/breach
	name = "hold breach"
	desc = "A hole torn in a ship's hold below the waterline, with the sea pouring in. Weld steel over it to shut it."
	icon_state = "platingdmg2"

// It is already as open as it gets.
/obj/covers/steelplating/hold/breach/ex_act(severity)
	return

/obj/covers/steelplating/hold/breach/examine(mob/user)
	..()
	to_chat(user, SPAN_WARNING("Use [HULL_BREACH_STEEL] steel on it, with a welding tool in your other hand, to shut it."))

/obj/covers/steelplating/hold/breach/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/material/steel) && ishuman(user))
		hull_breach_weld(user, W, src)
		return TRUE
	return ..()

// The craft whose hold holds C's tile, while she is afloat and not going
// down, or null.
/proc/hull_breach_craft(obj/covers/C)
	var/turf/T = get_turf(C)
	if (!istype(T, /turf/floor/plating/ship_hold))
		return null
	var/datum/craft/S = craft_holding(T)
	if (!S || !S.ledger || S.ledger.sinking || !istype(S.body, /datum/craft_body/built))
		return null
	return S

// A hold floor is going: leave a breach in its place.
/proc/hull_hold_breach(obj/covers/C)
	if (!C || istype(C, /obj/covers/steelplating/hold/breach) || C.wall)
		return null
	var/datum/craft/S = hull_breach_craft(C)
	if (!S)
		return null
	var/turf/T = get_turf(C)
	var/obj/covers/steelplating/hold/breach/B = new(T)
	B.hold_origin = C.hold_origin
	B.hold_sea_zone = C.hold_sea_zone
	S.ledger.holes++
	S.crew_message(SPAN_DANGER("<b>The [S.name] is holed below the waterline!</b> Her hold is breached at [T.x], [T.y]. Weld steel over it to shut it."))
	return B

// Open breaches in her hold.
/datum/hull_ledger/proc/hold_breaches()
	. = 0
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!istype(B) || !B.placed())
		return
	for (var/turf/L in B.lower_cells())
		if (locate(/obj/covers/steelplating/hold/breach) in L)
			.++

// Why H cannot weld the breach B shut with W, or null.
/proc/hull_breach_refusal(mob/living/human/H, obj/item/stack/material/steel/W, obj/covers/steelplating/hold/breach/B)
	if (!istype(H) || !istype(W) || QDELETED(B))
		return "nothing to weld with"
	if (!hull_breach_craft(B))
		return "it is not in the hold of a ship afloat"
	if (get_dist(H, B) > 1 || H.z != B.z)
		return "stand beside it"
	if (H.stat || H.lying || H.restrained())
		return "you are in no state to weld"
	if (!is_tool(H.get_inactive_hand(), TOOL_WELDER))
		return "you need a welding tool in your other hand"
	if (W.amount < HULL_BREACH_STEEL)
		return "it takes [HULL_BREACH_STEEL] steel"
	return null

/proc/hull_breach_weld(mob/living/human/H, obj/item/stack/material/steel/W, obj/covers/steelplating/hold/breach/B)
	var/why = hull_breach_refusal(H, W, B)
	if (why)
		to_chat(H, SPAN_WARNING("You cannot shut the breach: [why]."))
		return null
	H.visible_message(SPAN_NOTICE("[H] starts welding steel over the breach."), SPAN_NOTICE("You start welding steel over the breach."))
	if (!do_after(H, HULL_BREACH_TIME, B) || hull_breach_refusal(H, W, B))
		return null
	return hull_breach_shut(B, W)

// Shuts B with steel from W: a whole hold floor again. Returns the floor.
/proc/hull_breach_shut(obj/covers/steelplating/hold/breach/B, obj/item/stack/material/steel/W = null)
	var/datum/craft/S = hull_breach_craft(B)
	if (!S)
		return null
	if (W)
		W.use(HULL_BREACH_STEEL)
	var/turf/T = get_turf(B)
	var/obj/covers/steelplating/hold/F = new(T)
	F.hold_origin = B.hold_origin
	F.hold_sea_zone = B.hold_sea_zone
	qdel(B)
	S.ledger.holes = max(0, S.ledger.holes - 1)
	S.crew_message(SPAN_NOTICE("The breach in her hold at [T.x], [T.y] is welded shut. [S.ledger.holes ? "[S.ledger.holes] more hole\s let[S.ledger.holes == 1 ? "s" : ""] the sea in." : "No hole is left open."]"))
	return F

#undef HULL_BREACH_STEEL
#undef HULL_BREACH_TIME
