// ============================================================
// The orbit chart (docs/craft-core.md, docs/orbital-stations-plan.md)
// ------------------------------------------------------------
// An orbit world has one steered chart (craft/chart.dm): a square of
// ORBIT_CHART_SIZE squares with the arrival beacon in the middle. Every
// party that owns planes in the plane registry has a station token on it,
// at a spot the registry keeps as plain numbers, so stations lie apart and
// stay where they are across restarts.
//
// Spacecraft fly between them (spacecraft.dm). Until an orbit region runs,
// the probes are what exercises this.
// ============================================================

#define ORBIT_CHART_SIZE 100
#define ORBIT_CHART_SENSOR_RANGE 15
#define ORBIT_CHART_EDGE 5

var/global/datum/chart/orbit/orbit_chart_made = null

/datum/chart/orbit
	name = "orbit chart"
	mode = CHART_MODE_STEERED
	width = ORBIT_CHART_SIZE
	height = ORBIT_CHART_SIZE
	var/datum/chart_token/station/arrival
	var/list/stations = list()    // owner id = /datum/chart_token/station

/datum/chart/orbit/Destroy()
	if (orbit_chart_made == src)
		orbit_chart_made = null
	arrival = null
	stations.Cut()
	return ..()

/datum/chart_token/station
	kind = "station"
	sensor_range = ORBIT_CHART_SENSOR_RANGE
	var/owner = ""

// The chart of this orbit world, with its stations brought up to date, or
// null off an orbit world.
/proc/orbit_chart()
	if (!orbit_world() || !orbit_get_registry())
		return null
	if (!orbit_chart_made || QDELETED(orbit_chart_made))
		orbit_chart_made = new /datum/chart/orbit
	orbit_chart_made.sync_stations()
	return orbit_chart_made

// Where the nth station to be charted lies: a spiral out from the beacon, so
// neighbours are never on top of each other. list(x, y).
/proc/orbit_chart_spot(n)
	var/middle = ORBIT_CHART_SIZE / 2
	var/radius = min(12 + 6 * sqrt(n), middle - ORBIT_CHART_EDGE)
	var/angle = n * 137.5
	return list(round(middle + sin(angle) * radius), round(middle + cos(angle) * radius))

// Makes the station tokens match the plane registry: one for every party
// that owns a plane, none for a party that owns none.
/datum/chart/orbit/proc/sync_stations()
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R)
		return 0
	if (!islist(R.chart_spots))
		R.chart_spots = list()
	if (!arrival)
		arrival = new /datum/chart_token/station
		arrival.kind = "harbour"
		arrival.name = "arrival beacon"
		arrival.owner = "arrival"
		add_token(arrival, round(width / 2), round(height / 2))
	var/list/owners = list()
	for (var/key in R.owners)
		var/owner = R.owners[key]
		// The lanes and loaded sites hold planes but are not stations.
		if (istext(owner) && length(owner) && owner != "arrival" && owner != "transit" && findtext(owner, "site:") != 1)
			owners |= owner
	for (var/owner in stations.Copy())
		if (!(owner in owners))
			qdel(stations[owner])
			stations -= owner
			R.chart_spots -= owner
	for (var/owner in owners)
		var/datum/chart_token/station/T = stations[owner]
		if (!T)
			T = new /datum/chart_token/station
			T.owner = owner
			stations[owner] = T
		T.name = "[party_train_party_name(owner)] station"
		var/list/spot = null
		var/saved = R.chart_spots[owner]
		if (istext(saved))
			var/list/parts = splittext(saved, ",")
			if (parts.len == 2 && in_bounds(text2num(parts[1]), text2num(parts[2])))
				spot = list(text2num(parts[1]), text2num(parts[2]))
		if (!spot)
			spot = orbit_chart_spot(R.chart_spots.len + 1)
			R.chart_spots[owner] = "[spot[1]],[spot[2]]"
		if (T.chart != src || T.x != spot[1] || T.y != spot[2])
			add_token(T, spot[1], spot[2])
	return stations.len

// The token of a party's station, or null.
/proc/orbit_chart_station(owner)
	var/datum/chart/orbit/C = orbit_chart()
	return C ? C.stations[owner] : null

// The token of whatever holds a plane: the arrival beacon, a station, or
// null for the lanes and for a plane nobody holds.
/datum/chart/orbit/proc/place_of_owner(owner)
	if (owner == "arrival")
		return arrival
	return (istext(owner) && length(owner)) ? stations[owner] : null

// The helm of a spacecraft (spacecraft.dm).
/obj/structure/chart_helm/orbit
	name = "orbital helm"
	desc = "The orbit chart and the engine controls of a spacecraft. Set on the floor of a habitat module, it flies that module and every module docked to it."

/obj/structure/chart_helm/orbit/chart()
	return orbit_chart()
