world
	name = "Civ13 LOCAL world-save roundtrip"
	sleep_offline = FALSE
	maxx = 8
	maxy = 6
	maxz = 2
	turf = /turf/test
	visibility = 0
/turf/test
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood"
	map_storage_saved_vars = "name;dir"
/turf/test/edge
	icon_state = "plating"
/obj/item/test
	var/number = 0
	var/list/items = list("constructor default")
	var/datum/test/reference
	var/list/complex
	var/list/alias
	var/turf/destination
	var/area/current_area
	var/obj/map_metadata/metadata
	var/obj/item/test/other_z
	var/matrix/matrix_value
// Fault injection for failed-export recovery. A stale cross-level field no
// longer aborts a save, so a throwing capture hook stands in for it.
var/global/roundtrip_capture_failure = FALSE
/obj/item/test/before_save_context(map_storage/exporter, datum/save_export_frame/frame)
	if(roundtrip_capture_failure)
		throw EXCEPTION("Injected capture failure")
	return ..()
/datum/test
	var/value = 0
	var/datum/test/next
	var/obj/item/test/backlink
	var/tmp/constructor_argument_count = -1
/datum/test/New()
	constructor_argument_count = args.len
	..()
/datum/test/persistence_runtime_var(key)
	return key == "constructor_argument_count" || ..()
/proc/check(condition, message)
	if(!condition)
		throw EXCEPTION(message)
/proc/check_matrix(matrix/M, list/expected, label)
	check(istype(M, /matrix), "[label] matrix missing")
	var/list/keys = list("a", "b", "c", "d", "e", "f")
	for(var/i = 1, i <= keys.len, i++)
		if(M.vars[keys[i]] != expected[i])
			world.log << "Matrix mismatch: [label].[keys[i]] expected=[expected[i]] actual=[M.vars[keys[i]]]"
		check(M.vars[keys[i]] == expected[i], "[label] matrix coefficient [keys[i]] changed")
/proc/check_datum_constructor()
	var/savefile/F = new("constructor.sav")
	F["/format_version"] << 2
	var/datum/test/original = new
	original.value = 73
	var/ref = map_storage.BuildVarDirectory(F, original)
	map_storage.clear_bookkeeping()
	var/datum/test/restored = map_storage.Load_Entry(F, ref)
	check(restored && restored.constructor_argument_count == 0, "datum constructor received location argument")
	check(restored.value == 73, "datum constructor probe value lost")
	map_storage.clear_bookkeeping()
	qdel(original)
	qdel(restored)
/world/OpenPort(port)
	return ..("none")
/world/New()
	OpenPort("none")
	..()
	try
#ifdef ROUNDTRIP_NO_TOPOLOGY_COMPAT
		var/map_storage/initial_storage = map_storage
		map_storage = new /map_storage/roundtrip_fixture(initial_storage.game_id)
		qdel(initial_storage)
		check_roundtrip_topology_boundary()
#endif
		check_restore_wrapper()
		if(world.params["wrapper_only"])
			text2file("PASS", "result.txt")
			shutdown()
			return
		check_datum_constructor()
		check_save_transfers()
		check_save_identity_and_snapshot()
		check_value_format_2()
		if(world.params["large"])
			world.maxx = 500
			world.maxy = 500
		// Segmented (format 4) levels: tiny segments force many ID ranges,
		// cross-segment references, late content appends and list routing.
		if(world.params["low_memory"])
			map_storage.low_memory_override = TRUE
			map_storage.segment_size_override = text2num(world.params["segment"]) || 2
		// Stream-backed levels (format 5): stream_roundtrip.dme adds the module.
		if(world.params["stream"])
			check("stream_level_saves_override" in map_storage.vars, "stream fixture compiled without the stream module")
			map_storage.vars["stream_level_saves_override"] = TRUE
		map = new /obj/map_metadata(locate(1,1,1))
		var/turf/edge = new /turf/test/edge(locate(world.maxx,world.maxy,2))
		edge.name = "far corner"
		var/obj/item/test/A = new(locate(1,1,1))
		var/obj/item/test/B = new(A)
		A.number = 17
		B.number = 99
		A.items = list()
		A.reference = new /datum/test
		A.reference.value = 123
		A.reference.next = A.reference
		A.reference.backlink = A
		A.matrix_value = new /matrix(2,3,4,5,6,7)
		A.transform = new /matrix(8,9,10,11,12,13)
		A.color = "#123456"
		A.alpha = 173
		check_matrix(A.transform, list(8,9,10,11,12,13), "source transform")
		A.complex = list("literal **entry7", 7, 7, "key" = list("nested" = 42))
		A.alias = A.complex
		A.complex += list(A.complex)
		A.complex += list(null)
		A.destination = edge
		A.current_area = edge.loc
		A.metadata = map
		var/obj/item/test/C = new(edge)
		C.number = 314
		C.items = list("second level" = 271)
		var/mob/living/human/corpse = new(locate(2,1,1))
		corpse.stat = DEAD
		var/mob/living/human/living = new(locate(3,1,1))
		living.stat = UNCONSCIOUS
		// A later tile's object reaches an earlier segment's entry and list.
		var/obj/item/test/D
		if(world.params["low_memory"])
			D = new(locate(5,1,1))
			D.number = 55
			D.reference = A.reference
			D.alias = A.complex
			// An animal that steps onto an already-saved tile mid-save is
			// captured by the post-tile sweep in a later segment and appended
			// to the first segment's turf: a late write and, on load, a
			// recursive reference back into a later segment.
			var/mob/living/simple_animal/wanderer = new(locate(world.maxx,1,1))
			wanderer.name = "segment wanderer"
			spawn(0)
				for(var/wait = 1, wait <= 100000, wait++)
					var/datum/level_segment_writer/writer = map_storage.saving_segments
					if(writer && map_storage.saving_z == 1 && writer.number >= 3) break
					sleep(world.tick_lag)
				wanderer.loc = locate(1,1,1)
				mob_list += wanderer
		// Text macros do not survive a savefile's text export; the split
		// copies such a node again by value.
		if(world.params["split"] || world.params["stream"])
			var/obj/item/test/macro = new(locate(6,1,1))
			macro.name = "\improper split turkey"
			macro.number = 66
		// Values whose savefile text needs escaping or has no exact text form.
		if(world.params["stream"])
			var/obj/item/test/escaped = new(locate(7,1,1))
			escaped.name = "q\"uo\\te \[b\] \n nl \t tab \u00e9 {\"brace\"}"
			escaped.number = -0.125
			escaped.items = list("big" = 16777216, "small" = 1e-07, "inf" = 1.#INF, "file" = 'icons/turf/floors.dmi', /obj/item/test = "path key", "empty" = "", "nested" = list(list("x")))
		check(map_storage.Save_World(), "export failed")
		if(!world.params["large"]) check_round_metadata()
		check(!map_storage.saving_reference_pins.len && !map_storage.saving_list_pins.len, "save pins retained after completion")
		check(map_storage.validate_world_save(), "valid export rejected")
		var/savefile/marked = new("map_saves/1.sav")
		check(marked["/value_format"] == 2, "level file lacks the value format 2 marker")
		marked = null
		check_validation_record()
		// A full-file generation loaded in low-memory mode is split into
		// segments first, then imported one segment at a time.
		if(world.params["split"])
			var/savefile/full_level = new("map_saves/1.sav")
			check(full_level["/format_version"] == 3, "split fixture did not start from a full-file save")
			full_level = null
			map_storage.low_memory_override = TRUE
			map_storage.segment_size_override = 2
			map_storage.split_min_bytes = 0
		// Force import to allocate a different turf, rather than only rehydrate
		// the already matching type in the live fixture.
		edge.ChangeTurf(/turf/test, FALSE, FALSE)
		map_storage.ClearMap()
		check(map_storage.Load_World(), "import failed")
		corpse = locate(/mob/living/human) in locate(2,1,1)
		living = locate(/mob/living/human) in locate(3,1,1)
		check(corpse && corpse.stat == DEAD && !corpse.rejuvenate_calls, "saved dead human revived on import")
		check(living && living.stat == CONSCIOUS && living.rejuvenate_calls == 1, "living human import did not rejuvenate")
		check(istype(locate(world.maxx,world.maxy,2), /turf/test/edge), "edge turf lost")
		check(locate(world.maxx,world.maxy,2):name == "far corner", "turf name lost")
		A = locate(/obj/item/test) in locate(1,1,1)
		check(A && A.number == 17, "object lost")
		B = locate(/obj/item/test) in A
		check(B && B.number == 99, "nested contents lost")
		check(A.reference && A.reference.value == 123, "datum reference lost")
		check(A.reference.constructor_argument_count == 0, "loaded datum received location argument")
		check_matrix(A.matrix_value, list(2,3,4,5,6,7), "standalone")
		check_matrix(A.transform, list(8,9,10,11,12,13), "transform")
		check(A.color == "#123456" && A.alpha == 173, "individual appearance fields changed")
		check_hud_runtime_save()
		check_player_reclaim()
		check(A.reference.next == A.reference && A.reference.backlink == A, "datum/object cycle lost")
		check(islist(A.items) && !A.items.len, "empty list reverted to default")
		check(A.complex[1] == "literal **entry7", "literal marker string changed")
		check(A.complex[2] == 7 && A.complex[3] == 7, "duplicates lost")
		check(A.complex["key"]["nested"] == 42, "associative nested list lost")
		check(A.alias == A.complex && A.complex[A.complex.len-1] == A.complex, "list alias/cycle lost")
		check(isnull(A.complex[A.complex.len]), "null list element lost")
		check(A.destination == locate(world.maxx,world.maxy,2), "cross-level turf reference lost")
		check(A.current_area == A.destination.loc && A.metadata == map, "area or metadata identity lost")
		C = locate(/obj/item/test) in locate(world.maxx,world.maxy,2)
		check(C && C.number == 314 && C.items["second level"] == 271, "second-level objects/lists lost")
		check(map && map.loc == locate(1,1,1), "metadata deleted")
		check(!errors.len, "unexpected errors")
		if(world.params["split"])
			for(var/z = 1, z <= 2, z++)
				var/savefile/split_index = new("map_saves/[z].sav")
				check(split_index["/format_version"] == 4 && split_index["/segments/count"] > 1 && fexists("map_saves/[z].part2.sav"), "low-memory load did not split level [z]")
				check(!fexists("map_saves/[z].index.tmp"), "split index temporary retained")
			check(!map_storage.saving_segments && !map_storage.segment_reader, "segment handles retained after split load")
			var/savefile/split_rollback = new("map_rollback/1.sav")
			check(fexists("map_rollback/save_complete.txt") && split_rollback["/format_version"] == 3, "split load did not keep the full-file rollback")
			split_rollback = null
			check(map_storage.validate_world_save(), "split generation rejected")
			map_storage.ClearMap()
			check(map_storage.Load_World(), "second import of a split generation failed")
			A = locate(/obj/item/test) in locate(1,1,1)
			check(A && A.number == 17 && A.reference && A.reference.backlink == A && A.alias == A.complex, "split generation reload lost objects or identity")
			var/obj/item/test/macro_copy = locate(/obj/item/test) in locate(6,1,1)
			check(macro_copy && macro_copy.number == 66 && macro_copy.name == "\improper split turkey", "split changed a text-macro name")
			check(!errors.len, "unexpected errors after split reload")
			world.log << "PASS: low-memory load of a full-file world save"
			text2file("PASS", "result.txt")
			del(world)
			return
		if(world.params["stream"])
			check_stream_levels(A)
			return
		if(world.params["low_memory"])
			D = locate(/obj/item/test) in locate(5,1,1)
			check(D && D.number == 55 && D.reference == A.reference && D.alias == A.complex, "cross-segment entry or list identity lost")
			var/mob/living/simple_animal/swept = locate(/mob/living/simple_animal) in locate(1,1,1)
			check(swept && swept.name == "segment wanderer" && !(locate(/mob/living/simple_animal) in locate(world.maxx,1,1)), "late sweep append to an earlier segment lost")
			check(!map_storage.saving_segments && !map_storage.segment_reader, "segment handles retained after load")
			check(persistence_parse_tasklist_kib("\"dreamdaemon.exe\",\"4242\",\"Console\",\"1\",\"1,234,567 K\"" + ascii2text(13) + ascii2text(10)) == 1234567, "tasklist memory parse")
			check(persistence_parse_tasklist_kib("\"dreamdaemon.exe\",\"4242\",\"Console\",\"1\",\"1.234.567 K\"") == 1234567, "localized tasklist memory parse")
			check(isnull(persistence_parse_tasklist_kib("INFO: No tasks are running which match the specified criteria.")), "missing tasklist row accepted")
			var/savefile/index = new("map_saves/1.sav")
			check(index["/format_version"] == 4 && index["/segments/count"] > 1 && fexists("map_saves/1.part2.sav"), "low-memory save did not segment its levels")
			index = null
			check(map_storage.Save_World(), "second segmented export failed")
			check(fexists("map_backups/1.part2.sav") && fexists("map_backups/save_complete.txt"), "segmented backup incomplete")
			check(map_storage.validate_world_save(), "second segmented export rejected")
			check(!map_storage.saving_segments && !map_storage.segment_reader, "segment handles retained after save")
			check(!fexists("map_rollback/save_complete.txt"), "segmented generation copied as a full-file rollback")
			// A failed segmented capture keeps the completed backup and releases handles.
			roundtrip_capture_failure = TRUE
			var/datum/controller/gameticker/failed_segmented = new
			check(!failed_segmented.savemap(), "segmented capture failure accepted")
			check(!fexists("map_saves/save_complete.txt") && fexists("map_backups/save_complete.txt") && fexists("map_backups/1.part1.sav"), "failed segmented export lost its completed backup")
			check(!map_storage.saving_segments && !map_storage.segment_reader && !persistence_save_in_progress, "failed segmented export retained handles or lock")
			roundtrip_capture_failure = FALSE
			check(map_storage.Save_World() && map_storage.validate_world_save(), "segmented recovery export failed")
			map_storage.low_memory_override = FALSE
			check(map_storage.Save_World(), "full-file export after segmented export failed")
			check(!fexists("map_saves/1.part1.sav") && !fexists("map_saves/2.part1.sav"), "stale level segments retained")
			check(map_storage.validate_world_save(), "full-file export after segments rejected")
			// The first segmented save after a full-file one keeps that
			// generation for builds that cannot read format 4.
			map_storage.low_memory_override = TRUE
			check(map_storage.Save_World() && map_storage.validate_world_save(), "segmented export after full-file export failed")
			check(fexists("map_rollback/save_complete.txt") && fexists("map_rollback/1.sav") && !fexists("map_rollback/1.part1.sav"), "full-file rollback not kept")
			var/savefile/rollback_level = new("map_rollback/1.sav")
			check(rollback_level["/format_version"] == 3, "rollback is not a full-file generation")
			rollback_level = null
			world.log << "PASS: segmented low-memory world-save round trip"
			text2file("PASS", "result.txt")
			del(world)
			return
		// Large-map acceptance exercises the complete graph/grid round trip.
		// Fault injection and backup recovery use the focused fixture below.
		if(world.params["large"])
			world.log << "PASS: 500x500x2 world-save round trip and object/list/turf invariants"
			text2file("PASS", "result.txt")
			del(world)
			return
		check(map_storage.Save_World(), "second export failed")
		check(fexists("map_backups/save_complete.txt"), "backup completion marker missing")
		check(map_storage.validate_world_save(), "second export rejected")
		check_transfer_failed_generation()
		if(!world.params["large"])
			delete_failure_path = "map_saves/save_complete.txt"
			var/datum/controller/gameticker/deletion_failure_ticker = new
			check(!deletion_failure_ticker.savemap(), "failed marker deletion accepted")
			check(fexists("map_saves/save_complete.txt") && !persistence_save_in_progress, "failed marker deletion changed active completion or retained lock")
			delete_failure_path = null
			check(map_storage.validate_world_save(), "failed marker deletion changed original save")
			roundtrip_capture_failure = TRUE
			var/datum/controller/gameticker/failed_export_ticker = new
			check(!failed_export_ticker.savemap(), "capture failure accepted")
			check(!fexists("map_saves/save_complete.txt") && !persistence_save_in_progress, "failed export retained completion marker or lock")
			check(!map_storage.saving_reference_pins.len && !map_storage.saving_list_pins.len, "failed export retained save pins")
			check(fexists("map_backups/save_complete.txt"), "failed export lost completed backup")
			roundtrip_capture_failure = FALSE
			check(map_storage.Save_World(), "recovery export failed")
			// A stale pointer to an object on another level (an attacker log,
			// an AI target) is saved as null instead of aborting the world save.
			A.other_z = C
			check(map_storage.Save_World() && map_storage.validate_world_save(), "stale cross-level reference aborted the world save")
			check(A.other_z == C, "save cleared a live cross-level reference")
			var/savefile/stale_level = new("map_saves/1.sav")
			var/list/stale_value = stale_level["[map_storage.entry_path(stale_level, 2)]/other_z"]
			check(islist(stale_value) && stale_value["kind"] == "entry" && stale_value["ref"] == 0, "cross-level reference was not saved as null")
			stale_level = null
			A.other_z = null
			check(map_storage.Save_World(), "export after cross-level reference failed")
		var/savefile/F1 = new("map_saves/1.sav")
		F1["/maxx"] << world.maxx + 1
		check(!map_storage.validate_world_save(), "dimension mismatch accepted")
		F1["/maxx"] << world.maxx
		var/object_path = map_storage.entry_path(F1, 2)
		var/original_reference = F1["[object_path]/reference"]
		F1["[object_path]/reference"] << list("kind" = "entry", "ref" = 999999999)
		check(!map_storage.validate_world_save(), "missing object reference accepted")
		F1["[object_path]/reference"] << original_reference
		fdel("map_saves/save_complete.txt")
		check(!map_storage.validate_world_save(), "interrupted save accepted")
		text2file("test completed", "map_saves/save_complete.txt")
		var/savefile/F = new("map_saves/2.sav")
		F.cd = "/map/2/[world.maxy]"
		F["[world.maxx]"] << null
		check(!map_storage.validate_world_save(), "missing turf accepted")
		check(A && A.number == 17, "preflight modified world")
		var/datum/controller/gameticker/ticker = new
		check(!ticker.loadmap(), "ticker accepted corrupt save")
		check(A && A.number == 17 && !persistence_save_in_progress, "failed import cleared world or retained lock")
		if(!world.params["large"])
			F = null
			F1 = null
			write_legacy_fixture()
			check(ticker.loadmap(), "legacy fixture import failed")
			A = locate(/obj/item/test) in locate(1,1,1)
			check(A && A.number == 88 && A.loc == locate(1,1,1), "legacy object location/value lost")
			check(A.items && !A.items.len, "legacy empty list lost")
		world.log << "PASS: world-save round trip, edges, multilevel, nested objects, datums, empty lists, corrupt-save rejection"
		text2file("PASS", "result.txt")
	catch(var/exception/e)
		world.log << "FAIL: [e] at [e.file]:[e.line]"
		text2file("FAIL: [e]", "result.txt")
	if(!world.params["visual"])
		del(world)

/proc/write_legacy_fixture()
	for(var/z = 1, z <= world.maxz, z++)
		fdel("map_saves/[z].sav")
		var/savefile/F = new("map_saves/[z].sav")
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++)
				var/ref = (y-1)*world.maxx+x
				F["/map/[z]/[y]/[x]"] << ref
				F["/entries/[ref]/type"] << /turf/test
				F["/entries/[ref]/content"] << ""
		if(z == 1)
			var/ref = world.maxx*world.maxy+1
			F["/entries/1/content"] << "[ref]"
			F["/entries/[ref]/type"] << /obj/item/test
			F["/entries/[ref]/number"] << 88
			F["/entries/[ref]/items"] << "**emptylist"
			F["/entries/[ref]/pixloc"] << null

// Value format 2: scalar lists are one node and both value shapes decode.
/proc/check_value_format_2()
	var/savefile/F = new
	F["/format_version"] << 3
	var/list/scalars = list("a" = 1, 2, /obj/item/test, "b" = /turf/test, null, "c")
	var/list/encoded = map_storage.encode_saved_value(F, scalars)
	check(encoded["kind"] == "list" && isnull(F["/lists/[encoded["ref"]]/length"]), "scalar list was not written as one node")
	var/list/node = F["/lists/[encoded["ref"]]"]
	check(islist(node) && node["kind"] == "scalars" && node["length"] == 6, "scalar list node shape changed")
	map_storage.loaded_lists = list()
	var/list/restored = map_storage.decode_saved_value(F, encoded)
	check(restored.len == 6 && restored[1] == "a" && restored["a"] == 1 && restored[2] == 2 && restored[3] == /obj/item/test && restored["b"] == /turf/test && isnull(restored[5]) && restored[6] == "c" && isnull(restored["c"]), "scalar list round trip changed")
	check(map_storage.validate_saved_value(F, encoded, list(), list()), "scalar list rejected")
	check(map_storage.decode_saved_value(F, 5) == 5 && map_storage.decode_saved_value(F, "text") == "text" && isnull(map_storage.decode_saved_value(F, null)), "raw scalar did not decode")
	check(map_storage.decode_saved_value(F, list("kind" = "value", "value" = 9)) == 9, "format 1 scalar envelope no longer decodes")
	var/rejected = FALSE
	try
		map_storage.validate_saved_value(F, new /datum/test, list(), list())
	catch
		rejected = TRUE
	check(rejected, "raw non-scalar value accepted")
	F["/lists/77"] << list("kind" = "scalars", "length" = 2, "keys" = list("x"), "values" = list(1))
	rejected = FALSE
	try
		map_storage.validate_saved_value(F, list("kind" = "list", "ref" = 77), list(), list())
	catch
		rejected = TRUE
	check(rejected, "truncated scalar list accepted")
	map_storage.clear_bookkeeping()

// A save that passed candidate validation lets a same-build preflight skip
// the entry walk; any other build or a changed file runs the full check.
/proc/check_validation_record()
	check(!fexists("map_saves/validated.json"), "save without candidate validation wrote a validation record")
	check(map_storage.validate_world_save() && findtext(map_storage.last_validation_note, "full check") == 1, "unrecorded save skipped the full check")
	var/generation = trim(file2text("map_saves/save_complete.txt"))
	check(!map_storage.write_validation_record(generation), "validation record written without a build identity")
	map_storage.save_build_identity = "fixture-build-a"
	check(map_storage.write_validation_record(generation) && fexists("map_saves/validated.json"), "validation record not written")
	check(map_storage.validate_world_save() && findtext(map_storage.last_validation_note, "skipped") == 1, "matching validation record did not skip the entry check")
	map_storage.save_build_identity = "fixture-build-b"
	check(map_storage.validate_world_save() && map_storage.last_validation_note == "full check (saved by a different build)", "another build trusted the validation record")
	// A full preflight records its own build, so build b now skips and build a
	// runs the full check again (and records itself).
	check(map_storage.validate_world_save() && findtext(map_storage.last_validation_note, "skipped") == 1, "full preflight did not record its build")
	map_storage.save_build_identity = "fixture-build-a"
	check(map_storage.validate_world_save() && map_storage.last_validation_note == "full check (saved by a different build)", "another build trusted the preflight record")
	check(map_storage.validate_world_save() && findtext(map_storage.last_validation_note, "skipped") == 1, "second full preflight did not record its build")
	var/round_text = file2text("map_saves/round.json")
	fdel("map_saves/round.json")
	text2file("[round_text] ", "map_saves/round.json")
	check(map_storage.validate_world_save() && map_storage.last_validation_note == "full check (round.json changed since it was validated)", "changed file trusted the validation record")
	check(map_storage.write_validation_record(generation) && map_storage.validate_world_save() && findtext(map_storage.last_validation_note, "skipped") == 1, "rewritten record did not match its files")
	map_storage.clear_validation_record()
	map_storage.save_build_identity = null
	check(!fexists("map_saves/validated.json"), "validation record not removed")
	// Shard regions run region.dmb: its binary must identify the build too.
	var/list/binaries = list("identity_a.dmb", "identity_b.dmb")
	for(var/name in binaries) fdel(name)
	check(isnull(persistence_build_identity(binaries)), "build identity without any binary")
	text2file("region build", "identity_b.dmb")
	var/region_only = persistence_build_identity(binaries)
	check(istext(region_only) && findtext(region_only, "identity_b.dmb="), "second binary name gave no build identity")
	check(persistence_build_identity(binaries) == region_only, "unchanged binary changed the build identity")
	text2file("standalone build", "identity_a.dmb")
	var/both = persistence_build_identity(binaries)
	check(both != region_only, "another binary present kept the build identity")
	fdel("identity_b.dmb")
	text2file("region build, rebuilt", "identity_b.dmb")
	check(persistence_build_identity(binaries) != both, "rebuilt binary kept the build identity")
	for(var/name in binaries) fdel(name)

/proc/check_save_identity_and_snapshot()
	var/savefile/F = new
	F["/format_version"] << 2
	// A nested value keeps the per-edge encoder, which yields; all-scalar lists
	// are written as one node without yielding (value format 2).
	var/list/live = list("first", "second" = list())
	mutate_on_tick = live
	var/encoded = map_storage.encode_saved_value(F, live)
	var/list/restored = map_storage.decode_saved_value(F, encoded)
	check(!live.len && restored.len == 2 && restored[1] == "first" && restored[2] == "second", "list changed while encoder yielded")
	map_storage.clear_bookkeeping()
	var/datum/test/original = new
	var/old_id = map_storage.BuildVarDirectory(F, original)
	qdel(original)
	var/datum/test/replacement = new
	// Simulate reuse of an old raw ref slot without depending on allocator timing.
	map_storage.saving_references["\ref[replacement]"] = old_id
	var/new_id = map_storage.BuildVarDirectory(F, replacement)
	check(new_id != old_id && map_storage.saving_reference_pins[new_id] == replacement, "reused ref assigned an old save identity")
	map_storage.clear_bookkeeping()
	check(!map_storage.saving_reference_pins.len && !map_storage.saving_list_pins.len, "save pins retained after cleanup")
	qdel(replacement)

/proc/check_hud_runtime_save()
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/savefile/F = new("hud-runtime.sav")
	F["/format_version"] << 2
	var/mob/living/human/H = new(locate(1,1,1))
	H.name = "durable human"
	H.stat = DEAD
	var/obj/item/test/I = new(H)
	I.number = 731
	var/obj/screen/S = new
	var/datum/hud/U = new
	H.hud_used = U
	H.HUDneed = list("throw" = S)
	H.HUDinventory = list(S)
	H.HUDfrippery = list(S)
	H.HUDprocess = list(S)
	H.HUDtech = list(S)
	for(var/key in list("hands", "pullin", "purged", "i_select", "m_select", "zone_sel"))
		H.vars[key] = S
	var/id = map_storage.BuildVarDirectory(F, H, 1)
	F.cd = map_storage.entry_path(F, id)
	for(var/key in list("hud_used", "HUDneed", "HUDinventory", "HUDfrippery", "HUDprocess", "HUDtech", "hands", "pullin", "purged", "i_select", "m_select", "zone_sel"))
		check(!(key in F.dir), "HUD runtime field exported")
	check(H.persistence_runtime_var("persistence_export_frame"), "HUD exclusion lost datum parent")
	check(!map_storage.BuildVarDirectory(F, S) && !map_storage.BuildVarDirectory(F, U), "HUD runtime object exported")
	// Reproduce an old save with an ownerless screen entry and a HUD field.
	F["[map_storage.entry_path(F, 900)]/type"] << /obj/screen/HUDthrow
	F["[map_storage.entry_path(F, 901)]/type"] << /datum/hud
	F["/lists/900/length"] << 1
	F["/lists/900/1/key"] << list("kind" = "value", "value" = "throw")
	F["/lists/900/1/value"] << list("kind" = "entry", "ref" = "900")
	F.cd = map_storage.entry_path(F, id)
	F["HUDneed"] << list("kind" = "list", "ref" = "900")
	F["hud_used"] << list("kind" = "entry", "ref" = "901")
	for(var/key in list("hands", "pullin", "purged", "i_select", "m_select", "zone_sel"))
		F[key] << list("kind" = "entry", "ref" = "900")
	map_storage.clear_bookkeeping()
	var/mob/living/human/R = map_storage.Load_Entry(F, id)
	check(R && R.name == "durable human" && R.stat == DEAD, "HUD migration lost durable human")
	var/obj/item/test/RI = locate() in R
	check(RI && RI.number == 731, "HUD migration lost nested inventory")
	check(!R.hud_used && !R.HUDneed.len, "HUD runtime field imported")
	for(var/key in list("hands", "pullin", "purged", "i_select", "m_select", "zone_sel"))
		check(isnull(R.vars[key]), "HUD screen field imported")
	check(!map_storage.Load_Entry(F, "900") && !map_storage.Load_Entry(F, "901"), "HUD runtime entry constructed")
	map_storage.clear_bookkeeping()
	qdel(H)
	qdel(R)
	qdel(S)
	qdel(U)

// Deliberately preserve the owner-dependent production throw constructor contract.
/obj/screen/HUDthrow
	var/mob/parentmob
/obj/screen/HUDthrow/New(_name, _screen_loc, mob/_parentmob)
	parentmob = _parentmob
	if(!parentmob)
		throw EXCEPTION("ownerless HUD constructor reached")

/client/New()
	..()
	mob.loc = locate(4,3,1)
	var/status = file2text("result.txt")
	src << browse("<html><body><h2>Civ13 actual offline save/import regression world</h2><p>Result: [status]</p><p>8x6x2 fixture, using repository persistence procedures and isolated game adapters.</p><p>Checks: nested objects, datum references, empty lists, associative lists, duplicates, aliases, cycles, cross-level turf reference, edge coordinates, metadata survival, corrupt-save rejection.</p><p>This is fixture runtime evidence, not full playable-world acceptance.</p></body></html>", "window=world_save_result;size=620x350")

#ifdef ROUNDTRIP_NO_TOPOLOGY_COMPAT
/proc/check_roundtrip_topology_boundary()
	var/map_storage/roundtrip_fixture/probe = new("roundtrip-zone-boundary")
	check(isnull(probe.validated_zone_state), "roundtrip topology probe did not start empty")
	probe.begin_zone_restore(null)
	for(var/list/state in list(list(), list("schema" = 1), list("schema" = 2)))
		probe.validated_zone_state = state
		var/rejected = FALSE
		try
			probe.begin_zone_restore(null)
		catch(var/exception/topology_error)
			check("[topology_error]" == "Topology needs the full-source fixture", "unexpected roundtrip topology rejection")
			rejected = TRUE
		check(rejected, "roundtrip topology state was accepted")
	qdel(probe)
#endif

// Format 5: the index names one stream per level, every entry and list comes
// back through the helper, late sweep appends land in an earlier segment, and
// a failed save stops its helper and keeps the completed backup.
/proc/check_stream_levels(obj/item/test/A)
	var/obj/item/test/D = locate(/obj/item/test) in locate(5,1,1)
	check(D && D.number == 55 && D.reference == A.reference && D.alias == A.complex, "stream entry or list identity lost")
	var/mob/living/simple_animal/swept = locate(/mob/living/simple_animal) in locate(1,1,1)
	check(swept && swept.name == "segment wanderer" && !(locate(/mob/living/simple_animal) in locate(world.maxx,1,1)), "late sweep append through the stream lost")
	var/obj/item/test/macro_copy = locate(/obj/item/test) in locate(6,1,1)
	check(macro_copy && macro_copy.number == 66 && macro_copy.name == "\improper split turkey", "stream changed a text-macro name")
	check(!map_storage.saving_segments && !map_storage.segment_reader, "stream handles retained after load")
	var/obj/item/test/escaped = locate(/obj/item/test) in locate(7,1,1)
	check(escaped && escaped.name == "q\"uo\\te \[b\] \n nl \t tab \u00e9 {\"brace\"}" && escaped.number == -0.125, "stream changed an escaped name or a fraction")
	check(escaped.items["big"] == 16777216 && escaped.items["small"] == 1e-07 && escaped.items["inf"] == 1.#INF && escaped.items[/obj/item/test] == "path key" && escaped.items["empty"] == "" && escaped.items["nested"][1][1] == "x", "stream changed list values")
	check(isfile(escaped.items["file"]) && md5(escaped.items["file"]) == md5('icons/turf/floors.dmi'), "stream changed a stored file")
	call(text2path("/proc/check_stream_text_matches_wire"))()
	for(var/z = 1, z <= 2, z++)
		var/savefile/index = new("map_saves/[z].sav")
		check(index["/format_version"] == 5 && index["/stream/file"] == "[z].stream.sav" && fexists("map_saves/[z].stream.sav"), "level [z] was not saved as a stream")
		check(!fexists("map_saves/[z].part1.sav") && !fexists("map_saves/[z].stream.sav.tmp"), "stream level [z] left segment or temporary files")
		index.cd = "/"
		check(!("entries" in index.dir) && !("lists" in index.dir), "stream index [z] holds entries or lists")
		index = null
	check(map_storage.Save_World(), "second stream export failed")
	check(fexists("map_backups/1.stream.sav") && fexists("map_backups/save_complete.txt"), "stream backup incomplete")
	check(map_storage.validate_world_save(), "second stream export rejected")
	check(!map_storage.saving_segments && !map_storage.segment_reader, "stream handles retained after save")
	// The backup generation reads its own stream copy.
	var/savefile/backup = new("map_backups/1.sav")
	check(ispath(map_storage.level_entry_value(backup, backup["/map/1/1/1"], "type"), /turf), "backup stream unreadable")
	backup = null
	map_storage.drop_segment_reader()
	// An entry shard evicted by later list blocks may still be held by an
	// entry frame; the reader must keep recognising it.
	// This file is shared with builds that do not compile the stream module.
	var/savefile/index_file = new("map_saves/1.sav")
	var/stream_reader_type = text2path("/datum/level_segment_reader/stream")
	var/datum/R = new stream_reader_type(index_file, 1)
	var/savefile/shard = call(R, "entry_file")(1)
	for(var/block = 0, block <= R.vars["limit"], block++)
		call(R, "list_file")(block * 512 + 1)
	var/list/reader_files = R.vars["open_files"]
	check(!reader_files["e0"] && call(R, "owns_file")(shard), "evicted stream shard lost its reader routing")
	call(R, "close")()
	check(!call(R, "owns_file")(shard), "closed stream reader still claims its scratch files")
	R = null
	shard = null
	index_file = null
	roundtrip_capture_failure = TRUE
	var/datum/controller/gameticker/failed_stream = new
	check(!failed_stream.savemap(), "stream capture failure accepted")
	check(!fexists("map_saves/save_complete.txt") && fexists("map_backups/save_complete.txt") && fexists("map_backups/1.stream.sav"), "failed stream export lost its completed backup")
	check(!map_storage.saving_segments && !map_storage.segment_reader && !persistence_save_in_progress, "failed stream export retained handles or lock")
	check(!fexists("map_saves/1.stream.sav.tmp") && !fexists("map_saves/2.stream.sav.tmp"), "failed stream export left its temporary file")
	roundtrip_capture_failure = FALSE
	errors.Cut() // The injected capture failure is reported to admins.
	check(map_storage.Save_World() && map_storage.validate_world_save(), "stream recovery export failed")
	map_storage.ClearMap()
	check(map_storage.Load_World(), "stream reload failed")
	A = locate(/obj/item/test) in locate(1,1,1)
	check(A && A.number == 17 && A.reference && A.reference.backlink == A && A.alias == A.complex, "stream reload lost objects or identity")
	// Without the helper the save falls back to /savefile levels and drops the stream.
	map_storage.vars["stream_level_saves_override"] = FALSE
	check(map_storage.Save_World() && map_storage.validate_world_save(), "savefile export after stream export failed")
	var/savefile/fallback = new("map_saves/1.sav")
	check(fallback["/format_version"] == 4 && !fexists("map_saves/1.stream.sav") && !fexists("map_saves/2.stream.sav"), "savefile fallback kept a stale stream")
	fallback = null
	map_storage.ClearMap()
	check(map_storage.Load_World(), "savefile reload after stream generation failed")
	check(!errors.len, "unexpected errors with stream levels: [jointext(errors, " | ")]")
	world.log << "PASS: stream-backed world save"
	text2file("PASS", "result.txt")
	del(world)
