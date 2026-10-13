// Uses the already assembled fixture car. No accounts or credits are modified.
/proc/extraction_vehicle_custody_probe(obj/structure/vehicleparts/axis/A)
	var/datum/extraction_vehicle_transfer/T = new
	equipment_assert(T.capture(A, TRUE), "custody fixture begins with issued existing cargo")
	var/obj/structure/table/carboot/boot
	for (var/obj/structure/table/carboot/B in T.parts) boot = B
	equipment_assert(boot, "custody fixture has a native boot")
	var/obj/item/weapon/storage/backpack/bag = new(get_turf(boot))
	var/obj/item/extraction_salvage/original = new(bag)
	original.health = 37
	original.extraction_found_in_raid = TRUE
	original.extraction_insurance_token = md5("vehicle custody token")
	var/datum/extraction_equipment_codec/E = new
	equipment_assert(E.encode(bag), "fixture explicitly issues initial equipment IDs")
	equipment_assert(T.capture(A, TRUE), "custody fixture captures original nested atoms")
	var/list/save_flags = list()
	for (var/list/row in T.cargo_roster)
		var/atom/movable/member = row["item"]
		member.should_save = TRUE
		save_flags[member] = member.should_save
	equipment_assert(T.current(), "issued graph still validates with independent persistence flags")
	extraction_vehicle_custody_save_flags(save_flags, "successful current preserves cargo persistence flags")
	var/list/locations = list()
	for (var/atom/movable/O in T.parts) locations[O] = O.loc
	var/atom/original_parent = original.loc
	var/obj/item/extraction_salvage/replacement = new(null)
	replacement.health = original.health
	replacement.extraction_item_id = original.extraction_item_id
	replacement.extraction_found_in_raid = original.extraction_found_in_raid
	replacement.extraction_insurance_token = original.extraction_insurance_token
	original.forceMove(locate(23,23,1))
	replacement.forceMove(bag)
	var/datum/extraction_vehicle_cargo/C = new
	var/list/equal_record = C.encode(A, T.cargo, FALSE)
	equipment_assert(equal_record && json_encode(equal_record) == json_encode(T.cargo_record), "replacement has identical encoded cargo to isolate native identity")
	equipment_assert(!T.current(), "equal-value replacement refuses captured native identity")
	equipment_assert(!T.relocate(locate(16,16,1)), "equal-value replacement refuses physical relocation")
	extraction_vehicle_custody_save_flags(save_flags, "replacement refusal preserves cargo persistence flags")
	for (var/atom/movable/O in locations)
		equipment_assert(O.loc == locations[O], "replacement refusal preserves every captured part and root location")
	equipment_assert(original.loc == locate(23,23,1) && replacement.loc == bag, "replacement refusal leaves both children where observed")
	replacement.forceMove(null)
	original.forceMove(original_parent)
	equipment_assert(T.current(), "restoring original child restores captured eligibility")
	qdel(replacement)
	A.key_service_busy = TRUE
	equipment_assert(!T.current(), "post-capture key reservation refuses validation")
	equipment_assert(!T.relocate(locate(16,16,1)), "post-capture key reservation refuses relocation")
	extraction_vehicle_custody_save_flags(save_flags, "reservation refusal preserves cargo persistence flags")
	for (var/atom/movable/O in locations)
		equipment_assert(O.loc == locations[O], "reservation refusal preserves every captured part and root location")
	A.key_service_busy = FALSE
	equipment_assert(T.current(), "released key reservation restores original eligibility")
	var/issued_id = original.extraction_item_id
	original.extraction_item_id = null
	equipment_assert(!T.current() && isnull(original.extraction_item_id), "cleared cargo ID refuses validation without minting")
	equipment_assert(!T.relocate(locate(16,16,1)) && isnull(original.extraction_item_id), "cleared cargo ID refuses relocation without minting")
	extraction_vehicle_custody_save_flags(save_flags, "missing-ID refusal preserves cargo persistence flags")
	var/datum/extraction_vehicle_transfer/validation_capture = new
	equipment_assert(!validation_capture.capture(A, TRUE) && isnull(original.extraction_item_id), "default capture refuses cleared ID without minting")
	original.extraction_item_id = issued_id
	equipment_assert(T.current(), "restored cargo ID validates original capture")
	var/obj/item/extraction_salvage/unissued = new(bag)
	equipment_assert(!T.current() && isnull(unissued.extraction_item_id), "unissued child refuses validation without minting")
	equipment_assert(!T.relocate(locate(16,16,1)) && isnull(unissued.extraction_item_id), "unissued child refuses relocation without minting")
	extraction_vehicle_custody_save_flags(save_flags, "unissued-child refusal preserves cargo persistence flags")
	equipment_assert(!validation_capture.capture(A, TRUE) && isnull(unissued.extraction_item_id), "default capture refuses unissued child without minting")
	for (var/atom/movable/O in locations)
		equipment_assert(O.loc == locations[O], "missing-ID refusal preserves every captured part and root location")
	unissued.forceMove(null)
	qdel(unissued)
	equipment_assert(T.current(), "removing unissued child restores original eligibility")
	// This would satisfy the old snapshot_installation refresh preconditions.
	var/obj/item/extraction_generator_kit/installed = new(get_turf(boot))
	installed.engine = new(get_turf(boot))
	installed.cable = new(get_turf(boot))
	installed.engine.fueltank = installed.tank()
	installed.generator_broken = FALSE
	installed.engine.broken = TRUE
	equipment_assert(isnull(C.encode(A, list(installed), FALSE)) && !installed.generator_broken && isnull(installed.extraction_item_id), "installed generator validation refuses before live state refresh or ID issuance")
	qdel(installed.engine)
	qdel(installed.cable)
	installed.engine = null
	installed.cable = null
	qdel(installed)
	equipment_assert(T.current(), "removing installed generator restores original eligibility")
	equipment_assert(T.persistence_runtime_var("cargo_roster") && T.persistence_runtime_var("parts"), "capture references are excluded from custom persistence")
	T.capture(null)
	equipment_assert(isnull(T.cargo_roster) && isnull(T.cargo_record), "capture reset releases cargo reference roster")
	qdel(bag)

/proc/extraction_vehicle_custody_save_flags(list/flags, message)
	for (var/atom/movable/member in flags)
		equipment_assert(member.should_save == flags[member], message)
