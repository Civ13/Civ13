// Server-wide agent actions. See agent_control.dm for transport and scopes.

/datum/agent_control/proc/act_discover(datum/agent_identity/A, list/req)
	var/list/available = list()
	for (var/name in agent_control_actions())
		var/list/spec = agent_control_actions()[name]
		available[name] = list("scope" = spec["scope"], "allowed" = A.has_scope(spec["scope"]) ? TRUE : FALSE)
	return list("agent" = A.name, "scopes" = A.scopes.Copy(), "rights" = rights2text(A.rights), "allow_handover" = allow_handover, "max_characters" = max_characters, "actions" = available)

/datum/agent_control/proc/act_status(datum/agent_identity/A, list/req)
	audit_read(A, "status")
	var/list/out = list()
	out["world"] = list("name" = world.name, "port" = world.port, "time" = world.time, "timeofday" = world.timeofday, "realtime" = world.realtime, "cpu" = world.cpu, "tick_usage" = world.tick_usage, "tick_lag" = world.tick_lag, "fps" = world.fps, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz)
	out["players"] = clients.len
	out["admins"] = admins.len
	out["round_id"] = game_id
	out["round_duration"] = roundduration2text()
	out["round_ticks"] = round_start_time ? world.time - round_start_time : 0
	out["game_state"] = ticker ? ticker.current_state : null
	if (map)
		out["map"] = list("title" = map.title, "id" = map.ID, "age" = map.age, "gamemode" = map.gamemode, "nomads" = map.nomads ? TRUE : FALSE, "civilizations" = map.civilizations ? TRUE : FALSE)
	out["season"] = season
	out["time_of_day"] = time_of_day
	out["persistence"] = list("save_in_progress" = persistence_save_in_progress ? TRUE : FALSE, "restart_busy" = persistence_restart.busy ? TRUE : FALSE)
	out["agent_characters"] = agent_characters.len
	return out

/datum/agent_control/proc/act_players(datum/agent_identity/A, list/req)
	audit_read(A, "players")
	var/list/out = list()
	for (var/client/C in clients)
		var/list/row = list("ckey" = C.ckey, "key" = C.key, "inactivity" = C.inactivity)
		if (C.holder)
			row["admin_rank"] = C.holder.rank
		var/mob/M = C.mob
		if (M)
			row["mob"] = agent_encode(M)
			row["stat"] = M.stat
			if (istype(M, /mob/living))
				var/mob/living/L = M
				row["health"] = L.health
			var/area/area = get_area(M)
			if (area)
				row["area"] = area.name
			row["agent_controlled"] = agent_characters[M] ? TRUE : FALSE
		out += list(row)
	return out

/datum/agent_control/proc/act_inspect(datum/agent_identity/A, list/req)
	var/datum/D = agent_resolve_target(req["target"])
	audit_read(A, "inspect", "[req["target"]]")
	if (D == "global")
		agent_fail("bad_target", "use get_vars for globals")
	var/list/out = agent_encode(D)
	if (isatom(D))
		var/atom/AT = D
		out["desc"] = AT.desc
		out["density"] = AT.density
		out["loc"] = agent_encode(AT.loc)
		var/area/area = get_area(AT)
		if (area)
			out["area"] = area.name
		var/list/contents = list()
		for (var/atom/movable/M in AT.contents)
			if (contents.len >= AGENT_CONTROL_MAX_LIST)
				break
			contents += list(agent_encode(M))
		out["contents"] = contents
		out["contents_len"] = AT.contents.len
		if (ismob(AT))
			var/mob/M = AT
			out["ckey"] = M.ckey
			out["stat"] = M.stat
			out["agent_controlled"] = agent_characters[M] ? TRUE : FALSE
			if (istype(M, /mob/living))
				var/mob/living/L = M
				out["health"] = L.health
				out["max_health"] = L.maxHealth
	return out

/datum/agent_control/proc/act_look(datum/agent_identity/A, list/req)
	var/turf/center = agent_resolve_target(req["target"])
	center = get_turf(center)
	if (!center)
		agent_fail("bad_target", "target has no turf")
	var/radius_value = text2num("[req["radius"]]")
	var/radius = clamp(round(isnull(radius_value) ? 3 : radius_value), 0, 7)
	audit_read(A, "look", "[center.x],[center.y],[center.z] r[radius]")
	var/list/turfs = list()
	var/count = 0
	for (var/turf/T in block(locate(max(1, center.x - radius), max(1, center.y - radius), center.z), locate(min(world.maxx, center.x + radius), min(world.maxy, center.y + radius), center.z)))
		var/list/row = list("x" = T.x, "y" = T.y, "type" = "[T.type]", "name" = T.name, "density" = T.density)
		var/list/things = list()
		for (var/atom/movable/M in T)
			if (M.invisibility > 0 || ++count > 256)
				continue
			things += list(list("ref" = agent_ref(M), "type" = "[M.type]", "name" = M.name, "density" = M.density))
		if (things.len)
			row["contents"] = things
		turfs += list(row)
	return list("center" = list(center.x, center.y, center.z), "radius" = radius, "turfs" = turfs, "truncated" = count > 256)

/datum/agent_control/proc/act_find(datum/agent_identity/A, list/req)
	var/path = text2path("[req["type"]]")
	if (!ispath(path, /atom))
		agent_fail("bad_type", "type must be an atom path")
	var/z = text2num("[req["z"]]")
	var/limit = clamp(round(text2num("[req["limit"]]") || 50), 1, 200)
	var/name_filter = istext(req["name"]) ? lowertext(req["name"]) : null
	audit_read(A, "find", "[path] z=[z] limit=[limit]")
	var/list/out = list()
	var/list/source = ispath(path, /mob) ? mob_list : world
	var/scanned = 0
	var/scan_capped = FALSE
	for (var/atom/AT in source)
		// Bound one request's work; the whole Gaia world is about 400k turfs.
		if (++scanned > 500000)
			scan_capped = TRUE
			break
		if (!istype(AT, path))
			continue
		if (z && AT.z != z)
			continue
		if (name_filter && !findtext(lowertext(AT.name), name_filter))
			continue
		out += list(agent_encode(AT))
		if (out.len >= limit)
			break
	return list("results" = out, "limited" = out.len >= limit || scan_capped, "scan_capped" = scan_capped)

/datum/agent_control/proc/act_logs(datum/agent_identity/A, list/req)
	var/count = clamp(round(text2num("[req["count"]]") || 50), 1, 200)
	audit_read(A, "logs", "[count]")
	var/start = max(1, admin_log.len - count + 1)
	var/list/out = list()
	for (var/i = start, i <= admin_log.len, i++)
		out += agent_plain_text(admin_log[i])
	return list("admin_log" = out)

/datum/agent_control/proc/act_job(datum/agent_identity/A, list/req)
	var/datum/agent_job/J = jobs["[req["job"]]"]
	if (!J || J.agent != A.name)
		agent_fail("not_found", "no such job")
	if (J.done)
		jobs -= J.id
	return J.report()

// ---------------------------------------------------------------------------
// Variables

// Agent control's own state (tokens, scopes, proxy rights) is never readable
// or writable through the API, whatever scopes an agent holds.
/proc/agent_protected_target(target)
	if (istype(target, /datum/agent_control) || istype(target, /datum/agent_identity) || istype(target, /mob/agent_proxy) || istype(target, /datum/agent_job))
		return TRUE
	if (istype(target, /datum/admins))
		for (var/name in agent_control.agents)
			var/datum/agent_identity/I = agent_control.agents[name]
			if (I.proxy && I.proxy.agent_holder == target)
				return TRUE
	return FALSE

/proc/agent_protected_var(name)
	return name in list("agent_control", "agent_characters", "address", "computer_id", "lastKnownIP", "token")

/proc/agent_vars_of(target)
	if (target == "global")
		return global.vars
	if (target == world)
		agent_fail("bad_target", "world variables are reported by status")
	if (agent_protected_target(target))
		agent_fail("forbidden", "agent control state is not accessible to agents")
	if (istype(target, /datum) || istype(target, /client))
		var/datum/D = target
		return D.vars
	agent_fail("bad_target", "target has no variables")

/datum/agent_control/proc/act_get_vars(datum/agent_identity/A, list/req)
	var/target = agent_resolve_target(req["target"])
	var/list/V = agent_vars_of(target)
	var/list/names = req["names"]
	audit_read(A, "get_vars", "[req["target"]] [islist(names) ? jointext(names, ",") : "all"]")
	var/list/out = list()
	if (islist(names))
		if (names.len > 100)
			agent_fail("bad_args", "at most 100 names")
		for (var/name in names)
			if (agent_protected_var(name))
				out[name] = list("protected" = TRUE)
			else if (!(name in V))
				out[name] = list("missing" = TRUE)
			else
				out[name] = agent_encode(V[name])
	else
		// Every variable, with lists and objects summarised to stay bounded.
		for (var/name in V)
			if (agent_protected_var(name))
				continue
			var/value = V[name]
			out[name] = islist(value) ? list("list_len" = length(value)) : agent_encode(value, 2)
	return list("target" = target == "global" ? "global" : agent_encode(target), "vars" = out)

/proc/agent_locked_var(name)
	return (name in VVlocked) || (name in list("type", "parent_type", "vars", "ckey", "key", "computer_id", "lastKnownIP"))

/datum/agent_control/proc/act_set_var(datum/agent_identity/A, list/req)
	var/target = agent_resolve_target(req["target"])
	var/name = req["name"]
	if (!istext(name))
		agent_fail("bad_args", "name is required")
	if (agent_locked_var(name) || agent_protected_var(name))
		agent_fail("locked_var", "[name] cannot be edited by agents")
	var/list/V = agent_vars_of(target)
	if (!(name in V))
		agent_fail("missing_var", "no variable [name]")
	if (!("value" in req))
		agent_fail("bad_args", "value is required (null is allowed)")
	var/value = agent_decode(req["value"])
	var/old = V[name]
	var/target_text = target == "global" ? "global" : "[target] ([agent_ref(target)])"
	if (target == "global")
		global.vars[name] = value
	else
		var/datum/D = target
		D.vars[name] = value
	audit(A, "set_var", "[target_text].[name]: [agent_plain_text("[old]")] -> [agent_plain_text("[value]")]")
	return list("name" = name, "old" = agent_encode(old), "new" = agent_encode(target == "global" ? global.vars[name] : V[name]))

// ---------------------------------------------------------------------------
// Procs and admin verbs

/proc/agent_decode_arguments(list/raw)
	var/list/arguments = list()
	if (isnull(raw))
		return arguments
	if (!islist(raw))
		agent_fail("bad_args", "arguments must be a list")
	if (raw.len > 16)
		agent_fail("bad_args", "at most 16 arguments")
	for (var/item in raw)
		arguments += list(agent_decode(item))
	return arguments

/datum/agent_control/proc/act_call_proc(datum/agent_identity/A, list/req)
	var/procname = req["proc"]
	if (!istext(procname) || !length(procname))
		agent_fail("bad_args", "proc is required")
	var/target = isnull(req["target"]) ? "global" : agent_resolve_target(req["target"])
	var/list/arguments = agent_decode_arguments(req["arguments"])
	var/procref
	if (target == "global")
		procref = text2path(copytext(procname, 1, 2) == "/" ? procname : "/proc/[procname]")
		if (!procref)
			agent_fail("missing_proc", "no global proc [procname]")
	else
		if (agent_protected_target(target))
			agent_fail("forbidden", "agent control state is not accessible to agents")
		if (!hascall(target, procname))
			agent_fail("missing_proc", "[target] has no proc [procname]")
		procref = procname
	audit(A, "call_proc", "[target == "global" ? "" : "[target] ([agent_ref(target)])."][procname]([agent_plain_text(list2params(arguments))])")
	return run_job(A, "call_proc [procname]", target, procref, arguments)

// Admin verbs the agent's configured rights would give an admin client.
/datum/agent_control/proc/verbs_for(datum/agent_identity/A)
	var/list/out = list()
	if (!A.rights)
		return out
	var/rights = A.rights
	out |= admin_verbs_default
	if (rights & R_ADMIN) out |= admin_verbs_admin
	if (rights & R_FUN) out |= admin_verbs_fun
	if (rights & R_SERVER) out |= admin_verbs_server
	if (rights & R_DEBUG)
		out |= admin_verbs_debug
		if (config.debugparanoid && !(rights & R_ADMIN))
			out -= admin_verbs_paranoid_debug
	if (rights & R_PERMISSIONS)
		out |= admin_verbs_permissions
		out |= admin_verbs_manager
	if (rights & R_REJUVINATE) out |= admin_verbs_rejuv
	if (rights & R_SOUNDS) out |= admin_verbs_sounds
	if (rights & R_SPAWN) out |= admin_verbs_spawn
	if (rights & R_MOD) out |= admin_verbs_mod
	if (rights & R_MENTOR) out |= admin_verbs_mentor
	if (rights & R_TRIALADMIN) out |= admin_verbs_trialadmin
	if (rights & R_HOST) out |= admin_verbs_host
	return out

/datum/agent_control/proc/act_list_verbs(datum/agent_identity/A, list/req)
	audit_read(A, "list_verbs")
	var/list/out = list()
	for (var/path in verbs_for(A))
		out += "[path]"
	return list("rights" = rights2text(A.rights), "verbs" = out, "note" = "Verbs run with usr set to the agent; interactive prompts receive no answer, so pass arguments where the verb declares them.")

/datum/agent_control/proc/act_call_verb(datum/agent_identity/A, list/req)
	var/name = req["verb"]
	if (!istext(name) || !length(name))
		agent_fail("bad_args", "verb is required")
	var/verbpath
	for (var/path in verbs_for(A))
		var/path_text = "[path]"
		if (path_text == name || copytext(path_text, findlasttext(path_text, "/") + 1) == name)
			verbpath = path
			break
	if (!verbpath)
		agent_fail("forbidden", "[name] is not an admin verb allowed by this agent's rights")
	var/list/arguments = agent_decode_arguments(req["arguments"])
	var/mob/agent_proxy/P = A.get_proxy()
	var/target = null
	if (findtext("[verbpath]", "/datum/admins/") == 1)
		target = P.agent_holder
	audit(A, "call_verb", "[verbpath]([agent_plain_text(list2params(arguments))])")
	if (target)
		var/procname = copytext("[verbpath]", findlasttext("[verbpath]", "/") + 1)
		return run_job(A, "call_verb [verbpath]", target, procname, arguments)
	return run_job(A, "call_verb [verbpath]", null, verbpath, arguments)

// ---------------------------------------------------------------------------
// Messaging, moderation and round control

/proc/agent_text_arg(list/req, name, max_length = 1024)
	var/text = req[name]
	if (!istext(text) || !length(trim(text)))
		agent_fail("bad_args", "[name] is required")
	return copytext(trim(text), 1, max_length + 1)

/datum/agent_control/proc/act_announce(datum/agent_identity/A, list/req)
	var/message = html_encode(agent_text_arg(req, "text"))
	to_chat(world, "<big><span class=notice><b>[html_encode(A.name)] (server agent) Announces:</b></big><p style='text-indent: 50px'>[replacetext(message, "\n", "<br>")]</p></span>")
	audit(A, "announce", message, FALSE)
	return list("sent_to" = clients.len)

/datum/agent_control/proc/act_admin_pm(datum/agent_identity/A, list/req)
	var/client/C = agent_resolve_target("client:[req["ckey"]]")
	var/message = html_encode(agent_text_arg(req, "text"))
	to_chat(C, "<span class='pm'><span class='in'>PM from <b>[html_encode(A.name)] (server agent)</b>: [message]</span></span>")
	audit(A, "admin_pm to [C.ckey]", message)
	return list("ckey" = C.ckey)

/datum/agent_control/proc/act_narrate(datum/agent_identity/A, list/req)
	var/message = html_encode(agent_text_arg(req, "text"))
	if (istext(req["ckey"]))
		var/client/C = agent_resolve_target("client:[req["ckey"]]")
		to_chat(C, message)
		audit(A, "narrate to [C.ckey]", message)
		return list("sent_to" = 1)
	to_chat(world, message)
	audit(A, "narrate to world", message)
	return list("sent_to" = clients.len)

/datum/agent_control/proc/act_asay(datum/agent_identity/A, list/req)
	var/message = html_encode(agent_text_arg(req, "text"))
	audit(A, "asay", message)
	return list("sent_to" = admins.len)

/datum/agent_control/proc/act_kick(datum/agent_identity/A, list/req)
	var/client/C = agent_resolve_target("client:[req["ckey"]]")
	var/reason = istext(req["reason"]) ? html_encode(copytext(req["reason"], 1, 257)) : "No reason given"
	if (C.holder)
		agent_fail("forbidden", "agents cannot kick admins")
	audit(A, "kick [C.ckey]", reason)
	to_chat(C, "<span class='danger'>You have been kicked from the server by a server agent: [reason]</span>")
	var/ckey = C.ckey
	qdel(C)
	return list("ckey" = ckey)

/datum/agent_control/proc/act_start_round(datum/agent_identity/A, list/req)
	if (!ticker)
		agent_fail("unavailable", "the ticker is not set up")
	if (ticker.current_state != GAME_STATE_PREGAME)
		agent_fail("unavailable", "the round has already started")
	round_progressing = TRUE
	ticker.pregame_timeleft = 1
	ticker.admin_started = TRUE
	audit(A, "start_round")
	return list("starting" = TRUE)

/datum/agent_control/proc/act_restart(datum/agent_identity/A, list/req)
	if (req["confirm"] != TRUE && req["confirm"] != 1)
		agent_fail("confirm_required", "pass confirm: true")
	if (persistence_save_in_progress || persistence_restart.busy || persistence_restart.startup_hold)
		agent_fail("unavailable", "a save or recovery is in progress")
	var/reason = istext(req["reason"]) ? html_encode(copytext(req["reason"], 1, 257)) : "requested by a server agent"
	audit(A, "restart", reason)
	to_chat(world, "<span class='danger'>Restarting world!</span> <span class='notice'>Initiated by server agent <b>[html_encode(A.name)]</b>: [reason]</span>")
	spawn(50)
		world.Reboot()
	return list("restarting_in_seconds" = 5)

// ---------------------------------------------------------------------------
// Spawning and deletion

/datum/agent_control/proc/act_spawn_atom(datum/agent_identity/A, list/req)
	var/path = text2path("[req["type"]]")
	if (!ispath(path, /obj) && !ispath(path, /mob))
		agent_fail("bad_type", "type must be an /obj or /mob path")
	var/turf/T = get_turf(agent_resolve_target(req["target"]))
	if (!T)
		agent_fail("bad_target", "target has no turf")
	var/amount = clamp(round(text2num("[req["amount"]]") || 1), 1, 20)
	var/list/out = list()
	for (var/i = 1, i <= amount, i++)
		out += list(agent_encode(new path(T)))
	audit(A, "spawn_atom", "[amount] x [path] at [T.x],[T.y],[T.z]")
	return list("spawned" = out)

/datum/agent_control/proc/act_delete_atom(datum/agent_identity/A, list/req)
	var/atom/movable/M = agent_resolve_target(req["target"])
	if (!istype(M))
		agent_fail("bad_target", "only movable atoms can be deleted")
	if (ismob(M))
		var/mob/mob = M
		if (mob.client)
			agent_fail("forbidden", "cannot delete a mob with a connected player")
	audit(A, "delete_atom", "[M] ([agent_ref(M)], [M.type])")
	agent_characters -= M
	qdel(M)
	return list("deleted" = TRUE)
