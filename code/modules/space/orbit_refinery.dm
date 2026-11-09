// ============================================================
// Orbital refinery (orbital stations, stage E)
// ------------------------------------------------------------
// An electric furnace that only works in free fall, so asteroid ore mined
// beside a station (orbit_asteroids.dm) need not fly home to be smelted.
// Like the microgravity lab (orbit_lab.dm) it works only in orbit, inside a
// sealed habitat module, while cabled to power and while the world has
// players. It takes no fuel:
//
// - Iron ore: two lumps make one steel sheet, for hull plates and trusses.
// - Copper, silver and gold ore: one lump makes one ingot.
//
// It smelts one batch at a time beside itself, and conveyor belts and arms
// can feed it and take from it. Water ice goes in an ice melter or an
// electrolyser, as on the ground. Ore loaded and progress are plain saved
// numbers; nothing here is a world.time stamp, and a late tick never replays
// a backlog.
// ============================================================

#define ORBIT_REFINERY_BATCH_TICKS 10
#define ORBIT_REFINERY_BATCH 4
#define ORBIT_REFINERY_ORE_MAX 100

// kind = list(ore type, output type, ore per output)
var/global/list/orbit_refinery_ores = list(
	"iron" = list(/obj/item/stack/ore/iron, /obj/item/stack/material/steel, 2),
	"copper" = list(/obj/item/stack/ore/copper, /obj/item/stack/material/copper, 1),
	"silver" = list(/obj/item/stack/ore/silver, /obj/item/stack/material/silver, 1),
	"gold" = list(/obj/item/stack/ore/gold, /obj/item/stack/material/gold, 1))

/obj/structure/zero_g_lab/refinery
	name = "orbital refinery"
	desc = "An electric furnace that only works in free fall. In a sealed module in orbit, cabled to power, it smelts asteroid iron into steel, and copper, silver and gold ore into ingots, with no fuel."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "uranium_refinery"
	color = "#ffd8b0"
	powerneeded = 30
	programme = null

/obj/structure/zero_g_lab/refinery/status_line()
	var/list/have = list()
	for (var/kind in orbit_refinery_ores)
		have += "[kind] [feed[kind] || 0]"
	return "Ore loaded: [jointext(have, ", ")]."

/obj/structure/zero_g_lab/refinery/batch_ticks()
	return ORBIT_REFINERY_BATCH_TICKS

// The kind of ore it smelts next, or null when it holds none it can use.
/obj/structure/zero_g_lab/refinery/proc/next_kind()
	for (var/kind in orbit_refinery_ores)
		var/list/info = orbit_refinery_ores[kind]
		if ((feed[kind] || 0) >= info[3])
			return kind
	return null

/obj/structure/zero_g_lab/refinery/fed()
	return next_kind() != null

// Smelts up to one batch of the next ore. Returns TRUE if metal came out.
/obj/structure/zero_g_lab/refinery/finish_batch()
	var/kind = next_kind()
	if (!kind)
		return FALSE
	var/list/info = orbit_refinery_ores[kind]
	var/per = info[3]
	var/made = min(ORBIT_REFINERY_BATCH, round(feed[kind] / per))
	feed[kind] -= made * per
	if (feed[kind] <= 0)
		feed -= kind
	var/path = info[2]
	var/obj/item/stack/out = new path(get_turf(src), made)
	visible_message(SPAN_NOTICE("\The [src] hisses and drops [made] [out.singular_name || out.name]\s."))
	return TRUE

// The ore kind of stack S, or null.
/obj/structure/zero_g_lab/refinery/proc/ore_kind(obj/item/stack/S)
	if (!istype(S))
		return null
	for (var/kind in orbit_refinery_ores)
		var/list/info = orbit_refinery_ores[kind]
		if (S.type == info[1])
			return kind
	return null

/obj/structure/zero_g_lab/refinery/load(obj/item/stack/S)
	var/kind = ore_kind(S)
	if (!kind)
		return 0
	var/take = min(S.amount, ORBIT_REFINERY_ORE_MAX - (feed[kind] || 0))
	if (take <= 0)
		return 0
	feed[kind] = (feed[kind] || 0) + take
	S.use(take)
	return take

/obj/structure/zero_g_lab/refinery/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/ore/ice))
		to_chat(user, SPAN_WARNING("\The [src] takes no ice. Melt it in an ice melter or an electrolyser."))
		return
	if (istype(W, /obj/item/stack) && !istype(W, /obj/item/stack/cable_coil))
		var/took = load(W)
		if (!took)
			to_chat(user, SPAN_WARNING("\The [src] takes only iron, copper, silver and gold ore, up to [ORBIT_REFINERY_ORE_MAX] of each."))
			return
		to_chat(user, SPAN_NOTICE("You load [took] lump\s of ore into \the [src]."))
		return
	return ..()

/obj/structure/zero_g_lab/refinery/attack_hand(mob/user)
	if (!ishuman(user))
		return
	to_chat(user, SPAN_NOTICE(status_line()))
	var/reason = work_refusal()
	if (reason)
		to_chat(user, SPAN_WARNING(reason))

// Belts and arms (factory_ports.dm) feed it ore and take its metal.
/obj/structure/zero_g_lab/refinery/factory_accepts(obj/item/I, from_dir = 0)
	if (!factory_movable_item(I))
		return 0
	var/kind = ore_kind(I)
	if (!kind)
		return 0
	var/obj/item/stack/S = I
	return max(0, min(S.amount, ORBIT_REFINERY_ORE_MAX - (feed[kind] || 0)))

/obj/structure/zero_g_lab/refinery/factory_insert(obj/item/I, from_dir = 0)
	if (factory_accepts(I, from_dir) <= 0)
		return 0
	return load(I)

/obj/structure/zero_g_lab/refinery/factory_offer(to_dir = 0, filter_type = null)
	var/list/types = list()
	for (var/kind in orbit_refinery_ores)
		var/list/info = orbit_refinery_ores[kind]
		types += info[2]
	return factory_offer_tile_output(src, types, filter_type)

/obj/structure/zero_g_lab/refinery/factory_take(obj/item/I, atom/destination)
	return factory_take_tile_output(src, I, destination)

#undef ORBIT_REFINERY_BATCH_TICKS
#undef ORBIT_REFINERY_BATCH
#undef ORBIT_REFINERY_ORE_MAX
