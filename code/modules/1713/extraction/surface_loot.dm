// Placement schema only. No constructor, loader or interaction issues loot.
/obj/effect/extraction_surface_source
	name = "surface loot source"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	invisibility = 101
	var/source_id = 0
	var/pool_id = ""
	var/support_kind = "floor"
	var/support_type = null
	proc/schema_valid()
		if (!isnum(source_id) || round(source_id) != source_id || source_id < 1 || source_id > 128) return FALSE
		if (!(pool_id in list("parking_fuel", "parking_wheel", "repair_parts", "canned_food", "register_cash"))) return FALSE
		if (!(support_kind in list("floor", "shelf", "table", "register"))) return FALSE
		if (support_kind == "floor") return isnull(support_type)
		return ispath(support_type, /obj/structure)
	proc/pool_enabled()
		// Enable only after durable custody and restart reconciliation acceptance.
		return FALSE
