// Vehicle papers (code/modules/craft/vehicle_papers.dm, docs/craft-core.md):
// a modular vehicle as a craft with an axis body, its papers in a vehicle's
// words, the lock on its controls, saving on the axis, naming, and the list
// of a party's vehicles.
/world
	hub = ""
	hub_password = ""
	maxx = 60
	maxy = 60
	maxz = 1
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

/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(/turf/floor/beach/sand)

// A register whose owners are about when the probe says so (nobody has a
// client in the fixture).
var/papers_owners_about = FALSE
/datum/craft_register/probe/owners_online()
	return party ? papers_owners_about : FALSE

/proc/papers_car(x, y)
	new /obj/effects/premadevehicles/asno/piccolino(locate(x, y, 1))
	sleep(40)
	for (var/obj/structure/vehicleparts/axis/A in vehicle_axes)
		var/turf/T = get_turf(A)
		if (T && T.x == x + 2 && T.y == y + 1)
			return A
	return null

/proc/papers_person(char_name, faction, turf/T)
	var/mob/living/human/naval_probe/H = new(T)
	H.real_name = char_name
	H.name = char_name
	H.civilization = faction
	return H

/proc/naval_checks()
	naval_fixture()
	var/obj/structure/vehicleparts/axis/A = papers_car(20, 30)
	naval_check(A && A.components.len >= 6 && A.wheel && A.wheel.control && A.wheel.drivingchair, "a car stands assembled with its controls")
	var/obj/structure/bed/chair/drivers/seat = A.wheel.drivingchair
	var/obj/item/vehicleparts/wheel/modular/W = A.wheel
	var/turf/at = get_turf(seat)
	var/mob/living/human/naval_probe/ann = papers_person("Ann", "Reds", at)
	var/mob/living/human/naval_probe/bob = papers_person("Bob", "Blues", at)
	var/mob/living/human/naval_probe/cat = papers_person("Cat", "Reds", at)

	// ---- A vehicle nobody registered drives for anyone ----
	naval_check(isnull(craft_of_axis(A, FALSE)) && A.papers_allow(bob, seat) && A.papers_steer(bob), "a car without papers answers to anyone and has no craft yet")
	naval_check(seat.seat_axis() == A, "the driver's seat knows its vehicle")
	var/datum/craft/vehicle/C = craft_of_axis(A)
	naval_check(C && C == craft_of_axis(A) && A.craft == C && (C in vehicle_crafts) && !(C in crafts), "asked for, its craft is made once and kept off the ships' list")
	var/list/cells = C.body.cells()
	naval_check(C.body.placed() && cells.len == 6 && C.body.contains(get_turf(A)) && C.body.heading() == A.dir && C.mass() == 6, "its body is the tiles its frames stand on ([cells.len]), facing as the axis does")
	naval_check(!findtext(C.name, "axis") && length(C.name), "and it has a plain name ([C.name])")
	C.register = new /datum/craft_register/probe
	var/datum/craft_register/R = C.register
	naval_check(A.papers_allow(bob, seat) && findtext(R.summary_text(C.name, C), "sits at the controls may drive it"), "blank papers guard nothing and say so in a vehicle's words")
	A.before_save()
	naval_check(A.register_state == "", "blank papers are not saved")

	// ---- Registering ----
	naval_check(("Our vehicles" in C.papers_extra(ann, R)) && !("Name the vehicle" in C.papers_extra(ann, R)), "an unregistered car offers the vehicle list but no naming")
	C.papers_action(ann, R, "Register it to Reds", seat)
	naval_check(R.party == party_train_faction_party("Reds") && R.role_of(ann) == CRAFT_ROLE_CAPTAIN, "Ann registers it to the Reds and is its commander")
	var/text = R.summary_text(C.name, C)
	naval_check(findtext(text, "Ann (commander)") && findtext(text, "It takes no new crew"), "the papers read in a vehicle's words ([text])")
	var/list/titles = C.role_titles(R)
	naval_check(titles["driver"] == CRAFT_ROLE_HELMSMAN && titles["commander"] == CRAFT_ROLE_CAPTAIN && titles["mechanic"] == CRAFT_ROLE_ENGINEER && titles["crewman"] == CRAFT_ROLE_HAND && titles["gunner"] == CRAFT_ROLE_GUNNER, "its roles are a vehicle crew's")
	naval_check(("Name the vehicle" in C.papers_extra(ann, R)) && ("Name the vehicle" in C.papers_extra(cat, R)) && !("Name the vehicle" in C.papers_extra(bob, R)), "its owners may name it; a stranger may not")
	naval_check(A.papers_allow(ann, seat) && A.papers_allow(cat, seat) && A.papers_steer(cat), "its owners take the controls freely, listed or not")

	// ---- Strangers ----
	papers_owners_about = FALSE
	naval_check(C.helm_access(bob) == CRAFT_HELM_CHAINED && !A.papers_allow(bob, seat) && !A.papers_steer(bob), "with no owner about the controls are locked to a stranger")
	W.forceMove(bob)
	var/was_on = A.engine && A.engine.on
	W.attack_self(bob)
	naval_check(A.engine && !was_on && !A.engine.on && !A.moving && A.currentspeed == 0, "and the wheel in a stranger's hands starts nothing")
	naval_check(!W.turndir(bob, "left"), "nor turns it")
	papers_owners_about = TRUE
	naval_check(C.helm_access(bob) == CRAFT_HELM_FORCE && !A.papers_steer(bob), "while an owner is about the controls can be forced, but are not his yet")
	C.forced_by = "Bob"
	naval_check(A.papers_allow(bob, seat) && A.papers_steer(bob), "once forced, he drives and steers")
	papers_owners_about = FALSE
	naval_check(!A.papers_allow(bob, seat) && A.papers_steer(bob), "if the owners leave he can still steer what is rolling, but not speed up")
	C.forced_by = null

	// ---- Crew ----
	R.set_role("Bob", CRAFT_ROLE_HAND)
	naval_check(R.is_crew(bob) && !A.papers_allow(bob, seat), "a crewman is crew but does not drive")
	R.set_role("Bob", CRAFT_ROLE_HELMSMAN)
	naval_check(A.papers_allow(bob, seat) && A.papers_steer(bob), "a driver does")
	W.attack_self(bob)
	naval_check(A.engine.on, "and the wheel in the driver's hands starts the engine")
	A.engine.on = FALSE

	// ---- The axis saves the papers and the name ----
	C.rename("Iron Duke")
	R.memo = "Park it under the trees."
	A.before_save()
	naval_check(length(A.register_state), "the axis saves the papers")
	qdel(C)
	A.craft = null
	naval_check(isnull(craft_of_axis(A, FALSE)) && A.papers_allow(cat, seat), "without a craft the car is open")
	A.after_load()
	var/datum/craft/vehicle/C2 = craft_of_axis(A, FALSE)
	var/datum/craft_register/R2 = C2 ? C2.register : null
	naval_check(C2 && C2 != C && (C2 in vehicle_crafts) && R2 && R2.party == party_train_faction_party("Reds") && R2.crew["Bob"] == CRAFT_ROLE_HELMSMAN && R2.memo == "Park it under the trees." && C2.name == "Iron Duke", "and the load brings back its craft, crew, memo and name")
	naval_check(C2.helm_access(bob) == CRAFT_HELM_FREE && C2.helm_access(papers_person("Dan", "Blues", at)) == CRAFT_HELM_CHAINED, "with the same people at the controls")

	// ---- The vehicle list ----
	var/obj/structure/vehicleparts/axis/B = papers_car(30, 30)
	var/datum/craft/vehicle/CB = craft_of_axis(B)
	CB.register = new /datum/craft_register/probe
	naval_check(CB.register.claim(cat) && party_vehicles(R2.party).len == 2, "a second car registered to the Reds makes two on their list")
	var/fleet = C2.fleet_text(ann, get_turf(A))
	naval_check(findtext(fleet, "Iron Duke: here") && findtext(fleet, "[CB.name]: 10 tiles to the east") && findtext(fleet, "standing"), "the list tells a member where each stands ([fleet])")
	naval_check(findtext(C2.fleet_text(bob, at), "no registered vehicles"), "and tells a stranger nothing of them")
	var/obj/structure/vehicleparts/axis/free = papers_car(40, 30)
	craft_of_axis(free)
	naval_check(party_vehicles(R2.party).len == 2, "a car nobody registered is on nobody's list")

	// ---- Giving up, and a wrecked vehicle ----
	R2.give_up()
	A.before_save()
	naval_check(A.register_state == "" && A.papers_allow(papers_person("Eve", "Blues", at), seat) && party_vehicles(party_train_faction_party("Reds")).len == 1, "a vehicle given up is anyone's and leaves the list")
	qdel(B)
	naval_check(!(CB in vehicle_crafts) && QDELETED(CB) && !party_vehicles(party_train_faction_party("Reds")).len, "a destroyed vehicle takes its craft and papers with it")

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
