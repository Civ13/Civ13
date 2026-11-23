// ============================================================
// Checks and part book for rocket plans (docs/rocket-plans.md)
// ------------------------------------------------------------
// Design checks (craft/design_checks.dm) of kind "rocket_plan" judge a
// /datum/rocket_plan the way the rocket works and the launch stand will: an
// error stops it being built, a warning is something its crew will miss, a
// note is advice. Cells are stack positions, "1" at the bottom.
//
// Every mission needs liftoff and orbit, so failing either is an error. The
// later legs (coming home, the Moon) are not errors: the launch planner says
// which a rocket supports and what it is missing.
// ============================================================

/datum/design_check/rocket_plan
	kind = "rocket_plan"
	abstract_type = /datum/design_check/rocket_plan

/datum/design_check/rocket_plan/check(datum/rocket_plan/D, datum/design_report/R)
	if (istype(D))
		plan_check(D, R)

/datum/design_check/rocket_plan/proc/plan_check(datum/rocket_plan/D, datum/design_report/R)
	return

// The stack: something to fly, within the size a launch stand takes.
/datum/design_check/rocket_plan/stack
	order = 10

/datum/design_check/rocket_plan/stack/plan_check(datum/rocket_plan/D, datum/design_report/R)
	if (!D.stack.len)
		R.error("The sheet has no rocket on it yet. Start with a sea-level engine at the bottom.", null, "E")
		return
	if (D.stack.len > ROCKET_PLAN_MAX_PIECES)
		R.error("It has [D.stack.len] pieces; a sheet holds [ROCKET_PLAN_MAX_PIECES].")
	var/sections = D.section_count()
	if (sections > ROCKET_PLAN_MAX_SECTIONS)
		R.error("It is [sections] sections tall; a launch stand takes [ROCKET_PLAN_MAX_SECTIONS] at most.")
	if (D.stack[1] != "E")
		R.error("The bottom piece must be a sea-level engine: nothing else lifts it off the pad.", list("1"), "E")
	if (!D.count("C") && !D.count("K") && !D.count("Q"))
		R.error("It carries nothing: add a crew capsule, a cargo bay or a probe bus to the top.")
	if (D.count("C") > 1)
		R.error("It has [D.count("C")] crew capsules; a rocket carries one, with three seats.", D.positions("C").Copy(2), "C")
	if (!(D.boosters in list(0, 2, 4, 6)))
		R.error("Boosters strap on in pairs, up to six.")
	if (map)
		var/list/frame = rocket_plan_frames()[D.frame]
		if (frame && map.ordinal_age < frame["age"])
			R.error("Nobody in this age can build a [frame["name"]] frame.")
		var/list/late = list()
		for (var/i = 1, i <= D.stack.len, i++)
			var/list/P = rocket_plan_pieces()[D.stack[i]]
			if (P && map.ordinal_age < P["age"])
				late += "[i]"
		if (late.len)
			R.error("[late.len] piece\s cannot be built in this age yet.", late)

// Stages: every decoupler ends a stage that burns.
/datum/design_check/rocket_plan/stages
	order = 20

/datum/design_check/rocket_plan/stages/plan_check(datum/rocket_plan/D, datum/design_report/R)
	if (!D.stack.len)
		return
	if (D.stack[D.stack.len] == "D")
		R.error("A decoupler on top drops nothing; put it between two stages.", list("[D.stack.len]"), "D")
	var/list/segs = D.segments()
	for (var/s = 1, s < segs.len, s++)
		var/list/seg = segs[s]
		var/engines = 0
		var/tanks = 0
		var/list/cells = list()
		for (var/i in seg)
			cells += "[i]"
			if (D.stack[i] == "E" || D.stack[i] == "V")
				engines++
			if (D.stack[i] == "T")
				tanks++
		if (!engines || !tanks)
			R.error("Stage [s] has [engines ? "no tank" : "no engine"]: it would drop away unburnt. Each stage below a decoupler needs an engine and a tank.", cells, engines ? "T" : "E")
	if (D.boosters && !(D.stack[1] == "E"))
		R.error("Boosters strap to a first stage with a sea-level engine.")
	// Engines sit at the bottom of their stage, under its tanks.
	for (var/list/seg in segs)
		var/seen_other = FALSE
		for (var/i in seg)
			var/key = D.stack[i]
			if (key == "E" || key == "V")
				if (seen_other)
					R.error("An engine must sit at the bottom of its stage, under its tanks.", list("[i]"), key)
					break
			else if (key != "G")
				seen_other = TRUE

// Payload and fittings sit where they work.
/datum/design_check/rocket_plan/payload
	order = 30

/datum/design_check/rocket_plan/payload/plan_check(datum/rocket_plan/D, datum/design_report/R)
	if (!D.stack.len)
		return
	var/list/top = D.top_segment()
	var/list/first = D.first_stage_recovers() ? D.segments()[1] : list()
	for (var/i = 1, i <= D.stack.len, i++)
		var/key = D.stack[i]
		var/list/P = rocket_plan_pieces()[key]
		switch (key)
			if ("G")
				if (!(i in top) && !(i in first))
					R.error("Landing legs belong on the top stage, for whatever lands on the Moon[map && map.ordinal_age >= ROCKET_FLYBACK_AGE ? ", or on the first stage to fly it back to the stand" : ""].", list("[i]"), key)
			if ("C", "K", "Q", "M")
				if (!(i in top))
					R.error("The [P["name"]] must ride above the last decoupler: anything below it drops away on the way up.", list("[i]"), key)
			if ("X", "Y")
				if (i == D.stack.len || D.stack[i + 1] != "C")
					R.error("A [P["name"]] fits directly under the crew capsule.", list("[i]"), key)
			if ("R")
				if (i == 1 || D.stack[i - 1] != "C")
					R.error("Parachutes fit directly over the crew capsule.", list("[i]"), key)
			if ("L")
				if (i == D.stack.len || !(D.stack[i + 1] in list("X", "Y")))
					R.error("Landing rockets fit directly under the capsule's heat shield.", list("[i]"), key)

// Liftoff and orbit: every mission needs both.
/datum/design_check/rocket_plan/legs
	order = 40

/datum/design_check/rocket_plan/legs/plan_check(datum/rocket_plan/D, datum/design_report/R)
	if (!D.stack.len || D.stack[1] != "E")
		return
	var/list/L = D.legs()
	var/list/liftoff = L[ROCKET_LEG_LIFTOFF]
	var/list/orbit = L[ROCKET_LEG_ORBIT]
	if (!liftoff["ok"])
		R.error("It cannot lift off: [liftoff["why"]].", null, "E")
		return
	if (!orbit["ok"])
		R.error("It cannot reach orbit: [orbit["why"]]. [D.next_leg_hint()]")
		return
	var/list/home = L[ROCKET_LEG_RETURN]
	if (D.count("C") && !home["ok"])
		R.warning("Its crew cannot come home on their own: [home["why"]]. They could only leave orbit from a station.", D.positions("C"), "C")

// ---- What each part is ----

/datum/design_part_book/rocket_plan
	kind = "rocket_plan"

/datum/design_part_book/rocket_plan/entries()
	. = list()
	var/list/pieces = rocket_plan_pieces()
	for (var/key in pieces)
		var/list/P = pieces[key]
		var/list/C = rocket_plan_piece_costs(key)
		var/list/cost = list()
		for (var/material in C)
			cost += "[C[material]] [material == "frame" ? "frame metal" : material]"
		var/stats = "[P["dry"]] t dry[P["framed"] ? " on steel, less on aluminium" : ""]"
		if (P["prop"])
			stats += ", [P["prop"]] t propellant"
		if (P["thrust"])
			stats += ", [P["thrust"]] kN thrust, exhaust speed [P["ve"]]"
		.[key] = list("what" = "The [P["name"]] ([stats]).", "use" = P["what"], "how" = "[P["height"] ? "One section of the stack" : "A fitting: it takes no section"]; the rocket works builds it for [english_list(cost)].")
	.["B"] = list("what" = "Strap-on solid boosters, in pairs up to six.", "use" = "They burn beside the first stage and drop when empty: more lift off the pad, but heavy, so they do not carry a rocket much farther.", "how" = "Set the count on the sheet; each costs 15 steel.")
	.["x"] = list("what" = "The eraser.", "use" = "Removes a piece from the stack.", "how" = "Click a piece. Undo brings it back.")
