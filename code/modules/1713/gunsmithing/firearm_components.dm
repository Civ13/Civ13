// Modular firearm components (issue #4443: AK family from phase 2; AR family,
// AK-100 series and the Mauser, Mosin and Arisaka bolt-action families from
// phase 5).
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
	var/list/good_mags = null // feed parts: magazines or clips the gun accepts
	var/ammo_type = null      // feed parts: the loose round a box of ammo must hold
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
	var/list/ak101_mags = list(/obj/item/ammo_magazine/ak101, /obj/item/ammo_magazine/ak101/drum)
	var/list/stanag_mags = list(/obj/item/ammo_magazine/m16, /obj/item/ammo_magazine/m16/mag5_60, /obj/item/ammo_magazine/ar15)
	var/list/mauser792_clips = list(/obj/item/ammo_magazine/gewehr98)
	var/list/mauser765_clips = list(/obj/item/ammo_magazine/gewehr71)
	var/list/mauser7x57_clips = list(/obj/item/ammo_magazine/mauser1893)
	var/list/mosin_clips = list(/obj/item/ammo_magazine/mosin)
	var/list/arisaka65_clips = list(/obj/item/ammo_magazine/arisaka)
	var/list/arisaka77_clips = list(/obj/item/ammo_magazine/arisaka99)
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
		list("id" = "ak/barrel/556x45", "family" = "ak", "slot" = FIREARM_SLOT_BARREL, "name" = "AK barrel (5.56x45mm)",
			"desc" = "A 5.56x45mm barrel for an AK-pattern rifle. Pair it with a 5.56x45mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a556x45"),
		list("id" = "ak/feed/556x45", "family" = "ak", "slot" = FIREARM_SLOT_FEED, "name" = "AK magazine well (5.56x45mm)",
			"desc" = "Takes AK-101 magazines.", "icon_state" = "External Magazine_unloaded", "caliber" = "a556x45", "good_mags" = ak101_mags),
		list("id" = "ak/furniture/fixed", "family" = "ak", "slot" = FIREARM_SLOT_FURNITURE, "name" = "AK fixed stock",
			"desc" = "A fixed AK stock and handguard.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "ak/furniture/folding", "family" = "ak", "slot" = FIREARM_SLOT_FURNITURE, "name" = "AK folding stock",
			"desc" = "A folding AK stock and handguard. Slightly less steady than a fixed stock.", "icon_state" = "Folding Stock", "ergonomics" = 0.95),
		list("id" = "ar/action", "family" = "ar", "slot" = FIREARM_SLOT_ACTION, "name" = "AR bolt carrier group",
			"desc" = "The bolt and carrier of an AR-pattern rifle. Fits any AR receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "ar/barrel/556x45", "family" = "ar", "slot" = FIREARM_SLOT_BARREL, "name" = "AR barrel (5.56x45mm)",
			"desc" = "A 5.56x45mm barrel for an AR-pattern rifle. Pair it with an AR magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a556x45"),
		list("id" = "ar/feed/556x45", "family" = "ar", "slot" = FIREARM_SLOT_FEED, "name" = "AR magazine well (5.56x45mm)",
			"desc" = "Takes M16 and AR-15 magazines.", "icon_state" = "External Magazine_unloaded", "caliber" = "a556x45", "good_mags" = stanag_mags),
		list("id" = "ar/furniture/fixed", "family" = "ar", "slot" = FIREARM_SLOT_FURNITURE, "name" = "AR fixed stock",
			"desc" = "A fixed AR rifle stock and handguard.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "ar/furniture/collapsible", "family" = "ar", "slot" = FIREARM_SLOT_FURNITURE, "name" = "AR collapsible stock",
			"desc" = "A collapsible AR carbine stock and handguard. Slightly less steady than a fixed stock.", "icon_state" = "Folding Stock", "ergonomics" = 0.95),
		list("id" = "mauser/action", "family" = "mauser", "slot" = FIREARM_SLOT_ACTION, "name" = "Mauser bolt",
			"desc" = "The bolt of a Mauser-pattern rifle. Fits any Mauser receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "mauser/barrel/792x57", "family" = "mauser", "slot" = FIREARM_SLOT_BARREL, "name" = "Mauser barrel (7.92x57mm)",
			"desc" = "A 7.92x57mm barrel for a Mauser-pattern rifle. Pair it with a 7.92x57mm magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a792x57"),
		list("id" = "mauser/barrel/765x53", "family" = "mauser", "slot" = FIREARM_SLOT_BARREL, "name" = "Mauser barrel (7.65x53mm)",
			"desc" = "A 7.65x53mm barrel for a Mauser-pattern rifle. Pair it with a 7.65x53mm magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a765x53"),
		list("id" = "mauser/barrel/7x57", "family" = "mauser", "slot" = FIREARM_SLOT_BARREL, "name" = "Mauser barrel (7x57mm)",
			"desc" = "A 7x57mm barrel for a Mauser-pattern rifle. Pair it with a 7x57mm magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a7x57"),
		list("id" = "mauser/feed/792x57", "family" = "mauser", "slot" = FIREARM_SLOT_FEED, "name" = "Mauser magazine (7.92x57mm)",
			"desc" = "A fixed five-round magazine and clip guide. Takes Gewehr 98 stripper clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a792x57", "good_mags" = mauser792_clips, "ammo_type" = /obj/item/ammo_casing/a792x57),
		list("id" = "mauser/feed/765x53", "family" = "mauser", "slot" = FIREARM_SLOT_FEED, "name" = "Mauser magazine (7.65x53mm)",
			"desc" = "A fixed five-round magazine and clip guide. Takes 7.65x53mm stripper clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a765x53", "good_mags" = mauser765_clips, "ammo_type" = /obj/item/ammo_casing/a765x53),
		list("id" = "mauser/feed/7x57", "family" = "mauser", "slot" = FIREARM_SLOT_FEED, "name" = "Mauser magazine (7x57mm)",
			"desc" = "A fixed five-round magazine and clip guide. Takes 7x57mm stripper clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a7x57", "good_mags" = mauser7x57_clips, "ammo_type" = /obj/item/ammo_casing/a7x57),
		list("id" = "mauser/furniture/stock", "family" = "mauser", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Mauser stock",
			"desc" = "A wooden Mauser rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "mosin/action", "family" = "mosin", "slot" = FIREARM_SLOT_ACTION, "name" = "Mosin bolt",
			"desc" = "The bolt of a Mosin-Nagant rifle. Fits any Mosin receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "mosin/barrel/762x54", "family" = "mosin", "slot" = FIREARM_SLOT_BARREL, "name" = "Mosin barrel (7.62x54mmR)",
			"desc" = "A 7.62x54mmR barrel for a Mosin-Nagant rifle.", "icon_state" = "Long Rifle Barrel", "caliber" = "a762x54"),
		list("id" = "mosin/feed/762x54", "family" = "mosin", "slot" = FIREARM_SLOT_FEED, "name" = "Mosin magazine (7.62x54mmR)",
			"desc" = "A fixed five-round magazine and clip guide. Takes Mosin stripper clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a762x54", "good_mags" = mosin_clips, "ammo_type" = /obj/item/ammo_casing/a762x54),
		list("id" = "mosin/furniture/stock", "family" = "mosin", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Mosin stock",
			"desc" = "A wooden Mosin-Nagant rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "arisaka/action", "family" = "arisaka", "slot" = FIREARM_SLOT_ACTION, "name" = "Arisaka bolt",
			"desc" = "The bolt of an Arisaka rifle. Fits any Arisaka receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "arisaka/barrel/65x50", "family" = "arisaka", "slot" = FIREARM_SLOT_BARREL, "name" = "Arisaka barrel (6.5x50mm)",
			"desc" = "A 6.5x50mm barrel for an Arisaka rifle. Pair it with a 6.5x50mm magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a65x50"),
		list("id" = "arisaka/barrel/77x58", "family" = "arisaka", "slot" = FIREARM_SLOT_BARREL, "name" = "Arisaka barrel (7.7x58mm)",
			"desc" = "A 7.7x58mm barrel for an Arisaka rifle. Pair it with a 7.7x58mm magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a77x58"),
		list("id" = "arisaka/feed/65x50", "family" = "arisaka", "slot" = FIREARM_SLOT_FEED, "name" = "Arisaka magazine (6.5x50mm)",
			"desc" = "A fixed five-round magazine and clip guide. Takes 6.5x50mm Arisaka clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a65x50", "good_mags" = arisaka65_clips, "ammo_type" = /obj/item/ammo_casing/a65x50),
		list("id" = "arisaka/feed/77x58", "family" = "arisaka", "slot" = FIREARM_SLOT_FEED, "name" = "Arisaka magazine (7.7x58mm)",
			"desc" = "A fixed five-round magazine and clip guide. Takes Type 99 clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a77x58", "good_mags" = arisaka77_clips, "ammo_type" = /obj/item/ammo_casing/a77x58),
		list("id" = "arisaka/furniture/stock", "family" = "arisaka", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Arisaka stock",
			"desc" = "A wooden Arisaka rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
	))
		var/datum/firearm_component/C = new(data)
		firearm_component_defs[C.id] = C
	firearm_presets = list(
		"akm" = list(FIREARM_SLOT_ACTION = "ak/action", FIREARM_SLOT_BARREL = "ak/barrel/762x39", FIREARM_SLOT_FEED = "ak/feed/762x39", FIREARM_SLOT_FURNITURE = "ak/furniture/fixed"),
		"akms" = list(FIREARM_SLOT_ACTION = "ak/action", FIREARM_SLOT_BARREL = "ak/barrel/762x39", FIREARM_SLOT_FEED = "ak/feed/762x39", FIREARM_SLOT_FURNITURE = "ak/furniture/folding"),
		"ak74" = list(FIREARM_SLOT_ACTION = "ak/action", FIREARM_SLOT_BARREL = "ak/barrel/545x39", FIREARM_SLOT_FEED = "ak/feed/545x39", FIREARM_SLOT_FURNITURE = "ak/furniture/fixed"),
		"aks74" = list(FIREARM_SLOT_ACTION = "ak/action", FIREARM_SLOT_BARREL = "ak/barrel/545x39", FIREARM_SLOT_FEED = "ak/feed/545x39", FIREARM_SLOT_FURNITURE = "ak/furniture/folding"),
		"ak100_556" = list(FIREARM_SLOT_ACTION = "ak/action", FIREARM_SLOT_BARREL = "ak/barrel/556x45", FIREARM_SLOT_FEED = "ak/feed/556x45", FIREARM_SLOT_FURNITURE = "ak/furniture/folding"),
		"ak100_762" = list(FIREARM_SLOT_ACTION = "ak/action", FIREARM_SLOT_BARREL = "ak/barrel/762x39", FIREARM_SLOT_FEED = "ak/feed/762x39", FIREARM_SLOT_FURNITURE = "ak/furniture/folding"),
		"ar_rifle" = list(FIREARM_SLOT_ACTION = "ar/action", FIREARM_SLOT_BARREL = "ar/barrel/556x45", FIREARM_SLOT_FEED = "ar/feed/556x45", FIREARM_SLOT_FURNITURE = "ar/furniture/fixed"),
		"ar_carbine" = list(FIREARM_SLOT_ACTION = "ar/action", FIREARM_SLOT_BARREL = "ar/barrel/556x45", FIREARM_SLOT_FEED = "ar/feed/556x45", FIREARM_SLOT_FURNITURE = "ar/furniture/collapsible"),
		"mauser_792" = list(FIREARM_SLOT_ACTION = "mauser/action", FIREARM_SLOT_BARREL = "mauser/barrel/792x57", FIREARM_SLOT_FEED = "mauser/feed/792x57", FIREARM_SLOT_FURNITURE = "mauser/furniture/stock"),
		"mauser_765" = list(FIREARM_SLOT_ACTION = "mauser/action", FIREARM_SLOT_BARREL = "mauser/barrel/765x53", FIREARM_SLOT_FEED = "mauser/feed/765x53", FIREARM_SLOT_FURNITURE = "mauser/furniture/stock"),
		"mauser_7x57" = list(FIREARM_SLOT_ACTION = "mauser/action", FIREARM_SLOT_BARREL = "mauser/barrel/7x57", FIREARM_SLOT_FEED = "mauser/feed/7x57", FIREARM_SLOT_FURNITURE = "mauser/furniture/stock"),
		"mosin" = list(FIREARM_SLOT_ACTION = "mosin/action", FIREARM_SLOT_BARREL = "mosin/barrel/762x54", FIREARM_SLOT_FEED = "mosin/feed/762x54", FIREARM_SLOT_FURNITURE = "mosin/furniture/stock"),
		"arisaka_65" = list(FIREARM_SLOT_ACTION = "arisaka/action", FIREARM_SLOT_BARREL = "arisaka/barrel/65x50", FIREARM_SLOT_FEED = "arisaka/feed/65x50", FIREARM_SLOT_FURNITURE = "arisaka/furniture/stock"),
		"arisaka_77" = list(FIREARM_SLOT_ACTION = "arisaka/action", FIREARM_SLOT_BARREL = "arisaka/barrel/77x58", FIREARM_SLOT_FEED = "arisaka/feed/77x58", FIREARM_SLOT_FURNITURE = "arisaka/furniture/stock"),
		// A factory-made receiver starts empty and is built up from parts.
		"ak_receiver" = list(),
		"ar_receiver" = list(),
		"mauser_receiver" = list(),
		"mosin_receiver" = list(),
		"arisaka_receiver" = list(),
	)

var/global/list/firearm_family_labels = list("ak" = "AK", "ar" = "AR", "mauser" = "Mauser", "mosin" = "Mosin", "arisaka" = "Arisaka")
var/global/list/firearm_caliber_labels = list("a762x39" = "7.62x39mm", "a545x39" = "5.45x39mm", "a556x45" = "5.56x45mm",
	"a792x57" = "7.92x57mm", "a765x53" = "7.65x53mm", "a7x57" = "7x57mm", "a762x54" = "7.62x54mmR",
	"a65x50" = "6.5x50mm", "a77x58" = "7.7x58mm")

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
/obj/item/weapon/gun/projectile/submachinegun/ak101
	firearm_family = "ak"
	firearm_preset = "ak100_556"
/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103
	firearm_preset = "ak100_762"
/obj/item/weapon/gun/projectile/submachinegun/ak101/ak105
	firearm_preset = "aks74"
/obj/item/weapon/gun/projectile/submachinegun/m16
	firearm_family = "ar"
	firearm_preset = "ar_rifle"
/obj/item/weapon/gun/projectile/submachinegun/m16/commando
	firearm_preset = "ar_carbine"
// The Service Rifle takes its own magazines, so it stays a fixed design.
/obj/item/weapon/gun/projectile/submachinegun/m16/fallout/service_rifle
	firearm_family = null
	firearm_preset = null
/obj/item/weapon/gun/projectile/submachinegun/c7
	firearm_family = "ar"
	firearm_preset = "ar_rifle"
/obj/item/weapon/gun/projectile/submachinegun/c7/c8
	firearm_preset = "ar_carbine"
/obj/item/weapon/gun/projectile/boltaction/gewehr98
	firearm_family = "mauser"
	firearm_preset = "mauser_792"
/obj/item/weapon/gun/projectile/boltaction/gewehr98/mauser1903
	firearm_preset = "mauser_765"
/obj/item/weapon/gun/projectile/boltaction/mauser1890
	firearm_family = "mauser"
	firearm_preset = "mauser_765"
/obj/item/weapon/gun/projectile/boltaction/mauser1893
	firearm_family = "mauser"
	firearm_preset = "mauser_7x57"
/obj/item/weapon/gun/projectile/boltaction/mauser1893/mauser1893o
	firearm_preset = "mauser_765"
/obj/item/weapon/gun/projectile/boltaction/mosin
	firearm_family = "mosin"
	firearm_preset = "mosin"
// The sawn-off Obrez keeps its own weight, size and damage, so it stays fixed.
/obj/item/weapon/gun/projectile/boltaction/mosin/obrez
	firearm_family = null
	firearm_preset = null
/obj/item/weapon/gun/projectile/boltaction/arisaka30
	firearm_family = "arisaka"
	firearm_preset = "arisaka_65"
/obj/item/weapon/gun/projectile/boltaction/arisaka35
	firearm_family = "arisaka"
	firearm_preset = "arisaka_65"
// The Type 38 used to inherit 7.62x54mmR loose rounds from the base rifle.
/obj/item/weapon/gun/projectile/boltaction/arisaka38
	firearm_family = "arisaka"
	firearm_preset = "arisaka_65"
	ammo_type = /obj/item/ammo_casing/a65x50
/obj/item/weapon/gun/projectile/boltaction/arisaka99
	firearm_family = "arisaka"
	firearm_preset = "arisaka_77"

// Factory output: the bare core. It names itself from its barrel once fitted.
/obj/item/weapon/gun/projectile/submachinegun/ak74/receiver
	name = "AK receiver"
	desc = "A bare AK-pattern receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	magazine_type = null
	firearm_preset = "ak_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/m16/receiver
	name = "AR receiver"
	desc = "A bare AR-pattern receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	magazine_type = null
	firearm_preset = "ar_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/mosin/receiver
	name = "Mosin receiver"
	desc = "A bare Mosin-Nagant receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_preset = "mosin_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/arisaka38/receiver
	name = "Arisaka receiver"
	desc = "A bare Arisaka receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_preset = "arisaka_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/gewehr98/receiver
	name = "Mauser receiver"
	desc = "A bare Mauser-pattern receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_preset = "mauser_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun
	var/firearm_family = null
	var/firearm_preset = null
	var/firearm_named_by_parts = FALSE
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
	return firearm_assembly_block(firearm_part_ids, firearm_part_condition)

// Why a set of parts (slot -> id, slot -> condition) cannot fire, or null. Pure,
// so the parts panel can preview a swap without touching the gun.
/proc/firearm_assembly_block(list/ids, list/conditions)
	for (var/slot in firearm_required_slots)
		if (!firearm_component_def(ids[slot]))
			return "it has no [slot]"
	var/datum/firearm_component/barrel = firearm_component_def(ids[FIREARM_SLOT_BARREL])
	var/datum/firearm_component/feed = firearm_component_def(ids[FIREARM_SLOT_FEED])
	if (barrel.caliber != feed.caliber)
		return "its barrel and magazine well are for different cartridges"
	if (conditions[FIREARM_SLOT_BARREL] <= 0)
		return "its barrel is worn out"
	return null

// Handling factor of a set of parts: the stock's, or x0.75 with none.
/proc/firearm_assembly_handling(list/ids)
	var/datum/firearm_component/furniture = firearm_component_def(ids[FIREARM_SLOT_FURNITURE])
	return furniture ? furniture.ergonomics : 0.75

// Derives caliber, magazines and handling from the installed parts.
/obj/item/weapon/gun/proc/firearm_apply_parts()
	if (!islist(firearm_part_ids) || !istype(src, /obj/item/weapon/gun/projectile))
		return
	var/obj/item/weapon/gun/projectile/G = src
	initialize_configuration()
	var/datum/firearm_component/barrel = firearm_component_def(firearm_part_ids[FIREARM_SLOT_BARREL])
	var/datum/firearm_component/feed = firearm_component_def(firearm_part_ids[FIREARM_SLOT_FEED])
	if (barrel && feed && barrel.caliber == feed.caliber)
		G.caliber = barrel.caliber
	if (feed)
		if (feed.good_mags)
			G.good_mags = feed.good_mags.Copy()
		if (feed.ammo_type)
			G.ammo_type = feed.ammo_type
	if (firearm_named_by_parts)
		name = barrel ? "[firearm_family_labels[firearm_family]] rifle ([firearm_caliber_labels[barrel.caliber]])" : initial(name)
	// No stock at all handles badly but still fires. The base is the type's
	// compiled value, so reapplying (or loading a save) never compounds.
	var/handling = firearm_assembly_handling(firearm_part_ids)
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

// Every modular gun gets the strip verb; fixed designs never see it.
/obj/item/weapon/gun/New()
	..()
	if (firearm_family)
		verbs += /obj/item/weapon/gun/proc/remove_rifle_part

/obj/item/weapon/gun/proc/remove_rifle_part()
	set name = "Rifle Parts"
	set desc = "Inspect, remove, fit and salvage parts. Unload first; magazine and stock come off by hand, the action and barrel need a firearm bench."
	set category = null
	set src in usr
	firearm_panel(usr)

// Parts panel (phase 6): what is installed, what blocks firing, what the parts
// you carry would change, and remove, fit and salvage actions.

// Cartridge a set of parts chambers, or null when barrel and feed disagree.
/proc/firearm_assembly_caliber(list/ids)
	var/datum/firearm_component/barrel = firearm_component_def(ids[FIREARM_SLOT_BARREL])
	var/datum/firearm_component/feed = firearm_component_def(ids[FIREARM_SLOT_FEED])
	if (!barrel || !feed || barrel.caliber != feed.caliber)
		return null
	return barrel.caliber

/proc/firearm_caliber_text(caliber)
	if (!caliber)
		return "none"
	var/label = firearm_caliber_labels[caliber]
	return label ? label : caliber

// What this gun would be with P in P's slot (replacing any part there), without
// touching the gun: list(fire_block, handling, caliber).
/obj/item/weapon/gun/proc/firearm_fit_preview(obj/item/weapon/gun_component/P)
	var/datum/firearm_component/C = firearm_component_def(P.component_id)
	if (!C || !firearm_parts_ready())
		return null
	var/list/ids = firearm_part_ids.Copy()
	var/list/conditions = firearm_part_condition.Copy()
	ids[C.slot] = C.id
	conditions[C.slot] = P.condition
	return list("fire_block" = firearm_assembly_block(ids, conditions), "handling" = firearm_assembly_handling(ids), "caliber" = firearm_assembly_caliber(ids))

/obj/item/weapon/gun/proc/firearm_carried_parts(mob/living/human/H)
	var/list/parts = list()
	for (var/obj/item/weapon/gun_component/P in H)
		if (!QDELETED(P) && !P.component_busy)
			parts += P
	return parts

/obj/item/weapon/gun/proc/firearm_panel_html(mob/living/human/H, obj/item/weapon/gun_component/pending_salvage = null)
	if (!firearm_parts_ready())
		return null
	var/list/out = list("<html><head><title>[name] parts</title></head><body>")
	out += "<b>[name]</b><br>"
	var/block = firearm_fire_block()
	out += block ? "<font color='red'>Cannot fire: [block].</font><br>" : "<font color='green'>Ready to fire.</font><br>"
	out += "Cartridge: [firearm_caliber_text(firearm_assembly_caliber(firearm_part_ids))]. Handling: [round(firearm_assembly_handling(firearm_part_ids) * 100)]%.<br>"
	var/datum/firearm_component/feed = firearm_part(FIREARM_SLOT_FEED)
	if (feed && feed.good_mags && feed.good_mags.len)
		var/list/mags = list()
		for (var/mag_type in feed.good_mags)
			var/obj/item/M = mag_type
			mags += initial(M.name)
		out += "Takes: [jointext(mags, ", ")].<br>"
	if (!configuration_unloaded())
		out += "<i>Unload it before working on the parts.</i><br>"
	out += "<hr><b>Installed</b><br>"
	for (var/slot in firearm_slot_order)
		var/datum/firearm_component/C = firearm_part(slot)
		var/where = firearm_slot_needs_bench(slot) ? "firearm bench" : "by hand"
		if (C)
			out += "[capitalize(slot)]: [C.name] ([round(firearm_part_condition[slot] * 100)]%), [where] <a href='?src=\ref[src];firearm_action=remove;slot=[slot]'>Remove</a><br>"
		else
			out += "[capitalize(slot)]: <b>missing</b>[slot in firearm_required_slots ? "" : " (optional)"], [where]<br>"
	out += "<hr><b>Parts you carry</b><br>"
	var/list/parts = firearm_carried_parts(H)
	if (!parts.len)
		out += "None.<br>"
	var/bench = configuration_bench(H)
	for (var/obj/item/weapon/gun_component/P in parts)
		out += "[P.name] ([round(P.condition * 100)]%): "
		var/fit_block = firearm_install_block(P)
		var/datum/firearm_component/C = firearm_component_def(P.component_id)
		if (C && C.family == firearm_family)
			var/list/preview = firearm_fit_preview(P)
			out += "with it, handling [round(firearm_assembly_handling(firearm_part_ids) * 100)]% to [round(preview["handling"] * 100)]%, cartridge [firearm_caliber_text(preview["caliber"])], [preview["fire_block"] ? "cannot fire: [preview["fire_block"]]" : "fires"]. "
		if (fit_block)
			out += "<i>Can't fit: [fit_block].</i> "
		else if (H.get_active_hand() == P)
			out += "<a href='?src=\ref[src];firearm_action=fit;part=\ref[P]'>Fit</a> "
		else
			out += "<i>Hold it in your active hand to fit it.</i> "
		if (bench)
			out += "<a href='?src=\ref[src];firearm_action=salvage;part=\ref[P]'>Salvage</a>"
		else
			out += "<i>Salvage at a firearm bench.</i>"
		out += "<br>"
		if (P == pending_salvage)
			out += "<font color='red'>[firearm_salvage_preview(P)]</font> <a href='?src=\ref[src];firearm_action=salvage_confirm;part=\ref[P]'>Confirm salvage</a> <a href='?src=\ref[src];firearm_action=refresh'>Cancel</a><br>"
	out += "</body></html>"
	return jointext(out, "")

/obj/item/weapon/gun/proc/firearm_panel(mob/living/human/H, obj/item/weapon/gun_component/pending_salvage = null)
	if (!istype(H))
		return
	var/html = firearm_panel_html(H, pending_salvage)
	if (html)
		show_browse(H, html, "window=firearm_parts;size=560x480")

// Panel links. Every action re-checks access itself; the link is only a request.
/obj/item/weapon/gun/proc/firearm_panel_act(mob/living/human/H, list/href_list)
	if (!istype(H) || H.stat || !firearm_parts_ready() || !configuration_actor(H))
		return FALSE
	var/action = href_list["firearm_action"]
	var/obj/item/weapon/gun_component/P = null
	if (href_list["part"])
		P = locate(href_list["part"])
		if (!istype(P) || P.loc != H || QDELETED(P))
			return FALSE
	switch (action)
		if ("remove")
			var/slot = href_list["slot"]
			if (!(slot in firearm_slot_order))
				return FALSE
			if (!firearm_remove(slot, H))
				to_chat(H, SPAN_WARNING("You can't remove that now. Unload and hold [name][firearm_slot_needs_bench(slot) ? " next to a firearm bench" : ""]."))
				return FALSE
		if ("fit")
			if (!P || !firearm_install(P, H))
				return FALSE
		if ("salvage")
			if (!P)
				return FALSE
			firearm_panel(H, P)
			return TRUE
		if ("salvage_confirm")
			if (!P || !firearm_salvage(P, H))
				return FALSE
		if ("refresh")
		else
			return FALSE
	firearm_panel(H)
	return TRUE

/obj/item/weapon/gun/Topic(href, href_list)
	if (!href_list["firearm_action"])
		return ..()
	firearm_panel_act(usr, href_list)
	return TRUE

// Salvage: about half the factory materials back, scaled by the part's
// condition, rounded to the nearest unit. The part is destroyed.
#define FIREARM_SALVAGE_RETURN 0.5

/proc/firearm_component_recipe(id)
	for (var/recipe_name in factory_get_recipes())
		var/datum/factory_recipe/R = factory_recipes[recipe_name]
		if (!ispath(R.output_type, /obj/item/weapon/gun_component))
			continue
		var/obj/item/weapon/gun_component/T = R.output_type
		if (initial(T.component_id) == id)
			return R
	return null

// Material type -> amount salvaging P would return (may be empty).
/proc/firearm_salvage_yield(obj/item/weapon/gun_component/P)
	var/list/yield = list()
	var/datum/factory_recipe/R = firearm_component_recipe(P.component_id)
	if (!R)
		return yield
	for (var/input_type in R.inputs)
		var/amount = round(R.inputs[input_type] / R.output_amount * P.condition * FIREARM_SALVAGE_RETURN, 1)
		if (amount > 0)
			yield[input_type] = amount
	return yield

/proc/firearm_salvage_preview(obj/item/weapon/gun_component/P)
	var/list/yield = firearm_salvage_yield(P)
	var/list/returned = list()
	for (var/input_type in yield)
		var/obj/item/I = input_type
		returned += "[yield[input_type]] [initial(I.name)]"
	return "Salvaging destroys [P.name] ([round(P.condition * 100)]%) and returns [returned.len ? jointext(returned, ", ") : "nothing usable"]."

/obj/item/weapon/gun_component/proc/salvage_bench(mob/living/human/H)
	for (var/obj/structure/repair/gun/B in range(1, H))
		if (!QDELETED(B) && isturf(B.loc) && B.anchored)
			return B
	return null

/obj/item/weapon/gun_component/proc/salvage_wait(mob/living/human/H)
	return do_after(H, 30, salvage_bench(H))

// Destroys P at a firearm bench and drops its salvage. The caller has already
// shown firearm_salvage_preview and had it confirmed.
/proc/firearm_salvage(obj/item/weapon/gun_component/P, mob/living/human/H)
	if (!istype(P) || !istype(H) || QDELETED(P) || P.component_busy || P.loc != H || !P.salvage_bench(H))
		if (istype(H)) to_chat(H, SPAN_WARNING("Carry the part to a firearm bench to salvage it."))
		return FALSE
	P.component_busy = TRUE
	var/complete = P.salvage_wait(H)
	if (!complete || QDELETED(P) || P.loc != H || !P.salvage_bench(H) || !H.unEquip(P))
		if (!QDELETED(P)) P.component_busy = FALSE
		return FALSE
	var/list/yield = firearm_salvage_yield(P)
	var/part_name = P.name
	P.component_busy = FALSE
	P.component_consumed = TRUE
	qdel(P)
	for (var/input_type in yield)
		new input_type(H.loc, yield[input_type])
	to_chat(H, SPAN_NOTICE("You salvage [part_name][yield.len ? "" : ", but nothing usable is left"]."))
	return TRUE

#undef FIREARM_SALVAGE_RETURN

// Hitting the firearm bench with a loose part offers to salvage it, showing
// what it destroys and returns first.
/proc/firearm_offer_salvage(obj/item/weapon/gun_component/P, mob/living/human/H)
	if (!istype(P) || !istype(H))
		return FALSE
	var/choice = WWinput(H, firearm_salvage_preview(P), "Salvage rifle part", "Cancel", list("Salvage", "Cancel"))
	if (choice != "Salvage")
		return FALSE
	return firearm_salvage(P, H)

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
/obj/item/weapon/gun_component/ak_barrel_556
	component_id = "ak/barrel/556x45"
/obj/item/weapon/gun_component/ak_feed_556
	component_id = "ak/feed/556x45"
/obj/item/weapon/gun_component/ar_action
	component_id = "ar/action"
/obj/item/weapon/gun_component/ar_barrel_556
	component_id = "ar/barrel/556x45"
/obj/item/weapon/gun_component/ar_feed_556
	component_id = "ar/feed/556x45"
/obj/item/weapon/gun_component/ar_furniture_fixed
	component_id = "ar/furniture/fixed"
/obj/item/weapon/gun_component/ar_furniture_collapsible
	component_id = "ar/furniture/collapsible"
/obj/item/weapon/gun_component/mauser_action
	component_id = "mauser/action"
/obj/item/weapon/gun_component/mauser_barrel_792
	component_id = "mauser/barrel/792x57"
/obj/item/weapon/gun_component/mauser_barrel_765
	component_id = "mauser/barrel/765x53"
/obj/item/weapon/gun_component/mauser_barrel_7x57
	component_id = "mauser/barrel/7x57"
/obj/item/weapon/gun_component/mauser_feed_792
	component_id = "mauser/feed/792x57"
/obj/item/weapon/gun_component/mauser_feed_765
	component_id = "mauser/feed/765x53"
/obj/item/weapon/gun_component/mauser_feed_7x57
	component_id = "mauser/feed/7x57"
/obj/item/weapon/gun_component/mauser_furniture_stock
	component_id = "mauser/furniture/stock"
/obj/item/weapon/gun_component/mosin_action
	component_id = "mosin/action"
/obj/item/weapon/gun_component/mosin_barrel_762
	component_id = "mosin/barrel/762x54"
/obj/item/weapon/gun_component/mosin_feed_762
	component_id = "mosin/feed/762x54"
/obj/item/weapon/gun_component/mosin_furniture_stock
	component_id = "mosin/furniture/stock"
/obj/item/weapon/gun_component/arisaka_action
	component_id = "arisaka/action"
/obj/item/weapon/gun_component/arisaka_barrel_65
	component_id = "arisaka/barrel/65x50"
/obj/item/weapon/gun_component/arisaka_barrel_77
	component_id = "arisaka/barrel/77x58"
/obj/item/weapon/gun_component/arisaka_feed_65
	component_id = "arisaka/feed/65x50"
/obj/item/weapon/gun_component/arisaka_feed_77
	component_id = "arisaka/feed/77x58"
/obj/item/weapon/gun_component/arisaka_furniture_stock
	component_id = "arisaka/furniture/stock"

#undef FIREARM_BARREL_LIFE
