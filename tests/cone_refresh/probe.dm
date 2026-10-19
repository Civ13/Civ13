// Headless full-source fixture. Constructors suppress physiology/vehicle workers,
// not the procedures under test. Client image delivery alone uses a test datum.
/world
	maxx = 24
	maxy = 24
	maxz = 2
	turf = /turf/cone_probe
	area = /area
	hub = ""
	hub_password = ""
/turf/cone_probe
	luminosity = 1
	dynamic_lighting = FALSE
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/datum/cone_fixture_client
	var/list/hidden_atoms = list()
	var/list/hidden_mobs = list()
	var/list/images = list()
/mob/living/human/var/datum/cone_fixture_client/cone_client
/mob/living/human/cone_probe
	m_intent = "stealth" // Avoid unrelated footstep scheduler in disabled startup.
	var/cone_calls = 0
	var/obj/structure/vehicleparts/axis/cone_axis
	var/obj/structure/vehicleparts/frame/cone_frame
	var/turf/cone_expected
	var/cone_facing = 0
/mob/living/human/cone_probe/New()
	return
/mob/living/human/cone_probe/persistence_runtime_var(key)
	return findtext(key, "cone_") == 1 || ..()
/mob/living/human/cone_probe/update_vision_cone()
	cone_calls++
	if (cone_axis)
		var/turf/current = get_turf(src)
		cone_check(!cone_axis.transforming_vehicle && current && !current.vehicle_transforming && current == cone_expected && get_turf(cone_frame) == cone_expected && dir == cone_facing, "vehicle callback observes final geometry")
	return ..()
/mob/living/cone_target/New()
	return
/obj/structure/vehicleparts/frame/cone_probe/New()
	return
/obj/structure/vehicleparts/frame/cone_probe/update_icon()
	return
/obj/structure/vehicleparts/axis/cone_probe/New()
	return
/obj/structure/vehicleparts/axis/cone_probe/update_icon()
	return
/obj/structure/bed/chair/drivers/cone_probe/New()
	return
/obj/structure/bed/chair/mgunner/cone_probe/New()
	return
/obj/structure/bed/chair/gunner/cone_probe/New()
	return
/obj/structure/bed/chair/gunner/mtlb/cone_probe/New()
	return
/obj/structure/bed/chair/loader/cone_probe/New()
	return
/obj/structure/bed/chair/commander/cone_probe/New()
	return
/obj/structure/turret/cone_probe/New()
	return
/obj/structure/cone_wall
	density = TRUE
	opacity = TRUE
/turf/cone_probe/Entered(atom/movable/M, atom/oldloc, special_event)
	if (M)
		cone_entries++
		cone_special_event = special_event
	return ..()

var/cone_checks = 0
var/cone_entries = 0
var/cone_special_event = FALSE
var/list/cone_phases = list()
var/cone_roundtrip = 0
var/cone_runtime = FALSE
/proc/cone_check(condition, label)
	cone_checks++
	if (!condition)
		throw EXCEPTION(label)
/proc/cone_observer(turf/T)
	var/mob/living/human/cone_probe/H = new(T)
	H.cone_client = new
	H.HUDtech = list("fov" = new /obj/screen/fov)
	H.dir = NORTH
	return H

/proc/cone_forced_cases()
	var/mob/living/human/cone_probe/H = cone_observer(locate(4,4,1))
	var/entries_before = cone_entries
	cone_check(H.forceMove(locate(5,4,1), TRUE) && H.cone_calls == 1, "forced move refreshes exactly once")
	cone_check(cone_entries == entries_before + 1 && cone_special_event, "parent Entered callback and special event retained")
	cone_check(!H.forceMove(H.loc) && H.cone_calls == 1, "redundant move preserves false result without refresh")
	cone_check(H.forceMove(null) && H.cone_calls == 1, "nullspace move preserves parent result without refresh")
	cone_check(H.forceMove(locate(5,4,2)) && H.cone_calls == 2, "return from nullspace refreshes")
	cone_check(H.forceMove(locate(6,5,1)) && H.cone_calls == 3, "diagonal and compiled-z relocation refreshes")
	var/mob/living/cone_target/behind = new(locate(6,2,1))
	var/mob/living/cone_target/ahead = new(locate(6,8,1))
	H.update_vision_cone()
	cone_check(behind in H.cone_client.hidden_mobs, "native cone hides distant rear target")
	cone_check(!(ahead in H.cone_client.hidden_mobs), "native cone retains forward target")
	var/list/walls = list()
	for (var/xpos in 4 to 8)
		walls += new /obj/structure/cone_wall(locate(xpos,4,1))
	H.forceMove(locate(7,5,1))
	cone_check(!(behind in H.cone_client.hidden_mobs), "native opaque barrier removes unseen target from mask")
	for (var/obj/structure/cone_wall/W in walls)
		W.opacity = FALSE
	H.forceMove(locate(6,5,1))
	cone_check(behind in H.cone_client.hidden_mobs, "opening barrier restores native view target on relocation")
	for (var/obj/structure/cone_wall/W in walls)
		W.loc = null
	H.forceMove(locate(6,1,1))
	cone_check(!(behind in H.cone_client.hidden_mobs), "forced movement recomputes rear target membership")
	H.forceMove(locate(6,16,1))
	cone_check(!(behind in H.cone_client.hidden_mobs), "view-edge relocation drops out-of-range target")
	H.forceMove(locate(6,5,1))
	H.resting = TRUE
	H.update_vision_cone()
	cone_check(!H.cone_client.hidden_mobs.len && H.HUDtech["fov"].alpha == 0, "resting gate retained")
	H.resting = FALSE
	config.disable_fov = TRUE
	H.cone_client.hidden_mobs = list(ahead)
	H.update_vision_cone()
	cone_check(H.cone_client.hidden_mobs.len == 1 && (ahead in H.cone_client.hidden_mobs), "disabled gate preserves existing state")
	config.disable_fov = FALSE
	H.HUDtech = list()
	H.update_vision_cone()
	cone_check(H.cone_client.hidden_mobs.len == 1, "missing HUD gate retained")
	H.cone_client = null
	H.forceMove(locate(7,5,1))
	cone_check(H.loc == locate(7,5,1), "no-client forced movement remains usable")
	H.loc = null
	behind.loc = null
	ahead.loc = null

/proc/cone_vehicle(x,y,turning=FALSE)
	var/obj/structure/vehicleparts/frame/cone_probe/P = new(locate(x,y,1))
	var/obj/structure/vehicleparts/frame/cone_probe/F = new(locate(x+1,y,1))
	var/obj/structure/vehicleparts/axis/cone_probe/A = new(P)
	A.components = list(P,F)
	A.dir = NORTH
	A.maxdist = 2
	P.axis = A
	F.axis = A
	P.dir = NORTH
	F.dir = NORTH
	if (turning)
		var/obj/structure/vehicleparts/frame/cone_probe/BL = new(locate(x,y-1,1))
		var/obj/structure/vehicleparts/frame/cone_probe/BR = new(locate(x+1,y-1,1))
		BL.axis = A
		BR.axis = A
		BL.dir = NORTH
		BR.dir = NORTH
		A.components += list(BL,BR)
		A.corners = list(F,P,BR,BL)
		cone_check(A.check_matrix(), "production rotation matrix built")
	cone_check(F in range(7,A.loc), "occupied frame belongs to transport scan")
	var/mob/living/human/cone_probe/H = cone_observer(get_turf(F))
	var/obj/structure/bed/chair/drivers/cone_probe/S = new(get_turf(F))
	H.buckled = S
	S.buckled_mob = H
	S.dir = NORTH
	H.cone_axis = A
	H.cone_frame = F
	H.cone_expected = turning ? locate(x+1,y-1,1) : locate(x+1,y+1,1)
	H.cone_facing = turning ? EAST : NORTH
	return list(A,H,F,S)

/proc/cone_vehicle_cases()
	var/list/parts = cone_vehicle(5,15)
	var/obj/structure/vehicleparts/axis/A = parts[1]
	var/mob/living/human/cone_probe/H = parts[2]
	cone_check(A.do_move(), "production translation succeeds")
	cone_check(H.cone_calls == 1 && H.loc == H.cone_expected && (H in A.transporting), "translation refreshes once after final geometry")
	H.cone_axis = null
	var/calls = H.cone_calls
	A.transforming_vehicle = TRUE
	cone_check(!A.do_move() && H.cone_calls == calls, "busy translation refuses without refresh")
	A.transforming_vehicle = FALSE
	parts = cone_vehicle(14,15,TRUE)
	A = parts[1]
	H = parts[2]
	cone_check(A.do_matrix(NORTH,EAST,"right"), "production rotation succeeds")
	cone_check(H.cone_calls == 1 && H.loc == H.cone_expected && H.dir == EAST, "rotation refreshes once after final facing")
	H.cone_axis = null
	parts = cone_vehicle(14,7,TRUE)
	A = parts[1]
	H = parts[2]
	H.cone_axis = null
	var/turf/blocked = locate(15,6,1)
	blocked.density = TRUE
	cone_check(!A.do_matrix(NORTH,EAST,"right") && !H.cone_calls && H.loc == locate(15,7,1), "blocked rotation has no callback or partial move")
	blocked.density = FALSE
	// A different actor entering an active tile is not owned by the transaction.
	var/mob/living/human/cone_probe/outsider = cone_observer(locate(20,20,1))
	var/turf/T = locate(21,20,1)
	T.vehicle_transforming = A
	A.transforming_vehicle = TRUE
	cone_check(outsider.forceMove(T) && outsider.cone_calls == 1, "unrelated actor is not suppressed by active tile")
	A.release_transform_tiles(list(T))

/proc/cone_seat_cases()
	var/mob/living/human/cone_probe/H = cone_observer(locate(3,20,1))
	var/obj/structure/bed/chair/drivers/cone_probe/D = new(H.loc)
	D.buckled_mob = H
	H.buckled = D
	D.dir = EAST
	D.update_icon()
	cone_check(!H.cone_calls && H.dir == NORTH, "driver icon refresh preserves existing facing policy")
	D.post_buckle_mob()
	cone_check(H.cone_calls == 1, "driver buckle refreshes occupant")
	H.buckled = null
	D.refresh_seated_vision()
	cone_check(H.cone_calls == 1, "nonreciprocal seat reference does not refresh")
	D.buckled_mob = null
	D.refresh_seated_vision()
	cone_check(H.cone_calls == 1, "empty seat does not refresh")
	var/obj/structure/turret/cone_probe/turret = new(H.loc)
	var/obj/structure/bed/chair/mgunner/cone_probe/MG = new(H.loc)
	MG.buckled_mob = H
	H.buckled = MG
	MG.dir = SOUTH
	MG.update_icon()
	cone_check(H.dir == NORTH && H.cone_calls == 1, "machine gunner icon refresh preserves existing facing policy")
	MG.post_buckle_mob()
	cone_check(H.cone_calls == 2, "machine gunner buckle refreshes occupant")
	MG.buckled_mob = null
	for (var/seat_type in list(/obj/structure/bed/chair/gunner/cone_probe, /obj/structure/bed/chair/gunner/mtlb/cone_probe, /obj/structure/bed/chair/loader/cone_probe, /obj/structure/bed/chair/commander/cone_probe))
		var/obj/structure/bed/chair/S = new seat_type(H.loc)
		if (S.vars.Find("turret"))
			S:turret = turret
		S.buckled_mob = H
		H.buckled = S
		H.dir = NORTH
		turret.dir = SOUTH
		S.dir = SOUTH
		var/calls = H.cone_calls
		S.update_icon()
		if (seat_type == /obj/structure/bed/chair/gunner/cone_probe)
			cone_check(H.cone_calls == calls + 1 && H.dir == SOUTH && H.HUDtech["fov"].dir == SOUTH, "stationary gunner facing refreshes once")
		else
			cone_check(H.cone_calls == calls + 1 && H.dir == SOUTH && H.HUDtech["fov"].dir == SOUTH, "seat subtype final facing refresh: [seat_type]")
		S.update_icon()
		cone_check(H.cone_calls == calls + 1, "unchanged stationary facing does not refresh")
		S.buckled_mob = null
		S.loc = null
	H.buckled = null

/proc/cone_save_case()
	var/mob/living/human/cone_probe/H = cone_observer(locate(2,2,2))
	H.name = "disk cone actor"
	H.stat = DEAD // Identity-only import avoids unrelated rejuvenation physiology.
	H.dir = WEST
	cone_check(!("HUDtech" in H.get_saved_vars()) && !("cone_client" in H.get_saved_vars()), "client HUD and fixture transport excluded from save")
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 2
	var/savefile/F = new("actor.sav")
	F["/format_version"] << 2
	var/ref = map_storage.BuildVarDirectory(F,H)
	cone_check(ref > 0, "production codec exports actor")
	F.Flush()
	F = null
	map_storage.clear_bookkeeping()
	F = new("actor.sav")
	var/mob/living/human/cone_probe/restored = map_storage.Load_Entry(F,ref,null,locate(3,2,2))
	cone_check(restored && restored != H && restored.name == H.name && restored.dir == WEST, "disk codec restores durable identity and facing")
	cone_check(!restored.cone_client && !restored.cone_calls, "disk import has no retained fixture client or callbacks")
	restored.cone_client = new
	restored.HUDtech = list("fov" = new /obj/screen/fov)
	cone_check(restored.forceMove(locate(4,2,2)) && restored.cone_calls == 1 && restored.HUDtech["fov"].dir == WEST, "recovered actor rebuilds cone after forced move")
	map_storage.clear_bookkeeping()
	cone_roundtrip = 1

/world/Error(exception/E)
	cone_runtime = TRUE
	text2file("Unexpected runtime error: [E] at [E.file]:[E.line]", "errors.txt")
/world/New()
	OpenPort("none")
	var/result = "PASS: cone refresh"
	try
		// Normal global startup is disabled; retain real observation procedures.
		if (!GLOB)
			GLOB = new /datum/controller/global_vars
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		config = new
		config.disable_fov = FALSE
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		cone_forced_cases()
		cone_phases += "forced"
		cone_vehicle_cases()
		cone_phases += "vehicle"
		cone_seat_cases()
		cone_phases += "seats"
		cone_save_case()
		cone_phases += "save"
	catch (var/exception/E)
		result = "FAIL: [E]"
		text2file(json_encode(list("message"="[E]","file"=E.file,"line"=E.line)),"failure.json")
	if (cone_runtime)
		result = "Unexpected runtime error"
	text2file(result,"result.txt")
	text2file(json_encode(list("checks"=cone_checks,"save_roundtrip"=cone_roundtrip,"phases"=cone_phases,"byond_version"=world.byond_version,"byond_build"=world.byond_build,"port"=world.port)),"receipt.json")
	shutdown()
