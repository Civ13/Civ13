// Test-only adapter. The runner inserts dispatch before ordinary Topic logging.
// Startup, serialization, restart and recovery remain production procedures.
var/global/full_map_probe_session = md5("[world.realtime]-[rand(1, 1000000000)]")
var/global/full_map_probe_start_requested = FALSE
var/global/full_map_probe_restart_requested = FALSE
var/global/full_map_probe_setup_done = FALSE
var/global/list/full_map_probe_nature_done = list()

/world/IsBanned(key, address, computer_id, type)
	// This headless recovery host never admits a player session.
	return list("reason" = "isolated recovery probe", "message" = "Offline recovery test host")

/proc/full_map_probe_ready()
	return full_map_probe_setup_done && full_map_probe_nature_done.len == 4 && ticker && ticker.current_state == GAME_STATE_PLAYING

/proc/full_map_probe_record_generation()
	// Synchronous receipt immediately before the unchanged native reboot call.
	var/list/I = persistence_restart.current_identity()
	I["fixture"] = full_map_probe_fixture_status()
	I["status"] = full_map_probe_status()
	var/list/files = list()
	for(var/name in flist("map_saves/"))
		if(name == "map.txt" || name == "round.json" || name == "save_complete.txt" || copytext(name, max(1, length(name)-3)) == ".sav")
			files[name] = md5(file("map_saves/[name]"))
	I["files_md5"] = files
	if(fexists("full-map-before-reboot.json") || !text2file(json_encode(I), "full-map-before-reboot.json"))
		throw EXCEPTION("Full-map probe could not preserve its pre-reboot receipt")

/proc/full_map_probe_fixture_status()
	if(!fexists("full-map-fixture.json")) return list("seeded" = FALSE)
	var/list/F = json_decode(file2text("full-map-fixture.json"))
	var/turf/T = locate(F["x"], F["y"], F["z"])
	var/crates = 0
	var/knives = 0
	for(var/obj/structure/closet/crate/C in T)
		if(C.name != F["crate"]) continue
		crates++
		for(var/obj/item/weapon/material/kitchen/utensil/knife/K in C)
			if(K.name == F["knife"]) knives++
	return list("seeded" = TRUE, "crates" = crates, "nested_knives" = knives, "baseline" = F)

/proc/full_map_probe_seed()
	for(var/attempt = 1, attempt <= 12000, attempt++)
		if(full_map_probe_ready()) break
		sleep(1)
	if(!full_map_probe_ready() || fexists("full-map-fixture.json")) return
	var/turf/T = locate(20,20,1)
	if(!T) return
	var/obj/structure/closet/crate/C = new(T)
	C.name = "full-map-probe-[full_map_probe_session]-crate"
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(C)
	K.name = "full-map-probe-[full_map_probe_session]-knife"
	text2file(json_encode(list("x" = T.x, "y" = T.y, "z" = T.z, "crate" = C.name, "knife" = K.name, "game_id" = game_id, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "season" = season, "time_of_day" = time_of_day, "research_clock" = map.research_time())), "full-map-fixture.json")

/hook/startup/proc/full_map_probe_isolation()
	config.webhook_can_fire = FALSE
	config.ToRban = FALSE
	world.visibility = FALSE
	return TRUE

/proc/full_map_probe_status()
	return list("source" = world.params["tested_commit"], "session" = full_map_probe_session, "map" = map ? map.ID : null, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "state" = ticker ? ticker.current_state : -1, "playing" = ticker && ticker.current_state == GAME_STATE_PLAYING, "ready" = full_map_probe_ready(), "nature_passes" = full_map_probe_nature_done.len, "setup_done" = full_map_probe_setup_done, "clients" = clients.len, "start_requested" = full_map_probe_start_requested, "restart_requested" = full_map_probe_restart_requested, "game_id" = game_id, "world_time" = world.time, "season" = season, "time_of_day" = time_of_day, "research_clock" = map ? map.research_time() : 0, "save_busy" = persistence_save_in_progress, "restart_busy" = persistence_restart.busy, "restart_hold" = persistence_restart.startup_hold, "import_complete" = persistence_restart.import_complete, "intent" = persistence_restart.exists(), "generation" = trim(file2text("map_saves/save_complete.txt")), "error" = persistence_restart.last_error, "storage_error" = map_storage.last_error, "fixture" = full_map_probe_fixture_status())

/proc/full_map_probe_topic(query, address)
	var/list/host = splittext(address, ":")
	if(host.len > 2 || host[1] != "127.0.0.1") return "rejected"
	if(host.len == 2 && (!length(host[2]) || "[text2num(host[2])]" != host[2] || text2num(host[2]) < 1 || text2num(host[2]) > 65535)) return "rejected"
	var/list/input = params2list(query)
	var/token = trim(file2text("config/full-map-probe-token.txt"))
	if(length(token) != 64 || input.len != 4 || input["full_map_probe"] != "1" || input["token"] != token) return "rejected"
	if(input["action"] == "status" && input["session"] == "observe") return json_encode(full_map_probe_status())
	if(input["session"] != full_map_probe_session || persistence_restart.busy || persistence_restart.startup_hold || persistence_save_in_progress || persistence_restart.exists()) return "rejected"
	if(input["action"] == "start")
		if(!ticker || ticker.current_state != GAME_STATE_PREGAME || !ticker.pregame_timeleft || full_map_probe_start_requested) return "rejected"
		full_map_probe_start_requested = TRUE
		// These are the existing admin Start Now inputs. The ordinary pregame
		// scheduler performs setup and changes current_state itself.
		round_progressing = TRUE
		ticker.pregame_timeleft = 1
		ticker.admin_started = TRUE
		spawn(0)
			full_map_probe_seed()
		return json_encode(full_map_probe_status())
	if(input["action"] == "restart")
		if(!full_map_probe_ready() || full_map_probe_restart_requested || !persistence_restart.supported()) return "rejected"
		var/list/fixture = full_map_probe_fixture_status()
		if(!fixture["seeded"] || fixture["crates"] != 1 || fixture["nested_knives"] != 1) return "rejected"
		full_map_probe_restart_requested = TRUE
		spawn(0)
			persistence_restart.execute()
		return json_encode(full_map_probe_status())
	return "rejected"
