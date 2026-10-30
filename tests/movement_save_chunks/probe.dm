// Isolated native fixture source. Preparation does not execute this world.
world
	maxx = 4
	maxy = 1
	maxz = 2
	fps = 20
	visibility = 0
	sleep_offline = FALSE
var/list/mob_list = list()
var/mob/living/simple_animal/chunk_fixture/subject
var/armed = FALSE
var/mutations = 0
/mob/living/simple_animal/chunk_fixture
	// Production cohort predicate reads these by name. Minimal shared stubs do
	// not define them; neutral nulls model an uncoupled, empty fixture animal.
	// Human-only handcuffed/legcuffed are deliberately absent, like real animals.
	var/corpse_decay_record
	var/pulling
	var/pulledby
	var/buckled
	var/npc_subtile_pulse
	var/ride
	var/rider
	var/control_object
	var/following_mob
	var/origin
	var/list/grab_list
	var/list/grabbed_by
	var/list/pinned
	var/list/friends
	var/list/payload
	New()
		..()
		mob_list += src
	Del()
		mob_list -= src
		..()
	before_save()
		if(armed && world.params["scenario"] == "yield") sleep(1)
		if(armed && world.params["scenario"] == "depth")
			var/list/deep = list()
			for(var/i = 1, i <= 70, i++) deep = list(deep)
			payload = deep
		return ..()
/mob/living/simple_animal/chunk_fixture/optional_cuff
	var/handcuffed = TRUE
var/peak_roster = 0
var/peak_nodes = 0
var/peak_edges = 0
var/peak_logical_bytes = 0
var/peak_paths = 0
var/peak_entry_pins = 0
var/peak_list_pins = 0
var/peak_capture_tick_usage = 0
/map_storage/chunk_fixture/record_save_capture_path(savefile/F, path)
	. = ..()
	if(moving_save_chunk)
		peak_nodes = max(peak_nodes, moving_save_chunk.nodes)
		peak_edges = max(peak_edges, moving_save_chunk.edges)
		peak_logical_bytes = max(peak_logical_bytes, moving_save_chunk.reserved_bytes)
		peak_paths = max(peak_paths, moving_save_chunk.paths.len)
		peak_capture_tick_usage = max(peak_capture_tick_usage, world.tick_usage - moving_save_chunk.start_usage)
/map_storage/chunk_fixture/save_work_check()
	peak_roster = max(peak_roster, moving_save_roots.len)
	peak_entry_pins = max(peak_entry_pins, saving_reference_pins.len)
	peak_list_pins = max(peak_list_pins, saving_list_pins.len)
	// Interleave only outside the synchronous capture, including every replay
	// checkpoint. This exercises movement while detached records are written.
	if(armed && !moving_save_chunk && saving_z == 1 && subject)
		var/list/record = moving_save_roots["\ref[subject]"]
		if(world.params["scenario"] in list("frontier", "frontier-delete"))
			// Wait until the visited turf frame is closed, not merely assigned an ID.
			if(!mutations && !saving_export_stack.len && saving_references["\ref[locate(1,1,1)]"])
				subject.loc = locate(1,1,1)
				mutations++
			else if(world.params["scenario"] == "frontier-delete" && record && record["ref"])
				del(subject)
		else if(record && record["ref"])
			mutations++
			if(world.params["scenario"] == "delete")
				del(subject)
			else if(world.params["scenario"] == "inventory")
				new /obj/item(subject)
			else if(world.params["scenario"] == "cross-z")
				subject.loc = locate(1,1,2)
			else if(world.params["scenario"] == "reference")
				subject.loc = locate(1,1,1) // Keep the wrong-owner omission deterministic.
			else
				subject.loc = locate(subject.x == 1 ? 4 : 1,1,1)
	return ..()
/obj/chunk_reference_holder
	map_storage_saved_vars = "name;shared;pet"
	var/mob/pet
	var/list/shared
/world/OpenPort(port)
	return ..("none")
/world/New()
	OpenPort("none")
	..()
	try
		if(world.params["scenario"] == "codec-read" || world.params["scenario"] == "codec-write")
			if(world.params["scenario"] == "codec-write") write_native_list_codec_fixture()
			else verify_native_list_codec_fixture()
			world.log << "LIST_CODEC: PASS"
			text2file("PASS", "result.txt")
			del(world)
			return
		if(world.params["scenario"] == "walking")
			if(!check_native_list_identity()) throw EXCEPTION("LIST_IDENTITY: primitive probe did not complete")
			world.log << "LIST_IDENTITY: PASS"
			write_native_list_codec_fixture()
		map_storage = new /map_storage/chunk_fixture
		map = new /obj/map_metadata(locate(1,1,1))
		var/mob/living/simple_animal/chunk_fixture/optional_cuff/cuffed = new(locate(1,1,1))
		if(map_storage.moving_save_root_supported(cuffed)) throw EXCEPTION("Present active optional cuff was admitted")
		del(cuffed)
		if(mob_list.len) throw EXCEPTION("Optional-cuff fixture left registry debris")
		subject = new(locate(4,1,1))
		if(!map_storage.moving_save_root_supported(subject)) throw EXCEPTION("Absent optional cuff fields rejected an ordinary animal")
		subject.name = "admitted animal"
		subject.payload = list("literal", "key" = 17)
		if(world.params["scenario"] == "reference")
			var/obj/chunk_reference_holder/holder = new(locate(1,1,1))
			holder.pet = subject
			holder.shared = subject.payload
		if(!map_storage.Save_World()) throw EXCEPTION("baseline save failed")
		var/old_marker = file2text("map_saves/save_complete.txt")
		armed = TRUE
		var/refused = FALSE
		try
			if(!map_storage.Save_World()) throw EXCEPTION("save returned false")
		catch(var/exception/error)
			refused = TRUE
			world.log << "REFUSED: [error]"
		armed = FALSE
		var/expect_refusal = !!(world.params["scenario"] in list("delete", "frontier-delete", "inventory", "cross-z", "yield", "depth"))
		if(refused != expect_refusal) throw EXCEPTION("unexpected acceptance/refusal")
		if(file2text("map_backups/save_complete.txt") != old_marker) throw EXCEPTION("prior completed generation changed")
		if(refused)
			if(fexists("map_saves/save_complete.txt") || persistence_save_in_progress || map_storage.moving_save_chunk || map_storage.moving_save_roots.len)
				throw EXCEPTION("failed candidate retained marker or capture ownership")
		else
			if(!mutations) throw EXCEPTION("movement injection never ran")
			var/savefile/F = new("map_saves/1.sav")
			var/owners = 0
			var/found_ref
			var/holder_ref
			for(var/x = 1, x <= world.maxx, x++)
				var/turf_ref = F["/map/1/1/[x]"]
				for(var/ref in map_storage.saved_content_refs(F["[map_storage.entry_path(F, turf_ref)]/content"], 3))
					if(F["[map_storage.entry_path(F, ref)]/name"])
						var/path = F["[map_storage.entry_path(F, ref)]/type"]
						if(path == /obj/chunk_reference_holder) holder_ref = ref
						if(path == /mob/living/simple_animal/chunk_fixture)
							owners++
							found_ref = ref
			if(owners != 1 || !found_ref) throw EXCEPTION("admitted animal missing or multiply owned")
			if(world.params["scenario"] == "reference")
				if(!holder_ref) throw EXCEPTION("Shared-list legacy owner missing")
				var/list/legacy_list = F["[map_storage.entry_path(F, holder_ref)]/shared"]
				var/list/chunk_list = F["[map_storage.entry_path(F, found_ref)]/payload"]
				if(legacy_list["kind"] != "list" || chunk_list["kind"] != "list" || legacy_list["ref"] != chunk_list["ref"])
					throw EXCEPTION("Legacy/chunk shared list alias was split")
			if(!fexists("map_saves/save_complete.txt")) throw EXCEPTION("completed marker missing")
		world.log << "CHUNK_PROFILE roster=[peak_roster] nodes=[peak_nodes] edges=[peak_edges] logical_bytes=[peak_logical_bytes] paths=[peak_paths] entry_pins=[peak_entry_pins] list_pins=[peak_list_pins] capture_tick_usage=[peak_capture_tick_usage]"
		text2file("PASS", "result.txt")
	catch(var/exception/error)
		world.log << "FAIL: [error] ([error.file]:[error.line])"
		text2file("FAIL", "result.txt")
	del(world)
