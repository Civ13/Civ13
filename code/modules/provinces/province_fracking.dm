// Fracking on the continents (Val, 2026-11-18): a late-era way for the Americas
// to get oil from the ground, at the cost of their land.
//
// - On the continents a hydraulic fracturing rig works only in North and South
//   America. Elsewhere offshore rigs are the late-era source of oil. Lands that
//   are not continents (expedition islands, battle maps) frack as before.
// - The rig works only in a province held by the operator's side, so the cost
//   falls on the holder's own land.
// - Each batch soils the ground within FRACK_POLLUTION_RADIUS tiles of the rig
//   (ecology/pollution.dm): crops near a busy rig slow and then stop. Charcoal
//   and time clear it.
// - Each batch fouls the groundwater: for a day, wells and puddles within
//   FRACK_FOUL_RANGE tiles of it, on any level, draw foul water (the dirty-water
//   rule in watercloset.dm, which soap clears once the day is out).
//
// State: fracking_foul_sites, runtime only (a restart clears it; wells already
// fouled stay dirty until washed). Nothing here sleeps.

#define FRACK_POLLUTION 25
#define FRACK_POLLUTION_RADIUS 3
#define FRACK_FOUL_RANGE 6
#define FRACK_FOUL_TIME 864000 // a day, in world.realtime tenths

var/global/list/fracking_foul_sites = list() // "x,y" -> last batch realtime, oldest batch first

/proc/fracking_lands()
	var/static/list/lands = list(MAP_NOMADS_AMERICAS_NORTH, MAP_NOMADS_AMERICAS_SOUTH)
	return lands

// Why the initiating faction cannot frack at T, or null.
/proc/fracking_refusal(faction, turf/T)
	if (!continent_home()) // continent_resources.dm
		return null
	if (!(map.ID in fracking_lands()))
		return "The ground here holds no oil worth fracturing. Fracking works only in the Americas; elsewhere oil comes from offshore rigs."
	var/datum/province_map/P = map.province_map()
	var/c = P && T ? P.char_at(T.x, T.y) : null
	if (!c)
		return null
	var/holder = province_holder_of(c) // province_holding.dm
	var/side = faction && faction != "none" ? province_group_of(faction) : null
	if (!holder || holder != side)
		return "Only the side that holds the [P.names[c]] may frack its ground."
	return null

// One batch's cost to the land around the rig.
/proc/fracking_batch_cost(atom/rig)
	var/turf/T = get_turf(rig)
	if (!T)
		return
	pollution_emit(T, FRACK_POLLUTION, FRACK_POLLUTION_RADIUS)
	fracking_record_foul_site(T.x, T.y)

// Only successful batches refresh their own column. Prune the expired
// prefix when writing, so unrelated activity cannot evict a live site.
/proc/fracking_record_foul_site(x, y, now = world.realtime)
	var/first_live = 1
	while (first_live <= fracking_foul_sites.len)
		var/oldest_key = fracking_foul_sites[first_live]
		if (now - fracking_foul_sites[oldest_key] <= FRACK_FOUL_TIME)
			break
		first_live++
	if (first_live > 1)
		fracking_foul_sites.Cut(1, first_live)
	var/site = "[x],[y]"
	fracking_foul_sites -= site
	fracking_foul_sites[site] = now

// Search only the six-tile horizontal neighborhood, independent of map z
// and the number of batches elsewhere. Check expiry even without new batches.
/proc/fracking_fouls_near(atom/A, now = world.realtime)
	if (!fracking_foul_sites.len || !A)
		return FALSE
	var/turf/T = get_turf(A)
	if (!T)
		return FALSE
	for (var/x in max(1, T.x - FRACK_FOUL_RANGE) to min(world.maxx, T.x + FRACK_FOUL_RANGE))
		for (var/y in max(1, T.y - FRACK_FOUL_RANGE) to min(world.maxy, T.y + FRACK_FOUL_RANGE))
			var/last_batch = fracking_foul_sites["[x],[y]"]
			if (isnum(last_batch) && now - last_batch <= FRACK_FOUL_TIME)
				return TRUE
	return FALSE

/proc/fracking_text()
	if (!continent_home())
		return ""
	if (map.ID in fracking_lands())
		return "Fracking rigs work here, in a province their side holds; each batch soils the ground around the rig and fouls nearby wells for a day."
	return ""

#undef FRACK_POLLUTION
#undef FRACK_POLLUTION_RADIUS
#undef FRACK_FOUL_RANGE
#undef FRACK_FOUL_TIME
