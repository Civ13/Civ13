// On-paper cord plans. This module deliberately knows no live turfs or atoms.

#define CONTRAPTION_CORD_REACH 7
#define CONTRAPTION_TRIGGER_CORDS 4
#define CONTRAPTION_WINCH_REACH 2

/proc/contraption_plan_parts()
	var/static/list/parts = list(
		"L" = list("name" = "Lever", "role" = "trigger", "how" = "Throw it over or back to set its connected mechanisms."),
		"C" = list("name" = "Pull cord", "role" = "trigger", "how" = "A pull toggles a gate and rings a bell."),
		"P" = list("name" = "Pressure plate", "role" = "trigger", "how" = "A stranger or sufficiently large animal can trigger it. The setter's people are ignored."),
		"B" = list("name" = "Bell", "role" = "actuator", "how" = "Rings on a pull or on throwing a lever over, subject to its usual cooldown."),
		"W" = list("name" = "Gate winch", "role" = "actuator", "how" = "Put it within two tiles of the portcullis it works. Only the winch end takes a cord."),
		"G" = list("name" = "Portcullis", "role" = "gate", "how" = "The nearby winch moves the gate. A cord does not attach directly to the gate."),
		"S" = list("name" = "Sluice gate", "role" = "actuator", "how" = "A lever raises or lowers the boards; a single pull toggles them. This does not run a pump."),
	)
	return parts

// Read decimal grid coordinates without rounding, exponent syntax or a fallback.
/proc/contraption_plan_coordinate(value)
	if (!istext(value) || length(value) > 2)
		return null
	var/n = text2num(value)
	return isnum(n) && n >= 1 && n <= CONTRAPTION_PLAN_SIDE && "[n]" == value ? n : null

/proc/contraption_plan_cell_key(x, y)
	if (!contraption_plan_coordinate(x) || !contraption_plan_coordinate(y))
		return null
	return "[x],[y]"

/proc/contraption_plan_cell_valid(cell)
	if (!istext(cell) || length(cell) > 5)
		return FALSE
	var/list/xy = splittext(cell, ",")
	return xy.len == 2 && !!contraption_plan_cell_key(xy[1], xy[2])

/proc/contraption_plan_distance(a, b)
	var/list/A = splittext(a, ",")
	var/list/B = splittext(b, ",")
	return max(abs(text2num(A[1]) - text2num(B[1])), abs(text2num(A[2]) - text2num(B[2])))

/datum/contraption_plan
	var/name = "Contraption"
	var/list/cells = list() // "x,y" -> palette key
	var/list/cords = list() // "x,y,x,y" -> list(source, target)

/datum/contraption_plan/proc/role(cell)
	var/list/part = contraption_plan_parts()[cells[cell]]
	return part ? part["role"] : null

/datum/contraption_plan/proc/place(cell, part)
	if (!contraption_plan_cell_valid(cell) || !contraption_plan_parts()[part])
		return FALSE
	if (cells[cell] == part)
		return TRUE
	if (cells[cell])
		erase(cell)
	else if (cells.len >= CONTRAPTION_PLAN_PARTS)
		return FALSE
	cells[cell] = part
	return TRUE

/datum/contraption_plan/proc/erase(cell)
	cells -= cell
	for (var/key in cords.Copy())
		var/list/ends = cords[key]
		if (cell in ends)
			cords -= key

/datum/contraption_plan/proc/tie(source, target)
	var/key = "[source],[target]"
	if (role(source) != "trigger" || role(target) != "actuator" || cords[key] || cords.len >= CONTRAPTION_PLAN_CORDS)
		return FALSE
	cords[key] = list(source, target)
	return TRUE

/datum/contraption_plan/proc/nearby(cell, wanted)
	. = list()
	for (var/other in cells)
		if (cells[other] == wanted && contraption_plan_distance(cell, other) <= CONTRAPTION_WINCH_REACH)
			. += other

/datum/contraption_plan/proc/check_design()
	return design_report("contraption_plan", src)

/datum/design_check/contraption_plan
	kind = "contraption_plan"
	abstract_type = /datum/design_check/contraption_plan

/datum/design_check/contraption_plan/cords/check(datum/contraption_plan/D, datum/design_report/R)
	if (!D.cells.len)
		R.note("The sheet is blank. Place a trigger and an actuator to begin.")
	var/list/counts = list()
	var/list/incoming = list()
	for (var/key in D.cords)
		var/list/ends = D.cords[key]
		counts[ends[1]] = counts[ends[1]] + 1
		incoming[ends[2]] = TRUE
		if (contraption_plan_distance(ends[1], ends[2]) > CONTRAPTION_CORD_REACH)
			R.error("A cord cannot reach more than [CONTRAPTION_CORD_REACH] tiles across this level.", ends)
	for (var/cell in D.cells)
		if (counts[cell] > CONTRAPTION_TRIGGER_CORDS)
			R.error("A trigger takes at most [CONTRAPTION_TRIGGER_CORDS] cords.", list(cell))
		if (D.role(cell) == "trigger" && !counts[cell])
			R.warning("This trigger has no cord.", list(cell))
		if (D.role(cell) == "actuator" && !incoming[cell])
			R.warning("This actuator has no cord.", list(cell))
		if (D.cells[cell] == "W" && !D.nearby(cell, "G").len)
			R.warning("No portcullis is drawn within range of this winch.", list(cell))
		if (D.cells[cell] == "G" && !D.nearby(cell, "W").len)
			R.warning("No winch is drawn within range of this portcullis.", list(cell))

/datum/design_part_book/contraption_plan
	kind = "contraption_plan"

/datum/design_part_book/contraption_plan/entries()
	. = list()
	for (var/key in contraption_plan_parts())
		var/list/row = contraption_plan_parts()[key]
		.[key] = list("what" = row["name"], "use" = row["role"], "how" = row["how"])

// Forecast one action on paper. No pulses, timers, opened doors or messages to the world.
/datum/contraption_plan/proc/forecast(source, back = FALSE)
	. = list()
	if (role(source) != "trigger" || (back && cells[source] != "L"))
		return
	var/datum/design_report/R = check_design()
	var/blocked = R.blocked()
	qdel(R)
	if (blocked)
		return list("Fix the blocking findings first; the layout cannot be tied as shown.")
	for (var/key in cords)
		var/list/ends = cords[key]
		if (ends[1] != source)
			continue
		var/target = ends[2]
		switch (cells[target])
			if ("B")
				. += "Bell at [target]: [back ? "no ring on the return throw" : "rings if its cooldown permits"]."
			if ("W")
				var/list/gates = nearby(target, "G")
				if (!gates.len)
					. += "Winch at [target]: no portcullis drawn within its reach."
				else
					var/action = cells[source] != "L" ? "toggles" : (back ? "lowers" : "raises")
					. += "Winch at [target]: [action] the nearby portcullis at [jointext(gates, "; ")] if it can move."
			if ("S")
				var/action = cells[source] != "L" ? "toggles the boards" : (back ? "lowers the boards" : "raises the boards")
				. += "Sluice gate at [target]: [action]."

/datum/contraption_plan/proc/to_code()
	var/list/nodes = list()
	var/list/links = list()
	for (var/cell in cells)
		nodes += "[cell],[cells[cell]]"
	for (var/key in cords)
		links += key
	return "C13MECH/1/[replacetext(name, " ", "_")]/[jointext(nodes, ";")]/[jointext(links, ";")]"

/proc/contraption_plan_from_code(code)
	if (!istext(code) || length(code) > DESIGN_CODE_MECH_MAX)
		return null
	var/list/fields = design_code_fields(code, "MECH", DESIGN_CODE_MECH_MAX)
	if (!fields || fields.len != 3)
		return null
	var/static/regex/valid_name = regex("^\[A-Za-z0-9_\]{1,32}$")
	if (!valid_name.Find(fields[1]))
		return null
	var/datum/contraption_plan/D = new
	D.name = replacetext(fields[1], "_", " ")
	if (length(fields[2]))
		for (var/node in splittext(fields[2], ";"))
			var/list/parts = splittext(node, ",")
			var/cell = parts.len == 3 ? contraption_plan_cell_key(parts[1], parts[2]) : null
			if (!cell || D.cells[cell] || !D.place(cell, parts[3]))
				qdel(D)
				return null
	if (length(fields[3]))
		for (var/link in splittext(fields[3], ";"))
			var/list/parts = splittext(link, ",")
			var/source = parts.len == 4 ? contraption_plan_cell_key(parts[1], parts[2]) : null
			var/target = parts.len == 4 ? contraption_plan_cell_key(parts[3], parts[4]) : null
			if (!source || !target || !D.tie(source, target))
				qdel(D)
				return null
	return D

/obj/item/ship_draught/proc/contraption_plan()
	return contraption_plan_from_code(draught_code)

/obj/item/ship_draught/proc/take_contraption(datum/contraption_plan/D)
	draught_code = D.to_code()
	name = "contraption plan ([D.name])"

#undef CONTRAPTION_CORD_REACH
#undef CONTRAPTION_TRIGGER_CORDS
#undef CONTRAPTION_WINCH_REACH
