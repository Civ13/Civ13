// Native fixture for code/modules/player_activity/player_activity.dm. The
// production file is included unchanged; only what it calls is stubbed.
#define SECONDS *10
#define MINUTE SECONDS*60
#define MINUTES SECONDS*60
#define DEAD 2
#define QDELETED(X) (!X)
#define isobserver(A) istype(A, /mob/observer)
#define isliving(A) istype(A, /mob/living)

var/list/checks = list()
var/list/failed = list()

/proc/check(label, ok)
	checks += label
	if (!ok)
		failed += label

/datum/configuration
	var/player_activity = TRUE
var/datum/configuration/config = new

/datum/shard_group
	var/enabled = TRUE
	var/region = "gaia"
var/datum/shard_group/shard_group = new

/obj/map_metadata
	var/ID = "NOMADS"
var/obj/map_metadata/map = new

#define PROCESS_PRIORITY_IRRELEVANT 1
#define GAME_STATE_PREGAME 1
#define GAME_STATE_SETTING_UP 2
#define GAME_STATE_PLAYING 3
#define GAME_STATE_FINISHED 4
/process
	var/name
	var/schedule_interval
	var/start_delay
	var/priority
	var/list/fires_at_gamestates
/process/proc/setup()
/process/proc/fire()
/process/proc/reset_current_list()

/process/time_track
	var/list/stored_averages = list("dilation" = 12.34, "cpu" = 56.78)
/datum/process_list
	var/process/time_track/time_track = new
var/datum/process_list/processes = new

var/list/clients = list()
var/list/human_mob_list = list()
var/time_of_day = "Night"
var/season = "WINTER"


/client/var/holder = null

/proc/get_turf(atom/A)
	return A ? locate(A.x, A.y, A.z) : null
/hook/death

/proc/account_key(client/C)
	return C ? C.ckey : null

/proc/is_agent_account(account)
	return istext(account) && copytext(account, 1, 7) == "agent@"

/datum/species
	var/cold_level_1 = 260
	var/heat_level_1 = 315

/mob/var/lastattacker = null
/mob/new_player
/mob/observer
/mob/living
	var/stat = 0
	var/brute = 0
	var/burn = 0
	var/oxy = 0
	var/tox = 0
/mob/living/proc/getBruteLoss()
	return brute
/mob/living/proc/getBurnLoss()
	return burn
/mob/living/proc/getOxyLoss()
	return oxy
/mob/living/proc/getToxLoss()
	return tox
/mob/living/human
	var/persistence_owner_ckey = null
	var/nutrition = 400
	var/water = 400
	var/bodytemperature = 310
	var/disease = FALSE
	var/civilization = "none"
	var/round_fact_hit_time = -1
	var/datum/species/species = new
/mob/living/human/corpse

/turf/floor/beach/water

/proc/human(owner)
	var/mob/living/human/H = new
	H.persistence_owner_ckey = owner
	return H

/proc/lines_of(path)
	if (!fexists(path))
		return list()
	var/list/out = list()
	for (var/line in splittext(file2text(path), "\n"))
		if (length(line))
			out += list(json_decode(line))
	return out

/world/New()
	..()
	var/datum/player_activity/A = player_activity
	var/path = "data/player_activity/[A.today()].jsonl"
	fdel("data/player_activity/")

	// Causes of death
	var/mob/living/human/H = human("alice")
	H.nutrition = 0
	check("starved", player_activity_death_cause(H)[1] == "starved")
	H = human("alice"); H.water = 0
	check("thirst", player_activity_death_cause(H)[1] == "thirst")
	H = human("alice"); H.bodytemperature = 200
	check("cold", player_activity_death_cause(H)[1] == "cold")
	H = human("alice"); H.bodytemperature = 330
	check("heat", player_activity_death_cause(H)[1] == "heat")
	H = human("alice"); H.disease = TRUE
	check("disease", player_activity_death_cause(H)[1] == "disease")
	H = human("alice"); H.burn = 80; H.brute = 10
	check("burned", player_activity_death_cause(H)[1] == "burned")
	H = human("alice"); H.oxy = 90
	check("suffocated", player_activity_death_cause(H)[1] == "suffocated")
	H = human("alice"); H.tox = 90
	check("poison", player_activity_death_cause(H)[1] == "poison")
	H = human("alice"); H.brute = 90
	check("wounded", player_activity_death_cause(H)[1] == "wounded")
	H = human("alice")
	check("unknown is visible", player_activity_death_cause(H)[1] == "unknown")
	var/mob/living/human/K = human("bob")
	H = human("alice"); H.lastattacker = K; H.round_fact_hit_time = world.time
	var/list/pk = player_activity_death_cause(H)
	check("player kill names killer account", pk[1] == "player" && pk[2] == "bob")
	K = human(null)
	H = human("alice"); H.lastattacker = K; H.round_fact_hit_time = world.time
	check("unowned killer is npc", player_activity_death_cause(H)[1] == "npc")
	K = human("agent@ada")
	H = human("alice"); H.lastattacker = K; H.round_fact_hit_time = world.time
	check("agent killer is npc", player_activity_death_cause(H)[1] == "npc")

	// Travel methods
	check("ship payload", player_activity_payload_method("{\"ship\":{}}") == "ship")
	check("edge payload", player_activity_payload_method("{\"edge\":1}") == "edge")
	check("plain trail", player_activity_payload_method("{\"owner\":\"a\"}") == "trail")
	check("decoded aircraft", player_activity_travel_method(list("plane" = 1)) == "aircraft")
	check("refusal class", player_activity_refusal_class("You carry too much to travel.") == "too_much")
	check("refusal asleep", player_activity_refusal_class("Europe is asleep. Use the trail to wake it.") == "destination_down")

	// Recording and flushing
	H = human("alice"); H.nutrition = 0; H.civilization = "Rome"
	A.death(H, FALSE)
	A.death(human(null), FALSE)
	A.depart(human("alice"), "europe", "{\"edge\":1}")
	A.arrive(list("owner" = "carol", "from" = "asia", "edge" = 1), TRUE)
	A.travel_refused(human("alice"), "europe", "The trail is busy. Try again in a moment.")
	A.count("alice", "atlas", 2)
	A.count("alice", "atlas", 3)
	A.heartbeat()
	A.world_saved("finished", TRUE, 4.5)
	var/process/player_activity/P = new
	P.setup()
	check("process fires each minute", P.schedule_interval == 600)
	var/list/L = lines_of(path)
	check("header first", length(L) && L[1]["e"] == "boot" && L[1]["region"] == "gaia" && L[1]["v"] == 1)
	var/list/by = list()
	for (var/list/E in L)
		by[E["e"]] = E
	var/list/D = by["death"]
	check("death line", D && D["a"] == "alice" && D["cause"] == "starved" && D["fac"] == "Rome" && D["tod"] == "Night" && D["season"] == "WINTER")
	var/deaths = 0
	for (var/list/E in L)
		if (E["e"] == "death") deaths++
	check("unowned npc death not recorded", deaths == 1)
	check("depart line", by["depart"] && by["depart"]["to"] == "europe" && by["depart"]["how"] == "edge")
	check("arrive line", by["arrive"] && by["arrive"]["from"] == "asia" && !by["arrive"]["back"])
	check("refused line", by["refused"] && by["refused"]["why"] == "busy")
	check("counters merged", by["counts"] && by["counts"]["c"]["atlas"] == 5)
	check("health line", by["health"] && by["health"]["dil"] == 12.3 && by["health"]["cpu"] == 56.8)
	check("save line", by["save"] && by["save"]["ok"] == 1 && by["save"]["sec"] == 4.5)
	var/text = file2text(path)
	check("no ip or cid", !findtext(text, "\"ip\"") && !findtext(text, "\"cid\"") && !findtext(text, "computer"))
	check("no character names", !findtext(text, "real_name"))

	// A second flush appends without a second header.
	A.record("test")
	A.flush()
	L = lines_of(path)
	var/headers = 0
	for (var/list/E in L)
		if (E["e"] == "boot") headers++
	check("one header per boot and day", headers == 1 && L[length(L)]["e"] == "test")

	// The buffer is capped and the drops are counted.
	for (var/i in 1 to 2100)
		A.record("spam")
	check("buffer capped", length(A.lines) == 2000 && A.dropped == 100)
	A.flush()
	L = lines_of(path)
	check("drop count written", L[length(L)]["e"] == "dropped" && L[length(L)]["n"] == 100)

	// Off means nothing is written.
	config.player_activity = FALSE
	var/before = length(file2text(path))
	A.record("off")
	A.count("alice", "x")
	A.flush()
	check("off writes nothing", length(file2text(path)) == before && !length(A.lines))

	fdel("data/player_activity/")
	fdel("result.json")
	text2file(json_encode(list("checks" = length(checks), "failed_labels" = failed)), "result.json")
	del(src)
