// Native probe for lifts between storeys
// (code/modules/multiz/lifts.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/lifts/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 8
	maxz = 3
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/lf_probe/New()
	return
/mob/living/human/lf_fixture
	m_intent = "stealth"
	var/mood_gain = 0
/mob/living/human/lf_fixture/New()
	return
/mob/living/human/lf_fixture/adaptStat(stat, amount)
	return
/mob/living/human/lf_fixture/update_body(update_icons = 1, forced = FALSE)
	return
/mob/living/human/lf_fixture/update_icons()
	return
/mob/living/human/lf_fixture/regenerate_icons()
	return
/mob/living/human/lf_fixture/adjust_mood(amount, reason)
	mood_gain += amount
var/lf_failures = 0
var/lf_runtime_error = FALSE
/proc/lf_check(condition, label)
	if (!condition)
		lf_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	lf_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/lf_probe
		lf_checks()
	catch(var/exception/e)
		lf_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = lf_failures, "runtime_error" = lf_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/lf_checks()
	new /turf/sky/building(locate(5, 5, 2))
	new /turf/sky/building(locate(5, 5, 3))
	var/turf/bottom = locate(5, 5, 1)
	var/obj/structure/lift_platform/P = new(bottom)
	var/list/levels = P.shaft_levels()
	lf_check(levels.len == 3 && levels[1] == 1 && levels[3] == 3, "the shaft reaches three stops ([json_encode(levels)])")
	lf_check(P.drive_kind(P.best_drive()) == 0 && P.travel_time(P.best_drive(), 2) == 120, "with no drive it is wound by hand, a minute a storey")

	var/obj/item/stack/rods/R = new(bottom)
	lf_check(P.arrive(3) && P.z == 3 && R.z == 3, "it rides to the top with what stands on it")
	lf_check(castle_trapdoor_holds(locate(5, 5, 3), R), "the platform is floor in the open air")
	levels = P.shaft_levels()
	lf_check(levels.len == 3 && levels[1] == 1, "from the top it still sees the whole shaft ([json_encode(levels)])")

	var/obj/structure/lift_call/C = new(locate(4, 5, 2))
	lf_check(C.find_platform() == P, "a bell beside the shaft finds the platform above")

	var/obj/structure/lift_drive/steam/E = new(locate(6, 5, 1))
	E.fuel = 10
	lf_check(P.drive_kind(P.best_drive()) == 2, "a fuelled steam engine beside the shaft drives it")
	lf_check(P.travel_time(P.best_drive(), 2) == 42, "steam winds two storeys in about four seconds ([P.travel_time(P.best_drive(), 2)])")
	lf_check(E.spend(2) && E.fuel == 8, "each storey burns fuel")
	E.fuel = 0
	lf_check(P.drive_kind(P.best_drive()) == 0, "a cold engine leaves it to the hand winch")

	lf_check(P.arrive(1) && P.z == 1, "it comes back down")
	lf_check_transactions(P, bottom)
	lf_check_reachable_call()

	var/obj/structure/anvil/A = new(bottom)
	A.anchored = TRUE
	lf_check(!P.load_refusal(), "anchored equipment is not part of the initial load")
	A.anchored = FALSE
	lf_check(P.load_refusal(), "a wooden lift won't take a loose anvil")
	var/mob/living/human/lf_fixture/operator = new(bottom)
	lf_check(!P.finish_travel(operator, 2, P.shaft_levels()) && P.loc == bottom && A.loc == bottom, "completion rechecks new load before moving")
	var/obj/structure/lift_platform/iron/I = new(locate(8, 5, 1))
	A.loc = I.loc
	lf_check(!I.load_refusal(), "an iron lift car takes it")

	new /obj/covers/repairedfloor(locate(5, 5, 2))
	levels = P.shaft_levels()
	lf_check(levels.len == 1, "a floor laid over the shaft blocks it ([json_encode(levels)])")


// Stay with a fixed seat, but travel with a portable seat in either direction.
/proc/lf_check_transactions(obj/structure/lift_platform/P, turf/bottom)
	var/mob/living/human/lf_fixture/fixed_rider = new(bottom)
	var/mob/living/human/lf_fixture/portable_rider = new(bottom)
	var/obj/structure/bed/chair/fixed_seat = new(bottom)
	var/obj/structure/bed/chair/portable_seat = new(bottom)
	fixed_seat.anchored = TRUE
	portable_seat.anchored = FALSE
	lf_check(fixed_seat.buckle_mob(fixed_rider) && portable_seat.buckle_mob(portable_rider), "fixtures buckle both riders to their chairs")
	var/list/carried = P.riders()
	lf_check(!(fixed_rider in carried) && !(fixed_seat in carried) && (portable_rider in carried) && (portable_seat in carried), "load includes only the portable seat and its rider")
	lf_check(P.arrive(2) && fixed_rider.loc == bottom && fixed_rider.buckled == fixed_seat && fixed_seat.loc == bottom, "fixed seat and rider stay together at the starting stop")
	lf_check(portable_rider.loc == P.loc && portable_rider.buckled == portable_seat && portable_seat.loc == P.loc, "portable seat and rider arrive together")
	lf_check(P.arrive(1) && portable_rider.loc == bottom && portable_seat.loc == bottom, "portable seat and rider return together")
	qdel(fixed_seat)
	qdel(portable_seat)
	qdel(fixed_rider)
	qdel(portable_rider)

// The middle floor stops the lower lift but is the upper lift's bottom stop.
/proc/lf_check_reachable_call()
	new /turf/sky/building(locate(3, 2, 3))
	var/obj/structure/lift_platform/lower = new(locate(3, 2, 1))
	var/obj/structure/lift_platform/upper = new(locate(3, 2, 3))
	var/obj/structure/lift_call/button/call_button = new(locate(2, 2, 2))
	lf_check(!(2 in lower.shaft_levels()) && (2 in upper.shaft_levels()), "the two lifts belong to different shafts")
	lf_check(call_button.find_platform() == upper, "the call finds a platform that reaches this floor")
	qdel(upper)
	lf_check(!call_button.find_platform(), "an unreachable platform is not called")
