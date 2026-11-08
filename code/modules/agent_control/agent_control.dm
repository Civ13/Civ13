// Authenticated agent control over world/Topic (docs/agent-control.md).
//
// Disabled unless config/agent-control.txt exists with at least one agent line.
// Every request needs a named agent and its secret token, comes from an allowed
// address (loopback only unless the file names another address) and is limited
// to the scopes that agent was granted. Tokens never enter any log. Mutating
// actions are written to the admin log and announced to online admins; reads go
// to the game log.

#define AGENT_CONTROL_CONFIG "config/agent-control.txt"
#define AGENT_CONTROL_MAX_RESPONSE 60000
#define AGENT_CONTROL_MAX_FAILURES 5
#define AGENT_CONTROL_LOCKOUT 6000
#define AGENT_CONTROL_RATE_PER_SECOND 30
#define AGENT_CONTROL_MAX_JOBS 64
#define AGENT_CONTROL_MAX_TEXT 4096
#define AGENT_CONTROL_MAX_LIST 64

var/global/datum/agent_control/agent_control = new

// Mobs an agent may drive, keyed by the mob. Read on hot message paths, so it
// stays a plain associative list and is checked with .len first.
var/global/list/agent_characters = list()

/datum/agent_identity
	var/name
	var/token
	var/list/scopes = list()
	var/rights = 0
	var/rate_window = 0
	var/rate_count = 0
	var/mob/agent_proxy/proxy

/datum/agent_identity/proc/has_scope(scope)
	return ("*" in scopes) || (scope in scopes)

/datum/agent_identity/proc/get_proxy()
	if (!proxy)
		proxy = new /mob/agent_proxy(src)
	return proxy

/datum/agent_control
	var/config_text
	var/list/agents = list()
	var/list/allowed_addresses = list("127.0.0.1")
	var/allow_handover = FALSE
	var/max_characters = 4
	var/list/last_watch = list() // agent name -> world.time it last listed its characters
	var/list/failures = list()
	var/list/locked_until = list()
	var/list/jobs = list()
	var/next_job = 1
	var/datum/agent_identity/current_agent

/datum/agent_control/proc/enabled()
	reload()
	return agents.len > 0

// Re-parse only when the file text changes. Invalid lines are ignored and
// reported to the server log by line number, never by content.
/datum/agent_control/proc/reload()
	var/text = fexists(AGENT_CONTROL_CONFIG) ? file2text(AGENT_CONTROL_CONFIG) : ""
	if (text == config_text)
		return
	config_text = text
	var/list/old_agents = agents
	agents = list()
	allowed_addresses = list("127.0.0.1")
	allow_handover = FALSE
	max_characters = 4
	var/line_number = 0
	for (var/raw in splittext(text, "\n"))
		line_number++
		var/line = trim(replacetext(raw, ascii2text(13), ""))
		if (!length(line) || copytext(line, 1, 2) == "#")
			continue
		var/list/parts = splittext(line, " ")
		var/list/words = list()
		for (var/part in parts)
			if (length(part))
				words += part
		switch (lowertext(words[1]))
			if ("agent")
				if (words.len < 4 || !agent_control_valid_name(words[2]) || !agent_control_valid_token(words[3]))
					world.log << "agent-control: ignored invalid agent line [line_number]"
					continue
				var/datum/agent_identity/A = new
				A.name = words[2]
				A.token = words[3]
				for (var/scope in splittext(lowertext(words[4]), ","))
					if (scope in agent_control_scopes())
						A.scopes += scope
				if (words.len >= 5)
					A.rights = agent_control_parse_rights(words[5])
				var/datum/agent_identity/previous = old_agents[A.name]
				if (previous)
					A.proxy = previous.proxy
					if (A.proxy)
						A.proxy.identity = A
				agents[A.name] = A
			if ("allow_address")
				if (words.len >= 2)
					allowed_addresses |= words[2]
			if ("allow_handover")
				allow_handover = TRUE
			if ("max_characters")
				if (words.len >= 2)
					max_characters = clamp(round(text2num(words[2])), 0, 32)
			else
				world.log << "agent-control: ignored unknown line [line_number]"
	for (var/client/C in clients)
		update_handover_verbs(C)

/proc/agent_control_scopes()
	return list("*", "observe", "vars_read", "vars_write", "call_proc", "admin_verbs", "message", "moderation", "server", "spawn", "characters", "visits", "ooc")

/proc/agent_control_valid_name(name)
	if (!istext(name) || length(name) < 1 || length(name) > 32)
		return FALSE
	var/static/regex/allowed = regex(@"^[A-Za-z0-9_-]+$")
	return allowed.Find(name)

/proc/agent_control_valid_token(token)
	if (!istext(token) || length(token) < 32 || length(token) > 128)
		return FALSE
	var/static/regex/allowed = regex(@"^[A-Za-z0-9_-]+$")
	return allowed.Find(token)

// Accepts a rank name from config/admin_ranks.txt or a number of R_* flags.
/proc/agent_control_parse_rights(value)
	if (!istext(value))
		return 0
	var/number = text2num(value)
	if (!isnull(number))
		return clamp(round(number), 0, 0xFFFF)
	var/rank_rights = admin_ranks[ckeyEx(value)]
	if (istext(rank_rights))
		rank_rights = text2num(rank_rights)
	return isnum(rank_rights) ? rank_rights : 0

// Same-length comparison that does not stop at the first difference.
/proc/agent_control_token_matches(supplied, expected)
	if (!istext(supplied) || !istext(expected) || length(supplied) != length(expected))
		return FALSE
	var/diff = 0
	for (var/i = 1, i <= length(expected), i++)
		if (text2ascii(supplied, i) != text2ascii(expected, i))
			diff++
	return diff == 0

/datum/agent_control/proc/respond(list/payload, request_id)
	if (request_id)
		payload["request_id"] = request_id
	var/text = json_encode(payload)
	if (length(text) > AGENT_CONTROL_MAX_RESPONSE)
		var/list/short = list("ok" = FALSE, "error" = "response_too_large", "detail" = "Narrow the request (fewer vars, smaller radius or limit).")
		if (request_id)
			short["request_id"] = request_id
		text = json_encode(short)
	return text

/datum/agent_control/proc/error(code, detail, request_id)
	var/list/payload = list("ok" = FALSE, "error" = code)
	if (detail)
		payload["detail"] = "[detail]"
	return respond(payload, request_id)

// Entry point from /world/Topic. Credentials stay out of the generic Topic log.
/datum/agent_control/proc/handle(list/input, addr)
	var/request_id = input["request_id"]
	if (!istext(request_id) || length(request_id) > 64)
		request_id = null
	if (!enabled())
		return error("disabled", null, request_id)
	var/list/peer = istext(addr) ? splittext(addr, ":") : list("")
	var/host = peer[1]
	if (!(host in allowed_addresses))
		return error("address_not_allowed", null, request_id)
	if (locked_until[host] && world.time < locked_until[host])
		return error("locked_out", "Too many failed authentications; try again later.", request_id)
	var/datum/agent_identity/A = agents[input["agent"]]
	if (!A || !agent_control_token_matches(input["token"], A.token))
		failures[host] = (failures[host] || 0) + 1
		game_log("AGENT", "Failed agent authentication from [host] (attempt [failures[host]]).")
		if (failures[host] >= AGENT_CONTROL_MAX_FAILURES)
			locked_until[host] = world.time + AGENT_CONTROL_LOCKOUT
			failures[host] = 0
			log_admin("AGENT: authentication locked out [host] after repeated failures.")
		if (failures.len > 256)
			failures.Cut(1, 2)
		if (locked_until.len > 256)
			locked_until.Cut(1, 2)
		return error("unauthorized", null, request_id)
	failures -= host
	var/now = world.timeofday
	if (now - A.rate_window >= 10 || now < A.rate_window)
		A.rate_window = now
		A.rate_count = 0
	if (++A.rate_count > AGENT_CONTROL_RATE_PER_SECOND)
		return error("rate_limited", null, request_id)

	var/action = input["action"]
	var/list/req = list()
	if (istext(input["args"]) && length(input["args"]))
		try
			req = json_decode(input["args"])
		catch
			return error("invalid_args", "args must be a JSON object", request_id)
		if (!islist(req))
			return error("invalid_args", "args must be a JSON object", request_id)
	var/list/spec = agent_control_actions()[action]
	if (!spec)
		return error("unknown_action", "Use the discover action for the catalog.", request_id)
	if (!A.has_scope(spec["scope"]))
		game_log("AGENT", "[A.name] denied [action]: missing scope [spec["scope"]].")
		return error("forbidden", "Requires scope [spec["scope"]].", request_id)

	current_agent = A
	var/result
	try
		result = dispatch(action, A, req)
	catch(var/exception/E)
		current_agent = null
		if (istype(E))
			if (E.name == "agent_control_error")
				return error(E.desc ? copytext(E.desc, 1, findtext(E.desc, ":")) : "failed", copytext(E.desc, findtext(E.desc, ":") + 1), request_id)
			game_log("AGENT", "[A.name] [action] raised [E.name] ([E.file]:[E.line]).")
			return error("runtime_error", "[E.name] ([E.file]:[E.line])", request_id)
		return error("runtime_error", "[E]", request_id)
	current_agent = null
	return respond(list("ok" = TRUE, "action" = action, "result" = result), request_id)

// Raised inside actions; handle() turns it into {"ok": false}.
/proc/agent_fail(code, detail = "")
	var/exception/E = new("agent_control_error")
	E.desc = "[code]:[detail]"
	throw E

// Audit helpers. Mutating actions always reach the admin log.
/datum/agent_control/proc/audit(datum/agent_identity/A, action, detail, notify_admins = TRUE)
	var/line = "AGENT [A.name]: [action][detail ? " - [detail]" : ""]"
	log_admin(line)
	if (notify_admins)
		message_admins(html_encode(line))

/datum/agent_control/proc/audit_read(datum/agent_identity/A, action, detail)
	game_log("AGENT", "[A.name]: [action][detail ? " - [detail]" : ""]")

// The action catalog. Keep in sync with tools/agent-control/catalog.py; the
// offline test compares the two.
/proc/agent_control_actions()
	var/static/list/actions = list(
		"discover" = list("scope" = "observe"),
		"status" = list("scope" = "observe"),
		"players" = list("scope" = "observe"),
		"inspect" = list("scope" = "observe"),
		"look" = list("scope" = "observe"),
		"find" = list("scope" = "observe"),
		"logs" = list("scope" = "observe"),
		"job" = list("scope" = "observe"),
		"get_vars" = list("scope" = "vars_read"),
		"set_var" = list("scope" = "vars_write"),
		"call_proc" = list("scope" = "call_proc"),
		"list_verbs" = list("scope" = "admin_verbs"),
		"call_verb" = list("scope" = "admin_verbs"),
		"announce" = list("scope" = "message"),
		"admin_pm" = list("scope" = "message"),
		"narrate" = list("scope" = "message"),
		"asay" = list("scope" = "message"),
		"kick" = list("scope" = "moderation"),
		"start_round" = list("scope" = "server"),
		"restart" = list("scope" = "server"),
		"spawn_atom" = list("scope" = "spawn"),
		"delete_atom" = list("scope" = "spawn"),
		"character_spawn" = list("scope" = "characters"),
		"character_list" = list("scope" = "characters"),
		"character_observe" = list("scope" = "characters"),
		"character_act" = list("scope" = "characters"),
		"character_queue" = list("scope" = "characters"),
		"character_route" = list("scope" = "characters"),
		"character_release" = list("scope" = "characters"),
		"visit_status" = list("scope" = "visits"),
		"visit_order" = list("scope" = "visits"),
		"visit_start" = list("scope" = "visits"),
	)
	return actions


// Direct calls, not call(): BYOND does not propagate agent_fail() exceptions
// out of procs started with call().
/datum/agent_control/proc/dispatch(action, datum/agent_identity/A, list/req)
	switch (action)
		if ("discover") return act_discover(A, req)
		if ("status") return act_status(A, req)
		if ("players") return act_players(A, req)
		if ("inspect") return act_inspect(A, req)
		if ("look") return act_look(A, req)
		if ("find") return act_find(A, req)
		if ("logs") return act_logs(A, req)
		if ("job") return act_job(A, req)
		if ("get_vars") return act_get_vars(A, req)
		if ("set_var") return act_set_var(A, req)
		if ("call_proc") return act_call_proc(A, req)
		if ("list_verbs") return act_list_verbs(A, req)
		if ("call_verb") return act_call_verb(A, req)
		if ("announce") return act_announce(A, req)
		if ("admin_pm") return act_admin_pm(A, req)
		if ("narrate") return act_narrate(A, req)
		if ("asay") return act_asay(A, req)
		if ("kick") return act_kick(A, req)
		if ("start_round") return act_start_round(A, req)
		if ("restart") return act_restart(A, req)
		if ("spawn_atom") return act_spawn_atom(A, req)
		if ("delete_atom") return act_delete_atom(A, req)
		if ("character_spawn") return act_character_spawn(A, req)
		if ("character_list") return act_character_list(A, req)
		if ("character_observe") return act_character_observe(A, req)
		if ("character_act") return act_character_act(A, req)
		if ("character_queue") return act_character_queue(A, req)
		if ("character_route") return act_character_route(A, req)
		if ("character_release") return act_character_release(A, req)
		if ("visit_status") return act_visit_status(A, req)
		if ("visit_order") return act_visit_order(A, req)
		if ("visit_start") return act_visit_start(A, req)
	agent_fail("unknown_action")

// ---------------------------------------------------------------------------
// Value encoding. Everything leaving the server is JSON-safe and bounded.

/proc/agent_ref(datum/D)
	return "\ref[D]"

/proc/agent_encode(value, depth = 0)
	if (isnull(value))
		return null
	if (isnum(value))
		if (value != value)
			return "NaN"
		if (value == 1.#INF || value == -1.#INF)
			return value > 0 ? "Infinity" : "-Infinity"
		return value
	if (istext(value))
		return length(value) > AGENT_CONTROL_MAX_TEXT ? copytext(value, 1, AGENT_CONTROL_MAX_TEXT + 1) : value
	if (ispath(value))
		return list("type" = "[value]")
	if (value == world)
		return list("ref" = "world", "type" = "/world")
	if (istype(value, /client))
		var/client/C = value
		return list("ref" = agent_ref(C), "type" = "/client", "ckey" = C.ckey)
	if (istype(value, /datum))
		var/datum/D = value
		var/list/out = list("ref" = agent_ref(D), "type" = "[D.type]")
		if (isatom(D))
			var/atom/A = D
			out["name"] = A.name
			var/turf/T = get_turf(A)
			if (T)
				out["x"] = T.x
				out["y"] = T.y
				out["z"] = T.z
		return out
	if (islist(value))
		var/list/L = value
		if (depth >= 2)
			return list("list_len" = L.len)
		var/list/items = list()
		var/assoc = FALSE
		var/count = 0
		for (var/key in L)
			if (++count > AGENT_CONTROL_MAX_LIST)
				break
			var/assoc_value = null
			if (!isnum(key))
				assoc_value = L[key]
			if (!isnull(assoc_value))
				assoc = TRUE
			items += list(list(agent_encode(key, depth + 1), agent_encode(assoc_value, depth + 1)))
		var/list/out = list("list_len" = L.len, "truncated" = L.len > AGENT_CONTROL_MAX_LIST)
		var/list/flat = list()
		for (var/list/pair in items)
			flat += list(assoc ? pair : pair[1])
		out[assoc ? "assoc" : "list"] = flat
		return out
	return "[value]"

// Arguments arriving from agents. Scalars pass through; objects describe refs:
//   {"ref": "[0x...]"}  {"type": "/obj/item"}  {"ckey": "name"}
//   {"turf": [x, y, z]}  {"list": [...]}  {"text": "literal"}
/proc/agent_decode(value)
	if (!islist(value))
		return value
	var/list/L = value
	if (istext(L["ref"]))
		return agent_resolve_target(L["ref"])
	if (istext(L["type"]))
		var/path = text2path(L["type"])
		if (!path)
			agent_fail("bad_type", L["type"])
		return path
	if (istext(L["ckey"]))
		return agent_resolve_target("ckey:[L["ckey"]]")
	if (islist(L["turf"]))
		var/list/c = L["turf"]
		if (c.len != 3)
			agent_fail("bad_turf", "turf needs \[x, y, z]")
		var/turf/T = locate(c[1], c[2], c[3])
		if (!T)
			agent_fail("bad_turf", "no turf there")
		return T
	if ("text" in L)
		return "[L["text"]]"
	if (islist(L["list"]))
		var/list/out = list()
		for (var/item in L["list"])
			out += list(agent_decode(item))
		return out
	agent_fail("bad_value", "Objects must be ref, type, ckey, turf, text or list.")

// Targets: "world", "global", "global:<var>", "[0x...]" refs, "ckey:<ckey>"
// (that player's mob), "client:<ckey>", "turf:x,y,z".
/proc/agent_resolve_target(target)
	if (!istext(target) || !length(target))
		agent_fail("bad_target", "target is required")
	if (target == "world")
		return world
	if (target == "global")
		return "global"
	if (copytext(target, 1, 8) == "global:")
		var/name = copytext(target, 8)
		if (!(name in global.vars))
			agent_fail("bad_target", "no global [name]")
		var/datum/D = global.vars[name]
		if (!istype(D))
			agent_fail("bad_target", "global [name] is not an object")
		return D
	if (copytext(target, 1, 6) == "ckey:" || copytext(target, 1, 8) == "client:")
		var/is_client = copytext(target, 1, 8) == "client:"
		var/ckey = ckey(copytext(target, is_client ? 8 : 6))
		var/client/C = directory[ckey]
		if (is_client)
			if (!C)
				agent_fail("not_found", "no client [ckey]")
			return C
		if (C && C.mob)
			return C.mob
		var/mob/M = get_mob_by_key(ckey)
		if (!M)
			agent_fail("not_found", "no mob for [ckey]")
		return M
	if (copytext(target, 1, 6) == "turf:")
		var/list/c = splittext(copytext(target, 6), ",")
		if (c.len != 3)
			agent_fail("bad_target", "turf:x,y,z")
		var/turf/T = locate(text2num(c[1]), text2num(c[2]), text2num(c[3]))
		if (!T)
			agent_fail("not_found", "no turf there")
		return T
	if (copytext(target, 1, 4) == "\[0x")
		var/datum/D = locate(target)
		if (!D || (istype(D) && QDELETED(D)))
			agent_fail("not_found", "ref [target] no longer exists")
		return D
	agent_fail("bad_target", "Use world, global, global:<var>, a ref, ckey:, client: or turf:x,y,z")

// ---------------------------------------------------------------------------
// The proxy mob is the agent's usr while it runs admin verbs and procs. It has
// no client, location or life; check_rights reads its configured rights and
// to_chat output sent to it is kept for the job result.

/mob/agent_proxy
	name = "agent"
	// Lives in nullspace for one agent session; never part of a world save.
	should_save = FALSE
	invisibility = 101
	density = FALSE
	anchored = TRUE
	var/datum/agent_identity/identity
	var/datum/admins/agent_holder
	var/list/agent_output = list()

/mob/agent_proxy/New(datum/agent_identity/A)
	// Deliberately skip /mob/New: no mob lists, life processing or location.
	identity = A
	name = "AGENT:[A.name]"
	real_name = name
	agent_holder = new /datum/admins("Agent", A.rights, "agent-[lowertext(A.name)]")
	admin_datums -= "agent-[lowertext(A.name)]"

/mob/agent_proxy/proc/has_rights(rights_required)
	if (!identity)
		return FALSE
	agent_holder.rights = identity.rights
	if (!rights_required)
		return identity.rights != 0
	return (identity.rights & rights_required) != 0

/mob/agent_proxy/proc/capture(message)
	if (agent_output.len >= 50)
		agent_output.Cut(1, 2)
	agent_output += agent_plain_text(message)

/proc/agent_plain_text(message)
	var/static/regex/tags = regex(@"<[^>]*>", "g")
	var/text = html_decode(tags.Replace("[message]", ""))
	return length(text) > 1024 ? copytext(text, 1, 1025) : text

// ---------------------------------------------------------------------------
// Jobs: procs and verbs run without blocking the Topic reply. A call that
// finishes immediately returns its result; one that sleeps returns a job id.

/datum/agent_job
	var/id
	var/agent
	var/label
	var/done = FALSE
	var/result
	var/error
	var/list/output = list()
	var/started

/datum/agent_job/proc/report()
	var/list/out = list("job" = id, "label" = label, "done" = done)
	if (done)
		out["result"] = agent_encode(result)
		if (error)
			out["error"] = error
	if (output.len)
		out["output"] = output.Copy()
	return out

/datum/agent_control/proc/run_job(datum/agent_identity/A, label, target, procref, list/arguments)
	if (jobs.len >= AGENT_CONTROL_MAX_JOBS)
		for (var/id in jobs)
			var/datum/agent_job/old = jobs[id]
			if (old.done)
				jobs -= id
				break
	if (jobs.len >= AGENT_CONTROL_MAX_JOBS)
		agent_fail("busy", "Too many unfinished jobs.")
	var/datum/agent_job/J = new
	J.id = "[next_job++]"
	J.agent = A.name
	J.label = label
	J.started = world.time
	jobs[J.id] = J
	var/mob/agent_proxy/P = A.get_proxy()
	P.has_rights(0) // refresh holder rights from the identity
	P.agent_output.Cut()
	execute_job(J, P, target, procref, arguments)
	return J.report()

/datum/agent_control/proc/execute_job(datum/agent_job/J, mob/agent_proxy/P, target, procref, list/arguments)
	set waitfor = FALSE
	usr = P
	try
		if (target == "global" || isnull(target))
			J.result = call(procref)(arglist(arguments))
		else
			J.result = call(target, procref)(arglist(arguments))
	catch(var/exception/E)
		J.error = istype(E) ? "[E.name] ([E.file]:[E.line])" : "[E]"
	J.output = P.agent_output.Copy()
	J.done = TRUE

#undef AGENT_CONTROL_CONFIG
#undef AGENT_CONTROL_MAX_RESPONSE
#undef AGENT_CONTROL_MAX_FAILURES
#undef AGENT_CONTROL_LOCKOUT
#undef AGENT_CONTROL_RATE_PER_SECOND
#undef AGENT_CONTROL_MAX_JOBS
