// Shared transfer contract, through the real aircraft and submarine wrappers.
// Adapters suppress constructors, inject the collection snapshot, record icon /
// vision effects, and replace forceMove's external hooks with native loc writes.
// This tests ordering/cleanup, not Entered/Exited, falling, rendering or GC.
var/datum/level_shift_probe/level_shift_state

/datum/level_shift_probe
	var/obj/structure/vehicleparts/axis/controller
	var/list/collected = list()
	var/list/events = list()
	var/list/owned = list()
	var/list/expected_tiles = list()
	var/collections = 0
	var/atom/movable/fail_mover
	var/atom/movable/retire_on_frame
	var/exception/injected

/datum/level_shift_probe/proc/collect(trigger_mines)
	collections++
	aircraft_check(!trigger_mines, "level shift collects without triggering mines")
	controller.transporting = collected.Copy()

/datum/level_shift_probe/proc/move(atom/movable/M, atom/destination)
	aircraft_check(controller.transforming_vehicle, "movement runs under the vehicle guard")
	for (var/turf/T in expected_tiles)
		aircraft_check(T.vehicle_transforming == controller && (T in controller.transform_tiles), "all source and destination tiles are guarded before movement")
	var/collections_before = collections
	aircraft_check(!controller.shift_vehicle_level(destination.z) && collections == collections_before, "reentrant shift is rejected before collection")
	if (M == fail_mover)
		throw injected
	events += M
	M.loc = destination
	if (istype(M, /obj/structure/vehicleparts/frame) && retire_on_frame)
		// Model a queued-deleted object still retained in the snapshot.
		retire_on_frame.gc_destroyed = GC_QUEUED_FOR_QUEUING

/datum/level_shift_probe/proc/icon_effect(obj/O)
	aircraft_check(!controller.transforming_vehicle && !controller.transform_tiles, "icons refresh only after guard release")
	events += "icon"

/datum/level_shift_probe/proc/clean()
	for (var/turf/T in expected_tiles)
		aircraft_check(!T.vehicle_transforming, "level shift releases every touched tile")
	aircraft_check(!controller.transforming_vehicle && !controller.transform_tiles, "level shift releases controller state")

/datum/level_shift_probe/proc/dispose()
	// Do not exercise vehicle destruction or queued deletion in this fixture.
	// Remove all test atoms from the map before the existing flight cases run.
	for (var/atom/movable/M in owned)
		M.gc_destroyed = null
		M.loc = null

/obj/structure/vehicleparts/axis/aircraft/level_shift_probe/New()
	return
/obj/structure/vehicleparts/axis/aircraft/level_shift_probe/add_transporting(trigger_mines = TRUE)
	level_shift_state.collect(trigger_mines)
/obj/structure/vehicleparts/axis/ship/submarine/level_shift_probe/New()
	return
/obj/structure/vehicleparts/axis/ship/submarine/level_shift_probe/add_transporting(trigger_mines = TRUE)
	level_shift_state.collect(trigger_mines)

/obj/structure/vehicleparts/frame/level_shift_probe/New()
	return
/obj/structure/vehicleparts/frame/level_shift_probe/forceMove(atom/destination, special_event, list/throw_hop_token = null)
	level_shift_state.move(src, destination)
	return TRUE
/obj/structure/vehicleparts/frame/level_shift_probe/update_icon()
	level_shift_state.icon_effect(src)
/obj/level_shift_probe/New()
	return
/obj/level_shift_probe/forceMove(atom/destination, special_event, list/throw_hop_token = null)
	level_shift_state.move(src, destination)
	return TRUE
/obj/level_shift_probe/update_icon()
	level_shift_state.icon_effect(src)
/mob/living/level_shift_probe/New()
	return
/mob/living/level_shift_probe/forceMove(atom/destination, special_event, list/throw_hop_token = null)
	level_shift_state.move(src, destination)
	return TRUE
/mob/living/level_shift_probe/update_vision_cone()
	aircraft_check(!level_shift_state.controller.transforming_vehicle, "passenger vision refreshes after guard release")
	level_shift_state.events += "vision"

/proc/level_shift_call(obj/structure/vehicleparts/axis/A, target_z, dx = 0, dy = 0)
	if (istype(A, /obj/structure/vehicleparts/axis/aircraft))
		var/obj/structure/vehicleparts/axis/aircraft/plane = A
		return plane.aircraft_shift(target_z, dx, dy)
	var/obj/structure/vehicleparts/axis/ship/submarine/boat = A
	return boat.shift_level(target_z)

/proc/level_shift_case(submarine)
	var/datum/level_shift_probe/S = new
	level_shift_state = S
	var/obj/structure/vehicleparts/frame/level_shift_probe/F = new(locate(5, 5, 1))
	var/obj/structure/vehicleparts/frame/level_shift_probe/G = new(locate(6, 5, 1))
	var/obj/structure/vehicleparts/axis/A
	if (submarine)
		A = new /obj/structure/vehicleparts/axis/ship/submarine/level_shift_probe(F)
	else
		A = new /obj/structure/vehicleparts/axis/aircraft/level_shift_probe(F)
	S.controller = A
	F.axis = A
	G.axis = A
	var/obj/level_shift_probe/cargo = new(F.loc)
	var/obj/level_shift_probe/nested = new(cargo)
	var/obj/level_shift_probe/stale = new(F.loc)
	stale.gc_destroyed = GC_QUEUED_FOR_QUEUING
	var/obj/level_shift_probe/unlocated = new
	var/mob/living/level_shift_probe/passenger = new(F.loc)
	S.owned = list(A, F, G, cargo, nested, stale, unlocated, passenger)
	// Nonframes deliberately precede frames, with cargo and frames duplicated
	// across lists. A and nested are retained but not directly turf-located.
	S.collected = list(cargo, passenger, G, F, stale, nested, unlocated)
	A.components = list(F, G, cargo, A, nested, stale)
	var/dx = submarine ? 0 : 2
	var/dy = submarine ? 0 : -1
	S.expected_tiles = list(F.loc, G.loc, locate(5 + dx, 5 + dy, 2), locate(6 + dx, 5 + dy, 2))
	aircraft_check(level_shift_call(A, 2, dx, dy), "[submarine ? "submarine" : "aircraft"] wrapper completes level shift")
	aircraft_check(F.loc == locate(5 + dx, 5 + dy, 2) && G.loc == locate(6 + dx, 5 + dy, 2) && cargo.loc == F.loc && passenger.loc == F.loc, "frames, cargo and passenger use original coordinates and offsets")
	aircraft_check(A.loc == F && get_turf(A) == F.loc && nested.loc == cargo && get_turf(nested) == F.loc, "nested controller and cargo stay nested and travel with their containers")
	aircraft_check(stale.loc == locate(5, 5, 1) && !unlocated.loc, "queued-deleted and unlocated snapshot entries are skipped")
	aircraft_check(S.events.len == 8 && S.events[1] == G && S.events[2] == F && S.events[3] == cargo && S.events[4] == passenger && S.events[5] == "icon" && S.events[6] == "icon" && S.events[7] == "icon" && S.events[8] == "vision", "deduplicated frames move first, then nonframes, then object icons, then passenger vision")
	S.clean()

	// Each invalid destination is checked before any mover can move.
	S.events.Cut()
	var/collections_before = S.collections
	aircraft_check(!level_shift_call(A, 0) && S.collections == collections_before, "zero target is rejected before collection")
	A.transforming_vehicle = TRUE
	aircraft_check(!level_shift_call(A, 1) && S.collections == collections_before, "busy controller is rejected before collection")
	A.transforming_vehicle = FALSE
	aircraft_check(!level_shift_call(A, world.maxz + 1) && !S.events.len && F.z == 2 && cargo.z == 2, "out-of-world level moves nothing")
	if (!submarine)
		// First frame has a valid destination; the later frame is off-map.
		S.collected = list(F, G, cargo, passenger)
		aircraft_check(!level_shift_call(A, 1, world.maxx - F.x, 0) && !S.events.len && F.z == 2 && G.z == 2, "later x-edge failure prevalidates the entire snapshot")
		aircraft_check(!level_shift_call(A, 1, 0, -F.y) && !S.events.len, "y-edge failure moves nothing")
	S.clean()

	// A frame callback retires a retained cargo before the nonframe pass.
	S.retire_on_frame = cargo
	S.expected_tiles = list(F.loc, G.loc, locate(F.x, F.y, 1), locate(G.x, G.y, 1))
	aircraft_check(level_shift_call(A, 1) && F.z == 1 && G.z == 1 && passenger.z == 1 && cargo.z == 2, "nonframe deleted during the frame pass is not moved")
	S.clean()
	S.retire_on_frame = null
	cargo.gc_destroyed = null

	// Throw after both frames and cargo have moved, before the passenger.
	S.events.Cut()
	S.collected = list(cargo, passenger, F, G)
	S.fail_mover = passenger
	S.injected = new /exception("level shift injected forceMove failure")
	S.expected_tiles = list(F.loc, G.loc, cargo.loc, locate(F.x, F.y, 2), locate(G.x, G.y, 2))
	var/caught_same = FALSE
	try
		level_shift_call(A, 2)
	catch (var/exception/shift_error)
		caught_same = shift_error == S.injected
	aircraft_check(caught_same, "forceMove exception is rethrown unchanged")
	aircraft_check(F.z == 2 && G.z == 2 && cargo.z == 2 && passenger.z == 1, "exception cleanup does not claim rollback of completed moves")
	aircraft_check(S.events.len == 3 && S.events[1] == F && S.events[2] == G && S.events[3] == cargo, "failed transfer does not run post-transfer icons or vision")
	S.clean()
	S.dispose()
	level_shift_state = null

/proc/level_shift_checks()
	level_shift_case(FALSE)
	level_shift_case(TRUE)
