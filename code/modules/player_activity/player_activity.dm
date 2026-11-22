// Player activity recorder: small JSON lines about who plays, for how long and
// what happens to them, so the host can tell who is active and where players
// stop. Plan: https://claude.ai/artifact/Rr7NGiEdMCwRaXtpbfP3PV
//
// Off unless config.txt has PLAYER_ACTIVITY 1. Lines are buffered here and
// appended once a minute (code/processes/player_activity.dm) to data/player_activity/<yyyy-mm-dd>.jsonl in this
// region's folder; tools/player_activity reads every region's files on the
// host. Never part of the world save and adds no vars to mobs.
//
// Privacy: the key is account_key() (the ckey, or d:<discord id>), plus the
// ckey for a BYOND key. Unsigned guests get an anonymous per-session id. No IP,
// computer id, chat text, coordinates or character names are written.

#define PLAYER_ACTIVITY_VERSION 1
#define PLAYER_ACTIVITY_MAX_LINES 2000
#define PLAYER_ACTIVITY_HEARTBEAT (5 MINUTES)
#define PLAYER_ACTIVITY_IDLE (5 MINUTES)
#define PLAYER_ACTIVITY_DIR "data/player_activity/"
// A kill is put on another player only if their last hit landed this recently.
#define PLAYER_ACTIVITY_KILL_WINDOW (60 SECONDS)

var/global/datum/player_activity/player_activity = new

/datum/player_activity
	var/boot = null
	var/list/lines = list()
	var/dropped = 0
	// account -> list(counter -> amount), cleared at each flush
	var/list/counters = list()
	// ckey -> list("start" = world.time, "a" = account or null, "anon" = id, "travel" = destination)
	var/list/sessions = list()
	var/header_written = FALSE
	var/last_heartbeat = 0
	var/last_reach_date = null
	// Result types already reported as crafted by someone since this boot.
	var/list/crafted_types = list()
	var/last_date = null

/datum/player_activity/New()
	..()
	boot = copytext(md5("[world.realtime]-[world.timeofday]-[rand(1, 1000000000)]"), 1, 13)

/datum/player_activity/proc/enabled()
	return config && config.player_activity

/datum/player_activity/proc/region()
	return (shard_group && shard_group.enabled && istext(shard_group.region)) ? shard_group.region : "solo"

// Seconds since the host's local midnight: world.timeofday is exact, while
// world.realtime as a 32-bit number is only good to about a minute.
/datum/player_activity/proc/now_seconds()
	return round(world.timeofday / 10)

/datum/player_activity/proc/today()
	return time2text(world.realtime, "YYYY-MM-DD")

// Adds one line. Fields are kept short; "e" names the event.
/datum/player_activity/proc/record(event, list/fields = null)
	if(!enabled() || !istext(event)) return FALSE
	if(length(lines) >= PLAYER_ACTIVITY_MAX_LINES)
		dropped++
		return FALSE
	var/list/L = list("e" = event, "s" = now_seconds())
	if(islist(fields))
		for(var/k in fields)
			L[k] = fields[k]
	lines += json_encode(L)
	return TRUE

// Adds to a per-account daily counter, written as one "counts" line per flush.
/datum/player_activity/proc/count(account, name, amount = 1)
	if(!enabled() || !istext(account) || !istext(name) || !isnum(amount)) return FALSE
	var/list/C = counters[account]
	if(!C)
		C = list()
		counters[account] = C
	C[name] = (C[name] || 0) + amount
	return TRUE

/datum/player_activity/proc/header_line()
	return json_encode(list("e" = "boot", "s" = now_seconds(), "v" = PLAYER_ACTIVITY_VERSION, "boot" = boot,
		"region" = region(), "tz" = world.timezone, "map" = map ? "[map.ID]" : null))

// Appends everything buffered in one write. Returns the number of lines written.
/datum/player_activity/proc/flush()
	if(!enabled()) return 0
	for(var/account in counters)
		var/list/C = counters[account]
		if(length(C))
			if(length(lines) >= PLAYER_ACTIVITY_MAX_LINES)
				dropped++
			else
				lines += json_encode(list("e" = "counts", "s" = now_seconds(), "a" = account, "c" = C))
	counters = list()
	if(dropped)
		lines += json_encode(list("e" = "dropped", "s" = now_seconds(), "n" = dropped))
		dropped = 0
	if(!length(lines)) return 0
	var/date = today()
	// Every file opens with this boot's header, so it can be read alone.
	if(!header_written || date != last_date)
		lines.Insert(1, header_line())
		header_written = TRUE
		last_date = date
	var/written = length(lines)
	text2file(jointext(lines, "\n") + "\n", "[PLAYER_ACTIVITY_DIR][date].jsonl")
	lines = list()
	return written

// One fire a minute: a heartbeat every PLAYER_ACTIVITY_HEARTBEAT, then a flush.
/datum/player_activity/proc/tick()
	if(!enabled()) return
	if(world.time - last_heartbeat >= PLAYER_ACTIVITY_HEARTBEAT)
		last_heartbeat = world.time
		heartbeat()
	var/date = today()
	if(date != last_reach_date && length(clients))
		last_reach_date = date
		map_reach()
	flush()

// ---------------------------------------------------------------- sessions

/datum/player_activity/proc/client_fields(client/C, list/S)
	var/list/F = list()
	if(S && S["a"])
		F["a"] = S["a"]
	else if(S)
		F["anon"] = S["anon"]
	return F

/datum/player_activity/proc/session_start(client/C)
	if(!enabled() || !C) return
	var/account = account_key(C)
	var/list/S = list("start" = world.time, "a" = account, "anon" = account ? null : copytext(md5("[boot]-[C.ckey]-[world.time]"), 1, 13))
	sessions[C.ckey] = S
	var/list/F = client_fields(C, S)
	if(account && account != C.ckey)
		F["ck"] = C.ckey
	F["via"] = account ? (copytext(account, 1, 3) == "d:" ? "discord" : "byond") : "guest"
	if(C.holder)
		F["staff"] = 1
	record("join", F)

/datum/player_activity/proc/note_travel(client/C, destination)
	if(!C) return
	var/list/S = sessions[C.ckey]
	if(S) S["travel"] = istext(destination) ? destination : "?"

/datum/player_activity/proc/session_end(client/C, reason = null)
	if(!enabled() || !C) return
	var/list/S = sessions[C.ckey]
	if(!S) return
	sessions -= C.ckey
	var/list/F = client_fields(C, S)
	// A launcher sign-in can finish after the join line; tie the two together.
	if(!S["a"])
		var/late = account_key(C)
		if(late) F["a"] = late
	F["min"] = round((world.time - S["start"]) / (1 MINUTE), 0.1)
	F["why"] = reason || (S["travel"] ? "travel" : "quit")
	if(S["travel"])
		F["to"] = S["travel"]
	record("leave", F)
	// The host may freeze an empty world straight away; write while we can.
	if(length(clients) <= 1)
		flush()

/proc/player_activity_mob_state(mob/M)
	if(!M) return "none"
	if(istype(M, /mob/new_player)) return "lobby"
	if(isobserver(M)) return "observer"
	if(isliving(M))
		var/mob/living/L = M
		if(L.stat == DEAD) return "dead"
		// Playtime counts only while alive and awake (shared player records).
		if(L.stat == UNCONSCIOUS || L.sleeping) return "asleep"
		return "alive"
	return "other"

/datum/player_activity/proc/heartbeat()
	var/living = 0
	for(var/mob/living/human/H in human_mob_list)
		if(H.persistence_owner_ckey && H.stat != DEAD && !QDELETED(H) && !is_agent_account(H.persistence_owner_ckey))
			living++
	var/list/health = list("p" = length(clients), "living" = living)
	if(map) health["era"] = map.ordinal_age
	if(processes && processes.time_track)
		health["dil"] = round(processes.time_track.stored_averages["dilation"], 0.1)
		health["cpu"] = round(processes.time_track.stored_averages["cpu"], 0.1)
	record("health", health)
	for(var/client/C in clients)
		var/list/S = sessions[C.ckey]
		if(!S) continue
		var/list/F = client_fields(C, S)
		F["act"] = C.inactivity < PLAYER_ACTIVITY_IDLE ? 1 : 0
		F["st"] = player_activity_mob_state(C.mob)
		record("hb", F)

// Every connected player's session ends with the world.
/datum/player_activity/proc/world_stopping(reason = "restart")
	if(!enabled()) return
	for(var/client/C in clients)
		session_end(C, reason)
	flush()

/datum/player_activity/proc/world_saved(event, success, seconds)
	if(!enabled() || event == "started") return
	var/list/F = list("ok" = success ? 1 : 0)
	if(isnum(seconds)) F["sec"] = seconds
	record("save", F)
	flush()

// ---------------------------------------------------------------- characters

// The account a character is recorded under: its player's account key when
// connected, else its saved owner. Null for unowned NPCs.
/proc/player_activity_account(mob/living/human/H)
	if(!istype(H)) return null
	if(H.client)
		var/account = account_key(H.client)
		if(account) return account
	return istext(H.persistence_owner_ckey) && length(H.persistence_owner_ckey) ? owner_key_account(H.persistence_owner_ckey) : null

// Best guess at what killed a human, from the body at death.
// Returns list(cause, killer account or null).
/proc/player_activity_death_cause(mob/living/human/H)
	var/mob/living/human/K = H.lastattacker
	if(istype(K) && K != H && H.round_fact_hit_time >= 0 && world.time - H.round_fact_hit_time <= PLAYER_ACTIVITY_KILL_WINDOW)
		var/killer = player_activity_account(K)
		if(killer && !is_agent_account(killer)) return list("player", killer)
		return list("npc", null)
	if(H.nutrition <= 0) return list("starved", null)
	if(H.water <= 0) return list("thirst", null)
	if(H.species)
		if(H.bodytemperature < H.species.cold_level_1) return list("cold", null)
		if(H.bodytemperature > H.species.heat_level_1) return list("heat", null)
	if(H.disease) return list("disease", null)
	var/brute = H.getBruteLoss()
	var/burn = H.getBurnLoss()
	var/oxy = H.getOxyLoss()
	var/tox = H.getToxLoss()
	var/top = max(brute, burn, oxy, tox)
	if(top <= 0) return list("unknown", null)
	if(top == oxy) return list(istype(get_turf(H), /turf/floor/beach/water) ? "drowned" : "suffocated", null)
	if(top == burn) return list("burned", null)
	if(top == tox) return list("poison", null)
	return list("wounded", null)

/datum/player_activity/proc/death(mob/living/human/H, gibbed)
	if(!enabled() || !istype(H) || istype(H, /mob/living/human/corpse)) return
	var/account = player_activity_account(H)
	if(!account) return
	var/list/cause = player_activity_death_cause(H)
	var/list/F = list("a" = account, "cause" = cause[1], "tod" = "[time_of_day]", "season" = "[season]")
	if(cause[2]) F["by"] = cause[2]
	if(gibbed) F["gib"] = 1
	if(is_agent_account(account)) F["agent"] = 1
	if(istext(H.civilization) && H.civilization != "none") F["fac"] = H.civilization
	if(H.client)
		var/list/S = sessions[H.client.ckey]
		if(S) F["smin"] = round((world.time - S["start"]) / (1 MINUTE), 0.1)
	record("death", F)

// ---------------------------------------------------------------- travel

// How a traveller's payload says they went: the same keys the arrival code uses.
/proc/player_activity_travel_method(list/P)
	if(!islist(P)) return "trail"
	if(P["lander"] || P["orbit"]) return "lander"
	if(P["ship"] || P["voyage"]) return "ship"
	if(P["plane"] || P["flight"]) return "aircraft"
	if(P["admin_send"]) return "admin"
	if(P["party"]) return "train"
	if(P["edge"]) return "edge"
	if(P["raid"]) return "raid"
	return "trail"

// The same answer from a payload still in text, without decoding a large ship payload.
/proc/player_activity_payload_method(payload)
	if(!istext(payload)) return "trail"
	var/list/P = list()
	for(var/key in list("lander", "orbit", "ship", "voyage", "plane", "flight", "admin_send", "party", "edge", "raid"))
		if(findtext(payload, "\"[key]\":"))
			P[key] = TRUE
	return player_activity_travel_method(P)

/datum/player_activity/proc/depart(mob/living/human/H, destination, payload)
	if(!enabled() || !istype(H)) return
	var/account = player_activity_account(H)
	if(!account) return
	var/list/F = list("a" = account, "to" = destination, "how" = player_activity_payload_method(payload))
	if(is_agent_account(account)) F["agent"] = 1
	record("depart", F)
	if(H.client) note_travel(H.client, destination)

/datum/player_activity/proc/arrive(list/P, incoming)
	if(!enabled() || !islist(P) || !istext(P["owner"])) return
	var/list/F = list("a" = P["owner"], "from" = P["from"], "how" = player_activity_travel_method(P))
	if(!incoming) F["back"] = 1
	if(is_agent_account(P["owner"])) F["agent"] = 1
	record("arrive", F)

// A trip that did not start, with the reason as a short class.
/proc/player_activity_refusal_class(reason)
	if(!istext(reason)) return "other"
	var/r = lowertext(reason)
	if(findtext(r, "asleep") || findtext(r, "stopped")) return "destination_down"
	if(findtext(r, "carry too much")) return "too_much"
	if(findtext(r, "too far")) return "too_far"
	if(findtext(r, "busy") || findtext(r, "changed")) return "busy"
	if(findtext(r, "byond account")) return "no_account"
	if(findtext(r, "closed") || findtext(r, "approval")) return "closed"
	return "other"

/datum/player_activity/proc/travel_refused(mob/living/human/H, destination, reason)
	if(!enabled() || !istype(H)) return
	var/account = player_activity_account(H)
	if(!account) return
	record("refused", list("a" = account, "to" = destination, "why" = player_activity_refusal_class(reason)))

// ---------------------------------------------------------------- progress
// Research node ids come only from research_node.dm and crafted types only
// from the config/crafting recipe files; tests/player_activity keeps both free
// of anything hidden.

// Records for owned characters only; host agents are marked.
/datum/player_activity/proc/character_fields(mob/living/human/H)
	var/account = player_activity_account(H)
	if(!account) return null
	var/list/F = list("a" = account)
	if(is_agent_account(account)) F["agent"] = 1
	return F

/datum/player_activity/proc/node_learned(mob/living/human/H, node_id)
	if(!enabled() || !istext(node_id)) return
	var/list/F = character_fields(H)
	if(!F) return
	F["node"] = node_id
	record("learn", F)

/datum/player_activity/proc/node_done(faction, node_id, era = null)
	if(!enabled() || !istext(node_id)) return
	var/list/F = list("fac" = "[faction]", "node" = node_id)
	if(isnum(era)) F["era"] = era
	record("node_done", F)

/datum/player_activity/proc/faction_event(mob/living/human/H, event, faction)
	if(!enabled() || !istext(faction) || faction == "none") return
	var/list/F = character_fields(H)
	if(!F) return
	F["fac"] = faction
	record(event, F)

// The family a crafted type belongs to: /obj/item/weapon/foo -> item/weapon.
/proc/player_activity_craft_family(type_text)
	var/list/parts = splittext("[type_text]", "/")
	// "", "obj", "item", "weapon", ...
	if(length(parts) >= 4) return "[parts[3]]/[parts[4]]"
	if(length(parts) >= 3) return parts[3]
	return "other"

/datum/player_activity/proc/crafted(mob/living/human/H, result_type)
	if(!enabled() || !result_type) return
	var/account = player_activity_account(H)
	if(!account || is_agent_account(account)) return
	var/type_text = "[result_type]"
	count(account, "craft:[player_activity_craft_family(type_text)]")
	if(!crafted_types[type_text])
		crafted_types[type_text] = TRUE
		record("first_craft", list("a" = account, "type" = type_text))

// A hand action refused for missing research: where players hit walls.
/datum/player_activity/proc/research_wall(mob/living/human/H, node_id)
	if(!enabled() || !istext(node_id)) return
	var/account = player_activity_account(H)
	if(!account || is_agent_account(account)) return
	count(account, "locked:[node_id]")

/datum/player_activity/proc/tutorial_step(client/C, step_id)
	if(!enabled() || !C || !istext(step_id)) return
	var/list/S = sessions[C.ckey]
	var/list/F = client_fields(C, S || list("a" = account_key(C)))
	F["step"] = step_id
	record("tutorial", F)

// ---------------------------------------------------------------- features

// Counts one use of a feature ("use:<name>") for the client or mob's account.
/datum/player_activity/proc/feature_used(who, feature)
	if(!enabled() || !istext(feature)) return
	var/account = null
	if(istype(who, /client))
		account = account_key(who)
	else if(istype(who, /mob))
		var/mob/M = who
		if(ishuman(M))
			account = player_activity_account(M)
		else if(M.client)
			account = account_key(M.client)
	if(!account || is_agent_account(account)) return
	count(account, "use:[feature]")

// How an AI help question ended: ok, rate_limited, busy, failed or timeout.
/datum/player_activity/proc/help_outcome(client/C, outcome)
	if(!enabled() || !istext(outcome)) return
	var/account = C ? account_key(C) : null
	if(account) count(account, "help:[outcome]")
	else count("anonymous", "help:[outcome]")

// A boat leaving on a voyage from a tiller (naval/ship_voyage.dm).
/datum/player_activity/proc/voyage(mob/living/human/H, kind)
	if(!enabled()) return
	var/list/F = character_fields(H)
	if(!F) return
	F["kind"] = "[kind]"
	record("voyage", F)

// Once a day: how many map chunks of each level anyone has stood in, from
// the existing visited record (persistence/visited_areas.dm). No per-player data.
/datum/player_activity/proc/map_reach()
	if(!enabled() || !islist(persistence_visited_levels)) return
	var/list/levels = list()
	for(var/z = 1, z <= length(persistence_visited_levels), z++)
		var/list/level = persistence_visited_levels[z]
		if(!islist(level) || !length(level)) continue
		var/seen = 0
		for(var/cell in level)
			if(cell) seen++
		levels["[z]"] = list(seen, length(level))
	if(length(levels))
		record("reach", list("levels" = levels))

// ---------------------------------------------------------------- hooks

/hook/death/proc/player_activity_death(mob/living/human/H, gibbed)
	player_activity.death(H, gibbed)
	return TRUE

// Called through text2path from notify_world_save (persistence fixtures build without this module).
/proc/player_activity_world_save(event, success, seconds)
	player_activity.world_saved(event, success, seconds)

#undef PLAYER_ACTIVITY_VERSION
#undef PLAYER_ACTIVITY_MAX_LINES
#undef PLAYER_ACTIVITY_HEARTBEAT
#undef PLAYER_ACTIVITY_IDLE
#undef PLAYER_ACTIVITY_DIR
#undef PLAYER_ACTIVITY_KILL_WINDOW
