// Each continent's own resources (docs/provinces.md, "Continent resources").
// Val (2026-11-18): each continent is rich in a critical resource that can only
// be had in reasonable quality and quantity there; Gaia is great for new people
// and staying alive but not for reaching the endgame. Reviewed by Fable.
//
// Mining finds follow the continent:
// - Its own resources come twice as often.
// - Other bulk ores (copper, tin, coal, zinc) and precious finds (silver, gold,
//   diamonds, gems) come at half, strategic ores (saltpeter, sulphur, lead,
//   bauxite) at a third. Iron stays normal everywhere.
// - Gaia keeps tin and iron at the normal rate so a new player reaches bronze
//   and iron alone, has copper at twice, and no bauxite or uranium at all.
// - Lands that are not continents (expedition islands, battle maps) mine as
//   before.
// Lowered rates phase in: normal for CONTINENT_PHASE_DAYS days after this world
// first used them, then three quarters, then final after twice that. Raised
// rates apply at once. State: map.faction_recruitment["continent_resources_from"].
// Nothing here sleeps.

#define CONTINENT_HOME 2
#define CONTINENT_RICH 3 // in the resource's rich provinces (province_rich.dm)
#define CONTINENT_BULK 0.5
#define CONTINENT_STRATEGIC 0.33
#define CONTINENT_PHASE_DAYS 7

// Map id -> the resources it is rich in.
/proc/continent_home_resources()
	var/static/list/homes = list(
		MAP_NOMADS_GAIA = list("copper"),
		MAP_NOMADS_JUNGLE = list("tin"),
		MAP_NOMADS_AMERICAS_NORTH = list("iron", "lead"),
		MAP_NOMADS_EUROPE = list("coal", "zinc"),
		MAP_NOMADS_ASIA = list("saltpeter", "silver", "gems", "diamond"),
		MAP_NOMADS_DESERT = list("sulphur"),
		MAP_NOMADS_AMERICAS_SOUTH = list("gold", "silver", "bauxite"),
		MAP_NOMADS_EARTH_EUROPE = list("coal", "zinc"),
		MAP_NOMADS_EARTH_AFRICA = list("sulphur", "tin"), // Africa replaces the Desert and the Jungle
		MAP_NOMADS_EARTH_ASIA = list("saltpeter", "silver", "gems", "diamond"),
		MAP_NOMADS_EARTH_OCEANIA = list("bauxite", "uranium", "gems"), // reached only by sea and air
		MAP_NOMADS_EARTH_GREENLAND = list("zinc", "lead", "gold"),
		MAP_NOMADS_EARTH_ANTARCTICA = list("coal"), // a hard-won frontier seam
	)
	return homes

// Resource -> its rate on a continent that is not its home.
/proc/continent_away_rates()
	var/static/list/rates = list(
		"iron" = 1, "uranium" = 1,
		"copper" = CONTINENT_BULK, "tin" = CONTINENT_BULK, "coal" = CONTINENT_BULK, "zinc" = CONTINENT_BULK,
		"silver" = CONTINENT_BULK, "gold" = CONTINENT_BULK, "diamond" = CONTINENT_BULK, "gems" = CONTINENT_BULK,
		"saltpeter" = CONTINENT_STRATEGIC, "sulphur" = CONTINENT_STRATEGIC, "lead" = CONTINENT_STRATEGIC, "bauxite" = CONTINENT_STRATEGIC,
	)
	return rates

// Gaia, the start continent, differs from the away rates here.
/proc/continent_gaia_rates()
	var/static/list/rates = list("tin" = 1, "bauxite" = 0, "uranium" = 0)
	return rates

// The resources this land is rich in, or null when it is not a continent.
/proc/continent_home()
	if (!map)
		return null
	var/list/homes = continent_home_resources()
	return homes[map.ID]

// The realtime the lowered rates started phasing in; set on first use.
/obj/map_metadata/proc/continent_resources_from()
	var/list/S = recruitment_state()
	if (!isnum(S["continent_resources_from"]))
		S["continent_resources_from"] = world.realtime
	return S["continent_resources_from"]

// The rate a lowered resource has reached in its phase-in.
/proc/continent_phased(rate)
	if (rate >= 1)
		return rate
	var/days = (world.realtime - map.continent_resources_from()) / 864000
	if (days < CONTINENT_PHASE_DAYS)
		return 1
	if (days < 2 * CONTINENT_PHASE_DAYS)
		return max(rate, 0.75)
	return rate

// The final rate of resource here (at turf T when given), before any phase-in.
/proc/continent_rate(resource, turf/T = null)
	var/list/home = continent_home()
	if (!home)
		return 1
	if (resource in home)
		return T && province_rich_at(T) == resource ? CONTINENT_RICH : CONTINENT_HOME
	if (map.ID == MAP_NOMADS_GAIA)
		var/list/gaia = continent_gaia_rates()
		if (!isnull(gaia[resource]))
			return gaia[resource]
	var/list/away = continent_away_rates()
	return isnull(away[resource]) ? 1 : away[resource]

// What a chance or an amount of resource is multiplied by when mined here now.
/proc/continent_ore_factor(resource, turf/T = null)
	return continent_phased(continent_rate(resource, T))

// The resource an ore type counts as, or null for one the continents leave alone.
/proc/continent_ore_resource(ore_type)
	var/static/list/kinds = list(
		/obj/item/stack/ore/copper = "copper", /obj/item/stack/ore/tin = "tin",
		/obj/item/stack/ore/iron = "iron", /obj/item/stack/ore/zinc = "zinc",
		/obj/item/stack/ore/coal = "coal", /obj/item/stack/ore/saltpeter = "saltpeter",
		/obj/item/stack/ore/sulphur = "sulphur", /obj/item/stack/ore/lead = "lead",
		/obj/item/stack/ore/silver = "silver", /obj/item/stack/ore/gold = "gold",
		/obj/item/stack/ore/gold_quartz = "gold", /obj/item/stack/ore/silver_lode = "silver",
		/obj/item/stack/ore/bauxite = "bauxite", /obj/item/stack/ore/diamond = "diamond",
	)
	return kinds[ore_type]

// A mountain seam's load (mountain_seams.dm): the amount to give, 0 when the
// continent's lower rate leaves only stone this time.
/proc/continent_seam_amount(ore_type, amount, turf/T = null)
	var/resource = continent_ore_resource(ore_type)
	if (!resource)
		return amount
	var/factor = continent_ore_factor(resource, T)
	if (factor < 1)
		return prob(factor * 100) ? amount : 0
	return round(amount * factor)

// One line for Faction > Province Holdings and Admin > Land Status.
/proc/continent_resources_text()
	var/list/home = continent_home()
	if (!home)
		return ""
	var/list/names = list()
	for (var/resource in home)
		if (resource == "diamond")
			continue
		names += resource
	var/text = "This continent is rich in [english_list(names)]: they are found twice as often here. Other ores are scarcer than elsewhere, except iron."
	if (map.ID == MAP_NOMADS_GAIA)
		text += " Tin stays plentiful, but there is no bauxite or uranium."
	var/days = round((map.continent_resources_from() + 2 * CONTINENT_PHASE_DAYS * 864000 - world.realtime) / 864000, 0.1)
	if (days > 0)
		text += " The scarcer rates are phasing in over the next [days] days."
	var/rich = province_rich_text() // province_rich.dm
	if (rich)
		text += " [rich]"
	return text

#undef CONTINENT_HOME
#undef CONTINENT_RICH
#undef CONTINENT_BULK
#undef CONTINENT_STRATEGIC
#undef CONTINENT_PHASE_DAYS
