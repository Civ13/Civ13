// Opt-in full-startup, whole-world save/load. Only disposable launcher storage.
/proc/extraction_full_game_vehicle_save()
	try
		var/obj/map_metadata/original_map = map
		var/original_houses = extraction_house_markers.len
		for (var/x in 20 to 39)
			for (var/y in 20 to 39)
				var/turf/T = locate(x,y,1)
				for (var/atom/movable/O in T) qdel(O)
				T.ChangeTurf(/turf/floor, FALSE, FALSE)
		var/obj/structure/car_workshop/W = new(locate(21,21,1))
		var/obj/effects/premadevehicles/asno/piccolino/template = new(null, TRUE)
		var/obj/structure/vehicleparts/axis/A = W.assemble_layout(template, 3)
		qdel(template)
		// Let native registration-plate constructor descriptions settle.
		sleep(20)
		if (!A || !A.engine?.fueltank || !A.wheel) throw EXCEPTION("Native car construction failed")
		var/obj/structure/vehicleparts/frame/F = A.loc
		var/obj/structure/engine/internal/engine = A.engine
		F.w_front[5] = 73
		A.engine.fueltank.reagents.clear_reagents()
		engine.fueltank.reagents.add_reagent(engine.fuels[1], 17, safety = TRUE)
		var/datum/extraction_vehicle_transfer/transfer = new
		if (!transfer.capture(A)) throw EXCEPTION("Native car transfer graph unavailable")
		for (var/obj/part in transfer.parts) part.update_icon()
		var/obj/structure/table/carboot/boot
		for (var/obj/structure/table/carboot/B in transfer.parts) boot = B
		if (!boot) throw EXCEPTION("Native car boot unavailable")
		var/obj/item/weapon/storage/backpack/bag = new(get_turf(boot))
		var/obj/item/extraction_salvage/child = new(bag)
		child.health = 37
		var/datum/extraction_equipment_codec/equipment = new
		if (!equipment.set_raid_provenance(bag, TRUE)) throw EXCEPTION("Native boot provenance unavailable")
		var/datum/extraction_vehicle_codec/codec = new
		var/list/expected = codec.encode(A)
		if (!expected) throw EXCEPTION("Native car encoding failed before world save")
		var/id = A.extraction_vehicle_part_id
		var/bag_id = bag.extraction_item_id
		var/child_id = child.extraction_item_id
		text2file(json_encode(expected), "vehicle-world-save-before.json")
		// This car has no account owner. Encoding deliberately excludes account
		// vehicles from world saves, so restore fixture world ownership here.
		var/list/world_parts = transfer.parts.Copy()
		for (var/obj/part in transfer.parts)
			for (var/obj/nested in part.contents) world_parts |= nested
		for (var/obj/part in world_parts) part.should_save = TRUE
		bag.should_save = TRUE
		child.should_save = TRUE
		if (!ticker.savemap()) throw EXCEPTION("Whole-world save failed: [map_storage.last_error]")
		// Force observable differences before loading the real disk snapshot.
		F.w_front[5] = 1
		A.engine.fueltank.reagents.clear_reagents()
		child.health = 1
		if (!ticker.loadmap()) throw EXCEPTION("Whole-world load failed: [map_storage.last_error]")
		sleep(20)
		if (extraction_house_markers.len != original_houses) throw EXCEPTION("House marker registry changed from [original_houses] to [extraction_house_markers.len]")
		var/found = 0
		var/obj/structure/vehicleparts/axis/restored
		for (var/obj/structure/vehicleparts/axis/candidate in world)
			if (get_turf(candidate) && candidate.extraction_vehicle_part_id == id)
				restored = candidate
				found++
		if (found != 1 || restored == A || map != original_map) throw EXCEPTION("Vehicle identity, replacement or metadata mismatch: found=[found], same=[restored == A], metadata=[map == original_map], original_loc=[A?.loc], restored_loc=[restored?.loc]")
		var/list/actual = codec.encode(restored)
		text2file(json_encode(actual), "vehicle-world-save-after.json")
		if (!actual || json_encode(actual) != json_encode(expected)) throw EXCEPTION("Whole-world vehicle graph differs after load: [codec.last_error]")
		F = restored.loc
		if (F.w_front[5] != 73 || restored.engine.fueltank.reagents.total_volume != 17 || restored.wheels.len != 4 || restored.wheel.control:axis != restored) throw EXCEPTION("Native vehicle condition, fuel or controller links lost")
		var/bags = 0
		var/children = 0
		for (var/obj/item/I in world)
			if (!get_turf(I)) continue
			if (I.extraction_item_id == bag_id) bags++
			if (I.extraction_item_id == child_id)
				children++
				if (I.health != 37 || !I.extraction_found_in_raid || I.loc:extraction_item_id != bag_id) throw EXCEPTION("Nested boot child condition, provenance or parent lost")
		if (bags != 1 || children != 1 || persistence_save_in_progress) throw EXCEPTION("Boot cargo duplicated or persistence lock retained")
		text2file("PASS: full-game native vehicle whole-world disk save/load, exact graph, identity, fuel, damage, steering and nested boot cargo", "vehicle-world-save-result.txt")
	catch (var/exception/E)
		text2file("FAIL: [E] at [E.file]:[E.line]", "vehicle-world-save-result.txt")
		world.log << "FAIL: extraction full-game vehicle save: [E]"
