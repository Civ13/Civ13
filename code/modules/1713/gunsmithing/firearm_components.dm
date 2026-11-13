// Modular firearm components (issue #4443: AK family from phase 2; AR family,
// AK-100 series and the Mauser, Mosin, Arisaka, Lee-Enfield, Springfield,
// Lebel, Berthier and Carcano bolt-action families from phase 5).
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
	var/capacity = null       // feed parts: rounds held, when it differs between feeds of one family (0 = none, magazine only)
	var/load_method = null    // feed parts: how the gun loads, when it differs between feeds of one family
	var/cliploader = null     // feed parts: TRUE when clips load into a detachable magazine
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
	var/list/stanag_mags = list(/obj/item/ammo_magazine/m16, /obj/item/ammo_magazine/m16/mag5_60, /obj/item/ammo_magazine/ar15, /obj/item/ammo_magazine/mk18)
	var/list/mauser792_clips = list(/obj/item/ammo_magazine/gewehr98)
	var/list/mauser765_clips = list(/obj/item/ammo_magazine/gewehr71)
	var/list/mauser7x57_clips = list(/obj/item/ammo_magazine/mauser1893)
	var/list/mosin_clips = list(/obj/item/ammo_magazine/mosin)
	var/list/arisaka65_clips = list(/obj/item/ammo_magazine/arisaka)
	var/list/arisaka77_clips = list(/obj/item/ammo_magazine/arisaka99)
	var/list/enfield_clips = list(/obj/item/ammo_magazine/enfield)
	var/list/springfield_clips = list(/obj/item/ammo_magazine/springfield, /obj/item/ammo_magazine/garand)
	var/list/lebel_clips = list(/obj/item/ammo_magazine/c8x50)
	var/list/berthier3_clips = list(/obj/item/ammo_magazine/c8x50_3clip)
	var/list/berthier5_clips = list(/obj/item/ammo_magazine/c8x50_5clip)
	var/list/carcano_clips = list(/obj/item/ammo_magazine/carcano)
	var/list/murata_clips = list(/obj/item/ammo_magazine/murata)
	var/list/vg_clips = list(/obj/item/ammo_magazine/vgclip)
	var/list/m24_clips = list(/obj/item/ammo_magazine/m24)
	// Anti-tank and anti-materiel rifles take more than one loose round type.
	var/list/ptrd_rounds = list(/obj/item/ammo_casing/a145, /obj/item/ammo_casing/a145_ap)
	var/list/pzb_rounds = list(/obj/item/ammo_casing/a792x94, /obj/item/ammo_casing/a792x94_ap)
	var/list/barrett_rounds = list(/obj/item/ammo_casing/a50cal, /obj/item/ammo_casing/a50cal_ap, /obj/item/ammo_casing/a50cal_he)
	var/list/bamr_rounds = list(/obj/item/ammo_casing/a15115, /obj/item/ammo_casing/a15115_ap, /obj/item/ammo_casing/a15115_aphe)
	var/list/sks_clips = list(/obj/item/ammo_magazine/sks)
	var/list/sksm_mags = list(/obj/item/ammo_magazine/sks, /obj/item/ammo_magazine/sksm, /obj/item/ammo_magazine/rpk47, /obj/item/ammo_magazine/rpk47/drum, /obj/item/ammo_magazine/ak47, /obj/item/ammo_magazine/ak47/makeshift)
	var/list/g43_mags = list(/obj/item/ammo_magazine/g43, /obj/item/ammo_magazine/gewehr98)
	var/list/svt_mags = list(/obj/item/ammo_magazine/svt, /obj/item/ammo_magazine/mosin)
	var/list/m1carbine_mags = list(/obj/item/ammo_magazine/m1carbine, /obj/item/ammo_magazine/m1carbine/big)
	var/list/avtomat_mags = list(/obj/item/ammo_magazine/avtomat)
	var/list/vg5_mags = list(/obj/item/ammo_magazine/stg, /obj/item/ammo_magazine/vgclip)
	var/list/ptrs_clips = list(/obj/item/ammo_magazine/ptrs)
	var/list/svd_mags = list(/obj/item/ammo_magazine/svd)
	var/list/vss_mags = list(/obj/item/ammo_magazine/vintorez)
	var/list/m82_mags = list(/obj/item/ammo_magazine/barrett)
	var/list/bamr_mags = list(/obj/item/ammo_magazine/bamr, /obj/item/ammo_magazine/bamr_aphe, /obj/item/ammo_magazine/bamr_ap)
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
		list("id" = "enfield/action", "family" = "enfield", "slot" = FIREARM_SLOT_ACTION, "name" = "Lee-Enfield bolt",
			"desc" = "The bolt of a Lee-Enfield rifle. Fits any Lee-Enfield receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "enfield/barrel/303", "family" = "enfield", "slot" = FIREARM_SLOT_BARREL, "name" = "Lee-Enfield barrel (.303 British)",
			"desc" = "A .303 British barrel for a Lee-Enfield rifle. Pair it with a .303 British magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a303"),
		list("id" = "enfield/feed/303", "family" = "enfield", "slot" = FIREARM_SLOT_FEED, "name" = "Lee-Enfield magazine (.303 British)",
			"desc" = "A detachable ten-round box magazine and clip guide. Takes .303 chargers.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a303", "good_mags" = enfield_clips, "ammo_type" = /obj/item/ammo_casing/a303),
		list("id" = "enfield/furniture/stock", "family" = "enfield", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Lee-Enfield stock",
			"desc" = "A wooden Lee-Enfield rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "springfield/action", "family" = "springfield", "slot" = FIREARM_SLOT_ACTION, "name" = "Springfield bolt",
			"desc" = "The bolt of a Springfield rifle. Fits any Springfield receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "springfield/barrel/3006", "family" = "springfield", "slot" = FIREARM_SLOT_BARREL, "name" = "Springfield barrel (.30-06)",
			"desc" = "A .30-06 barrel for a Springfield rifle. Pair it with a .30-06 magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a3006"),
		list("id" = "springfield/feed/3006", "family" = "springfield", "slot" = FIREARM_SLOT_FEED, "name" = "Springfield magazine (.30-06)",
			"desc" = "A fixed five-round magazine and clip guide. Takes Springfield stripper clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a3006", "good_mags" = springfield_clips, "ammo_type" = /obj/item/ammo_casing/a3006),
		list("id" = "springfield/furniture/stock", "family" = "springfield", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Springfield stock",
			"desc" = "A wooden M1903 Springfield stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "lebel/action", "family" = "lebel", "slot" = FIREARM_SLOT_ACTION, "name" = "Lebel bolt",
			"desc" = "The bolt of a Lebel rifle. Fits any Lebel receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "lebel/barrel/8x50", "family" = "lebel", "slot" = FIREARM_SLOT_BARREL, "name" = "Lebel barrel (8x50mmR)",
			"desc" = "A 8x50mmR barrel for a Lebel rifle. Pair it with a 8x50mmR magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a8x50"),
		list("id" = "lebel/feed/8x50", "family" = "lebel", "slot" = FIREARM_SLOT_FEED, "name" = "Lebel magazine (8x50mmR)",
			"desc" = "A tube magazine under the barrel, loaded a round at a time.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a8x50", "good_mags" = lebel_clips, "ammo_type" = /obj/item/ammo_casing/a8x50),
		list("id" = "lebel/furniture/stock", "family" = "lebel", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Lebel stock",
			"desc" = "A wooden Lebel rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "berthier/action", "family" = "berthier", "slot" = FIREARM_SLOT_ACTION, "name" = "Berthier bolt",
			"desc" = "The bolt of a Berthier rifle. Fits any Berthier receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "berthier/barrel/8x50", "family" = "berthier", "slot" = FIREARM_SLOT_BARREL, "name" = "Berthier barrel (8x50mmR)",
			"desc" = "A 8x50mmR barrel for a Berthier rifle. Pair it with a 8x50mmR magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a8x50"),
		list("id" = "berthier/feed/8x50_3", "family" = "berthier", "slot" = FIREARM_SLOT_FEED, "name" = "Berthier magazine (8x50mmR, 3 rounds)",
			"desc" = "A three-round magazine for Berthier en-bloc clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a8x50", "good_mags" = berthier3_clips, "ammo_type" = /obj/item/ammo_casing/a8x50, "capacity" = 3),
		list("id" = "berthier/feed/8x50_5", "family" = "berthier", "slot" = FIREARM_SLOT_FEED, "name" = "Berthier magazine (8x50mmR, 5 rounds)",
			"desc" = "The longer M16 magazine for five-round Berthier clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a8x50", "good_mags" = berthier5_clips, "ammo_type" = /obj/item/ammo_casing/a8x50, "capacity" = 5),
		list("id" = "berthier/furniture/stock", "family" = "berthier", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Berthier stock",
			"desc" = "A wooden Berthier rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "carcano/action", "family" = "carcano", "slot" = FIREARM_SLOT_ACTION, "name" = "Carcano bolt",
			"desc" = "The bolt of a Carcano rifle. Fits any Carcano receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "carcano/barrel/65x52", "family" = "carcano", "slot" = FIREARM_SLOT_BARREL, "name" = "Carcano barrel (6.5x52mm)",
			"desc" = "A 6.5x52mm barrel for a Carcano rifle. Pair it with a 6.5x52mm magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a65x52"),
		list("id" = "carcano/feed/65x52", "family" = "carcano", "slot" = FIREARM_SLOT_FEED, "name" = "Carcano magazine (6.5x52mm)",
			"desc" = "A fixed six-round magazine for Carcano en-bloc clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a65x52", "good_mags" = carcano_clips, "ammo_type" = /obj/item/ammo_casing/a65x52),
		list("id" = "carcano/furniture/stock", "family" = "carcano", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Carcano stock",
			"desc" = "A wooden Carcano rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "murata/action", "family" = "murata", "slot" = FIREARM_SLOT_ACTION, "name" = "Murata bolt",
			"desc" = "The bolt of a Type-22 Murata rifle. Fits any Murata receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "murata/barrel/8x53", "family" = "murata", "slot" = FIREARM_SLOT_BARREL, "name" = "Murata barrel (8x53mm)",
			"desc" = "A 8x53mm barrel for a Murata rifle. Pair it with a 8x53mm magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a8x53"),
		list("id" = "murata/feed/8x53", "family" = "murata", "slot" = FIREARM_SLOT_FEED, "name" = "Murata magazine (8x53mm)",
			"desc" = "An eight-round tube magazine under the barrel. Takes Murata clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a8x53", "good_mags" = murata_clips, "ammo_type" = /obj/item/ammo_casing/a8x53),
		list("id" = "murata/furniture/stock", "family" = "murata", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Murata stock",
			"desc" = "A wooden Type-22 Murata stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "berdan/action", "family" = "berdan", "slot" = FIREARM_SLOT_ACTION, "name" = "Berdan bolt",
			"desc" = "The bolt of a Berdan rifle. Fits any Berdan receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "berdan/barrel/762x54", "family" = "berdan", "slot" = FIREARM_SLOT_BARREL, "name" = "Berdan barrel (7.62x54mmR)",
			"desc" = "A 7.62x54mmR barrel for a Berdan rifle. Pair it with a 7.62x54mmR magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a762x54"),
		list("id" = "berdan/feed/762x54", "family" = "berdan", "slot" = FIREARM_SLOT_FEED, "name" = "Berdan magazine (7.62x54mmR)",
			"desc" = "A fixed magazine and clip guide. Takes Mosin stripper clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a762x54", "good_mags" = mosin_clips, "ammo_type" = /obj/item/ammo_casing/a762x54),
		list("id" = "berdan/furniture/stock", "family" = "berdan", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Berdan stock",
			"desc" = "A wooden Berdan rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "vg/action", "family" = "vg", "slot" = FIREARM_SLOT_ACTION, "name" = "Volkssturmgewehr bolt",
			"desc" = "The bolt of a Volkssturmgewehr. Fits any Volkssturmgewehr receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "vg/barrel/792x33", "family" = "vg", "slot" = FIREARM_SLOT_BARREL, "name" = "Volkssturmgewehr barrel (7.92x33mm Kurz)",
			"desc" = "A 7.92x33mm Kurz barrel for a Volkssturmgewehr rifle. Pair it with a 7.92x33mm Kurz magazine.", "icon_state" = "Carbine Barrel", "caliber" = "a792x33"),
		list("id" = "vg/feed/792x33", "family" = "vg", "slot" = FIREARM_SLOT_FEED, "name" = "Volkssturmgewehr magazine (7.92x33mm Kurz)",
			"desc" = "A fixed ten-round magazine. Takes 7.92x33mm clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a792x33", "good_mags" = vg_clips, "ammo_type" = /obj/item/ammo_casing/a792x33),
		list("id" = "vg/furniture/stock", "family" = "vg", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Volkssturmgewehr stock",
			"desc" = "A plain wooden Volkssturmgewehr stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "m24/action", "family" = "m24", "slot" = FIREARM_SLOT_ACTION, "name" = "M24 bolt",
			"desc" = "The bolt of an M24 sniper rifle. Fits any M24 receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "m24/barrel/762x51", "family" = "m24", "slot" = FIREARM_SLOT_BARREL, "name" = "M24 barrel (7.62x51mm)",
			"desc" = "A 7.62x51mm barrel for a M24 rifle. Pair it with a 7.62x51mm magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a762x51"),
		list("id" = "m24/feed/762x51", "family" = "m24", "slot" = FIREARM_SLOT_FEED, "name" = "M24 magazine (7.62x51mm)",
			"desc" = "A five-round internal magazine. Takes 7.62x51mm clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a762x51", "good_mags" = m24_clips, "ammo_type" = /obj/item/ammo_casing/a762x51),
		list("id" = "m24/furniture/stock", "family" = "m24", "slot" = FIREARM_SLOT_FURNITURE, "name" = "M24 stock",
			"desc" = "A synthetic M24 stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "sharps/action", "family" = "sharps", "slot" = FIREARM_SLOT_ACTION, "name" = "Sharps breechblock",
			"desc" = "The falling breechblock of a Sharps rifle. Fits any Sharps receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "sharps/barrel/4570", "family" = "sharps", "slot" = FIREARM_SLOT_BARREL, "name" = "Sharps barrel (.45-70)",
			"desc" = "A .45-70 barrel for a Sharps rifle. Pair it with a .45-70 extractor.", "icon_state" = "Long Rifle Barrel", "caliber" = "a4570"),
		list("id" = "sharps/feed/4570", "family" = "sharps", "slot" = FIREARM_SLOT_FEED, "name" = "Sharps extractor (.45-70)",
			"desc" = "The extractor of a single-shot breech, loaded one round at a time.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a4570", "ammo_type" = /obj/item/ammo_casing/a4570),
		list("id" = "sharps/furniture/stock", "family" = "sharps", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Sharps stock",
			"desc" = "A wooden Sharps rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "rollingblock/action", "family" = "rollingblock", "slot" = FIREARM_SLOT_ACTION, "name" = "Rolling-block breechblock",
			"desc" = "The rolling breechblock of a Rolling-Block rifle. Fits any Rolling-block receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "rollingblock/barrel/4570", "family" = "rollingblock", "slot" = FIREARM_SLOT_BARREL, "name" = "Rolling-block barrel (.45-70)",
			"desc" = "A .45-70 barrel for a Rolling-block rifle. Pair it with a .45-70 extractor.", "icon_state" = "Long Rifle Barrel", "caliber" = "a4570"),
		list("id" = "rollingblock/barrel/43", "family" = "rollingblock", "slot" = FIREARM_SLOT_BARREL, "name" = "Rolling-block barrel (.43 Spanish)",
			"desc" = "A .43 Spanish barrel for a Rolling-block rifle. Pair it with a .43 Spanish extractor.", "icon_state" = "Long Rifle Barrel", "caliber" = "a43"),
		list("id" = "rollingblock/feed/4570", "family" = "rollingblock", "slot" = FIREARM_SLOT_FEED, "name" = "Rolling-block extractor (.45-70)",
			"desc" = "The extractor of a single-shot breech, loaded one round at a time.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a4570", "ammo_type" = /obj/item/ammo_casing/a4570),
		list("id" = "rollingblock/feed/43", "family" = "rollingblock", "slot" = FIREARM_SLOT_FEED, "name" = "Rolling-block extractor (.43 Spanish)",
			"desc" = "The extractor of a single-shot breech, loaded one round at a time.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a43", "ammo_type" = /obj/item/ammo_casing/a43),
		list("id" = "rollingblock/furniture/stock", "family" = "rollingblock", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Rolling-block stock",
			"desc" = "A wooden Rolling-Block rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "martini/action", "family" = "martini", "slot" = FIREARM_SLOT_ACTION, "name" = "Martini-Henry breechblock",
			"desc" = "The falling breechblock of a Martini-Henry rifle. Fits any Martini-Henry receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "martini/barrel/577", "family" = "martini", "slot" = FIREARM_SLOT_BARREL, "name" = "Martini-Henry barrel (.577/450)",
			"desc" = "A .577/450 barrel for a Martini-Henry rifle. Pair it with a .577/450 extractor.", "icon_state" = "Long Rifle Barrel", "caliber" = "a577"),
		list("id" = "martini/feed/577", "family" = "martini", "slot" = FIREARM_SLOT_FEED, "name" = "Martini-Henry extractor (.577/450)",
			"desc" = "The extractor of a single-shot breech, loaded one round at a time.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a577", "ammo_type" = /obj/item/ammo_casing/a577),
		list("id" = "martini/furniture/stock", "family" = "martini", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Martini-Henry stock",
			"desc" = "A wooden Martini-Henry rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "ptrd/action", "family" = "ptrd", "slot" = FIREARM_SLOT_ACTION, "name" = "PTRD bolt",
			"desc" = "The bolt of a PTRD-41 anti-tank rifle. Fits any PTRD receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "ptrd/barrel/145", "family" = "ptrd", "slot" = FIREARM_SLOT_BARREL, "name" = "PTRD barrel (14.5x114mm)",
			"desc" = "A 14.5x114mm barrel for a PTRD rifle. Pair it with a 14.5x114mm breech.", "icon_state" = "Long Rifle Barrel", "caliber" = "a145"),
		list("id" = "ptrd/feed/145", "family" = "ptrd", "slot" = FIREARM_SLOT_FEED, "name" = "PTRD breech (14.5x114mm)",
			"desc" = "The breech of a single-shot anti-tank rifle, loaded one round at a time.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a145", "ammo_type" = ptrd_rounds),
		list("id" = "ptrd/furniture/stock", "family" = "ptrd", "slot" = FIREARM_SLOT_FURNITURE, "name" = "PTRD stock",
			"desc" = "The padded steel stock of a PTRD-41.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "pzb/action", "family" = "pzb", "slot" = FIREARM_SLOT_ACTION, "name" = "PzB breechblock",
			"desc" = "The falling breechblock of a PzB 39 anti-tank rifle. Fits any PzB receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "pzb/barrel/792x94", "family" = "pzb", "slot" = FIREARM_SLOT_BARREL, "name" = "PzB barrel (7.92x94mm)",
			"desc" = "A 7.92x94mm barrel for a PzB rifle. Pair it with a 7.92x94mm breech.", "icon_state" = "Long Rifle Barrel", "caliber" = "a792x94"),
		list("id" = "pzb/feed/792x94", "family" = "pzb", "slot" = FIREARM_SLOT_FEED, "name" = "PzB breech (7.92x94mm)",
			"desc" = "The breech of a single-shot anti-tank rifle, loaded one round at a time.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a792x94", "ammo_type" = pzb_rounds),
		list("id" = "pzb/furniture/stock", "family" = "pzb", "slot" = FIREARM_SLOT_FURNITURE, "name" = "PzB stock",
			"desc" = "The folding steel stock of a PzB 39.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "barrett/action", "family" = "barrett", "slot" = FIREARM_SLOT_ACTION, "name" = "Barrett bolt",
			"desc" = "The bolt of a Barrett M99. Fits any Barrett receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "barrett/barrel/50cal", "family" = "barrett", "slot" = FIREARM_SLOT_BARREL, "name" = "Barrett barrel (.50 BMG)",
			"desc" = "A .50 BMG barrel for a Barrett rifle. Pair it with a .50 BMG breech.", "icon_state" = "Long Rifle Barrel", "caliber" = "a50cal"),
		list("id" = "barrett/feed/50cal", "family" = "barrett", "slot" = FIREARM_SLOT_FEED, "name" = "Barrett breech (.50 BMG)",
			"desc" = "The breech of a single-shot anti-materiel rifle, loaded one round at a time.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a50cal", "ammo_type" = barrett_rounds),
		list("id" = "barrett/furniture/stock", "family" = "barrett", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Barrett stock",
			"desc" = "The steel skeleton stock of a Barrett M99.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "sks/action", "family" = "sks", "slot" = FIREARM_SLOT_ACTION, "name" = "SKS bolt carrier",
			"desc" = "The bolt carrier of a SKS rifle. Fits any SKS receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "sks/barrel/762x39", "family" = "sks", "slot" = FIREARM_SLOT_BARREL, "name" = "SKS barrel (7.62x39mm)",
			"desc" = "A 7.62x39mm barrel for a SKS rifle. Pair it with a 7.62x39mm magazine.", "icon_state" = "Rifle Barrel", "caliber" = "a762x39"),
		list("id" = "sks/feed/762x39", "family" = "sks", "slot" = FIREARM_SLOT_FEED, "name" = "SKS magazine (7.62x39mm)",
			"desc" = "A fixed ten-round magazine loaded from SKS stripper clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a762x39", "good_mags" = sks_clips, "ammo_type" = /obj/item/ammo_casing/a762x39, "capacity" = 10, "load_method" = SINGLE_CASING|SPEEDLOADER, "cliploader" = FALSE),
		list("id" = "sks/feed/762x39_detachable", "family" = "sks", "slot" = FIREARM_SLOT_FEED, "name" = "SKS-M magazine well (7.62x39mm)",
			"desc" = "A Type 63 magazine well that takes SKS-M and AK-47 magazines, which SKS clips can top up.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x39", "good_mags" = sksm_mags, "ammo_type" = /obj/item/ammo_casing/a762x39, "capacity" = 0, "load_method" = SINGLE_CASING|SPEEDLOADER|MAGAZINE, "cliploader" = TRUE),
		list("id" = "sks/furniture/stock", "family" = "sks", "slot" = FIREARM_SLOT_FURNITURE, "name" = "SKS stock",
			"desc" = "A wooden SKS stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "gewehr43/action", "family" = "gewehr43", "slot" = FIREARM_SLOT_ACTION, "name" = "Gewehr 41/43 bolt carrier",
			"desc" = "The bolt carrier of a Gewehr 41/43 rifle. Fits any Gewehr 41/43 receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "gewehr43/barrel/792x57", "family" = "gewehr43", "slot" = FIREARM_SLOT_BARREL, "name" = "Gewehr 41/43 barrel (7.92x57mm)",
			"desc" = "A 7.92x57mm barrel for a Gewehr 41/43 rifle. Pair it with a 7.92x57mm magazine.", "icon_state" = "Rifle Barrel", "caliber" = "a792x57"),
		list("id" = "gewehr43/feed/792x57", "family" = "gewehr43", "slot" = FIREARM_SLOT_FEED, "name" = "Gewehr 41 magazine (7.92x57mm)",
			"desc" = "A fixed ten-round magazine loaded from Mauser stripper clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a792x57", "good_mags" = mauser792_clips, "ammo_type" = /obj/item/ammo_casing/a792x57, "capacity" = 10, "load_method" = SINGLE_CASING|SPEEDLOADER, "cliploader" = FALSE),
		list("id" = "gewehr43/feed/792x57_detachable", "family" = "gewehr43", "slot" = FIREARM_SLOT_FEED, "name" = "Gewehr 43 magazine well (7.92x57mm)",
			"desc" = "A magazine well for detachable Gewehr 43 magazines, which Mauser clips can top up.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a792x57", "good_mags" = g43_mags, "ammo_type" = /obj/item/ammo_casing/a792x57, "capacity" = 10, "load_method" = SINGLE_CASING|SPEEDLOADER|MAGAZINE, "cliploader" = TRUE),
		list("id" = "gewehr43/furniture/stock", "family" = "gewehr43", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Gewehr 41/43 stock",
			"desc" = "A wooden Gewehr 41/43 stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "svt/action", "family" = "svt", "slot" = FIREARM_SLOT_ACTION, "name" = "SVT bolt carrier",
			"desc" = "The bolt carrier of a SVT rifle. Fits any SVT receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "svt/barrel/762x54", "family" = "svt", "slot" = FIREARM_SLOT_BARREL, "name" = "SVT barrel (7.62x54mmR)",
			"desc" = "A 7.62x54mmR barrel for a SVT rifle. Pair it with a 7.62x54mmR magazine.", "icon_state" = "Rifle Barrel", "caliber" = "a762x54"),
		list("id" = "svt/feed/762x54", "family" = "svt", "slot" = FIREARM_SLOT_FEED, "name" = "SVT magazine well (7.62x54mmR)",
			"desc" = "A magazine well for SVT-40 magazines, which Mosin clips can top up.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x54", "good_mags" = svt_mags, "ammo_type" = /obj/item/ammo_casing/a762x54),
		list("id" = "svt/furniture/stock", "family" = "svt", "slot" = FIREARM_SLOT_FURNITURE, "name" = "SVT stock",
			"desc" = "A wooden SVT-40 stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "garand/action", "family" = "garand", "slot" = FIREARM_SLOT_ACTION, "name" = "M1 Garand operating rod and bolt",
			"desc" = "The operating rod of a M1 Garand rifle. Fits any M1 Garand receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "garand/barrel/3006", "family" = "garand", "slot" = FIREARM_SLOT_BARREL, "name" = "M1 Garand barrel (.30-06)",
			"desc" = "A .30-06 barrel for a M1 Garand rifle. Pair it with a .30-06 magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a3006"),
		list("id" = "garand/feed/3006", "family" = "garand", "slot" = FIREARM_SLOT_FEED, "name" = "M1 Garand magazine (.30-06)",
			"desc" = "A fixed magazine for eight-round en-bloc clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a3006", "good_mags" = springfield_clips, "ammo_type" = /obj/item/ammo_casing/a3006),
		list("id" = "garand/furniture/stock", "family" = "garand", "slot" = FIREARM_SLOT_FURNITURE, "name" = "M1 Garand stock",
			"desc" = "A wooden M1 Garand stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "m1carbine/action", "family" = "m1carbine", "slot" = FIREARM_SLOT_ACTION, "name" = "M1 Carbine bolt carrier",
			"desc" = "The bolt carrier of a M1 Carbine rifle. Fits any M1 Carbine receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "m1carbine/barrel/762x33", "family" = "m1carbine", "slot" = FIREARM_SLOT_BARREL, "name" = "M1 Carbine barrel (7.62x33mm)",
			"desc" = "A 7.62x33mm barrel for a M1 Carbine rifle. Pair it with a 7.62x33mm magazine.", "icon_state" = "Carbine Barrel", "caliber" = "a762x33"),
		list("id" = "m1carbine/feed/762x33", "family" = "m1carbine", "slot" = FIREARM_SLOT_FEED, "name" = "M1 Carbine magazine well (7.62x33mm)",
			"desc" = "A magazine well for M1 Carbine magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x33", "good_mags" = m1carbine_mags, "ammo_type" = /obj/item/ammo_casing/a762x33),
		list("id" = "m1carbine/furniture/stock", "family" = "m1carbine", "slot" = FIREARM_SLOT_FURNITURE, "name" = "M1 Carbine stock",
			"desc" = "A wooden M1 Carbine stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "avtomat/action", "family" = "avtomat", "slot" = FIREARM_SLOT_ACTION, "name" = "Fedorov bolt carrier",
			"desc" = "The bolt carrier of a Fedorov rifle. Fits any Fedorov receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "avtomat/barrel/65x50", "family" = "avtomat", "slot" = FIREARM_SLOT_BARREL, "name" = "Fedorov barrel (6.5x50mm)",
			"desc" = "A 6.5x50mm barrel for a Fedorov rifle. Pair it with a 6.5x50mm magazine.", "icon_state" = "Rifle Barrel", "caliber" = "a65x50"),
		list("id" = "avtomat/feed/65x50", "family" = "avtomat", "slot" = FIREARM_SLOT_FEED, "name" = "Fedorov magazine well (6.5x50mm)",
			"desc" = "A magazine well for Fedorov Avtomat magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a65x50", "good_mags" = avtomat_mags, "ammo_type" = /obj/item/ammo_casing/a65x50),
		list("id" = "avtomat/furniture/stock", "family" = "avtomat", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Fedorov stock",
			"desc" = "A wooden Fedorov Avtomat stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "vg5/action", "family" = "vg5", "slot" = FIREARM_SLOT_ACTION, "name" = "Volkssturmkarabiner bolt carrier",
			"desc" = "The bolt carrier of a Volkssturmkarabiner rifle. Fits any Volkssturmkarabiner receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "vg5/barrel/792x33", "family" = "vg5", "slot" = FIREARM_SLOT_BARREL, "name" = "Volkssturmkarabiner barrel (7.92x33mm Kurz)",
			"desc" = "A 7.92x33mm Kurz barrel for a Volkssturmkarabiner rifle. Pair it with a 7.92x33mm Kurz magazine.", "icon_state" = "Carbine Barrel", "caliber" = "a792x33"),
		list("id" = "vg5/feed/792x33", "family" = "vg5", "slot" = FIREARM_SLOT_FEED, "name" = "Volkssturmkarabiner magazine well (7.92x33mm Kurz)",
			"desc" = "A magazine well for StG 44 magazines and 7.92x33mm clips.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a792x33", "good_mags" = vg5_mags, "ammo_type" = /obj/item/ammo_casing/a792x33),
		list("id" = "vg5/furniture/stock", "family" = "vg5", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Volkssturmkarabiner stock",
			"desc" = "A plain wooden Volkssturmkarabiner stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "ptrs/action", "family" = "ptrs", "slot" = FIREARM_SLOT_ACTION, "name" = "PTRS bolt carrier",
			"desc" = "The bolt carrier of a PTRS rifle. Fits any PTRS receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "ptrs/barrel/145", "family" = "ptrs", "slot" = FIREARM_SLOT_BARREL, "name" = "PTRS barrel (14.5x114mm)",
			"desc" = "A 14.5x114mm barrel for a PTRS rifle. Pair it with a 14.5x114mm magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a145"),
		list("id" = "ptrs/feed/145", "family" = "ptrs", "slot" = FIREARM_SLOT_FEED, "name" = "PTRS magazine (14.5x114mm)",
			"desc" = "A fixed five-round magazine loaded from PTRS clips.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a145", "good_mags" = ptrs_clips, "ammo_type" = /obj/item/ammo_casing/a145),
		list("id" = "ptrs/furniture/stock", "family" = "ptrs", "slot" = FIREARM_SLOT_FURNITURE, "name" = "PTRS stock",
			"desc" = "The padded steel stock of a PTRS-41.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "svd/action", "family" = "svd", "slot" = FIREARM_SLOT_ACTION, "name" = "SVD bolt carrier",
			"desc" = "The bolt carrier of a SVD rifle. Fits any SVD receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "svd/barrel/762x54", "family" = "svd", "slot" = FIREARM_SLOT_BARREL, "name" = "SVD barrel (7.62x54mmR)",
			"desc" = "A 7.62x54mmR barrel for a SVD rifle. Pair it with a 7.62x54mmR magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a762x54"),
		list("id" = "svd/feed/762x54", "family" = "svd", "slot" = FIREARM_SLOT_FEED, "name" = "SVD magazine well (7.62x54mmR)",
			"desc" = "A magazine well for SVD magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x54", "good_mags" = svd_mags, "ammo_type" = /obj/item/ammo_casing/a762x54),
		list("id" = "svd/furniture/stock", "family" = "svd", "slot" = FIREARM_SLOT_FURNITURE, "name" = "SVD stock",
			"desc" = "A wooden SVD thumbhole stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "vss/action", "family" = "vss", "slot" = FIREARM_SLOT_ACTION, "name" = "VSS bolt carrier",
			"desc" = "The bolt carrier of a VSS rifle. Fits any VSS receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "vss/barrel/9x39", "family" = "vss", "slot" = FIREARM_SLOT_BARREL, "name" = "VSS barrel (9x39mm)",
			"desc" = "A 9x39mm barrel for a VSS rifle. Pair it with a 9x39mm magazine.", "icon_state" = "Carbine Barrel", "caliber" = "a9x39"),
		list("id" = "vss/feed/9x39", "family" = "vss", "slot" = FIREARM_SLOT_FEED, "name" = "VSS magazine well (9x39mm)",
			"desc" = "A magazine well for VSS Vintorez magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x39", "good_mags" = vss_mags, "ammo_type" = /obj/item/ammo_casing/a9x39),
		list("id" = "vss/furniture/stock", "family" = "vss", "slot" = FIREARM_SLOT_FURNITURE, "name" = "VSS stock",
			"desc" = "A wooden VSS skeleton stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "m82/action", "family" = "m82", "slot" = FIREARM_SLOT_ACTION, "name" = "Barrett M82 bolt carrier",
			"desc" = "The bolt carrier of a Barrett M82 rifle. Fits any Barrett M82 receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "m82/barrel/50cal", "family" = "m82", "slot" = FIREARM_SLOT_BARREL, "name" = "Barrett M82 barrel (.50 BMG)",
			"desc" = "A .50 BMG barrel for a Barrett M82 rifle. Pair it with a .50 BMG magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a50cal"),
		list("id" = "m82/feed/50cal", "family" = "m82", "slot" = FIREARM_SLOT_FEED, "name" = "Barrett M82 magazine well (.50 BMG)",
			"desc" = "A magazine well for Barrett M82 magazines.", "icon_state" = "Large External Magazine_unloaded",
			"caliber" = "a50cal", "good_mags" = m82_mags, "ammo_type" = barrett_rounds),
		list("id" = "m82/furniture/stock", "family" = "m82", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Barrett M82 stock",
			"desc" = "The steel stock of a Barrett M82.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "bamr/action", "family" = "bamr", "slot" = FIREARM_SLOT_ACTION, "name" = "BAMR bolt carrier",
			"desc" = "The bolt carrier of a BAMR rifle. Fits any BAMR receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "bamr/barrel/15115", "family" = "bamr", "slot" = FIREARM_SLOT_BARREL, "name" = "BAMR barrel (15x115mm)",
			"desc" = "A 15x115mm barrel for a BAMR rifle. Pair it with a 15x115mm magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a15115"),
		list("id" = "bamr/feed/15115", "family" = "bamr", "slot" = FIREARM_SLOT_FEED, "name" = "BAMR magazine well (15x115mm)",
			"desc" = "A magazine well for BAMR magazines.", "icon_state" = "Large External Magazine_unloaded",
			"caliber" = "a15115", "good_mags" = bamr_mags, "ammo_type" = bamr_rounds),
		list("id" = "bamr/furniture/stock", "family" = "bamr", "slot" = FIREARM_SLOT_FURNITURE, "name" = "BAMR stock",
			"desc" = "The steel stock of a BAMR.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "lever/action", "family" = "lever", "slot" = FIREARM_SLOT_ACTION, "name" = "lever action",
			"desc" = "The lever of a Lever-action rifle. Fits any Lever-action receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "lever/barrel/44", "family" = "lever", "slot" = FIREARM_SLOT_BARREL, "name" = "Lever-action barrel (.44-40)",
			"desc" = "A .44-40 barrel for a Lever-action rifle. Pair it with a .44-40 magazine.", "icon_state" = "Rifle Barrel", "caliber" = "a44"),
		list("id" = "lever/barrel/357", "family" = "lever", "slot" = FIREARM_SLOT_BARREL, "name" = "Lever-action barrel (.357 Magnum)",
			"desc" = "A .357 Magnum barrel for a Lever-action rifle. Pair it with a .357 Magnum magazine.", "icon_state" = "Carbine Barrel", "caliber" = "a357"),
		list("id" = "lever/barrel/4570", "family" = "lever", "slot" = FIREARM_SLOT_BARREL, "name" = "Lever-action barrel (.45-70)",
			"desc" = "A .45-70 barrel for a Lever-action rifle. Pair it with a .45-70 magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "a4570"),
		list("id" = "lever/feed/44", "family" = "lever", "slot" = FIREARM_SLOT_FEED, "name" = "Lever-action tube magazine (.44-40)",
			"desc" = "A tube magazine under the barrel, loaded a round at a time. Its length stays with the rifle.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a44", "ammo_type" = /obj/item/ammo_casing/a44),
		list("id" = "lever/feed/357", "family" = "lever", "slot" = FIREARM_SLOT_FEED, "name" = "Lever-action tube magazine (.357 Magnum)",
			"desc" = "A tube magazine under the barrel, loaded a round at a time. Its length stays with the rifle.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a357", "ammo_type" = /obj/item/ammo_casing/a357),
		list("id" = "lever/feed/4570", "family" = "lever", "slot" = FIREARM_SLOT_FEED, "name" = "Lever-action tube magazine (.45-70)",
			"desc" = "A tube magazine under the barrel, loaded a round at a time. Its length stays with the rifle.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a4570", "ammo_type" = /obj/item/ammo_casing/a4570),
		list("id" = "lever/furniture/stock", "family" = "lever", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Lever-action stock",
			"desc" = "A wooden lever-action rifle stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "nambu/action", "family" = "nambu", "slot" = FIREARM_SLOT_ACTION, "name" = "Nambu slide",
			"desc" = "The slide of a Nambu pistol. Fits any Nambu frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "nambu/barrel/8mm", "family" = "nambu", "slot" = FIREARM_SLOT_BARREL, "name" = "Nambu barrel (8mm Nambu)",
			"desc" = "A 8mm Nambu barrel for a Nambu pistol. Pair it with a 8mm Nambu magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "c8mmnambu"),
		list("id" = "nambu/feed/8mm", "family" = "nambu", "slot" = FIREARM_SLOT_FEED, "name" = "Nambu magazine well (8mm Nambu)",
			"desc" = "A magazine well for 8mm Nambu Nambu magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "c8mmnambu", "good_mags" = list(/obj/item/ammo_magazine/c8mmnambu, /obj/item/ammo_magazine/c8mmnambu/empty), "ammo_type" = /obj/item/ammo_casing/c8mmnambu),
		list("id" = "nambu/furniture/grip", "family" = "nambu", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Nambu grip",
			"desc" = "A wooden Nambu grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "bergmann/action", "family" = "bergmann", "slot" = FIREARM_SLOT_ACTION, "name" = "Bergmann slide",
			"desc" = "The slide of a Bergmann pistol. Fits any Bergmann frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "bergmann/barrel/8mm", "family" = "bergmann", "slot" = FIREARM_SLOT_BARREL, "name" = "Bergmann barrel (8mm Nambu)",
			"desc" = "A 8mm Nambu barrel for a Bergmann pistol. Pair it with a 8mm Nambu magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "c8mmnambu"),
		list("id" = "bergmann/feed/8mm", "family" = "bergmann", "slot" = FIREARM_SLOT_FEED, "name" = "Bergmann magazine well (8mm Nambu)",
			"desc" = "A magazine well for 8mm Nambu Bergmann magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "c8mmnambu", "good_mags" = list(/obj/item/ammo_magazine/bergmann), "ammo_type" = /obj/item/ammo_casing/c8mmnambu),
		list("id" = "bergmann/furniture/grip", "family" = "bergmann", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Bergmann grip",
			"desc" = "A wooden Bergmann grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "luger/action", "family" = "luger", "slot" = FIREARM_SLOT_ACTION, "name" = "Luger slide",
			"desc" = "The slide of a Luger pistol. Fits any Luger frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "luger/barrel/9x19", "family" = "luger", "slot" = FIREARM_SLOT_BARREL, "name" = "Luger barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a Luger pistol. Pair it with a 9x19mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a9x19"),
		list("id" = "luger/feed/9x19", "family" = "luger", "slot" = FIREARM_SLOT_FEED, "name" = "Luger magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm Luger magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/luger, /obj/item/ammo_magazine/luger/empty), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "luger/furniture/grip", "family" = "luger", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Luger grip",
			"desc" = "A wooden Luger grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "walther/action", "family" = "walther", "slot" = FIREARM_SLOT_ACTION, "name" = "Walther P38 slide",
			"desc" = "The slide of a Walther P38 pistol. Fits any Walther P38 frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "walther/barrel/9x19", "family" = "walther", "slot" = FIREARM_SLOT_BARREL, "name" = "Walther P38 barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a Walther P38 pistol. Pair it with a 9x19mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a9x19"),
		list("id" = "walther/feed/9x19", "family" = "walther", "slot" = FIREARM_SLOT_FEED, "name" = "Walther P38 magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm Walther P38 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/walther), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "walther/furniture/grip", "family" = "walther", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Walther P38 grip",
			"desc" = "A wooden Walther P38 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "browninghp/action", "family" = "browninghp", "slot" = FIREARM_SLOT_ACTION, "name" = "Browning Hi-Power slide",
			"desc" = "The slide of a Browning Hi-Power pistol. Fits any Browning Hi-Power frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "browninghp/barrel/9x19", "family" = "browninghp", "slot" = FIREARM_SLOT_BARREL, "name" = "Browning Hi-Power barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a Browning Hi-Power pistol. Pair it with a 9x19mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a9x19"),
		list("id" = "browninghp/feed/9x19", "family" = "browninghp", "slot" = FIREARM_SLOT_FEED, "name" = "Browning Hi-Power magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm Browning Hi-Power magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/browninghp), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "browninghp/furniture/grip", "family" = "browninghp", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Browning Hi-Power grip",
			"desc" = "A wooden Browning Hi-Power grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "c96/action", "family" = "c96", "slot" = FIREARM_SLOT_ACTION, "name" = "Mauser C96 slide",
			"desc" = "The slide of a Mauser C96 pistol. Fits any Mauser C96 frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "c96/barrel/762x25", "family" = "c96", "slot" = FIREARM_SLOT_BARREL, "name" = "Mauser C96 barrel (7.62x25mm)",
			"desc" = "A 7.62x25mm barrel for a Mauser C96 pistol. Pair it with a 7.62x25mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a762x25"),
		list("id" = "c96/feed/762x25", "family" = "c96", "slot" = FIREARM_SLOT_FEED, "name" = "Mauser C96 magazine well (7.62x25mm)",
			"desc" = "A fixed ten-round magazine loaded from stripper clips.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x25", "good_mags" = list(/obj/item/ammo_magazine/mauser), "ammo_type" = /obj/item/ammo_casing/a762x25),
		list("id" = "c96/furniture/grip", "family" = "c96", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Mauser C96 grip",
			"desc" = "A wooden Mauser C96 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "borchardt/action", "family" = "borchardt", "slot" = FIREARM_SLOT_ACTION, "name" = "Borchardt slide",
			"desc" = "The slide of a Borchardt pistol. Fits any Borchardt frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "borchardt/barrel/765x25", "family" = "borchardt", "slot" = FIREARM_SLOT_BARREL, "name" = "Borchardt barrel (7.65x25mm)",
			"desc" = "A 7.65x25mm barrel for a Borchardt pistol. Pair it with a 7.65x25mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a765x25"),
		list("id" = "borchardt/feed/765x25", "family" = "borchardt", "slot" = FIREARM_SLOT_FEED, "name" = "Borchardt magazine well (7.65x25mm)",
			"desc" = "A magazine well for 7.65x25mm Borchardt magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a765x25", "good_mags" = list(/obj/item/ammo_magazine/borchardt, /obj/item/ammo_magazine/borchardt/empty), "ammo_type" = /obj/item/ammo_casing/a765x25),
		list("id" = "borchardt/furniture/grip", "family" = "borchardt", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Borchardt grip",
			"desc" = "A wooden Borchardt grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "colthammerless/action", "family" = "colthammerless", "slot" = FIREARM_SLOT_ACTION, "name" = "Colt Pocket Hammerless slide",
			"desc" = "The slide of a Colt Pocket Hammerless pistol. Fits any Colt Pocket Hammerless frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "colthammerless/barrel/32acp", "family" = "colthammerless", "slot" = FIREARM_SLOT_BARREL, "name" = "Colt Pocket Hammerless barrel (.32 ACP)",
			"desc" = "A .32 ACP barrel for a Colt Pocket Hammerless pistol. Pair it with a .32 ACP magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a32acp"),
		list("id" = "colthammerless/barrel/380acp", "family" = "colthammerless", "slot" = FIREARM_SLOT_BARREL, "name" = "Colt Pocket Hammerless barrel (.380 ACP)",
			"desc" = "A .380 ACP barrel for a Colt Pocket Hammerless pistol. Pair it with a .380 ACP magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a380acp"),
		list("id" = "colthammerless/feed/32acp", "family" = "colthammerless", "slot" = FIREARM_SLOT_FEED, "name" = "Colt Pocket Hammerless magazine well (.32 ACP)",
			"desc" = "A magazine well for .32 ACP Colt Pocket Hammerless magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a32acp", "good_mags" = list(/obj/item/ammo_magazine/colthammerless), "ammo_type" = /obj/item/ammo_casing/a32acp),
		list("id" = "colthammerless/feed/380acp", "family" = "colthammerless", "slot" = FIREARM_SLOT_FEED, "name" = "Colt Pocket Hammerless magazine well (.380 ACP)",
			"desc" = "A magazine well for .380 ACP Colt Pocket Hammerless magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a380acp", "good_mags" = list(/obj/item/ammo_magazine/colthammerless/a380acp), "ammo_type" = /obj/item/ammo_casing/a380acp),
		list("id" = "colthammerless/furniture/grip", "family" = "colthammerless", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Colt Pocket Hammerless grip",
			"desc" = "A wooden Colt Pocket Hammerless grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "m1911/action", "family" = "m1911", "slot" = FIREARM_SLOT_ACTION, "name" = "M1911 slide",
			"desc" = "The slide of a M1911 pistol. Fits any M1911 frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "m1911/barrel/45acp", "family" = "m1911", "slot" = FIREARM_SLOT_BARREL, "name" = "M1911 barrel (.45 ACP)",
			"desc" = "A .45 ACP barrel for a M1911 pistol. Pair it with a .45 ACP magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a45acp"),
		list("id" = "m1911/feed/45acp", "family" = "m1911", "slot" = FIREARM_SLOT_FEED, "name" = "M1911 magazine well (.45 ACP)",
			"desc" = "A magazine well for .45 ACP M1911 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a45acp", "good_mags" = list(/obj/item/ammo_magazine/m1911, /obj/item/ammo_magazine/m1911/empty), "ammo_type" = /obj/item/ammo_casing/a45acp),
		list("id" = "m1911/feed/45acp_2011", "family" = "m1911", "slot" = FIREARM_SLOT_FEED, "name" = "M1911 2011 grip module (.45 ACP)",
			"desc" = "A double-stack 2011 grip module for STI 2011 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a45acp", "good_mags" = list(/obj/item/ammo_magazine/sti2011), "ammo_type" = /obj/item/ammo_casing/a45acp),
		list("id" = "m1911/furniture/grip", "family" = "m1911", "slot" = FIREARM_SLOT_FURNITURE, "name" = "M1911 grip",
			"desc" = "A wooden M1911 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "tt/action", "family" = "tt", "slot" = FIREARM_SLOT_ACTION, "name" = "Tokarev slide",
			"desc" = "The slide of a Tokarev pistol. Fits any Tokarev frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "tt/barrel/762x25", "family" = "tt", "slot" = FIREARM_SLOT_BARREL, "name" = "Tokarev barrel (7.62x25mm)",
			"desc" = "A 7.62x25mm barrel for a Tokarev pistol. Pair it with a 7.62x25mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a762x25"),
		list("id" = "tt/feed/762x25", "family" = "tt", "slot" = FIREARM_SLOT_FEED, "name" = "Tokarev magazine well (7.62x25mm)",
			"desc" = "A magazine well for 7.62x25mm Tokarev magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x25", "good_mags" = list(/obj/item/ammo_magazine/tt30, /obj/item/ammo_magazine/tt30ll, /obj/item/ammo_magazine/tt30/empty, /obj/item/ammo_magazine/tt30ll/rubber), "ammo_type" = /obj/item/ammo_casing/a762x25),
		list("id" = "tt/furniture/grip", "family" = "tt", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Tokarev grip",
			"desc" = "A wooden Tokarev grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "makarov/action", "family" = "makarov", "slot" = FIREARM_SLOT_ACTION, "name" = "Makarov slide",
			"desc" = "The slide of a Makarov pistol. Fits any Makarov frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "makarov/barrel/9x18", "family" = "makarov", "slot" = FIREARM_SLOT_BARREL, "name" = "Makarov barrel (9x18mm)",
			"desc" = "A 9x18mm barrel for a Makarov pistol. Pair it with a 9x18mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a9x18"),
		list("id" = "makarov/feed/9x18", "family" = "makarov", "slot" = FIREARM_SLOT_FEED, "name" = "Makarov magazine well (9x18mm)",
			"desc" = "A magazine well for 9x18mm Makarov magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x18", "good_mags" = list(/obj/item/ammo_magazine/makarov, /obj/item/ammo_magazine/makarov/empty), "ammo_type" = /obj/item/ammo_casing/a9x18),
		list("id" = "makarov/furniture/grip", "family" = "makarov", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Makarov grip",
			"desc" = "A polymer Makarov grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "aps/action", "family" = "aps", "slot" = FIREARM_SLOT_ACTION, "name" = "Stechkin slide",
			"desc" = "The slide of a Stechkin pistol. Fits any Stechkin frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "aps/barrel/9x18", "family" = "aps", "slot" = FIREARM_SLOT_BARREL, "name" = "Stechkin barrel (9x18mm)",
			"desc" = "A 9x18mm barrel for a Stechkin pistol. Pair it with a 9x18mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a9x18"),
		list("id" = "aps/feed/9x18", "family" = "aps", "slot" = FIREARM_SLOT_FEED, "name" = "Stechkin magazine well (9x18mm)",
			"desc" = "A magazine well for 9x18mm Stechkin magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x18", "good_mags" = list(/obj/item/ammo_magazine/aps, /obj/item/ammo_magazine/aps/empty), "ammo_type" = /obj/item/ammo_casing/a9x18),
		list("id" = "aps/furniture/grip", "family" = "aps", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Stechkin grip",
			"desc" = "A polymer Stechkin grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "glock/action", "family" = "glock", "slot" = FIREARM_SLOT_ACTION, "name" = "Glock slide",
			"desc" = "The slide of a Glock pistol. Fits any Glock frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "glock/barrel/9x19", "family" = "glock", "slot" = FIREARM_SLOT_BARREL, "name" = "Glock barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a Glock pistol. Pair it with a 9x19mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a9x19"),
		list("id" = "glock/feed/9x19", "family" = "glock", "slot" = FIREARM_SLOT_FEED, "name" = "Glock magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm Glock magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/glock17), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "glock/furniture/grip", "family" = "glock", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Glock grip",
			"desc" = "A polymer Glock grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "beretta/action", "family" = "beretta", "slot" = FIREARM_SLOT_ACTION, "name" = "Beretta M9 slide",
			"desc" = "The slide of a Beretta M9 pistol. Fits any Beretta M9 frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "beretta/barrel/9x19", "family" = "beretta", "slot" = FIREARM_SLOT_BARREL, "name" = "Beretta M9 barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a Beretta M9 pistol. Pair it with a 9x19mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a9x19"),
		list("id" = "beretta/feed/9x19", "family" = "beretta", "slot" = FIREARM_SLOT_FEED, "name" = "Beretta M9 magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm Beretta M9 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/m9beretta), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "beretta/furniture/grip", "family" = "beretta", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Beretta M9 grip",
			"desc" = "A polymer Beretta M9 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "jericho/action", "family" = "jericho", "slot" = FIREARM_SLOT_ACTION, "name" = "Jericho 941 slide",
			"desc" = "The slide of a Jericho 941 pistol. Fits any Jericho 941 frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "jericho/barrel/9x19", "family" = "jericho", "slot" = FIREARM_SLOT_BARREL, "name" = "Jericho 941 barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a Jericho 941 pistol. Pair it with a 9x19mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a9x19"),
		list("id" = "jericho/feed/9x19", "family" = "jericho", "slot" = FIREARM_SLOT_FEED, "name" = "Jericho 941 magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm Jericho 941 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/jericho), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "jericho/furniture/grip", "family" = "jericho", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Jericho 941 grip",
			"desc" = "A polymer Jericho 941 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "sig250/action", "family" = "sig250", "slot" = FIREARM_SLOT_ACTION, "name" = "SIG 250 slide",
			"desc" = "The slide of a SIG 250 pistol. Fits any SIG 250 frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "sig250/barrel/9x19", "family" = "sig250", "slot" = FIREARM_SLOT_BARREL, "name" = "SIG 250 barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a SIG 250 pistol. Pair it with a 9x19mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a9x19"),
		list("id" = "sig250/feed/9x19", "family" = "sig250", "slot" = FIREARM_SLOT_FEED, "name" = "SIG 250 magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm SIG 250 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/sig250), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "sig250/furniture/grip", "family" = "sig250", "slot" = FIREARM_SLOT_FURNITURE, "name" = "SIG 250 grip",
			"desc" = "A polymer SIG 250 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "p220/action", "family" = "p220", "slot" = FIREARM_SLOT_ACTION, "name" = "SIG P220 slide",
			"desc" = "The slide of a SIG P220 pistol. Fits any SIG P220 frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "p220/barrel/45", "family" = "p220", "slot" = FIREARM_SLOT_BARREL, "name" = "SIG P220 barrel (.45)",
			"desc" = "A .45 barrel for a SIG P220 pistol. Pair it with a .45 magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a45"),
		list("id" = "p220/feed/45", "family" = "p220", "slot" = FIREARM_SLOT_FEED, "name" = "SIG P220 magazine well (.45)",
			"desc" = "A magazine well for .45 SIG P220 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a45", "good_mags" = list(/obj/item/ammo_magazine/p220), "ammo_type" = /obj/item/ammo_casing/a45),
		list("id" = "p220/furniture/grip", "family" = "p220", "slot" = FIREARM_SLOT_FURNITURE, "name" = "SIG P220 grip",
			"desc" = "A polymer SIG P220 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "pl14/action", "family" = "pl14", "slot" = FIREARM_SLOT_ACTION, "name" = "PL-14 slide",
			"desc" = "The slide of a PL-14 pistol. Fits any PL-14 frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "pl14/barrel/9x19", "family" = "pl14", "slot" = FIREARM_SLOT_BARREL, "name" = "PL-14 barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a PL-14 pistol. Pair it with a 9x19mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a9x19"),
		list("id" = "pl14/feed/9x19", "family" = "pl14", "slot" = FIREARM_SLOT_FEED, "name" = "PL-14 magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm PL-14 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/pl14), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "pl14/furniture/grip", "family" = "pl14", "slot" = FIREARM_SLOT_FURNITURE, "name" = "PL-14 grip",
			"desc" = "A polymer PL-14 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "mp443/action", "family" = "mp443", "slot" = FIREARM_SLOT_ACTION, "name" = "MP-443 slide",
			"desc" = "The slide of a MP-443 pistol. Fits any MP-443 frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "mp443/barrel/9x19", "family" = "mp443", "slot" = FIREARM_SLOT_BARREL, "name" = "MP-443 barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a MP-443 pistol. Pair it with a 9x19mm magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a9x19"),
		list("id" = "mp443/feed/9x19", "family" = "mp443", "slot" = FIREARM_SLOT_FEED, "name" = "MP-443 magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm MP-443 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/mp443), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "mp443/furniture/grip", "family" = "mp443", "slot" = FIREARM_SLOT_FURNITURE, "name" = "MP-443 grip",
			"desc" = "A polymer MP-443 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "deagle/action", "family" = "deagle", "slot" = FIREARM_SLOT_ACTION, "name" = "Desert Eagle slide",
			"desc" = "The slide of a Desert Eagle pistol. Fits any Desert Eagle frame.", "icon_state" = "Semi-Auto (small)"),
		list("id" = "deagle/barrel/50ae", "family" = "deagle", "slot" = FIREARM_SLOT_BARREL, "name" = "Desert Eagle barrel (.50 AE)",
			"desc" = "A .50 AE barrel for a Desert Eagle pistol. Pair it with a .50 AE magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a50cal"),
		list("id" = "deagle/barrel/44magnum", "family" = "deagle", "slot" = FIREARM_SLOT_BARREL, "name" = "Desert Eagle barrel (.44 Magnum)",
			"desc" = "A .44 Magnum barrel for a Desert Eagle pistol. Pair it with a .44 Magnum magazine well.", "icon_state" = "Pistol Barrel", "caliber" = "a44magnum"),
		list("id" = "deagle/feed/50ae", "family" = "deagle", "slot" = FIREARM_SLOT_FEED, "name" = "Desert Eagle magazine well (.50 AE)",
			"desc" = "A magazine well for .50 AE Desert Eagle magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a50cal", "good_mags" = list(/obj/item/ammo_magazine/deagle), "ammo_type" = /obj/item/ammo_casing/a50cal),
		list("id" = "deagle/feed/44magnum", "family" = "deagle", "slot" = FIREARM_SLOT_FEED, "name" = "Desert Eagle magazine well (.44 Magnum)",
			"desc" = "A magazine well for .44 Magnum Desert Eagle magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a44magnum", "good_mags" = list(/obj/item/ammo_magazine/deaglemagnum), "ammo_type" = /obj/item/ammo_casing/a44magnum),
		list("id" = "deagle/furniture/grip", "family" = "deagle", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Desert Eagle grip",
			"desc" = "A polymer Desert Eagle grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "nagant/action", "family" = "nagant", "slot" = FIREARM_SLOT_ACTION, "name" = "Nagant lockwork",
			"desc" = "The lockwork of a Nagant revolver. Fits any Nagant frame.", "icon_state" = "Revolver"),
		list("id" = "nagant/barrel/762x38", "family" = "nagant", "slot" = FIREARM_SLOT_BARREL, "name" = "Nagant barrel (7.62x38mmR)",
			"desc" = "A 7.62x38mmR barrel for a Nagant revolver. Pair it with a 7.62x38mmR cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a762x38"),
		list("id" = "nagant/feed/762x38", "family" = "nagant", "slot" = FIREARM_SLOT_FEED, "name" = "Nagant cylinder (7.62x38mmR)",
			"desc" = "A 7.62x38mmR cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a762x38", "ammo_type" = /obj/item/ammo_casing/a762x38),
		list("id" = "nagant/furniture/grip", "family" = "nagant", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Nagant grip",
			"desc" = "A wooden Nagant grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "m1892/action", "family" = "m1892", "slot" = FIREARM_SLOT_ACTION, "name" = "Modele 1892 lockwork",
			"desc" = "The lockwork of a Modele 1892 revolver. Fits any Modele 1892 frame.", "icon_state" = "Revolver"),
		list("id" = "m1892/barrel/8x27", "family" = "m1892", "slot" = FIREARM_SLOT_BARREL, "name" = "Modele 1892 barrel (8x27mmR)",
			"desc" = "A 8x27mmR barrel for a Modele 1892 revolver. Pair it with a 8x27mmR cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a8x27"),
		list("id" = "m1892/feed/8x27", "family" = "m1892", "slot" = FIREARM_SLOT_FEED, "name" = "Modele 1892 cylinder (8x27mmR)",
			"desc" = "A 8x27mmR cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a8x27", "ammo_type" = /obj/item/ammo_casing/a8x27),
		list("id" = "m1892/furniture/grip", "family" = "m1892", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Modele 1892 grip",
			"desc" = "A wooden Modele 1892 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "colt_saa/action", "family" = "colt_saa", "slot" = FIREARM_SLOT_ACTION, "name" = "Colt Single Action lockwork",
			"desc" = "The lockwork of a Colt Single Action revolver. Fits any Colt Single Action frame.", "icon_state" = "Revolver"),
		list("id" = "colt_saa/barrel/45", "family" = "colt_saa", "slot" = FIREARM_SLOT_BARREL, "name" = "Colt Single Action barrel (.45 Colt)",
			"desc" = "A .45 Colt barrel for a Colt Single Action revolver. Pair it with a .45 Colt cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a45"),
		list("id" = "colt_saa/barrel/44", "family" = "colt_saa", "slot" = FIREARM_SLOT_BARREL, "name" = "Colt Single Action barrel (.44-40)",
			"desc" = "A .44-40 barrel for a Colt Single Action revolver. Pair it with a .44-40 cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a44"),
		list("id" = "colt_saa/feed/45", "family" = "colt_saa", "slot" = FIREARM_SLOT_FEED, "name" = "Colt Single Action cylinder (.45 Colt)",
			"desc" = "A .45 Colt cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a45", "ammo_type" = /obj/item/ammo_casing/a45),
		list("id" = "colt_saa/feed/44", "family" = "colt_saa", "slot" = FIREARM_SLOT_FEED, "name" = "Colt Single Action cylinder (.44-40)",
			"desc" = "A .44-40 cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a44", "ammo_type" = /obj/item/ammo_casing/a44),
		list("id" = "colt_saa/furniture/grip", "family" = "colt_saa", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Colt Single Action grip",
			"desc" = "A wooden Colt Single Action grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "colt1892/action", "family" = "colt1892", "slot" = FIREARM_SLOT_ACTION, "name" = "Colt M1892 lockwork",
			"desc" = "The lockwork of a Colt M1892 revolver. Fits any Colt M1892 frame.", "icon_state" = "Revolver"),
		list("id" = "colt1892/barrel/38", "family" = "colt1892", "slot" = FIREARM_SLOT_BARREL, "name" = "Colt M1892 barrel (.38)",
			"desc" = "A .38 barrel for a Colt M1892 revolver. Pair it with a .38 cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a38"),
		list("id" = "colt1892/feed/38", "family" = "colt1892", "slot" = FIREARM_SLOT_FEED, "name" = "Colt M1892 cylinder (.38)",
			"desc" = "A .38 cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a38", "ammo_type" = /obj/item/ammo_casing/a38),
		list("id" = "colt1892/furniture/grip", "family" = "colt1892", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Colt M1892 grip",
			"desc" = "A wooden Colt M1892 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "policepositive/action", "family" = "policepositive", "slot" = FIREARM_SLOT_ACTION, "name" = "Colt Police Positive lockwork",
			"desc" = "The lockwork of a Colt Police Positive revolver. Fits any Colt Police Positive frame.", "icon_state" = "Revolver"),
		list("id" = "policepositive/barrel/32", "family" = "policepositive", "slot" = FIREARM_SLOT_BARREL, "name" = "Colt Police Positive barrel (.32)",
			"desc" = "A .32 barrel for a Colt Police Positive revolver. Pair it with a .32 cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a32"),
		list("id" = "policepositive/feed/32", "family" = "policepositive", "slot" = FIREARM_SLOT_FEED, "name" = "Colt Police Positive cylinder (.32)",
			"desc" = "A .32 cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a32", "ammo_type" = /obj/item/ammo_casing/a32),
		list("id" = "policepositive/furniture/grip", "family" = "policepositive", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Colt Police Positive grip",
			"desc" = "A wooden Colt Police Positive grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "smithwesson/action", "family" = "smithwesson", "slot" = FIREARM_SLOT_ACTION, "name" = "Smith & Wesson lockwork",
			"desc" = "The lockwork of a Smith & Wesson revolver. Fits any Smith & Wesson frame.", "icon_state" = "Revolver"),
		list("id" = "smithwesson/barrel/32", "family" = "smithwesson", "slot" = FIREARM_SLOT_BARREL, "name" = "Smith & Wesson barrel (.32)",
			"desc" = "A .32 barrel for a Smith & Wesson revolver. Pair it with a .32 cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a32"),
		list("id" = "smithwesson/barrel/38", "family" = "smithwesson", "slot" = FIREARM_SLOT_BARREL, "name" = "Smith & Wesson barrel (.38)",
			"desc" = "A .38 barrel for a Smith & Wesson revolver. Pair it with a .38 cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a38"),
		list("id" = "smithwesson/feed/32", "family" = "smithwesson", "slot" = FIREARM_SLOT_FEED, "name" = "Smith & Wesson cylinder (.32)",
			"desc" = "A .32 cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a32", "ammo_type" = /obj/item/ammo_casing/a32),
		list("id" = "smithwesson/feed/38", "family" = "smithwesson", "slot" = FIREARM_SLOT_FEED, "name" = "Smith & Wesson cylinder (.38)",
			"desc" = "A .38 cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a38", "ammo_type" = /obj/item/ammo_casing/a38),
		list("id" = "smithwesson/furniture/grip", "family" = "smithwesson", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Smith & Wesson grip",
			"desc" = "A wooden Smith & Wesson grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "enfieldno2/action", "family" = "enfieldno2", "slot" = FIREARM_SLOT_ACTION, "name" = "Enfield No. 2 lockwork",
			"desc" = "The lockwork of an Enfield No. 2 revolver. Fits any Enfield No. 2 frame.", "icon_state" = "Revolver"),
		list("id" = "enfieldno2/barrel/41", "family" = "enfieldno2", "slot" = FIREARM_SLOT_BARREL, "name" = "Enfield No. 2 barrel (.41)",
			"desc" = "A .41 barrel for an Enfield No. 2 revolver. Pair it with a .41 cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a41"),
		list("id" = "enfieldno2/feed/41", "family" = "enfieldno2", "slot" = FIREARM_SLOT_FEED, "name" = "Enfield No. 2 cylinder (.41)",
			"desc" = "A .41 cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a41", "ammo_type" = /obj/item/ammo_casing/a41),
		list("id" = "enfieldno2/furniture/grip", "family" = "enfieldno2", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Enfield No. 2 grip",
			"desc" = "A wooden Enfield No. 2 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "webley/action", "family" = "webley", "slot" = FIREARM_SLOT_ACTION, "name" = "Webley lockwork",
			"desc" = "The lockwork of a Webley revolver. Fits any Webley frame.", "icon_state" = "Revolver"),
		list("id" = "webley/barrel/455", "family" = "webley", "slot" = FIREARM_SLOT_BARREL, "name" = "Webley barrel (.455 Webley)",
			"desc" = "A .455 Webley barrel for a Webley revolver. Pair it with a .455 Webley cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a455"),
		list("id" = "webley/feed/455", "family" = "webley", "slot" = FIREARM_SLOT_FEED, "name" = "Webley cylinder (.455 Webley)",
			"desc" = "A .455 Webley cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a455", "ammo_type" = /obj/item/ammo_casing/a455),
		list("id" = "webley/furniture/grip", "family" = "webley", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Webley grip",
			"desc" = "A wooden Webley grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "type26/action", "family" = "type26", "slot" = FIREARM_SLOT_ACTION, "name" = "Type 26 lockwork",
			"desc" = "The lockwork of a Type 26 revolver. Fits any Type 26 frame.", "icon_state" = "Revolver"),
		list("id" = "type26/barrel/9mm", "family" = "type26", "slot" = FIREARM_SLOT_BARREL, "name" = "Type 26 barrel (9mm Japanese)",
			"desc" = "A 9mm Japanese barrel for a Type 26 revolver. Pair it with a 9mm Japanese cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "c9mm_jap_revolver"),
		list("id" = "type26/feed/9mm", "family" = "type26", "slot" = FIREARM_SLOT_FEED, "name" = "Type 26 cylinder (9mm Japanese)",
			"desc" = "A 9mm Japanese cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "c9mm_jap_revolver", "ammo_type" = /obj/item/ammo_casing/c9mm_jap_revolver),
		list("id" = "type26/furniture/grip", "family" = "type26", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Type 26 grip",
			"desc" = "A wooden Type 26 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "derringer/action", "family" = "derringer", "slot" = FIREARM_SLOT_ACTION, "name" = "Derringer lockwork",
			"desc" = "The lockwork of a Derringer revolver. Fits any Derringer frame.", "icon_state" = "Revolver"),
		list("id" = "derringer/barrel/41", "family" = "derringer", "slot" = FIREARM_SLOT_BARREL, "name" = "Derringer barrel (.41)",
			"desc" = "A .41 barrel for a Derringer revolver. Pair it with a .41 cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a41"),
		list("id" = "derringer/feed/41", "family" = "derringer", "slot" = FIREARM_SLOT_FEED, "name" = "Derringer cylinder (.41)",
			"desc" = "A two-shot over-and-under breech, loaded a round at a time.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a41", "ammo_type" = /obj/item/ammo_casing/a41),
		list("id" = "derringer/furniture/grip", "family" = "derringer", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Derringer grip",
			"desc" = "A wooden Derringer grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "magnum44/action", "family" = "magnum44", "slot" = FIREARM_SLOT_ACTION, "name" = "Magnum 44 lockwork",
			"desc" = "The lockwork of a Magnum 44 revolver. Fits any Magnum 44 frame.", "icon_state" = "Revolver"),
		list("id" = "magnum44/barrel/44magnum", "family" = "magnum44", "slot" = FIREARM_SLOT_BARREL, "name" = "Magnum 44 barrel (.44 Magnum)",
			"desc" = "A .44 Magnum barrel for a Magnum 44 revolver. Pair it with a .44 Magnum cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a44magnum"),
		list("id" = "magnum44/feed/44magnum", "family" = "magnum44", "slot" = FIREARM_SLOT_FEED, "name" = "Magnum 44 cylinder (.44 Magnum)",
			"desc" = "A .44 Magnum cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a44magnum", "ammo_type" = /obj/item/ammo_casing/a44magnum),
		list("id" = "magnum44/furniture/grip", "family" = "magnum44", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Magnum 44 grip",
			"desc" = "A polymer Magnum 44 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "mckellen/action", "family" = "mckellen", "slot" = FIREARM_SLOT_ACTION, "name" = "Mckellen lockwork",
			"desc" = "The lockwork of a Mckellen revolver. Fits any Mckellen frame.", "icon_state" = "Revolver"),
		list("id" = "mckellen/barrel/44magnum", "family" = "mckellen", "slot" = FIREARM_SLOT_BARREL, "name" = "Mckellen barrel (.44 Magnum)",
			"desc" = "A .44 Magnum barrel for a Mckellen revolver. Pair it with a .44 Magnum cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a44magnum"),
		list("id" = "mckellen/feed/44magnum", "family" = "mckellen", "slot" = FIREARM_SLOT_FEED, "name" = "Mckellen cylinder (.44 Magnum)",
			"desc" = "A .44 Magnum cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a44magnum", "ammo_type" = /obj/item/ammo_casing/a44magnum),
		list("id" = "mckellen/furniture/grip", "family" = "mckellen", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Mckellen grip",
			"desc" = "A polymer Mckellen grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "judge/action", "family" = "judge", "slot" = FIREARM_SLOT_ACTION, "name" = "Taurus Judge lockwork",
			"desc" = "The lockwork of a Taurus Judge revolver. Fits any Taurus Judge frame.", "icon_state" = "Revolver"),
		list("id" = "judge/barrel/45", "family" = "judge", "slot" = FIREARM_SLOT_BARREL, "name" = "Taurus Judge barrel (.45 Colt)",
			"desc" = "A .45 Colt barrel for a Taurus Judge revolver. Pair it with a .45 Colt cylinder.", "icon_state" = "Pistol Barrel", "caliber" = "a45"),
		list("id" = "judge/feed/45", "family" = "judge", "slot" = FIREARM_SLOT_FEED, "name" = "Taurus Judge cylinder (.45 Colt)",
			"desc" = "A .45 Colt cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a45", "ammo_type" = /obj/item/ammo_casing/a45),
		list("id" = "judge/furniture/grip", "family" = "judge", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Taurus Judge grip",
			"desc" = "A polymer Taurus Judge grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "revolving/action", "family" = "revolving", "slot" = FIREARM_SLOT_ACTION, "name" = "Colt Revolving lockwork",
			"desc" = "The lockwork of a Colt Revolving rifle. Fits any Colt Revolving receiver.", "icon_state" = "Revolver"),
		list("id" = "revolving/barrel/44", "family" = "revolving", "slot" = FIREARM_SLOT_BARREL, "name" = "Colt Revolving barrel (.44-40)",
			"desc" = "A .44-40 barrel for a Colt Revolving rifle. Pair it with a .44-40 cylinder.", "icon_state" = "Rifle Barrel", "caliber" = "a44"),
		list("id" = "revolving/feed/44", "family" = "revolving", "slot" = FIREARM_SLOT_FEED, "name" = "Colt Revolving cylinder (.44-40)",
			"desc" = "A .44-40 cylinder, loaded a round at a time or from a speedloader.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "a44", "ammo_type" = /obj/item/ammo_casing/a44),
		list("id" = "revolving/furniture/stock", "family" = "revolving", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Colt Revolving stock",
			"desc" = "A wooden Colt Revolving stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "pump/action", "family" = "pump", "slot" = FIREARM_SLOT_ACTION, "name" = "Pump-action pump action",
			"desc" = "The pump action of a Pump-action shotgun. Fits any Pump-action receiver.", "icon_state" = "Pump-Action"),
		list("id" = "pump/barrel/12g", "family" = "pump", "slot" = FIREARM_SLOT_BARREL, "name" = "Pump-action barrel (12 gauge)",
			"desc" = "A 12 gauge barrel for a Pump-action shotgun. Pair it with a 12 gauge tube magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "12gauge"),
		list("id" = "pump/feed/12g", "family" = "pump", "slot" = FIREARM_SLOT_FEED, "name" = "Pump-action tube magazine (12 gauge)",
			"desc" = "A tube magazine under the barrel, loaded a shell at a time. Its length stays with the gun.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "12gauge"),
		list("id" = "pump/furniture/stock", "family" = "pump", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Pump-action stock",
			"desc" = "A wooden Pump-action stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "ks23/action", "family" = "ks23", "slot" = FIREARM_SLOT_ACTION, "name" = "KS-23 pump action",
			"desc" = "The pump action of a KS-23 shotgun. Fits any KS-23 receiver.", "icon_state" = "Pump-Action"),
		list("id" = "ks23/barrel/12g", "family" = "ks23", "slot" = FIREARM_SLOT_BARREL, "name" = "KS-23 barrel (12 gauge)",
			"desc" = "A 12 gauge barrel for a KS-23 shotgun. Pair it with a 12 gauge tube magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "12gauge"),
		list("id" = "ks23/feed/12g", "family" = "ks23", "slot" = FIREARM_SLOT_FEED, "name" = "KS-23 tube magazine (12 gauge)",
			"desc" = "A tube magazine under the barrel, loaded a shell at a time. Its length stays with the gun.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "12gauge"),
		list("id" = "ks23/furniture/stock", "family" = "ks23", "slot" = FIREARM_SLOT_FURNITURE, "name" = "KS-23 stock",
			"desc" = "A wooden KS-23 stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "coachgun/action", "family" = "coachgun", "slot" = FIREARM_SLOT_ACTION, "name" = "Coach gun break action",
			"desc" = "The break action of a Coach gun shotgun. Fits any Coach gun receiver.", "icon_state" = "Bolt-Action"),
		list("id" = "coachgun/barrel/12g", "family" = "coachgun", "slot" = FIREARM_SLOT_BARREL, "name" = "Coach gun barrel (12 gauge)",
			"desc" = "A 12 gauge barrel for a Coach gun shotgun. Pair it with a 12 gauge breech.", "icon_state" = "Long Rifle Barrel", "caliber" = "12gauge"),
		list("id" = "coachgun/feed/12g", "family" = "coachgun", "slot" = FIREARM_SLOT_FEED, "name" = "Coach gun breech (12 gauge)",
			"desc" = "A double-barrel breech, loaded a shell at a time.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "12gauge"),
		list("id" = "coachgun/furniture/stock", "family" = "coachgun", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Coach gun stock",
			"desc" = "A wooden Coach gun stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "mts225/action", "family" = "mts225", "slot" = FIREARM_SLOT_ACTION, "name" = "MTS-225 lockwork",
			"desc" = "The lockwork of a MTS-225 shotgun. Fits any MTS-225 receiver.", "icon_state" = "Revolver"),
		list("id" = "mts225/barrel/12g", "family" = "mts225", "slot" = FIREARM_SLOT_BARREL, "name" = "MTS-225 barrel (12 gauge)",
			"desc" = "A 12 gauge barrel for a MTS-225 shotgun. Pair it with a 12 gauge cylinder.", "icon_state" = "Long Rifle Barrel", "caliber" = "12gauge"),
		list("id" = "mts225/feed/12g", "family" = "mts225", "slot" = FIREARM_SLOT_FEED, "name" = "MTS-225 cylinder (12 gauge)",
			"desc" = "A five-shell revolving cylinder, loaded a shell at a time.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "12gauge"),
		list("id" = "mts225/furniture/stock", "family" = "mts225", "slot" = FIREARM_SLOT_FURNITURE, "name" = "MTS-225 stock",
			"desc" = "A wooden MTS-225 stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "remington11/action", "family" = "remington11", "slot" = FIREARM_SLOT_ACTION, "name" = "Remington 11 action",
			"desc" = "The action of a Remington 11 shotgun. Fits any Remington 11 receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "remington11/barrel/12g", "family" = "remington11", "slot" = FIREARM_SLOT_BARREL, "name" = "Remington 11 barrel (12 gauge)",
			"desc" = "A 12 gauge barrel for a Remington 11 shotgun. Pair it with a 12 gauge tube magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "12gauge"),
		list("id" = "remington11/feed/12g", "family" = "remington11", "slot" = FIREARM_SLOT_FEED, "name" = "Remington 11 tube magazine (12 gauge)",
			"desc" = "A tube magazine under the barrel, loaded a shell at a time. Its length stays with the gun.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "12gauge"),
		list("id" = "remington11/furniture/stock", "family" = "remington11", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Remington 11 stock",
			"desc" = "A wooden Remington 11 stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "spas/action", "family" = "spas", "slot" = FIREARM_SLOT_ACTION, "name" = "SPAS-12 action",
			"desc" = "The action of a SPAS-12 shotgun. Fits any SPAS-12 receiver.", "icon_state" = "Pump-Action"),
		list("id" = "spas/barrel/12g", "family" = "spas", "slot" = FIREARM_SLOT_BARREL, "name" = "SPAS-12 barrel (12 gauge)",
			"desc" = "A 12 gauge barrel for a SPAS-12 shotgun. Pair it with a 12 gauge tube magazine.", "icon_state" = "Long Rifle Barrel", "caliber" = "12gauge"),
		list("id" = "spas/feed/12g", "family" = "spas", "slot" = FIREARM_SLOT_FEED, "name" = "SPAS-12 tube magazine (12 gauge)",
			"desc" = "A tube magazine under the barrel, loaded a shell at a time. Its length stays with the gun.", "icon_state" = "Internal Magazine_unloaded",
			"caliber" = "12gauge"),
		list("id" = "spas/furniture/stock", "family" = "spas", "slot" = FIREARM_SLOT_FURNITURE, "name" = "SPAS-12 stock",
			"desc" = "A steel SPAS-12 stock.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "saiga/action", "family" = "saiga", "slot" = FIREARM_SLOT_ACTION, "name" = "Saiga-12 action",
			"desc" = "The action of a Saiga-12 shotgun. Fits any Saiga-12 receiver.", "icon_state" = "Semi-Auto (large)"),
		list("id" = "saiga/barrel/12g", "family" = "saiga", "slot" = FIREARM_SLOT_BARREL, "name" = "Saiga-12 barrel (12 gauge)",
			"desc" = "A 12 gauge barrel for a Saiga-12 shotgun. Pair it with a 12 gauge magazine well.", "icon_state" = "Long Rifle Barrel", "caliber" = "12gauge"),
		list("id" = "saiga/feed/12g", "family" = "saiga", "slot" = FIREARM_SLOT_FEED, "name" = "Saiga-12 magazine well (12 gauge)",
			"desc" = "A magazine well for 12 gauge Saiga-12 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "12gauge", "good_mags" = list(/obj/item/ammo_magazine/saiga12, /obj/item/ammo_magazine/saiga12/slug)),
		list("id" = "saiga/furniture/stock", "family" = "saiga", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Saiga-12 stock",
			"desc" = "A steel Saiga-12 stock.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "usas12/action", "family" = "usas12", "slot" = FIREARM_SLOT_ACTION, "name" = "USAS-12 action",
			"desc" = "The action of an USAS-12 shotgun. Fits any USAS-12 receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "usas12/barrel/12g", "family" = "usas12", "slot" = FIREARM_SLOT_BARREL, "name" = "USAS-12 barrel (12 gauge)",
			"desc" = "A 12 gauge barrel for an USAS-12 shotgun. Pair it with a 12 gauge magazine well.", "icon_state" = "Long Rifle Barrel", "caliber" = "12gauge"),
		list("id" = "usas12/feed/12g", "family" = "usas12", "slot" = FIREARM_SLOT_FEED, "name" = "USAS-12 magazine well (12 gauge)",
			"desc" = "A magazine well for 12 gauge USAS-12 magazines.", "icon_state" = "Large External Magazine_unloaded",
			"caliber" = "12gauge", "good_mags" = list(/obj/item/ammo_magazine/usas12, /obj/item/ammo_magazine/usas12/slug, /obj/item/ammo_magazine/usas12drum, /obj/item/ammo_magazine/usas12drum/slug)),
		list("id" = "usas12/furniture/stock", "family" = "usas12", "slot" = FIREARM_SLOT_FURNITURE, "name" = "USAS-12 stock",
			"desc" = "A polymer USAS-12 stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "ar12/action", "family" = "ar12", "slot" = FIREARM_SLOT_ACTION, "name" = "AR-12 action",
			"desc" = "The action of an AR-12 shotgun. Fits any AR-12 receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "ar12/barrel/12g", "family" = "ar12", "slot" = FIREARM_SLOT_BARREL, "name" = "AR-12 barrel (12 gauge)",
			"desc" = "A 12 gauge barrel for an AR-12 shotgun. Pair it with a 12 gauge magazine well.", "icon_state" = "Long Rifle Barrel", "caliber" = "12gauge"),
		list("id" = "ar12/feed/12g", "family" = "ar12", "slot" = FIREARM_SLOT_FEED, "name" = "AR-12 magazine well (12 gauge)",
			"desc" = "A magazine well for 12 gauge AR-12 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "12gauge", "good_mags" = list(/obj/item/ammo_magazine/ar12)),
		list("id" = "ar12/furniture/stock", "family" = "ar12", "slot" = FIREARM_SLOT_FURNITURE, "name" = "AR-12 stock",
			"desc" = "A polymer AR-12 stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "mp40/action", "family" = "mp40", "slot" = FIREARM_SLOT_ACTION, "name" = "MP40 bolt",
			"desc" = "The bolt of a MP40 submachine gun. Fits any MP40 receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "mp40/barrel/9x19", "family" = "mp40", "slot" = FIREARM_SLOT_BARREL, "name" = "MP40 barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a MP40 submachine gun. Pair it with a 9x19mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a9x19"),
		list("id" = "mp40/feed/9x19", "family" = "mp40", "slot" = FIREARM_SLOT_FEED, "name" = "MP40 magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm MP40 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/mp40), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "mp40/furniture/stock", "family" = "mp40", "slot" = FIREARM_SLOT_FURNITURE, "name" = "MP40 stock",
			"desc" = "A steel MP40 stock.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "erma/action", "family" = "erma", "slot" = FIREARM_SLOT_ACTION, "name" = "Erma EMP bolt",
			"desc" = "The bolt of an Erma EMP submachine gun. Fits any Erma EMP receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "erma/barrel/9x19", "family" = "erma", "slot" = FIREARM_SLOT_BARREL, "name" = "Erma EMP barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for an Erma EMP submachine gun. Pair it with a 9x19mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a9x19"),
		list("id" = "erma/feed/9x19", "family" = "erma", "slot" = FIREARM_SLOT_FEED, "name" = "Erma EMP magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm Erma EMP magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/mp40, /obj/item/ammo_magazine/mp40/erma), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "erma/furniture/stock", "family" = "erma", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Erma EMP stock",
			"desc" = "A steel Erma EMP stock.", "icon_state" = "Carbine Wooden Stock", "ergonomics" = 1),
		list("id" = "mab38/action", "family" = "mab38", "slot" = FIREARM_SLOT_ACTION, "name" = "MAB 38 bolt",
			"desc" = "The bolt of a MAB 38 submachine gun. Fits any MAB 38 receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "mab38/barrel/9x19", "family" = "mab38", "slot" = FIREARM_SLOT_BARREL, "name" = "MAB 38 barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a MAB 38 submachine gun. Pair it with a 9x19mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a9x19"),
		list("id" = "mab38/feed/9x19", "family" = "mab38", "slot" = FIREARM_SLOT_FEED, "name" = "MAB 38 magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm MAB 38 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/mp40/modello38), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "mab38/furniture/stock", "family" = "mab38", "slot" = FIREARM_SLOT_FURNITURE, "name" = "MAB 38 stock",
			"desc" = "A steel MAB 38 stock.", "icon_state" = "Carbine Wooden Stock", "ergonomics" = 1),
		list("id" = "sten/action", "family" = "sten", "slot" = FIREARM_SLOT_ACTION, "name" = "Sten bolt",
			"desc" = "The bolt of a Sten submachine gun. Fits any Sten receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "sten/barrel/9x19", "family" = "sten", "slot" = FIREARM_SLOT_BARREL, "name" = "Sten barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a Sten submachine gun. Pair it with a 9x19mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a9x19"),
		list("id" = "sten/feed/9x19", "family" = "sten", "slot" = FIREARM_SLOT_FEED, "name" = "Sten magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm Sten magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/sten2), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "sten/furniture/stock", "family" = "sten", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Sten stock",
			"desc" = "A steel Sten stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "thompson/action", "family" = "thompson", "slot" = FIREARM_SLOT_ACTION, "name" = "Thompson bolt",
			"desc" = "The bolt of a Thompson submachine gun. Fits any Thompson receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "thompson/barrel/45acp", "family" = "thompson", "slot" = FIREARM_SLOT_BARREL, "name" = "Thompson barrel (.45 ACP)",
			"desc" = "A .45 ACP barrel for a Thompson submachine gun. Pair it with a .45 ACP magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a45acp"),
		list("id" = "thompson/feed/45acp", "family" = "thompson", "slot" = FIREARM_SLOT_FEED, "name" = "Thompson magazine well (.45 ACP)",
			"desc" = "A magazine well for .45 ACP Thompson magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a45acp", "good_mags" = list(/obj/item/ammo_magazine/thompson, /obj/item/ammo_magazine/tommy), "ammo_type" = /obj/item/ammo_casing/a45acp),
		list("id" = "thompson/furniture/stock", "family" = "thompson", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Thompson stock",
			"desc" = "A steel Thompson stock.", "icon_state" = "Carbine Wooden Stock", "ergonomics" = 1),
		list("id" = "greasegun/action", "family" = "greasegun", "slot" = FIREARM_SLOT_ACTION, "name" = "M3 Grease Gun bolt",
			"desc" = "The bolt of a M3 Grease Gun submachine gun. Fits any M3 Grease Gun receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "greasegun/barrel/45acp", "family" = "greasegun", "slot" = FIREARM_SLOT_BARREL, "name" = "M3 Grease Gun barrel (.45 ACP)",
			"desc" = "A .45 ACP barrel for a M3 Grease Gun submachine gun. Pair it with a .45 ACP magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a45acp"),
		list("id" = "greasegun/feed/45acp", "family" = "greasegun", "slot" = FIREARM_SLOT_FEED, "name" = "M3 Grease Gun magazine well (.45 ACP)",
			"desc" = "A magazine well for .45 ACP M3 Grease Gun magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a45acp", "good_mags" = list(/obj/item/ammo_magazine/greasegun), "ammo_type" = /obj/item/ammo_casing/a45acp),
		list("id" = "greasegun/furniture/stock", "family" = "greasegun", "slot" = FIREARM_SLOT_FURNITURE, "name" = "M3 Grease Gun stock",
			"desc" = "A steel M3 Grease Gun stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "ppsh/action", "family" = "ppsh", "slot" = FIREARM_SLOT_ACTION, "name" = "PPSh bolt",
			"desc" = "The bolt of a PPSh submachine gun. Fits any PPSh receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "ppsh/barrel/762x25", "family" = "ppsh", "slot" = FIREARM_SLOT_BARREL, "name" = "PPSh barrel (7.62x25mm)",
			"desc" = "A 7.62x25mm barrel for a PPSh submachine gun. Pair it with a 7.62x25mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a762x25"),
		list("id" = "ppsh/feed/762x25", "family" = "ppsh", "slot" = FIREARM_SLOT_FEED, "name" = "PPSh magazine well (7.62x25mm)",
			"desc" = "A magazine well for 7.62x25mm PPSh magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x25", "good_mags" = list(/obj/item/ammo_magazine/c762x25_ppsh, /obj/item/ammo_magazine/c762x25_pps), "ammo_type" = /obj/item/ammo_casing/a762x25),
		list("id" = "ppsh/furniture/stock", "family" = "ppsh", "slot" = FIREARM_SLOT_FURNITURE, "name" = "PPSh stock",
			"desc" = "A steel PPSh stock.", "icon_state" = "Carbine Wooden Stock", "ergonomics" = 1),
		list("id" = "ppd/action", "family" = "ppd", "slot" = FIREARM_SLOT_ACTION, "name" = "PPD bolt",
			"desc" = "The bolt of a PPD submachine gun. Fits any PPD receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "ppd/barrel/762x25", "family" = "ppd", "slot" = FIREARM_SLOT_BARREL, "name" = "PPD barrel (7.62x25mm)",
			"desc" = "A 7.62x25mm barrel for a PPD submachine gun. Pair it with a 7.62x25mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a762x25"),
		list("id" = "ppd/feed/762x25", "family" = "ppd", "slot" = FIREARM_SLOT_FEED, "name" = "PPD magazine well (7.62x25mm)",
			"desc" = "A magazine well for 7.62x25mm PPD magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x25", "good_mags" = list(/obj/item/ammo_magazine/c762x25_ppsh, /obj/item/ammo_magazine/c762x25_pps), "ammo_type" = /obj/item/ammo_casing/a762x25),
		list("id" = "ppd/furniture/stock", "family" = "ppd", "slot" = FIREARM_SLOT_FURNITURE, "name" = "PPD stock",
			"desc" = "A steel PPD stock.", "icon_state" = "Carbine Wooden Stock", "ergonomics" = 1),
		list("id" = "pps/action", "family" = "pps", "slot" = FIREARM_SLOT_ACTION, "name" = "PPS bolt",
			"desc" = "The bolt of a PPS submachine gun. Fits any PPS receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "pps/barrel/762x25", "family" = "pps", "slot" = FIREARM_SLOT_BARREL, "name" = "PPS barrel (7.62x25mm)",
			"desc" = "A 7.62x25mm barrel for a PPS submachine gun. Pair it with a 7.62x25mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a762x25"),
		list("id" = "pps/feed/762x25", "family" = "pps", "slot" = FIREARM_SLOT_FEED, "name" = "PPS magazine well (7.62x25mm)",
			"desc" = "A magazine well for 7.62x25mm PPS magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x25", "good_mags" = list(/obj/item/ammo_magazine/c762x25_ppsh, /obj/item/ammo_magazine/c762x25_pps), "ammo_type" = /obj/item/ammo_casing/a762x25),
		list("id" = "pps/furniture/stock", "family" = "pps", "slot" = FIREARM_SLOT_FURNITURE, "name" = "PPS stock",
			"desc" = "A steel PPS stock.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "type100/action", "family" = "type100", "slot" = FIREARM_SLOT_ACTION, "name" = "Type 100 bolt",
			"desc" = "The bolt of a Type 100 submachine gun. Fits any Type 100 receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "type100/barrel/8mm", "family" = "type100", "slot" = FIREARM_SLOT_BARREL, "name" = "Type 100 barrel (8mm Nambu)",
			"desc" = "An 8mm Nambu barrel for a Type 100 submachine gun. Pair it with a 8mm Nambu magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "c8mmnambu"),
		list("id" = "type100/feed/8mm", "family" = "type100", "slot" = FIREARM_SLOT_FEED, "name" = "Type 100 magazine well (8mm Nambu)",
			"desc" = "A magazine well for 8mm Nambu Type 100 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "c8mmnambu", "good_mags" = list(/obj/item/ammo_magazine/type100), "ammo_type" = /obj/item/ammo_casing/c8mmnambu),
		list("id" = "type100/furniture/stock", "family" = "type100", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Type 100 stock",
			"desc" = "A steel Type 100 stock.", "icon_state" = "Carbine Wooden Stock", "ergonomics" = 1),
		list("id" = "mp5/action", "family" = "mp5", "slot" = FIREARM_SLOT_ACTION, "name" = "MP5 bolt",
			"desc" = "The bolt of a MP5 submachine gun. Fits any MP5 receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "mp5/barrel/9x19", "family" = "mp5", "slot" = FIREARM_SLOT_BARREL, "name" = "MP5 barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a MP5 submachine gun. Pair it with a 9x19mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a9x19"),
		list("id" = "mp5/feed/9x19", "family" = "mp5", "slot" = FIREARM_SLOT_FEED, "name" = "MP5 magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm MP5 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/mp40/mp5), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "mp5/furniture/stock", "family" = "mp5", "slot" = FIREARM_SLOT_FURNITURE, "name" = "MP5 stock",
			"desc" = "A polymer MP5 stock.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "uzi/action", "family" = "uzi", "slot" = FIREARM_SLOT_ACTION, "name" = "Uzi bolt",
			"desc" = "The bolt of an Uzi submachine gun. Fits any Uzi receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "uzi/barrel/9x19", "family" = "uzi", "slot" = FIREARM_SLOT_BARREL, "name" = "Uzi barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for an Uzi submachine gun. Pair it with a 9x19mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a9x19"),
		list("id" = "uzi/feed/9x19", "family" = "uzi", "slot" = FIREARM_SLOT_FEED, "name" = "Uzi magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm Uzi magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/uzi), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "uzi/furniture/stock", "family" = "uzi", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Uzi stock",
			"desc" = "A steel Uzi stock.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "skorpion/action", "family" = "skorpion", "slot" = FIREARM_SLOT_ACTION, "name" = "Skorpion bolt",
			"desc" = "The bolt of a Skorpion submachine gun. Fits any Skorpion receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "skorpion/barrel/9x19", "family" = "skorpion", "slot" = FIREARM_SLOT_BARREL, "name" = "Skorpion barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a Skorpion submachine gun. Pair it with a 9x19mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a9x19"),
		list("id" = "skorpion/feed/9x19", "family" = "skorpion", "slot" = FIREARM_SLOT_FEED, "name" = "Skorpion magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm Skorpion magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/skorpion), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "skorpion/furniture/stock", "family" = "skorpion", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Skorpion stock",
			"desc" = "A steel Skorpion stock.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "tec9/action", "family" = "tec9", "slot" = FIREARM_SLOT_ACTION, "name" = "TEC-9 bolt",
			"desc" = "The bolt of a TEC-9 submachine gun. Fits any TEC-9 receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "tec9/barrel/9x19", "family" = "tec9", "slot" = FIREARM_SLOT_BARREL, "name" = "TEC-9 barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a TEC-9 submachine gun. Pair it with a 9x19mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a9x19"),
		list("id" = "tec9/feed/9x19", "family" = "tec9", "slot" = FIREARM_SLOT_FEED, "name" = "TEC-9 magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm TEC-9 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/tec9), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "tec9/furniture/grip", "family" = "tec9", "slot" = FIREARM_SLOT_FURNITURE, "name" = "TEC-9 grip",
			"desc" = "A polymer TEC-9 grip.", "icon_state" = "Pistol Grip", "ergonomics" = 1),
		list("id" = "vector/action", "family" = "vector", "slot" = FIREARM_SLOT_ACTION, "name" = "Kriss Vector bolt",
			"desc" = "The bolt of a Kriss Vector submachine gun. Fits any Kriss Vector receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "vector/barrel/9x19", "family" = "vector", "slot" = FIREARM_SLOT_BARREL, "name" = "Kriss Vector barrel (9x19mm)",
			"desc" = "A 9x19mm barrel for a Kriss Vector submachine gun. Pair it with a 9x19mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a9x19"),
		list("id" = "vector/feed/9x19", "family" = "vector", "slot" = FIREARM_SLOT_FEED, "name" = "Kriss Vector magazine well (9x19mm)",
			"desc" = "A magazine well for 9x19mm Kriss Vector magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x19", "good_mags" = list(/obj/item/ammo_magazine/glock17, /obj/item/ammo_magazine/glock17/vector), "ammo_type" = /obj/item/ammo_casing/a9x19),
		list("id" = "vector/furniture/stock", "family" = "vector", "slot" = FIREARM_SLOT_FURNITURE, "name" = "Kriss Vector stock",
			"desc" = "A polymer Kriss Vector stock.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "mac10/action", "family" = "mac10", "slot" = FIREARM_SLOT_ACTION, "name" = "MAC-10 bolt",
			"desc" = "The bolt of a MAC-10 submachine gun. Fits any MAC-10 receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "mac10/barrel/45acp", "family" = "mac10", "slot" = FIREARM_SLOT_BARREL, "name" = "MAC-10 barrel (.45 ACP)",
			"desc" = "A .45 ACP barrel for a MAC-10 submachine gun. Pair it with a .45 ACP magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a45acp"),
		list("id" = "mac10/feed/45acp", "family" = "mac10", "slot" = FIREARM_SLOT_FEED, "name" = "MAC-10 magazine well (.45 ACP)",
			"desc" = "A magazine well for .45 ACP MAC-10 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a45acp", "good_mags" = list(/obj/item/ammo_magazine/mac10), "ammo_type" = /obj/item/ammo_casing/a45acp),
		list("id" = "mac10/furniture/stock", "family" = "mac10", "slot" = FIREARM_SLOT_FURNITURE, "name" = "MAC-10 stock",
			"desc" = "A steel MAC-10 stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "p90/action", "family" = "p90", "slot" = FIREARM_SLOT_ACTION, "name" = "P90 bolt",
			"desc" = "The bolt of a P90 submachine gun. Fits any P90 receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "p90/barrel/57x28", "family" = "p90", "slot" = FIREARM_SLOT_BARREL, "name" = "P90 barrel (5.7x28mm)",
			"desc" = "A 5.7x28mm barrel for a P90 submachine gun. Pair it with a 5.7x28mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a57x28"),
		list("id" = "p90/feed/57x28", "family" = "p90", "slot" = FIREARM_SLOT_FEED, "name" = "P90 magazine well (5.7x28mm)",
			"desc" = "A magazine well for 5.7x28mm P90 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a57x28", "good_mags" = list(/obj/item/ammo_magazine/p90), "ammo_type" = /obj/item/ammo_casing/a57x28),
		list("id" = "p90/furniture/stock", "family" = "p90", "slot" = FIREARM_SLOT_FURNITURE, "name" = "P90 stock",
			"desc" = "A polymer P90 stock.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "sr3/action", "family" = "sr3", "slot" = FIREARM_SLOT_ACTION, "name" = "SR-3 bolt",
			"desc" = "The bolt of a SR-3 rifle. Fits any SR-3 receiver.", "icon_state" = "Open-Bolt (small)"),
		list("id" = "sr3/barrel/9x39", "family" = "sr3", "slot" = FIREARM_SLOT_BARREL, "name" = "SR-3 barrel (9x39mm)",
			"desc" = "A 9x39mm barrel for a SR-3 rifle. Pair it with a 9x39mm magazine well.", "icon_state" = "Carbine Barrel", "caliber" = "a9x39"),
		list("id" = "sr3/feed/9x39", "family" = "sr3", "slot" = FIREARM_SLOT_FEED, "name" = "SR-3 magazine well (9x39mm)",
			"desc" = "A magazine well for 9x39mm SR-3 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a9x39", "good_mags" = list(/obj/item/ammo_magazine/srm, /obj/item/ammo_magazine/srm/srms, /obj/item/ammo_magazine/vintorez), "ammo_type" = /obj/item/ammo_casing/a9x39),
		list("id" = "sr3/furniture/stock", "family" = "sr3", "slot" = FIREARM_SLOT_FURNITURE, "name" = "SR-3 stock",
			"desc" = "A steel SR-3 stock.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "stg/action", "family" = "stg", "slot" = FIREARM_SLOT_ACTION, "name" = "StG-44 bolt carrier",
			"desc" = "The bolt carrier of a StG-44 rifle. Fits any StG-44 receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "stg/barrel/792x33", "family" = "stg", "slot" = FIREARM_SLOT_BARREL, "name" = "StG-44 barrel (7.92x33mm Kurz)",
			"desc" = "A 7.92x33mm Kurz barrel for a StG-44 rifle. Pair it with a 7.92x33mm Kurz magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a792x33"),
		list("id" = "stg/feed/792x33", "family" = "stg", "slot" = FIREARM_SLOT_FEED, "name" = "StG-44 magazine well (7.92x33mm Kurz)",
			"desc" = "A magazine well for 7.92x33mm Kurz StG-44 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a792x33", "good_mags" = list(/obj/item/ammo_magazine/stg), "ammo_type" = /obj/item/ammo_casing/a792x33),
		list("id" = "stg/furniture/stock", "family" = "stg", "slot" = FIREARM_SLOT_FURNITURE, "name" = "StG-44 stock",
			"desc" = "A wooden StG-44 stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "fg42/action", "family" = "fg42", "slot" = FIREARM_SLOT_ACTION, "name" = "FG42 bolt carrier",
			"desc" = "The bolt carrier of a FG42 rifle. Fits any FG42 receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "fg42/barrel/792x57", "family" = "fg42", "slot" = FIREARM_SLOT_BARREL, "name" = "FG42 barrel (7.92x57mm)",
			"desc" = "A 7.92x57mm barrel for a FG42 rifle. Pair it with a 7.92x57mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a792x57"),
		list("id" = "fg42/feed/792x57", "family" = "fg42", "slot" = FIREARM_SLOT_FEED, "name" = "FG42 magazine well (7.92x57mm)",
			"desc" = "A magazine well for 7.92x57mm FG42 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a792x57", "good_mags" = list(/obj/item/ammo_magazine/fg42, /obj/item/ammo_magazine/fg42/small), "ammo_type" = /obj/item/ammo_casing/a792x57),
		list("id" = "fg42/furniture/stock", "family" = "fg42", "slot" = FIREARM_SLOT_FURNITURE, "name" = "FG42 stock",
			"desc" = "A steel FG42 stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "m14/action", "family" = "m14", "slot" = FIREARM_SLOT_ACTION, "name" = "M14 bolt carrier",
			"desc" = "The bolt carrier of a M14 rifle. Fits any M14 receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "m14/barrel/762x51", "family" = "m14", "slot" = FIREARM_SLOT_BARREL, "name" = "M14 barrel (7.62x51mm)",
			"desc" = "A 7.62x51mm barrel for a M14 rifle. Pair it with a 7.62x51mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a762x51"),
		list("id" = "m14/feed/762x51", "family" = "m14", "slot" = FIREARM_SLOT_FEED, "name" = "M14 magazine well (7.62x51mm)",
			"desc" = "A magazine well for 7.62x51mm M14 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x51", "good_mags" = list(/obj/item/ammo_magazine/m14), "ammo_type" = /obj/item/ammo_casing/a762x51),
		list("id" = "m14/furniture/stock", "family" = "m14", "slot" = FIREARM_SLOT_FURNITURE, "name" = "M14 stock",
			"desc" = "A wooden M14 stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "fal/action", "family" = "fal", "slot" = FIREARM_SLOT_ACTION, "name" = "FAL bolt carrier",
			"desc" = "The bolt carrier of a FAL rifle. Fits any FAL receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "fal/barrel/762x51", "family" = "fal", "slot" = FIREARM_SLOT_BARREL, "name" = "FAL barrel (7.62x51mm)",
			"desc" = "A 7.62x51mm barrel for a FAL rifle. Pair it with a 7.62x51mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a762x51"),
		list("id" = "fal/feed/762x51", "family" = "fal", "slot" = FIREARM_SLOT_FEED, "name" = "FAL magazine well (7.62x51mm)",
			"desc" = "A magazine well for 7.62x51mm FAL magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x51", "good_mags" = list(/obj/item/ammo_magazine/fal), "ammo_type" = /obj/item/ammo_casing/a762x51),
		list("id" = "fal/furniture/stock", "family" = "fal", "slot" = FIREARM_SLOT_FURNITURE, "name" = "FAL stock",
			"desc" = "A wooden FAL stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
		list("id" = "g3/action", "family" = "g3", "slot" = FIREARM_SLOT_ACTION, "name" = "G3 bolt carrier",
			"desc" = "The bolt carrier of a G3 rifle. Fits any G3 receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "g3/barrel/762x51", "family" = "g3", "slot" = FIREARM_SLOT_BARREL, "name" = "G3 barrel (7.62x51mm)",
			"desc" = "A 7.62x51mm barrel for a G3 rifle. Pair it with a 7.62x51mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a762x51"),
		list("id" = "g3/feed/762x51", "family" = "g3", "slot" = FIREARM_SLOT_FEED, "name" = "G3 magazine well (7.62x51mm)",
			"desc" = "A magazine well for 7.62x51mm G3 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x51", "good_mags" = list(/obj/item/ammo_magazine/hk), "ammo_type" = /obj/item/ammo_casing/a762x51),
		list("id" = "g3/furniture/stock", "family" = "g3", "slot" = FIREARM_SLOT_FURNITURE, "name" = "G3 stock",
			"desc" = "A polymer G3 stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "ar10/action", "family" = "ar10", "slot" = FIREARM_SLOT_ACTION, "name" = "AR-10 bolt carrier",
			"desc" = "The bolt carrier of an AR-10 rifle. Fits any AR-10 receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "ar10/barrel/762x51", "family" = "ar10", "slot" = FIREARM_SLOT_BARREL, "name" = "AR-10 barrel (7.62x51mm)",
			"desc" = "A 7.62x51mm barrel for an AR-10 rifle. Pair it with a 7.62x51mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a762x51"),
		list("id" = "ar10/feed/762x51", "family" = "ar10", "slot" = FIREARM_SLOT_FEED, "name" = "AR-10 magazine well (7.62x51mm)",
			"desc" = "A magazine well for 7.62x51mm AR-10 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x51", "good_mags" = list(/obj/item/ammo_magazine/ar10), "ammo_type" = /obj/item/ammo_casing/a762x51),
		list("id" = "ar10/furniture/stock", "family" = "ar10", "slot" = FIREARM_SLOT_FURNITURE, "name" = "AR-10 stock",
			"desc" = "A polymer AR-10 stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "hk417/action", "family" = "hk417", "slot" = FIREARM_SLOT_ACTION, "name" = "HK417 bolt carrier",
			"desc" = "The bolt carrier of a HK417 rifle. Fits any HK417 receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "hk417/barrel/762x51", "family" = "hk417", "slot" = FIREARM_SLOT_BARREL, "name" = "HK417 barrel (7.62x51mm)",
			"desc" = "A 7.62x51mm barrel for a HK417 rifle. Pair it with a 7.62x51mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a762x51"),
		list("id" = "hk417/feed/762x51", "family" = "hk417", "slot" = FIREARM_SLOT_FEED, "name" = "HK417 magazine well (7.62x51mm)",
			"desc" = "A magazine well for 7.62x51mm HK417 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x51", "good_mags" = list(/obj/item/ammo_magazine/scarh), "ammo_type" = /obj/item/ammo_casing/a762x51),
		list("id" = "hk417/furniture/stock", "family" = "hk417", "slot" = FIREARM_SLOT_FURNITURE, "name" = "HK417 stock",
			"desc" = "A polymer HK417 stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "scar/action", "family" = "scar", "slot" = FIREARM_SLOT_ACTION, "name" = "SCAR bolt carrier",
			"desc" = "The bolt carrier of a SCAR rifle. Fits any SCAR receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "scar/barrel/556x45", "family" = "scar", "slot" = FIREARM_SLOT_BARREL, "name" = "SCAR barrel (5.56x45mm)",
			"desc" = "A 5.56x45mm barrel for a SCAR rifle. Pair it with a 5.56x45mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a556x45"),
		list("id" = "scar/barrel/762x51", "family" = "scar", "slot" = FIREARM_SLOT_BARREL, "name" = "SCAR barrel (7.62x51mm)",
			"desc" = "A 7.62x51mm barrel for a SCAR rifle. Pair it with a 7.62x51mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a762x51"),
		list("id" = "scar/feed/556x45", "family" = "scar", "slot" = FIREARM_SLOT_FEED, "name" = "SCAR magazine well (5.56x45mm)",
			"desc" = "A magazine well for 5.56x45mm SCAR magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a556x45", "good_mags" = stanag_mags, "ammo_type" = /obj/item/ammo_casing/a556x45),
		list("id" = "scar/feed/762x51", "family" = "scar", "slot" = FIREARM_SLOT_FEED, "name" = "SCAR magazine well (7.62x51mm)",
			"desc" = "A magazine well for 7.62x51mm SCAR magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x51", "good_mags" = list(/obj/item/ammo_magazine/scarh), "ammo_type" = /obj/item/ammo_casing/a762x51),
		list("id" = "scar/furniture/stock", "family" = "scar", "slot" = FIREARM_SLOT_FURNITURE, "name" = "SCAR stock",
			"desc" = "A polymer SCAR stock.", "icon_state" = "Folding Stock", "ergonomics" = 1),
		list("id" = "aug/action", "family" = "aug", "slot" = FIREARM_SLOT_ACTION, "name" = "AUG bolt carrier",
			"desc" = "The bolt carrier of an AUG rifle. Fits any AUG receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "aug/barrel/556x45", "family" = "aug", "slot" = FIREARM_SLOT_BARREL, "name" = "AUG barrel (5.56x45mm)",
			"desc" = "A 5.56x45mm barrel for an AUG rifle. Pair it with a 5.56x45mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a556x45"),
		list("id" = "aug/feed/556x45", "family" = "aug", "slot" = FIREARM_SLOT_FEED, "name" = "AUG magazine well (5.56x45mm)",
			"desc" = "A magazine well for 5.56x45mm AUG magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a556x45", "good_mags" = stanag_mags, "ammo_type" = /obj/item/ammo_casing/a556x45),
		list("id" = "aug/furniture/stock", "family" = "aug", "slot" = FIREARM_SLOT_FURNITURE, "name" = "AUG stock",
			"desc" = "A polymer AUG stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "l85/action", "family" = "l85", "slot" = FIREARM_SLOT_ACTION, "name" = "L85 bolt carrier",
			"desc" = "The bolt carrier of a L85 rifle. Fits any L85 receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "l85/barrel/556x45", "family" = "l85", "slot" = FIREARM_SLOT_BARREL, "name" = "L85 barrel (5.56x45mm)",
			"desc" = "A 5.56x45mm barrel for a L85 rifle. Pair it with a 5.56x45mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a556x45"),
		list("id" = "l85/feed/556x45", "family" = "l85", "slot" = FIREARM_SLOT_FEED, "name" = "L85 magazine well (5.56x45mm)",
			"desc" = "A magazine well for 5.56x45mm L85 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a556x45", "good_mags" = stanag_mags, "ammo_type" = /obj/item/ammo_casing/a556x45),
		list("id" = "l85/furniture/stock", "family" = "l85", "slot" = FIREARM_SLOT_FURNITURE, "name" = "L85 stock",
			"desc" = "A polymer L85 stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "qbz95/action", "family" = "qbz95", "slot" = FIREARM_SLOT_ACTION, "name" = "QBZ-95 bolt carrier",
			"desc" = "The bolt carrier of a QBZ-95 rifle. Fits any QBZ-95 receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "qbz95/barrel/58x42", "family" = "qbz95", "slot" = FIREARM_SLOT_BARREL, "name" = "QBZ-95 barrel (5.8x42mm)",
			"desc" = "A 5.8x42mm barrel for a QBZ-95 rifle. Pair it with a 5.8x42mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a58x42"),
		list("id" = "qbz95/feed/58x42", "family" = "qbz95", "slot" = FIREARM_SLOT_FEED, "name" = "QBZ-95 magazine well (5.8x42mm)",
			"desc" = "A magazine well for 5.8x42mm QBZ-95 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a58x42", "good_mags" = list(/obj/item/ammo_magazine/qbz95), "ammo_type" = /obj/item/ammo_casing/a58x42),
		list("id" = "qbz95/furniture/stock", "family" = "qbz95", "slot" = FIREARM_SLOT_FURNITURE, "name" = "QBZ-95 stock",
			"desc" = "A polymer QBZ-95 stock.", "icon_state" = "Steel Stock", "ergonomics" = 1),
		list("id" = "vz58/action", "family" = "vz58", "slot" = FIREARM_SLOT_ACTION, "name" = "VZ-58 bolt carrier",
			"desc" = "The bolt carrier of a VZ-58 rifle. Fits any VZ-58 receiver.", "icon_state" = "Dual Selective Fire"),
		list("id" = "vz58/barrel/762x39", "family" = "vz58", "slot" = FIREARM_SLOT_BARREL, "name" = "VZ-58 barrel (7.62x39mm)",
			"desc" = "A 7.62x39mm barrel for a VZ-58 rifle. Pair it with a 7.62x39mm magazine well.", "icon_state" = "Rifle Barrel", "caliber" = "a762x39"),
		list("id" = "vz58/feed/762x39", "family" = "vz58", "slot" = FIREARM_SLOT_FEED, "name" = "VZ-58 magazine well (7.62x39mm)",
			"desc" = "A magazine well for 7.62x39mm VZ-58 magazines.", "icon_state" = "External Magazine_unloaded",
			"caliber" = "a762x39", "good_mags" = ak47_mags, "ammo_type" = /obj/item/ammo_casing/a762x39),
		list("id" = "vz58/furniture/stock", "family" = "vz58", "slot" = FIREARM_SLOT_FURNITURE, "name" = "VZ-58 stock",
			"desc" = "A wooden VZ-58 stock.", "icon_state" = "RIfle Wooden Stock", "ergonomics" = 1),
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
		"enfield" = list(FIREARM_SLOT_ACTION = "enfield/action", FIREARM_SLOT_BARREL = "enfield/barrel/303", FIREARM_SLOT_FEED = "enfield/feed/303", FIREARM_SLOT_FURNITURE = "enfield/furniture/stock"),
		"springfield" = list(FIREARM_SLOT_ACTION = "springfield/action", FIREARM_SLOT_BARREL = "springfield/barrel/3006", FIREARM_SLOT_FEED = "springfield/feed/3006", FIREARM_SLOT_FURNITURE = "springfield/furniture/stock"),
		"lebel" = list(FIREARM_SLOT_ACTION = "lebel/action", FIREARM_SLOT_BARREL = "lebel/barrel/8x50", FIREARM_SLOT_FEED = "lebel/feed/8x50", FIREARM_SLOT_FURNITURE = "lebel/furniture/stock"),
		"berthier_3" = list(FIREARM_SLOT_ACTION = "berthier/action", FIREARM_SLOT_BARREL = "berthier/barrel/8x50", FIREARM_SLOT_FEED = "berthier/feed/8x50_3", FIREARM_SLOT_FURNITURE = "berthier/furniture/stock"),
		"berthier_5" = list(FIREARM_SLOT_ACTION = "berthier/action", FIREARM_SLOT_BARREL = "berthier/barrel/8x50", FIREARM_SLOT_FEED = "berthier/feed/8x50_5", FIREARM_SLOT_FURNITURE = "berthier/furniture/stock"),
		"carcano" = list(FIREARM_SLOT_ACTION = "carcano/action", FIREARM_SLOT_BARREL = "carcano/barrel/65x52", FIREARM_SLOT_FEED = "carcano/feed/65x52", FIREARM_SLOT_FURNITURE = "carcano/furniture/stock"),
		"murata" = list(FIREARM_SLOT_ACTION = "murata/action", FIREARM_SLOT_BARREL = "murata/barrel/8x53", FIREARM_SLOT_FEED = "murata/feed/8x53", FIREARM_SLOT_FURNITURE = "murata/furniture/stock"),
		"berdan" = list(FIREARM_SLOT_ACTION = "berdan/action", FIREARM_SLOT_BARREL = "berdan/barrel/762x54", FIREARM_SLOT_FEED = "berdan/feed/762x54", FIREARM_SLOT_FURNITURE = "berdan/furniture/stock"),
		"vg" = list(FIREARM_SLOT_ACTION = "vg/action", FIREARM_SLOT_BARREL = "vg/barrel/792x33", FIREARM_SLOT_FEED = "vg/feed/792x33", FIREARM_SLOT_FURNITURE = "vg/furniture/stock"),
		"m24" = list(FIREARM_SLOT_ACTION = "m24/action", FIREARM_SLOT_BARREL = "m24/barrel/762x51", FIREARM_SLOT_FEED = "m24/feed/762x51", FIREARM_SLOT_FURNITURE = "m24/furniture/stock"),
		"sharps" = list(FIREARM_SLOT_ACTION = "sharps/action", FIREARM_SLOT_BARREL = "sharps/barrel/4570", FIREARM_SLOT_FEED = "sharps/feed/4570", FIREARM_SLOT_FURNITURE = "sharps/furniture/stock"),
		"rollingblock_4570" = list(FIREARM_SLOT_ACTION = "rollingblock/action", FIREARM_SLOT_BARREL = "rollingblock/barrel/4570", FIREARM_SLOT_FEED = "rollingblock/feed/4570", FIREARM_SLOT_FURNITURE = "rollingblock/furniture/stock"),
		"rollingblock_43" = list(FIREARM_SLOT_ACTION = "rollingblock/action", FIREARM_SLOT_BARREL = "rollingblock/barrel/43", FIREARM_SLOT_FEED = "rollingblock/feed/43", FIREARM_SLOT_FURNITURE = "rollingblock/furniture/stock"),
		"martini" = list(FIREARM_SLOT_ACTION = "martini/action", FIREARM_SLOT_BARREL = "martini/barrel/577", FIREARM_SLOT_FEED = "martini/feed/577", FIREARM_SLOT_FURNITURE = "martini/furniture/stock"),
		"ptrd" = list(FIREARM_SLOT_ACTION = "ptrd/action", FIREARM_SLOT_BARREL = "ptrd/barrel/145", FIREARM_SLOT_FEED = "ptrd/feed/145", FIREARM_SLOT_FURNITURE = "ptrd/furniture/stock"),
		"pzb" = list(FIREARM_SLOT_ACTION = "pzb/action", FIREARM_SLOT_BARREL = "pzb/barrel/792x94", FIREARM_SLOT_FEED = "pzb/feed/792x94", FIREARM_SLOT_FURNITURE = "pzb/furniture/stock"),
		"barrett" = list(FIREARM_SLOT_ACTION = "barrett/action", FIREARM_SLOT_BARREL = "barrett/barrel/50cal", FIREARM_SLOT_FEED = "barrett/feed/50cal", FIREARM_SLOT_FURNITURE = "barrett/furniture/stock"),
		"sks" = list(FIREARM_SLOT_ACTION = "sks/action", FIREARM_SLOT_BARREL = "sks/barrel/762x39", FIREARM_SLOT_FEED = "sks/feed/762x39", FIREARM_SLOT_FURNITURE = "sks/furniture/stock"),
		"sksm" = list(FIREARM_SLOT_ACTION = "sks/action", FIREARM_SLOT_BARREL = "sks/barrel/762x39", FIREARM_SLOT_FEED = "sks/feed/762x39_detachable", FIREARM_SLOT_FURNITURE = "sks/furniture/stock"),
		"gewehr41" = list(FIREARM_SLOT_ACTION = "gewehr43/action", FIREARM_SLOT_BARREL = "gewehr43/barrel/792x57", FIREARM_SLOT_FEED = "gewehr43/feed/792x57", FIREARM_SLOT_FURNITURE = "gewehr43/furniture/stock"),
		"gewehr43" = list(FIREARM_SLOT_ACTION = "gewehr43/action", FIREARM_SLOT_BARREL = "gewehr43/barrel/792x57", FIREARM_SLOT_FEED = "gewehr43/feed/792x57_detachable", FIREARM_SLOT_FURNITURE = "gewehr43/furniture/stock"),
		"svt" = list(FIREARM_SLOT_ACTION = "svt/action", FIREARM_SLOT_BARREL = "svt/barrel/762x54", FIREARM_SLOT_FEED = "svt/feed/762x54", FIREARM_SLOT_FURNITURE = "svt/furniture/stock"),
		"garand" = list(FIREARM_SLOT_ACTION = "garand/action", FIREARM_SLOT_BARREL = "garand/barrel/3006", FIREARM_SLOT_FEED = "garand/feed/3006", FIREARM_SLOT_FURNITURE = "garand/furniture/stock"),
		"m1carbine" = list(FIREARM_SLOT_ACTION = "m1carbine/action", FIREARM_SLOT_BARREL = "m1carbine/barrel/762x33", FIREARM_SLOT_FEED = "m1carbine/feed/762x33", FIREARM_SLOT_FURNITURE = "m1carbine/furniture/stock"),
		"avtomat" = list(FIREARM_SLOT_ACTION = "avtomat/action", FIREARM_SLOT_BARREL = "avtomat/barrel/65x50", FIREARM_SLOT_FEED = "avtomat/feed/65x50", FIREARM_SLOT_FURNITURE = "avtomat/furniture/stock"),
		"vg5" = list(FIREARM_SLOT_ACTION = "vg5/action", FIREARM_SLOT_BARREL = "vg5/barrel/792x33", FIREARM_SLOT_FEED = "vg5/feed/792x33", FIREARM_SLOT_FURNITURE = "vg5/furniture/stock"),
		"ptrs" = list(FIREARM_SLOT_ACTION = "ptrs/action", FIREARM_SLOT_BARREL = "ptrs/barrel/145", FIREARM_SLOT_FEED = "ptrs/feed/145", FIREARM_SLOT_FURNITURE = "ptrs/furniture/stock"),
		"svd" = list(FIREARM_SLOT_ACTION = "svd/action", FIREARM_SLOT_BARREL = "svd/barrel/762x54", FIREARM_SLOT_FEED = "svd/feed/762x54", FIREARM_SLOT_FURNITURE = "svd/furniture/stock"),
		"vss" = list(FIREARM_SLOT_ACTION = "vss/action", FIREARM_SLOT_BARREL = "vss/barrel/9x39", FIREARM_SLOT_FEED = "vss/feed/9x39", FIREARM_SLOT_FURNITURE = "vss/furniture/stock"),
		"m82" = list(FIREARM_SLOT_ACTION = "m82/action", FIREARM_SLOT_BARREL = "m82/barrel/50cal", FIREARM_SLOT_FEED = "m82/feed/50cal", FIREARM_SLOT_FURNITURE = "m82/furniture/stock"),
		"bamr" = list(FIREARM_SLOT_ACTION = "bamr/action", FIREARM_SLOT_BARREL = "bamr/barrel/15115", FIREARM_SLOT_FEED = "bamr/feed/15115", FIREARM_SLOT_FURNITURE = "bamr/furniture/stock"),
		"lever_44" = list(FIREARM_SLOT_ACTION = "lever/action", FIREARM_SLOT_BARREL = "lever/barrel/44", FIREARM_SLOT_FEED = "lever/feed/44", FIREARM_SLOT_FURNITURE = "lever/furniture/stock"),
		"lever_4570" = list(FIREARM_SLOT_ACTION = "lever/action", FIREARM_SLOT_BARREL = "lever/barrel/4570", FIREARM_SLOT_FEED = "lever/feed/4570", FIREARM_SLOT_FURNITURE = "lever/furniture/stock"),
		"lever_357" = list(FIREARM_SLOT_ACTION = "lever/action", FIREARM_SLOT_BARREL = "lever/barrel/357", FIREARM_SLOT_FEED = "lever/feed/357", FIREARM_SLOT_FURNITURE = "lever/furniture/stock"),
		"nambu" = list(FIREARM_SLOT_ACTION = "nambu/action", FIREARM_SLOT_BARREL = "nambu/barrel/8mm", FIREARM_SLOT_FEED = "nambu/feed/8mm", FIREARM_SLOT_FURNITURE = "nambu/furniture/grip"),
		"bergmann" = list(FIREARM_SLOT_ACTION = "bergmann/action", FIREARM_SLOT_BARREL = "bergmann/barrel/8mm", FIREARM_SLOT_FEED = "bergmann/feed/8mm", FIREARM_SLOT_FURNITURE = "bergmann/furniture/grip"),
		"luger" = list(FIREARM_SLOT_ACTION = "luger/action", FIREARM_SLOT_BARREL = "luger/barrel/9x19", FIREARM_SLOT_FEED = "luger/feed/9x19", FIREARM_SLOT_FURNITURE = "luger/furniture/grip"),
		"walther" = list(FIREARM_SLOT_ACTION = "walther/action", FIREARM_SLOT_BARREL = "walther/barrel/9x19", FIREARM_SLOT_FEED = "walther/feed/9x19", FIREARM_SLOT_FURNITURE = "walther/furniture/grip"),
		"browninghp" = list(FIREARM_SLOT_ACTION = "browninghp/action", FIREARM_SLOT_BARREL = "browninghp/barrel/9x19", FIREARM_SLOT_FEED = "browninghp/feed/9x19", FIREARM_SLOT_FURNITURE = "browninghp/furniture/grip"),
		"c96" = list(FIREARM_SLOT_ACTION = "c96/action", FIREARM_SLOT_BARREL = "c96/barrel/762x25", FIREARM_SLOT_FEED = "c96/feed/762x25", FIREARM_SLOT_FURNITURE = "c96/furniture/grip"),
		"borchardt" = list(FIREARM_SLOT_ACTION = "borchardt/action", FIREARM_SLOT_BARREL = "borchardt/barrel/765x25", FIREARM_SLOT_FEED = "borchardt/feed/765x25", FIREARM_SLOT_FURNITURE = "borchardt/furniture/grip"),
		"colthammerless_32" = list(FIREARM_SLOT_ACTION = "colthammerless/action", FIREARM_SLOT_BARREL = "colthammerless/barrel/32acp", FIREARM_SLOT_FEED = "colthammerless/feed/32acp", FIREARM_SLOT_FURNITURE = "colthammerless/furniture/grip"),
		"colthammerless_380" = list(FIREARM_SLOT_ACTION = "colthammerless/action", FIREARM_SLOT_BARREL = "colthammerless/barrel/380acp", FIREARM_SLOT_FEED = "colthammerless/feed/380acp", FIREARM_SLOT_FURNITURE = "colthammerless/furniture/grip"),
		"m1911" = list(FIREARM_SLOT_ACTION = "m1911/action", FIREARM_SLOT_BARREL = "m1911/barrel/45acp", FIREARM_SLOT_FEED = "m1911/feed/45acp", FIREARM_SLOT_FURNITURE = "m1911/furniture/grip"),
		"sti2011" = list(FIREARM_SLOT_ACTION = "m1911/action", FIREARM_SLOT_BARREL = "m1911/barrel/45acp", FIREARM_SLOT_FEED = "m1911/feed/45acp_2011", FIREARM_SLOT_FURNITURE = "m1911/furniture/grip"),
		"tt" = list(FIREARM_SLOT_ACTION = "tt/action", FIREARM_SLOT_BARREL = "tt/barrel/762x25", FIREARM_SLOT_FEED = "tt/feed/762x25", FIREARM_SLOT_FURNITURE = "tt/furniture/grip"),
		"makarov" = list(FIREARM_SLOT_ACTION = "makarov/action", FIREARM_SLOT_BARREL = "makarov/barrel/9x18", FIREARM_SLOT_FEED = "makarov/feed/9x18", FIREARM_SLOT_FURNITURE = "makarov/furniture/grip"),
		"aps" = list(FIREARM_SLOT_ACTION = "aps/action", FIREARM_SLOT_BARREL = "aps/barrel/9x18", FIREARM_SLOT_FEED = "aps/feed/9x18", FIREARM_SLOT_FURNITURE = "aps/furniture/grip"),
		"glock" = list(FIREARM_SLOT_ACTION = "glock/action", FIREARM_SLOT_BARREL = "glock/barrel/9x19", FIREARM_SLOT_FEED = "glock/feed/9x19", FIREARM_SLOT_FURNITURE = "glock/furniture/grip"),
		"beretta" = list(FIREARM_SLOT_ACTION = "beretta/action", FIREARM_SLOT_BARREL = "beretta/barrel/9x19", FIREARM_SLOT_FEED = "beretta/feed/9x19", FIREARM_SLOT_FURNITURE = "beretta/furniture/grip"),
		"jericho" = list(FIREARM_SLOT_ACTION = "jericho/action", FIREARM_SLOT_BARREL = "jericho/barrel/9x19", FIREARM_SLOT_FEED = "jericho/feed/9x19", FIREARM_SLOT_FURNITURE = "jericho/furniture/grip"),
		"sig250" = list(FIREARM_SLOT_ACTION = "sig250/action", FIREARM_SLOT_BARREL = "sig250/barrel/9x19", FIREARM_SLOT_FEED = "sig250/feed/9x19", FIREARM_SLOT_FURNITURE = "sig250/furniture/grip"),
		"p220" = list(FIREARM_SLOT_ACTION = "p220/action", FIREARM_SLOT_BARREL = "p220/barrel/45", FIREARM_SLOT_FEED = "p220/feed/45", FIREARM_SLOT_FURNITURE = "p220/furniture/grip"),
		"pl14" = list(FIREARM_SLOT_ACTION = "pl14/action", FIREARM_SLOT_BARREL = "pl14/barrel/9x19", FIREARM_SLOT_FEED = "pl14/feed/9x19", FIREARM_SLOT_FURNITURE = "pl14/furniture/grip"),
		"mp443" = list(FIREARM_SLOT_ACTION = "mp443/action", FIREARM_SLOT_BARREL = "mp443/barrel/9x19", FIREARM_SLOT_FEED = "mp443/feed/9x19", FIREARM_SLOT_FURNITURE = "mp443/furniture/grip"),
		"deagle_50" = list(FIREARM_SLOT_ACTION = "deagle/action", FIREARM_SLOT_BARREL = "deagle/barrel/50ae", FIREARM_SLOT_FEED = "deagle/feed/50ae", FIREARM_SLOT_FURNITURE = "deagle/furniture/grip"),
		"deagle_44" = list(FIREARM_SLOT_ACTION = "deagle/action", FIREARM_SLOT_BARREL = "deagle/barrel/44magnum", FIREARM_SLOT_FEED = "deagle/feed/44magnum", FIREARM_SLOT_FURNITURE = "deagle/furniture/grip"),
		"nagant" = list(FIREARM_SLOT_ACTION = "nagant/action", FIREARM_SLOT_BARREL = "nagant/barrel/762x38", FIREARM_SLOT_FEED = "nagant/feed/762x38", FIREARM_SLOT_FURNITURE = "nagant/furniture/grip"),
		"m1892" = list(FIREARM_SLOT_ACTION = "m1892/action", FIREARM_SLOT_BARREL = "m1892/barrel/8x27", FIREARM_SLOT_FEED = "m1892/feed/8x27", FIREARM_SLOT_FURNITURE = "m1892/furniture/grip"),
		"colt_saa_45" = list(FIREARM_SLOT_ACTION = "colt_saa/action", FIREARM_SLOT_BARREL = "colt_saa/barrel/45", FIREARM_SLOT_FEED = "colt_saa/feed/45", FIREARM_SLOT_FURNITURE = "colt_saa/furniture/grip"),
		"colt_saa_44" = list(FIREARM_SLOT_ACTION = "colt_saa/action", FIREARM_SLOT_BARREL = "colt_saa/barrel/44", FIREARM_SLOT_FEED = "colt_saa/feed/44", FIREARM_SLOT_FURNITURE = "colt_saa/furniture/grip"),
		"colt1892" = list(FIREARM_SLOT_ACTION = "colt1892/action", FIREARM_SLOT_BARREL = "colt1892/barrel/38", FIREARM_SLOT_FEED = "colt1892/feed/38", FIREARM_SLOT_FURNITURE = "colt1892/furniture/grip"),
		"policepositive" = list(FIREARM_SLOT_ACTION = "policepositive/action", FIREARM_SLOT_BARREL = "policepositive/barrel/32", FIREARM_SLOT_FEED = "policepositive/feed/32", FIREARM_SLOT_FURNITURE = "policepositive/furniture/grip"),
		"smithwesson_32" = list(FIREARM_SLOT_ACTION = "smithwesson/action", FIREARM_SLOT_BARREL = "smithwesson/barrel/32", FIREARM_SLOT_FEED = "smithwesson/feed/32", FIREARM_SLOT_FURNITURE = "smithwesson/furniture/grip"),
		"smithwesson_38" = list(FIREARM_SLOT_ACTION = "smithwesson/action", FIREARM_SLOT_BARREL = "smithwesson/barrel/38", FIREARM_SLOT_FEED = "smithwesson/feed/38", FIREARM_SLOT_FURNITURE = "smithwesson/furniture/grip"),
		"enfieldno2" = list(FIREARM_SLOT_ACTION = "enfieldno2/action", FIREARM_SLOT_BARREL = "enfieldno2/barrel/41", FIREARM_SLOT_FEED = "enfieldno2/feed/41", FIREARM_SLOT_FURNITURE = "enfieldno2/furniture/grip"),
		"webley" = list(FIREARM_SLOT_ACTION = "webley/action", FIREARM_SLOT_BARREL = "webley/barrel/455", FIREARM_SLOT_FEED = "webley/feed/455", FIREARM_SLOT_FURNITURE = "webley/furniture/grip"),
		"type26" = list(FIREARM_SLOT_ACTION = "type26/action", FIREARM_SLOT_BARREL = "type26/barrel/9mm", FIREARM_SLOT_FEED = "type26/feed/9mm", FIREARM_SLOT_FURNITURE = "type26/furniture/grip"),
		"derringer" = list(FIREARM_SLOT_ACTION = "derringer/action", FIREARM_SLOT_BARREL = "derringer/barrel/41", FIREARM_SLOT_FEED = "derringer/feed/41", FIREARM_SLOT_FURNITURE = "derringer/furniture/grip"),
		"magnum44" = list(FIREARM_SLOT_ACTION = "magnum44/action", FIREARM_SLOT_BARREL = "magnum44/barrel/44magnum", FIREARM_SLOT_FEED = "magnum44/feed/44magnum", FIREARM_SLOT_FURNITURE = "magnum44/furniture/grip"),
		"mckellen" = list(FIREARM_SLOT_ACTION = "mckellen/action", FIREARM_SLOT_BARREL = "mckellen/barrel/44magnum", FIREARM_SLOT_FEED = "mckellen/feed/44magnum", FIREARM_SLOT_FURNITURE = "mckellen/furniture/grip"),
		"judge" = list(FIREARM_SLOT_ACTION = "judge/action", FIREARM_SLOT_BARREL = "judge/barrel/45", FIREARM_SLOT_FEED = "judge/feed/45", FIREARM_SLOT_FURNITURE = "judge/furniture/grip"),
		"revolving" = list(FIREARM_SLOT_ACTION = "revolving/action", FIREARM_SLOT_BARREL = "revolving/barrel/44", FIREARM_SLOT_FEED = "revolving/feed/44", FIREARM_SLOT_FURNITURE = "revolving/furniture/stock"),
		"pump" = list(FIREARM_SLOT_ACTION = "pump/action", FIREARM_SLOT_BARREL = "pump/barrel/12g", FIREARM_SLOT_FEED = "pump/feed/12g", FIREARM_SLOT_FURNITURE = "pump/furniture/stock"),
		"ks23" = list(FIREARM_SLOT_ACTION = "ks23/action", FIREARM_SLOT_BARREL = "ks23/barrel/12g", FIREARM_SLOT_FEED = "ks23/feed/12g", FIREARM_SLOT_FURNITURE = "ks23/furniture/stock"),
		"coachgun" = list(FIREARM_SLOT_ACTION = "coachgun/action", FIREARM_SLOT_BARREL = "coachgun/barrel/12g", FIREARM_SLOT_FEED = "coachgun/feed/12g", FIREARM_SLOT_FURNITURE = "coachgun/furniture/stock"),
		"mts225" = list(FIREARM_SLOT_ACTION = "mts225/action", FIREARM_SLOT_BARREL = "mts225/barrel/12g", FIREARM_SLOT_FEED = "mts225/feed/12g", FIREARM_SLOT_FURNITURE = "mts225/furniture/stock"),
		"remington11" = list(FIREARM_SLOT_ACTION = "remington11/action", FIREARM_SLOT_BARREL = "remington11/barrel/12g", FIREARM_SLOT_FEED = "remington11/feed/12g", FIREARM_SLOT_FURNITURE = "remington11/furniture/stock"),
		"spas" = list(FIREARM_SLOT_ACTION = "spas/action", FIREARM_SLOT_BARREL = "spas/barrel/12g", FIREARM_SLOT_FEED = "spas/feed/12g", FIREARM_SLOT_FURNITURE = "spas/furniture/stock"),
		"saiga" = list(FIREARM_SLOT_ACTION = "saiga/action", FIREARM_SLOT_BARREL = "saiga/barrel/12g", FIREARM_SLOT_FEED = "saiga/feed/12g", FIREARM_SLOT_FURNITURE = "saiga/furniture/stock"),
		"usas12" = list(FIREARM_SLOT_ACTION = "usas12/action", FIREARM_SLOT_BARREL = "usas12/barrel/12g", FIREARM_SLOT_FEED = "usas12/feed/12g", FIREARM_SLOT_FURNITURE = "usas12/furniture/stock"),
		"ar12" = list(FIREARM_SLOT_ACTION = "ar12/action", FIREARM_SLOT_BARREL = "ar12/barrel/12g", FIREARM_SLOT_FEED = "ar12/feed/12g", FIREARM_SLOT_FURNITURE = "ar12/furniture/stock"),
		"mp40" = list(FIREARM_SLOT_ACTION = "mp40/action", FIREARM_SLOT_BARREL = "mp40/barrel/9x19", FIREARM_SLOT_FEED = "mp40/feed/9x19", FIREARM_SLOT_FURNITURE = "mp40/furniture/stock"),
		"erma" = list(FIREARM_SLOT_ACTION = "erma/action", FIREARM_SLOT_BARREL = "erma/barrel/9x19", FIREARM_SLOT_FEED = "erma/feed/9x19", FIREARM_SLOT_FURNITURE = "erma/furniture/stock"),
		"mab38" = list(FIREARM_SLOT_ACTION = "mab38/action", FIREARM_SLOT_BARREL = "mab38/barrel/9x19", FIREARM_SLOT_FEED = "mab38/feed/9x19", FIREARM_SLOT_FURNITURE = "mab38/furniture/stock"),
		"sten" = list(FIREARM_SLOT_ACTION = "sten/action", FIREARM_SLOT_BARREL = "sten/barrel/9x19", FIREARM_SLOT_FEED = "sten/feed/9x19", FIREARM_SLOT_FURNITURE = "sten/furniture/stock"),
		"thompson" = list(FIREARM_SLOT_ACTION = "thompson/action", FIREARM_SLOT_BARREL = "thompson/barrel/45acp", FIREARM_SLOT_FEED = "thompson/feed/45acp", FIREARM_SLOT_FURNITURE = "thompson/furniture/stock"),
		"greasegun" = list(FIREARM_SLOT_ACTION = "greasegun/action", FIREARM_SLOT_BARREL = "greasegun/barrel/45acp", FIREARM_SLOT_FEED = "greasegun/feed/45acp", FIREARM_SLOT_FURNITURE = "greasegun/furniture/stock"),
		"ppsh" = list(FIREARM_SLOT_ACTION = "ppsh/action", FIREARM_SLOT_BARREL = "ppsh/barrel/762x25", FIREARM_SLOT_FEED = "ppsh/feed/762x25", FIREARM_SLOT_FURNITURE = "ppsh/furniture/stock"),
		"ppd" = list(FIREARM_SLOT_ACTION = "ppd/action", FIREARM_SLOT_BARREL = "ppd/barrel/762x25", FIREARM_SLOT_FEED = "ppd/feed/762x25", FIREARM_SLOT_FURNITURE = "ppd/furniture/stock"),
		"pps" = list(FIREARM_SLOT_ACTION = "pps/action", FIREARM_SLOT_BARREL = "pps/barrel/762x25", FIREARM_SLOT_FEED = "pps/feed/762x25", FIREARM_SLOT_FURNITURE = "pps/furniture/stock"),
		"type100" = list(FIREARM_SLOT_ACTION = "type100/action", FIREARM_SLOT_BARREL = "type100/barrel/8mm", FIREARM_SLOT_FEED = "type100/feed/8mm", FIREARM_SLOT_FURNITURE = "type100/furniture/stock"),
		"mp5" = list(FIREARM_SLOT_ACTION = "mp5/action", FIREARM_SLOT_BARREL = "mp5/barrel/9x19", FIREARM_SLOT_FEED = "mp5/feed/9x19", FIREARM_SLOT_FURNITURE = "mp5/furniture/stock"),
		"uzi" = list(FIREARM_SLOT_ACTION = "uzi/action", FIREARM_SLOT_BARREL = "uzi/barrel/9x19", FIREARM_SLOT_FEED = "uzi/feed/9x19", FIREARM_SLOT_FURNITURE = "uzi/furniture/stock"),
		"skorpion" = list(FIREARM_SLOT_ACTION = "skorpion/action", FIREARM_SLOT_BARREL = "skorpion/barrel/9x19", FIREARM_SLOT_FEED = "skorpion/feed/9x19", FIREARM_SLOT_FURNITURE = "skorpion/furniture/stock"),
		"tec9" = list(FIREARM_SLOT_ACTION = "tec9/action", FIREARM_SLOT_BARREL = "tec9/barrel/9x19", FIREARM_SLOT_FEED = "tec9/feed/9x19", FIREARM_SLOT_FURNITURE = "tec9/furniture/grip"),
		"vector" = list(FIREARM_SLOT_ACTION = "vector/action", FIREARM_SLOT_BARREL = "vector/barrel/9x19", FIREARM_SLOT_FEED = "vector/feed/9x19", FIREARM_SLOT_FURNITURE = "vector/furniture/stock"),
		"mac10" = list(FIREARM_SLOT_ACTION = "mac10/action", FIREARM_SLOT_BARREL = "mac10/barrel/45acp", FIREARM_SLOT_FEED = "mac10/feed/45acp", FIREARM_SLOT_FURNITURE = "mac10/furniture/stock"),
		"p90" = list(FIREARM_SLOT_ACTION = "p90/action", FIREARM_SLOT_BARREL = "p90/barrel/57x28", FIREARM_SLOT_FEED = "p90/feed/57x28", FIREARM_SLOT_FURNITURE = "p90/furniture/stock"),
		"sr3" = list(FIREARM_SLOT_ACTION = "sr3/action", FIREARM_SLOT_BARREL = "sr3/barrel/9x39", FIREARM_SLOT_FEED = "sr3/feed/9x39", FIREARM_SLOT_FURNITURE = "sr3/furniture/stock"),
		"stg" = list(FIREARM_SLOT_ACTION = "stg/action", FIREARM_SLOT_BARREL = "stg/barrel/792x33", FIREARM_SLOT_FEED = "stg/feed/792x33", FIREARM_SLOT_FURNITURE = "stg/furniture/stock"),
		"fg42" = list(FIREARM_SLOT_ACTION = "fg42/action", FIREARM_SLOT_BARREL = "fg42/barrel/792x57", FIREARM_SLOT_FEED = "fg42/feed/792x57", FIREARM_SLOT_FURNITURE = "fg42/furniture/stock"),
		"m14" = list(FIREARM_SLOT_ACTION = "m14/action", FIREARM_SLOT_BARREL = "m14/barrel/762x51", FIREARM_SLOT_FEED = "m14/feed/762x51", FIREARM_SLOT_FURNITURE = "m14/furniture/stock"),
		"fal" = list(FIREARM_SLOT_ACTION = "fal/action", FIREARM_SLOT_BARREL = "fal/barrel/762x51", FIREARM_SLOT_FEED = "fal/feed/762x51", FIREARM_SLOT_FURNITURE = "fal/furniture/stock"),
		"g3" = list(FIREARM_SLOT_ACTION = "g3/action", FIREARM_SLOT_BARREL = "g3/barrel/762x51", FIREARM_SLOT_FEED = "g3/feed/762x51", FIREARM_SLOT_FURNITURE = "g3/furniture/stock"),
		"ar10" = list(FIREARM_SLOT_ACTION = "ar10/action", FIREARM_SLOT_BARREL = "ar10/barrel/762x51", FIREARM_SLOT_FEED = "ar10/feed/762x51", FIREARM_SLOT_FURNITURE = "ar10/furniture/stock"),
		"hk417" = list(FIREARM_SLOT_ACTION = "hk417/action", FIREARM_SLOT_BARREL = "hk417/barrel/762x51", FIREARM_SLOT_FEED = "hk417/feed/762x51", FIREARM_SLOT_FURNITURE = "hk417/furniture/stock"),
		"scar_l" = list(FIREARM_SLOT_ACTION = "scar/action", FIREARM_SLOT_BARREL = "scar/barrel/556x45", FIREARM_SLOT_FEED = "scar/feed/556x45", FIREARM_SLOT_FURNITURE = "scar/furniture/stock"),
		"scar_h" = list(FIREARM_SLOT_ACTION = "scar/action", FIREARM_SLOT_BARREL = "scar/barrel/762x51", FIREARM_SLOT_FEED = "scar/feed/762x51", FIREARM_SLOT_FURNITURE = "scar/furniture/stock"),
		"aug" = list(FIREARM_SLOT_ACTION = "aug/action", FIREARM_SLOT_BARREL = "aug/barrel/556x45", FIREARM_SLOT_FEED = "aug/feed/556x45", FIREARM_SLOT_FURNITURE = "aug/furniture/stock"),
		"l85" = list(FIREARM_SLOT_ACTION = "l85/action", FIREARM_SLOT_BARREL = "l85/barrel/556x45", FIREARM_SLOT_FEED = "l85/feed/556x45", FIREARM_SLOT_FURNITURE = "l85/furniture/stock"),
		"qbz95" = list(FIREARM_SLOT_ACTION = "qbz95/action", FIREARM_SLOT_BARREL = "qbz95/barrel/58x42", FIREARM_SLOT_FEED = "qbz95/feed/58x42", FIREARM_SLOT_FURNITURE = "qbz95/furniture/stock"),
		"vz58" = list(FIREARM_SLOT_ACTION = "vz58/action", FIREARM_SLOT_BARREL = "vz58/barrel/762x39", FIREARM_SLOT_FEED = "vz58/feed/762x39", FIREARM_SLOT_FURNITURE = "vz58/furniture/stock"),
		// A factory-made receiver starts empty and is built up from parts.
		"ak_receiver" = list(),
		"ar_receiver" = list(),
		"mauser_receiver" = list(),
		"mosin_receiver" = list(),
		"arisaka_receiver" = list(),
		"enfield_receiver" = list(),
		"springfield_receiver" = list(),
		"lebel_receiver" = list(),
		"berthier_receiver" = list(),
		"carcano_receiver" = list(),
		"murata_receiver" = list(),
		"berdan_receiver" = list(),
		"vg_receiver" = list(),
		"m24_receiver" = list(),
		"sharps_receiver" = list(),
		"rollingblock_receiver" = list(),
		"martini_receiver" = list(),
		"ptrd_receiver" = list(),
		"pzb_receiver" = list(),
		"barrett_receiver" = list(),
		"sks_receiver" = list(),
		"gewehr43_receiver" = list(),
		"svt_receiver" = list(),
		"garand_receiver" = list(),
		"m1carbine_receiver" = list(),
		"avtomat_receiver" = list(),
		"vg5_receiver" = list(),
		"ptrs_receiver" = list(),
		"svd_receiver" = list(),
		"vss_receiver" = list(),
		"m82_receiver" = list(),
		"bamr_receiver" = list(),
		"lever_receiver" = list(),
		"nambu_receiver" = list(),
		"bergmann_receiver" = list(),
		"luger_receiver" = list(),
		"walther_receiver" = list(),
		"browninghp_receiver" = list(),
		"c96_receiver" = list(),
		"borchardt_receiver" = list(),
		"colthammerless_receiver" = list(),
		"m1911_receiver" = list(),
		"tt_receiver" = list(),
		"makarov_receiver" = list(),
		"aps_receiver" = list(),
		"glock_receiver" = list(),
		"beretta_receiver" = list(),
		"jericho_receiver" = list(),
		"sig250_receiver" = list(),
		"p220_receiver" = list(),
		"pl14_receiver" = list(),
		"mp443_receiver" = list(),
		"deagle_receiver" = list(),
		"nagant_receiver" = list(),
		"m1892_receiver" = list(),
		"colt_saa_receiver" = list(),
		"colt1892_receiver" = list(),
		"policepositive_receiver" = list(),
		"smithwesson_receiver" = list(),
		"enfieldno2_receiver" = list(),
		"webley_receiver" = list(),
		"type26_receiver" = list(),
		"derringer_receiver" = list(),
		"magnum44_receiver" = list(),
		"mckellen_receiver" = list(),
		"judge_receiver" = list(),
		"revolving_receiver" = list(),
		"pump_receiver" = list(),
		"ks23_receiver" = list(),
		"coachgun_receiver" = list(),
		"mts225_receiver" = list(),
		"remington11_receiver" = list(),
		"spas_receiver" = list(),
		"saiga_receiver" = list(),
		"usas12_receiver" = list(),
		"ar12_receiver" = list(),
		"mp40_receiver" = list(),
		"erma_receiver" = list(),
		"mab38_receiver" = list(),
		"sten_receiver" = list(),
		"thompson_receiver" = list(),
		"greasegun_receiver" = list(),
		"ppsh_receiver" = list(),
		"ppd_receiver" = list(),
		"pps_receiver" = list(),
		"type100_receiver" = list(),
		"mp5_receiver" = list(),
		"uzi_receiver" = list(),
		"skorpion_receiver" = list(),
		"tec9_receiver" = list(),
		"vector_receiver" = list(),
		"mac10_receiver" = list(),
		"p90_receiver" = list(),
		"sr3_receiver" = list(),
		"stg_receiver" = list(),
		"fg42_receiver" = list(),
		"m14_receiver" = list(),
		"fal_receiver" = list(),
		"g3_receiver" = list(),
		"ar10_receiver" = list(),
		"hk417_receiver" = list(),
		"scar_receiver" = list(),
		"aug_receiver" = list(),
		"l85_receiver" = list(),
		"qbz95_receiver" = list(),
		"vz58_receiver" = list(),
	)

var/global/list/firearm_family_labels = list("ak" = "AK", "ar" = "AR", "mauser" = "Mauser", "mosin" = "Mosin", "arisaka" = "Arisaka",
	"enfield" = "Lee-Enfield", "springfield" = "Springfield", "lebel" = "Lebel", "berthier" = "Berthier", "carcano" = "Carcano",
	"murata" = "Murata", "berdan" = "Berdan", "vg" = "Volkssturmgewehr", "m24" = "M24", "sharps" = "Sharps", "rollingblock" = "Rolling-block",
	"martini" = "Martini-Henry", "ptrd" = "PTRD", "pzb" = "PzB", "barrett" = "Barrett",
	"sks" = "SKS", "gewehr43" = "Gewehr 41/43", "svt" = "SVT", "garand" = "M1 Garand", "m1carbine" = "M1 Carbine", "avtomat" = "Fedorov",
	"vg5" = "Volkssturmkarabiner", "ptrs" = "PTRS", "svd" = "SVD", "vss" = "VSS", "m82" = "Barrett M82", "bamr" = "BAMR", "lever" = "Lever-action",
	"nambu" = "Nambu", "bergmann" = "Bergmann", "luger" = "Luger", "walther" = "Walther P38", "browninghp" = "Browning Hi-Power", "c96" = "Mauser C96", "borchardt" = "Borchardt", "colthammerless" = "Colt Pocket Hammerless", "m1911" = "M1911", "tt" = "Tokarev", "makarov" = "Makarov", "aps" = "Stechkin", "glock" = "Glock", "beretta" = "Beretta M9", "jericho" = "Jericho 941", "sig250" = "SIG 250", "p220" = "SIG P220", "pl14" = "PL-14", "mp443" = "MP-443", "deagle" = "Desert Eagle", "nagant" = "Nagant", "m1892" = "Modele 1892", "colt_saa" = "Colt Single Action", "colt1892" = "Colt M1892", "policepositive" = "Colt Police Positive", "smithwesson" = "Smith & Wesson", "enfieldno2" = "Enfield No. 2", "webley" = "Webley", "type26" = "Type 26", "derringer" = "Derringer", "magnum44" = "Magnum 44", "mckellen" = "Mckellen", "judge" = "Taurus Judge", "revolving" = "Colt Revolving",
	"pump" = "Pump-action", "ks23" = "KS-23", "coachgun" = "Coach gun", "mts225" = "MTS-225", "remington11" = "Remington 11", "spas" = "SPAS-12", "saiga" = "Saiga-12", "usas12" = "USAS-12", "ar12" = "AR-12", "mp40" = "MP40", "erma" = "Erma EMP", "mab38" = "MAB 38", "sten" = "Sten", "thompson" = "Thompson", "greasegun" = "M3 Grease Gun", "ppsh" = "PPSh", "ppd" = "PPD", "pps" = "PPS", "type100" = "Type 100", "mp5" = "MP5", "uzi" = "Uzi", "skorpion" = "Skorpion", "tec9" = "TEC-9", "vector" = "Kriss Vector", "mac10" = "MAC-10", "p90" = "P90", "sr3" = "SR-3", "stg" = "StG-44", "fg42" = "FG42", "m14" = "M14", "fal" = "FAL", "g3" = "G3", "ar10" = "AR-10", "hk417" = "HK417", "scar" = "SCAR", "aug" = "AUG", "l85" = "L85", "qbz95" = "QBZ-95", "vz58" = "VZ-58")
var/global/list/firearm_caliber_labels = list("a762x39" = "7.62x39mm", "a545x39" = "5.45x39mm", "a556x45" = "5.56x45mm",
	"a792x57" = "7.92x57mm", "a765x53" = "7.65x53mm", "a7x57" = "7x57mm", "a762x54" = "7.62x54mmR",
	"a65x50" = "6.5x50mm", "a77x58" = "7.7x58mm", "a303" = ".303 British", "a3006" = ".30-06", "a8x50" = "8x50mmR",
	"a65x52" = "6.5x52mm", "a8x53" = "8x53mm", "a792x33" = "7.92x33mm Kurz", "a762x51" = "7.62x51mm", "a4570" = ".45-70",
	"a43" = ".43 Spanish", "a577" = ".577/450", "a145" = "14.5x114mm", "a792x94" = "7.92x94mm", "a50cal" = ".50 BMG",
	"a762x33" = "7.62x33mm", "a9x39" = "9x39mm", "a15115" = "15x115mm", "a44" = ".44-40", "a357" = ".357 Magnum",
	"c8mmnambu" = "8mm Nambu", "a9x19" = "9x19mm", "a9x18" = "9x18mm", "a762x25" = "7.62x25mm", "a765x25" = "7.65x25mm", "a32acp" = ".32 ACP",
	"a380acp" = ".380 ACP", "a45acp" = ".45 ACP", "a45" = ".45 Colt", "a44magnum" = ".44 Magnum", "a762x38" = "7.62x38mmR", "a8x27" = "8x27mmR",
	"a38" = ".38", "a32" = ".32", "a41" = ".41", "a455" = ".455 Webley", "c9mm_jap_revolver" = "9mm Japanese",
	"12gauge" = "12 gauge", "a57x28" = "5.7x28mm", "a58x42" = "5.8x42mm")

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
	firearm_fixed_reason = "takes its own magazines"
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
	firearm_fixed_reason = "sawn-off with its own weight, size and damage"
// The training Arisaka fires wooden bullets only; real parts would make it a weapon.
/obj/item/weapon/gun/projectile/boltaction/arisaka99_training
	firearm_fixed_reason = "training rifle that fires wooden bullets"
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

// The Gewehr 71 and Madsen M47 take the Mauser 7.65x53mm parts. The Madsen used
// to name 7.62x51 loose rounds for its 7.65x53mm chamber.
/obj/item/weapon/gun/projectile/boltaction/gewehr71
	firearm_family = "mauser"
	firearm_preset = "mauser_765"
/obj/item/weapon/gun/projectile/boltaction/madsenm47
	firearm_family = "mauser"
	firearm_preset = "mauser_765"
	ammo_type = /obj/item/ammo_casing/a765x53
/obj/item/weapon/gun/projectile/boltaction/enfield
	firearm_family = "enfield"
	firearm_preset = "enfield"
/obj/item/weapon/gun/projectile/boltaction/p14enfield
	firearm_family = "enfield"
	firearm_preset = "enfield"
/obj/item/weapon/gun/projectile/boltaction/springfield
	firearm_family = "springfield"
	firearm_preset = "springfield"
/obj/item/weapon/gun/projectile/boltaction/lebel
	firearm_family = "lebel"
	firearm_preset = "lebel"
/obj/item/weapon/gun/projectile/boltaction/berthier
	firearm_family = "berthier"
	firearm_preset = "berthier_3"
// The M1907/16 used to accept only three-round clips despite its five-round magazine.
/obj/item/weapon/gun/projectile/boltaction/berthier/m16
	firearm_preset = "berthier_5"
	good_mags = list(/obj/item/ammo_magazine/c8x50_5clip)
/obj/item/weapon/gun/projectile/boltaction/carcano
	firearm_family = "carcano"
	firearm_preset = "carcano"
/obj/item/weapon/gun/projectile/boltaction/murata
	firearm_family = "murata"
	firearm_preset = "murata"
/obj/item/weapon/gun/projectile/boltaction/berdan
	firearm_family = "berdan"
	firearm_preset = "berdan"
/obj/item/weapon/gun/projectile/boltaction/vg
	firearm_family = "vg"
	firearm_preset = "vg"
/obj/item/weapon/gun/projectile/boltaction/m24
	firearm_family = "m24"
	firearm_preset = "m24"
/obj/item/weapon/gun/projectile/boltaction/singleshot
	firearm_family = "sharps"
	firearm_preset = "sharps"
/obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock
	firearm_family = "rollingblock"
	firearm_preset = "rollingblock_4570"
/obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock/spanish
	firearm_preset = "rollingblock_43"
/obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry
	firearm_family = "martini"
	firearm_preset = "martini"
/obj/item/weapon/gun/projectile/boltaction/singleshot/ptrd
	firearm_family = "ptrd"
	firearm_preset = "ptrd"
/obj/item/weapon/gun/projectile/boltaction/singleshot/pzb39
	firearm_family = "pzb"
	firearm_preset = "pzb"
/obj/item/weapon/gun/projectile/boltaction/singleshot/barrett
	firearm_family = "barrett"
	firearm_preset = "barrett"
/obj/item/weapon/gun/projectile/semiautomatic/sks
	firearm_family = "sks"
	firearm_preset = "sks"
/obj/item/weapon/gun/projectile/semiautomatic/sks/sksm
	firearm_preset = "sksm"
/obj/item/weapon/gun/projectile/semiautomatic/g41
	firearm_family = "gewehr43"
	firearm_preset = "gewehr41"
/obj/item/weapon/gun/projectile/semiautomatic/g43
	firearm_family = "gewehr43"
	firearm_preset = "gewehr43"
/obj/item/weapon/gun/projectile/semiautomatic/svt
	firearm_family = "svt"
	firearm_preset = "svt"
/obj/item/weapon/gun/projectile/semiautomatic/m1garand
	firearm_family = "garand"
	firearm_preset = "garand"
/obj/item/weapon/gun/projectile/semiautomatic/m1carbine
	firearm_family = "m1carbine"
	firearm_preset = "m1carbine"
/obj/item/weapon/gun/projectile/semiautomatic/avtomat
	firearm_family = "avtomat"
	firearm_preset = "avtomat"
/obj/item/weapon/gun/projectile/semiautomatic/vg5
	firearm_family = "vg5"
	firearm_preset = "vg5"
/obj/item/weapon/gun/projectile/semiautomatic/ptrs
	firearm_family = "ptrs"
	firearm_preset = "ptrs"
/obj/item/weapon/gun/projectile/semiautomatic/svd
	firearm_family = "svd"
	firearm_preset = "svd"
/obj/item/weapon/gun/projectile/semiautomatic/vintorez
	firearm_family = "vss"
	firearm_preset = "vss"
/obj/item/weapon/gun/projectile/semiautomatic/barrett
	firearm_family = "m82"
	firearm_preset = "m82"
/obj/item/weapon/gun/projectile/semiautomatic/bamr
	firearm_family = "bamr"
	firearm_preset = "bamr"
/obj/item/weapon/gun/projectile/leveraction
	firearm_family = "lever"
	firearm_preset = "lever_44"
/obj/item/weapon/gun/projectile/leveraction/winchesterm1886
	firearm_preset = "lever_4570"
/obj/item/weapon/gun/projectile/leveraction/cowboy_repeater
	firearm_preset = "lever_357"
// The semi-automatic AR-15 and MK-18 take AR parts; the MK-18's own magazines are STANAG.
/obj/item/weapon/gun/projectile/semiautomatic/ar15
	firearm_family = "ar"
	firearm_preset = "ar_rifle"
/obj/item/weapon/gun/projectile/special/mk18
	firearm_family = "ar"
	firearm_preset = "ar_carbine"
/obj/item/weapon/gun/projectile/special/ak74mtactical
	firearm_family = "ak"
	firearm_preset = "aks74"
/obj/item/weapon/gun/projectile/pistol/nambu
	firearm_family = "nambu"
	firearm_preset = "nambu"
/obj/item/weapon/gun/projectile/pistol/ww2/nambu
	firearm_family = "nambu"
	firearm_preset = "nambu"
/obj/item/weapon/gun/projectile/pistol/bergmann
	firearm_family = "bergmann"
	firearm_preset = "bergmann"
/obj/item/weapon/gun/projectile/pistol/luger
	firearm_family = "luger"
	firearm_preset = "luger"
/obj/item/weapon/gun/projectile/pistol/waltherp38
	firearm_family = "walther"
	firearm_preset = "walther"
/obj/item/weapon/gun/projectile/pistol/browninghp
	firearm_family = "browninghp"
	firearm_preset = "browninghp"
/obj/item/weapon/gun/projectile/pistol/mauser
	firearm_family = "c96"
	firearm_preset = "c96"
/obj/item/weapon/gun/projectile/pistol/borchardt
	firearm_family = "borchardt"
	firearm_preset = "borchardt"
/obj/item/weapon/gun/projectile/pistol/colthammerless
	firearm_family = "colthammerless"
	firearm_preset = "colthammerless_32"
/obj/item/weapon/gun/projectile/pistol/colthammerless/m1908
	firearm_family = "colthammerless"
	firearm_preset = "colthammerless_380"
/obj/item/weapon/gun/projectile/pistol/m1911
	firearm_family = "m1911"
	firearm_preset = "m1911"
/obj/item/weapon/gun/projectile/pistol/blackm1911
	firearm_family = "m1911"
	firearm_preset = "m1911"
/obj/item/weapon/gun/projectile/pistol/sti2011
	firearm_family = "m1911"
	firearm_preset = "sti2011"
/obj/item/weapon/gun/projectile/pistol/tt30
	firearm_family = "tt"
	firearm_preset = "tt"
/obj/item/weapon/gun/projectile/pistol/makarov
	firearm_family = "makarov"
	firearm_preset = "makarov"
/obj/item/weapon/gun/projectile/pistol/aps
	firearm_family = "aps"
	firearm_preset = "aps"
/obj/item/weapon/gun/projectile/pistol/glock17
	firearm_family = "glock"
	firearm_preset = "glock"
/obj/item/weapon/gun/projectile/pistol/iogb7
	firearm_family = "glock"
	firearm_preset = "glock"
/obj/item/weapon/gun/projectile/pistol/tarus
	firearm_family = "glock"
	firearm_preset = "glock"
/obj/item/weapon/gun/projectile/pistol/m9beretta
	firearm_family = "beretta"
	firearm_preset = "beretta"
/obj/item/weapon/gun/projectile/pistol/jericho941
	firearm_family = "jericho"
	firearm_preset = "jericho"
/obj/item/weapon/gun/projectile/pistol/sig250
	firearm_family = "sig250"
	firearm_preset = "sig250"
/obj/item/weapon/gun/projectile/pistol/p220
	firearm_family = "p220"
	firearm_preset = "p220"
/obj/item/weapon/gun/projectile/pistol/pl14
	firearm_family = "pl14"
	firearm_preset = "pl14"
/obj/item/weapon/gun/projectile/pistol/mp443
	firearm_family = "mp443"
	firearm_preset = "mp443"
/obj/item/weapon/gun/projectile/pistol/deagle
	firearm_family = "deagle"
	firearm_preset = "deagle_50"
/obj/item/weapon/gun/projectile/pistol/deaglemagnum
	firearm_family = "deagle"
	firearm_preset = "deagle_44"
/obj/item/weapon/gun/projectile/revolver/nagant_revolver
	firearm_family = "nagant"
	firearm_preset = "nagant"
/obj/item/weapon/gun/projectile/revolver/m1892
	firearm_family = "m1892"
	firearm_preset = "m1892"
/obj/item/weapon/gun/projectile/revolver/peacemaker
	firearm_family = "colt_saa"
	firearm_preset = "colt_saa_45"
/obj/item/weapon/gun/projectile/revolver/frontier
	firearm_family = "colt_saa"
	firearm_preset = "colt_saa_44"
/obj/item/weapon/gun/projectile/revolver/colt1892
	firearm_family = "colt1892"
	firearm_preset = "colt1892"
/obj/item/weapon/gun/projectile/revolver/coltpolicepositive
	firearm_family = "policepositive"
	firearm_preset = "policepositive"
/obj/item/weapon/gun/projectile/revolver/smithwesson
	firearm_family = "smithwesson"
	firearm_preset = "smithwesson_32"
/obj/item/weapon/gun/projectile/revolver/sw3
	firearm_family = "smithwesson"
	firearm_preset = "smithwesson_32"
/obj/item/weapon/gun/projectile/revolver/snw10
	firearm_family = "smithwesson"
	firearm_preset = "smithwesson_38"
/obj/item/weapon/gun/projectile/revolver/enfieldno2
	firearm_family = "enfieldno2"
	firearm_preset = "enfieldno2"
/obj/item/weapon/gun/projectile/revolver/webley4
	firearm_family = "webley"
	firearm_preset = "webley"
/obj/item/weapon/gun/projectile/revolver/t26_revolver
	firearm_family = "type26"
	firearm_preset = "type26"
/obj/item/weapon/gun/projectile/revolver/derringer
	firearm_family = "derringer"
	firearm_preset = "derringer"
/obj/item/weapon/gun/projectile/revolver/magnum44
	firearm_family = "magnum44"
	firearm_preset = "magnum44"
/obj/item/weapon/gun/projectile/revolver/graysonfito12
	firearm_family = "mckellen"
	firearm_preset = "mckellen"
/obj/item/weapon/gun/projectile/revolver/taurus
	firearm_family = "judge"
	firearm_preset = "judge"
/obj/item/weapon/gun/projectile/revolving/colt
	firearm_family = "revolving"
	firearm_preset = "revolving"
// The Panther fires a placeholder test cartridge and the makeshift revolver is a one-off build.
/obj/item/weapon/gun/projectile/revolver/panther
	firearm_fixed_reason = "legacy revolver with a placeholder test cartridge"
/obj/item/weapon/gun/projectile/revolver/makeshift
	firearm_fixed_reason = "crude one-off build with no standard parts"
/obj/item/weapon/gun/projectile/pistol
	firearm_kind = "pistol"
/obj/item/weapon/gun/projectile/revolver
	firearm_kind = "revolver"
/obj/item/weapon/gun/projectile/revolver/derringer
	firearm_kind = "pistol"
/obj/item/weapon/gun/projectile/shotgun
	firearm_kind = "shotgun"
/obj/item/weapon/gun/projectile/shotgun/pump
	firearm_family = "pump"
	firearm_preset = "pump"
	firearm_kind = "shotgun"
/obj/item/weapon/gun/projectile/shotgun/pump/ks23
	firearm_family = "ks23"
	firearm_preset = "ks23"
	firearm_kind = "shotgun"
/obj/item/weapon/gun/projectile/shotgun/coachgun
	firearm_family = "coachgun"
	firearm_preset = "coachgun"
	firearm_kind = "shotgun"
/obj/item/weapon/gun/projectile/shotgun/mts225
	firearm_family = "mts225"
	firearm_preset = "mts225"
	firearm_kind = "shotgun"
/obj/item/weapon/gun/projectile/semiautomatic/remington11
	firearm_family = "remington11"
	firearm_preset = "remington11"
	firearm_kind = "shotgun"
/obj/item/weapon/gun/projectile/submachinegun/spas
	firearm_family = "spas"
	firearm_preset = "spas"
	firearm_kind = "shotgun"
/obj/item/weapon/gun/projectile/submachinegun/saiga12
	firearm_family = "saiga"
	firearm_preset = "saiga"
	firearm_kind = "shotgun"
/obj/item/weapon/gun/projectile/submachinegun/usas12
	firearm_family = "usas12"
	firearm_preset = "usas12"
	firearm_kind = "shotgun"
/obj/item/weapon/gun/projectile/submachinegun/ar12
	firearm_family = "ar12"
	firearm_preset = "ar12"
	firearm_kind = "shotgun"
/obj/item/weapon/gun/projectile/submachinegun/mp40
	firearm_family = "mp40"
	firearm_preset = "mp40"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/ermaemp
	firearm_family = "erma"
	firearm_preset = "erma"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/mp40/modello38
	firearm_family = "mab38"
	firearm_preset = "mab38"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/sten
	firearm_family = "sten"
	firearm_preset = "sten"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/thompson
	firearm_family = "thompson"
	firearm_preset = "thompson"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/tommy
	firearm_family = "thompson"
	firearm_preset = "thompson"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/greasegun
	firearm_family = "greasegun"
	firearm_preset = "greasegun"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/ppsh
	firearm_family = "ppsh"
	firearm_preset = "ppsh"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/ppd
	firearm_family = "ppd"
	firearm_preset = "ppd"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/pps
	firearm_family = "pps"
	firearm_preset = "pps"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/type100
	firearm_family = "type100"
	firearm_preset = "type100"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/mp40/mp5
	firearm_family = "mp5"
	firearm_preset = "mp5"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/uzi
	firearm_family = "uzi"
	firearm_preset = "uzi"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/skorpion
	firearm_family = "skorpion"
	firearm_preset = "skorpion"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/tec9
	firearm_family = "tec9"
	firearm_preset = "tec9"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/vector
	firearm_family = "vector"
	firearm_preset = "vector"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/mac10
	firearm_family = "mac10"
	firearm_preset = "mac10"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/p90
	firearm_family = "p90"
	firearm_preset = "p90"
	firearm_kind = "submachine gun"
/obj/item/weapon/gun/projectile/submachinegun/srm
	firearm_family = "sr3"
	firearm_preset = "sr3"
/obj/item/weapon/gun/projectile/submachinegun/stg
	firearm_family = "stg"
	firearm_preset = "stg"
/obj/item/weapon/gun/projectile/submachinegun/fg42
	firearm_family = "fg42"
	firearm_preset = "fg42"
/obj/item/weapon/gun/projectile/submachinegun/m14
	firearm_family = "m14"
	firearm_preset = "m14"
/obj/item/weapon/gun/projectile/submachinegun/fal
	firearm_family = "fal"
	firearm_preset = "fal"
/obj/item/weapon/gun/projectile/submachinegun/g3
	firearm_family = "g3"
	firearm_preset = "g3"
/obj/item/weapon/gun/projectile/submachinegun/ar10
	firearm_family = "ar10"
	firearm_preset = "ar10"
/obj/item/weapon/gun/projectile/submachinegun/hk417
	firearm_family = "hk417"
	firearm_preset = "hk417"
/obj/item/weapon/gun/projectile/submachinegun/scarl
	firearm_family = "scar"
	firearm_preset = "scar_l"
/obj/item/weapon/gun/projectile/submachinegun/scarh
	firearm_family = "scar"
	firearm_preset = "scar_h"
/obj/item/weapon/gun/projectile/submachinegun/aug
	firearm_family = "aug"
	firearm_preset = "aug"
/obj/item/weapon/gun/projectile/submachinegun/l85a2
	firearm_family = "l85"
	firearm_preset = "l85"
/obj/item/weapon/gun/projectile/submachinegun/qbz95
	firearm_family = "qbz95"
	firearm_preset = "qbz95"
/obj/item/weapon/gun/projectile/submachinegun/vz58
	firearm_family = "vz58"
	firearm_preset = "vz58"
// The M2 carbine is a select-fire M1 Carbine; the AK-74M, AK-12 and AK-15 are AKs.
/obj/item/weapon/gun/projectile/submachinegun/m2carbine
	firearm_family = "m1carbine"
	firearm_preset = "m1carbine"
/obj/item/weapon/gun/projectile/submachinegun/ak74m
	firearm_family = "ak"
	firearm_preset = "aks74"
/obj/item/weapon/gun/projectile/submachinegun/ak74m/ak12/ak15
	firearm_preset = "ak100_762"
/obj/item/weapon/gun/projectile/submachinegun/makeshiftak47
	firearm_fixed_reason = "crude one-off build with no standard parts"
// The makeshift bolt is a crude one-off build with no standard parts.
/obj/item/weapon/gun/projectile/boltaction/singleshot/makeshiftbolt
	firearm_family = null
	firearm_preset = null
	firearm_fixed_reason = "crude one-off build with no standard parts"

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

/obj/item/weapon/gun/projectile/boltaction/enfield/receiver
	name = "Lee-Enfield receiver"
	desc = "A bare Lee-Enfield receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_preset = "enfield_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/springfield/receiver
	name = "Springfield receiver"
	desc = "A bare Springfield receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_preset = "springfield_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/lebel/receiver
	name = "Lebel receiver"
	desc = "A bare Lebel receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_preset = "lebel_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/berthier/receiver
	name = "Berthier receiver"
	desc = "A bare Berthier receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_preset = "berthier_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/carcano/receiver
	name = "Carcano receiver"
	desc = "A bare Carcano receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_preset = "carcano_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/murata/receiver
	name = "Murata receiver"
	desc = "A bare Murata receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_family = "murata"
	firearm_preset = "murata_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/berdan/receiver
	name = "Berdan receiver"
	desc = "A bare Berdan receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_family = "berdan"
	firearm_preset = "berdan_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/vg/receiver
	name = "Volkssturmgewehr receiver"
	desc = "A bare Volkssturmgewehr receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_family = "vg"
	firearm_preset = "vg_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/m24/receiver
	name = "M24 receiver"
	desc = "A bare M24 receiver. Fit a bolt and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	firearm_family = "m24"
	firearm_preset = "m24_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/singleshot/receiver
	name = "Sharps receiver"
	desc = "A bare Sharps receiver. Fit a breechblock and barrel at a firearm bench, then an extractor and stock, to build a working rifle."
	ammo_type = null
	firearm_family = "sharps"
	firearm_preset = "sharps_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock/receiver
	name = "Rolling-block receiver"
	desc = "A bare Rolling-block receiver. Fit a breechblock and barrel at a firearm bench, then an extractor and stock, to build a working rifle."
	ammo_type = null
	firearm_family = "rollingblock"
	firearm_preset = "rollingblock_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry/receiver
	name = "Martini-Henry receiver"
	desc = "A bare Martini-Henry receiver. Fit a breechblock and barrel at a firearm bench, then an extractor and stock, to build a working rifle."
	ammo_type = null
	firearm_family = "martini"
	firearm_preset = "martini_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/singleshot/ptrd/receiver
	name = "PTRD receiver"
	desc = "A bare PTRD receiver. Fit a bolt and barrel at a firearm bench, then a breech and stock, to build a working rifle."
	ammo_type = null
	firearm_family = "ptrd"
	firearm_preset = "ptrd_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/singleshot/pzb39/receiver
	name = "PzB receiver"
	desc = "A bare PzB receiver. Fit a breechblock and barrel at a firearm bench, then a breech and stock, to build a working rifle."
	ammo_type = null
	firearm_family = "pzb"
	firearm_preset = "pzb_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/boltaction/singleshot/barrett/receiver
	name = "Barrett receiver"
	desc = "A bare Barrett receiver. Fit a bolt and barrel at a firearm bench, then a breech and stock, to build a working rifle."
	ammo_type = null
	firearm_family = "barrett"
	firearm_preset = "barrett_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/sks/receiver
	name = "SKS receiver"
	desc = "A bare SKS receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "sks"
	firearm_preset = "sks_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/g43/receiver
	name = "Gewehr 41/43 receiver"
	desc = "A bare Gewehr 41/43 receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "gewehr43"
	firearm_preset = "gewehr43_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/svt/receiver
	name = "SVT receiver"
	desc = "A bare SVT receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "svt"
	firearm_preset = "svt_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/m1garand/receiver
	name = "M1 Garand receiver"
	desc = "A bare M1 Garand receiver. Fit an operating rod and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "garand"
	firearm_preset = "garand_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/m1carbine/receiver
	name = "M1 Carbine receiver"
	desc = "A bare M1 Carbine receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "m1carbine"
	firearm_preset = "m1carbine_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/avtomat/receiver
	name = "Fedorov receiver"
	desc = "A bare Fedorov receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "avtomat"
	firearm_preset = "avtomat_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/vg5/receiver
	name = "Volkssturmkarabiner receiver"
	desc = "A bare Volkssturmkarabiner receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "vg5"
	firearm_preset = "vg5_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/ptrs/receiver
	name = "PTRS receiver"
	desc = "A bare PTRS receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "ptrs"
	firearm_preset = "ptrs_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/svd/receiver
	name = "SVD receiver"
	desc = "A bare SVD receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "svd"
	firearm_preset = "svd_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/vintorez/receiver
	name = "VSS receiver"
	desc = "A bare VSS receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "vss"
	firearm_preset = "vss_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/barrett/receiver
	name = "Barrett M82 receiver"
	desc = "A bare Barrett M82 receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "m82"
	firearm_preset = "m82_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/bamr/receiver
	name = "BAMR receiver"
	desc = "A bare BAMR receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "bamr"
	firearm_preset = "bamr_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/leveraction/receiver
	name = "Lever-action receiver"
	desc = "A bare Lever-action receiver. Fit a lever and barrel at a firearm bench, then a magazine and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "lever"
	firearm_preset = "lever_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/nambu/receiver
	name = "Nambu frame"
	desc = "A bare Nambu frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "nambu"
	firearm_preset = "nambu_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/bergmann/receiver
	name = "Bergmann frame"
	desc = "A bare Bergmann frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "bergmann"
	firearm_preset = "bergmann_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/luger/receiver
	name = "Luger frame"
	desc = "A bare Luger frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "luger"
	firearm_preset = "luger_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/waltherp38/receiver
	name = "Walther P38 frame"
	desc = "A bare Walther P38 frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "walther"
	firearm_preset = "walther_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/browninghp/receiver
	name = "Browning Hi-Power frame"
	desc = "A bare Browning Hi-Power frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "browninghp"
	firearm_preset = "browninghp_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/mauser/receiver
	name = "Mauser C96 frame"
	desc = "A bare Mauser C96 frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "c96"
	firearm_preset = "c96_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/borchardt/receiver
	name = "Borchardt frame"
	desc = "A bare Borchardt frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "borchardt"
	firearm_preset = "borchardt_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/colthammerless/receiver
	name = "Colt Pocket Hammerless frame"
	desc = "A bare Colt Pocket Hammerless frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "colthammerless"
	firearm_preset = "colthammerless_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/m1911/receiver
	name = "M1911 frame"
	desc = "A bare M1911 frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "m1911"
	firearm_preset = "m1911_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/tt30/receiver
	name = "Tokarev frame"
	desc = "A bare Tokarev frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "tt"
	firearm_preset = "tt_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/makarov/receiver
	name = "Makarov frame"
	desc = "A bare Makarov frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "makarov"
	firearm_preset = "makarov_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/aps/receiver
	name = "Stechkin frame"
	desc = "A bare Stechkin frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "aps"
	firearm_preset = "aps_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/glock17/receiver
	name = "Glock frame"
	desc = "A bare Glock frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "glock"
	firearm_preset = "glock_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/m9beretta/receiver
	name = "Beretta M9 frame"
	desc = "A bare Beretta M9 frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "beretta"
	firearm_preset = "beretta_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/jericho941/receiver
	name = "Jericho 941 frame"
	desc = "A bare Jericho 941 frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "jericho"
	firearm_preset = "jericho_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/sig250/receiver
	name = "SIG 250 frame"
	desc = "A bare SIG 250 frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "sig250"
	firearm_preset = "sig250_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/p220/receiver
	name = "SIG P220 frame"
	desc = "A bare SIG P220 frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "p220"
	firearm_preset = "p220_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/pl14/receiver
	name = "PL-14 frame"
	desc = "A bare PL-14 frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "pl14"
	firearm_preset = "pl14_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/mp443/receiver
	name = "MP-443 frame"
	desc = "A bare MP-443 frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "mp443"
	firearm_preset = "mp443_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/pistol/deagle/receiver
	name = "Desert Eagle frame"
	desc = "A bare Desert Eagle frame. Fit a slide and barrel at a firearm bench, then a magazine well and grip, to build a working pistol."
	ammo_type = null
	magazine_type = null
	firearm_family = "deagle"
	firearm_preset = "deagle_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/nagant_revolver/receiver
	name = "Nagant frame"
	desc = "A bare Nagant frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "nagant"
	firearm_preset = "nagant_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/m1892/receiver
	name = "Modele 1892 frame"
	desc = "A bare Modele 1892 frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "m1892"
	firearm_preset = "m1892_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/peacemaker/receiver
	name = "Colt Single Action frame"
	desc = "A bare Colt Single Action frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "colt_saa"
	firearm_preset = "colt_saa_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/colt1892/receiver
	name = "Colt M1892 frame"
	desc = "A bare Colt M1892 frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "colt1892"
	firearm_preset = "colt1892_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/coltpolicepositive/receiver
	name = "Colt Police Positive frame"
	desc = "A bare Colt Police Positive frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "policepositive"
	firearm_preset = "policepositive_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/smithwesson/receiver
	name = "Smith & Wesson frame"
	desc = "A bare Smith & Wesson frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "smithwesson"
	firearm_preset = "smithwesson_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/enfieldno2/receiver
	name = "Enfield No. 2 frame"
	desc = "A bare Enfield No. 2 frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "enfieldno2"
	firearm_preset = "enfieldno2_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/webley4/receiver
	name = "Webley frame"
	desc = "A bare Webley frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "webley"
	firearm_preset = "webley_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/t26_revolver/receiver
	name = "Type 26 frame"
	desc = "A bare Type 26 frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "type26"
	firearm_preset = "type26_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/derringer/receiver
	name = "Derringer frame"
	desc = "A bare Derringer frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "derringer"
	firearm_preset = "derringer_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/magnum44/receiver
	name = "Magnum 44 frame"
	desc = "A bare Magnum 44 frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "magnum44"
	firearm_preset = "magnum44_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/graysonfito12/receiver
	name = "Mckellen frame"
	desc = "A bare Mckellen frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "mckellen"
	firearm_preset = "mckellen_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolver/taurus/receiver
	name = "Taurus Judge frame"
	desc = "A bare Taurus Judge frame. Fit a lockwork and barrel at a firearm bench, then a cylinder and grip, to build a working revolver."
	ammo_type = null
	magazine_type = null
	firearm_family = "judge"
	firearm_preset = "judge_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/revolving/colt/receiver
	name = "Colt Revolving receiver"
	desc = "A bare Colt Revolving receiver. Fit a lockwork and barrel at a firearm bench, then a cylinder and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "revolving"
	firearm_preset = "revolving_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/shotgun/pump/receiver
	name = "Pump-action receiver"
	desc = "A bare Pump-action receiver. Fit a pump action and barrel at a firearm bench, then a tube magazine and stock, to build a working shotgun."
	ammo_type = null
	magazine_type = null
	firearm_family = "pump"
	firearm_preset = "pump_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/shotgun/pump/ks23/receiver
	name = "KS-23 receiver"
	desc = "A bare KS-23 receiver. Fit a pump action and barrel at a firearm bench, then a tube magazine and stock, to build a working shotgun."
	ammo_type = null
	magazine_type = null
	firearm_family = "ks23"
	firearm_preset = "ks23_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/shotgun/coachgun/receiver
	name = "Coach gun receiver"
	desc = "A bare Coach gun receiver. Fit a break action and barrel at a firearm bench, then a breech and stock, to build a working shotgun."
	ammo_type = null
	magazine_type = null
	firearm_family = "coachgun"
	firearm_preset = "coachgun_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/shotgun/mts225/receiver
	name = "MTS-225 receiver"
	desc = "A bare MTS-225 receiver. Fit a lockwork and barrel at a firearm bench, then a cylinder and stock, to build a working shotgun."
	ammo_type = null
	magazine_type = null
	firearm_family = "mts225"
	firearm_preset = "mts225_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/semiautomatic/remington11/receiver
	name = "Remington 11 receiver"
	desc = "A bare Remington 11 receiver. Fit an action and barrel at a firearm bench, then a tube magazine and stock, to build a working shotgun."
	ammo_type = null
	magazine_type = null
	firearm_family = "remington11"
	firearm_preset = "remington11_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/spas/receiver
	name = "SPAS-12 receiver"
	desc = "A bare SPAS-12 receiver. Fit an action and barrel at a firearm bench, then a tube magazine and stock, to build a working shotgun."
	ammo_type = null
	magazine_type = null
	firearm_family = "spas"
	firearm_preset = "spas_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/saiga12/receiver
	name = "Saiga-12 receiver"
	desc = "A bare Saiga-12 receiver. Fit an action and barrel at a firearm bench, then a magazine well and stock, to build a working shotgun."
	ammo_type = null
	magazine_type = null
	firearm_family = "saiga"
	firearm_preset = "saiga_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/usas12/receiver
	name = "USAS-12 receiver"
	desc = "A bare USAS-12 receiver. Fit an action and barrel at a firearm bench, then a magazine well and stock, to build a working shotgun."
	ammo_type = null
	magazine_type = null
	firearm_family = "usas12"
	firearm_preset = "usas12_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/ar12/receiver
	name = "AR-12 receiver"
	desc = "A bare AR-12 receiver. Fit an action and barrel at a firearm bench, then a magazine well and stock, to build a working shotgun."
	ammo_type = null
	magazine_type = null
	firearm_family = "ar12"
	firearm_preset = "ar12_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/mp40/receiver
	name = "MP40 receiver"
	desc = "A bare MP40 receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "mp40"
	firearm_preset = "mp40_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/ermaemp/receiver
	name = "Erma EMP receiver"
	desc = "A bare Erma EMP receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "erma"
	firearm_preset = "erma_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/mp40/modello38/receiver
	name = "MAB 38 receiver"
	desc = "A bare MAB 38 receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "mab38"
	firearm_preset = "mab38_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/sten/receiver
	name = "Sten receiver"
	desc = "A bare Sten receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "sten"
	firearm_preset = "sten_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/thompson/receiver
	name = "Thompson receiver"
	desc = "A bare Thompson receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "thompson"
	firearm_preset = "thompson_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/greasegun/receiver
	name = "M3 Grease Gun receiver"
	desc = "A bare M3 Grease Gun receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "greasegun"
	firearm_preset = "greasegun_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/ppsh/receiver
	name = "PPSh receiver"
	desc = "A bare PPSh receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "ppsh"
	firearm_preset = "ppsh_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/ppd/receiver
	name = "PPD receiver"
	desc = "A bare PPD receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "ppd"
	firearm_preset = "ppd_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/pps/receiver
	name = "PPS receiver"
	desc = "A bare PPS receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "pps"
	firearm_preset = "pps_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/type100/receiver
	name = "Type 100 receiver"
	desc = "A bare Type 100 receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "type100"
	firearm_preset = "type100_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/mp40/mp5/receiver
	name = "MP5 receiver"
	desc = "A bare MP5 receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "mp5"
	firearm_preset = "mp5_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/uzi/receiver
	name = "Uzi receiver"
	desc = "A bare Uzi receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "uzi"
	firearm_preset = "uzi_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/skorpion/receiver
	name = "Skorpion receiver"
	desc = "A bare Skorpion receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "skorpion"
	firearm_preset = "skorpion_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/tec9/receiver
	name = "TEC-9 receiver"
	desc = "A bare TEC-9 receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and grip, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "tec9"
	firearm_preset = "tec9_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/vector/receiver
	name = "Kriss Vector receiver"
	desc = "A bare Kriss Vector receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "vector"
	firearm_preset = "vector_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/mac10/receiver
	name = "MAC-10 receiver"
	desc = "A bare MAC-10 receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "mac10"
	firearm_preset = "mac10_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/p90/receiver
	name = "P90 receiver"
	desc = "A bare P90 receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working submachine gun."
	ammo_type = null
	magazine_type = null
	firearm_family = "p90"
	firearm_preset = "p90_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/srm/receiver
	name = "SR-3 receiver"
	desc = "A bare SR-3 receiver. Fit a bolt and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "sr3"
	firearm_preset = "sr3_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/stg/receiver
	name = "StG-44 receiver"
	desc = "A bare StG-44 receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "stg"
	firearm_preset = "stg_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/fg42/receiver
	name = "FG42 receiver"
	desc = "A bare FG42 receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "fg42"
	firearm_preset = "fg42_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/m14/receiver
	name = "M14 receiver"
	desc = "A bare M14 receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "m14"
	firearm_preset = "m14_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/fal/receiver
	name = "FAL receiver"
	desc = "A bare FAL receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "fal"
	firearm_preset = "fal_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/g3/receiver
	name = "G3 receiver"
	desc = "A bare G3 receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "g3"
	firearm_preset = "g3_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/ar10/receiver
	name = "AR-10 receiver"
	desc = "A bare AR-10 receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "ar10"
	firearm_preset = "ar10_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/hk417/receiver
	name = "HK417 receiver"
	desc = "A bare HK417 receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "hk417"
	firearm_preset = "hk417_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/scarh/receiver
	name = "SCAR receiver"
	desc = "A bare SCAR receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "scar"
	firearm_preset = "scar_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/aug/receiver
	name = "AUG receiver"
	desc = "A bare AUG receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "aug"
	firearm_preset = "aug_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/l85a2/receiver
	name = "L85 receiver"
	desc = "A bare L85 receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "l85"
	firearm_preset = "l85_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/qbz95/receiver
	name = "QBZ-95 receiver"
	desc = "A bare QBZ-95 receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "qbz95"
	firearm_preset = "qbz95_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun/projectile/submachinegun/vz58/receiver
	name = "VZ-58 receiver"
	desc = "A bare VZ-58 receiver. Fit a bolt carrier and barrel at a firearm bench, then a magazine well and stock, to build a working rifle."
	ammo_type = null
	magazine_type = null
	firearm_family = "vz58"
	firearm_preset = "vz58_receiver"
	firearm_named_by_parts = TRUE

/obj/item/weapon/gun
	var/firearm_family = null
	var/firearm_preset = null
	// Why a modern gun deliberately has no modular parts (coverage manifest).
	var/firearm_fixed_reason = null
	var/firearm_named_by_parts = FALSE
	// What a gun built from parts is called: "[family] [kind] ([caliber])".
	var/firearm_kind = "rifle"
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
		if (islist(feed.ammo_type))
			var/list/rounds = feed.ammo_type
			G.ammo_type = rounds.Copy()
		else if (feed.ammo_type)
			G.ammo_type = feed.ammo_type
		G.max_shells = isnull(feed.capacity) ? initial(G.max_shells) : feed.capacity
		G.load_method = isnull(feed.load_method) ? initial(G.load_method) : feed.load_method
		G.cliploader = isnull(feed.cliploader) ? initial(G.cliploader) : feed.cliploader
	if (firearm_named_by_parts)
		name = barrel ? "[firearm_family_labels[firearm_family]] [firearm_kind] ([firearm_caliber_labels[barrel.caliber]])" : initial(name)
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
		return "that part is for a different gun family"
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
	set name = "Gun Parts"
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
	var/choice = WWinput(H, firearm_salvage_preview(P), "Salvage gun part", "Cancel", list("Salvage", "Cancel"))
	if (choice != "Salvage")
		return FALSE
	return firearm_salvage(P, H)

/obj/item/weapon/gun_component
	name = "gun part"
	desc = "A modular gun part."
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

/obj/item/weapon/gun_component/enfield_action
	component_id = "enfield/action"
/obj/item/weapon/gun_component/enfield_barrel_303
	component_id = "enfield/barrel/303"
/obj/item/weapon/gun_component/enfield_feed_303
	component_id = "enfield/feed/303"
/obj/item/weapon/gun_component/enfield_furniture_stock
	component_id = "enfield/furniture/stock"
/obj/item/weapon/gun_component/springfield_action
	component_id = "springfield/action"
/obj/item/weapon/gun_component/springfield_barrel_3006
	component_id = "springfield/barrel/3006"
/obj/item/weapon/gun_component/springfield_feed_3006
	component_id = "springfield/feed/3006"
/obj/item/weapon/gun_component/springfield_furniture_stock
	component_id = "springfield/furniture/stock"
/obj/item/weapon/gun_component/lebel_action
	component_id = "lebel/action"
/obj/item/weapon/gun_component/lebel_barrel_8x50
	component_id = "lebel/barrel/8x50"
/obj/item/weapon/gun_component/lebel_feed_8x50
	component_id = "lebel/feed/8x50"
/obj/item/weapon/gun_component/lebel_furniture_stock
	component_id = "lebel/furniture/stock"
/obj/item/weapon/gun_component/berthier_action
	component_id = "berthier/action"
/obj/item/weapon/gun_component/berthier_barrel_8x50
	component_id = "berthier/barrel/8x50"
/obj/item/weapon/gun_component/berthier_feed_8x50_3
	component_id = "berthier/feed/8x50_3"
/obj/item/weapon/gun_component/berthier_feed_8x50_5
	component_id = "berthier/feed/8x50_5"
/obj/item/weapon/gun_component/berthier_furniture_stock
	component_id = "berthier/furniture/stock"
/obj/item/weapon/gun_component/carcano_action
	component_id = "carcano/action"
/obj/item/weapon/gun_component/carcano_barrel_65x52
	component_id = "carcano/barrel/65x52"
/obj/item/weapon/gun_component/carcano_feed_65x52
	component_id = "carcano/feed/65x52"
/obj/item/weapon/gun_component/carcano_furniture_stock
	component_id = "carcano/furniture/stock"
/obj/item/weapon/gun_component/murata_action
	component_id = "murata/action"
/obj/item/weapon/gun_component/murata_barrel_8x53
	component_id = "murata/barrel/8x53"
/obj/item/weapon/gun_component/murata_feed_8x53
	component_id = "murata/feed/8x53"
/obj/item/weapon/gun_component/murata_furniture_stock
	component_id = "murata/furniture/stock"
/obj/item/weapon/gun_component/berdan_action
	component_id = "berdan/action"
/obj/item/weapon/gun_component/berdan_barrel_762x54
	component_id = "berdan/barrel/762x54"
/obj/item/weapon/gun_component/berdan_feed_762x54
	component_id = "berdan/feed/762x54"
/obj/item/weapon/gun_component/berdan_furniture_stock
	component_id = "berdan/furniture/stock"
/obj/item/weapon/gun_component/vg_action
	component_id = "vg/action"
/obj/item/weapon/gun_component/vg_barrel_792x33
	component_id = "vg/barrel/792x33"
/obj/item/weapon/gun_component/vg_feed_792x33
	component_id = "vg/feed/792x33"
/obj/item/weapon/gun_component/vg_furniture_stock
	component_id = "vg/furniture/stock"
/obj/item/weapon/gun_component/m24_action
	component_id = "m24/action"
/obj/item/weapon/gun_component/m24_barrel_762x51
	component_id = "m24/barrel/762x51"
/obj/item/weapon/gun_component/m24_feed_762x51
	component_id = "m24/feed/762x51"
/obj/item/weapon/gun_component/m24_furniture_stock
	component_id = "m24/furniture/stock"
/obj/item/weapon/gun_component/sharps_action
	component_id = "sharps/action"
/obj/item/weapon/gun_component/sharps_barrel_4570
	component_id = "sharps/barrel/4570"
/obj/item/weapon/gun_component/sharps_feed_4570
	component_id = "sharps/feed/4570"
/obj/item/weapon/gun_component/sharps_furniture_stock
	component_id = "sharps/furniture/stock"
/obj/item/weapon/gun_component/rollingblock_action
	component_id = "rollingblock/action"
/obj/item/weapon/gun_component/rollingblock_barrel_4570
	component_id = "rollingblock/barrel/4570"
/obj/item/weapon/gun_component/rollingblock_barrel_43
	component_id = "rollingblock/barrel/43"
/obj/item/weapon/gun_component/rollingblock_feed_4570
	component_id = "rollingblock/feed/4570"
/obj/item/weapon/gun_component/rollingblock_feed_43
	component_id = "rollingblock/feed/43"
/obj/item/weapon/gun_component/rollingblock_furniture_stock
	component_id = "rollingblock/furniture/stock"
/obj/item/weapon/gun_component/martini_action
	component_id = "martini/action"
/obj/item/weapon/gun_component/martini_barrel_577
	component_id = "martini/barrel/577"
/obj/item/weapon/gun_component/martini_feed_577
	component_id = "martini/feed/577"
/obj/item/weapon/gun_component/martini_furniture_stock
	component_id = "martini/furniture/stock"
/obj/item/weapon/gun_component/ptrd_action
	component_id = "ptrd/action"
/obj/item/weapon/gun_component/ptrd_barrel_145
	component_id = "ptrd/barrel/145"
/obj/item/weapon/gun_component/ptrd_feed_145
	component_id = "ptrd/feed/145"
/obj/item/weapon/gun_component/ptrd_furniture_stock
	component_id = "ptrd/furniture/stock"
/obj/item/weapon/gun_component/pzb_action
	component_id = "pzb/action"
/obj/item/weapon/gun_component/pzb_barrel_792x94
	component_id = "pzb/barrel/792x94"
/obj/item/weapon/gun_component/pzb_feed_792x94
	component_id = "pzb/feed/792x94"
/obj/item/weapon/gun_component/pzb_furniture_stock
	component_id = "pzb/furniture/stock"
/obj/item/weapon/gun_component/barrett_action
	component_id = "barrett/action"
/obj/item/weapon/gun_component/barrett_barrel_50cal
	component_id = "barrett/barrel/50cal"
/obj/item/weapon/gun_component/barrett_feed_50cal
	component_id = "barrett/feed/50cal"
/obj/item/weapon/gun_component/barrett_furniture_stock
	component_id = "barrett/furniture/stock"
/obj/item/weapon/gun_component/sks_action
	component_id = "sks/action"
/obj/item/weapon/gun_component/sks_barrel_762x39
	component_id = "sks/barrel/762x39"
/obj/item/weapon/gun_component/sks_feed_762x39
	component_id = "sks/feed/762x39"
/obj/item/weapon/gun_component/sks_feed_762x39_detachable
	component_id = "sks/feed/762x39_detachable"
/obj/item/weapon/gun_component/sks_furniture_stock
	component_id = "sks/furniture/stock"
/obj/item/weapon/gun_component/gewehr43_action
	component_id = "gewehr43/action"
/obj/item/weapon/gun_component/gewehr43_barrel_792x57
	component_id = "gewehr43/barrel/792x57"
/obj/item/weapon/gun_component/gewehr43_feed_792x57
	component_id = "gewehr43/feed/792x57"
/obj/item/weapon/gun_component/gewehr43_feed_792x57_detachable
	component_id = "gewehr43/feed/792x57_detachable"
/obj/item/weapon/gun_component/gewehr43_furniture_stock
	component_id = "gewehr43/furniture/stock"
/obj/item/weapon/gun_component/svt_action
	component_id = "svt/action"
/obj/item/weapon/gun_component/svt_barrel_762x54
	component_id = "svt/barrel/762x54"
/obj/item/weapon/gun_component/svt_feed_762x54
	component_id = "svt/feed/762x54"
/obj/item/weapon/gun_component/svt_furniture_stock
	component_id = "svt/furniture/stock"
/obj/item/weapon/gun_component/garand_action
	component_id = "garand/action"
/obj/item/weapon/gun_component/garand_barrel_3006
	component_id = "garand/barrel/3006"
/obj/item/weapon/gun_component/garand_feed_3006
	component_id = "garand/feed/3006"
/obj/item/weapon/gun_component/garand_furniture_stock
	component_id = "garand/furniture/stock"
/obj/item/weapon/gun_component/m1carbine_action
	component_id = "m1carbine/action"
/obj/item/weapon/gun_component/m1carbine_barrel_762x33
	component_id = "m1carbine/barrel/762x33"
/obj/item/weapon/gun_component/m1carbine_feed_762x33
	component_id = "m1carbine/feed/762x33"
/obj/item/weapon/gun_component/m1carbine_furniture_stock
	component_id = "m1carbine/furniture/stock"
/obj/item/weapon/gun_component/avtomat_action
	component_id = "avtomat/action"
/obj/item/weapon/gun_component/avtomat_barrel_65x50
	component_id = "avtomat/barrel/65x50"
/obj/item/weapon/gun_component/avtomat_feed_65x50
	component_id = "avtomat/feed/65x50"
/obj/item/weapon/gun_component/avtomat_furniture_stock
	component_id = "avtomat/furniture/stock"
/obj/item/weapon/gun_component/vg5_action
	component_id = "vg5/action"
/obj/item/weapon/gun_component/vg5_barrel_792x33
	component_id = "vg5/barrel/792x33"
/obj/item/weapon/gun_component/vg5_feed_792x33
	component_id = "vg5/feed/792x33"
/obj/item/weapon/gun_component/vg5_furniture_stock
	component_id = "vg5/furniture/stock"
/obj/item/weapon/gun_component/ptrs_action
	component_id = "ptrs/action"
/obj/item/weapon/gun_component/ptrs_barrel_145
	component_id = "ptrs/barrel/145"
/obj/item/weapon/gun_component/ptrs_feed_145
	component_id = "ptrs/feed/145"
/obj/item/weapon/gun_component/ptrs_furniture_stock
	component_id = "ptrs/furniture/stock"
/obj/item/weapon/gun_component/svd_action
	component_id = "svd/action"
/obj/item/weapon/gun_component/svd_barrel_762x54
	component_id = "svd/barrel/762x54"
/obj/item/weapon/gun_component/svd_feed_762x54
	component_id = "svd/feed/762x54"
/obj/item/weapon/gun_component/svd_furniture_stock
	component_id = "svd/furniture/stock"
/obj/item/weapon/gun_component/vss_action
	component_id = "vss/action"
/obj/item/weapon/gun_component/vss_barrel_9x39
	component_id = "vss/barrel/9x39"
/obj/item/weapon/gun_component/vss_feed_9x39
	component_id = "vss/feed/9x39"
/obj/item/weapon/gun_component/vss_furniture_stock
	component_id = "vss/furniture/stock"
/obj/item/weapon/gun_component/m82_action
	component_id = "m82/action"
/obj/item/weapon/gun_component/m82_barrel_50cal
	component_id = "m82/barrel/50cal"
/obj/item/weapon/gun_component/m82_feed_50cal
	component_id = "m82/feed/50cal"
/obj/item/weapon/gun_component/m82_furniture_stock
	component_id = "m82/furniture/stock"
/obj/item/weapon/gun_component/bamr_action
	component_id = "bamr/action"
/obj/item/weapon/gun_component/bamr_barrel_15115
	component_id = "bamr/barrel/15115"
/obj/item/weapon/gun_component/bamr_feed_15115
	component_id = "bamr/feed/15115"
/obj/item/weapon/gun_component/bamr_furniture_stock
	component_id = "bamr/furniture/stock"
/obj/item/weapon/gun_component/lever_action
	component_id = "lever/action"
/obj/item/weapon/gun_component/lever_barrel_44
	component_id = "lever/barrel/44"
/obj/item/weapon/gun_component/lever_barrel_357
	component_id = "lever/barrel/357"
/obj/item/weapon/gun_component/lever_barrel_4570
	component_id = "lever/barrel/4570"
/obj/item/weapon/gun_component/lever_feed_44
	component_id = "lever/feed/44"
/obj/item/weapon/gun_component/lever_feed_357
	component_id = "lever/feed/357"
/obj/item/weapon/gun_component/lever_feed_4570
	component_id = "lever/feed/4570"
/obj/item/weapon/gun_component/lever_furniture_stock
	component_id = "lever/furniture/stock"
/obj/item/weapon/gun_component/nambu_action
	component_id = "nambu/action"
/obj/item/weapon/gun_component/nambu_barrel_8mm
	component_id = "nambu/barrel/8mm"
/obj/item/weapon/gun_component/nambu_feed_8mm
	component_id = "nambu/feed/8mm"
/obj/item/weapon/gun_component/nambu_furniture_grip
	component_id = "nambu/furniture/grip"
/obj/item/weapon/gun_component/bergmann_action
	component_id = "bergmann/action"
/obj/item/weapon/gun_component/bergmann_barrel_8mm
	component_id = "bergmann/barrel/8mm"
/obj/item/weapon/gun_component/bergmann_feed_8mm
	component_id = "bergmann/feed/8mm"
/obj/item/weapon/gun_component/bergmann_furniture_grip
	component_id = "bergmann/furniture/grip"
/obj/item/weapon/gun_component/luger_action
	component_id = "luger/action"
/obj/item/weapon/gun_component/luger_barrel_9x19
	component_id = "luger/barrel/9x19"
/obj/item/weapon/gun_component/luger_feed_9x19
	component_id = "luger/feed/9x19"
/obj/item/weapon/gun_component/luger_furniture_grip
	component_id = "luger/furniture/grip"
/obj/item/weapon/gun_component/walther_action
	component_id = "walther/action"
/obj/item/weapon/gun_component/walther_barrel_9x19
	component_id = "walther/barrel/9x19"
/obj/item/weapon/gun_component/walther_feed_9x19
	component_id = "walther/feed/9x19"
/obj/item/weapon/gun_component/walther_furniture_grip
	component_id = "walther/furniture/grip"
/obj/item/weapon/gun_component/browninghp_action
	component_id = "browninghp/action"
/obj/item/weapon/gun_component/browninghp_barrel_9x19
	component_id = "browninghp/barrel/9x19"
/obj/item/weapon/gun_component/browninghp_feed_9x19
	component_id = "browninghp/feed/9x19"
/obj/item/weapon/gun_component/browninghp_furniture_grip
	component_id = "browninghp/furniture/grip"
/obj/item/weapon/gun_component/c96_action
	component_id = "c96/action"
/obj/item/weapon/gun_component/c96_barrel_762x25
	component_id = "c96/barrel/762x25"
/obj/item/weapon/gun_component/c96_feed_762x25
	component_id = "c96/feed/762x25"
/obj/item/weapon/gun_component/c96_furniture_grip
	component_id = "c96/furniture/grip"
/obj/item/weapon/gun_component/borchardt_action
	component_id = "borchardt/action"
/obj/item/weapon/gun_component/borchardt_barrel_765x25
	component_id = "borchardt/barrel/765x25"
/obj/item/weapon/gun_component/borchardt_feed_765x25
	component_id = "borchardt/feed/765x25"
/obj/item/weapon/gun_component/borchardt_furniture_grip
	component_id = "borchardt/furniture/grip"
/obj/item/weapon/gun_component/colthammerless_action
	component_id = "colthammerless/action"
/obj/item/weapon/gun_component/colthammerless_barrel_32acp
	component_id = "colthammerless/barrel/32acp"
/obj/item/weapon/gun_component/colthammerless_barrel_380acp
	component_id = "colthammerless/barrel/380acp"
/obj/item/weapon/gun_component/colthammerless_feed_32acp
	component_id = "colthammerless/feed/32acp"
/obj/item/weapon/gun_component/colthammerless_feed_380acp
	component_id = "colthammerless/feed/380acp"
/obj/item/weapon/gun_component/colthammerless_furniture_grip
	component_id = "colthammerless/furniture/grip"
/obj/item/weapon/gun_component/m1911_action
	component_id = "m1911/action"
/obj/item/weapon/gun_component/m1911_barrel_45acp
	component_id = "m1911/barrel/45acp"
/obj/item/weapon/gun_component/m1911_feed_45acp
	component_id = "m1911/feed/45acp"
/obj/item/weapon/gun_component/m1911_feed_45acp_2011
	component_id = "m1911/feed/45acp_2011"
/obj/item/weapon/gun_component/m1911_furniture_grip
	component_id = "m1911/furniture/grip"
/obj/item/weapon/gun_component/tt_action
	component_id = "tt/action"
/obj/item/weapon/gun_component/tt_barrel_762x25
	component_id = "tt/barrel/762x25"
/obj/item/weapon/gun_component/tt_feed_762x25
	component_id = "tt/feed/762x25"
/obj/item/weapon/gun_component/tt_furniture_grip
	component_id = "tt/furniture/grip"
/obj/item/weapon/gun_component/makarov_action
	component_id = "makarov/action"
/obj/item/weapon/gun_component/makarov_barrel_9x18
	component_id = "makarov/barrel/9x18"
/obj/item/weapon/gun_component/makarov_feed_9x18
	component_id = "makarov/feed/9x18"
/obj/item/weapon/gun_component/makarov_furniture_grip
	component_id = "makarov/furniture/grip"
/obj/item/weapon/gun_component/aps_action
	component_id = "aps/action"
/obj/item/weapon/gun_component/aps_barrel_9x18
	component_id = "aps/barrel/9x18"
/obj/item/weapon/gun_component/aps_feed_9x18
	component_id = "aps/feed/9x18"
/obj/item/weapon/gun_component/aps_furniture_grip
	component_id = "aps/furniture/grip"
/obj/item/weapon/gun_component/glock_action
	component_id = "glock/action"
/obj/item/weapon/gun_component/glock_barrel_9x19
	component_id = "glock/barrel/9x19"
/obj/item/weapon/gun_component/glock_feed_9x19
	component_id = "glock/feed/9x19"
/obj/item/weapon/gun_component/glock_furniture_grip
	component_id = "glock/furniture/grip"
/obj/item/weapon/gun_component/beretta_action
	component_id = "beretta/action"
/obj/item/weapon/gun_component/beretta_barrel_9x19
	component_id = "beretta/barrel/9x19"
/obj/item/weapon/gun_component/beretta_feed_9x19
	component_id = "beretta/feed/9x19"
/obj/item/weapon/gun_component/beretta_furniture_grip
	component_id = "beretta/furniture/grip"
/obj/item/weapon/gun_component/jericho_action
	component_id = "jericho/action"
/obj/item/weapon/gun_component/jericho_barrel_9x19
	component_id = "jericho/barrel/9x19"
/obj/item/weapon/gun_component/jericho_feed_9x19
	component_id = "jericho/feed/9x19"
/obj/item/weapon/gun_component/jericho_furniture_grip
	component_id = "jericho/furniture/grip"
/obj/item/weapon/gun_component/sig250_action
	component_id = "sig250/action"
/obj/item/weapon/gun_component/sig250_barrel_9x19
	component_id = "sig250/barrel/9x19"
/obj/item/weapon/gun_component/sig250_feed_9x19
	component_id = "sig250/feed/9x19"
/obj/item/weapon/gun_component/sig250_furniture_grip
	component_id = "sig250/furniture/grip"
/obj/item/weapon/gun_component/p220_action
	component_id = "p220/action"
/obj/item/weapon/gun_component/p220_barrel_45
	component_id = "p220/barrel/45"
/obj/item/weapon/gun_component/p220_feed_45
	component_id = "p220/feed/45"
/obj/item/weapon/gun_component/p220_furniture_grip
	component_id = "p220/furniture/grip"
/obj/item/weapon/gun_component/pl14_action
	component_id = "pl14/action"
/obj/item/weapon/gun_component/pl14_barrel_9x19
	component_id = "pl14/barrel/9x19"
/obj/item/weapon/gun_component/pl14_feed_9x19
	component_id = "pl14/feed/9x19"
/obj/item/weapon/gun_component/pl14_furniture_grip
	component_id = "pl14/furniture/grip"
/obj/item/weapon/gun_component/mp443_action
	component_id = "mp443/action"
/obj/item/weapon/gun_component/mp443_barrel_9x19
	component_id = "mp443/barrel/9x19"
/obj/item/weapon/gun_component/mp443_feed_9x19
	component_id = "mp443/feed/9x19"
/obj/item/weapon/gun_component/mp443_furniture_grip
	component_id = "mp443/furniture/grip"
/obj/item/weapon/gun_component/deagle_action
	component_id = "deagle/action"
/obj/item/weapon/gun_component/deagle_barrel_50ae
	component_id = "deagle/barrel/50ae"
/obj/item/weapon/gun_component/deagle_barrel_44magnum
	component_id = "deagle/barrel/44magnum"
/obj/item/weapon/gun_component/deagle_feed_50ae
	component_id = "deagle/feed/50ae"
/obj/item/weapon/gun_component/deagle_feed_44magnum
	component_id = "deagle/feed/44magnum"
/obj/item/weapon/gun_component/deagle_furniture_grip
	component_id = "deagle/furniture/grip"
/obj/item/weapon/gun_component/nagant_action
	component_id = "nagant/action"
/obj/item/weapon/gun_component/nagant_barrel_762x38
	component_id = "nagant/barrel/762x38"
/obj/item/weapon/gun_component/nagant_feed_762x38
	component_id = "nagant/feed/762x38"
/obj/item/weapon/gun_component/nagant_furniture_grip
	component_id = "nagant/furniture/grip"
/obj/item/weapon/gun_component/m1892_action
	component_id = "m1892/action"
/obj/item/weapon/gun_component/m1892_barrel_8x27
	component_id = "m1892/barrel/8x27"
/obj/item/weapon/gun_component/m1892_feed_8x27
	component_id = "m1892/feed/8x27"
/obj/item/weapon/gun_component/m1892_furniture_grip
	component_id = "m1892/furniture/grip"
/obj/item/weapon/gun_component/colt_saa_action
	component_id = "colt_saa/action"
/obj/item/weapon/gun_component/colt_saa_barrel_45
	component_id = "colt_saa/barrel/45"
/obj/item/weapon/gun_component/colt_saa_barrel_44
	component_id = "colt_saa/barrel/44"
/obj/item/weapon/gun_component/colt_saa_feed_45
	component_id = "colt_saa/feed/45"
/obj/item/weapon/gun_component/colt_saa_feed_44
	component_id = "colt_saa/feed/44"
/obj/item/weapon/gun_component/colt_saa_furniture_grip
	component_id = "colt_saa/furniture/grip"
/obj/item/weapon/gun_component/colt1892_action
	component_id = "colt1892/action"
/obj/item/weapon/gun_component/colt1892_barrel_38
	component_id = "colt1892/barrel/38"
/obj/item/weapon/gun_component/colt1892_feed_38
	component_id = "colt1892/feed/38"
/obj/item/weapon/gun_component/colt1892_furniture_grip
	component_id = "colt1892/furniture/grip"
/obj/item/weapon/gun_component/policepositive_action
	component_id = "policepositive/action"
/obj/item/weapon/gun_component/policepositive_barrel_32
	component_id = "policepositive/barrel/32"
/obj/item/weapon/gun_component/policepositive_feed_32
	component_id = "policepositive/feed/32"
/obj/item/weapon/gun_component/policepositive_furniture_grip
	component_id = "policepositive/furniture/grip"
/obj/item/weapon/gun_component/smithwesson_action
	component_id = "smithwesson/action"
/obj/item/weapon/gun_component/smithwesson_barrel_32
	component_id = "smithwesson/barrel/32"
/obj/item/weapon/gun_component/smithwesson_barrel_38
	component_id = "smithwesson/barrel/38"
/obj/item/weapon/gun_component/smithwesson_feed_32
	component_id = "smithwesson/feed/32"
/obj/item/weapon/gun_component/smithwesson_feed_38
	component_id = "smithwesson/feed/38"
/obj/item/weapon/gun_component/smithwesson_furniture_grip
	component_id = "smithwesson/furniture/grip"
/obj/item/weapon/gun_component/enfieldno2_action
	component_id = "enfieldno2/action"
/obj/item/weapon/gun_component/enfieldno2_barrel_41
	component_id = "enfieldno2/barrel/41"
/obj/item/weapon/gun_component/enfieldno2_feed_41
	component_id = "enfieldno2/feed/41"
/obj/item/weapon/gun_component/enfieldno2_furniture_grip
	component_id = "enfieldno2/furniture/grip"
/obj/item/weapon/gun_component/webley_action
	component_id = "webley/action"
/obj/item/weapon/gun_component/webley_barrel_455
	component_id = "webley/barrel/455"
/obj/item/weapon/gun_component/webley_feed_455
	component_id = "webley/feed/455"
/obj/item/weapon/gun_component/webley_furniture_grip
	component_id = "webley/furniture/grip"
/obj/item/weapon/gun_component/type26_action
	component_id = "type26/action"
/obj/item/weapon/gun_component/type26_barrel_9mm
	component_id = "type26/barrel/9mm"
/obj/item/weapon/gun_component/type26_feed_9mm
	component_id = "type26/feed/9mm"
/obj/item/weapon/gun_component/type26_furniture_grip
	component_id = "type26/furniture/grip"
/obj/item/weapon/gun_component/derringer_action
	component_id = "derringer/action"
/obj/item/weapon/gun_component/derringer_barrel_41
	component_id = "derringer/barrel/41"
/obj/item/weapon/gun_component/derringer_feed_41
	component_id = "derringer/feed/41"
/obj/item/weapon/gun_component/derringer_furniture_grip
	component_id = "derringer/furniture/grip"
/obj/item/weapon/gun_component/magnum44_action
	component_id = "magnum44/action"
/obj/item/weapon/gun_component/magnum44_barrel_44magnum
	component_id = "magnum44/barrel/44magnum"
/obj/item/weapon/gun_component/magnum44_feed_44magnum
	component_id = "magnum44/feed/44magnum"
/obj/item/weapon/gun_component/magnum44_furniture_grip
	component_id = "magnum44/furniture/grip"
/obj/item/weapon/gun_component/mckellen_action
	component_id = "mckellen/action"
/obj/item/weapon/gun_component/mckellen_barrel_44magnum
	component_id = "mckellen/barrel/44magnum"
/obj/item/weapon/gun_component/mckellen_feed_44magnum
	component_id = "mckellen/feed/44magnum"
/obj/item/weapon/gun_component/mckellen_furniture_grip
	component_id = "mckellen/furniture/grip"
/obj/item/weapon/gun_component/judge_action
	component_id = "judge/action"
/obj/item/weapon/gun_component/judge_barrel_45
	component_id = "judge/barrel/45"
/obj/item/weapon/gun_component/judge_feed_45
	component_id = "judge/feed/45"
/obj/item/weapon/gun_component/judge_furniture_grip
	component_id = "judge/furniture/grip"
/obj/item/weapon/gun_component/revolving_action
	component_id = "revolving/action"
/obj/item/weapon/gun_component/revolving_barrel_44
	component_id = "revolving/barrel/44"
/obj/item/weapon/gun_component/revolving_feed_44
	component_id = "revolving/feed/44"
/obj/item/weapon/gun_component/revolving_furniture_stock
	component_id = "revolving/furniture/stock"
/obj/item/weapon/gun_component/pump_action
	component_id = "pump/action"
/obj/item/weapon/gun_component/pump_barrel_12g
	component_id = "pump/barrel/12g"
/obj/item/weapon/gun_component/pump_feed_12g
	component_id = "pump/feed/12g"
/obj/item/weapon/gun_component/pump_furniture_stock
	component_id = "pump/furniture/stock"
/obj/item/weapon/gun_component/ks23_action
	component_id = "ks23/action"
/obj/item/weapon/gun_component/ks23_barrel_12g
	component_id = "ks23/barrel/12g"
/obj/item/weapon/gun_component/ks23_feed_12g
	component_id = "ks23/feed/12g"
/obj/item/weapon/gun_component/ks23_furniture_stock
	component_id = "ks23/furniture/stock"
/obj/item/weapon/gun_component/coachgun_action
	component_id = "coachgun/action"
/obj/item/weapon/gun_component/coachgun_barrel_12g
	component_id = "coachgun/barrel/12g"
/obj/item/weapon/gun_component/coachgun_feed_12g
	component_id = "coachgun/feed/12g"
/obj/item/weapon/gun_component/coachgun_furniture_stock
	component_id = "coachgun/furniture/stock"
/obj/item/weapon/gun_component/mts225_action
	component_id = "mts225/action"
/obj/item/weapon/gun_component/mts225_barrel_12g
	component_id = "mts225/barrel/12g"
/obj/item/weapon/gun_component/mts225_feed_12g
	component_id = "mts225/feed/12g"
/obj/item/weapon/gun_component/mts225_furniture_stock
	component_id = "mts225/furniture/stock"
/obj/item/weapon/gun_component/remington11_action
	component_id = "remington11/action"
/obj/item/weapon/gun_component/remington11_barrel_12g
	component_id = "remington11/barrel/12g"
/obj/item/weapon/gun_component/remington11_feed_12g
	component_id = "remington11/feed/12g"
/obj/item/weapon/gun_component/remington11_furniture_stock
	component_id = "remington11/furniture/stock"
/obj/item/weapon/gun_component/spas_action
	component_id = "spas/action"
/obj/item/weapon/gun_component/spas_barrel_12g
	component_id = "spas/barrel/12g"
/obj/item/weapon/gun_component/spas_feed_12g
	component_id = "spas/feed/12g"
/obj/item/weapon/gun_component/spas_furniture_stock
	component_id = "spas/furniture/stock"
/obj/item/weapon/gun_component/saiga_action
	component_id = "saiga/action"
/obj/item/weapon/gun_component/saiga_barrel_12g
	component_id = "saiga/barrel/12g"
/obj/item/weapon/gun_component/saiga_feed_12g
	component_id = "saiga/feed/12g"
/obj/item/weapon/gun_component/saiga_furniture_stock
	component_id = "saiga/furniture/stock"
/obj/item/weapon/gun_component/usas12_action
	component_id = "usas12/action"
/obj/item/weapon/gun_component/usas12_barrel_12g
	component_id = "usas12/barrel/12g"
/obj/item/weapon/gun_component/usas12_feed_12g
	component_id = "usas12/feed/12g"
/obj/item/weapon/gun_component/usas12_furniture_stock
	component_id = "usas12/furniture/stock"
/obj/item/weapon/gun_component/ar12_action
	component_id = "ar12/action"
/obj/item/weapon/gun_component/ar12_barrel_12g
	component_id = "ar12/barrel/12g"
/obj/item/weapon/gun_component/ar12_feed_12g
	component_id = "ar12/feed/12g"
/obj/item/weapon/gun_component/ar12_furniture_stock
	component_id = "ar12/furniture/stock"
/obj/item/weapon/gun_component/mp40_action
	component_id = "mp40/action"
/obj/item/weapon/gun_component/mp40_barrel_9x19
	component_id = "mp40/barrel/9x19"
/obj/item/weapon/gun_component/mp40_feed_9x19
	component_id = "mp40/feed/9x19"
/obj/item/weapon/gun_component/mp40_furniture_stock
	component_id = "mp40/furniture/stock"
/obj/item/weapon/gun_component/erma_action
	component_id = "erma/action"
/obj/item/weapon/gun_component/erma_barrel_9x19
	component_id = "erma/barrel/9x19"
/obj/item/weapon/gun_component/erma_feed_9x19
	component_id = "erma/feed/9x19"
/obj/item/weapon/gun_component/erma_furniture_stock
	component_id = "erma/furniture/stock"
/obj/item/weapon/gun_component/mab38_action
	component_id = "mab38/action"
/obj/item/weapon/gun_component/mab38_barrel_9x19
	component_id = "mab38/barrel/9x19"
/obj/item/weapon/gun_component/mab38_feed_9x19
	component_id = "mab38/feed/9x19"
/obj/item/weapon/gun_component/mab38_furniture_stock
	component_id = "mab38/furniture/stock"
/obj/item/weapon/gun_component/sten_action
	component_id = "sten/action"
/obj/item/weapon/gun_component/sten_barrel_9x19
	component_id = "sten/barrel/9x19"
/obj/item/weapon/gun_component/sten_feed_9x19
	component_id = "sten/feed/9x19"
/obj/item/weapon/gun_component/sten_furniture_stock
	component_id = "sten/furniture/stock"
/obj/item/weapon/gun_component/thompson_action
	component_id = "thompson/action"
/obj/item/weapon/gun_component/thompson_barrel_45acp
	component_id = "thompson/barrel/45acp"
/obj/item/weapon/gun_component/thompson_feed_45acp
	component_id = "thompson/feed/45acp"
/obj/item/weapon/gun_component/thompson_furniture_stock
	component_id = "thompson/furniture/stock"
/obj/item/weapon/gun_component/greasegun_action
	component_id = "greasegun/action"
/obj/item/weapon/gun_component/greasegun_barrel_45acp
	component_id = "greasegun/barrel/45acp"
/obj/item/weapon/gun_component/greasegun_feed_45acp
	component_id = "greasegun/feed/45acp"
/obj/item/weapon/gun_component/greasegun_furniture_stock
	component_id = "greasegun/furniture/stock"
/obj/item/weapon/gun_component/ppsh_action
	component_id = "ppsh/action"
/obj/item/weapon/gun_component/ppsh_barrel_762x25
	component_id = "ppsh/barrel/762x25"
/obj/item/weapon/gun_component/ppsh_feed_762x25
	component_id = "ppsh/feed/762x25"
/obj/item/weapon/gun_component/ppsh_furniture_stock
	component_id = "ppsh/furniture/stock"
/obj/item/weapon/gun_component/ppd_action
	component_id = "ppd/action"
/obj/item/weapon/gun_component/ppd_barrel_762x25
	component_id = "ppd/barrel/762x25"
/obj/item/weapon/gun_component/ppd_feed_762x25
	component_id = "ppd/feed/762x25"
/obj/item/weapon/gun_component/ppd_furniture_stock
	component_id = "ppd/furniture/stock"
/obj/item/weapon/gun_component/pps_action
	component_id = "pps/action"
/obj/item/weapon/gun_component/pps_barrel_762x25
	component_id = "pps/barrel/762x25"
/obj/item/weapon/gun_component/pps_feed_762x25
	component_id = "pps/feed/762x25"
/obj/item/weapon/gun_component/pps_furniture_stock
	component_id = "pps/furniture/stock"
/obj/item/weapon/gun_component/type100_action
	component_id = "type100/action"
/obj/item/weapon/gun_component/type100_barrel_8mm
	component_id = "type100/barrel/8mm"
/obj/item/weapon/gun_component/type100_feed_8mm
	component_id = "type100/feed/8mm"
/obj/item/weapon/gun_component/type100_furniture_stock
	component_id = "type100/furniture/stock"
/obj/item/weapon/gun_component/mp5_action
	component_id = "mp5/action"
/obj/item/weapon/gun_component/mp5_barrel_9x19
	component_id = "mp5/barrel/9x19"
/obj/item/weapon/gun_component/mp5_feed_9x19
	component_id = "mp5/feed/9x19"
/obj/item/weapon/gun_component/mp5_furniture_stock
	component_id = "mp5/furniture/stock"
/obj/item/weapon/gun_component/uzi_action
	component_id = "uzi/action"
/obj/item/weapon/gun_component/uzi_barrel_9x19
	component_id = "uzi/barrel/9x19"
/obj/item/weapon/gun_component/uzi_feed_9x19
	component_id = "uzi/feed/9x19"
/obj/item/weapon/gun_component/uzi_furniture_stock
	component_id = "uzi/furniture/stock"
/obj/item/weapon/gun_component/skorpion_action
	component_id = "skorpion/action"
/obj/item/weapon/gun_component/skorpion_barrel_9x19
	component_id = "skorpion/barrel/9x19"
/obj/item/weapon/gun_component/skorpion_feed_9x19
	component_id = "skorpion/feed/9x19"
/obj/item/weapon/gun_component/skorpion_furniture_stock
	component_id = "skorpion/furniture/stock"
/obj/item/weapon/gun_component/tec9_action
	component_id = "tec9/action"
/obj/item/weapon/gun_component/tec9_barrel_9x19
	component_id = "tec9/barrel/9x19"
/obj/item/weapon/gun_component/tec9_feed_9x19
	component_id = "tec9/feed/9x19"
/obj/item/weapon/gun_component/tec9_furniture_grip
	component_id = "tec9/furniture/grip"
/obj/item/weapon/gun_component/vector_action
	component_id = "vector/action"
/obj/item/weapon/gun_component/vector_barrel_9x19
	component_id = "vector/barrel/9x19"
/obj/item/weapon/gun_component/vector_feed_9x19
	component_id = "vector/feed/9x19"
/obj/item/weapon/gun_component/vector_furniture_stock
	component_id = "vector/furniture/stock"
/obj/item/weapon/gun_component/mac10_action
	component_id = "mac10/action"
/obj/item/weapon/gun_component/mac10_barrel_45acp
	component_id = "mac10/barrel/45acp"
/obj/item/weapon/gun_component/mac10_feed_45acp
	component_id = "mac10/feed/45acp"
/obj/item/weapon/gun_component/mac10_furniture_stock
	component_id = "mac10/furniture/stock"
/obj/item/weapon/gun_component/p90_action
	component_id = "p90/action"
/obj/item/weapon/gun_component/p90_barrel_57x28
	component_id = "p90/barrel/57x28"
/obj/item/weapon/gun_component/p90_feed_57x28
	component_id = "p90/feed/57x28"
/obj/item/weapon/gun_component/p90_furniture_stock
	component_id = "p90/furniture/stock"
/obj/item/weapon/gun_component/sr3_action
	component_id = "sr3/action"
/obj/item/weapon/gun_component/sr3_barrel_9x39
	component_id = "sr3/barrel/9x39"
/obj/item/weapon/gun_component/sr3_feed_9x39
	component_id = "sr3/feed/9x39"
/obj/item/weapon/gun_component/sr3_furniture_stock
	component_id = "sr3/furniture/stock"
/obj/item/weapon/gun_component/stg_action
	component_id = "stg/action"
/obj/item/weapon/gun_component/stg_barrel_792x33
	component_id = "stg/barrel/792x33"
/obj/item/weapon/gun_component/stg_feed_792x33
	component_id = "stg/feed/792x33"
/obj/item/weapon/gun_component/stg_furniture_stock
	component_id = "stg/furniture/stock"
/obj/item/weapon/gun_component/fg42_action
	component_id = "fg42/action"
/obj/item/weapon/gun_component/fg42_barrel_792x57
	component_id = "fg42/barrel/792x57"
/obj/item/weapon/gun_component/fg42_feed_792x57
	component_id = "fg42/feed/792x57"
/obj/item/weapon/gun_component/fg42_furniture_stock
	component_id = "fg42/furniture/stock"
/obj/item/weapon/gun_component/m14_action
	component_id = "m14/action"
/obj/item/weapon/gun_component/m14_barrel_762x51
	component_id = "m14/barrel/762x51"
/obj/item/weapon/gun_component/m14_feed_762x51
	component_id = "m14/feed/762x51"
/obj/item/weapon/gun_component/m14_furniture_stock
	component_id = "m14/furniture/stock"
/obj/item/weapon/gun_component/fal_action
	component_id = "fal/action"
/obj/item/weapon/gun_component/fal_barrel_762x51
	component_id = "fal/barrel/762x51"
/obj/item/weapon/gun_component/fal_feed_762x51
	component_id = "fal/feed/762x51"
/obj/item/weapon/gun_component/fal_furniture_stock
	component_id = "fal/furniture/stock"
/obj/item/weapon/gun_component/g3_action
	component_id = "g3/action"
/obj/item/weapon/gun_component/g3_barrel_762x51
	component_id = "g3/barrel/762x51"
/obj/item/weapon/gun_component/g3_feed_762x51
	component_id = "g3/feed/762x51"
/obj/item/weapon/gun_component/g3_furniture_stock
	component_id = "g3/furniture/stock"
/obj/item/weapon/gun_component/ar10_action
	component_id = "ar10/action"
/obj/item/weapon/gun_component/ar10_barrel_762x51
	component_id = "ar10/barrel/762x51"
/obj/item/weapon/gun_component/ar10_feed_762x51
	component_id = "ar10/feed/762x51"
/obj/item/weapon/gun_component/ar10_furniture_stock
	component_id = "ar10/furniture/stock"
/obj/item/weapon/gun_component/hk417_action
	component_id = "hk417/action"
/obj/item/weapon/gun_component/hk417_barrel_762x51
	component_id = "hk417/barrel/762x51"
/obj/item/weapon/gun_component/hk417_feed_762x51
	component_id = "hk417/feed/762x51"
/obj/item/weapon/gun_component/hk417_furniture_stock
	component_id = "hk417/furniture/stock"
/obj/item/weapon/gun_component/scar_action
	component_id = "scar/action"
/obj/item/weapon/gun_component/scar_barrel_556x45
	component_id = "scar/barrel/556x45"
/obj/item/weapon/gun_component/scar_barrel_762x51
	component_id = "scar/barrel/762x51"
/obj/item/weapon/gun_component/scar_feed_556x45
	component_id = "scar/feed/556x45"
/obj/item/weapon/gun_component/scar_feed_762x51
	component_id = "scar/feed/762x51"
/obj/item/weapon/gun_component/scar_furniture_stock
	component_id = "scar/furniture/stock"
/obj/item/weapon/gun_component/aug_action
	component_id = "aug/action"
/obj/item/weapon/gun_component/aug_barrel_556x45
	component_id = "aug/barrel/556x45"
/obj/item/weapon/gun_component/aug_feed_556x45
	component_id = "aug/feed/556x45"
/obj/item/weapon/gun_component/aug_furniture_stock
	component_id = "aug/furniture/stock"
/obj/item/weapon/gun_component/l85_action
	component_id = "l85/action"
/obj/item/weapon/gun_component/l85_barrel_556x45
	component_id = "l85/barrel/556x45"
/obj/item/weapon/gun_component/l85_feed_556x45
	component_id = "l85/feed/556x45"
/obj/item/weapon/gun_component/l85_furniture_stock
	component_id = "l85/furniture/stock"
/obj/item/weapon/gun_component/qbz95_action
	component_id = "qbz95/action"
/obj/item/weapon/gun_component/qbz95_barrel_58x42
	component_id = "qbz95/barrel/58x42"
/obj/item/weapon/gun_component/qbz95_feed_58x42
	component_id = "qbz95/feed/58x42"
/obj/item/weapon/gun_component/qbz95_furniture_stock
	component_id = "qbz95/furniture/stock"
/obj/item/weapon/gun_component/vz58_action
	component_id = "vz58/action"
/obj/item/weapon/gun_component/vz58_barrel_762x39
	component_id = "vz58/barrel/762x39"
/obj/item/weapon/gun_component/vz58_feed_762x39
	component_id = "vz58/feed/762x39"
/obj/item/weapon/gun_component/vz58_furniture_stock
	component_id = "vz58/furniture/stock"
#undef FIREARM_BARREL_LIFE
