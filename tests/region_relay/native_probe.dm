// Headless routing relay probe. Test-only: native_probe.py appends it to a
// temporary copy of civ13.dme and runs scripts/gaia-host/relay.py beside it.
// It checks that a world reads the relay settings, writes and reads routes
// through the relay's control port with world.Export, and refuses what the
// relay refuses. No client connects; the relay never pipes anything here.
var/global/datum/region_relay_probe/region_relay_probe = new

/datum/region_relay_probe
	var/list/checks = list()
	var/phase = "startup"

/datum/region_relay_probe/New()
	spawn(50)
		drive()

/datum/region_relay_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/region_relay_probe/proc/require(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/datum/region_relay_probe/proc/group_json(relay)
	var/list/settings = list("group" = "probe", "region" = "gaia", "mainland" = "gaia",
		"regions" = list(list("id" = "gaia", "name" = "Gaia", "kind" = "SURFACE", "address" = "127.0.0.1:1720"),
			list("id" = "deep", "name" = "The Deep", "kind" = "UNDERGROUND", "address" = "127.0.0.1:1721")))
	if (relay)
		settings["relay"] = "203.0.113.5:[relay]"
		settings["relay_control"] = "127.0.0.1:[file2text("relay_control_port.txt")]"
		settings["gate"] = "gaia"
	return json_encode(settings)

/datum/region_relay_probe/proc/drive()
	var/failure = null
	var/failed_phase = null
	try
		phase = "off"
		require(shard_group.configure(group_json(0)), "plain group config refused: [shard_group.last_error]")
		require(!shard_group.relay_on(), "relay on without settings")
		require(shard_group.player_href("deep") == "byond://127.0.0.1:1721", "direct link: [shard_group.player_href("deep")]")
		pass("relay_off_links_direct")

		phase = "configure"
		require(shard_group.configure(group_json(1730)), "relay group config refused: [shard_group.last_error]")
		require(shard_group.relay_on(), "relay settings not read")
		require(shard_group.player_href("deep") == "byond://?region_go=deep", "relay link: [shard_group.player_href("deep")]")
		require(shard_group.gate_address() == "127.0.0.1:1720", "gate address: [shard_group.gate_address()]")
		pass("relay_settings")

		phase = "route"
		var/list/reply = shard_group.ask_relay("route=1&ip=198.51.100.7&ckey=alice&port=1720")
		require(reply && reply["ok"], "route refused: [json_encode(reply)]")
		reply = shard_group.ask_relay("lookup=1&ckey=alice")
		require(reply && reply["ok"] && reply["ip"] == "198.51.100.7" && reply["port"] == 1720, "lookup: [json_encode(reply)]")
		reply = shard_group.ask_relay("route=1&ip=198.51.100.8&ckey=bob&port=1721")
		require(reply && reply["ok"], "peer route refused")
		reply = shard_group.ask_relay("lookup=1&ckey=bob")
		require(reply && reply["port"] == 1721, "peer lookup: [json_encode(reply)]")
		pass("route_and_lookup")

		phase = "refusals"
		reply = shard_group.ask_relay("route=1&ip=198.51.100.7&ckey=alice&port=1729")
		require(reply && !reply["ok"], "route to a foreign port: [json_encode(reply)]")
		var/token = shard_group.relay_token
		shard_group.relay_token = "00000000000000000000000000000000"
		reply = shard_group.ask_relay("lookup=1&ckey=alice")
		shard_group.relay_token = token
		require(isnull(reply), "wrong token answered: [json_encode(reply)]")
		fdel("config/relay-token.txt")
		require(shard_group.configure(group_json(1730)), "group refused without a relay token")
		require(!shard_group.relay_on(), "relay on without its token")
		pass("refusals")
	catch (var/exception/e)
		failure = "[e.name]"
		failed_phase = phase
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks)
	text2file(json_encode(result), "result.json")
	sleep(1)
	del(world)
