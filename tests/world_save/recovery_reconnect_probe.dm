// Production disk save/load, transaction and reclaim with client IO adapted.
// No real client, native reboot, HUD, network or production storage is used.
var/list/recovery_fixture_clients = list()
var/recovery_fixture_loads = 0
var/recovery_fixture_late_arrived = FALSE
/mob/new_player/var/datum/recovery_fixture_client/claim_client
/mob/new_player/recovery_probe/New()
	return
/datum/recovery_fixture_client
	var/key = "FixtureAccount"
	var/ckey = "fixtureaccount"
	var/mob/mob
	var/playing_banned = FALSE
	var/server_banned = FALSE
	var/transfers = 0
/datum/recovery_fixture_client/proc/quickBan_isbanned(kind)
	return kind == "Playing" ? playing_banned : server_banned
/proc/recovery_fixture_client(account)
	var/mob/new_player/recovery_probe/L = new
	var/datum/recovery_fixture_client/C = new
	C.ckey = account
	C.key = account
	C.mob = L
	L.claim_client = C
	recovery_fixture_clients += C
	return C
/proc/recovery_fixture_transfer(datum/recovery_fixture_client/C, mob/living/human/H)
	durable_world_check(persistence_player_restore_ready && !persistence_save_in_progress && !persistence_restart.startup_hold && !persistence_restart.busy && persistence_restart.import_complete && !persistence_restart.exists(), "client transferred before recovery committed")
	durable_world_check(C.ckey == H.persistence_owner_ckey, "wrong account received body")
	C.transfers++
	C.mob = H
/map_storage/recovery_probe/register_restored_player(datum/D)
	..()
	if(istype(D, /mob/living/human) && D:persistence_owner_ckey == "latearrival" && !recovery_fixture_late_arrived)
		recovery_fixture_late_arrived = TRUE
		var/datum/recovery_fixture_client/C = recovery_fixture_client("latearrival")
		durable_world_check(!reclaim_saved_player(C.mob) && !C.transfers, "client arriving during import reclaimed early")
/datum/persistence_restart_transaction/recovery_probe
	var/fail_consume = TRUE
/datum/persistence_restart_transaction/recovery_probe/load_generation()
	recovery_fixture_loads++
	return ..()
/datum/persistence_restart_transaction/recovery_probe/consume(list/I)
	if(fail_consume) throw EXCEPTION("fixture intent consumption blocked")
	return ..()

/world/New()
	world.OpenPort(0)
	try
		// Normal global startup is disabled; real mob removal still emits these.
		GLOB.moved_event = new /decl/observ/moved
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		map_storage = new /map_storage/recovery_probe
		map_storage.record_compiled_dimensions()
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		ticker = new
		global.game_id = "recovery-reconnect-fixture"
		processes.time_of_day = new
		processes.weather = new
		var/map_type = world.params["profile"] == "europe" ? /obj/map_metadata/nomads/europe : /obj/map_metadata/nomads/gaia
		map = new map_type(locate(1,1,1))
		map.times_of_day = list("Morning", "Evening")
		times_of_day = map.times_of_day
		season = "SUMMER"
		time_of_day = "Evening"
		game_hour = 129
		for(var/account in list("fixtureaccount", "playingbanned", "serverbanned", "guest123", "latearrival", "disconnected"))
			var/mob/living/human/durable_probe_leader/H = new(locate(2,2,1))
			// A guest client is tested against a registered saved owner, since
			// durable guest ownership itself must fail validation.
			H.persistence_owner_ckey = account == "guest123" ? "guestowner" : account
			H.health = 73.25
			new /obj/item/clothing/under/loinleather(H)
			if(account == "fixtureaccount") map.faction_research_director = list("saved" = H)
		persistence_save_in_progress = TRUE
		durable_world_check(map_storage.Save_World() && map_storage.validate_world_save(), "reconnect generation export invalid")
		persistence_save_in_progress = FALSE
		var/datum/persistence_restart_transaction/recovery_probe/T = new
		persistence_restart = T
		T.publish(T.current_identity())
		durable_world_check(T.detect_startup(), "reconnect generation did not hold startup")
		var/datum/recovery_fixture_client/C = recovery_fixture_client("fixtureaccount")
		var/mob/waiting_lobby = C.mob
		var/datum/recovery_fixture_client/playing = recovery_fixture_client("playingbanned")
		playing.playing_banned = TRUE
		var/datum/recovery_fixture_client/server = recovery_fixture_client("serverbanned")
		server.server_banned = TRUE
		var/datum/recovery_fixture_client/guest = recovery_fixture_client("guestowner")
		guest.key = "Guest-123"
		var/datum/recovery_fixture_client/disconnected = recovery_fixture_client("disconnected")
		disconnected.mob = null
		durable_world_check(!map_storage.reclaim_saved_player(waiting_lobby) && !C.transfers, "waiting client reclaimed before import")
		durable_world_check(!T.resume_startup() && T.import_complete && T.startup_hold && T.exists() && recovery_fixture_loads == 1, "failed consumption released recovery or lost import")
		durable_world_check(!map_storage.finish_player_restoration() && !persistence_player_restore_ready && C.mob == waiting_lobby && !C.transfers, "failed consumption admitted waiting client")
		T.fail_consume = FALSE
		durable_world_check(T.resume_startup() && !T.startup_hold && !T.exists() && !T.busy && !persistence_save_in_progress && recovery_fixture_loads == 1, "consumption retry did not finish without reimport")
		durable_world_check(istype(C.mob, /mob/living/human) && C.mob != waiting_lobby && C.transfers == 1, "waiting authenticated client not reclaimed after recovery")
		var/mob/living/human/H = C.mob
		durable_world_check(H.persistence_owner_ckey == C.ckey && H.health == 73.25 && (locate(/obj/item/clothing/under/loinleather) in H) && map.faction_research_director["saved"] == H, "reclaimed durable identity health inventory or alias changed")
		var/datum/recovery_fixture_client/late = recovery_fixture_clients[recovery_fixture_clients.len]
		durable_world_check(recovery_fixture_late_arrived && late.ckey == "latearrival" && istype(late.mob, /mob/living/human) && late.transfers == 1, "client arriving during import not reclaimed after readiness")
		durable_world_check(!playing.transfers && !server.transfers && !guest.transfers && !disconnected.transfers, "recovery bypassed admission or stale session")
		durable_world_check(map_storage.find_restored_player("playingbanned") && map_storage.find_restored_player("serverbanned") && map_storage.find_restored_player("guestowner") && map_storage.find_restored_player("disconnected"), "rejected waiting account lost its saved claim")
		map_storage.finish_player_restoration()
		durable_world_check(C.transfers == 1 && late.transfers == 1 && !T.resume_startup() && recovery_fixture_loads == 1, "readiness repeated client transfer or import")
		playing.playing_banned = FALSE
		map_storage.finish_player_restoration()
		durable_world_check(playing.transfers == 1 && istype(playing.mob, /mob/living/human), "eligible waiting account could not reclaim retained body")
		text2file(json_encode(list("done" = !durable_probe_failed, "checks" = durable_probe_checks)), "metadata-result.json")
	catch(var/exception/e)
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "error" = "[e]")), "metadata-result.json")
	del(world)
