// Deterministic attribution and real generated-wrapper lifecycle fixture only.
/datum/test/phase_probe
	map_storage_saved_vars = "value"
	var/throw_from_hook = FALSE

/datum/test/phase_probe/before_save_context(map_storage/exporter, datum/save_export_frame/frame)
	check(world_save_profile_current == "object", "nested hook entered wrong profile phase")
	world_save_progress_test_clock += 5
	if(throw_from_hook) throw EXCEPTION("phase fixture original exception")
	return ..()

/proc/world_save_profile_clock_contract()
	world_save_progress_test_clock = 1000
	world_save_progress_begin()
	world_save_progress_test_clock = 1010
	world_save_profile_phase("object")
	world_save_progress_test_clock = 1020
	world_save_profile_phase("value")
	world_save_progress_test_clock = 1030
	world_save_profile_phase("object")
	world_save_progress_test_clock = 1040
	world_save_profile_phase("yield")
	world_save_progress_test_clock = 1070
	world_save_profile_phase("object")
	world_save_progress_test_clock = 1080
	world_save_profile_phase("other")
	world_save_progress_test_clock = 1090
	var/list/row = list()
	world_save_profile_row(row)
	var/list/totals = row["phase_wall_ds"]
	check(totals["value"] == 10 && totals["object"] == 30 && totals["yield"] == 30 && totals["other"] == 20, "phase category attribution failed")
	check(row["elapsed_real_ds"] == 90, "phase sample elapsed mismatch")
	// Sub-ds transitions must telescope at the declared 0.1-second resolution.
	world_save_progress_test_clock = 1100.75
	world_save_progress_begin()
	world_save_progress_test_clock = 1101.25
	world_save_profile_phase("object")
	world_save_progress_test_clock = 1101.75
	world_save_profile_phase("value")
	world_save_progress_test_clock = 1102.25
	world_save_profile_row(row)
	totals = row["phase_wall_ds"]
	check(totals["other"] == 1 && totals["object"] == 0 && totals["value"] == 1 && row["elapsed_real_ds"] == 2, "fractional phase endpoints lost time")
	world_save_progress_test_clock = 863999.75
	world_save_progress_begin()
	world_save_progress_test_clock = 0.25
	world_save_profile_phase("object")
	world_save_progress_test_clock = 0.75
	world_save_profile_phase("value")
	world_save_progress_test_clock = 1.25
	world_save_profile_row(row)
	totals = row["phase_wall_ds"]
	check(totals["other"] == 1 && totals["object"] == 0 && totals["value"] == 1 && row["elapsed_real_ds"] == 2, "fractional midnight endpoints lost time")
	world_save_progress_test_clock = 2000
	world_save_progress_begin()
	world_save_profile_phase("traversal")
	map_storage.clear_bookkeeping()
	var/savefile/F = new
	F["/format_version"] << 2
	var/datum/test/phase_probe/parent = new
	var/datum/test/phase_probe/child = new
	// Datums export changed vars; a default scalar would not call the encoder.
	child.value = 17
	parent.value = child
	var/ref = map_storage.BuildVarDirectory(F, parent)
	check(ref && world_save_profile_current == "traversal", "nested wrapper failed to restore caller phase")
	check(world_save_profile_objects == 2 && world_save_profile_values == 2, "nested wrapper changed call counts")
	check(world_save_profile_totals["object"] == 10, "nested wrapper lost exclusive object time")
	var/list/envelope
	F["[map_storage.entry_path(F, ref)]/value"] >> envelope
	check(envelope["kind"] == "entry", "profile changed original encoded return")
	var/child_ref = envelope["ref"]
	F["[map_storage.entry_path(F, child_ref)]/value"] >> envelope
	check(envelope["kind"] == "value" && envelope["value"] == 17, "profile changed nested scalar encoding")
	var/datum/test/phase_probe/failing = new
	failing.throw_from_hook = TRUE
	var/caught = FALSE
	try
		map_storage.BuildVarDirectory(F, failing)
	catch(var/exception/E)
		caught = E.name == "phase fixture original exception"
	check(caught && world_save_profile_current == "traversal", "wrapper changed original exception or caller phase")
	check(world_save_profile_totals["object"] == 15, "throwing wrapper lost measured work")
	world_save_progress_active = FALSE
	var/calls_before = world_save_profile_values
	var/list/inactive = map_storage.encode_saved_value(F, 17)
	check(inactive["kind"] == "value" && inactive["value"] == 17 && world_save_profile_values == calls_before, "inactive wrapper changed original return or counters")
	map_storage.clear_bookkeeping()
	qdel(parent)
	qdel(child)
	qdel(failing)
