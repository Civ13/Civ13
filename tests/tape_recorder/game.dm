// Tape recorder fixture (code/modules/1713/tape_recorder.dm): recording in
// earshot and from a pocket, the tape limit, labels, playback, language
// scrambling, erase/eject and a native save round trip of a recorded tape.
var/tape_failures = 0
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 12
	maxz = 2
	turf = /turf
	visibility = 0
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/obj/map_metadata/tape_fixture/New()
	return
/mob/living/human/tape_fixture/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	bloodstr = new /datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new /datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new /datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	vessel = new /datum/reagents(1000, src)
/proc/tape_check(condition, label)
	if (!condition)
		tape_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	tape_failures++
	world.log << "runtime error: [e] [e.file]:[e.line]"
/proc/tape_fixture_person(x, name)
	var/mob/living/human/tape_fixture/P = new(locate(x, 5, 1))
	P.real_name = name
	P.name = name
	P.stat = CONSCIOUS
	P.languages = list()
	return P
/world/New()
	OpenPort("none")
	generate_gameid()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	movementMachine = new
	map = new /obj/map_metadata/tape_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.ordinal_age = 7
	try
		build_research_tree()
		var/datum/research_node/node = get_research_node("automation")
		tape_check(node && node.era_tier == 7, "Automation unlocks in 1969")
		tape_check(get_recipe_node_req("/obj/item/tape_recorder") == "automation" && get_recipe_node_req("/obj/item/cassette") == "automation", "tape recorder and cassette recipes need Automation")
		var/datum/language/english/english = all_languages["English"]
		if (!english)
			english = new
			all_languages[english.name] = english
		var/mob/living/human/tape_fixture/ann = tape_fixture_person(3, "Ann")
		var/mob/living/human/tape_fixture/bob = tape_fixture_person(30, "Bob")
		ann.languages += english
		var/obj/item/tape_recorder/R = new(locate(4, 5, 1))
		var/obj/item/cassette/T = new(locate(4, 5, 1))
		tape_check(!R.start_recording(ann) && !R.recording, "no recording without a tape")
		R.attackby(T, ann)
		tape_check(R.get_tape() == T && T.loc == R, "a cassette goes into the recorder")
		var/obj/item/cassette/second = new(locate(4, 5, 1))
		R.attackby(second, ann)
		tape_check(second.loc != R, "only one tape fits")
		tape_check(R.start_recording(ann) && R.recording && (R in recording_tape_recorders) && R.icon_state == "recorder_on", "press record")
		// On the ground it hears through hear_talk(); the carried-recorder hook skips it, so nothing is doubled.
		tape_recorders_hear(ann, "Meet me at the mill at dawn.", "says", english, view(7, ann))
		tape_check(!T.lines.len, "the carried-recorder hook leaves a recorder on the ground to hear_talk()")
		for (var/obj/O in view(7, ann))
			O.hear_talk(ann, "Meet me at the mill at dawn.", "says", english)
		tape_recorders_hear(bob, "You can't hear me from here.", "says", english, view(7, bob))
		R.hear_talk(ann, "<span class = 'font-size: 1.1em;'>Bring rope!</span>", "exclaims", english)
		R.hear_talk(ann, "*waves", "says", english)
		tape_check(T.lines.len == 2 && T.lines[1] == "Meet me at the mill at dawn." && T.lines[2] == "Bring rope!", "records speech in earshot, without markup or emotes")
		tape_check(T.voices[1] == "Ann" && T.speech_verbs[2] == "exclaims" && T.language_names[1] == "English", "keeps voice, verb and language")
		sleep(15)
		R.hear_talk(ann, "Later line.", "whispers", english)
		tape_check(T.stamps[3] >= T.stamps[1] + 10 && T.used >= T.stamps[3], "the tape advances while recording")
		tape_check(R.stop(ann) && !R.recording && !(R in recording_tape_recorders) && R.icon_state == "recorder", "press stop")
		R.hear_talk(ann, "Not recorded.", "says", english)
		tape_check(T.lines.len == 3, "a stopped recorder records nothing")
		// A recorder in a pocket records what its carrier and people near them say.
		R.forceMove(ann)
		tape_check(R.start_recording(ann), "record from a pocket")
		tape_recorders_hear(ann, "Pocket line.", "says", english, view(7, ann))
		R.hear_talk(ann, "Pocket line.", "says", english)
		tape_check(T.lines.len == 4 && T.lines[4] == "Pocket line.", "a carried recorder records its carrier")
		R.stop()
		R.forceMove(locate(4, 5, 1))
		// Language: a listener who does not speak it hears the line scrambled.
		tape_check(tape_heard_text(ann, "Meet me at the mill at dawn.", "English") == "Meet me at the mill at dawn.", "a speaker of the language hears the words")
		tape_check(tape_heard_text(bob, "Meet me at the mill at dawn.", "English") != "Meet me at the mill at dawn.", "others hear it scrambled")
		tape_check(tape_heard_text(bob, "Plain words.", "") == "Plain words.", "a line with no language is plain")
		// Playback runs through the tape and stops by itself.
		tape_check(R.start_playback(ann) && R.playing && !R.start_recording(ann), "press play; no recording while playing")
		var/waited = 0
		while (R.playing && waited < 300)
			sleep(10)
			waited += 10
		tape_check(!R.playing && R.icon_state == "recorder", "playback finishes on its own")
		// Labels
		var/obj/item/weapon/pen/pen = new(locate(4, 5, 1))
		T.label = sanitize("Mill <b>plan</b>", 32)
		T.update_icon()
		tape_check(findtext(T.name, "cassette tape - '") == 1 && T.overlays.len == 1, "a label names the tape and shows on it")
		qdel(pen)
		// The tape fills up.
		var/obj/item/cassette/full = new
		full.used = TAPE_CAPACITY
		tape_check(full.is_full(), "a tape at capacity is full")
		var/obj/item/cassette/many = new
		for (var/i = 1, i <= TAPE_MAX_LINES, i++)
			many.add_line(i, "Ann", "says", "line [i]", "English")
		tape_check(many.is_full() && !many.add_line(999, "Ann", "says", "one more", "English") && many.lines.len == TAPE_MAX_LINES, "a tape holds a bounded number of lines")
		var/obj/item/tape_recorder/R2 = new(locate(6, 5, 1))
		full.forceMove(R2)
		tape_check(!R2.start_recording(ann), "a full tape cannot record")
		full.forceMove(null)
		qdel(full)
		qdel(many)
		qdel(R2)
		// Eject
		tape_check(R.eject() && T.loc == R.loc && !R.get_tape(), "eject drops the tape")
		R.attackby(T, ann)
		tape_check(R.get_tape() == T, "and it goes back in")
		var/label = T.label
		qdel(ann)
		qdel(bob)
		qdel(second)
		tape_check(map_storage.Save_World() && map_storage.validate_world_save(), "native save")
		map_storage.ClearMap()
		tape_check(map_storage.Load_World(), "native reload")
		var/obj/item/tape_recorder/restored = locate(/obj/item/tape_recorder) in locate(4, 5, 1)
		var/obj/item/cassette/restored_tape = restored ? restored.get_tape() : null
		tape_check(restored && !restored.recording && !restored.playing && !(restored in recording_tape_recorders), "a restored recorder is idle")
		tape_check(restored_tape && restored_tape.label == label && restored_tape.lines.len == 4 && restored_tape.lines[2] == "Bring rope!" && restored_tape.voices[1] == "Ann" && restored_tape.language_names[1] == "English" && restored_tape.stamps.len == 4, "the recorded tape and its label survive a save")
		tape_check(restored_tape && findtext(restored_tape.name, "Mill"), "the label still names the tape")
	catch (var/exception/e)
		tape_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = tape_failures, "byond_build" = world.byond_build)), "result.json")
	del(world)
