// ============================================================
// Caulking (docs/hull-ledger.md)
// ------------------------------------------------------------
// A wooden boat or ship keeps the sea out with oakum driven into the seams
// between her planks and paid with pitch. Sailing works it loose: the ledger
// (hull_ledger.dm) wears her seams from sound to open over some hours under
// way, and the worse they are the faster she seeps.
//
// - Tarred oakum: use rope on an open container holding pitch from a tar
//   kiln. One coil and ten units of pitch make three twists.
// - Caulking: stand on her deck while she lies still and use the oakum on
//   one of her planks, with a chisel or a hammer in the other hand to drive
//   it home. One twist does three tiles of hull and takes four seconds; you
//   keep going until she is as tight as she can be made or the oakum is gone.
// - Afloat on deep water only the seams you can reach are done: she comes
//   back to sound and no better. Lying in the shallows she can be heeled and
//   caulked right down to tight, where she seeps half as fast.
//
// Small craft and plated hulls have no seams to caulk.
// ============================================================

// Units of pitch one coil of rope soaks up, and the twists it makes.
#define OAKUM_PITCH 10
#define OAKUM_PER_ROPE 3
// Tiles of hull one twist caulks, and the deciseconds it takes.
#define CAULK_TILES_PER_TWIST 3
#define CAULK_TIME 40

/obj/item/stack/tarred_oakum
	name = "tarred oakum"
	desc = "Old rope picked apart and soaked in pitch. Use it on a plank of a wooden hull, with a chisel or a hammer in your other hand, to caulk her seams."
	icon = 'icons/obj/hull_gear.dmi'
	icon_state = "tarred_oakum"
	singular_name = "twist of tarred oakum"
	max_amount = 30
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 2

// Rope dipped in pitch is picked into oakum. TRUE when handled here.
/proc/oakum_dip(obj/item/stack/material/rope/R, obj/item/weapon/reagent_containers/C, mob/user)
	if (!istype(R) || !istype(C) || !C.reagents || !C.is_open_container() || !C.reagents.has_reagent("pitch"))
		return FALSE
	if (C.reagents.get_reagent_amount("pitch") < OAKUM_PITCH)
		to_chat(user, SPAN_WARNING("A coil of rope soaks up [OAKUM_PITCH] units of pitch. There is not that much in \the [C]."))
		return TRUE
	if (!R.use(1))
		return TRUE
	C.reagents.remove_reagent("pitch", OAKUM_PITCH)
	var/obj/item/stack/tarred_oakum/O = new(get_turf(user), OAKUM_PER_ROPE)
	var/mob/living/human/H = user
	if (istype(H) && H.species)
		H.put_in_any_hand_if_possible(O)
	to_chat(user, SPAN_NOTICE("You pick a coil of rope apart, soak it in the pitch and twist it into [OAKUM_PER_ROPE] twists of tarred oakum."))
	return TRUE

/obj/item/stack/material/rope/afterattack(atom/target, mob/user, proximity_flag, params)
	if (proximity_flag && istype(target, /obj/item/weapon/reagent_containers) && oakum_dip(src, target, user))
		return TRUE
	return ..()

// How tight caulking can make her where she lies: sound afloat on deep water,
// tight in the shallows or at a berth (berth.dm).
/datum/hull_ledger/proc/caulk_floor()
	return bottom_reachable() ? 0 : HULL_SEAMS_FAIR

// Twists of oakum it takes to caulk her as tight as she can be made here.
/datum/hull_ledger/proc/caulk_wanted()
	if (!has_seams() || seams <= caulk_floor() + 0.001)
		return 0
	return CEILING((seams - caulk_floor()) * seep_tiles / CAULK_TILES_PER_TWIST, 1)

// Why H cannot caulk the hull under plank P with W, or null.
/proc/hull_caulk_refusal(mob/living/human/H, obj/item/stack/tarred_oakum/W, obj/covers/P)
	if (!istype(H) || !istype(W) || !P)
		return "nothing to caulk with"
	var/turf/plank = get_turf(P)
	var/datum/craft/C = plank ? craft_at(plank) : null
	if (!C || !C.ledger)
		return "that is not a hull afloat"
	var/datum/hull_ledger/L = C.ledger
	if (!C.body.contains(get_turf(H)))
		return "stand on her deck to caulk her"
	if (H.stat || H.lying || H.restrained())
		return "you are in no state to caulk"
	if (L.hull_class() == HULL_CLASS_SMALL)
		return "a hull this small needs no caulking"
	if (!L.has_seams())
		return "her plating has no seams to caulk"
	if (!is_tool(H.get_inactive_hand(), TOOL_CHISEL) && !is_tool(H.get_inactive_hand(), TOOL_HAMMER))
		return "you need a chisel or a hammer in your other hand to drive it home"
	if (L.under_way())
		return "she must lie still"
	if (L.depth() >= HULL_DEPTH_AWASH)
		return "her seams are under water: bail her first"
	if (L.seams <= L.caulk_floor() + 0.001)
		return L.seams <= 0.001 ? "her seams are tight" : "her seams are as tight as they can be made afloat on deep water: lay her in the shallows or bring her to a berth to finish the job"
	return null

// One twist driven home. Returns how much tighter her seams are.
/datum/hull_ledger/proc/caulk_twist()
	var/was = seams
	seams = max(caulk_floor(), seams - CAULK_TILES_PER_TWIST / max(1, seep_tiles))
	seams_told = seams >= HULL_SEAMS_OPEN ? 2 : (seams >= HULL_SEAMS_WORKING ? 1 : 0)
	return was - seams

// H caulks until she is tight, the oakum is gone or they stop. Returns the
// twists used.
/proc/hull_caulk(mob/living/human/H, obj/item/stack/tarred_oakum/W, obj/covers/P)
	. = 0
	var/why = hull_caulk_refusal(H, W, P)
	if (why)
		to_chat(H, SPAN_WARNING("You cannot caulk her here: [why]."))
		return
	var/datum/craft/C = craft_at(get_turf(P))
	var/datum/hull_ledger/L = C.ledger
	if (L.caulkers[H])
		return
	L.caulkers[H] = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts caulking the seams of the [C.name]."), SPAN_NOTICE("You start driving oakum into the seams of the [C.name]."))
	while (TRUE)
		playsound(get_turf(H), 'sound/items/Screwdriver.ogg', 40, TRUE)
		if (!do_after(H, CAULK_TIME, P))
			break
		if (QDELETED(L) || QDELETED(W) || QDELETED(P) || H.get_active_hand() != W || hull_caulk_refusal(H, W, P))
			break
		if (!W.use(1))
			break
		L.caulk_twist()
		.++
	if (!QDELETED(L))
		L.caulkers -= H
		if (.)
			var/more = L.seams > L.caulk_floor() + 0.001
			to_chat(H, SPAN_NOTICE("You drive home [.] twist\s of oakum. Her seams are [L.seam_name()][more ? ", with more to do" : (L.seams > 0.001 ? ": as tight as they can be made out here" : "")]."))

/datum/hull_ledger
	// Who is caulking now: mob = TRUE.
	var/tmp/list/caulkers = list()

// Tarred oakum used on a plank of a hull caulks her. Anything else behaves
// as it always did.
/obj/covers/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/tarred_oakum) && ishuman(user))
		var/turf/plank = get_turf(src)
		var/datum/craft/C = plank ? craft_at(plank) : null
		if (C && C.ledger)
			hull_caulk(user, W, src)
			return TRUE
	return ..()

#undef OAKUM_PITCH
#undef OAKUM_PER_ROPE
#undef CAULK_TIME
