// Deterministic clock contract, included only by run-string-path.py.
/proc/world_save_progress_test_clock_contract()
	world_save_progress_test_clock = 1000
	world_save_progress_begin()
	world_save_progress_test_clock = 1099
	world_save_progress_emit("clock_too_soon", 1, 1024)
	var/list/row = json_decode(file2text("world_save_progress.json"))
	check(row["stage"] == "save_entered", "progress throttle emitted before ten seconds")
	world_save_progress_test_clock = 1100
	world_save_progress_emit("clock_ten_seconds", 1, 1024)
	row = json_decode(file2text("world_save_progress.json"))
	check(row["stage"] == "clock_ten_seconds", "periodic progress not emitted after ten seconds")
	check(row["elapsed_real_ds"] == 100, "wrong progress wall-clock elapsed time")
	check(row["clock_source"] == "fixture timeofday (24-hour wrap)", "fixture clock incorrectly labeled")
	world_save_progress_test_clock = 863995
	world_save_progress_begin()
	world_save_progress_test_clock = 100
	world_save_progress_emit("clock_midnight", 1, 2048)
	row = json_decode(file2text("world_save_progress.json"))
	check(row["stage"] == "clock_midnight" && row["elapsed_real_ds"] == 105, "progress throttle failed across midnight")
	world_save_progress_test_clock = 863995
	world_save_progress_begin()
	spawn(0)
		world_save_progress_test_clock = 10
	var/waits = world_save_progress_stoplag()
	check(waits >= 1 && world_save_progress_yields == 1, "progress wrapper changed stoplag behavior")
	check(world_save_progress_yield_ds == 15, "progress yield duration failed across midnight")
	world_save_progress_active = FALSE
