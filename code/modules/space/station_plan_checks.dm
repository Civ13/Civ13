// ============================================================
// Checks and part book for space station plans (docs/station-plans.md)
// ------------------------------------------------------------
// Design checks (craft/design_checks.dm) of kind "station_plan" judge a
// /datum/station_plan the way the launch complex office and the founding of
// the station (station_plan.dm) will: an error stops her being launched, a
// warning is something her crew will miss, a note is advice. Cells are the
// plan's "col,row".
// ============================================================

/datum/design_check/station_plan
	kind = "station_plan"
	abstract_type = /datum/design_check/station_plan

/datum/design_check/station_plan/check(datum/station_plan/D, datum/design_report/R)
	if (istype(D))
		plan_check(D, R)

/datum/design_check/station_plan/proc/plan_check(datum/station_plan/D, datum/design_report/R)
	return

// One command module: the console, the supply crate, the life support and the way home.
/datum/design_check/station_plan/command
	order = 10

/datum/design_check/station_plan/command/plan_check(datum/station_plan/D, datum/design_report/R)
	var/list/at = D.piece_cells("C")
	if (!at.len)
		R.error("She has no command module: it holds her console, life support, supply crate and the hatch home. Place one.", null, "C")
	else if (at.len > 1)
		R.error("She has [at.len] command modules; a station has one. Make the others workshops.", at.Copy(2), "C")

/datum/design_check/station_plan/size
	order = 20

/datum/design_check/station_plan/size/plan_check(datum/station_plan/D, datum/design_report/R)
	var/count = D.module_count()
	if (count > STATION_PLAN_MAX_MODULES)
		R.error("She has [count] modules; a station is launched with [STATION_PLAN_MAX_MODULES] at most. Add more in orbit with module kits.")
	var/allowance = station_plan_allowance()
	if (count > allowance)
		R.note("The starter station of this age has [allowance] modules; each module past that costs 60 more steel at the office.")

// Every module must dock to the rest, side by side.
/datum/design_check/station_plan/joined
	order = 30

/datum/design_check/station_plan/joined/plan_check(datum/station_plan/D, datum/design_report/R)
	if (!D.piece_cells("C").len)
		return
	var/list/joined = D.joined()
	var/list/loose = list()
	for (var/at in D.cells)
		if (!(at in joined))
			loose += at
	if (loose.len)
		R.error("[loose.len] module\s [loose.len == 1 ? "does" : "do"] not dock to the rest: each module must stand beside another, north, south, east or west.", loose)

// The keel airlock and the keel.
/datum/design_check/station_plan/keel
	order = 40

/datum/design_check/station_plan/keel/plan_check(datum/station_plan/D, datum/design_report/R)
	var/list/at = D.piece_cells("K")
	if (!at.len)
		R.error("She has no keel airlock: her solar power, fuel cell and reboost thruster hang on a keel of truss outside it. Place one at the end of an arm.", null, "K")
		return
	if (at.len > 1)
		R.error("She has [at.len] keel airlocks; one carries the keel. Make the others plain airlocks.", at.Copy(2), "K")
		return
	if (!D.keel_dir())
		R.error("Her keel airlock must dock to exactly one module, so its outer hatch faces open space for the keel.", at, "K")
		return
	var/list/blocked = list()
	for (var/slot in D.keel_slots())
		if (D.cells[slot])
			blocked += slot
	if (blocked.len)
		R.error("Her keel runs 12 tiles out from the keel airlock with a solar boom across it; [blocked.len] module\s [blocked.len == 1 ? "stands" : "stand"] in its way.", blocked, "K")

// At least one docking airlock, its berth left clear for rockets (Val, 2026-11-23).
/datum/design_check/station_plan/docking
	order = 45

/datum/design_check/station_plan/docking/plan_check(datum/station_plan/D, datum/design_report/R)
	var/list/at = D.piece_cells("P")
	if (!at.len)
		R.error("She has no docking airlock: rockets dock at the port on its outer hatch, and none can reach her without one. Place one at the end of an arm.", null, "P")
		return
	var/list/keel = D.keel_slots()
	var/list/taken = list()
	for (var/lock in at)
		var/berth = D.berth_slot(lock)
		if (!berth)
			R.error("A docking airlock must dock to exactly one module: the slot beyond its outer hatch is its berth, where a rocket docks, and must stay empty.", list(lock), "P")
			continue
		if (D.cells[berth])
			R.error("A rocket docks in the slot beyond this docking airlock's outer hatch; a module stands in its berth.", list(lock, berth), "P")
		else if (berth in keel)
			R.error("This docking airlock's berth lies across her keel; turn it another way.", list(lock, berth), "P")
		else if (taken[berth])
			R.error("Two docking airlocks share one berth; only one rocket fits there.", list(lock, taken[berth]), "P")
		taken[berth] = lock

// Air: the life support is in the command module, and air moves through open hatches.
/datum/design_check/station_plan/air
	order = 50

/datum/design_check/station_plan/air/plan_check(datum/station_plan/D, datum/design_report/R)
	var/list/hops = D.hops()
	var/list/far = list()
	for (var/at in hops)
		if (hops[at] > 2)
			far += at
	if (far.len)
		R.warning("[far.len] module\s [far.len == 1 ? "is" : "are"] more than two hatches from the command module's heater and scrubber; build life support there or keep the hatches open.", far)

/datum/design_check/station_plan/living
	order = 60

/datum/design_check/station_plan/living/plan_check(datum/station_plan/D, datum/design_report/R)
	if (!D.bunks())
		R.warning("She has no quarters module, so there is no bunk to sleep in. Add one.", null, "Q")
	if (!D.piece_cells("G").len)
		R.note("With no greenhouse module her crew live on what they fly up.", null, "G")
	if (!D.piece_cells("N").len)
		R.note("A node module lets her crew build decks above and below her later.", null, "N")

// ---- What each part is ----

/datum/design_part_book/station_plan
	kind = "station_plan"

/datum/design_part_book/station_plan/entries()
	return list(
		"C" = list("what" = "The command module: the station's first sealed module.", "use" = "Holds her orbit console, supply crate, workbench, heater, CO2 scrubber, radiator and the return hatch home.", "how" = "Every plan has exactly one; the launch complex office builds it with the station."),
		"Q" = list("what" = "A quarters module with two bunks.", "use" = "Where her crew sleep; a bunk can be claimed as a home bed.", "how" = "Built with the station; in orbit a habitat module kit (60 steel, Sealed Habitats) adds another."),
		"G" = list("what" = "A greenhouse module with two hydroponics trays.", "use" = "Grows food aboard, so the crew need not fly it all up.", "how" = "Built with the station; a greenhouse module kit (60 steel, Sealed Habitats) adds another."),
		"W" = list("what" = "A workshop module with a workbench.", "use" = "Room to craft and repair aboard.", "how" = "Built with the station; a workshop module kit (60 steel, Sealed Habitats) adds another."),
		"S" = list("what" = "A storage module with two crates.", "use" = "Keeps supplies, ore and spares aboard.", "how" = "Built with the station; a storage module kit (60 steel, Sealed Habitats) adds another."),
		"N" = list("what" = "A node module with a deck hatch.", "use" = "A node module kit used on its open deck hatch builds a new deck above or below.", "how" = "Built with the station; a node module kit (70 steel, Orbital Flight) adds another."),
		"A" = list("what" = "An airlock with an inner and an outer hatch.", "use" = "A way out on EVA. Pump it down before opening the outer hatch.", "how" = "Built with the station; an airlock module kit (50 steel, Sealed Habitats) adds another."),
		"K" = list("what" = "The keel airlock: the airlock the keel runs out from.", "use" = "Outside it a keel of truss carries her solar wings, fuel cell, generators and the reboost thruster, 12 tiles out with a 7-tile boom.", "how" = "Every plan has exactly one, docked to one module at the end of an arm, with the slots beyond it left empty."),
		"P" = list("what" = "A docking airlock: an airlock with a docking port on its outer hatch.", "use" = "Rockets from other worlds dock their capsule at its berth, the slot beyond the outer hatch, and the crew walk aboard. Either side can bar the port.", "how" = "Every plan needs at least one, docked to one module, with the slot beyond it left empty. A docking port (30 steel, Orbital Flight) fitted on any outer hatch adds another in orbit."),
		"x" = list("what" = "The eraser.", "use" = "Clears a slot to open space.", "how" = "Click a slot. Undo brings it back."),
	)
