// No saver, generation validator, Topic dispatch or native exit adapters.
// Normal startup and human physiology remain disabled in this tiny world.
var/lifecycle_disk_operation
var/lifecycle_disk_session
/datum/persistence_restart_transaction/disk_probe/request_shutdown()
	var/list/I = read_intent()
	durable_world_check(matches(I, current_identity()), "disk intent lost completed generation")
	durable_world_check(I["lifecycle_operation"] == lifecycle_disk_operation && I["lifecycle_session"] == lifecycle_disk_session, "disk intent lost acknowledged request binding")
	durable_world_check(fexists("map_saves/1.sav") && fexists("map_saves/2.sav") && fexists("map_saves/round.json"), "disk generation files incomplete")
	text2file(json_encode(list("done" = !durable_probe_failed, "checks" = durable_probe_checks, "intent_hash" = md5(file2text(intent_path)), "generation" = I["generation"])), "metadata-result.json")
	return ..()
/world/New()
	world.OpenPort(0)
	try
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		ticker = new
		ticker.current_state = GAME_STATE_PLAYING
		processes.time_of_day = new
		processes.weather = new
		global.game_id = "lifecycle-disk-fixture"
		map_storage.record_compiled_dimensions()
		var/map_type = world.params["profile"] == "europe" ? /obj/map_metadata/nomads/europe : /obj/map_metadata/nomads/gaia
		map = new map_type(locate(1,1,1))
		map.times_of_day = list("Morning", "Evening")
		times_of_day = map.times_of_day
		season = "SUMMER"
		time_of_day = "Evening"
		var/mob/living/human/durable_probe_leader/H = new(locate(2,2,2))
		H.persistence_owner_ckey = "lifecyclefixture"
		new /obj/item/clothing/under/loinleather(H)
		map.faction_research_director = list("saved" = H)
		persistence_restart = new /datum/persistence_restart_transaction/disk_probe
		var/fixture_token = md5("offline-fixture-token")
		text2file(fixture_token, "config/lifecycle-token.txt")
		text2file("0123456789abcdef0123456789abcdef01234567", "config/lifecycle-revision.txt")
		var/list/request = list("nomads_lifecycle" = "1", "token" = "incorrect", "action" = "status")
		var/list/R = json_decode(world.Topic(list2params(request), "127.0.0.1:12345", null, null))
		durable_world_check(!R["ok"], "production Topic accepted wrong token")
		request["token"] = fixture_token
		R = json_decode(world.Topic(list2params(request), "127.0.0.1:12345", null, null))
		durable_world_check(R["ok"] && R["ready"] && R["map"] == map.ID, "production Topic status failed")
		durable_world_check(!("token" in R), "production Topic status leaked token")
		lifecycle_disk_session = R["session"]
		lifecycle_disk_operation = md5("offline-fixture-operation")
		request["action"] = "save_shutdown"
		request["session"] = lifecycle_disk_session
		request["operation"] = lifecycle_disk_operation
		R = json_decode(world.Topic(list2params(request), "127.0.0.1:12345", null, null))
		durable_world_check(R["ok"] && R["busy"] && R["operation"] == lifecycle_disk_operation, "production Topic mutation not reserved")
		spawn(300)
			text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "error" = "native shutdown did not exit")), "metadata-result.json")
			del(world)
	catch(var/exception/e)
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "error" = "[e]")), "metadata-result.json")
		del(world)
