// ============================================================
// Checks for hand-built vehicles (docs/design-checks.md)
// ------------------------------------------------------------
// The design checks (design_checks.dm) of kind "vehicle" judge the frame
// survey an axis makes before assembly (vehicle_assembly.dm): cars, trucks,
// tanks, aircraft, boats of ship frames and submarines built by hand. The
// survey's refusal is the error. Its list of missing parts stays in its own
// report; these checks add what would make the assembled vehicle stall,
// starve or go dark. Cell keys are frame offsets "x,y" from the survey's
// south-west corner.
// ============================================================

/datum/design_check/vehicle
	kind = "vehicle"
	abstract_type = /datum/design_check/vehicle

/datum/design_check/vehicle/check(datum/vehicle_survey/S, datum/design_report/R)
	if (!istype(S))
		return
	if (S.refusal)
		if (order == 10)
			R.error("This cannot be made into a [S.ship ? "boat" : "vehicle"]: [S.refusal].")
		return
	vehicle_check(S, R)

/datum/design_check/vehicle/proc/vehicle_check(datum/vehicle_survey/S, datum/design_report/R)
	return

/datum/vehicle_survey/proc/cell_key(atom/A)
	return A ? "[A.x - min_x],[A.y - min_y]" : null

// What the vehicle will weigh, the way the axis weighs it to drive.
/datum/vehicle_survey/proc/weight()
	. = 5
	for (var/obj/structure/vehicleparts/frame/F in frames)
		. += F.total_weight()

/datum/vehicle_survey/proc/check_design()
	return design_report("vehicle", src)

/datum/design_check/vehicle/refusal
	order = 10

/datum/design_check/vehicle/power
	order = 20

/datum/design_check/vehicle/power/vehicle_check(datum/vehicle_survey/S, datum/design_report/R)
	if (S.ship || !S.engine)
		return
	var/weight = S.weight()
	var/limit = S.engine.maxpower * 2
	if (weight > limit)
		R.warning("It weighs [round(weight)] and \the [S.engine] can move [round(limit)] at most: it will stall. Fit a stronger engine or take weight off.", list(S.cell_key(S.engine)))
	else if (S.axis && weight > S.axis.maxpower)
		R.warning("It weighs [round(weight)] and its axis bears [round(S.axis.maxpower)] at most: it will stall. Take weight off.")

/datum/design_check/vehicle/fuel
	order = 30

/datum/design_check/vehicle/fuel/vehicle_check(datum/vehicle_survey/S, datum/design_report/R)
	if (!S.tank || !S.engine)
		return
	var/datum/reagents/G = S.tank.reagents
	if (!G || G.total_volume <= 0)
		R.warning("\The [S.tank] is empty: fill it before the engine will run.", list(S.cell_key(S.tank)))
		return
	var/obj/structure/engine/internal/I = S.engine
	if (!istype(I) || !I.fuels || !I.fuels.len)
		return
	for (var/fuel in I.fuels)
		if (G.has_reagent(fuel))
			return
	R.warning("\The [S.tank] holds nothing \the [S.engine] burns: it takes [english_list(I.fuels)].", list(S.cell_key(S.tank)))

/datum/design_check/vehicle/lights
	order = 40

/datum/design_check/vehicle/lights/vehicle_check(datum/vehicle_survey/S, datum/design_report/R)
	if (S.ship || istype(S.axis, /obj/structure/vehicleparts/axis/aircraft))
		return
	for (var/obj/structure/vehicleparts/frame/F in S.frames)
		if (locate(/obj/structure/lamp/lamp_small/tank) in get_turf(F))
			return
	R.note("It has no lamp: at night the driver sees no further than anyone else. Stand a vehicle lamp on a frame.")
