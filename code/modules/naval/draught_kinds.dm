// ============================================================
// Kinds of sheet a ship's draught can carry (docs/ship-draught.md)
// ------------------------------------------------------------
// Each kind is a design code prefix with its own datum, reader and rules: a
// ship (ship_draught.dm), a submarine (sub_draught.dm) or a land
// vehicle or plane (craft/vehicle_draught.dm). A new kind of
// planner (a spaceship, a rocket, a station) is one more row here with its
// own reader, a take proc on the sheet and its own window.
//
//   "name"  what it is called in the log and in messages
//   "max"   the longest code it accepts
//   "read"  the proc that reads its code into a datum, or null
//   "take"  the sheet's proc that keeps that datum on it
// ============================================================

var/global/list/draught_kinds = list(
	"SHIP" = list("name" = "ship", "max" = DESIGN_CODE_SHIP_MAX, "read" = /proc/ship_draught_from_code, "take" = "take"),
	"SUB" = list("name" = "submarine", "max" = DESIGN_CODE_SUB_MAX, "read" = /proc/sub_draught_from_code, "take" = "take_sub"),
	"CAR" = list("name" = "vehicle", "max" = DESIGN_CODE_CAR_MAX, "read" = /proc/vehicle_draught_from_code, "take" = "take_vehicle"),
)

// The longest code any kind of sheet accepts.
/proc/draught_code_max()
	. = 0
	for (var/kind in draught_kinds)
		var/list/K = draught_kinds[kind]
		. = max(., K["max"])
