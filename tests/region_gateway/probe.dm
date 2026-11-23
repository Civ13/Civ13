// Gateway region fixture: the real region_gateway.dm, shard_group.dm and
// region_home.dm procs on a small world with a hand-made group. The transfer
// agent is a stub subtype that answers /account with canned verdicts. No client
// joins: the login forward, the relay route and the link are not driven.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	area = /area/caribbean
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Closed gateway region fixture"

var/global/list/gateway_probe_checks = list()
var/global/list/gateway_probe_failed = list()
var/global/gateway_probe_runtime_error = FALSE

/world/Error(exception/E)
	gateway_probe_runtime_error = TRUE
	world.log << "Unexpected fixture runtime: [E] at [E.file]:[E.line]"
	return ..()

/proc/gateway_probe_check(label, passed)
	gateway_probe_checks += list(list("label" = label, "passed" = !!passed))
	if (!passed)
		gateway_probe_failed += label

// The gateway's transfer agent: the next /account answer, and what was asked.
/datum/transfer_bridge/gateway_probe
	var/list/next_answer = null
	var/list/asked = list()

/datum/transfer_bridge/gateway_probe/enabled()
	return TRUE

/datum/transfer_bridge/gateway_probe/request(path, list/body)
	asked += list(list("path" = path, "body" = body))
	if (path == "/chart/request")
		return list("ok" = TRUE, "result" = list())
	return next_answer

/proc/gateway_probe_group(region)
	return json_encode(list("group" = "earth", "region" = region, "mainland" = "gaia", "start_region" = "gaia",
		"regions" = list(
			list("id" = "gateway", "name" = "Gateway", "kind" = "GATEWAY", "address" = "play.example:1714"),
			list("id" = "gaia", "name" = "Gaia", "kind" = "SURFACE", "address" = "play.example:1771"),
			list("id" = "northamerica", "name" = "North America", "kind" = "SURFACE", "address" = "play.example:1744"),
			list("id" = "tutorial", "name" = "Tutorial", "kind" = "TUTORIAL", "address" = "play.example:1760"))))

/proc/gateway_probe_answer(verdict, home)
	return list("ok" = TRUE, "result" = list("verdict" = verdict, "home" = home))

/proc/gateway_probe_run()
	makeDatumRefLists()
	var/datum/transfer_bridge/gateway_probe/bridge = new
	transfer_bridge = bridge

	gateway_probe_check("config/accepts_gateway", shard_group.configure(gateway_probe_group("gateway")) && shard_group.kind == "GATEWAY")
	gateway_probe_check("here", region_gateway_here())
	gateway_probe_check("kind_text", shard_kind_text("GATEWAY", "gateway") == "gateway")

	// Every account goes on: the home the agent names, or the start region for a new one.
	bridge.next_answer = gateway_probe_answer("ELSEWHERE", "northamerica")
	var/list/where = region_gateway_destination("Somebody")
	gateway_probe_check("home/elsewhere", where["home"] == "northamerica")
	var/list/sent = bridge.asked[bridge.asked.len]
	gateway_probe_check("home/claim_without_body", sent["path"] == "/account" && sent["body"]["op"] == "claim" && sent["body"]["ckey"] == "somebody" && isnull(sent["body"]["body"]))
	bridge.next_answer = gateway_probe_answer("ELSEWHERE", "gaia")
	where = region_gateway_destination("Newcomer")
	gateway_probe_check("home/new_player_start_region", where["home"] == "gaia")
	bridge.next_answer = gateway_probe_answer("PENDING", null)
	where = region_gateway_destination("Somebody")
	gateway_probe_check("wait/pending", isnull(where["home"]) && findtext(where["wait"], "settled"))
	bridge.next_answer = gateway_probe_answer("TRAVELLING", "northamerica")
	where = region_gateway_destination("Somebody")
	gateway_probe_check("wait/travelling", isnull(where["home"]) && findtext(where["wait"], "on its way"))
	bridge.next_answer = null
	where = region_gateway_destination("Somebody")
	gateway_probe_check("wait/agent_silent", isnull(where["home"]) && findtext(where["wait"], "not answering"))
	bridge.next_answer = gateway_probe_answer("ELSEWHERE", "atlantis")
	where = region_gateway_destination("Somebody")
	gateway_probe_check("wait/unknown_home", isnull(where["home"]) && findtext(where["wait"], "not known"))
	bridge.next_answer = gateway_probe_answer("HOME", "gateway")
	where = region_gateway_destination("Somebody")
	gateway_probe_check("wait/home_here_is_a_mistake", isnull(where["home"]) && findtext(where["wait"], "admin"))
	bridge.next_answer = gateway_probe_answer("ELSEWHERE", "land:3,4")
	var/before = bridge.asked.len
	where = region_gateway_destination("Sailor")
	sent = bridge.asked[bridge.asked.len]
	gateway_probe_check("wait/parked_land_summoned", isnull(where["home"]) && bridge.asked.len == before + 2 && sent["path"] == "/chart/request" && sent["body"]["op"] == "summon")
	before = bridge.asked.len
	where = region_gateway_destination("Guest-12345")
	gateway_probe_check("guest/start_region_unasked", where["home"] == "gaia" && bridge.asked.len == before)

	// Nobody plays here, not even a guest.
	var/mob/new_player/lobby = new
	gateway_probe_check("join/refused", !region_home_admit(lobby))
	qdel(lobby)

	// While a land cannot be reached, the practice rooms are offered when the tutorial is up,
	// and the gateway never opens in-world rooms of its own.
	var/list/tutorial = shard_group.peers["tutorial"]
	tutorial["state"] = "DOWN"
	gateway_probe_check("practice/none_without_tutorial", region_gateway_practice_link() == "" && !practice_room_available())
	tutorial["state"] = "UP"
	gateway_probe_check("practice/offered", findtext(region_gateway_practice_link(), "gateway_practice=1") && tutorial_region_peer() == "tutorial" && practice_room_available())

	// Unchecked peers are not a confirmed zero at startup.
	gateway_probe_check("hub/unchecked", !findtext(region_gateway_hub_status(), "Players across regions"))
	shard_group.record("gaia", list("group" = "earth", "region" = "gaia", "map" = "Gaia", "players" = 3), world.time)
	shard_group.record("northamerica", list("group" = "earth", "region" = "northamerica", "players" = 2), world.time)
	shard_group.record("tutorial", list("group" = "earth", "region" = "tutorial", "players" = 1), world.time)
	var/list/population = region_gateway_population()
	gateway_probe_check("players/across_regions", population["players"] == 6 && population["unknown"] == 0)
	var/hub = region_gateway_hub_status()
	gateway_probe_check("hub/mainland_and_players", findtext(hub, "Mainland:") && findtext(hub, "Gaia") && findtext(hub, "Players across regions:</b> 6<br>"))

	// A TDM front door names the battle map instead of the waiting room.
	tutorial["kind"] = "BATTLE"
	shard_group.record("tutorial", list("group" = "earth", "region" = "tutorial", "map" = "Karak", "players" = 1), world.time)
	hub = region_gateway_hub_status()
	gateway_probe_check("hub/battle_map", findtext(hub, "<b>Battle:</b> Karak<br>") && !findtext(hub, "Mainland:"))
	tutorial["kind"] = "TUTORIAL"
	gateway_probe_check("hub/mainland_again", findtext(region_gateway_hub_status(), "<b>Mainland:</b> Gaia<br>"))

	shard_group.record_sleeping("tutorial", list("state" = "asleep"), world.time)
	gateway_probe_check("players/sleeping_zero", region_gateway_population()["players"] == 5 && region_gateway_population()["unknown"] == 0)
	shard_group.record_sleeping("northamerica", list("state" = "stopped"), world.time)
	gateway_probe_check("players/stopped_zero", region_gateway_population()["players"] == 3 && region_gateway_population()["unknown"] == 0)
	shard_group.record_sleeping("tutorial", list("state" = "waking"), world.time)
	gateway_probe_check("hub/partial_waking", findtext(region_gateway_hub_status(), "Players across regions:</b> 3<br>"))
	shard_group.record("northamerica", list("group" = "other", "region" = "northamerica", "players" = 50), world.time)
	gateway_probe_check("hub/partial_mismatch", findtext(region_gateway_hub_status(), "Players across regions:</b> 3<br>") && region_gateway_population()["unknown"] == 2)
	shard_group.record("gaia", list("group" = "earth", "region" = "gaia", "players" = 99), world.time - (4 MINUTES))
	gateway_probe_check("hub/stale_unavailable", region_gateway_population()["players"] == 0 && !findtext(region_gateway_hub_status(), "Players across regions"))
	shard_group.record("gaia", list("group" = "earth", "region" = "gaia", "players" = -5), world.time)
	shard_group.record("northamerica", list("group" = "earth", "region" = "northamerica", "players" = 0.5), world.time)
	gateway_probe_check("players/invalid_ignored", region_gateway_population()["unknown"] == 3)
	shard_group.record("gaia", list("group" = "earth", "region" = "gaia", "players" = 0), world.time)
	shard_group.record_sleeping("northamerica", list("state" = "asleep", "cold" = TRUE), world.time)
	shard_group.record_sleeping("tutorial", list("state" = "stopped"), world.time)
	gateway_probe_check("hub/confirmed_zero", findtext(region_gateway_hub_status(), "Players across regions:</b> 0<br>"))

	// Seen from a land: no Join link, no trail, nobody sent there.
	gateway_probe_check("config/land_view", shard_group.configure(gateway_probe_group("gaia")) && !region_gateway_here())
	var/list/peer = shard_group.peers["gateway"]
	peer["state"] = "UP"
	shard_group.peers["northamerica"]["state"] = "UP"
	var/panel = shard_group.panel_html()
	gateway_probe_check("panel/no_join", !findtext(panel, "play.example:1714") && findtext(panel, "play.example:1744"))
	var/list/trails = region_trail_peer_choices()
	gateway_probe_check("trails/none", !("gateway" in trails.Copy()) && !trails.Find("Gateway (gateway)") && trails.Find("North America (northamerica)"))
	gateway_probe_check("admin_send/refused", findtext(region_admin_send_kind_refusal(peer), "never keeps a character"))
	shard_group.enabled = FALSE

/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	gateway_probe_run()
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = gateway_probe_checks.len, "failed_labels" = gateway_probe_failed, "runtime_error" = gateway_probe_runtime_error, "checks" = gateway_probe_checks)), "result.json")
	world.log << "COMPLETE gateway region fixture"
	del(world)
