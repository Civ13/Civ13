// Native voice chat probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/voice/voice_chat.dm with
// real humans, walls and factions; clients are stood in for by a probe datum
// that maps bodies to Discord IDs.
/world
	hub = ""
	hub_password = ""
	maxx = 60
	maxy = 60
	maxz = 2
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
/obj/map_metadata/voice_probe/New()
	map = src
/mob/living/human/voice_tester/New()
	return
/mob/living/human/voice_tester/adaptStat(stat, amount)
	return
/turf/wall/voice_probe_wall
	opacity = 1
	density = 1
/datum/voice_chat/voice_probe
	var/list/probe_ids = list()
/datum/voice_chat/voice_probe/speaker_id(mob/M)
	return probe_ids[M]
var/voice_failures = 0
var/voice_runtime_error = FALSE
/proc/voice_check(condition, label)
	if (!condition)
		voice_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	voice_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/voice_probe
		voice_topic_checks()
		voice_volume_checks()
		voice_sight_checks()
		voice_ids_checks()
		voice_limiter_checks()
	catch(var/exception/e)
		voice_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = voice_failures, "runtime_error" = voice_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/voice_tester(x, y, z = 1)
	var/mob/living/human/H = new /mob/living/human/voice_tester(locate(x, y, z))
	H.stat = CONSCIOUS
	return H

/proc/voice_topic_checks()
	var/good = "abcdefghijklmnopqrstuvwxyzABCDEF0123456789_-"
	voice_check(voice_key_from_topic("civ13_voice=[good]") == good, "a launcher join link carries its voice key")
	voice_check(voice_key_from_topic("civ13_ticket=x&civ13_voice=[good]") == good, "next to a sign-in ticket")
	voice_check(!voice_key_from_topic("civ13_voice=short"), "a short key is ignored")
	voice_check(!voice_key_from_topic("civ13_voice=[good]%20x"), "a key with other characters is ignored")
	voice_check(!voice_key_from_topic("civ13_voice=[good][good]"), "a key over 64 characters is ignored")
	voice_check(!voice_key_from_topic(null) && !voice_key_from_topic(""), "no topic, no key")

/proc/voice_volume_checks()
	voice_check(voice_volume_at(0) == 100 && voice_volume_at(2) == 100, "right next to you is full volume")
	voice_check(voice_volume_at(5) == 75 && voice_volume_at(8) == 50 && voice_volume_at(10) == 30, "quieter with distance")
	voice_check(voice_volume_at(11) == 0 && voice_volume_at(-1) == 0 && voice_volume_at(null) == 0, "out of range is silent")

/proc/voice_sight_checks()
	var/datum/voice_chat/voice_probe/V = new
	var/mob/living/human/listener = voice_tester(10, 10)
	var/mob/living/human/near = voice_tester(12, 10)
	var/mob/living/human/far = voice_tester(19, 10)
	var/mob/living/human/beyond = voice_tester(25, 10)
	var/mob/living/human/walled = voice_tester(10, 14)
	var/mob/living/human/upstairs = voice_tester(11, 10, 2)
	var/mob/living/human/no_voice = voice_tester(11, 11)
	var/mob/living/human/knocked_out = voice_tester(9, 10)
	var/mob/living/human/corpse = voice_tester(9, 9)
	knocked_out.stat = UNCONSCIOUS
	corpse.stat = DEAD
	new /turf/wall/voice_probe_wall(locate(10, 12, 1))
	new /turf/wall/voice_probe_wall(locate(9, 12, 1))
	new /turf/wall/voice_probe_wall(locate(11, 12, 1))
	V.probe_ids[near] = "100000000000000001"
	V.probe_ids[far] = "100000000000000002"
	V.probe_ids[beyond] = "100000000000000003"
	V.probe_ids[walled] = "100000000000000004"
	V.probe_ids[upstairs] = "100000000000000005"
	V.probe_ids[knocked_out] = "100000000000000006"
	V.probe_ids[corpse] = "100000000000000007"
	V.probe_ids[listener] = "100000000000000008"
	var/list/heard = V.audible(listener)
	voice_check(heard["100000000000000001"] == 100, "a player two tiles away is full volume")
	voice_check(heard["100000000000000002"] == 30, "nine tiles away is quiet")
	voice_check(!heard["100000000000000003"], "fifteen tiles away is not heard")
	voice_check(!heard["100000000000000004"], "a player behind a wall is not heard")
	voice_check(!heard["100000000000000005"], "another level is not heard")
	voice_check(!heard["100000000000000006"], "a knocked-out player cannot talk")
	voice_check(!heard["100000000000000007"], "a dead player cannot talk")
	voice_check(!heard["100000000000000008"], "you do not hear yourself")
	voice_check(heard.len == 2, "nobody without voice is listed")
	var/list/from_knocked_out = V.audible(knocked_out)
	voice_check(from_knocked_out["100000000000000001"] == 75, "a knocked-out player still hears (three tiles)")
	voice_check(!length(V.audible(corpse)), "the dead hear nobody")
	listener.faction_text = "GERMAN"
	near.faction_text = null
	voice_check(voice_team(listener) == "GERMAN" && !voice_team(near), "the team call follows the faction")
	voice_check(!voice_team(null), "no body, no team")
	for (var/mob/M in list(listener, near, far, beyond, walled, upstairs, no_voice, knocked_out, corpse))
		qdel(M)

/proc/voice_ids_checks()
	var/datum/voice_chat/V = new
	voice_check(V.take_ids(json_encode(list("ids" = list("alpha" = "123456789012345678", "Bad Key" = "123456789012345679", "beta" = "nope")))), "the bot's answer is read")
	voice_check(V.ids["alpha"] == "123456789012345678", "a ckey gets its Discord user ID")
	voice_check(!("Bad Key" in V.ids) && !("beta" in V.ids), "malformed ckeys and IDs are dropped")
	voice_check(!V.take_ids("not json") && V.ids["alpha"], "a broken answer keeps the known IDs")
	voice_check(!V.take_ids(json_encode(list("other" = 1))) && V.ids["alpha"], "an answer without ids keeps them too")
	voice_check(V.take_ids(json_encode(list("ids" = list()))) && !length(V.ids), "an empty answer clears them")
	voice_check(voice_roster_endpoint("https://bot.example/webhook/tdm") == "https://bot.example/webhook/tdm/voice_roster", "the roster goes beside discord_verify")
	voice_check(voice_roster_endpoint("http://127.0.0.1:55555/webhook/tdm/") == "http://127.0.0.1:55555/webhook/tdm/voice_roster", "loopback works")
	voice_check(!voice_roster_endpoint("http://bot.example/webhook/tdm"), "plain http to another host never carries the key")
	voice_check(!length(V.roster()), "no voice players, empty roster")

/proc/voice_limiter_checks()
	var/datum/voice_chat/V = new
	var/key = "abcdefghijklmnopqrstuvwxyzABCDEF"
	var/list/input = list("civ13_voice_state" = key)
	var/first = V.handle_topic(input, "1.2.3.4:5000")
	var/list/answer = json_decode(first)
	voice_check(answer["v"] == 1 && answer["gen"] == 0 && answer["ready"] == -1, "an unknown key gets an empty answer")
	voice_check(V.handle_topic(input, "1.2.3.4:5001") == "", "a second call inside the interval gets nothing")
	voice_check(V.handle_topic(input, "5.6.7.8:5000") != "", "another address is not slowed down")
	voice_check(V.handle_topic(list("civ13_voice_state" = "short"), "9.9.9.9") == "", "a short key gets nothing")
	V.address_next["1.2.3.4"] = world.time - 1
	voice_check(V.handle_topic(input, "1.2.3.4:5002") != "", "after the interval it answers again")
