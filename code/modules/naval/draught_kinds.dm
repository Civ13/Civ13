// ============================================================
// Kinds of sheet a ship's draught can carry (docs/ship-draught.md)
// ------------------------------------------------------------
// Each kind is a design code prefix with its own datum, reader and rules: a
// ship (ship_draught.dm), a submarine (sub_draught.dm) or a land
// vehicle or plane (craft/vehicle_draught.dm), an airship (air_draught.dm), a train (1713/train_draught.dm), a railway (1713/rail_plan.dm), a space
// station (space/station_plan.dm) or a house (game/objects/house_plan.dm). A new kind of
// planner (a spaceship, a rocket, a station) is one more row here with its
// own reader, a take proc on the sheet and its own window.
//
//   "name"  what it is called in the log and in messages
//   "max"   the longest code it accepts
//   "read"  the proc that reads its code into a datum, or null
//   "take"  the sheet's proc that keeps that datum on it
//   "title" what the export pop-up calls the sheet
//   "open"  the sheet's proc that opens its designer window
//   "window" that window's id, closed when an import switches kind
//   "age"   (optional) the earliest age whose blank sheet offers this kind;
//           an import before it is refused the same way
//
// Every kind is exported and imported the same way (docs/design-codes.md):
// the sheet menu's "Export its design code" / "Import a design code", and the
// same pair of buttons in every designer window (draught_export/draught_import).
// ============================================================

// Built by a proc: the world's global initialiser is near BYOND's size limit
// for one procedure, and a call costs it far less than the nested lists.
var/global/list/draught_kinds = draught_kinds_list()

/proc/draught_kinds_list()
	return list(
		"SHIP" = list("name" = "ship", "title" = "Ship's draught", "max" = DESIGN_CODE_SHIP_MAX, "read" = /proc/ship_draught_from_code, "take" = "take", "open" = "open_designer", "window" = "ship_designer"),
		"SUB" = list("name" = "submarine", "title" = "Submarine sheet", "max" = DESIGN_CODE_SUB_MAX, "read" = /proc/sub_draught_from_code, "take" = "take_sub", "open" = "open_sub_designer", "window" = "sub_designer"),
		"CAR" = list("name" = "vehicle", "title" = "Vehicle sheet", "max" = DESIGN_CODE_CAR_MAX, "read" = /proc/vehicle_draught_from_code, "take" = "take_vehicle", "open" = "open_vehicle_designer", "window" = "vehicle_designer"),
		"AIR" = list("name" = "airship", "title" = "Airship sheet", "max" = DESIGN_CODE_AIR_MAX, "read" = /proc/air_draught_from_code, "take" = "take_air", "open" = "open_air_designer", "window" = "air_designer"),
		"WATER" = list("name" = "waterworks", "title" = "Waterworks plan", "max" = DESIGN_CODE_WATER_MAX, "read" = /proc/waterworks_plan_from_code, "take" = "take_waterworks", "open" = "open_waterworks_designer", "window" = "waterworks_designer"),
		"HOUSE" = list("name" = "house", "title" = "House plan", "max" = DESIGN_CODE_HOUSE_MAX, "read" = /proc/house_plan_from_code, "take" = "take_house", "open" = "open_house_designer", "window" = "house_designer"),
		"HARBOR" = list("name" = "harbor", "title" = "Harbor plan", "max" = 48, "read" = /proc/harbor_plan_from_code, "take" = "take_harbor", "open" = "open_harbor_designer", "window" = "harbor_designer"),
		"MECH" = list("name" = "contraption", "title" = "Contraption plan", "max" = DESIGN_CODE_MECH_MAX, "read" = /proc/contraption_plan_from_code, "take" = "take_contraption", "open" = "open_contraption_designer", "window" = "contraption_designer"),
		"RAIL" = list("name" = "railway", "title" = "Rail plan", "max" = DESIGN_CODE_RAIL_MAX, "read" = /proc/rail_plan_from_code, "take" = "take_rail", "open" = "open_rail_designer", "window" = "rail_designer"),
		"TRAIN" = list("name" = "train", "title" = "Train sheet", "max" = DESIGN_CODE_TRAIN_MAX, "read" = /proc/train_draught_from_code, "take" = "take_train", "open" = "open_train_designer", "window" = "train_designer"),
		"STATION" = list("name" = "space station", "title" = "Station plan", "max" = DESIGN_CODE_STATION_MAX, "read" = /proc/station_plan_from_code, "take" = "take_station", "open" = "open_station_designer", "window" = "station_designer", "age" = ORBIT_MIN_AGE),
	)

// The longest code any kind of sheet accepts.
/proc/draught_code_max()
	. = 0
	for (var/kind in draught_kinds)
		var/list/K = draught_kinds[kind]
		. = max(., K["max"])

// The kind row for the code on the sheet, or null.
/obj/item/ship_draught/proc/draught_kind_row()
	return draught_code ? draught_kinds[design_code_kind(draught_code)] : null

// Shows the code on the sheet ready to copy.
/obj/item/ship_draught/proc/draught_export(mob/living/human/H, plan_name)
	var/list/K = draught_kind_row()
	if (!K)
		to_chat(H, SPAN_WARNING("There is nothing drawn on the sheet to export."))
		return
	design_code_show(H, "[K["title"]]: [plan_name]", draught_code, "Import it into any ship's draught to draw the same [K["name"]].")

// Imports a pasted code onto the sheet (any kind in draught_kinds). The code
// is read by the same proc the designer window saves through, so an imported
// plan is held to exactly the rules of one drawn by hand, and its checks are
// shown the way the window shows them. Returns the kind row taken, or null.
/obj/item/ship_draught/proc/draught_import(mob/living/human/H, datum/callback/recheck = null)
	var/client/connection = H?.client
	var/expected_code = draught_code
	var/datum/admission = persistence_admission_identity
	var/typed = design_code_ask(H, name, "Paste a ship, submarine, vehicle, airship, train, railway, space station, harbor, contraption, house or waterworks design code (C13SHIP/..., C13SUB/..., C13CAR/..., C13AIR/..., C13TRAIN/..., C13STATION/..., C13RAIL/..., C13HARBOR/..., C13MECH/..., C13HOUSE/... or C13WATER/...). It replaces what is drawn on this sheet.", draught_code_max())
	if (!typed || QDELETED(src) || QDELETED(H) || !(src in H.get_contents()) || (recheck && !recheck.Invoke()))
		return null
	// The prompt can outlive the browser, a holder change or a second sheet edit.
	if (editor && (QDELETED(editor) || editor.sheet != src || !editor.can_edit(H)))
		return null
	var/kind = design_code_kind(typed)
	// The prompt can outlive the holder, connection or another edit of the sheet.
	if (kind == "HARBOR" || design_code_kind(expected_code) == "HARBOR" || design_code_kind(draught_code) == "HARBOR")
		if (!harbor_can_draw(H, src) || H.client != connection || draught_code != expected_code || persistence_admission_changed(admission))
			return null
	if (kind == "MECH" && (!connection || H.client != connection || connection.mob != H || !ship_designer_can_draw(H, src) || (H.get_active_hand() != src && H.get_inactive_hand() != src) || draught_code != expected_code || persistence_admission_changed(admission)))
		return null
	var/list/K = draught_kinds[kind]
	if (K && length(typed) > K["max"])
		K = null
	var/datum/D = K ? call(K["read"])(typed) : null
	if (!D)
		to_chat(H, SPAN_WARNING(design_code_refusal(typed, K ? kind : "SHIP")))
		return null
	if (K["age"] && (!map || map.ordinal_age < K["age"]))
		to_chat(H, SPAN_WARNING("Nobody in this age could build [design_code_kind_name(kind)]."))
		qdel(D)
		return null
	call(src, K["take"])(D)
	design_code_log(H, K["name"], name, typed)
	to_chat(H, SPAN_NOTICE("You draw the [D:name] on the sheet."))
	var/datum/design_report/R = D:check_design()
	if (R)
		var/list/lines = R.chat_lines()
		if (R.blocked())
			to_chat(H, SPAN_WARNING("As drawn it cannot be built yet:"))
		for (var/line in lines)
			to_chat(H, line)
		qdel(R)
	qdel(D)
	return K

// The Import button in a designer window: imports onto the sheet, then shows
// it in the right window (another kind's window when the code is another kind).
/obj/item/ship_draught/proc/draught_import_in_window(mob/living/human/H, from_window, datum/callback/recheck = null)
	var/list/K = draught_import(H, recheck)
	if (!K)
		return
	if (K["window"] != from_window)
		show_browse(H, null, "window=[from_window]")
	call(src, K["open"])(H)
