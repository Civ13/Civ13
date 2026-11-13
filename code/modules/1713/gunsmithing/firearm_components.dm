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
	var/capacity = null       // feed parts: rounds held, when it differs between feeds of one family
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
	)

var/global/list/firearm_family_labels = list("ak" = "AK", "ar" = "AR", "mauser" = "Mauser", "mosin" = "Mosin", "arisaka" = "Arisaka",
	"enfield" = "Lee-Enfield", "springfield" = "Springfield", "lebel" = "Lebel", "berthier" = "Berthier", "carcano" = "Carcano",
	"murata" = "Murata", "berdan" = "Berdan", "vg" = "Volkssturmgewehr", "m24" = "M24", "sharps" = "Sharps", "rollingblock" = "Rolling-block",
	"martini" = "Martini-Henry", "ptrd" = "PTRD", "pzb" = "PzB", "barrett" = "Barrett")
var/global/list/firearm_caliber_labels = list("a762x39" = "7.62x39mm", "a545x39" = "5.45x39mm", "a556x45" = "5.56x45mm",
	"a792x57" = "7.92x57mm", "a765x53" = "7.65x53mm", "a7x57" = "7x57mm", "a762x54" = "7.62x54mmR",
	"a65x50" = "6.5x50mm", "a77x58" = "7.7x58mm", "a303" = ".303 British", "a3006" = ".30-06", "a8x50" = "8x50mmR",
	"a65x52" = "6.5x52mm", "a8x53" = "8x53mm", "a792x33" = "7.92x33mm Kurz", "a762x51" = "7.62x51mm", "a4570" = ".45-70",
	"a43" = ".43 Spanish", "a577" = ".577/450", "a145" = "14.5x114mm", "a792x94" = "7.92x94mm", "a50cal" = ".50 BMG")

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

/obj/item/weapon/gun
	var/firearm_family = null
	var/firearm_preset = null
	// Why a modern gun deliberately has no modular parts (coverage manifest).
	var/firearm_fixed_reason = null
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
		if (islist(feed.ammo_type))
			var/list/rounds = feed.ammo_type
			G.ammo_type = rounds.Copy()
		else if (feed.ammo_type)
			G.ammo_type = feed.ammo_type
		G.max_shells = feed.capacity ? feed.capacity : initial(G.max_shells)
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
#undef FIREARM_BARREL_LIFE
