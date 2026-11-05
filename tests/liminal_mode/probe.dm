// Liminal Facility escape round (slice 4). Runs the production round datum,
// era policy, map objects and metadata steps in the shared resource-extraction
// fixture with ordinary game startup disabled. Times are passed explicitly.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/liminal_facility/probe
	var/finished_calls = 0
/obj/map_metadata/liminal_facility/probe/New()
	liminal = new
	era_policy = new(scenario_year)
	liminal.configure(hold_seconds, deadline_minutes, team_cap)
/obj/map_metadata/liminal_facility/probe/finish()
	finished_calls++
	announced = TRUE
/mob/living/human/liminal_probe/New()
	return
/mob/living/human/liminal_probe/update_icons()
	return
var/liminal_failures = 0
var/liminal_runtime_error = FALSE
/proc/liminal_check(condition, label)
	if (!condition)
		liminal_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	liminal_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/liminal_body(x, y)
	var/mob/living/human/H = new /mob/living/human/liminal_probe(locate(x, y, 1))
	human_mob_list += H // the probe body skips the ordinary New()
	return H
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		populate_material_list()
		for (var/x in 1 to 12)
			for (var/y in 1 to 12)
				var/turf/T = locate(x, y, 1)
				T.ChangeTurf(/turf/floor/plating/steel, FALSE, FALSE)
		liminal_check(!world.port, "fixture has no listening port")
		liminal_config_checks()
		liminal_admission_checks()
		liminal_progress_checks()
		liminal_timer_checks()
		liminal_policy_checks()
		liminal_object_checks()
		liminal_threat_checks()
		liminal_scene_checks()
	catch(var/exception/e)
		liminal_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = liminal_failures, "runtime_error" = liminal_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/liminal_new_round(hold = 20, deadline = 15, cap = 4)
	var/datum/liminal_round/R = new
	R.configure(hold, deadline, cap)
	var/datum/liminal_era_policy/P = new
	P.admitted = TRUE
	R.ready(P)
	return R

/proc/liminal_config_checks()
	var/datum/liminal_round/R = new
	liminal_check(!R.configure(9, 15) && !R.configure(121, 15) && !R.configure(20, 9) && !R.configure(20, 31) && !R.configure(20, 15, 5) && !R.configure(20.5, 15), "holds outside 10-120 s, deadlines outside 10-30 min and teams over four are refused")
	liminal_check(R.state == "PLANNED", "a refused configuration stays PLANNED")
	liminal_check(R.configure(20, 15) && R.hold_needed == 200 && R.deadline_length == 9000 && R.state == "VALIDATED", "defaults are a 20 s hold and a 15 min deadline in deciseconds")
	liminal_check(!R.configure(30, 20), "configuration is fixed once validated")
	var/datum/liminal_era_policy/P = new
	liminal_check(!R.ready(P) && R.state == "VALIDATED", "READY needs an admitted era policy")
	P.admitted = TRUE
	liminal_check(R.ready(P) && R.state == "READY", "an admitted policy makes the round READY")

/proc/liminal_admission_checks()
	var/datum/liminal_round/R = liminal_new_round(20, 15, 4)
	var/list/bodies = list()
	for (var/i in 1 to 5)
		bodies += liminal_body(i, 1)
	liminal_check(R.admit(bodies[1], 100) && R.state == "EXPLORING" && R.started_at == 100, "the first admission starts the round clock")
	liminal_check(R.admit(bodies[1], 110) && R.participants.len == 1, "admitting the same body twice is idempotent")
	liminal_check(R.admit(bodies[2], 200) && R.admit(bodies[3], 300) && R.admit(bodies[4], 700), "three more join inside the 60 s window")
	liminal_check(!R.admit(bodies[5], 700), "a fifth participant is refused")
	var/datum/liminal_round/L = liminal_new_round()
	L.admit(bodies[1], 0)
	liminal_check(!L.admit(bodies[2], 601) && L.participants.len == 1, "late joins after the window are not participants")
	var/datum/liminal_round/C = liminal_new_round(20, 15, 2)
	C.admit(bodies[1], 0)
	C.admit(bodies[2], 0)
	liminal_check(!C.admit(bodies[3], 0), "a smaller configured team cap is honoured")

/proc/liminal_progress_checks()
	var/datum/liminal_round/R = liminal_new_round()
	var/mob/living/human/A = liminal_body(1, 2)
	var/mob/living/human/B = liminal_body(2, 2)
	var/mob/living/human/O = liminal_body(3, 2)
	liminal_check(R.grant(LIMINAL_FOUND_MARKER, A) == "REFUSED", "no task can be done before the round starts")
	R.admit(A, 0)
	R.admit(B, 0)
	liminal_check(R.grant(LIMINAL_SERVICE_DONE, A) == "REFUSED" && !R.flags[LIMINAL_SERVICE_DONE], "service before discovery is refused")
	liminal_check(R.grant(LIMINAL_FOUND_MARKER, O) == "REFUSED", "a non-participant cannot grant progress")
	B.stat = UNCONSCIOUS
	liminal_check(R.grant(LIMINAL_FOUND_MARKER, B) == "REFUSED", "an unconscious participant cannot grant progress")
	B.stat = CONSCIOUS
	liminal_check(R.grant(LIMINAL_FOUND_MARKER, A) == "GRANTED" && R.state == "EXPLORING", "discovery grants FOUND_MARKER")
	liminal_check(R.grant(LIMINAL_FOUND_MARKER, B) == "HELD", "discovery is shared: a teammate finds it held")
	liminal_check(R.grant("OPEN_SESAME", A) == "REFUSED", "unknown flags are refused")
	liminal_check(R.grant(LIMINAL_SERVICE_DONE, B) == "GRANTED" && R.state == "TASKS_DONE", "service after discovery grants SERVICE_DONE and TASKS_DONE")
	liminal_check(R.grant(LIMINAL_SERVICE_DONE, A) == "HELD" && R.state == "TASKS_DONE", "a repeated service does not change state")
	var/grants = 0
	for (var/line in R.history)
		if (findtext(line, "GRANT ") == 1)
			grants++
	liminal_check(grants == 2, "each flag is recorded once")

/proc/liminal_timer_checks()
	var/datum/liminal_round/R = liminal_new_round()
	var/mob/living/human/A = liminal_body(1, 3)
	R.admit(A, 0)
	liminal_check(R.advance(100, 1, 1) == "EXPLORING", "standing in the zone before the tasks does nothing")
	R.grant(LIMINAL_FOUND_MARKER, A)
	R.grant(LIMINAL_SERVICE_DONE, A)
	liminal_check(R.advance(1000, 1, 1) == "EXTRACTING" && R.hold_started == 1000, "a participant in the zone starts the hold")
	liminal_check(R.advance(1150, 1, 0) == "TASKS_DONE" && isnull(R.hold_started), "leaving the zone breaks the hold")
	R.advance(1200, 1, 1)
	liminal_check(R.advance(1399, 1, 1) == "EXTRACTING", "19.9 s of hold is not enough")
	liminal_check(R.advance(1400, 1, 1) == "ESCAPED" && R.end_reason == "EXTRACTED", "20 s of elapsed engine time escapes")
	liminal_check(R.advance(1500, 0, 0) == "ESCAPED" && !R.fail("LATE") && R.grant(LIMINAL_FOUND_MARKER, A) == "REFUSED", "an escaped round cannot change again")
	var/datum/liminal_round/D = liminal_new_round()
	D.admit(A, 0)
	liminal_check(D.advance(8999, 1, 0) == "EXPLORING", "the round runs until the deadline")
	liminal_check(D.advance(9000, 1, 0) == "FAILED" && D.end_reason == "DEADLINE", "15 minutes of elapsed time fails the round")
	var/datum/liminal_round/E = liminal_new_round()
	E.admit(A, 0)
	E.grant(LIMINAL_FOUND_MARKER, A)
	E.grant(LIMINAL_SERVICE_DONE, A)
	E.advance(8800, 1, 1)
	liminal_check(E.advance(9000, 1, 1) == "ESCAPED", "a hold completing on the deadline step escapes")
	var/datum/liminal_round/N = liminal_new_round()
	N.admit(A, 0)
	liminal_check(N.advance(50, 0, 0) == "FAILED" && N.end_reason == "NO_SURVIVORS", "no living participant fails the round")

/proc/liminal_policy_checks()
	var/datum/liminal_era_policy/P = new
	liminal_check(P.permits_equipment(/obj/item/flashlight/flashlight) && !P.permits_equipment(/obj/item/weapon/gun/projectile/pistol/m9beretta) && !P.permits_equipment(/obj/item/flashlight/modern/darknight), "only the 1990 kit is issued")
	var/mob/living/human/H = liminal_body(6, 6)
	liminal_check(!P.issue(/obj/item/weapon/gun/projectile/pistol/m9beretta, H, slot_l_hand) && !(locate(/obj/item/weapon/gun) in H), "issuing an unlisted item creates nothing")
	new /obj/structure/filingcabinet(locate(10, 10, 1))
	liminal_check(P.admit_z(1) && P.admitted, "a map of listed props admits the policy")
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = new(locate(10, 11, 1))
	liminal_check(!P.admit_z(1) && !P.admitted && ("[G.type]" in P.refused), "an unlisted object on the map refuses the policy")
	qdel(G)
	P.scenario_year = 1994
	liminal_check(!P.admit_z(1), "a year outside 1990-1993 is refused")
	var/material/M = get_material_by_name("steel")
	var/list/made = M.generate_recipes_civs(list(185, 185, 185), "liminal")
	var/only_utensils = TRUE
	for (var/datum/stack_recipe/S in made)
		if (!ispath(S.result_type, /obj/item/weapon/material/kitchen/utensil))
			only_utensils = FALSE
	liminal_check(only_utensils, "the liminal recipe list offers no material crafting beyond utensils")

/proc/liminal_object_checks()
	var/obj/map_metadata/liminal_facility/probe/M = new(locate(1, 12, 1))
	map = M
	liminal_check(M.override_global_recipes == "liminal" && !M.research_active && M.ordinal_age == 7 && M.age == "1990" && !M.gamemode_vote, "metadata closes recipes and research and binds 1990")
	var/area/caribbean/liminal/extraction/X = new
	X.contents += locate(11, 1, 1)
	X.contents += locate(12, 1, 1)
	var/obj/structure/liminal_marker/K = new(locate(4, 8, 1))
	var/obj/structure/liminal_marker/service/S = new(locate(8, 8, 1))
	var/obj/structure/liminal_gate/G = new(locate(10, 1, 1))
	liminal_check(G.density && G.opacity && (G in liminal_gates), "the egress gate starts sealed and registered")
	var/mob/living/human/A = liminal_body(4, 7)
	var/mob/living/human/B = liminal_body(8, 7)
	liminal_check(M.prepare() && M.liminal.state == "READY", "metadata admits the fixture props and becomes READY")
	liminal_check(M.join(A) && M.join(B) && M.liminal.state == "EXPLORING", "joining admits the team")
	var/obj/item/weapon/W = new /obj/item/weapon/paper(A)
	G.attackby(W, A)
	liminal_check(G.density, "the gate cannot be forced")
	S.attack_hand(B)
	liminal_check(!M.liminal.flags[LIMINAL_SERVICE_DONE] && G.density && S.icon_state == "1980_computer_off", "the service panel refuses before the marker")
	K.attack_hand(B)
	liminal_check(!M.liminal.flags[LIMINAL_FOUND_MARKER], "a marker out of reach does nothing")
	K.attack_hand(A)
	liminal_check(M.liminal.flags[LIMINAL_FOUND_MARKER] && K.icon_state == "nboard02", "the marker grants FOUND_MARKER")
	S.attack_hand(B)
	liminal_check(M.liminal.state == "TASKS_DONE" && !G.density && !G.opacity && G.open && S.icon_state == "1980_computer_on", "the service panel opens the egress gate")
	A.loc = locate(11, 1, 1)
	B.loc = locate(12, 1, 1)
	B.stat = DEAD
	M.advance(M.liminal.started_at + 100)
	liminal_check(M.liminal.state == "EXTRACTING", "a conscious participant in the egress starts the hold")
	A.stat = UNCONSCIOUS
	M.advance(M.liminal.started_at + 150)
	liminal_check(M.liminal.state == "TASKS_DONE", "an unconscious participant does not hold the egress")
	A.stat = CONSCIOUS
	M.advance(M.liminal.started_at + 200)
	M.advance(M.liminal.started_at + 400)
	liminal_check(M.liminal.state == "ESCAPED" && M.finished_calls == 1, "holding for 20 s escapes and finishes once")
	M.advance(M.liminal.started_at + 500)
	liminal_check(M.finished_calls == 1, "finish is not repeated")
	var/obj/map_metadata/liminal_facility/probe/F = new(locate(2, 12, 1))
	map = F
	var/mob/living/human/C = liminal_body(5, 5)
	F.join(C)
	qdel(C)
	F.advance(F.liminal.started_at + 10)
	liminal_check(F.liminal.state == "FAILED" && F.liminal.end_reason == "NO_SURVIVORS" && F.finished_calls == 1, "a deleted last body fails the round")

// Slice 5: one sound-hunting threat after the arrival grace, placed out of
// sight, at most once; it hears sounds, cannot pass the sealed gate.
/proc/liminal_threat_checks()
	var/datum/liminal_round/R = liminal_new_round()
	liminal_check(!R.threat_due(1000), "no threat before the round starts")
	var/mob/living/human/A = liminal_body(1, 4)
	R.admit(A, 100)
	liminal_check(!R.threat_due(399), "no threat during the 30 s arrival grace")
	liminal_check(R.threat_due(400), "the threat is due once the grace has passed")
	liminal_check(R.threat_placed(TRUE) && R.threat_state == "SPAWNED" && !R.threat_due(5000) && !R.threat_placed(TRUE), "the threat is placed at most once")
	var/datum/liminal_round/N = liminal_new_round()
	N.admit(A, 0)
	liminal_check(N.threat_placed(FALSE) && N.threat_state == "NONE" && !N.threat_due(1000), "a map without a site never gets a threat")
	var/datum/liminal_round/T = liminal_new_round()
	T.admit(A, 0)
	T.fail("TEST")
	liminal_check(!T.threat_due(1000), "a finished round places no threat")

	var/obj/map_metadata/liminal_facility/probe/M = new(locate(3, 12, 1))
	map = M
	latejoin_turfs["LiminalThreat"] = null
	var/mob/living/human/B = liminal_body(1, 1)
	M.prepare()
	M.join(B)
	var/start = M.liminal.started_at
	liminal_check(!M.place_threat(start + 400) && M.liminal.threat_state == "NONE" && !M.threat, "with no exported site the round records NONE")
	var/obj/map_metadata/liminal_facility/probe/S = new(locate(4, 12, 1))
	map = S
	human_mob_list = list() // only the bodies placed below
	new /obj/effect/landmark{name = "LiminalThreat"}(locate(12, 10, 1))
	liminal_check(S.threat_site() == locate(12, 10, 1), "the LiminalThreat landmark names the site")
	var/mob/living/human/C = liminal_body(11, 9)
	S.prepare()
	S.join(C)
	start = S.liminal.started_at
	liminal_check(!S.place_threat(start + 299) && !S.threat, "the site stays empty during the grace")
	liminal_check(!S.place_threat(start + 400) && !S.threat && S.liminal.threat_state == "WAITING", "a participant near the site defers the threat")
	C.loc = locate(12, 3, 1)
	S.threat_clearance = 3
	liminal_check(!S.place_threat(start + 410) && !S.threat, "a participant with a clear line to the site defers the threat")
	for (var/x in 1 to 12)
		var/turf/W = locate(x, 6, 1)
		W.ChangeTurf(/turf/wall/cement, FALSE, FALSE)
	liminal_check(!(C in hearers(world.view, locate(12, 10, 1))), "a wall row blocks the line to the site")
	var/mob/living/human/V = liminal_body(10, 10)
	liminal_check(!S.place_threat(start + 415) && !S.threat, "a late explorer who is not a participant also defers the threat")
	var/obj/structure/closet/K = new(locate(10, 9, 1))
	V.loc = K
	liminal_check(!S.place_threat(start + 416) && !S.threat, "someone hiding in a locker near the site defers it too")
	V.stat = DEAD
	liminal_check(S.place_threat(start + 420) && istype(S.threat, /mob/living/simple_animal/hostile/echofiend) && get_turf(S.threat) == locate(12, 10, 1), "with nobody near or in line one echofiend appears at the site")
	for (var/x in 1 to 12)
		var/turf/W = locate(x, 6, 1)
		W.ChangeTurf(/turf/floor/plating/steel, FALSE, FALSE)
	C.loc = null
	var/mob/living/simple_animal/hostile/echofiend/E = S.threat
	liminal_check(!S.place_threat(start + 900) && S.liminal.threat_state == "SPAWNED", "no second threat is placed")
	var/n = 0
	for (var/mob/living/simple_animal/hostile/echofiend/X in world)
		n++
	liminal_check(n == 1, "exactly one threat exists")
	playsound(locate(8, 10, 1), 'sound/effects/footsteps/tile1-2.ogg', 50, TRUE)
	liminal_check(E.investigate_turf == locate(8, 10, 1), "a sound within earshot sends the threat to investigate it")
	playsound(E.loc, 'sound/animals/monsters/growl1.ogg', 100, TRUE)
	liminal_check(E.investigate_turf == locate(8, 10, 1), "its own growl does not cancel an investigation")
	E.set_investigate_turf(null)
	playsound(locate(1, 1, 1), 'sound/effects/footsteps/tile1-2.ogg', 50, TRUE)
	liminal_check(E.investigate_turf == locate(1, 1, 1), "the 15-tile earshot covers the fixture")
	var/obj/structure/liminal_gate/G = new(locate(11, 10, 1))
	var/turf/here = get_turf(E)
	E.Move(locate(11, 10, 1), WEST)
	liminal_check(get_turf(E) == here, "the sealed gate stops the threat")
	G.release()
	E.Move(locate(11, 10, 1), WEST)
	liminal_check(get_turf(E) == locate(11, 10, 1), "an open gate lets it through")
	var/obj/map_metadata/liminal_facility/probe/Q = new(locate(7, 12, 1))
	map = Q
	var/mob/living/human/Y = liminal_body(1, 3)
	Q.prepare()
	Q.join(Y)
	Y.loc = null
	liminal_check(!Q.place_threat(Q.liminal.started_at + 400) && Q.threat == E && Q.liminal.threat_state == "SPAWNED", "a restored world that already holds the threat does not get a second one")
	var/obj/map_metadata/liminal_facility/probe/O = new(locate(5, 12, 1))
	map = O
	O.threat_enabled = FALSE
	var/mob/living/human/F = liminal_body(1, 2)
	O.prepare()
	O.join(F)
	liminal_check(!O.place_threat(O.liminal.started_at + 400) && O.liminal.threat_state == "NONE", "threats can be switched off per map")

/proc/liminal_scene_checks()
	var/area/caribbean/liminal/L = new
	liminal_check(L.location == AREA_INSIDE && L.sound_env == 11 && !L.ambience.len, "the facility is indoors, with hallway reverb and no looping ambience")
	var/obj/map_metadata/liminal_facility/probe/M = new(locate(6, 12, 1))
	liminal_check(M.times_of_day.len == 1 && M.times_of_day[1] == "Night" && M.no_time_of_day_cycle && !M.ambience.len, "the round keeps one dim time of day")
	var/obj/structure/lamp/lamp_big/alwayson/white/T = new(locate(2, 6, 1))
	var/obj/structure/lamp/lamp_small/alwayson/white/B = new(locate(3, 6, 1))
	liminal_check(T.on && !T.powerneeded && T.light_range == 4 && B.on && !B.powerneeded && B.light_range == 3, "tubes and bulbs light steadily without power")
	var/datum/liminal_era_policy/P = new
	liminal_check(P.permits_prop(T.type) && P.permits_prop(B.type) && !P.permits_prop(/obj/structure/lamp/lamp_big), "only the unpowered lights are on the prop list")
	var/obj/item/flashlight/flashlight/FL = new(locate(4, 6, 1))
	liminal_check(P.permits_equipment(FL.type), "the issued flashlight is the handheld light")
