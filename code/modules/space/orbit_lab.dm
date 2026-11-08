// ============================================================
// Zero-g manufacturing (orbital stations, stage E)
// ------------------------------------------------------------
// A microgravity lab makes goods that only orbit can make, worth flying home
// in a freighter (orbit_freight.dm). It works only in orbit, inside a sealed
// habitat module, while cabled to power, and only while the world has
// players. Load its feedstock, pick a programme, and it turns out one batch
// at a time beside itself:
//
// - Semiconductor crystals: glass and a little copper grow into electronics,
//   with no crafting skill and no iron.
// - Protein crystals: plain bruise packs become advanced bruise packs.
// - Gem crystals: coal is pressed and grown into rough diamonds.
//
// Feedstock and progress are plain saved numbers; nothing here is a
// world.time stamp, and a late tick never replays a backlog.
// ============================================================

#define ORBIT_LAB_BATCH_TICKS 30
#define ORBIT_LAB_FEED_MAX 200

// programme = list(name, list(feed = amount per batch), output path, output amount)
var/global/list/orbit_lab_programmes = list(
	"semiconductors" = list("semiconductor crystals", list("glass" = 6, "copper" = 1), /obj/item/stack/material/electronics, 3),
	"proteins" = list("protein crystals", list("bruise_pack" = 5), /obj/item/stack/medical/advanced/bruise_pack, 5),
	"gems" = list("gem crystals", list("coal" = 20), /obj/item/stack/ore/diamond, 1))

// Feedstock kinds the lab takes, by exact stack type.
var/global/list/orbit_lab_feeds = list(
	"glass" = /obj/item/stack/material/glass,
	"copper" = /obj/item/stack/material/copper,
	"bruise_pack" = /obj/item/stack/medical/bruise_pack,
	"coal" = /obj/item/stack/ore/coal)

/obj/structure/zero_g_lab
	name = "microgravity lab"
	desc = "Furnaces and growth cells that only work in free fall. In a sealed module in orbit, cabled to power, it grows semiconductor, protein and gem crystals from what you load into it."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "uranium_refinery"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	powerneeded = 20
	// Feedstock loaded, as kind = amount.
	var/list/feed = list()
	var/programme = "semiconductors"
	// Process ticks towards the current batch.
	var/progress = 0

/obj/structure/zero_g_lab/New()
	..()
	processing_objects |= src

/obj/structure/zero_g_lab/Destroy()
	processing_objects -= src
	return ..()

/obj/structure/zero_g_lab/examine(mob/user)
	..()
	var/list/P = orbit_lab_programmes[programme]
	var/list/have = list()
	for (var/kind in orbit_lab_feeds)
		have += "[kind_name(kind)] [feed[kind] || 0]"
	to_chat(user, SPAN_NOTICE("Programme: [P ? P[1] : "none"]. Loaded: [jointext(have, ", ")]."))
	var/reason = work_refusal()
	if (reason)
		to_chat(user, SPAN_WARNING(reason))

/obj/structure/zero_g_lab/proc/kind_name(kind)
	return kind == "bruise_pack" ? "bruise packs" : kind

// Null when the lab can work here, otherwise why not.
/obj/structure/zero_g_lab/proc/work_refusal()
	if (!orbit_world())
		return "It needs free fall: it only works in orbit."
	var/turf/floor/habitat/F = get_turf(src)
	var/obj/structure/habitat_core/C = istype(F) ? F.habitat_core() : null
	if (!C)
		return "It must stand inside a habitat module."
	if (C.breaches())
		return "The module is breached. Seal it first."
	if (!powersource)
		return "Run a cable to it to power it."
	return null

// TRUE when the loaded feedstock covers one batch of the programme.
/obj/structure/zero_g_lab/proc/fed()
	var/list/P = orbit_lab_programmes[programme]
	if (!P)
		return FALSE
	var/list/needs = P[2]
	for (var/kind in needs)
		if ((feed[kind] || 0) < needs[kind])
			return FALSE
	return TRUE

// Gives the lab's power back to the grid while it has nothing to do.
/obj/structure/zero_g_lab/proc/release_power()
	if (powersource && powersource.power_consumers[src])
		powersource.update_power(0, 1, src)

// One step of work. Returns TRUE when a batch came out.
/obj/structure/zero_g_lab/proc/step_work()
	if (work_refusal() || !fed())
		release_power()
		return FALSE
	if (!draw_cable_power())
		return FALSE
	progress++
	if (progress < ORBIT_LAB_BATCH_TICKS)
		return FALSE
	progress = 0
	return finish_batch()

// Uses one batch of feedstock and puts out the product. Returns TRUE if it did.
/obj/structure/zero_g_lab/proc/finish_batch()
	var/list/P = orbit_lab_programmes[programme]
	if (!P || !fed())
		return FALSE
	var/list/needs = P[2]
	for (var/kind in needs)
		feed[kind] -= needs[kind]
		if (feed[kind] <= 0)
			feed -= kind
	var/path = P[3]
	new path(get_turf(src), P[4])
	visible_message(SPAN_NOTICE("\The [src] chimes and slides out a tray of [P[1]]."))
	return TRUE

/obj/structure/zero_g_lab/process()
	if (!clients.len)
		release_power()
		return
	step_work()

// Takes feedstock from a stack. Returns how much it took.
/obj/structure/zero_g_lab/proc/load(obj/item/stack/S)
	if (!istype(S))
		return 0
	var/kind = null
	for (var/k in orbit_lab_feeds)
		if (S.type == orbit_lab_feeds[k])
			kind = k
			break
	if (!kind)
		return 0
	var/take = min(S.amount, ORBIT_LAB_FEED_MAX - (feed[kind] || 0))
	if (take <= 0)
		return 0
	feed[kind] = (feed[kind] || 0) + take
	S.use(take)
	return take

/obj/structure/zero_g_lab/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			to_chat(user, SPAN_WARNING("It is already cabled."))
			return
		connect_cable(user, W)
		return
	if (istype(W, /obj/item/stack))
		var/took = load(W)
		if (!took)
			to_chat(user, SPAN_WARNING("\The [src] takes only glass, copper, plain bruise packs and coal, up to [ORBIT_LAB_FEED_MAX] of each."))
			return
		to_chat(user, SPAN_NOTICE("You load [took] into \the [src]."))
		return
	return ..()

/obj/structure/zero_g_lab/attack_hand(mob/user)
	if (!ishuman(user))
		return
	var/list/choices = list()
	for (var/key in orbit_lab_programmes)
		var/list/P = orbit_lab_programmes[key]
		var/list/needs = P[2]
		var/list/parts = list()
		for (var/kind in needs)
			parts += "[needs[kind]] [kind_name(kind)]"
		var/obj/out = P[3]
		choices["[capitalize(P[1])]: [jointext(parts, " + ")] -> [P[4]] [initial(out.name)]"] = key
	var/pick = input(user, "Grow which crystals? Each batch takes about a minute of power.", "Microgravity lab") as null|anything in choices
	if (!pick || QDELETED(src) || !in_range(src, user))
		return
	if (choices[pick] != programme)
		programme = choices[pick]
		progress = 0
	to_chat(user, SPAN_NOTICE("You set \the [src] to grow [orbit_lab_programmes[programme][1]]."))

#undef ORBIT_LAB_BATCH_TICKS
#undef ORBIT_LAB_FEED_MAX
