// ============================================================
// A land across the sea: its template's ore, rare find and game
// ------------------------------------------------------------
// Each land on the world chart has a template (docs/world-chart.md#templates)
// with resources: an ore richness, two or three ore kinds, maybe a rare find
// and the game animals it is known for. The host writes them to the slot's
// config/expedition_land.json (slot_world, expedition_land.dm). Here the land
// world applies them:
// - Ore: every mined wall rolls once more for a lode of one of the land's ore
//   kinds, more often on a richer land. Era rules for each ore still apply.
// - Rare find: gem pockets, rich gold or silver veins, or diamonds.
// - Game: the land's animals are plentiful (ecology spawning, ecology_spawning.dm).
// Names match tools/transfer_storage/world_chart.py (ORES, RARE_FINDS, GAME).
// ============================================================

#define LAND_GAME_DENSITY 3 // the land's own game: times its usual density
#define LAND_GAME_TARGET 2 // and times its usual cap

// The land's slot_world entry (ores, rare, game), or null off a land.
/proc/expedition_land_resources()
	var/list/info = expedition_land()
	if (!islist(info) || !islist(info["slot_world"]))
		return null
	return info["slot_world"]

// Percent per mined wall of a lode, by the land's ore richness.
/proc/expedition_lode_chance()
	var/list/res = expedition_land_resources()
	if (!res)
		return 0
	switch (res["ore"])
		if ("rich") return 12
		if ("good") return 9
		if ("fair") return 6
		if ("thin") return 4
		if ("poor") return 2
	return 0

// The land's ore kinds a miner in this era can find.
/proc/expedition_lode_kinds()
	var/list/res = expedition_land_resources()
	var/list/kinds = list()
	if (!res || !islist(res["ores"]))
		return kinds
	var/age = map ? map.ordinal_age : 0
	for (var/kind in res["ores"])
		switch (kind)
			if ("copper", "tin", "gold", "silver", "flint", "obsidian")
				kinds += kind
			if ("iron", "zinc")
				if (age >= 1)
					kinds += kind
			if ("coal", "lead", "saltpeter", "sulphur")
				if (age >= 2)
					kinds += kind
	return kinds

// Ore kind -> list(stack type, least, most). Flint is loose nodules instead.
var/global/list/expedition_lode_types = expedition_lode_types_table()
/proc/expedition_lode_types_table()
	return list(
	"iron" = list(/obj/item/stack/ore/iron, 12, 24),
	"copper" = list(/obj/item/stack/ore/copper, 12, 24),
	"tin" = list(/obj/item/stack/ore/tin, 12, 24),
	"zinc" = list(/obj/item/stack/ore/zinc, 12, 24),
	"coal" = list(/obj/item/stack/ore/coal, 24, 32),
	"lead" = list(/obj/item/stack/ore/lead, 8, 8),
	"saltpeter" = list(/obj/item/stack/ore/saltpeter, 8, 8),
	"sulphur" = list(/obj/item/stack/ore/sulphur, 8, 8),
	"gold" = list(/obj/item/stack/ore/gold, 4, 4),
	"silver" = list(/obj/item/stack/ore/silver, 4, 4),
	"obsidian" = list(/obj/item/stack/ore/obsidian, 4, 8),
)

// Leaves a lode of kind on src. Returns the item, or null for an unknown kind.
/turf/proc/expedition_lode(kind, list/rubble = null)
	if (kind == "flint")
		var/obj/item/weapon/flint/F = null
		var/count = rand(2, 4)
		for (var/i = 1, i <= count, i++)
			F = new /obj/item/weapon/flint(src)
		return F
	var/list/lode = expedition_lode_types[kind]
	if (!islist(lode))
		return null
	var/path = lode[1]
	var/amount = rand(lode[2], lode[3])
	return quarry_drop_ore(path, amount, rubble)

// One more roll per mined wall on a land across the sea (mining_proc).
/turf/proc/mining_expedition_lode(mob/living/human/H, list/rubble = null)
	var/list/res = expedition_land_resources()
	if (!res)
		return null
	var/obj/item/found = null
	var/list/kinds = expedition_lode_kinds()
	if (length(kinds) && prob(expedition_lode_chance()))
		var/kind = pick(kinds)
		found = expedition_lode(kind, rubble)
		if (found && H)
			to_chat(H, SPAN_GREEN_BOLD("You struck a rich lode of [kind]!"))
	var/list/rare = islist(res["rare"]) ? res["rare"] : list()
	if ("gems" in rare)
		if (prob(4))
			var/gem_type = pickweight(gem_pocket_weights)
			var/obj/item/stack/ore/gem/G = new gem_type(src)
			found = G
			if (H)
				to_chat(H, SPAN_GREEN_BOLD("You found \a [G.singular_name]!"))
	if (("rich gold vein" in rare) && prob(3))
		found = quarry_drop_ore(/obj/item/stack/ore/gold, 8, rubble)
		if (H)
			to_chat(H, SPAN_GREEN_BOLD("You broke into a rich vein of <b>gold</b>!"))
	if (("rich silver vein" in rare) && prob(3))
		found = quarry_drop_ore(/obj/item/stack/ore/silver, 8, rubble)
		if (H)
			to_chat(H, SPAN_GREEN_BOLD("You broke into a rich vein of <b>silver</b>!"))
	if (("diamonds" in rare) && prob(1))
		found = quarry_drop_ore(/obj/item/stack/ore/diamond, 2, rubble)
		if (H)
			to_chat(H, SPAN_GREEN_BOLD("You found rough <b>diamonds</b>!"))
	return found

// Makes the land's own game plentiful (ecology_spawner New). Returns how many
// species were raised.
/proc/expedition_land_tune_species(list/table)
	var/list/res = expedition_land_resources()
	if (!res || !islist(res["game"]) || !islist(table))
		return 0
	var/raised = 0
	for (var/datum/ecology_species/S in table)
		if (!(S.name in res["game"]))
			continue
		S.density *= LAND_GAME_DENSITY
		S.max_target *= LAND_GAME_TARGET
		raised++
	return raised

#undef LAND_GAME_DENSITY
#undef LAND_GAME_TARGET
