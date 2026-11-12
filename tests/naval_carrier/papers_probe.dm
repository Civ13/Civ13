// The craft core (code/modules/craft/, docs/craft-core.md): a turf-built
// vessel is a craft through a template body that forwards to it; moves and
// turns made through the body reach the craft's hooks; drives add up to a
// push per tile of hull; a register decides who may steer; berths answer a
// docking request with a ticket; charts hold tokens, sites and hazards; a
// plane pool hands out levels.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

// A register whose owners are about when the probe says so (nobody has a
// client in the fixture).
var/papers_owners_about = FALSE
/datum/craft_register/probe/owners_online()
	return party ? papers_owners_about : FALSE

/proc/naval_checks()
	naval_fixture()
	var/datum/vessel/schooner/S = new
	naval_check(S.place(30, 20, 2, EAST), "the schooner is laid on the sea ([S.last_refusal])")
	var/obj/structure/vessel_helm/helm = null
	for (var/turf/T in S.cells())
		helm = locate(/obj/structure/vessel_helm) in T
		if (helm)
			break
	naval_check(helm && helm.vessel == S, "her wheel is aboard and connected")
	var/mob/living/human/naval_probe/ann = new(get_step(helm, EAST))
	ann.real_name = "Ann"
	ann.civilization = "Reds"
	var/mob/living/human/naval_probe/bob = new(get_step(helm, NORTH))
	bob.real_name = "Bob"
	bob.civilization = "Blues"
	var/mob/living/human/naval_probe/cat = new(get_step(helm, SOUTH))
	cat.real_name = "Cat"
	cat.civilization = "Reds"

	// ---- An unregistered ship sails for anyone ----
	naval_check(helm.steer_access(bob) == CRAFT_HELM_FREE && isnull(vessel_fitting_refusal(S, bob)), "an unregistered ship answers to anyone")
	naval_check(isnull(helm.ship_register()), "and has no papers until someone opens them")
	var/datum/craft/C = helm.ship_craft()
	C.register = new /datum/craft_register/probe
	var/datum/craft_register/R = helm.ship_register(TRUE)
	naval_check(R == C.register && !R.party && helm.steer_access(bob) == CRAFT_HELM_FREE, "blank papers guard nothing")
	naval_check(findtext(R.summary_text(S.name), "not registered"), "blank papers say so")
	helm.before_save()
	naval_check(helm.register_state == "", "blank papers are not saved")

	// ---- Registering ----
	helm.papers_action(ann, R, "Register her to Reds")
	naval_check(R.party == party_train_faction_party("Reds") && R.role_of(ann) == CRAFT_ROLE_CAPTAIN, "Ann registers her to the Reds and is her captain")
	naval_check(!R.claim(bob) && R.party == party_train_faction_party("Reds"), "a registered ship cannot be registered again")
	naval_check(helm.steer_access(ann) == CRAFT_HELM_FREE && helm.steer_access(cat) == CRAFT_HELM_FREE, "her owners take the wheel freely, listed or not")

	// ---- Strangers ----
	papers_owners_about = FALSE
	naval_check(helm.steer_access(bob) == CRAFT_HELM_CHAINED, "with no owner about the wheel is chained to a stranger")
	naval_check(findtext(vessel_fitting_refusal(S, bob), "belongs to Reds"), "and so are her levers and radar ([vessel_fitting_refusal(S, bob)])")
	papers_owners_about = TRUE
	naval_check(helm.steer_access(bob) == CRAFT_HELM_FORCE, "while an owner is about a stranger can force the wheel")
	naval_check(isnull(vessel_fitting_refusal(S, bob)), "and work her fittings")
	papers_owners_about = FALSE

	// ---- Joining the crew ----
	helm.papers_action(bob, R, "Ask to join")
	naval_check(!R.requests.len && !R.is_crew(bob), "she takes no new crew until her owners say how")
	R.join_mode = CRAFT_JOIN_ASK
	helm.papers_action(bob, R, "Ask to join")
	naval_check(("Bob" in R.requests) && !R.is_crew(bob), "asked, Bob's request waits for an answer")
	R.set_role("Bob", CRAFT_ROLE_HAND)
	naval_check(R.is_crew(bob) && isnull(vessel_fitting_refusal(S, bob)) && helm.steer_access(bob) == CRAFT_HELM_CHAINED, "a hand works the fittings but not the wheel")
	R.set_role("Bob", CRAFT_ROLE_HELMSMAN)
	naval_check(helm.steer_access(bob) == CRAFT_HELM_FREE, "a helmsman takes the wheel")
	naval_check(!helm.papers_still_valid(bob, R) && helm.papers_still_valid(ann, R) && helm.papers_still_valid(cat, R), "only owners and the captain keep the papers")
	var/text = R.summary_text(S.name)
	naval_check(findtext(text, "registered to Reds") && findtext(text, "Bob (helmsman)") && findtext(text, "must ask"), "the papers read back ([text])")

	// ---- The papers are saved by the wheel ----
	R.memo = "Fresh water at the north quay."
	helm.before_save()
	naval_check(length(helm.register_state) && length(helm.vessel_state), "the wheel saves the papers beside the ship")
	C.register = null
	naval_check(helm.steer_access(bob) == CRAFT_HELM_FREE, "without papers she is open again")
	helm.after_load()
	var/datum/craft_register/R2 = helm.ship_register()
	naval_check(R2 && R2 != R && R2.party == R.party && R2.crew["Ann"] == CRAFT_ROLE_CAPTAIN && R2.crew["Bob"] == CRAFT_ROLE_HELMSMAN && R2.join_mode == CRAFT_JOIN_ASK && R2.memo == R.memo, "and the load brings them back")
	naval_check(helm.steer_access(bob) == CRAFT_HELM_FREE && helm.steer_access(cat) == CRAFT_HELM_FREE, "with the same people at the wheel")

	// ---- Barring and giving up ----
	R2.bar("Bob")
	naval_check(!R2.is_crew(bob) && helm.steer_access(bob) == CRAFT_HELM_CHAINED, "a barred helmsman is a stranger again")
	R2.give_up()
	naval_check(!R2.party && !R2.crew.len && !R2.barred.len && helm.steer_access(bob) == CRAFT_HELM_FREE, "a ship given up is anyone's")
	helm.before_save()
	naval_check(helm.register_state == "", "and saves no papers")

	// ---- The ship keeps her papers through a hop and a turn ----
	R2.claim(ann)
	naval_check(S.relocate(34, 20, EAST) && S.turn_to(NORTH) && helm.ship_register() == R2 && helm.vessel == S, "her papers ride with her")
	S.remove()
	qdel(S)
	naval_check(!crafts.len, "a ship that is gone leaves no craft behind")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
