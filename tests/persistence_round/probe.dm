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
	proc/receive(winner)
		called = TRUE

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
			vote.mode = kind
			vote.callback = list(C, "receive")
			vote.process()
			persistent_assert(!vote.mode && !vote.callback, "pending vote cancelled: [kind]")
			vote.mode = kind
			vote.callback = list(C, "receive")
			persistent_assert(!vote.result() && !vote.mode && !vote.callback && !C.called, "result blocked before callback: [kind]")
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
