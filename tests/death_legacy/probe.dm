// Native death legacy probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/research_tree/death_legacy.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 400
	maxy = 400
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
	return
/obj/map_metadata/legacy_probe/New()
	map = src
	persistence = TRUE
	recipe_books = TRUE
/mob/living/human/legacy_tester/New()
	return
/mob/living/human/legacy_tester/adaptStat(stat, amount)
	return
var/legacy_failures = 0
var/legacy_runtime_error = FALSE
/proc/legacy_check(condition, label)
	if (!condition)
		legacy_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	legacy_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/legacy_probe
		build_research_tree()
		legacy_table_checks()
		legacy_station_checks()
		legacy_bed_checks()
		legacy_cause_checks()
		legacy_save_checks()
		legacy_weakness_checks()
	catch(var/exception/e)
		legacy_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = legacy_failures, "runtime_error" = legacy_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/legacy_nodes(count)
	var/list/ids = list()
	for (var/id in research_nodes)
		ids += id
		if (ids.len >= count)
			break
	return ids

/proc/legacy_tester(x, y, account)
	var/mob/living/human/H = new /mob/living/human/legacy_tester(locate(x, y, 1))
	H.persistence_owner_ckey = account
	H.real_name = "Tester [account]"
	H.nutrition = 300
	H.water = 300
	return H

// A character with five subjects, some scholarship and trained skills.
/proc/legacy_scholar(x, y, account)
	var/mob/living/human/H = legacy_tester(x, y, account)
	H.known_recipe_nodes = legacy_nodes(5)
	H.scholarship = list("mathematics" = 50, "engineering" = 30)
	H.stats["strength"] = list(150, 150)
	H.stats["crafting"] = list(200, 200)
	H.stats["farming"] = list(90, 90)
	return H

/proc/legacy_table_checks()
	var/list/loss = death_legacy_loss("starved")
	legacy_check(loss[1] == 0.2 && !loss[2] && !loss[4], "starving costs a fifth of body skills and no knowledge")
	loss = death_legacy_loss("wounded")
	legacy_check(loss[1] == 0.1, "wounds cost a tenth of body skills")
	loss = death_legacy_loss("drowned")
	legacy_check(loss[2] == 0.2 && !loss[1], "drowning costs a fifth of scholarship")
	loss = death_legacy_loss("burned")
	legacy_check(loss[3] == 0.2 && !loss[1], "burning costs crafting and dexterity")
	loss = death_legacy_loss("player")
	legacy_check(loss[4] == 3 && loss[2] == 0.2, "a killing costs three subjects and a fifth of scholarship")
	loss = death_legacy_loss("player", 1)
	legacy_check(loss[4] == 6 && loss[2] == 0.4, "a second return in a day costs double")
	loss = death_legacy_loss("starved", 5)
	legacy_check(loss[1] == 1, "the loss never passes everything")

/proc/legacy_station_checks()
	var/mob/living/human/dead = legacy_scholar(100, 100, "alpha")
	dead.nutrition = 0
	death_legacy_note(dead, FALSE)
	var/list/record = death_legacies["alpha"]
	legacy_check(record["kept"] && record["cause"] == "starved" && length(record["nodes"]) == 5, "a death records what the character knew and why it died")
	// Too far: 151 tiles away.
	var/mob/living/human/far = legacy_tester(251, 100, "alpha")
	far.started_with_faction = TRUE
	legacy_check(!death_legacy_apply(far, "alpha") && !length(far.known_recipe_nodes), "a station more than 150 tiles away gives nothing back")
	legacy_check(far.death_weakness_left == 1800, "the next character is weakened for 30 minutes even without a return")
	// The wilds beside the death: no station, no bed.
	var/mob/living/human/wild = legacy_tester(101, 100, "alpha")
	legacy_check(!death_legacy_apply(wild, "alpha") && !wild.death_weakness_left, "a start in the wilds gives nothing back, and the weakness is given once")
	var/mob/living/human/back = legacy_tester(250, 100, "alpha")
	back.started_with_faction = TRUE
	legacy_check(death_legacy_apply(back, "alpha"), "a station start 150 tiles away takes the record back")
	legacy_check(length(back.known_recipe_nodes) == 5 && back.scholarship["mathematics"] == 50, "starving keeps every subject and all scholarship")
	var/list/strength = back.stats["strength"]
	var/list/crafting = back.stats["crafting"]
	var/list/farming = back.stats["farming"]
	legacy_check(strength[1] == 140 && crafting[1] == 180 && crafting[2] == 180, "a fifth of what each body skill had gained is lost")
	legacy_check(farming[1] == 90, "a skill below the starting level is not lowered further")
	legacy_check(!death_legacy_record("alpha"), "a record is used once")
	// A second death and return the same day costs double.
	back.nutrition = 0
	back.forceMove(locate(100, 100, 1))
	death_legacy_note(back, FALSE)
	var/mob/living/human/again = legacy_tester(100, 101, "alpha")
	again.started_with_faction = TRUE
	legacy_check(death_legacy_apply(again, "alpha"), "the second return works")
	strength = again.stats["strength"]
	legacy_check(strength[1] == 124, "the second return in a day loses two fifths")
	// A day later the record is gone.
	var/mob/living/human/late_dead = legacy_scholar(100, 100, "beta")
	late_dead.nutrition = 0
	death_legacy_note(late_dead, FALSE)
	death_legacy_test_hours += 24
	var/mob/living/human/late = legacy_tester(100, 101, "beta")
	late.started_with_faction = TRUE
	legacy_check(!death_legacy_apply(late, "beta") && !length(late.known_recipe_nodes), "a record lasts one day")
	legacy_check(late.death_weakness_left == 1800, "the weakness still applies after the record has expired")

/proc/legacy_bed_checks()
	var/now = death_legacy_now()
	var/obj/structure/bed/B = new(locate(300, 300, 1))
	B.anchored = TRUE
	B.persistence_bed_owner_ckey = "gamma"
	B.persistence_bed_assigned_at = now - 2
	var/mob/living/human/dead = legacy_scholar(310, 300, "gamma")
	dead.water = 0
	death_legacy_note(dead, FALSE)
	var/list/record = death_legacies["gamma"]
	legacy_check(!record["bed"], "a bed held for two hours does not count")
	var/mob/living/human/fresh = legacy_tester(300, 300, "gamma")
	legacy_check(!death_legacy_apply(fresh, "gamma") && !length(fresh.known_recipe_nodes), "starting at a new bed gives nothing back")
	B.persistence_bed_assigned_at = now - 30
	var/mob/living/human/dead2 = legacy_scholar(310, 300, "gamma")
	dead2.water = 0
	death_legacy_note(dead2, FALSE)
	record = death_legacies["gamma"]
	legacy_check(record["bed"] == 1, "a bed held for more than a day counts")
	var/mob/living/human/away = legacy_tester(305, 300, "gamma")
	legacy_check(!death_legacy_apply(away, "gamma"), "the character must start at the bed itself")
	// Claimed again after the death: the bed no longer counts.
	B.persistence_bed_assigned_at = death_legacy_now()
	var/mob/living/human/reclaimed = legacy_tester(300, 300, "gamma")
	legacy_check(!death_legacy_apply(reclaimed, "gamma"), "a bed claimed after the death never counts")
	B.persistence_bed_assigned_at = null
	var/mob/living/human/home = legacy_tester(300, 300, "gamma")
	legacy_check(death_legacy_apply(home, "gamma") && length(home.known_recipe_nodes) == 5, "starting at a long-held bed takes the record back with no faction")
	// A destroyed bed ends the cover.
	var/mob/living/human/dead3 = legacy_scholar(310, 300, "delta")
	var/obj/structure/bed/B2 = new(locate(300, 302, 1))
	B2.anchored = TRUE
	B2.persistence_bed_owner_ckey = "delta"
	dead3.water = 0
	death_legacy_note(dead3, FALSE)
	var/turf/spot = get_turf(B2)
	qdel(B2)
	var/mob/living/human/homeless = legacy_tester(spot.x, spot.y, "delta")
	legacy_check(!death_legacy_apply(homeless, "delta"), "a destroyed bed ends the cover")

/proc/legacy_cause_checks()
	var/mob/living/human/victim = legacy_scholar(50, 50, "epsilon")
	var/mob/living/human/killer = legacy_tester(51, 50, "zeta")
	victim.lastattacker = killer
	victim.round_fact_hit_time = world.time
	var/list/known = victim.known_recipe_nodes.Copy()
	death_legacy_note(victim, FALSE)
	var/list/record = death_legacies["epsilon"]
	legacy_check(record["cause"] == "player", "a death soon after another person's attack is a killing")
	var/mob/living/human/heir = legacy_tester(50, 51, "epsilon")
	heir.started_with_faction = TRUE
	death_legacy_apply(heir, "epsilon")
	legacy_check(length(heir.known_recipe_nodes) == 2 && heir.known_recipe_nodes[1] == known[1] && heir.known_recipe_nodes[2] == known[2], "a killing loses the three subjects learned last")
	legacy_check(heir.scholarship["mathematics"] == 40 && heir.scholarship["engineering"] == 24, "a killing loses a fifth of scholarship")
	var/list/strength = heir.stats["strength"]
	legacy_check(strength[1] == 150, "a killing leaves body skills alone")
	var/mob/living/human/own = legacy_scholar(50, 50, "eta")
	own.died_by_own_hand = TRUE
	death_legacy_note(own, FALSE)
	record = death_legacies["eta"]
	legacy_check(!record["kept"] && record["weak"] && !("nodes" in record), "a death by one's own hand keeps nothing but still weakens")
	var/mob/living/human/gone = legacy_scholar(50, 50, "theta")
	death_legacy_note(gone, TRUE)
	record = death_legacies["theta"]
	legacy_check(!record["kept"], "a destroyed body keeps nothing")

/proc/legacy_save_checks()
	var/mob/living/human/dead = legacy_scholar(120, 130, "iota")
	dead.nutrition = 0
	death_legacy_note(dead, FALSE)
	var/datum/map_storage_probe = new /map_storage
	var/map_storage/M = map_storage_probe
	var/list/capture = M.death_legacy_capture()
	var/list/decoded = json_decode(json_encode(list("death_legacy" = capture)))
	legacy_check(valid_death_legacy_record(decoded["death_legacy"]), "the saved record passes the save check")
	var/list/before = death_legacies["iota"]
	var/at = before["at"]
	death_legacies = list()
	M.death_legacy_loaded(decoded)
	var/list/after = death_legacies["iota"]
	legacy_check(islist(after) && after["at"] == at && after["x"] == 120 && after["y"] == 130 && after["cause"] == "starved", "a restart keeps when, where and why")
	legacy_check(islist(after) && length(after["nodes"]) == 5 && after["scholarship"]["mathematics"] == 50, "a restart keeps the knowledge")
	var/list/pair = islist(after) ? after["skills"]["crafting"] : null
	legacy_check(islist(pair) && pair[1] == 200, "a restart keeps the body skills")
	legacy_check(!valid_death_legacy_record(list("version" = 1, "accounts" = list("x" = list("at" = "soon")))), "a malformed record is refused")
	legacy_check(!valid_death_legacy_record(list("version" = 2, "accounts" = decoded["death_legacy"]["accounts"])), "an unknown version is refused")
	death_legacy_test_hours += 200
	death_legacy_prune()
	legacy_check(!death_legacies.len, "old records are dropped")

/proc/legacy_weakness_checks()
	var/mob/living/human/weak = legacy_tester(20, 20, "kappa")
	var/mob/living/human/other = legacy_tester(21, 20, "lambda")
	var/mob/living/simple_animal/animal = new(locate(22, 20, 1))
	legacy_check(death_weakness_scale(weak, other) == 1, "an unweakened character deals full damage")
	weak.death_weakness_left = 600
	legacy_check(death_weakness_scale(weak, other) == 0.5, "a weakened character deals half damage to people")
	legacy_check(death_weakness_scale(weak, animal) == 1, "damage to animals is not reduced")
	legacy_check(death_weakness_scale(other, weak) == 1, "others hit a weakened character as usual")
	weak.death_weakness_checked = world.time - 20
	weak.handle_death_weakness()
	legacy_check(weak.death_weakness_left == 600, "the timer waits while nobody is playing the character")
