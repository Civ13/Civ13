// Native fireman-carry fixture: real humans and grabs on a tiny map.
// Built by tests/fireman_carry/run_native.py; not part of the offline suite.
// Fixture-only runtimes (no observers, ticker or job datums) are expected and
// counted; the carry oracle lines are what the runner checks.
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf/floor/plating
	area = /area/caribbean
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/global/carry_errors = 0
/world/Error(exception/E)
	carry_errors++
	world.log << "RUNTIME: [E] at [E.file]:[E.line]"
	return ..()
/world/New()
	..()
	spawn(5)
		carry_run()
		world.log << "COMPLETE errors=[carry_errors]"
		shutdown()
/proc/carry_check(condition, label)
	world.log << "CHECK [condition ? "PASS" : "FAIL"] [label]"

/proc/carry_run()
	makeDatumRefLists()
	var/mob/living/human/A = new(locate(3,3,1))
	var/mob/living/human/V = new(locate(4,3,1))
	sleep(5)
	V.lying = TRUE
	V.Weaken(200)
	var/obj/item/weapon/grab/G = new(A, V)
	A.put_in_active_hand(G)
	G.state = GRAB_AGGRESSIVE
	carry_check(G.carry_target_downed(), "downed-target")
	carry_check(A.grab_move_delay() == 1, "plain-grab-delay")
	var/turf/initial_patient_turf = get_turf(V)
	A.prone = TRUE
	G.fireman_carry_click()
	carry_check(!G.carrying && V.loc == initial_patient_turf, "prone-carrier-cannot-begin-lift")
	A.prone = FALSE
	spawn(5)
		A.prone = TRUE
	G.fireman_carry_click()
	carry_check(A.prone && !G.carrying && V.loc == initial_patient_turf, "going-prone-cancels-timed-lift")
	A.prone = FALSE
	G.fireman_carry_click()
	carry_check(G.carrying, "carry-starts")
	carry_check(V.loc == A.loc, "carried-on-carrier-tile")
	carry_check(V.pixel_y == 14 && V.layer > 4, "carried-over-shoulders")
	carry_check(A.grab_move_delay() < 1, "carry-faster-than-grab")
	for (var/i in 1 to 2)
		A.Move(get_step(A, EAST), EAST)
		G.adjust_position()
	carry_check(A.x == 5 && V.loc == A.loc && G.carrying, "carry-follows-walk")
	G.s_click(G.hud)
	carry_check(G.state == GRAB_AGGRESSIVE && G.carrying, "no-grip-upgrade-while-carrying")
	G.last_action = 0
	G.attack(A, A)
	carry_check(!G.carrying && V.layer == 4 && V.loc == A.loc, "click-self-puts-down")
	G.last_action = 0
	G.attack(A, A)
	carry_check(G.carrying, "click-self-carries-again")
	var/turf/putdown_site = get_turf(A)
	A.prone = TRUE
	carry_check(A.grab_move_cost() == 1, "prone-carrier-gets-no-carry-discount")
	A.forceMove(get_step(A, EAST))
	G.adjust_position()
	sleep(4)
	carry_check(!G.carrying && V.loc == putdown_site && V.pixel_y == 0 && V.layer == 4 && G.state == GRAB_AGGRESSIVE, "movement-drops-patient-before-repositioning")
	A.prone = FALSE
	G.fireman_carry_click()
	carry_check(G.carrying, "standing-carrier-can-lift-again")
	V.SetWeakened(0)
	V.lying = FALSE
	V.stat = CONSCIOUS
	G.check_fireman_carry()
	carry_check(!G.carrying, "standing-up-ends-carry")
	G.last_action = 0
	G.attack(A, A)
	carry_check(!G.carrying, "standing-target-not-carried")
	qdel(G)
	carry_check(!V.grabbed_by.len && V.pixel_y == 0, "grab-release-clears-carry")
