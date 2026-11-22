// ============================================================
// Checks and part book for vehicle sheets (docs/vehicle-sheets.md)
// ------------------------------------------------------------
// Design checks (design_checks.dm) of kind "vehicle_sheet" judge a
// /datum/vehicle_draught the way the hand assembly (vehicle_assembly.dm) and
// the axis will judge the vehicle built from it: an error stops assembly or
// leaves it unable to move, a warning is a part that will be left out or a
// crew it cannot carry, a note is advice. Cells are the sheet's "col,row".
// tests/ship_draught/test_design_checks.py wants a part book entry for every
// key in the sheet's tables.
// ============================================================

/datum/design_check/vehicle_sheet
	kind = "vehicle_sheet"
	abstract_type = /datum/design_check/vehicle_sheet

/datum/design_check/vehicle_sheet/check(datum/vehicle_draught/D, datum/design_report/R)
	if (istype(D))
		sheet_check(D, R)

/datum/design_check/vehicle_sheet/proc/sheet_check(datum/vehicle_draught/D, datum/design_report/R)
	return

// Every tile of the rectangle needs a frame: the assembly only takes a full
// rectangle.
/datum/design_check/vehicle_sheet/frames
	order = 10

/datum/design_check/vehicle_sheet/frames/sheet_check(datum/vehicle_draught/D, datum/design_report/R)
	var/list/empty = list()
	for (var/key in D.cells)
		var/list/C = D.cells[key]
		if (!C[1])
			empty += key
	if (empty.len)
		R.error("Every tile of the [D.width] by [D.length] rectangle needs a frame: [empty.len] [empty.len == 1 ? "has" : "have"] none. The frames must fill a rectangle to be assembled.", empty, "s")

/datum/design_check/vehicle_sheet/engine
	order = 20

/datum/design_check/vehicle_sheet/engine/sheet_check(datum/vehicle_draught/D, datum/design_report/R)
	var/list/at = D.part_cells("E")
	if (!at.len)
		R.error("It has no engine. Stand the engine on a frame.", null, "E")
		return
	var/most = (D.plane() && D.width == 5) ? 3 : 1
	if (at.len > most)
		R.warning("It has [at.len] engines; only [most == 1 ? "one is" : "[most] are"] connected. The rest ride as dead weight.", at, "E")

/datum/design_check/vehicle_sheet/fuel
	order = 30

/datum/design_check/vehicle_sheet/fuel/sheet_check(datum/vehicle_draught/D, datum/design_report/R)
	var/list/at = D.tank_cells()
	if (!at.len)
		R.error("It has no fuel tank. Stand one on a frame; the engine draws from it.", null, "T")
		return
	if (at.len > 1 && !(D.plane() && D.width == 5))
		R.warning("It has [at.len] fuel tanks; the engine is connected to only one.", at, "T")
	var/list/E = vehicle_draught_engines[D.engine]
	if (E)
		R.note("Its [D.engine_name()] burns [english_list(E["fuels"])]. Built tanks leave empty: fill one before setting out.", at, D.engine)

/datum/design_check/vehicle_sheet/driver
	order = 40

/datum/design_check/vehicle_sheet/driver/sheet_check(datum/vehicle_draught/D, datum/design_report/R)
	var/list/at = D.part_cells("D")
	var/seat = D.plane() ? "pilot's seat" : "driver's seat"
	if (!at.len)
		R.error("It has no [seat]: nobody can [D.plane() ? "fly" : "drive"] it.", null, "D")
		return
	if (at.len > 1)
		R.warning("It has [at.len] [seat]s; only one takes the controls. The others are plain seats.", at, "D")
	if (D.plane())
		var/list/xy = splittext(at[1], ",")
		if (text2num(xy[2]) != 2)
			R.warning("The pilot's seat is not in the wing row (the second from the front), so the plane gets no cockpit around it.", list(at[1]), "D")

// The assembly fits a wheel or track only on the four corner frames.
/datum/design_check/vehicle_sheet/corners
	order = 50

/datum/design_check/vehicle_sheet/corners/sheet_check(datum/vehicle_draught/D, datum/design_report/R)
	var/list/bare = list()
	var/list/loose = list()
	var/tracks = 0
	var/wheels = 0
	for (var/row = 1, row <= D.length, row++)
		for (var/col = 1, col <= D.width, col++)
			var/list/C = D.cell(col, row)
			if (D.is_corner(col, row))
				if (!C[2])
					bare += "[col],[row]"
				else if (C[2] == "K")
					tracks++
				else
					wheels++
			else if (C[2])
				loose += "[col],[row]"
	if (bare.len)
		R.error("Each of the four corner frames needs a wheel or a track: [bare.len] [bare.len == 1 ? "has" : "have"] none.", bare, "W")
	if (loose.len)
		R.warning("[loose.len] wheel\s or track\s not on a corner frame will be left out when it is assembled.", loose, "W")
	if (tracks && wheels)
		R.note("It runs on [wheels] wheel\s and [tracks] track\s. Tracks churn grass to dirt; wheels are cheaper.", null, "K")
	if (D.plane() && tracks)
		R.warning("A plane takes off and lands on wheels: fit rubber wheels on its corners, not tracks.", null, "K")

/datum/design_check/vehicle_sheet/power
	order = 60

/datum/design_check/vehicle_sheet/power/sheet_check(datum/vehicle_draught/D, datum/design_report/R)
	if (!D.count_parts("E"))
		return
	var/empty = round(D.weight())
	var/crewed = round(D.crewed_weight())
	var/axis = round(D.axis_power())
	var/engine = round(D.engine_limit())
	var/list/at = D.part_cells("E")
	if (empty > axis)
		R.error("It weighs [empty] empty and its [vehicle_draught_axes[D.axis]["name"]] bears [axis] at most: it will not move. Take weight off[D.axis == "car" ? " or draw it on a heavy axis" : ""].", null, D.axis)
	else if (empty > engine)
		R.error("It weighs [empty] empty and a [D.cc]cc [D.engine_name()] moves [engine] at most: it will stall. Draw a bigger or stronger engine.", at, "E")
	else if (crewed > min(axis, engine))
		R.warning("Empty it moves, but with all [D.crew()] seats filled it weighs [crewed] and will stall above [min(axis, engine)]. Draw a bigger engine or fewer seats.", at, "E")

/datum/design_check/vehicle_sheet/turret
	order = 70

/datum/design_check/vehicle_sheet/turret/sheet_check(datum/vehicle_draught/D, datum/design_report/R)
	var/list/at = D.part_cells("U")
	if (!at.len)
		return
	if (D.plane())
		R.error("A plane cannot carry a tank turret.", at, "U")
		return
	for (var/key in at)
		var/list/C = D.cells[key]
		if (C[1] == "w")
			R.warning("A turret stands on a wood frame: a tank's armour starts with steel under it.", list(key), "w")
	if (!D.count_parts("L"))
		R.note("It has a turret but no loader's seat; tanks usually seat a loader beside the gunner.", at, "L")

/datum/design_check/vehicle_sheet/cargo
	order = 80

/datum/design_check/vehicle_sheet/cargo/sheet_check(datum/vehicle_draught/D, datum/design_report/R)
	var/holds = D.count_parts("H")
	if (holds)
		R.note("Its [holds] cargo hold\s carry [holds * 20] items between them; each one's load adds to its weight.", D.part_cells("H"), "H")

// ---- What each part is ----

/datum/design_part_book/vehicle_sheet
	kind = "vehicle_sheet"

/datum/design_part_book/vehicle_sheet/entries()
	return list(
		// Axes
		"car" = list("what" = "A light axis: the steering, springs and drive shafts of a car.", "use" = "Bears up to 800 weight. Enough for cars, small trucks and light carriers.", "how" = "Craft it from 10 steel. Set it on any frame of the laid-out vehicle, clip the sheet to it, then click it to see what is left and to assemble."),
		"heavy" = list("what" = "A heavy axis: the running gear of trucks and tanks.", "use" = "Bears up to 2500 weight, for armour, turrets and heavy loads.", "how" = "Craft it from 30 steel and use it like a light axis."),
		"plane" = list("what" = "Airframe controls: control runs, trim and instruments.", "use" = "The axis of a hand-built plane. It bears 800 weight (a twin's wings carry 1400, and 100 more for each section past 4 long).", "how" = "Craft it from 12 steel. Lay airframe sections 3 wide and 3 to 6 long (or 5 wide and 4 to 6 long for a twin), set the controls on one and assemble with the nose along the long side."),
		// Frames and tools
		"s" = list("what" = "A steel vehicle frame: one tile of chassis.", "use" = "Every tile of a vehicle is a frame; together they are its body and carry its parts.", "how" = "Craft it from 2 steel. Lay the frames side by side to fill the drawn rectangle exactly."),
		"w" = list("what" = "A wood vehicle frame.", "use" = "A cheaper, lighter chassis tile for carts and early cars. It burns.", "how" = "Craft it from 2 softwood and lay it like a steel frame; both mix on one vehicle."),
		"a" = list("what" = "An airframe section: light metal ribs and skin.", "use" = "A plane's body. When the plane is assembled each section becomes the nose, wing, cockpit, fuselage or tail its place calls for.", "how" = "Craft it from 4 steel and lay the sections in the drawn rectangle."),
		"x" = list("what" = "The eraser.", "use" = "Clears a tile: its frame, its wheel and its part.", "how" = "Click a tile. Undo brings it back."),
		// Running gear
		"W" = list("what" = "A rubber wheel.", "use" = "Carries the vehicle on roads and open ground. Only the four corner frames' wheels are fitted.", "how" = "Craft it from 1 steel and stand it on a corner frame before assembling."),
		"K" = list("what" = "A tank track.", "use" = "Carries heavy vehicles over rough ground, churning grass to dirt as it goes.", "how" = "Craft it from 4 steel and stand one on each corner frame."),
		// Parts
		"E" = list("what" = "The engine the sheet is drawn for, of the kind and size chosen above the plan.", "use" = "Moves the vehicle: it can move twice its power in weight.", "how" = "Make it with the engine maker from steel, choosing the same kind and at least the size drawn, and stand it on its frame."),
		"Y" = list("what" = "A small fuel tank holding 120 units.", "use" = "Feeds the engine. Light, for small cars.", "how" = "Craft it from 10 steel, stand it on a frame and fill it with the engine's fuel."),
		"M" = list("what" = "A medium fuel tank holding 180 units.", "use" = "Feeds the engine for longer trips.", "how" = "Craft it from 15 steel and stand it on a frame."),
		"T" = list("what" = "A large fuel tank holding 250 units.", "use" = "Feeds a truck's or a plane's engine on long runs.", "how" = "Craft it from 20 steel and stand it on a frame."),
		"X" = list("what" = "A huge fuel tank holding 450 units.", "use" = "Feeds a thirsty tank or truck engine for a long time.", "how" = "Craft it from 36 steel and stand it on a frame."),
		"D" = list("what" = "The driver's seat (a pilot's seat in a plane), with the wheel or column.", "use" = "Where the vehicle is driven or flown from, and where its papers are opened.", "how" = "Craft it from 8 steel and stand it on its frame facing the front. A plane's goes in the wing row, where the cockpit is made around it."),
		"G" = list("what" = "A gunner's seat.", "use" = "A crew seat. In a turret, the gunner aims and fires its gun from it.", "how" = "Craft it from 6 steel and stand it on its frame."),
		"L" = list("what" = "A loader's seat.", "use" = "Seats the crewman who loads a tank's cannon, so the gunner can keep firing.", "how" = "Craft it from 6 steel and stand it near the turret."),
		"C" = list("what" = "A commander's seat.", "use" = "Seats the commander, who keeps the vehicle's papers, or a passenger.", "how" = "Craft it from 10 steel and stand it on its frame."),
		"U" = list("what" = "A tank turret carrying a tank cannon, with its gunner's seat.", "use" = "Turns and fires the cannon all round. The gunner sits in it.", "how" = "Craft the turret (30 steel), a tank cannon (40) and a gunner's seat (6) and stand all three on the same frame before assembling."),
		"H" = list("what" = "A cargo hold: a steel box bolted to the bed.", "use" = "Carries twenty items, bulky ones too, and feeder arms can load it.", "how" = "Craft it from 8 steel, stand it on a frame and bolt it down with a wrench."),
		// Engines
		"gasoline" = list("what" = "A 4-stroke gasoline engine: 100 power per 1000 cc.", "use" = "The usual car and truck engine. Burns gasoline.", "how" = "The engine maker makes it for 50 steel per 1000 cc, from 80 to 30000 cc."),
		"twostroke" = list("what" = "A 2-stroke gasoline engine: 90 power per 1000 cc.", "use" = "A tiny, cheap engine for the lightest vehicles. Burns gasoline.", "how" = "40 steel per 1000 cc, from 49 to 1000 cc."),
		"efficient" = list("what" = "A high efficiency gasoline engine: 500 power per 1000 cc.", "use" = "Much more power for its size, at a high price in steel.", "how" = "100 steel per 1000 cc, from 100 to 30000 cc."),
		"ethanol" = list("what" = "An ethanol-gasoline engine: 86 power per 1000 cc.", "use" = "Runs on gasoline or on ethanol distilled at home.", "how" = "60 steel per 1000 cc, from 80 to 30000 cc."),
		"diesel" = list("what" = "A diesel engine: 80 power per 1000 cc.", "use" = "Thrifty and strong in big sizes: trucks and tanks. Burns diesel.", "how" = "40 steel per 1000 cc, from 300 to 45000 cc."),
		"biodiesel" = list("what" = "A biodiesel engine: 72 power per 1000 cc.", "use" = "Burns diesel or biodiesel pressed from crops.", "how" = "45 steel per 1000 cc, from 300 to 45000 cc."),
		"hesselman" = list("what" = "A Hesselman engine: 86 power per 1000 cc.", "use" = "Burns diesel, biodiesel or gasoline, whichever is to hand.", "how" = "43 steel per 1000 cc, from 200 to 55000 cc."),
		"hotbulb" = list("what" = "A hot bulb engine: 66 power per 1000 cc.", "use" = "A slow old engine that burns almost any oil or fuel.", "how" = "33 steel per 1000 cc, from 200 to 45000 cc."),
		"turbine" = list("what" = "A turbine engine: 136 power per 1000 cc.", "use" = "Great power for its weight, burning almost any fuel quickly.", "how" = "73 steel per 1000 cc, from 250 to 18000 cc."),
	)
