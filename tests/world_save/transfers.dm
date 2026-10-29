// Narrow export-topology fixture. Uses production saver and temporary savefiles.
/obj/item/transfer_paid
	var/progress = 150
	var/nutrition = 37
	var/move_on_save = FALSE
/obj/item/transfer_paid/get_saved_vars()
	return list("progress", "nutrition")
/obj/item/transfer_paid/before_save()
	if(move_on_save)
		loc = locate(8,6,1)

/obj/structure/transfer_producer
	var/obj/transfer_wrapper/origin
	var/list/paid = list()
	var/mode = "normal"
	var/dropped = FALSE
/obj/structure/transfer_producer/get_saved_vars()
	return list("name")
/obj/structure/transfer_producer/before_save_context(map_storage/exporter, datum/save_export_frame/frame)
	var/turf/T = loc
	var/datum/save_transfer/ticket = exporter.prepare_save_transfer(frame, origin, T, paid)
	if(mode == "uncommitted")
		return
	for(var/obj/item/I in paid)
		I.loc = T
	dropped = TRUE
	if(mode == "replace")
		new /turf/transfer_parent(T)
	exporter.commit_save_transfer(ticket)
	exporter.commit_save_transfer(ticket) // Repeated commit must not duplicate refs.
	if(mode == "second")
		exporter.prepare_save_transfer(frame, origin, T, paid)
/obj/transfer_wrapper
	should_save = FALSE
/turf/transfer_parent
	var/obj/structure/transfer_producer/late_producer
/turf/transfer_parent/get_saved_vars()
	if(late_producer)
		late_producer.should_save = TRUE
		return list("late_producer")
	return list("name")

/proc/check_save_transfers()
	var/turf/transfer_parent/T = new(locate(4,4,1))
	// Direct discovery and discovery through saved variables after traversal.
	for(var/late in list(FALSE, TRUE))
		var/obj/structure/transfer_producer/P = make_transfer_producer(T, 1)
		var/obj/item/transfer_paid/I = P.paid[1]
		if(late)
			P.should_save = FALSE
			T.late_producer = P
		var/savefile/F = new("transfer-[late].sav")
		F["/format_version"] << 2
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/parent_ref = map_storage.BuildVarDirectory(F, T, 1)
		var/item_ref = map_storage.saving_references["\ref[I]"]
		var/list/refs = splittext(F["[map_storage.entry_path(F,parent_ref)]/content"], "&")
		var/count = 0
		for(var/ref in refs)
			if(ref == "[item_ref]") count++
		check(P.dropped && I.loc == T && item_ref && count == 1, "Declared paid child must occur once in parent contents")
		var/list/progress = F["[map_storage.entry_path(F,item_ref)]/progress"]
		var/list/nutrition = F["[map_storage.entry_path(F,item_ref)]/nutrition"]
		check(progress["value"] == 150 && nutrition["value"] == 37, "Transfer must preserve paid scalar state")
		check(!map_storage.saving_export_frames.len && !map_storage.saving_export_stack.len, "Successful export retained active frames")
		T.late_producer = null
		del(P.origin)
		del(P)
		del(I)
		map_storage.clear_bookkeeping()
	// Every refusal is a real production exporter exception, not a false result.
	for(var/mode in list("reference-first", "limit", "duplicate", "uncommitted", "replace", "move", "second"))
		T = new /turf/transfer_parent(locate(4,4,1))
		var/obj/structure/transfer_producer/P = make_transfer_producer(T, mode == "limit" ? 13 : 1)
		var/obj/item/transfer_paid/I = P.paid[1]
		if(mode == "duplicate") P.paid += I
		if(mode == "move") I.move_on_save = TRUE
		P.mode = mode
		var/savefile/F = new("transfer-refuse-[mode].sav")
		F["/format_version"] << 2
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/refused = FALSE
		try
			map_storage.BuildVarDirectory(F, mode == "reference-first" ? P : T, 1)
		catch(var/exception/e)
			check(length("[e]"), "Transfer refusal has no diagnostic")
			refused = TRUE
		check(refused, "Transfer case [mode] must refuse export")
		if(mode in list("reference-first", "limit", "duplicate", "uncommitted"))
			check(!P.dropped && I.loc == P.origin && I.progress == 150, "Admission refusal [mode] mutated paid state")
		check(!map_storage.saving_export_frames.len && !map_storage.saving_export_stack.len, "Failed export retained active frames")
		map_storage.clear_bookkeeping()
		for(var/obj/item/J in P.paid.Copy())
			if(J) del(J)
		del(P.origin)
		del(P)
	check_chunk_transfer_publication()
	return TRUE

/proc/make_transfer_producer(turf/T, count)
	var/obj/structure/transfer_producer/P = new(T)
	P.origin = new(P)
	for(var/n = 1, n <= count, n++)
		var/obj/item/transfer_paid/I = new(P.origin)
		P.paid += I
	return P

/proc/check_transfer_failed_generation()
	var/previous_level = md5(file("map_saves/1.sav"))
	var/obj/structure/transfer_producer/P = make_transfer_producer(locate(4,4,1), 13)
	var/obj/item/transfer_paid/I = P.paid[1]
	var/datum/controller/gameticker/ticker = new
	check(!ticker.savemap(), "Over-limit transfer published a completed generation")
	check(!fexists("map_saves/save_complete.txt") && fexists("map_backups/save_complete.txt"), "Transfer failure lost completed backup or kept current marker")
	check(md5(file("map_backups/1.sav")) == previous_level, "Transfer failure changed previous completed level")
	check(!P.dropped && I.loc == P.origin && I.progress == 150, "Transfer limit failure changed paid state")
	check(!map_storage.saving_export_frames.len && !map_storage.saving_export_stack.len && !map_storage.saving_reference_pins.len, "Transfer failure retained export state")
	for(var/obj/item/J in P.paid.Copy())
		if(J) del(J)
	del(P.origin)
	del(P)
	check(map_storage.Save_World(), "Transfer failure recovery export failed")

// Inject an ordinary movement callback at the version-3 chunk checkpoint.
// This runs the production encoder and final publication checks, with no world
// save or external effects. The old version-2 direct-export cases above remain.
/map_storage/transfer_chunk_probe
	var/inject_movement = FALSE
	var/moved = FALSE
	var/datum/save_export_frame/mutation_frame
/map_storage/transfer_chunk_probe/encode_saved_contents(savefile/F, datum/save_export_frame/frame)
	if(inject_movement && frame.declared_children.len)
		mutation_frame = frame
	return ..()
/map_storage/transfer_chunk_probe/save_work_check()
	if(mutation_frame)
		var/obj/item/I = mutation_frame.declared_children[1]
		mutation_frame = null
		spawn(0)
			I.loc = locate(8,6,1)
			moved = TRUE
		sleep(world.tick_lag)
	return ..()

/proc/check_chunk_transfer_publication()
	for(var/mutate in list(FALSE, TRUE))
		var/turf/transfer_parent/T = new(locate(4,4,1))
		var/obj/structure/transfer_producer/P = make_transfer_producer(T, 1)
		var/obj/item/transfer_paid/I = P.paid[1]
		var/map_storage/transfer_chunk_probe/exporter = new
		exporter.saving_z = 1
		exporter.inject_movement = mutate
		var/savefile/F = new("transfer-chunk-[mutate].sav")
		F["/format_version"] << 3
		var/refused = FALSE
		var/parent_ref
		try
			parent_ref = exporter.BuildVarDirectory(F, T, 1)
		catch(var/exception/chunk_error)
			check(findtext("[chunk_error]", "Declared paid child changed before content publication"), "Chunk transfer failed outside publication revalidation")
			refused = TRUE
		check(refused == mutate && exporter.moved == mutate, "Chunk transfer publication did not detect late movement")
		if(!mutate)
			var/item_ref = exporter.saving_references["\ref[I]"]
			var/list/refs = exporter.saved_content_refs(F["[exporter.entry_path(F,parent_ref)]/content"], 3)
			check(refs.Find("[item_ref]") && I.loc == T && I.progress == 150, "Version-3 paid transfer lost ownership or value")
		check(!exporter.saving_export_frames.len && !exporter.saving_export_stack.len, "Chunk transfer retained active frames")
		exporter.clear_bookkeeping()
		del(P.origin)
		del(P)
		del(I)
		del(exporter)
