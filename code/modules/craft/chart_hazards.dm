// ============================================================
// Chart hazards and sectors (docs/craft-core.md)
// ------------------------------------------------------------
// A hazard is an area of a steered chart that does something to the crafts
// inside it (craft/chart.dm holds the base). Here are the parts every chart
// shares:
//
//  - hazards drift, count down and go, and tell a crew when their craft
//    enters one;
//  - a chart rolls for passing hazards from its passing_table() while it is
//    awake (while anything on it moves), up to hazard_cap at once, and lays
//    its standing ones once from standing_hazards();
//  - the kinds: a field (a reef, an asteroid field) strikes a craft that
//    crosses it faster than a share of her top speed; a storm blows her off
//    her course and muddies her sensors; a wormhole throws her to its twin;
//  - sectors: boxes of a chart with rules. A harbour sector keeps hazards
//    out and may forbid boarding; a held sector belongs to a party.
//
// Nothing here is saved. Standing hazards are laid at fixed spots, so they
// are where they were after a restart; passing ones are weather.
//
// A new hazard is a subtype that overrides affect_token(), shape() or
// enter_text(); a new chart lists its hazards in the two table procs.
// ============================================================

// Set by a test that must not meet weather: no chart lays or rolls hazards.
var/global/chart_hazards_off = FALSE

/datum/chart
	var/list/sectors = list()     // /datum/chart_sector
	var/hazard_cap = CHART_HAZARD_CAP
	var/hazards_on = TRUE         // FALSE: no standing hazards are laid and none pass.
	var/tmp/hazard_clock = 0
	var/tmp/standing_laid = FALSE

/datum/chart_token
	var/tmp/hazard_rest = 0       // Seconds a wormhole leaves her alone.

/datum/chart_hazard
	var/kind = "hazard"
	var/vx = 0                    // Drift, in squares a second.
	var/vy = 0
	var/passing = FALSE           // Rolled by the chart; counts towards its cap.
	var/tmp/list/inside = list()  // Tokens inside it at the last step.

/datum/chart_hazard/Destroy()
	if (chart)
		chart.hazards -= src
		chart = null
	inside = list()
	return ..()

// ---- The chart's side ----

// Puts a hazard on the chart. FALSE when a sector there keeps hazards out.
/datum/chart/proc/add_hazard(datum/chart_hazard/H, x, y)
	if (!H || !in_bounds(x, y) || !hazard_allowed(x, y, H.radius))
		return FALSE
	if (H.chart && H.chart != src)
		H.chart.hazards -= H
	H.chart = src
	H.x = x
	H.y = y
	hazards |= H
	return TRUE

/datum/chart/proc/add_sector(datum/chart_sector/S)
	if (!S)
		return FALSE
	sectors |= S
	S.chart = src
	return TRUE

// The first sector that holds this point, or null: the open chart.
/datum/chart/proc/sector_at(x, y)
	for (var/datum/chart_sector/S in sectors)
		if (S.covers(x, y))
			return S
	return null

// TRUE when a hazard of that radius may lie there.
/datum/chart/proc/hazard_allowed(x, y, radius = 0)
	for (var/datum/chart_sector/S in sectors)
		if (!S.hazards && S.touches(x, y, radius))
			return FALSE
	return TRUE

// Why a craft at this point may not be boarded, or null.
/datum/chart/proc/boarding_refusal(x, y)
	var/datum/chart_sector/S = sector_at(x, y)
	return (S && !S.boarding) ? "[S.name] [S.kind == CHART_SECTOR_HARBOUR ? "are harbour waters" : "is closed water"]: no boarding there" : null

// The hazards that pass over this chart: type = weight. None by default.
/datum/chart/proc/passing_table()
	return list()

// The hazards that always lie on this chart: a list of
// list(type, x, y, radius). None by default.
/datum/chart/proc/standing_hazards()
	return list()

// Lays the standing hazards, once.
/datum/chart/proc/lay_standing()
	if (standing_laid || !hazards_on || chart_hazards_off)
		return 0
	standing_laid = TRUE
	. = 0
	for (var/list/spec in standing_hazards())
		var/path = spec[1]
		var/datum/chart_hazard/H = new path
		H.radius = spec[4]
		if (add_hazard(H, spec[2], spec[3]))
			.++
		else
			qdel(H)

/datum/chart/proc/passing_count()
	. = 0
	for (var/datum/chart_hazard/H in hazards)
		if (H.passing)
			.++

// A spot for a new passing hazard: where hazards are allowed and no craft
// lies under it. list(x, y) or null.
/datum/chart/proc/passing_spot(radius)
	for (var/tries = 1, tries <= 20, tries++)
		var/x = rand(1 + radius, max(1 + radius, width - radius))
		var/y = rand(1 + radius, max(1 + radius, height - radius))
		if (!hazard_allowed(x, y, radius))
			continue
		var/clear = TRUE
		for (var/datum/chart_token/T in tokens_near(x, y, radius + 2))
			if (T.craft)
				clear = FALSE
				break
		if (clear)
			return list(x, y)
	return null

// Brings one passing hazard onto the chart: of that type, or one picked from
// the table by weight. Returns it, or null.
/datum/chart/proc/spawn_passing(path = null)
	if (!path)
		var/list/table = passing_table()
		if (!table.len)
			return null
		path = pickweight(table)
	var/datum/chart_hazard/H = new path
	H.passing = TRUE
	H.shape()
	var/list/spot = passing_spot(H.radius)
	if (!spot || !add_hazard(H, spot[1], spot[2]) || !H.arrive())
		qdel(H)
		return null
	return H

// The hazard part of a chart's step: drift, the crafts inside, countdowns
// and the roll for a new passing hazard.
/datum/chart/proc/hazard_step(seconds)
	lay_standing()
	for (var/datum/chart_token/T in tokens)
		if (T.hazard_rest > 0)
			T.hazard_rest = max(0, T.hazard_rest - seconds)
	for (var/datum/chart_hazard/H in hazards.Copy())
		if (QDELETED(H))
			hazards -= H
			continue
		H.chart = src
		H.drift(seconds)
		var/list/now = list()
		for (var/datum/chart_token/T in tokens)
			if (!T.craft || !H.covers(T.x, T.y) || !T.exposed())
				continue
			now += T
			if (!(T in H.inside))
				H.entered(T)
			H.affect_token(T, seconds)
			// A wormhole may have thrown her out of it.
			if (!H.covers(T.x, T.y))
				now -= T
		H.inside = now
		if (H.lifetime > 0)
			H.lifetime -= seconds
			if (H.lifetime <= 0)
				hazards -= H
				qdel(H)
	if (!hazards_on || chart_hazards_off)
		return
	hazard_clock += seconds
	while (hazard_clock >= CHART_HAZARD_ROLL)
		hazard_clock -= CHART_HAZARD_ROLL
		if (passing_count() < hazard_cap)
			spawn_passing()

// What a helm reads of the hazards within sight of a token: one line each.
// unit is what the chart calls a square ("squares", "miles").
/datum/chart/proc/hazard_lines(datum/chart_token/T, unit = "squares")
	. = list()
	if (!T)
		return
	lay_standing()
	var/reach = T.sensor_range - interference_at(T.x, T.y)
	for (var/datum/chart_hazard/H in hazards)
		var/far = chart_distance(T.x, T.y, H.x, H.y)
		if (H.covers(T.x, T.y))
			. += "<b>She lies in [H.a_name()].</b> [H.advice(T)]"
		else if (far - H.radius <= reach)
			. += "[capitalize(H.a_name())], [H.radius * 2 + 1] [unit] across: [round(far, 0.1)] [unit] [chart_bearing_name(chart_bearing(T.x, T.y, H.x, H.y))][H.motion_text()][H.time_text()]. [H.advice(T)]"
	var/datum/chart_sector/S = sector_at(T.x, T.y)
	if (S)
		. += S.describe()

// ---- The hazard's side ----

/datum/chart_hazard/proc/a_name()
	return "\a [name]"

// Sets the size, life and drift of a passing hazard before it is placed.
/datum/chart_hazard/proc/shape()
	radius = rand(1, 3)
	lifetime = rand(300, 900)

// Called once a passing hazard is on the chart. FALSE takes it off again.
/datum/chart_hazard/proc/arrive()
	return TRUE

// Moves it by its drift. It turns back from the edge of the chart and from
// a sector that keeps hazards out.
/datum/chart_hazard/proc/drift(seconds)
	if (!chart || (!vx && !vy))
		return FALSE
	var/nx = x + vx * seconds
	var/ny = y + vy * seconds
	if (!chart.in_bounds(nx, ny) || !chart.hazard_allowed(nx, ny, radius))
		vx = -vx
		vy = -vy
		return FALSE
	x = nx
	y = ny
	return TRUE

/datum/chart_hazard/proc/motion_text()
	if (!vx && !vy)
		return ""
	return ", drifting [chart_bearing_name(chart_bearing(0, 0, vx, vy))]"

/datum/chart_hazard/proc/time_text()
	if (lifetime <= 0)
		return ""
	return lifetime >= 90 ? ", passing in about [round(lifetime / 60, 1)] minutes" : ", passing in under a minute"

// What a helm should do about it, for a token that sees it.
/datum/chart_hazard/proc/advice(datum/chart_token/T)
	return ""

// What her crew is told when she enters it, or null.
/datum/chart_hazard/proc/enter_text(datum/chart_token/T)
	return null

/datum/chart_hazard/proc/entered(datum/chart_token/T)
	var/text = enter_text(T)
	if (text && T.craft)
		T.craft.crew_message(SPAN_WARNING(text))

// Called every step for each craft's token inside it. The base keeps the
// old hook alive.
/datum/chart_hazard/proc/affect_token(datum/chart_token/T, seconds)
	if (T.craft)
		affect_craft(T.craft)

// ---- Fields: reefs and asteroid fields ----

/datum/chart_hazard/field
	name = "asteroid field"
	kind = "field"
	var/safe_share = 0.5          // Of her top speed.
	var/strike_chance = 40        // Per step while she is too fast.
	var/damage = 20
	var/strike_words = "A rock strikes the hull"

/datum/chart_hazard/field/shape()
	radius = rand(2, 4)
	lifetime = 0

/datum/chart_hazard/field/proc/safe_speed(datum/chart_token/T)
	return T.max_speed * safe_share

/datum/chart_hazard/field/advice(datum/chart_token/T)
	return "Keep under [round(safe_speed(T), 0.01)] a second inside it."

/datum/chart_hazard/field/enter_text(datum/chart_token/T)
	return "The [T.craft.name] is among the rocks of [a_name()]. [advice(T)]"

/datum/chart_hazard/field/affect_token(datum/chart_token/T, seconds)
	if (T.speed() <= safe_speed(T) + 0.0001 || !prob(strike_chance))
		return
	strike(T)

// She hits something: it takes half her way off and batters her hull.
/datum/chart_hazard/field/proc/strike(datum/chart_token/T)
	T.vx *= 0.5
	T.vy *= 0.5
	if (T.craft)
		T.craft.hazard_struck(src, damage, strike_words)

/datum/chart_hazard/field/reef
	name = "reef"
	strike_words = "She grinds over the reef"

/datum/chart_hazard/field/reef/enter_text(datum/chart_token/T)
	return "Broken water all round: the [T.craft.name] is over [a_name()]. [advice(T)]"

// ---- Storms ----

/datum/chart_hazard/storm
	name = "squall"
	kind = "storm"
	interference = 15
	var/push = 0.004              // Squares a second she is set, each second.
	var/blow = 0                  // Where it blows to, degrees clockwise from north.

/datum/chart_hazard/storm/shape()
	radius = rand(3, 6)
	lifetime = rand(300, 900)
	blow = rand(0, 359)
	var/pace = rand(2, 6) / 100
	vx = sin(blow) * pace
	vy = cos(blow) * pace

/datum/chart_hazard/storm/advice(datum/chart_token/T)
	return "It sets a ship to the [chart_bearing_name(blow)] and hides what lies beyond."

/datum/chart_hazard/storm/enter_text(datum/chart_token/T)
	return "[capitalize(a_name())] closes round the [T.craft.name]. [advice(T)]"

// She is blown along with it, up to half as fast again as her own top speed.
/datum/chart_hazard/storm/affect_token(datum/chart_token/T, seconds)
	if (push <= 0)
		return
	T.vx += sin(blow) * push * seconds
	T.vy += cos(blow) * push * seconds
	var/v = T.speed()
	var/top = T.max_speed * 1.5
	if (v > top)
		T.vx *= top / v
		T.vy *= top / v
	chart.wake()

// Interference and nothing else: it blinds sensors and passes.
/datum/chart_hazard/storm/solar
	name = "solar storm"
	interference = 10
	push = 0

/datum/chart_hazard/storm/solar/shape()
	..()
	vx = 0
	vy = 0

/datum/chart_hazard/storm/solar/advice(datum/chart_token/T)
	return "It blinds sensors inside it."

// ---- Wormholes ----

/datum/chart_hazard/wormhole
	name = "wormhole"
	kind = "wormhole"
	interference = 5
	var/datum/chart_hazard/wormhole/twin

/datum/chart_hazard/wormhole/Destroy()
	var/datum/chart_hazard/wormhole/other = twin
	twin = null
	if (other && !QDELETED(other))
		other.twin = null
		qdel(other)
	return ..()

/datum/chart_hazard/wormhole/shape()
	radius = 1
	lifetime = rand(600, 1200)

// Its other end opens far off, with the same time to live.
/datum/chart_hazard/wormhole/arrive()
	if (twin)
		return TRUE
	var/datum/chart_hazard/wormhole/other = new type
	other.passing = TRUE
	other.radius = radius
	other.lifetime = lifetime
	for (var/tries = 1, tries <= 20, tries++)
		var/list/spot = chart.passing_spot(radius)
		if (!spot || chart_distance(x, y, spot[1], spot[2]) < min(chart.width, chart.height) / 4)
			continue
		if (chart.add_hazard(other, spot[1], spot[2]))
			join(other)
			return TRUE
	qdel(other)
	return FALSE

/datum/chart_hazard/wormhole/proc/join(datum/chart_hazard/wormhole/other)
	twin = other
	other.twin = src

/datum/chart_hazard/wormhole/advice(datum/chart_token/T)
	if (!twin || !twin.chart)
		return "It leads nowhere."
	return "It throws a craft to its other end at [round(twin.x)], [round(twin.y)]."

/datum/chart_hazard/wormhole/affect_token(datum/chart_token/T, seconds)
	if (T.hazard_rest > 0 || !twin || twin.chart != chart)
		return
	T.x = twin.x
	T.y = twin.y
	T.hazard_rest = CHART_WORMHOLE_REST
	twin.inside |= T
	if (T.craft)
		T.craft.crew_message(SPAN_WARNING("The [name] takes the [T.craft.name] and throws her out of its other end at [round(T.x)], [round(T.y)]."))
	T.thrown(src)

// TRUE while her craft is out on the chart, where a hazard can reach her.
// A token whose craft lies at a place (a harbour, a station, a site) is not.
/datum/chart_token/proc/exposed()
	return TRUE

// A spot on a spiral out from the middle of a chart, for the nth standing
// hazard: the same every time, so a restart moves nothing. list(x, y).
/datum/chart/proc/standing_spot(n, turn = 0)
	var/mx = round(width / 2)
	var/my = round(height / 2)
	var/reach = min(16 + 8 * n, min(mx, my) - 6)
	var/angle = n * 137.5 + turn
	return list(round(mx + sin(angle) * reach), round(my + cos(angle) * reach))

// Called on a token a wormhole has just moved.
/datum/chart_token/proc/thrown(datum/chart_hazard/by)
	return

// ---- Sectors ----

/datum/chart_sector
	var/name = "these waters"
	var/kind = CHART_SECTOR_WILD
	var/datum/chart/chart
	var/x1 = 1
	var/y1 = 1
	var/x2 = 1
	var/y2 = 1
	var/owner = null              // The party that holds it, for a held sector.
	var/hazards = TRUE            // Hazards may lie and pass here.
	var/boarding = TRUE           // Crafts here may be grappled.

/datum/chart_sector/New(new_name = null, ax = 1, ay = 1, bx = 1, by = 1)
	..()
	if (new_name)
		name = new_name
	x1 = min(ax, bx)
	y1 = min(ay, by)
	x2 = max(ax, bx)
	y2 = max(ay, by)

/datum/chart_sector/Destroy()
	if (chart)
		chart.sectors -= src
		chart = null
	return ..()

/datum/chart_sector/proc/covers(x, y)
	return x >= x1 && x <= x2 && y >= y1 && y <= y2

// TRUE when a square of that radius about a point overlaps the sector.
/datum/chart_sector/proc/touches(x, y, radius = 0)
	return x + radius >= x1 && x - radius <= x2 && y + radius >= y1 && y - radius <= y2

/datum/chart_sector/proc/describe()
	var/list/rules = list()
	if (!hazards)
		rules += "no hazard comes here"
	if (!boarding)
		rules += "no ship may be boarded here"
	if (owner)
		rules += "held by [party_train_party_name(owner)]"
	return "[capitalize(name)][rules.len ? ": [jointext(rules, ", ")]" : ""]."

// Sheltered water round a harbour or a beacon: hazards stay out.
/datum/chart_sector/harbour
	kind = CHART_SECTOR_HARBOUR
	hazards = FALSE

// Water a party holds.
/datum/chart_sector/held
	kind = CHART_SECTOR_HELD

// ---- The craft's side ----

// Every chart token she has (a subtype with another token adds it).
/datum/craft/proc/chart_tokens()
	. = list()
	if (token && token.chart)
		. += token

// Why she may not be boarded where she lies on her charts, or null.
/datum/craft/proc/sector_boarding_refusal()
	for (var/datum/chart_token/T in chart_tokens())
		var/why = T.chart.boarding_refusal(T.x, T.y)
		if (why)
			return why
	return null

// A field has struck her.
/datum/craft/proc/hazard_struck(datum/chart_hazard/H, damage, words)
	crew_message(SPAN_DANGER("[words] and takes the way off her!"))
	if (body && damage > 0)
		body.hazard_damage(damage)

// Batters the body. The base has nothing to batter. Returns what was hit.
/datum/craft_body/proc/hazard_damage(amount)
	return null

// A built hull: one plank takes it, but is never broken through by it.
/datum/craft_body/built/hazard_damage(amount)
	var/list/planks = list()
	for (var/turf/T in cells())
		for (var/obj/covers/C in T)
			if (C.loc == T && !QDELETED(C))
				planks += C
	if (!planks.len)
		return null
	var/obj/covers/hit = pick(planks)
	var/least = max(1, round(hit.maxhealth * CHART_STRIKE_FLOOR))
	if (hit.health > least)
		hit.health = max(least, hit.health - amount)
	return hit
