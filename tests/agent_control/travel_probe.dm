// Native probe for agent region travel (code/modules/agent_control/agent_travel.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/agent_control/travel_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/mob/living/human/travel_probe/New()
	return
/mob/living/human/travel_probe/update_icons()
	return
/mob/living/human/travel_probe/movement_delay()
	return 1
var/travel_failures = 0
var/travel_runtime_error = FALSE
/proc/travel_check(condition, label)
	if (!condition)
		travel_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	travel_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		travel_checks()
	catch(var/exception/e)
		travel_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = travel_failures, "runtime_error" = travel_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/travel_body(x)
	var/mob/living/human/travel_probe/H = new(locate(x, 5, 1))
	H.species = new /datum/species/human
	H.stat = CONSCIOUS
	human_mob_list |= H
	return H

/proc/travel_checks()
	travel_check(is_agent_account("agent@ada"), "agent@ada is an agent account")
	travel_check(!is_agent_account("agent@") && !is_agent_account("agent@Ada") && !is_agent_account("ada") && !is_agent_account("agent@a-b"), "malformed agent accounts are refused")
	travel_check(persistence_owner_valid("agent@ada") && persistence_owner_valid("alice"), "agent accounts and ckeys are valid save owners")
	travel_check(agent_account_for("Ada Lovelace") == "agent@adalovelace", "the account is the agent name as a ckey")
	var/datum/agent_identity/A = new
	A.name = "Ada"
	var/mob/living/human/travel_probe/H = travel_body(2)
	var/datum/agent_character/C = new
	C.body = H
	C.owner_agent = "Ada"
	agent_characters[H] = C
	travel_check(agent_travel_account(H) == "agent@ada", "an agent's own character travels under its agent account")
	var/mob/living/human/travel_probe/P = travel_body(3)
	var/datum/agent_character/PC = new
	PC.body = P
	PC.handover_ckey = "alice"
	agent_characters[P] = PC
	travel_check(isnull(agent_travel_account(P)), "an opted-in player character has no agent account")
	travel_check(isnull(agent_travel_account(travel_body(4))), "a body no agent drives has no agent account")
	H.real_name = "Ada"
	H.persistence_owner_ckey = "agent@ada"
	agent_note_departure(H, "europe", "Europe")
	var/list/rows = agent_departure_rows("Ada")
	travel_check(rows.len == 1 && rows[1]["destination"] == "europe" && rows[1]["name"] == "Ada" && rows[1]["ref"] == agent_ref(H), "the departure is recorded for the agent")
	travel_check(!agent_departure_rows("Bob").len, "other agents do not see it")
	agent_characters -= H
	var/mob/living/human/travel_probe/arrived = travel_body(6)
	arrived.persistence_owner_ckey = "agent@ada"
	arrived.region_arrival_pending = TRUE
	var/mob/living/human/travel_probe/stranger = travel_body(7)
	stranger.persistence_owner_ckey = "agent@bob"
	var/mob/living/human/travel_probe/dead = travel_body(8)
	dead.persistence_owner_ckey = "agent@ada"
	dead.stat = DEAD
	agent_control.adopt_travellers(A)
	var/datum/agent_character/AC = agent_characters[arrived]
	travel_check(AC && AC.owner_agent == "Ada" && AC.body == arrived, "the arrived body becomes the agent's character")
	travel_check(!arrived.region_arrival_pending && arrived.mind, "it is no longer waiting for a player and has a mind")
	travel_check(!agent_characters[stranger] && !agent_characters[dead], "other accounts and dead bodies are left alone")
	agent_control.adopt_travellers(A)
	travel_check(agent_characters[arrived] == AC, "adopting again changes nothing")
