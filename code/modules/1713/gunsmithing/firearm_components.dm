// Modular firearm components (issue #4443 phase 2 pilot: the AK family).
// Contract: docs/firearm-component-contract.md. Installed parts are data on the
// gun (component id + condition per slot), so a gun costs no extra objects
// until a part is removed. Removed parts are /obj/item/weapon/gun_component
// items that keep their id and condition. Work reuses the gun configuration
// guards (gun_work_busy, configuration_actor, configuration_unloaded, waits).

#define FIREARM_SLOT_ACTION "action"
#define FIREARM_SLOT_BARREL "barrel"
#define FIREARM_SLOT_FEED "feed"
#define FIREARM_SLOT_FURNITURE "furniture"
// Shots a barrel lasts from full condition.
#define FIREARM_BARREL_LIFE 1000

/datum/firearm_component
	var/id
	var/family
	var/slot
	var/name
	var/desc
	var/icon_state
	var/caliber = null        // barrel and feed parts
	var/list/good_mags = null // feed parts: magazines the gun accepts
	var/ergonomics = 1        // furniture handling factor

/datum/firearm_component/New(list/data)
	..()
	for (var/key in data)
		vars[key] = data[key]

var/global/list/firearm_component_defs = null
var/global/list/firearm_presets = null
// Slots a gun needs before it can fire; furniture only changes handling.
var/global/list/firearm_required_slots = list(FIREARM_SLOT_ACTION, FIREARM_SLOT_BARREL, FIREARM_SLOT_FEED)
var/global/list/firearm_slot_order = list(FIREARM_SLOT_ACTION, FIREARM_SLOT_BARREL, FIREARM_SLOT_FEED, FIREARM_SLOT_FURNITURE)
// Field strip by hand; the rest needs a firearm bench.
var/global/list/firearm_field_slots = list(FIREARM_SLOT_FEED, FIREARM_SLOT_FURNITURE)

/proc/firearm_registry_init()
	if (firearm_component_defs)
		return
	firearm_component_defs = list()
	var/list/ak47_mags = list(/obj/item/ammo_magazine/rpk47, /obj/item/ammo_magazine/rpk47/drum, /obj/item/ammo_magazine/ak47, /obj/item/ammo_magazine/ak47/drum, /obj/item/ammo_magazine/ak47/makeshift)
	var/list/ak74_mags = list(/obj/item/ammo_magazine/rpk74, /obj/item/ammo_magazine/rpk74/drum, /obj/item/ammo_magazine/ak74, /obj/item/ammo_magazine/ak47/drum, /obj/item/ammo_magazine/ak74/ak74m)
	for (var/list/data in list(
		list("id" = "ak/action", "family" = "ak", "slot" = FIREARM_SLOT_ACTION, "name" = "AK bolt carrier group",
			"desc" = "The bolt and carrier of an AK-pattern rifle. Fits any AK receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "ak/barrel/762x39", "family" = "ak", "slot" = FIREARM_SLOT_BARREL, "name" = "AK barrel (7.62x39mm)",
			"desc" = "A 7.62x39mm barrel for an AK-pattern rifle. Pair it with a 7.62x39mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a762x39"),
		list("id" = "ak/barrel/545x39", "family" = "ak", "slot" = FIREARM_SLOT_BARREL, "name" = "AK barrel (5.45x39mm)",
			"desc" = "A 5.45x39mm barrel for an AK-pattern rifle. Pair it with a 5.45x39mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a545x39"),
		list("id" = "ak/feed/762x39", "family" = "ak", "slot" = FIREARM_SLOT_FEED, "name" = "AK magazine well (7.62x39mm)",
			"desc" = "Takes AKM and RPK magazines.", "icon_state" = "External Magazine_unloaded", "caliber" = "a762x39", "good_mags" = ak47_mags),
		list("id" = "ak/feed/545x39", "family" = "ak", "slot" = FIREARM_SLOT_FEED, "name" = "AK magazine well (5.45x39mm)",
			"desc" = "Takes AK-74 and RPK-74 magazines.", "icon_state" = "External Magazine_unloaded", "caliber" = "a545x39", "good_mags" = ak74_mags),
		list("id" = "ak/furniture/fixed", "family" = "ak", "slot" = FIREARM_SLOT_FURNITURE, "name" = "AK fixed stock",
			"desc" = "A fixed AK stock and handguard.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "ak/furniture/folding", "family" = "ak", "slot" = FIREARM_SLOT_FURNITURE, "name" = "AK folding stock",
			"desc" = "A folding AK stock and handguard. Slightly less steady than a fixed stock.", "icon_state" = "Folding Stock", "ergonomics" = 0.95),
	))
		var/datum/firearm_component/C = new(data)
		firearm_component_defs[C.id] = C
	firearm_presets = list(
		"akm" = list(FIREARM_SLOT_ACTION = "ak/action", FIREARM_SLOT_BARREL = "ak/barrel/762x39", FIREARM_SLOT_FEED = "ak/feed/762x39", FIREARM_SLOT_FURNITURE = "ak/furniture/fixed"),
		"akms" = list(FIREARM_SLOT_ACTION = "ak/action", FIREARM_SLOT_BARREL = "ak/barrel/762x39", FIREARM_SLOT_FEED = "ak/feed/762x39", FIREARM_SLOT_FURNITURE = "ak/furniture/folding"),
		"ak74" = list(FIREARM_SLOT_ACTION = "ak/action", FIREARM_SLOT_BARREL = "ak/barrel/545x39", FIREARM_SLOT_FEED = "ak/feed/545x39", FIREARM_SLOT_FURNITURE = "ak/furniture/fixed"),
		"aks74" = list(FIREARM_SLOT_ACTION = "ak/action", FIREARM_SLOT_BARREL = "ak/barrel/545x39", FIREARM_SLOT_FEED = "ak/feed/545x39", FIREARM_SLOT_FURNITURE = "ak/furniture/folding"),
	)

/proc/firearm_component_def(id)
	firearm_registry_init()
	return firearm_component_defs[id]

/obj/item/weapon/gun/projectile/submachinegun/ak47
	firearm_family = "ak"
	firearm_preset = "akm"
/obj/item/weapon/gun/projectile/submachinegun/ak47/akms
	firearm_preset = "akms"
/obj/item/weapon/gun/projectile/submachinegun/ak74
	firearm_family = "ak"
	firearm_preset = "ak74"
/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74
	firearm_preset = "aks74"

/obj/item/weapon/gun
	var/firearm_family = null
	var/firearm_preset = null
	// Saved state, null until first used: slot -> component id and slot -> condition (0..1).
	var/list/firearm_part_ids = null
	var/list/firearm_part_condition = null

// Builds the preset parts once. A gun saved with parts keeps them; a gun saved
// before parts existed gets its preset on first use, never twice.
/obj/item/weapon/gun/proc/firearm_parts_ready()
	if (!firearm_family)
		return FALSE
	if (islist(firearm_part_ids) && islist(firearm_part_condition))
		return TRUE
	firearm_registry_init()
	firearm_part_ids = list()
	firearm_part_condition = list()
	var/list/preset = firearm_presets[firearm_preset]
	for (var/slot in preset)
		firearm_part_ids[slot] = preset[slot]
		firearm_part_condition[slot] = 1
	firearm_apply_parts()
	return TRUE

/obj/item/weapon/gun/proc/firearm_part(slot)
	if (!firearm_parts_ready())
		return null
	return firearm_component_def(firearm_part_ids[slot])

// Why the gun cannot fire, or null when it can.
/obj/item/weapon/gun/proc/firearm_fire_block()
	if (!firearm_parts_ready())
		return null
	for (var/slot in firearm_required_slots)
		var/datum/firearm_component/C = firearm_part(slot)
		if (!C)
			return "it has no [slot]"
	var/datum/firearm_component/barrel = firearm_part(FIREARM_SLOT_BARREL)
	var/datum/firearm_component/feed = firearm_part(FIREARM_SLOT_FEED)
	if (barrel.caliber != feed.caliber)
		return "its barrel and magazine well are for different cartridges"
	if (firearm_part_condition[FIREARM_SLOT_BARREL] <= 0)
		return "its barrel is worn out"
	return null

// Derives caliber, magazines and handling from the installed parts.
/obj/item/weapon/gun/proc/firearm_apply_parts()
	if (!islist(firearm_part_ids) || !istype(src, /obj/item/weapon/gun/projectile))
		return
	var/obj/item/weapon/gun/projectile/G = src
	initialize_configuration()
	var/datum/firearm_component/barrel = firearm_component_def(firearm_part_ids[FIREARM_SLOT_BARREL])
	var/datum/firearm_component/feed = firearm_component_def(firearm_part_ids[FIREARM_SLOT_FEED])
	var/datum/firearm_component/furniture = firearm_component_def(firearm_part_ids[FIREARM_SLOT_FURNITURE])
	if (barrel && feed && barrel.caliber == feed.caliber)
		G.caliber = barrel.caliber
		G.good_mags = feed.good_mags.Copy()
	else if (feed)
		G.good_mags = feed.good_mags.Copy()
	// No stock at all handles badly but still fires. The base is the type's
	// compiled value, so reapplying (or loading a save) never compounds.
	var/handling = furniture ? furniture.ergonomics : 0.75
	configuration_base_ergonomics = initial(ergonomics) * handling
	recompute_configuration()

/obj/item/weapon/gun/proc/firearm_slot_needs_bench(slot)
	return !(slot in firearm_field_slots)

/obj/item/weapon/gun/proc/firearm_work_access(mob/living/human/H, slot)
	if (!configuration_actor(H) || !configuration_unloaded())
		return FALSE
	if (firearm_slot_needs_bench(slot) && !configuration_bench(H))
		return FALSE
	return TRUE

// Why a part cannot go into this gun, or null when it fits.
/obj/item/weapon/gun/proc/firearm_install_block(obj/item/weapon/gun_component/P)
	if (!firearm_parts_ready())
		return "this gun takes no modular parts"
	var/datum/firearm_component/C = firearm_component_def(P.component_id)
	if (!C)
		return "that part is not recognised"
	if (C.family != firearm_family)
		return "that part is for a different rifle family"
	if (firearm_part_ids[C.slot])
		return "the [C.slot] slot is already filled"
	return null

/obj/item/weapon/gun/proc/firearm_install(obj/item/weapon/gun_component/P, mob/living/human/H)
	if (!istype(P) || gun_work_busy || P.component_busy || QDELETED(P))
		return FALSE
	var/block = firearm_install_block(P)
	var/datum/firearm_component/C = firearm_component_def(P.component_id)
	if (block || !firearm_work_access(H, C.slot) || P.loc != H || H.get_active_hand() != P)
		if (H) to_chat(H, SPAN_WARNING(block ? "You can't fit [P.name]: [block]." : "Unload and hold [name] with the part in your active hand[firearm_slot_needs_bench(C.slot) ? " next to a firearm bench" : ""]."))
		return FALSE
	gun_work_busy = TRUE
	P.component_busy = TRUE
	var/complete = wait_for_configuration(H, 20)
	if (!complete || QDELETED(P) || firearm_install_block(P) || !firearm_work_access(H, C.slot) || P.loc != H || H.get_active_hand() != P || !H.unEquip(P))
		gun_work_busy = FALSE
		if (!QDELETED(P)) P.component_busy = FALSE
		return FALSE
	firearm_part_ids[C.slot] = C.id
	firearm_part_condition[C.slot] = P.condition
	P.component_busy = FALSE
	P.component_consumed = TRUE
	qdel(P)
	gun_work_busy = FALSE
	firearm_apply_parts()
	to_chat(H, SPAN_NOTICE("You fit [C.name] into [name]."))
	return TRUE

/obj/item/weapon/gun/proc/firearm_remove(slot, mob/living/human/H)
	if (gun_work_busy || !firearm_parts_ready() || !firearm_part_ids[slot] || !firearm_work_access(H, slot))
		return FALSE
	var/id = firearm_part_ids[slot]
	gun_work_busy = TRUE
	var/complete = wait_for_configuration(H, 20)
	if (!complete || firearm_part_ids[slot] != id || !firearm_work_access(H, slot))
		gun_work_busy = FALSE
		return FALSE
	var/obj/item/weapon/gun_component/P = new(H.loc, id, firearm_part_condition[slot])
	firearm_part_ids -= slot
	firearm_part_condition -= slot
	gun_work_busy = FALSE
	firearm_apply_parts()
	H.put_in_hands(P)
	to_chat(H, SPAN_NOTICE("You remove [P.name] from [name]."))
	return P

// One shot of barrel wear. Rebuilds nothing; firing checks the value.
/obj/item/weapon/gun/proc/firearm_wear()
	if (!firearm_family || !firearm_parts_ready() || !firearm_part_ids[FIREARM_SLOT_BARREL])
		return
	var/left = firearm_part_condition[FIREARM_SLOT_BARREL] - 1 / FIREARM_BARREL_LIFE
	// Snap float residue so the last shot of a barrel's life really ends it.
	firearm_part_condition[FIREARM_SLOT_BARREL] = left < 0.5 / FIREARM_BARREL_LIFE ? 0 : left

/obj/item/weapon/gun/proc/firearm_parts_report()
	if (!firearm_parts_ready())
		return null
	var/list/lines = list()
	for (var/slot in firearm_slot_order)
		var/datum/firearm_component/C = firearm_part(slot)
		if (C)
			lines += "[capitalize(slot)]: [C.name] ([round(firearm_part_condition[slot] * 100)]%)"
		else
			lines += "[capitalize(slot)]: <b>missing</b>"
	var/block = firearm_fire_block()
	if (block)
		lines += "<span class='warning'>It cannot fire: [block].</span>"
	return lines.Join("<br>")

/obj/item/weapon/gun/after_load()
	..()
	if (islist(firearm_part_ids))
		if (!islist(firearm_part_condition))
			firearm_part_condition = list()
		// Unknown ids stay recorded (and block firing) instead of being deleted.
		for (var/slot in firearm_part_ids)
			if (!isnum(firearm_part_condition[slot]))
				firearm_part_condition[slot] = 1
		firearm_apply_parts()

/obj/item/weapon/gun/examine(mob/user)
	..()
	if (firearm_family && get_dist(user, src) <= 1)
		var/report = firearm_parts_report()
		if (report)
			to_chat(user, report)

/obj/item/weapon/gun/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/weapon/gun_component) && ishuman(user))
		firearm_install(I, user)
		return
	return ..()

/obj/item/weapon/gun/proc/firearm_strip_menu(mob/living/human/H)
	if (!istype(H) || !firearm_parts_ready())
		return
	var/list/choices = list("Cancel")
	for (var/slot in firearm_slot_order)
		var/datum/firearm_component/C = firearm_part(slot)
		if (C)
			choices["[C.name] ([slot])"] = slot
	var/choice = WWinput(H, "Remove which part?", "Rifle parts", "Cancel", choices)
	if (choice == "Cancel" || !(choice in choices))
		return
	if (!firearm_remove(choices[choice], H))
		to_chat(H, SPAN_WARNING("You can't remove that now. Unload and hold the rifle[firearm_slot_needs_bench(choices[choice]) ? " next to a firearm bench" : ""]."))

/obj/item/weapon/gun/projectile/submachinegun/ak47/verb/remove_rifle_part()
	set name = "Remove Rifle Part"
	set desc = "Unload first. Magazine well and stock come off by hand; the bolt carrier and barrel need a firearm bench."
	set category = null
	set src in usr
	firearm_strip_menu(usr)

/obj/item/weapon/gun/projectile/submachinegun/ak74/verb/remove_rifle_part()
	set name = "Remove Rifle Part"
	set desc = "Unload first. Magazine well and stock come off by hand; the bolt carrier and barrel need a firearm bench."
	set category = null
	set src in usr
	firearm_strip_menu(usr)

/obj/item/weapon/gun_component
	name = "rifle part"
	desc = "A modular rifle part."
	icon = 'icons/obj/gunsmithing.dmi'
	icon_state = "none"
	w_class = ITEM_SIZE_SMALL
	var/component_id = null
	var/condition = 1
	var/tmp/component_busy = FALSE
	var/tmp/component_consumed = FALSE

/obj/item/weapon/gun_component/persistence_runtime_var(key)
	return key == "component_busy" || key == "component_consumed" || ..()

/obj/item/weapon/gun_component/New(loc, id = null, part_condition = 1)
	..(loc)
	if (id)
		component_id = id
		condition = part_condition
	refresh_component()

/obj/item/weapon/gun_component/after_load()
	..()
	refresh_component()

/obj/item/weapon/gun_component/proc/refresh_component()
	var/datum/firearm_component/C = firearm_component_def(component_id)
	if (!C)
		return
	name = C.name
	desc = C.desc
	icon_state = C.icon_state

/obj/item/weapon/gun_component/examine(mob/user)
	..()
	to_chat(user, "Condition: [round(condition * 100)]%.")

/obj/item/weapon/gun_component/ak_action
	component_id = "ak/action"
/obj/item/weapon/gun_component/ak_barrel_762
	component_id = "ak/barrel/762x39"
/obj/item/weapon/gun_component/ak_barrel_545
	component_id = "ak/barrel/545x39"
/obj/item/weapon/gun_component/ak_feed_762
	component_id = "ak/feed/762x39"
/obj/item/weapon/gun_component/ak_feed_545
	component_id = "ak/feed/545x39"
/obj/item/weapon/gun_component/ak_furniture_fixed
	component_id = "ak/furniture/fixed"
/obj/item/weapon/gun_component/ak_furniture_folding
	component_id = "ak/furniture/folding"

#undef FIREARM_BARREL_LIFE
