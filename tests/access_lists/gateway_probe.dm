// Run with the isolated ecology_spawning runner and a private TMPDIR. The
// fixture sees sibling front-door/SQL and touches only disposable files there.
/world
	hub = ""
	hub_password = ""
	maxx = 3
	maxy = 3
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/gateway_access_probe_failures = 0
var/gateway_access_probe_runtime_error = FALSE
/proc/gateway_access_probe_check(condition, label)
	if (!condition)
		gateway_access_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	gateway_access_probe_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		gateway_access_probe_run()
	catch(var/exception/e)
		gateway_access_probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = gateway_access_probe_failures, "runtime_error" = gateway_access_probe_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/gateway_access_probe_write(group, revision, approved, whitelist)
	var/path = "../front-door/SQL/verified-access.json"
	fdel(path)
	return text2file(json_encode(list("schema" = 1, "group" = group, "revision" = revision, "approved" = approved, "whitelist" = whitelist)), path)

/proc/gateway_access_probe_run()
	var/first = "alpha=990000000000000001\n"
	var/second = "beta=990000000000000002\n"
	var/legacy = "legacy=990000000000000003"
	var/path = "../front-door/SQL/verified-access.json"
	fdel(path)
	fdel("SQL/approved.txt")
	fdel("SQL/whitelist.txt")
	gateway_access_probe_check(text2file(legacy, "SQL/approved.txt") && text2file(legacy, "SQL/whitelist.txt"), "isolated legacy files are writable")
	var/list/settings = list("group" = "earth", "region" = "gaia", "gateway_verified_access" = TRUE, "regions" = list(
		list("id" = "gateway", "name" = "Gateway", "kind" = "GATEWAY", "address" = "127.0.0.1:1714"),
		list("id" = "gaia", "name" = "Gaia", "kind" = "SURFACE", "address" = "127.0.0.1:1721")))
	gateway_access_probe_check(shard_group.configure(json_encode(settings)) && gateway_access_enabled(), "configured game reader selects gateway authority")
	gateway_access_probe_check(!reload_verified_access_list("approved") && !verified_access_member("approved", "legacy"), "missing authority does not fall back to a regional grant")
	gateway_access_probe_check(gateway_access_probe_write("earth", 1, first, second), "isolated authority fixture is writable")
	gateway_access_probe_check(reload_gateway_verified_access(TRUE) && approved_list_ready && whitelist_list_ready, "a forced read accepts one complete pair")
	gateway_access_probe_check(verified_access_member("approved", "alpha") && verified_discord_id("alpha") == "990000000000000001" && verified_access_member("whitelist", "beta"), "reader publishes both lists and the lexical Discord ID")
	gateway_access_probe_write("earth", 2, "\n", "\n")
	gateway_access_probe_check(reload_gateway_verified_access(TRUE) && approved_list_ready && whitelist_list_ready && !verified_access_member("approved", "alpha") && !verified_access_member("whitelist", "beta"), "forced warm read immediately revokes both grants while marking an explicit empty pair ready")
	gateway_access_probe_write("earth", 1, first, second)
	gateway_access_probe_check(!reload_gateway_verified_access(TRUE) && !approved_list_ready && !whitelist_list_ready && !approved_list.len && !whitelist_list.len, "rollback clears both sets and denies their prior grants")
	gateway_access_probe_write("earth", 3, first, "incomplete")
	gateway_access_probe_check(!reload_gateway_verified_access(TRUE) && !verified_access_member("approved", "alpha"), "an invalid second half never admits the first half")
	gateway_access_probe_write("tdm", 3, first, second)
	gateway_access_probe_check(!reload_gateway_verified_access(TRUE), "reader rejects another group's valid bundle")
	gateway_access_probe_write("earth", 3, first, second)
	gateway_access_probe_check(reload_gateway_verified_access(TRUE) && verified_access_member("approved", "alpha"), "a fresh valid revision restores grants")
	gateway_access_probe_write("earth", 3, second, first)
	gateway_access_probe_check(!reload_gateway_verified_access(TRUE) && !verified_access_member("approved", "beta"), "a changed pair at an already loaded revision is refused")
	settings["gateway_verified_access"] = FALSE
	gateway_access_probe_check(shard_group.configure(json_encode(settings)) && !gateway_access_enabled() && reload_verified_access_list("approved") && verified_access_member("approved", "legacy"), "opted-out game reader retains legacy admission behavior")
