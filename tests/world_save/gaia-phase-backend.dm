// Narrow actual-backend smoke for the frozen legacy Gaia saver closure.
// The owner launches SAVE and VERIFY as separate guarded processes in one
// temporary directory. No fake clock, startup controller, or live files.
world
	name = "Civ13 isolated Gaia backend phase smoke"
	maxx = 8
	maxy = 6
	maxz = 2
	turf = /turf/backend_test
	sleep_offline = FALSE
	visibility = 0
/turf/backend_test
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood"
	map_storage_saved_vars = "name;dir"
/turf/backend_test/edge
	icon_state = "plating"
/obj/item/backend_test
	var/number = 0
	var/datum/backend_test/reference
	var/list/complex
	var/list/alias
	var/turf/destination
	var/matrix/matrix_value
/datum/backend_test
	var/value = 0
/obj/item/backend_test/before_save()
	..()
	// Explicit fixture hook: exercise a real scoped yield, including pending
	// engine flushes, without changing production tick limits or saver hooks.
	world_save_progress_stoplag()
/proc/backend_check(condition, message)
	if(!condition) throw EXCEPTION(message)
/proc/backend_check_matrix(matrix/M, list/expected, label)
	backend_check(istype(M, /matrix), "[label] matrix missing")
	var/list/keys = list("a", "b", "c", "d", "e", "f")
	for(var/i = 1, i <= keys.len, i++)
		backend_check(M.vars[keys[i]] == expected[i], "[label] matrix coefficient [keys[i]] changed")
/world/OpenPort(port)
	return ..("none")
/world/New()
	OpenPort("none")
	..()
	var/list/receipt = list("scope" = "isolated actual-backend legacy saver smoke", "mode" = world.params["verify"] ? "VERIFY" : "SAVE", "stop_route" = "owner console shutdown after disk receipts", "fake_clock" = FALSE, "full_gaia_recovery" = FALSE)
	try
		// OpenDream sleep uses game ticks. Its startup loop can consume up to
		// five queued ticks together; two startup ticks need not span 0.1s.
		// Move beyond that bounded queue before sampling the real getter.
		receipt["startup_world_time_ds"] = world.time
		receipt["startup_tick_lag_ds"] = world.tick_lag
		sleep(8 * world.tick_lag)
		var/start_clock = world_save_progress_now()
		var/start_time = world.time
		var/sample_tick_lag = world.tick_lag
		sleep(4 * sample_tick_lag)
		var/end_clock = world_save_progress_now()
		receipt["clock_start_ds"] = start_clock
		receipt["clock_end_ds"] = end_clock
		receipt["sample_world_start_ds"] = start_time
		receipt["sample_world_end_ds"] = world.time
		receipt["sample_tick_lag_ds"] = sample_tick_lag
		world.log << "BACKEND_CLOCK [json_encode(receipt)]"
		backend_check(world.time > start_time, "game time did not advance across clock sample")
		backend_check(world_save_progress_elapsed(start_clock, end_clock) > 0, "actual timeofday did not advance")
		map = new /obj/map_metadata(locate(1,1,1))
		if(world.params["verify"])
			backend_check(map_storage.validate_world_save(), "fresh process rejected completed generation")
			backend_check(map_storage.Load_World(), "fresh process load failed")
			var/obj/item/backend_test/A = locate(/obj/item/backend_test) in locate(1,1,1)
			backend_check(A && A.number == 17, "parent scalar lost")
			var/obj/item/backend_test/B = locate(/obj/item/backend_test) in A
			backend_check(B && B.number == 42, "nested item scalar lost")
			backend_check(A.reference && A.reference.value == 73, "typed datum lost")
			backend_check_matrix(A.matrix_value, list(2,3,4,5,6,7), "standalone")
			backend_check_matrix(A.transform, list(8,9,10,11,12,13), "transform")
			backend_check(A.complex["key"]["nested"] == 23, "nested associative list lost")
			backend_check(A.alias == A.complex && A.complex[A.complex.len] == A.complex, "list alias or cycle lost")
			backend_check(A.destination == locate(8,6,2), "cross-level turf reference lost")
			backend_check(istype(A.destination, /turf/backend_test/edge) && A.destination.name == "backend edge", "second-level turf lost")
			var/obj/item/backend_test/C = locate(/obj/item/backend_test) in locate(8,6,2)
			backend_check(C && C.number == 314, "second-level item lost")
		else
			var/turf/edge = new /turf/backend_test/edge(locate(8,6,2))
			edge.name = "backend edge"
			var/obj/item/backend_test/A = new(locate(1,1,1))
			A.number = 17
			var/obj/item/backend_test/B = new(A)
			B.number = 42
			A.reference = new /datum/backend_test
			A.reference.value = 73
			A.matrix_value = new /matrix(2,3,4,5,6,7)
			A.transform = new /matrix(8,9,10,11,12,13)
			A.complex = list("literal **entry7", "key" = list("nested" = 23))
			A.alias = A.complex
			A.complex += list(A.complex)
			A.destination = edge
			var/obj/item/backend_test/C = new(edge)
			C.number = 314
			backend_check(map_storage.Save_World(), "save returned failure")
			backend_check(!world_save_progress_unavailable, "progress diagnostic unavailable")
			var/list/row = json_decode(file2text("world_save_progress.json"))
			backend_check(row["clock_source"] == "world.timeofday (24-hour wrap)", "unexpected clock source")
			backend_check(row["visited_turfs_all_levels"] == 192 && row["selected_turfs_all_levels"] == 96, "phase traversal counts changed")
			backend_check(row["object_calls_including_references"] >= 96 && row["value_calls_including_recursive"] > 0, "phase call counters missing")
			backend_check(row["stoplag_calls"] >= 3 && row["stoplag_elapsed_real_ds"] > 0, "real scoped yield did not advance")
			var/list/phases = row["phase_wall_ds"]
			var/total = 0
			for(var/phase in phases)
				backend_check(phases[phase] >= 0, "negative phase interval")
				total += phases[phase]
			backend_check(total == row["elapsed_real_ds"], "phase partition differs from elapsed")
			receipt["progress"] = row
			// Give backend pending writes their normal tick boundary. File/marker
			// presence alone is not fresh-process recovery acceptance.
			sleep(2)
		backend_check(fexists("map_saves/save_complete.txt") && fexists("map_saves/1.sav") && fexists("map_saves/2.sav"), "completed multi-level generation missing")
		backend_check(!errors.len, "unexpected persistence errors")
		receipt["result"] = "PASS"
	catch(var/exception/E)
		receipt["result"] = "FAIL"
		receipt["error"] = E.name
		world.log << "FAIL: [E.name]"
	var/mode = world.params["verify"] ? "verify" : "save"
	text2file(json_encode(receipt), "backend_[mode]_result.json")
	text2file(receipt["result"], "backend_[mode]_result.txt")
	world.log << "BACKEND_RESULT [json_encode(receipt)]"
	// The owned host validates BOTH disk receipts, then sends the supported
	// console shutdown command and waits for clean exit before fresh VERIFY.
	// Returning keeps world alive; this does not fix or exercise del(world).
	return
