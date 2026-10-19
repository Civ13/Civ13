// Prepended with the existing game.dm minimal world/human setup. No fake wait.
var/list/training_click_checks = list()
var/list/training_click_cases = list()
var/training_click_done = FALSE

/mob/living/human/training_fixture
	var/list/training_click_messages = list()

/proc/training_click_chat(target, message)
	if (istype(target, /mob/living/human/training_fixture))
		var/mob/living/human/training_fixture/H = target
		H.training_click_messages += "[message]"
	to_chat(target, message)

/proc/training_click_seen(mob/living/human/training_fixture/H, text)
	for (var/message in H.training_click_messages)
		if (findtext(message, text))
			return TRUE
	return FALSE

/proc/training_click_check(condition, label)
	training_click_checks += list(list("label" = label, "passed" = !!condition))
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"

/proc/training_click_input(mob/living/human/training_fixture/H, obj/structure/exercise/E, label)
	// Respect the normal click clock; never reset input cooldowns.
	sleep(2)
	H.training_click_messages.Cut()
	H.ClickOn(E, "icon-x=16;icon-y=16")
	training_click_cases += list(list("case" = label, "messages" = H.training_click_messages.Copy(), "time" = world.time))

/obj/structure/exercise/click_fixture
	var/hand_entries = 0
	var/item_entries = 0
	var/wait_calls = 0
	var/list/wait_ticks = list()
	var/list/start_feedback_present = list()

/obj/structure/exercise/click_fixture/attack_hand(mob/living/human/H)
	hand_entries++
	return ..()

/obj/structure/exercise/click_fixture/attackby(obj/item/W, mob/user, icon_x, icon_y)
	item_entries++
	return ..()

/obj/structure/exercise/click_fixture/exercise_wait(mob/living/human/H, duration)
	wait_calls++
	var/started = world.time
	start_feedback_present += !!training_click_seen(H, "You begin lifting repetition [repetition+1]/3")
	. = ..()
	wait_ticks += world.time - started

/proc/training_click_finish()
	if (training_click_done)
		return
	training_click_done = TRUE
	text2file(json_encode(list("commit" = world.params["tested_commit"], "byond_build" = world.byond_build, "checks" = training_click_checks, "cases" = training_click_cases, "scope" = "Headless production ClickOn and real waits; fixture inventory/chat capture; no connected client")), "result.json")
	del(world)

/world/Error(exception/E)
	training_click_check(FALSE, "runtime error: [E] [E.file]:[E.line]")
	training_click_finish()

/world/New()
	OpenPort("none")
	spawn(900)
		training_click_check(FALSE, "fixture deadline")
		training_click_finish()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	movementMachine = new
	map = new /obj/map_metadata/training_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.ordinal_age = 0
	config = new /datum/configuration
	ticker = new /datum/controller/gameticker
	ticker.current_state = GAME_STATE_PLAYING
	try
		// Same turf avoids the client-only facing branch in headless ClickOn.
		// Connected acceptance must separately check an adjacent actual client.
		var/mob/living/human/training_fixture/H = new(locate(2,2,1))
		var/mob/living/human/training_fixture/other = new(locate(2,2,1))
		var/obj/structure/exercise/click_fixture/E = new(locate(2,2,1))
		H.stats["strength"] = list(80,80)
		var/obj/item/tool = new(H)
		H.r_hand = tool
		H.hand = FALSE
		training_click_input(H, E, "held active item")
		training_click_check(E.item_entries == 1 && !E.hand_entries && !E.wait_calls && !E.actor && H.getMaxStat("strength") == 80, "held item uses item route without training")
		training_click_check(training_click_seen(H, "empty active hand"), "held item receives empty-hand instruction")
		H.hand = TRUE // Empty active hand, item remains in inactive hand.
		for (var/i = 1, i <= 3, i++)
			training_click_input(H, E, "real repetition [i]")
			training_click_check(E.wait_calls == i && E.wait_ticks[i] >= 150 && H.may_do_after, "real wait [i] reaches150 ticks and releases action lock")
			training_click_check(E.start_feedback_present[i], "repetition [i] acknowledges start before real wait")
			if (i < 3)
				training_click_check(H.getMaxStat("strength") == 80 && E.repetition == i, "repetition [i] has no partial gain")
		training_click_check(abs(H.getMaxStat("strength") - 80.4) < 0.001 && H.exercise_fatigue == 2 && !E.actor && !H.exercise_equipment, "original finite set reward remains intact")
		sleep(3)
		training_click_check(E.wait_calls == 3, "no autonomous fourth repetition")
		var/gain = H.getMaxStat("strength")
		spawn(20)
			H.hand = FALSE // Real do_after observes active-hand change.
		training_click_input(H, E, "real hand-switch interruption")
		training_click_check(E.wait_ticks[E.wait_ticks.len] < 150 && H.may_do_after && !E.actor && !H.exercise_equipment && H.getMaxStat("strength") == gain, "real hand switch interrupts without partial gain")
		training_click_check(training_click_seen(H, "exercise was interrupted"), "interruption reports lost unfinished set")
		H.hand = TRUE
		H.stats["strength"] = list(125,125)
		training_click_input(H, E, "current cap")
		training_click_check(training_click_seen(H, "125 training limit") && !E.actor, "current cap explains rejection")
		H.stats["strength"] = list(80,125)
		training_click_input(H, E, "trained cap")
		training_click_check(training_click_seen(H, "125 training limit") && !E.actor, "trained cap explains rejection")
		H.stats["strength"] = list(80,80)
		H.exercise_fatigue = 6
		H.exercise_rest_epoch = exercise_time()
		training_click_input(H, E, "fatigue")
		training_click_check(training_click_seen(H, "too fatigued") && !E.actor, "fatigue explains rejection")
		H.exercise_fatigue = 0
		// Seed ownership guards, not fake waits or reward calculations.
		E.actor = other
		other.exercise_equipment = E
		E.expiry = exercise_time() + 1200
		training_click_input(H, E, "other actor")
		training_click_check(training_click_seen(H, "Someone else") && E.actor == other, "other actor ownership explains rejection")
		other.cancel_exercise()
		var/obj/structure/exercise/second = new(locate(2,2,1))
		H.exercise_equipment = second
		second.actor = H
		training_click_input(H, E, "other equipment")
		training_click_check(training_click_seen(H, "Stop Exercise") && !E.actor && second.actor == H, "own other equipment explains rejection")
		H.cancel_exercise()
		E.actor = H
		H.exercise_equipment = E
		E.expiry = exercise_time() + 1200
		E.busy = TRUE
		training_click_input(H, E, "busy")
		training_click_check(training_click_seen(H, "already in progress") && E.busy, "busy repetition explains rejection")
		H.cancel_exercise()
		H.training_click_messages.Cut()
		H.stats["strength"] = list(125,125)
		E.eligible(H)
		training_click_check(!H.training_click_messages.len, "internal eligibility checks stay quiet")
	catch (var/exception/error)
		training_click_check(FALSE, "exception [error] [error.file]:[error.line]")
	training_click_finish()
