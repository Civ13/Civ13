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
// On a steered chart a token has momentum: a burn along a heading speeds it
// up, it coasts when the burn is cut, a stop order burns against its motion
// until it lies still, and a course laid for a place brings it there and
// stops it. Site loading and the hazard effects come with the phases that
// use them. Positions and speeds are plain numbers, never world.time stamps.

var/global/list/charts = list()

/datum/chart
	var/name = "chart"
	var/tmp/step_timer = 0
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
	if (step_timer)
		deltimer(step_timer)
		step_timer = 0
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

// How much the hazards at a point muddy sensors there.
/datum/chart/proc/interference_at(x, y)
	. = 0
	for (var/datum/chart_hazard/H in hazards_at(x, y))
		. += H.interference

// What this token can make out: every other token within its sensor range,
// less the interference where the viewer is and where the other token is.
// A token running dark is still listed; contact_name() hides what it is.
/datum/chart/proc/contacts_of(datum/chart_token/viewer)
	. = list()
	if (!viewer || viewer.chart != src)
		return
	var/reach = viewer.sensor_range - interference_at(viewer.x, viewer.y)
	if (reach <= 0)
		return
	for (var/datum/chart_token/T in tokens_near(viewer.x, viewer.y, reach))
		if (T != viewer && chart_distance(viewer.x, viewer.y, T.x, T.y) <= reach - interference_at(T.x, T.y))
			. += T

// One step of a steered chart: every token moves by its orders and hazards
// count down. Returns how many tokens are still moving or under orders.
/datum/chart/proc/run_step(seconds = CHART_STEP_SECONDS)
	. = 0
	if (mode != CHART_MODE_STEERED)
		return
	for (var/datum/chart_token/T in tokens)
		if (T.advance(seconds))
			.++
	for (var/datum/chart_hazard/H in hazards.Copy())
		for (var/datum/chart_token/T in tokens)
			if (T.craft && H.covers(T.x, T.y))
				H.affect_craft(T.craft)
		if (H.lifetime > 0)
			H.lifetime -= seconds
			if (H.lifetime <= 0)
				hazards -= H
				H.chart = null
				qdel(H)

// Starts the chart stepping; it stops by itself when nothing moves.
/datum/chart/proc/wake()
	if (step_timer || mode != CHART_MODE_STEERED)
		return
	step_timer = addtimer(CALLBACK(src, PROC_REF(tick)), CHART_STEP_SECONDS * 10, TIMER_LOOP | TIMER_STOPPABLE)

/datum/chart/proc/tick()
	if (!run_step(CHART_STEP_SECONDS) && step_timer)
		deltimer(step_timer)
		step_timer = 0

/proc/chart_distance(ax, ay, bx, by)
	return sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))

// Degrees clockwise from north of the way from one point to another.
/proc/chart_bearing(ax, ay, bx, by)
	if (ax == bx && ay == by)
		return 0
	. = arctan(by - ay, bx - ax)
	if (. < 0)
		. += 360

// A bearing as a sailor says it: one of sixteen points.
/proc/chart_bearing_name(degrees)
	var/list/points = list("north", "north-northeast", "northeast", "east-northeast", "east", "east-southeast", "southeast", "south-southeast", "south", "south-southwest", "southwest", "west-southwest", "west", "west-northwest", "northwest", "north-northwest")
	var/index = round((degrees - 360 * round(degrees / 360)) / 22.5, 1) % 16
	return points[index + 1]

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
	// Steered charts: speed in squares per second, the heading a burn pushes
	// along (degrees clockwise from north), the share of full burn, a stop
	// order, and a course laid for a place.
	var/vx = 0
	var/vy = 0
	var/heading = 0
	var/throttle = 0
	var/stopping = FALSE
	var/on_course = FALSE
	var/course_x = 0
	var/course_y = 0
	var/course_name = ""
	var/accel = 0                 // Squares per second per second, for a token with no craft.
	var/max_speed = CHART_MAX_SPEED

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

/datum/chart_token/proc/speed()
	return sqrt(vx * vx + vy * vy)

// What a full burn gives: from her drives against her tiles of hull, or the
// token's own figure when it has no craft.
/datum/chart_token/proc/full_accel()
	return craft ? craft.thrust_per_tile() * CHART_ACCEL_PER_THRUST : accel

// Pays for a burn at that share of full power. Returns the share paid.
/datum/chart_token/proc/pay(share)
	if (!craft)
		return 1
	var/paid = 0
	var/drives = 0
	for (var/datum/craft_drive/D in craft.drives)
		if (!D.ready())
			continue
		drives++
		paid += D.burn(share)
	return drives ? paid / drives : 0

// A burn along a heading. A throttle of 0 cuts the engines: she coasts.
/datum/chart_token/proc/set_burn(new_heading, new_throttle)
	heading = new_heading - 360 * round(new_heading / 360)
	throttle = clamp(new_throttle, 0, 1)
	stopping = FALSE
	on_course = FALSE
	if (chart && throttle > 0)
		chart.wake()

// Burns against her motion until she lies still.
/datum/chart_token/proc/order_stop()
	throttle = 0
	on_course = FALSE
	stopping = speed() > 0
	if (chart && stopping)
		chart.wake()

// Makes for a place and stops there.
/datum/chart_token/proc/lay_course(x, y, place_name = "")
	if (!chart || !chart.in_bounds(x, y))
		return FALSE
	course_x = x
	course_y = y
	course_name = place_name
	on_course = TRUE
	stopping = FALSE
	throttle = 0
	chart.wake()
	return TRUE

// Seconds to reach a place from rest and stop there, as an estimate: speed
// up, coast at the limit, slow down. -1 when she cannot move at all.
/datum/chart_token/proc/eta(x, y)
	var/a = full_accel()
	if (a <= 0)
		return -1
	var/d = chart_distance(src.x, src.y, x, y)
	if (d <= CHART_ARRIVE_RANGE)
		return 0
	if (d < max_speed * max_speed / a)
		return round(2 * sqrt(d / a))
	return round(d / max_speed + max_speed / a)

// Changes her speed towards (wx, wy) by at most what the burn allows.
/datum/chart_token/proc/push_towards(wx, wy, seconds, share = 1)
	var/dx = wx - vx
	var/dy = wy - vy
	var/want = sqrt(dx * dx + dy * dy)
	var/a = full_accel() * share
	if (want <= 0 || a <= 0)
		return 0
	var/give = min(want, a * seconds)
	give *= pay(share * give / (a * seconds))
	if (give <= 0)
		return 0
	vx += dx / want * give
	vy += dy / want * give
	return give

// One step for this token. TRUE while it is moving or under orders.
/datum/chart_token/proc/advance(seconds)
	if (!chart || chart.mode != CHART_MODE_STEERED)
		return FALSE
	if (on_course)
		var/d = chart_distance(x, y, course_x, course_y)
		if (d <= CHART_ARRIVE_RANGE && speed() <= full_accel() * seconds)
			x = course_x
			y = course_y
			vx = 0
			vy = 0
			on_course = FALSE
			arrived()
			return FALSE
		// The fastest she may go and still stop in the distance left.
		var/a = full_accel()
		var/top = min(max_speed, sqrt(2 * a * d))
		push_towards((course_x - x) / max(d, 0.001) * top, (course_y - y) / max(d, 0.001) * top, seconds)
	else if (stopping)
		push_towards(0, 0, seconds)
		if (speed() < 0.0001)
			vx = 0
			vy = 0
			stopping = FALSE
	else if (throttle > 0)
		push_towards(vx + sin(heading) * max_speed, vy + cos(heading) * max_speed, seconds, throttle)
		var/v = speed()
		if (v > max_speed)
			vx *= max_speed / v
			vy *= max_speed / v
	if (!vx && !vy)
		// Under orders but with nothing to drive her, she waits.
		return (on_course || throttle > 0) && full_accel() > 0
	var/nx = x + vx * seconds
	var/ny = y + vy * seconds
	// The edge of the chart stops her dead on that axis.
	if (nx < 1 || nx > chart.width)
		nx = clamp(nx, 1, chart.width)
		vx = 0
	if (ny < 1 || ny > chart.height)
		ny = clamp(ny, 1, chart.height)
		vy = 0
	x = nx
	y = ny
	return TRUE

// She has reached the place her course was laid for.
/datum/chart_token/proc/arrived()
	return

// What a helm reads of her own motion.
/datum/chart_token/proc/motion_text()
	var/v = speed()
	if (on_course)
		var/left = eta(course_x, course_y)
		return "making for [course_name || "[round(course_x)], [round(course_y)]"], [round(chart_distance(x, y, course_x, course_y), 0.1)] squares off[left >= 0 ? ", about [left] seconds from rest" : ", but nothing drives her"]"
	if (stopping)
		return "stopping, [round(v, 0.01)] squares a second"
	if (v <= 0)
		return throttle > 0 ? "burning from rest" : "lying still"
	return "[throttle > 0 ? "burning" : "coasting"] [chart_bearing_name(chart_bearing(0, 0, vx, vy))] at [round(v, 0.01)] squares a second"

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
