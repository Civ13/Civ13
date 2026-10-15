// A paid crate owns one actual unattached native wheel, not a stock counter.
/obj/item/extraction_wheel_crate
	name = "boxed standard wheel"
	desc = "One unattached standard car wheel for private workshop assembly."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "wheel_t_dark"
	w_class = ITEM_SIZE_HUGE
	var/tmp/obj/structure/vehicleparts/movement/wheel
	New()
		..()
		wheel = new(src)
		wheel.extraction_vehicle_part_id = new_extraction_item_id()
		wheel.should_save = FALSE
		// Native configurations are shared templates; each paid wheel owns its wear.
		var/datum/extraction_vehicle_codec/C = new
		var/list/settings = C.config(get_wheel_config("standard_wheel"), "wheel")
		wheel.wconfig = new
		for (var/key in settings) wheel.wconfig.vars[key] = settings[key]
		wheel.load_config(wheel.wconfig)
	proc/snapshot_wheel()
		if (!wheel || wheel.loc != src || contents.len != 1 || wheel.type != /obj/structure/vehicleparts/movement || wheel.axis || wheel.connected || wheel.anchored || wheel.contents.len) return null
		var/datum/extraction_vehicle_codec/C = new
		var/list/record = list("id" = wheel.extraction_vehicle_part_id, "broken" = wheel.broken, "reversed" = wheel.reversed, "config" = C.config(wheel.wconfig, "wheel"))
		return extraction_wheel_record_valid(record) ? record : null
	proc/restore_wheel(list/record)
		if (!extraction_wheel_record_valid(record)) return FALSE
		wheel = new(src)
		wheel.should_save = FALSE
		wheel.extraction_vehicle_part_id = record["id"]
		wheel.wconfig = new
		for (var/key in record["config"]) wheel.wconfig.vars[key] = record["config"][key]
		wheel.load_config(wheel.wconfig)
		wheel.broken = record["broken"]
		wheel.reversed = record["reversed"]
		wheel.update_icon()
		return TRUE
	persistence_runtime_var(key)
		if (key == "wheel") return TRUE
		return ..()

/proc/extraction_wheel_record_valid(list/record)
	if (!islist(record) || record.len != 4 || !istext(record["id"]) || !length(record["id"]) || length(record["id"]) > 80 || !(record["broken"] in list(FALSE, TRUE)) || !(record["reversed"] in list(FALSE, TRUE))) return FALSE
	var/datum/extraction_vehicle_codec/C = new
	var/list/settings = record["config"]
	var/list/standard = C.config(get_wheel_config("standard_wheel"), "wheel")
	if (!islist(settings) || settings.len != standard.len) return FALSE
	for (var/key in standard)
		if (key == "current_health") continue
		if (!(key in settings) || settings[key] != standard[key]) return FALSE
	return isnum(settings["current_health"]) && settings["current_health"] >= 0 && settings["current_health"] <= standard["max_health"]
