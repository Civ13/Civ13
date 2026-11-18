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
#define FRACK_FOUL_SITES 64

var/global/list/fracking_foul_sites = list() // list(x, y, realtime)

/proc/fracking_lands()
	var/static/list/lands = list(MAP_NOMADS_AMERICAS_NORTH, MAP_NOMADS_AMERICAS_SOUTH)
	return lands

// Why H cannot frack at T, or null.
/proc/fracking_refusal(mob/living/human/H, turf/T)
	if (!continent_home()) // continent_resources.dm
		return null
	if (!(map.ID in fracking_lands()))
		return "The ground here holds no oil worth fracturing. Fracking works only in the Americas; elsewhere oil comes from offshore rigs."
	var/datum/province_map/P = map.province_map()
	var/c = P && T ? P.char_at(T.x, T.y) : null
	if (!c)
		return null
	var/holder = province_holder_of(c) // province_holding.dm
	var/side = H && H.civilization && H.civilization != "none" ? province_group_of(H.civilization) : null
	if (!holder || holder != side)
		return "Only the side that holds the [P.names[c]] may frack its ground."
	return null

// One batch's cost to the land around the rig.
/proc/fracking_batch_cost(atom/rig)
	var/turf/T = get_turf(rig)
	if (!T)
		return
	pollution_emit(T, FRACK_POLLUTION, FRACK_POLLUTION_RADIUS)
	fracking_foul_sites.Insert(1, list(list(T.x, T.y, world.realtime)))
	if (fracking_foul_sites.len > FRACK_FOUL_SITES)
		fracking_foul_sites.Cut(FRACK_FOUL_SITES + 1)

// TRUE when water drawn at A is fouled by a recent fracking batch nearby.
/proc/fracking_fouls_near(atom/A)
	if (!fracking_foul_sites.len || !A)
		return FALSE
	var/turf/T = get_turf(A)
	if (!T)
		return FALSE
	for (var/i = fracking_foul_sites.len, i >= 1, i--)
		var/list/S = fracking_foul_sites[i]
		if (world.realtime - S[3] > FRACK_FOUL_TIME)
			fracking_foul_sites.Cut(i, i + 1)
			continue
		if (max(abs(S[1] - T.x), abs(S[2] - T.y)) <= FRACK_FOUL_RANGE)
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
#undef FRACK_FOUL_SITES
