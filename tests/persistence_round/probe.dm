/world
	maxx = 4
	maxy = 4
	maxz = 1
	turf = /turf/floor/plating

/world/OpenPort(port)
	return ..("none")

/world/IsBanned(key, address, computer_id, type, real_bans_only)
	return list("reason" = "Offline regression")

/obj/map_metadata/persistence_fixture/New()
	map = src

/proc/persistent_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)

var/global/persistence_test_hooks = 0
var/global/persistence_test_reboots = 0

/proc/persistence_test_roundend()
	persistence_test_hooks++

/proc/persistence_test_reboot()
	persistence_test_reboots++

/datum/persistence_callback
	var/called = FALSE
	var/enable_persistence = FALSE
	proc/receive(winner)
		called = TRUE
		if (enable_persistence) map.persistence = TRUE

/world/New()
	OpenPort("none")
	sleep(1)
	try
		new /obj/map_metadata/persistence_fixture
		ticker = new
		ticker.current_state = GAME_STATE_PLAYING
		config.allowedgamemodes = "TDM"
		map.persistence = TRUE
		ticker.finished = TRUE
		persistence_save_in_progress = TRUE
		persistent_assert(!ticker.process() && ticker.finished && ticker.current_state == GAME_STATE_PLAYING, "save guard preserves persistent round state")
		persistence_save_in_progress = FALSE
		persistence_restart.startup_hold = TRUE
		persistent_assert(!ticker.process() && ticker.finished && ticker.current_state == GAME_STATE_PLAYING, "startup guard preserves persistent round state")
		persistence_restart.startup_hold = FALSE
		var/datum/persistence_callback/C = new
		for (var/kind in list("restart", "epoch", "map", "gamemode"))
			vote.reset()
			persistent_assert(!vote.initiate_vote(kind, "offline-admin", TRUE), "vote creation blocked: [kind]")
			persistent_assert(!vote.mode, "blocked vote cannot become active")
			// Acquire real generation-bound sessions, then simulate a mode whose
			// persistence policy changed while it was pending.
			var/datum/vote_handle/pending = vote.request_choices("Pending adapter", list("Choice"), "offline-admin", 20, list(C, "receive"), TRUE)
			persistent_assert(pending && vote.is_current(pending), "pending fixture acquires real handle")
			vote.mode = kind
			vote.process()
			persistent_assert(!vote.mode && !vote.active_request && pending.state == "cancelled" && !pending.manager && !pending.completion && !C.called, "pending vote cancelled: [kind]")
			var/datum/vote_handle/result_handle = vote.request_choices("Result adapter", list("Choice"), "offline-admin", 20, list(C, "receive"), TRUE)
			persistent_assert(result_handle && vote.submit_vote("offline-admin", 1, result_handle.generation), "result fixture acquires voted handle")
			vote.mode = kind
			persistent_assert(!result_handle.resolve() && !vote.mode && !vote.active_request && result_handle.state == "cancelled" && !result_handle.manager && !result_handle.completion && !C.called, "result blocked before callback: [kind]")
			persistent_assert(!pending.resolve() && !result_handle.resolve() && !C.called, "cancelled persistence handles remain inert")
			persistent_assert(!vote.apply_result(kind, 0, "Restart Round", list(C, "receive")), "direct result application blocked: [kind]")
		map.persistence = FALSE
		C.enable_persistence = TRUE
		var/datum/vote_handle/during_callback = vote.request_choices("Persistence during callback", list("Restart Round"), "offline-admin", 20, list(C, "receive"), TRUE)
		persistent_assert(during_callback && vote.submit_vote("offline-admin", 1, during_callback.generation), "callback fixture acquires voted handle")
		vote.mode = "restart"
		ticker.finished = FALSE
		persistent_assert(!during_callback.resolve() && C.called && map.persistence && !ticker.finished, "callback policy change blocks old result application")
		persistent_assert(during_callback.state == "resolved" && !during_callback.manager && !during_callback.completion, "callback policy change retains terminal detached handle")
		C.enable_persistence = FALSE
		persistent_assert(!persistence_blocks_vote("custom"), "non-ending polls remain available")
		ticker.finished = TRUE
		ticker.process()
		persistent_assert(!ticker.finished, "finished flag cleared")
		persistent_assert(ticker.current_state == GAME_STATE_PLAYING, "round continues")
		ticker.current_state = GAME_STATE_FINISHED
		ticker.finished = TRUE
		ticker.process()
		persistent_assert(!ticker.finished && ticker.current_state == GAME_STATE_PLAYING, "stale finished state recovered")
		var/process/epochswap/E = new
		var/process/mapswap/M = new
		persistent_assert(!vote.request_choices("Hidden map transition", list("Yes"), "offline-admin", 20, list(M, "swap"), TRUE), "generic map callback blocked")
		persistent_assert(!vote.request_choices("Hidden epoch transition", list("Yes"), "offline-admin", 20, list(E, "swap"), TRUE), "generic epoch callback blocked")
		E.ready = TRUE
		E.restart_triggered = TRUE
		M.ready = TRUE
		M.restart_triggered = TRUE
		persistent_assert(!E.is_ready() && !M.is_ready(), "automatic rotations blocked")
		vote.voted_epoch = "unchanged"
		E.swap("unexpected")
		persistent_assert(vote.voted_epoch == "unchanged", "direct epoch callback blocked")
		ticker.current_state = GAME_STATE_PREGAME
		persistent_assert(!persistence_blocks_vote("map") && !persistence_blocks_vote("epoch"), "initial lobby selection retained")
		persistent_assert(persistence_blocks_vote("restart"), "restart vote blocked in lobby")
		map.persistence = FALSE
		map.perschadplus = TRUE
		persistent_assert(persistence_round_active(), "persistent chad mode protected")
		map.perschadplus = FALSE
		config.allowedgamemodes = "PERSISTENCE"
		persistent_assert(persistence_round_active(), "configured persistence protected before map setup")
		config.allowedgamemodes = "TDM"
		ticker.current_state = GAME_STATE_PLAYING
		persistent_assert(!persistence_blocks_vote("restart") && !persistence_blocks_vote("map"), "ordinary rounds retain ending votes")
		persistent_assert(E.is_ready() && M.is_ready(), "ordinary round rotation retained")
		processes.epochswap = E
		E.finished_at = world.time - 1000
		ticker.finished = TRUE
		ticker.process()
		map.persistence = TRUE
		sleep(51)
		persistent_assert(!ticker.finished && ticker.current_state == GAME_STATE_PLAYING && !persistence_test_hooks, "deferred round end cancelled before hook")
		map.persistence = FALSE
		E.finished_at = world.time - 1000
		ticker.finished = TRUE
		ticker.process()
		sleep(51)
		persistent_assert(persistence_test_hooks == 1 && ticker.current_state == GAME_STATE_FINISHED, "ordinary round end hook retained")
		map.persistence = TRUE
		sleep(301)
		persistent_assert(!ticker.finished && ticker.current_state == GAME_STATE_PLAYING && !persistence_test_reboots, "pending reboot cancelled after restart sleep")
		text2file("PASS: production persistence votes, callbacks, rotation and ticker guards; lobby and ordinary-round controls", "result.txt")
	catch (var/exception/error)
		text2file("FAIL: [error]", "result.txt")
	del(world)

/world/Error(exception/E)
	text2file("[E]\n[E.file]:[E.line]\n[E.desc]", "errors.txt")
	return ..()
