// ============================================================
// Rocket plans (docs/rocket-plans.md)
// ------------------------------------------------------------
// From 1969 a rocket is not one recipe: it is drawn on a ship's draught as
// one stack of pieces from the pad up, with a frame material and a number
// of strap-on boosters, and the pieces chosen decide what it can do.
//
// Decouplers split the stack into stages. Each stage burns in turn with
// everything above it still attached, so its share of the delta-v budget is
// the rocket equation: exhaust speed x ln(mass at ignition / mass at burnout).
// Boosters burn beside the first stage and drop when they are empty. A
// service module is its own last stage: it rides with the capsule.
//
// The legs (rocket_plan_legs) then spend that budget in order, and each
// later leg also needs its own hardware:
//
//   liftoff          the first stage and boosters push 1.2x the weight
//   orbit            ROCKET_DV_ORBIT; every upper stage pushes 0.3x its load
//   return           ROCKET_DV_RETURN more; a capsule, heat shield, parachutes
//   transfer         ROCKET_DV_TRANSFER more than orbit
//   landing          ROCKET_DV_LANDING more; landing legs on the top stage
//   lunar_return     ROCKET_DV_LUNAR_RETURN more; a heavy heat shield and parachutes
//
// Every number is a game unit, tuned so that the three starter missions
// (docs/rocket-plans.md) need three different rockets. The probe in
// tests/rocket_plans pins the starter builds.
//
// A plan travels as a design code (design_codes.dm):
//   C13ROCKET/1/<name>/<frame>/<boosters>/<stack, bottom first>
// The checks are design checks of kind "rocket_plan" (rocket_plan_checks.dm).
// ============================================================

#define ROCKET_PLAN_NAME_MAX 40

// The pieces a plan can stack.
//   name, what (one line), dry (t), prop (t), thrust (kN), ve (exhaust speed),
//   height (0 for a fitting, which takes no section), age (earliest ordinal age),
//   framed (dry mass scales with the frame material).
/proc/rocket_plan_pieces()
	var/static/list/table
	if (!table)
		table = list(
		"E" = list("name" = "sea-level engine", "what" = "Lifts the rocket off the pad. Put one or more at the bottom of the first stage.", "dry" = 1.5, "prop" = 0, "thrust" = 1100, "ve" = 2.9, "height" = 1, "age" = 7),
		"V" = list("name" = "vacuum engine", "what" = "Efficient but weak; it cannot lift off. Use it at the bottom of an upper stage.", "dry" = 1.0, "prop" = 0, "thrust" = 250, "ve" = 3.9, "height" = 1, "age" = 7),
		"T" = list("name" = "propellant tank", "what" = "Holds 15 tonnes of propellant for the engines of its stage. Its frame sets how much it weighs.", "dry" = 2.0, "prop" = 15, "thrust" = 0, "ve" = 0, "height" = 1, "age" = 7, "framed" = TRUE),
		"D" = list("name" = "decoupler", "what" = "Ends a stage: everything below it drops away when that stage is empty.", "dry" = 0.5, "prop" = 0, "thrust" = 0, "ve" = 0, "height" = 1, "age" = 7, "framed" = TRUE),
		"M" = list("name" = "service module", "what" = "A small retro engine, its own propellant and power. It rides with the capsule and burns last, for the trip home or the last push.", "dry" = 1.2, "prop" = 2.5, "thrust" = 60, "ve" = 3.0, "height" = 1, "age" = 7),
		"C" = list("name" = "crew capsule", "what" = "Three seats. It needs a heat shield under it and parachutes over it to come home.", "dry" = 2.6, "prop" = 0, "thrust" = 0, "ve" = 0, "height" = 1, "age" = 7),
		"K" = list("name" = "cargo bay", "what" = "Carries up to [ROCKET_BAY_ITEMS] hold items, planned at a full [ROCKET_BAY_TONNES] tonnes.", "dry" = 1.0, "prop" = 0, "thrust" = 0, "ve" = 0, "height" = 1, "age" = 7),
		"Q" = list("name" = "probe bus", "what" = "An uncrewed probe with cameras and a radio. Flown to the Moon it maps it for your mission console.", "dry" = 0.6, "prop" = 0, "thrust" = 0, "ve" = 0, "height" = 1, "age" = 7),
		"X" = list("name" = "heat shield", "what" = "A fitting directly under the capsule. It survives a return from orbit, not from the Moon.", "dry" = 0.5, "prop" = 0, "thrust" = 0, "ve" = 0, "height" = 0, "age" = 7),
		"Y" = list("name" = "heavy heat shield", "what" = "A fitting directly under the capsule, thick enough for a return from the Moon.", "dry" = 0.9, "prop" = 0, "thrust" = 0, "ve" = 0, "height" = 0, "age" = 7),
		"R" = list("name" = "parachutes", "what" = "A fitting directly over the capsule. Alone they set it down in water near where the crew come home.", "dry" = 0.3, "prop" = 0, "thrust" = 0, "ve" = 0, "height" = 0, "age" = 7),
		"L" = list("name" = "landing rockets", "what" = "A fitting directly under the heat shield. They set the capsule down softly on dry ground.", "dry" = 0.4, "prop" = 0, "thrust" = 0, "ve" = 0, "height" = 0, "age" = 7),
		"G" = list("name" = "landing legs", "what" = "A fitting at the bottom of the top stage, for whatever lands on the Moon.", "dry" = 0.6, "prop" = 0, "thrust" = 0, "ve" = 0, "height" = 0, "age" = 7),
		)
	return table

// Frame materials: key = list(name, dry mass factor for framed pieces, earliest age).
/proc/rocket_plan_frames()
	var/static/list/table
	if (!table)
		table = list(
		"s" = list("name" = "steel", "factor" = 1.0, "age" = 7),
		"a" = list("name" = "aluminium", "factor" = 0.6, "age" = 7),
		)
	return table

// The legs, in the order a mission flies them: id = list(name, delta-v it
// costs on top of the leg it follows, the leg it follows).
/proc/rocket_plan_leg_table()
	var/static/list/table
	if (!table)
		table = list(
		ROCKET_LEG_LIFTOFF = list("name" = "Liftoff", "dv" = 0, "after" = null),
		ROCKET_LEG_ORBIT = list("name" = "Reach orbit", "dv" = ROCKET_DV_ORBIT, "after" = ROCKET_LEG_LIFTOFF),
		ROCKET_LEG_RETURN = list("name" = "Come home from orbit", "dv" = ROCKET_DV_RETURN, "after" = ROCKET_LEG_ORBIT),
		ROCKET_LEG_TRANSFER = list("name" = "Lunar transfer", "dv" = ROCKET_DV_TRANSFER, "after" = ROCKET_LEG_ORBIT),
		ROCKET_LEG_LANDING = list("name" = "Land on the Moon", "dv" = ROCKET_DV_LANDING, "after" = ROCKET_LEG_TRANSFER),
		ROCKET_LEG_LUNAR_RETURN = list("name" = "Come home from the Moon", "dv" = ROCKET_DV_LUNAR_RETURN, "after" = ROCKET_LEG_LANDING),
		)
	return table

// Total delta-v a leg needs from the pad.
/proc/rocket_leg_total_dv(id)
	var/list/legs = rocket_plan_leg_table()
	. = 0
	while (id)
		var/list/L = legs[id]
		if (!L)
			return
		. += L["dv"]
		id = L["after"]

/proc/rocket_dv_text(n)
	return num2text(round(n, 0.1))

/datum/rocket_plan
	var/name = "rocket"
	var/frame = "a"
	var/boosters = 0
	// Piece keys, from the pad up.
	var/list/stack = list()

/datum/rocket_plan/proc/frame_name()
	var/list/F = rocket_plan_frames()[frame]
	return F ? F["name"] : "unknown"

/datum/rocket_plan/proc/piece_dry(key)
	var/list/P = rocket_plan_pieces()[key]
	if (!P)
		return 0
	. = P["dry"]
	if (P["framed"])
		var/list/F = rocket_plan_frames()[frame]
		. *= F ? F["factor"] : 1

// Sections: pieces that take height in the stack.
/datum/rocket_plan/proc/section_count()
	. = 0
	for (var/key in stack)
		var/list/P = rocket_plan_pieces()[key]
		if (P && P["height"])
			.++

/datum/rocket_plan/proc/count(key)
	. = 0
	for (var/k in stack)
		if (k == key)
			.++

// Positions (1 = the bottom) of every piece key in the stack.
/datum/rocket_plan/proc/positions(key)
	. = list()
	for (var/i = 1, i <= stack.len, i++)
		if (stack[i] == key)
			. += "[i]"

// The stack split at its decouplers, bottom first: each segment is a list of
// positions. A decoupler belongs to the segment below it (it drops with it).
/datum/rocket_plan/proc/segments()
	. = list()
	var/list/current = list()
	for (var/i = 1, i <= stack.len, i++)
		current += i
		if (stack[i] == "D")
			. += list(current)
			current = list()
	if (current.len)
		. += list(current)

// The top segment: whatever is left above the last decoupler.
/datum/rocket_plan/proc/top_segment()
	var/list/S = segments()
	return S.len ? S[S.len] : list()

// From ROCKET_FLYBACK_AGE, landing legs on the first stage fly it back to
// the stand after staging (rocket_reuse.dm).
/datum/rocket_plan/proc/first_stage_recovers()
	if (!map || map.ordinal_age < ROCKET_FLYBACK_AGE)
		return FALSE
	var/list/segs = segments()
	if (segs.len < 2)
		return FALSE
	for (var/i in segs[1])
		if (stack[i] == "G")
			return TRUE
	return FALSE

/datum/rocket_plan/proc/seats()
	return count("C") * 3

// Planned cargo: every bay full, unless cargo_t says what is loaded.
/datum/rocket_plan/proc/cargo_mass(cargo_t = null)
	if (isnum(cargo_t))
		return max(0, cargo_t)
	return count("K") * ROCKET_BAY_TONNES

// The mass of the pieces at positions, with their propellant and the cargo
// and crew they carry.
/datum/rocket_plan/proc/mass_of(list/at, cargo_t = null, with_propellant = TRUE)
	. = 0
	var/bays = count("K")
	var/cargo = cargo_mass(cargo_t)
	for (var/i in at)
		var/key = stack[i]
		var/list/P = rocket_plan_pieces()[key]
		if (!P)
			continue
		. += piece_dry(key)
		if (with_propellant)
			. += P["prop"]
		if (key == "K" && bays)
			. += cargo / bays
		if (key == "C")
			. += 3 * ROCKET_CREW_MASS

/datum/rocket_plan/proc/booster_mass()
	return boosters * (ROCKET_BOOSTER_DRY + ROCKET_BOOSTER_PROPELLANT)

/datum/rocket_plan/proc/total_mass(cargo_t = null)
	var/list/all = list()
	for (var/i = 1, i <= stack.len, i++)
		all += i
	return mass_of(all, cargo_t) + booster_mass()

// Propellant to load, in tonnes (boosters come filled).
/datum/rocket_plan/proc/propellant_tonnes()
	. = 0
	for (var/key in stack)
		var/list/P = rocket_plan_pieces()[key]
		if (P)
			. += P["prop"]

/datum/rocket_plan/proc/propellant_units()
	return round(propellant_tonnes() * ROCKET_UNITS_PER_TONNE)

// The burns, in order: list of list("name", "dv", "twr", "thrust", "m0",
// "m1", "pieces"). A segment with no engine is no burn: its mass rides on.
// The service module burns last, from whatever stays with it.
/datum/rocket_plan/proc/burns(cargo_t = null)
	. = list()
	var/list/segs = segments()
	var/list/service = positions("M")
	var/n = 0
	for (var/s = 1, s <= segs.len, s++)
		var/list/seg = segs[s]
		var/list/above = list()
		for (var/t = s + 1, t <= segs.len, t++)
			above += segs[t]
		var/thrust = 0
		var/liftoff_thrust = 0
		var/flow = 0 // thrust / ve, so a mixed cluster averages properly
		var/prop = 0
		for (var/i in seg)
			var/key = stack[i]
			if (key == "M")
				continue
			var/list/P = rocket_plan_pieces()[key]
			if (P["thrust"])
				thrust += P["thrust"]
				flow += P["thrust"] / P["ve"]
				if (key == "E")
					liftoff_thrust += P["thrust"]
			prop += P["prop"]
		if (!thrust || !prop)
			continue
		// A first stage that flies back keeps a share of its propellant to land.
		if (s == 1 && first_stage_recovers())
			prop *= 1 - ROCKET_FLYBACK_RESERVE
		n++
		var/ve = thrust / flow
		// The service module's own propellant rides; it is not burnt here.
		var/m0 = mass_of(seg, cargo_t) + mass_of(above, cargo_t)
		var/stage_name = n == 1 ? "First stage" : (n == 2 ? "Second stage" : (n == 3 ? "Third stage" : "Stage [n]"))
		if (s == 1 && boosters > 0)
			var/bthrust = boosters * ROCKET_BOOSTER_THRUST
			var/bflow = bthrust / ROCKET_BOOSTER_VE
			var/bprop = boosters * ROCKET_BOOSTER_PROPELLANT
			var/m0b = m0 + booster_mass()
			// While the boosters burn, the core burns at its own rate.
			var/core_burn = min(prop, bprop * flow / bflow)
			var/mixed_ve = (thrust + bthrust) / (flow + bflow)
			var/m1b = m0b - bprop - core_burn
			var/dv1 = mixed_ve * log(m0b / m1b)
			var/m2 = m1b - boosters * ROCKET_BOOSTER_DRY
			var/m3 = m2 - (prop - core_burn)
			var/dv2 = m3 > 0 && m2 > m3 ? ve * log(m2 / m3) : 0
			. += list(list("name" = "[stage_name] with [boosters] booster\s", "dv" = dv1 + dv2, "twr" = (liftoff_thrust + bthrust) / (m0b * ROCKET_G), "thrust" = thrust + bthrust, "m0" = m0b, "m1" = m3, "first" = TRUE))
			continue
		var/m1 = m0 - prop
		. += list(list("name" = stage_name, "dv" = ve * log(m0 / m1), "twr" = (s == 1 ? liftoff_thrust : thrust) / (m0 * ROCKET_G), "thrust" = thrust, "m0" = m0, "m1" = m1, "first" = s == 1))
	if (service.len)
		// Whatever is still attached when the service module burns: the top segment.
		var/list/SM = rocket_plan_pieces()["M"]
		var/list/top = top_segment()
		var/m0 = mass_of(top, cargo_t)
		for (var/i in top)
			var/list/P = rocket_plan_pieces()[stack[i]]
			if (stack[i] != "M")
				m0 -= P["prop"] // spent by its stage, if the top segment burnt
		var/thrust = SM["thrust"] * service.len
		var/m1 = m0 - SM["prop"] * service.len
		if (m1 > 0)
			. += list(list("name" = "Service module", "dv" = SM["ve"] * log(m0 / m1), "twr" = thrust / (m0 * ROCKET_G), "thrust" = thrust, "m0" = m0, "m1" = m1, "first" = FALSE, "service" = TRUE))

/datum/rocket_plan/proc/total_dv(cargo_t = null)
	. = 0
	for (var/list/B in burns(cargo_t))
		. += B["dv"]

// The legs as list(id = list("name", "ok", "need", "have", "why")). why is
// what is missing, or "" when the leg is supported.
/datum/rocket_plan/proc/legs(cargo_t = null)
	. = list()
	var/list/table = rocket_plan_leg_table()
	var/list/burns = burns(cargo_t)
	var/dv = 0
	var/list/first = null
	var/list/weak = list()
	for (var/list/B in burns)
		dv += B["dv"]
		if (B["first"])
			first = B
		else if (!B["service"] && B["twr"] < ROCKET_UPPER_TWR)
			weak += B["name"]
	var/list/top = top_segment()
	var/has_capsule = count("C") > 0
	for (var/id in table)
		var/list/L = table[id]
		var/need = rocket_leg_total_dv(id)
		var/list/missing = list()
		var/after = L["after"]
		var/list/before = after ? .[after] : null
		if (before && !before["ok"])
			missing += "it must first manage \"[lowertext(before["name"])]\""
		switch (id)
			if (ROCKET_LEG_LIFTOFF)
				if (!first)
					missing += "the bottom stage needs a sea-level engine and a tank"
				else if (first["twr"] < ROCKET_LIFTOFF_TWR)
					missing += "it pushes only [rocket_dv_text(first["twr"])]x its weight at liftoff and needs [ROCKET_LIFTOFF_TWR]x: add sea-level engines or boosters, or make it lighter"
			if (ROCKET_LEG_ORBIT)
				if (weak.len)
					missing += "[english_list(weak)] push[weak.len == 1 ? "es" : ""] under [ROCKET_UPPER_TWR]x what [weak.len == 1 ? "it carries" : "they carry"]: add an engine to [weak.len == 1 ? "it" : "them"]"
			if (ROCKET_LEG_RETURN)
				if (!has_capsule)
					missing += "nobody comes home without a crew capsule"
				else
					if (!rocket_plan_shield_ok(src, FALSE))
						missing += "a heat shield directly under the capsule"
					if (!rocket_plan_chutes_ok(src))
						missing += "parachutes directly over the capsule"
			if (ROCKET_LEG_LANDING)
				var/legs_found = FALSE
				for (var/i in top)
					if (stack[i] == "G")
						legs_found = TRUE
				if (!legs_found)
					missing += "landing legs on the top stage"
			if (ROCKET_LEG_LUNAR_RETURN)
				if (!has_capsule)
					missing += "nobody comes home without a crew capsule"
				else
					if (!rocket_plan_shield_ok(src, TRUE))
						missing += "a heavy heat shield directly under the capsule"
					if (!rocket_plan_chutes_ok(src))
						missing += "parachutes directly over the capsule"
		if (need > 0 && dv < need)
			missing += "[rocket_dv_text(need - dv)] more delta-v ([rocket_dv_text(dv)] of [rocket_dv_text(need)])"
		.[id] = list("name" = L["name"], "ok" = !missing.len, "need" = need, "have" = dv, "why" = missing.len ? jointext(missing, "; ") : "")

/datum/rocket_plan/proc/supports(id, cargo_t = null)
	var/list/L = legs(cargo_t)[id]
	return L && L["ok"]

// One line per leg, for chat and the planner.
/datum/rocket_plan/proc/planner_lines(cargo_t = null)
	. = list()
	var/list/L = legs(cargo_t)
	for (var/id in L)
		var/list/leg = L[id]
		if (leg["ok"])
			. += "<span class='notice'>[leg["name"]]: yes[leg["need"] ? " ([rocket_dv_text(leg["have"] - leg["need"])] delta-v to spare)" : ""].</span>"
		else
			. += "<span class='warning'>[leg["name"]]: no - [leg["why"]].</span>"

// A hint for the first leg past orbit that is missing.
/datum/rocket_plan/proc/next_leg_hint(cargo_t = null)
	var/list/L = legs(cargo_t)
	var/list/orbit = L[ROCKET_LEG_ORBIT]
	var/list/transfer = L[ROCKET_LEG_TRANSFER]
	if (!orbit["ok"])
		return "Add a tank to an upper stage, a lighter frame, boosters or fewer payload pieces to reach orbit."
	if (!transfer["ok"])
		return "An upper stage turns an orbital rocket into a lunar one: add a third stage or more tanks above the first decoupler."
	return null

/datum/rocket_plan/proc/costs()
	. = list("steel" = 0, "aluminium" = 0, "copper" = 0, "electronics" = 0)
	var/framed = frame == "a" ? "aluminium" : "steel"
	for (var/key in stack)
		var/list/C = rocket_plan_piece_costs(key)
		for (var/material in C)
			var/to_material = material == "frame" ? framed : material
			.[to_material] += C[material]
	.["steel"] += boosters * 15
	for (var/material in .)
		if (!.[material])
			. -= material

/datum/rocket_plan/proc/costs_text()
	var/list/C = costs()
	var/list/parts = list()
	for (var/material in C)
		parts += "[C[material]] [material]"
	return english_list(parts)

/datum/rocket_plan/proc/problems()
	return design_errors("rocket_plan", src)

/datum/rocket_plan/proc/check_design()
	return design_report("rocket_plan", src)

/datum/rocket_plan/proc/summary_text()
	var/list/lines = list()
	lines += "<b>[name]</b>: a rocket of [section_count()] section\s on a [frame_name()] frame[boosters ? " with [boosters] boosters" : ""], [round(total_mass(), 0.1)] tonnes on the pad, [propellant_units()] units of propellant to load."
	lines += "Launch planner:"
	lines += planner_lines()
	var/hint = next_leg_hint()
	if (hint)
		lines += hint
	var/datum/design_report/R = check_design()
	if (R.blocked())
		lines += "<span class='warning'>Not ready to build:</span>"
	lines += R.chat_lines()
	qdel(R)
	return jointext(lines, "<br>")

// ---- Fittings ----

// The capsule has the right heat shield directly under it.
/proc/rocket_plan_shield_ok(datum/rocket_plan/D, heavy)
	for (var/at in D.positions("C"))
		var/i = text2num(at)
		if (i > 1 && (D.stack[i - 1] == "Y" || (!heavy && D.stack[i - 1] == "X")))
			return TRUE
	return FALSE

/proc/rocket_plan_chutes_ok(datum/rocket_plan/D)
	for (var/at in D.positions("C"))
		var/i = text2num(at)
		if (i < D.stack.len && D.stack[i + 1] == "R")
			return TRUE
	return FALSE

// What each piece costs at the rocket works; "frame" is steel or aluminium.
/proc/rocket_plan_piece_costs(key)
	switch (key)
		if ("E")
			return list("steel" = 30, "copper" = 10, "electronics" = 10)
		if ("V")
			return list("steel" = 20, "copper" = 10, "electronics" = 10)
		if ("T")
			return list("frame" = 20)
		if ("D")
			return list("frame" = 5, "electronics" = 2)
		if ("M")
			return list("frame" = 10, "copper" = 10, "electronics" = 15)
		if ("C")
			return list("frame" = 25, "copper" = 10, "electronics" = 20)
		if ("K")
			return list("frame" = 15)
		if ("Q")
			return list("frame" = 5, "copper" = 10, "electronics" = 20)
		if ("X", "Y")
			return list("steel" = key == "Y" ? 15 : 8)
		if ("R")
			return list("copper" = 2)
		if ("L")
			return list("steel" = 5, "electronics" = 2)
		if ("G")
			return list("frame" = 6)
	return list()

// ---- Design codes ----

/datum/rocket_plan/proc/to_code()
	return "C13ROCKET/1/[ship_draught_code_name(name)]/[frame]/[boosters]/[jointext(stack, "")]"

/proc/rocket_plan_from_code(code)
	var/list/F = design_code_fields(code, "ROCKET", DESIGN_CODE_ROCKET_MAX)
	if (!F || F.len != 4)
		return null
	var/datum/rocket_plan/D = new
	D.name = rocket_plan_clean_name(replacetext(F[1], "_", " "))
	if (!rocket_plan_frames()[F[2]])
		qdel(D)
		return null
	D.frame = F[2]
	var/b = text2num(F[3])
	if (!(b in list(0, 2, 4, 6)) || "[b]" != F[3])
		qdel(D)
		return null
	D.boosters = b
	var/text = uppertext(F[4])
	if (length(text) > ROCKET_PLAN_MAX_PIECES)
		qdel(D)
		return null
	for (var/i = 1, i <= length(text), i++)
		var/key = copytext(text, i, i + 1)
		if (!rocket_plan_pieces()[key])
			qdel(D)
			return null
		D.stack += key
	return D

/proc/rocket_plan_clean_name(text)
	if (!istext(text))
		return "rocket"
	text = replacetext(replacetext(replacetext(text, "/", " "), ";", " "), ",", " ")
	text = trim(sanitize(copytext(text, 1, ROCKET_PLAN_NAME_MAX + 1)))
	return length(text) ? text : "rocket"

// ---- Ready-made plans: the three starter missions (the probe checks) ----

/proc/rocket_plan_make(new_name, frame, boosters, stack_text)
	var/datum/rocket_plan/D = new
	D.name = new_name
	D.frame = frame
	D.boosters = boosters
	for (var/i = 1, i <= length(stack_text), i++)
		D.stack += copytext(stack_text, i, i + 1)
	return D

/proc/rocket_plan_examples()
	. = list()
	// Orbit and return: two stages on aluminium, capsule home on parachutes.
	. += rocket_plan_make("crew orbiter", "a", 0, "ETTTDVTXCRM")
	// Heavy orbital cargo: two cargo bays need four boosters.
	. += rocket_plan_make("cargo hauler", "a", 4, "EETTTTDVTTTKK")
	// One-way lunar probe: a third stage, with legs to land.
	. += rocket_plan_make("lunar probe", "a", 0, "EETTTDVTTDVTGQ")

// ---- The sheet ----

/obj/item/ship_draught/proc/rocket_plan()
	return draught_code ? rocket_plan_from_code(draught_code) : null

/obj/item/ship_draught/proc/rocket_plan_kind()
	return draught_code && design_code_kind(draught_code) == "ROCKET"

/obj/item/ship_draught/proc/take_rocket(datum/rocket_plan/D)
	draught_code = D ? D.to_code() : ""
	name = D ? "rocket sheet ([D.name])" : initial(name)

/obj/item/ship_draught/proc/rocket_sheet_menu(mob/living/human/H, datum/rocket_plan/D)
	var/choice = WWinput(H, D.summary_text(), name, "Cancel", list("Draw on the sheet", DRAUGHT_EXPORT_LABEL, DRAUGHT_IMPORT_LABEL, "Cancel"))
	if (choice == "Draw on the sheet")
		open_rocket_designer(H)
	else if (choice == DRAUGHT_EXPORT_LABEL)
		draught_export(H, D.name)
	else if (choice == DRAUGHT_IMPORT_LABEL)
		draught_import(H)

#undef ROCKET_PLAN_NAME_MAX
