// Charts (docs/craft-core.md): a flat map of tokens for the crafts, harbours,
// sites and hazards of one stretch of sea or space.
//
// A chart runs in one of two modes. A mirror chart copies the world: every
// token follows the real position of its craft, so it is a picture of a map
// people already sail on. A steered chart is the world: a helm steers the
// token, and the craft is wherever the token says. Sites are places on a chart
// that load a piece of map when a craft stops there; hazards are areas that do
// something to the crafts inside them.
//
// This is the shared base: the data and the hooks. The helm window, movement
// by heading and burn, site loading and the hazard effects come with the
// phases that use them. Positions are plain numbers, never world.time stamps.

var/global/list/charts = list()

/datum/chart
	var/name = "chart"
	var/mode = CHART_MODE_MIRROR
	var/width = 1
	var/height = 1
	var/list/tokens = list()      // /datum/chart_token
	var/list/sites = list()       // /datum/chart_site
	var/list/hazards = list()     // /datum/chart_hazard

/datum/chart/New()
	..()
	charts += src

/datum/chart/Destroy()
	charts -= src
	for (var/datum/chart_token/T in tokens)
		T.chart = null
	tokens.Cut()
	sites.Cut()
	hazards.Cut()
	return ..()

/datum/chart/proc/in_bounds(x, y)
	return x >= 1 && y >= 1 && x <= width && y <= height

/datum/chart/proc/add_token(datum/chart_token/T, x, y)
	if (!T || !in_bounds(x, y))
		return FALSE
	if (T.chart && T.chart != src)
		T.chart.tokens -= T
	T.chart = src
	T.x = x
	T.y = y
	tokens |= T
	return TRUE

/datum/chart/proc/remove_token(datum/chart_token/T)
	if (!(T in tokens))
		return FALSE
	tokens -= T
	T.chart = null
	return TRUE

// Where a turf of the real map lies on a mirror chart: list(x, y), or null.
// The base chart mirrors nothing.
/datum/chart/proc/chart_position(turf/T)
	return null

// Tokens within range of a point, nearest first is not promised.
/datum/chart/proc/tokens_near(x, y, range)
	. = list()
	for (var/datum/chart_token/T in tokens)
		if (max(abs(T.x - x), abs(T.y - y)) <= range)
			. += T

// What this token can make out: every other token within its sensor range.
// A token running dark is still listed; contact_name() hides what it is.
/datum/chart/proc/contacts_of(datum/chart_token/viewer)
	. = list()
	if (!viewer || viewer.chart != src)
		return
	for (var/datum/chart_token/T in tokens_near(viewer.x, viewer.y, viewer.sensor_range))
		if (T != viewer)
			. += T

/datum/chart/proc/hazards_at(x, y)
	. = list()
	for (var/datum/chart_hazard/H in hazards)
		if (H.covers(x, y))
			. += H

// Anything shown on a chart. A token with a craft is that craft's place.
/datum/chart_token
	var/name = "contact"
	var/kind = "craft"            // "craft", "harbour", "site", "hazard", "link"
	var/datum/chart/chart
	var/datum/craft/craft
	var/x = 1
	var/y = 1
	var/sensor_range = CHART_SENSOR_RANGE
	var/dark = FALSE              // Running dark: seen, but not known.

/datum/chart_token/Destroy()
	if (chart)
		chart.tokens -= src
		chart = null
	if (craft && craft.token == src)
		craft.token = null
	craft = null
	return ..()

// The name another token's crew reads for this one.
/datum/chart_token/proc/contact_name()
	return dark ? "unknown contact" : name

// On a mirror chart, puts the token where its craft really is.
/datum/chart_token/proc/follow_craft()
	if (!chart || chart.mode != CHART_MODE_MIRROR || !craft || !craft.body)
		return FALSE
	var/list/at = chart.chart_position(craft.body.origin())
	if (!islist(at) || !chart.in_bounds(at[1], at[2]))
		return FALSE
	x = at[1]
	y = at[2]
	return TRUE

// A place on a chart that can load a piece of map: a wreck, a derelict, an
// island, a patch of open water where crafts meet.
/datum/chart_site
	var/name = "site"
	var/datum/chart/chart
	var/x = 1
	var/y = 1
	var/weight = 1                // How often it is picked among its kind.
	var/kept = FALSE              // A keep beacon holds it loaded.
	var/loaded = FALSE

// The map file this site loads, or null for a site with no map of its own.
/datum/chart_site/proc/site_template()
	return null

// TRUE when the site may be unloaded now. Subtypes add their own reasons to
// stay (a character aboard, a claimed bed).
/datum/chart_site/proc/can_unload()
	return loaded && !kept

// An area of a chart that does something to the crafts inside it.
/datum/chart_hazard
	var/name = "hazard"
	var/datum/chart/chart
	var/x = 1
	var/y = 1
	var/radius = 0
	var/interference = 0          // How much it muddies sensors and radio.
	var/lifetime = 0              // Seconds left; 0 means it stays.

/datum/chart_hazard/proc/covers(tx, ty)
	return max(abs(tx - x), abs(ty - y)) <= radius

// Called for each craft inside the hazard on the chart's tick.
/datum/chart_hazard/proc/affect_craft(datum/craft/C)
	return

// Lets a hazard shape a site that loads inside it.
/datum/chart_hazard/proc/shape_site(datum/chart_site/S)
	return
