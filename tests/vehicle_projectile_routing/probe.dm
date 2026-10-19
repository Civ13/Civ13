/world
	maxx = 16
	maxy = 16
	maxz = 1
	turf = /turf/floor/plating
	area = /area/caribbean
	hub = ""
	hub_password = ""
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/vehicle_routing_probe/New()
	return

var/list/routing_owned = list()
var/list/routing_results = list()
var/routing_checks = 0
/datum/vehicle_routing_trace
	var/list/events = list()
	var/armor = 0
	var/frame_hits = 0
	var/mobs = 0
	var/interior_hits = 0
	var/impacts = 0
	var/initiations = 0
/obj/item/projectile/var/datum/vehicle_routing_trace/routing_trace

// Only damage/visual callbacks are counters. handleTurf, forceMove, axis.do_move,
// CheckPen, get_direction and get_wall_name remain production procedures.
/obj/structure/vehicleparts/frame/routing_probe/New()
	return
/obj/structure/vehicleparts/frame/routing_probe/update_icon()
	return
/obj/structure/vehicleparts/frame/routing_probe/CheckPen(obj/item/projectile/P, penloc = "front")
	P.routing_trace.armor++
	P.routing_trace.events += "armor:[penloc]"
	return ..()
/obj/structure/vehicleparts/frame/routing_probe/bullet_act(obj/item/projectile/P, penloc = "front")
	P.routing_trace.frame_hits++
	P.routing_trace.events += "frame:[penloc]"
	return TRUE
/obj/structure/vehicleparts/axis/routing_probe/New()
	return
/obj/structure/vehicleparts/axis/routing_probe/update_icon()
	return
/mob/living/vehicle_routing_probe/New()
	return
/obj/structure/turret/vehicle_routing_probe/New()
	return
/obj/structure/turret/vehicle_routing_probe/update_icon()
	return
/obj/structure/bed/chair/gunner/vehicle_routing_probe/New()
	return
/obj/structure/bed/chair/gunner/vehicle_routing_probe/update_icon()
	return
/obj/structure/vehicle_routing_interior
	density = TRUE
/obj/structure/vehicle_routing_interior/New()
	return
/obj/structure/vehicle_routing_interior/CanPass(atom/movable/M, turf/T, height=0, air_group=0)
	return FALSE
/obj/structure/vehicle_routing_interior/bullet_act(obj/item/projectile/P)
	P.routing_trace.interior_hits++
	P.routing_trace.events += "interior"
	return TRUE

/proc/routing_mob_hit(obj/item/projectile/P)
	P.routing_trace.mobs++
	P.routing_trace.events += "mob"
	return TRUE
/proc/routing_impact(obj/item/projectile/P)
	P.routing_trace.impacts++
	P.routing_trace.events += "impact"
	return TRUE
/proc/routing_initiate(obj/item/projectile/P, turf/T)
	P.routing_trace.initiations++
	P.routing_trace.events += "initiate:[T.x],[T.y]"
	return TRUE
/obj/item/projectile/vehicle_routing_probe/attack_mob(mob/living/M, distance, miss_modifier=0)
	return routing_mob_hit(src)
/obj/item/projectile/vehicle_routing_probe/on_impact(atom/A, play_sound=TRUE)
	return routing_impact(src)
/obj/item/projectile/shell/vehicle_routing_probe/attack_mob(mob/living/M, distance, miss_modifier=0)
	return routing_mob_hit(src)
/obj/item/projectile/shell/vehicle_routing_probe/on_impact(atom/A)
	return routing_impact(src)
/obj/item/projectile/shell/vehicle_routing_probe/initiate(turf/T)
	return routing_initiate(src,T)
/obj/item/projectile/shell/missile/vehicle_routing_probe/attack_mob(mob/living/M, distance, miss_modifier=0)
	return routing_mob_hit(src)
/obj/item/projectile/shell/missile/vehicle_routing_probe/on_impact(atom/A)
	return routing_impact(src)
/obj/item/projectile/shell/missile/vehicle_routing_probe/initiate(turf/T)
	return routing_initiate(src,T)

/proc/routing_assert(condition, message)
	routing_checks++
	if (!condition)
		throw EXCEPTION(message)
/proc/routing_reset()
	// Bounded fixture ownership; no unrelated Destroy/particle work during scenes.
	for (var/atom/movable/A in routing_owned)
		A.loc = null
	routing_owned.Cut()
/proc/routing_frame(turf/T, armor)
	var/obj/structure/vehicleparts/frame/routing_probe/F = new(T)
	for (var/side in list("w_front","w_back","w_left","w_right"))
		F.vars[side] = list("steel",FALSE,TRUE,armor,100000,FALSE,FALSE,FALSE)
	F.dir = NORTH
	routing_owned += F
	return F

/proc/routing_scene(frame_first=TRUE, armor=1000, projectile_type=/obj/item/projectile/vehicle_routing_probe, angle=0, mode="ordinary", legacy=FALSE, target_kind="mob", moved=FALSE)
	routing_reset()
	var/turf/T = locate(8,8,1)
	var/turf/start = locate(5,8,1)
	var/obj/structure/vehicleparts/frame/routing_probe/F
	if (frame_first)
		F = routing_frame(T,armor)
	if (mode == "interior")
		var/obj/structure/vehicle_routing_interior/interior = new(T)
		routing_owned += interior
	var/mob/living/vehicle_routing_probe/M = new(T)
	var/obj/structure/turret/vehicle_routing_probe/turret = new(T)
	var/obj/structure/bed/chair/gunner/vehicle_routing_probe/seat = new(T)
	M.buckled = seat
	routing_owned += M
	routing_owned += turret
	routing_owned += seat
	if (!frame_first)
		F = routing_frame(T,armor)
	// A distinct pivot matches a multi-tile assembly. range(7, axis.loc) excludes
	// its center atom; nesting the axis in the only tested frame prunes that frame.
	var/obj/structure/vehicleparts/frame/routing_probe/pivot = routing_frame(locate(7,8,1),armor)
	var/obj/structure/vehicleparts/axis/routing_probe/axis = new(pivot)
	axis.components = list(pivot,F)
	axis.dir = NORTH
	axis.maxdist = 2
	pivot.axis = axis
	F.axis = axis
	routing_owned += axis
	if (moved)
		routing_assert(F in range(7,axis.loc), "target frame is inside production transport scan")
		routing_assert(axis.do_move(), "production vehicle movement completed")
		T = get_turf(F)
		routing_assert(M.loc == T && T.contents.Find(M) < T.contents.Find(F), "production movement places occupant before frame")
	start = locate(T.x - round(cos(angle)*3), T.y - round(sin(angle)*3), 1)
	var/obj/item/projectile/P = new projectile_type(start)
	routing_owned += P
	P.routing_trace = new
	P.starting = start
	P.original = target_kind == "turret" ? turret : target_kind == "seat" ? seat : target_kind == "ground" ? T : M
	P.angle = angle
	P.setup_trajectory(start)
	P.angle = P.get_angle()
	routing_assert(P.get_direction() == get_dir(start,T), "production trajectory heading matches cardinal or diagonal travel")
	P.heavy_armor_penetration = 20
	P.def_zone = "chest"
	if (mode != "null-firer")
		P.firer = new /mob/living/vehicle_routing_probe(start)
		routing_owned += P.firer
	if (mode == "own-axis" || mode == "unbuckled-axis")
		P.fired_from_axis = axis
		P.fired_from_turret = mode == "own-axis"
	if (mode == "starting")
		P.starting = T
		P.fired_from_turret = TRUE
	if (mode == "multiple")
		var/obj/structure/vehicleparts/frame/routing_probe/F2 = routing_frame(T,1000)
		F.w_front[4] = 0
		F.w_back[4] = 0
		F.w_left[4] = 0
		F.w_right[4] = 0
		F2.axis = axis
	var/list/untouchable = mode == "untouchable" ? list(F) : list()
	var/answer = legacy ? P.routing_baseline_handleTurf(T,untouchable=untouchable) : P.handleTurf(T,untouchable=untouchable)
	var/datum/vehicle_routing_trace/trace = P.routing_trace
	var/list/row = list("result"=answer,"armor"=trace.armor,"frame_hits"=trace.frame_hits,"mobs"=trace.mobs,"interior_hits"=trace.interior_hits,"impacts"=trace.impacts,"initiations"=trace.initiations,"events"=trace.events)
	routing_results += list(row)
	return row

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		map = new /obj/map_metadata/vehicle_routing_probe
		// Preserve the existing frame-first callback trace, including shell callbacks.
		// Effects are counted rather than detonated; this is not explosion acceptance.
		for (var/kind in list(/obj/item/projectile/vehicle_routing_probe, /obj/item/projectile/shell/vehicle_routing_probe, /obj/item/projectile/shell/missile/vehicle_routing_probe))
			for (var/armor in list(0,1000))
				for (var/shot_angle in list(0,45,90,135,180,225,270,315))
					var/list/old = routing_scene(TRUE,armor,kind,shot_angle,"ordinary",TRUE)
					var/list/current = routing_scene(TRUE,armor,kind,shot_angle)
					routing_assert(json_encode(old) == json_encode(current), "frame-first callback parity")
					routing_assert(current["armor"] == 1, "one armor callback per frame")
		// The immutable baseline must fail this source-reachable ordering case.
		var/list/moved = routing_scene(TRUE,1000,/obj/item/projectile/vehicle_routing_probe,0,"ordinary",FALSE,"mob",TRUE)
		routing_assert(moved["armor"] == 1 && moved["mobs"] == 0, "armor checked before protected occupant")
		for (var/target_kind in list("mob","turret","seat","ground"))
			for (var/shot_angle in list(0,45,90,135,180,225,270,315))
				var/list/blocked = routing_scene(FALSE,1000,/obj/item/projectile/vehicle_routing_probe,shot_angle,"ordinary",FALSE,target_kind)
				routing_assert(blocked["armor"] == 1 && blocked["mobs"] == 0 && blocked["frame_hits"] == 1, "armor blocks interior regardless of actual target")
		var/list/pass = routing_scene(FALSE,0)
		routing_assert(pass["armor"] == 1 && pass["mobs"] == 1, "penetrated frame still permits occupant hit")
		var/list/interior = routing_scene(FALSE,1000,/obj/item/projectile/vehicle_routing_probe,0,"interior")
		routing_assert(interior["armor"] == 1 && !interior["interior_hits"] && !interior["mobs"], "armor protects dense interior structure")
		var/list/own = routing_scene(FALSE,1000,/obj/item/projectile/vehicle_routing_probe,0,"own-axis")
		routing_assert(own["result"] && !own["armor"] && !own["mobs"], "same-axis turret immunity precedes occupants")
		var/list/unbuckled = routing_scene(FALSE,1000,/obj/item/projectile/vehicle_routing_probe,0,"unbuckled-axis")
		routing_assert(unbuckled["armor"] == 1 && !unbuckled["mobs"], "axis pointer alone does not grant turret immunity")
		var/list/null_firer = routing_scene(FALSE,1000,/obj/item/projectile/vehicle_routing_probe,0,"null-firer")
		routing_assert(null_firer["armor"] == 1 && !null_firer["mobs"], "null firer retains armor routing")
		var/list/null_pass = routing_scene(FALSE,0,/obj/item/projectile/vehicle_routing_probe,0,"null-firer")
		routing_assert(null_pass["armor"] == 1 && null_pass["mobs"] == 1, "null firer permits penetrated hit")
		var/list/starting = routing_scene(FALSE,1000,/obj/item/projectile/vehicle_routing_probe,0,"starting")
		routing_assert(starting["result"] && !starting["armor"] && !starting["mobs"], "turret starting tile remains skipped")
		var/list/multiple = routing_scene(FALSE,0,/obj/item/projectile/vehicle_routing_probe,0,"multiple")
		routing_assert(multiple["armor"] == 2 && !multiple["mobs"], "all frame armor checks precede occupants")
		var/list/untouchable = routing_scene(FALSE,1000,/obj/item/projectile/vehicle_routing_probe,0,"untouchable")
		routing_assert(!untouchable["armor"] && untouchable["mobs"] == 1, "untouchable frame remains excluded")
		text2file(json_encode(list("checks"=routing_checks,"scenes"=routing_results)),"fixture.json")
		text2file("PASS: vehicle projectile routing","result.txt")
	catch (var/exception/E)
		text2file(json_encode(list("checks"=routing_checks,"scenes"=routing_results)),"fixture.json")
		text2file("FAIL: [E.name]","result.txt")
		world.log << "VEHICLE ROUTING exception: [E] at [E.file]:[E.line]"
	shutdown()
