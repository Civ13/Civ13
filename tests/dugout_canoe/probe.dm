// Native dugout canoe probe, included by tests/ecology_spawning/run_linux.py, never by
// the game DME. It drives code/modules/1713/dugout_canoe.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/canoe_probe/New()
	map = src
/mob/living/human/canoe_probe/New()
	icon_update = FALSE
	return
var/canoe_failures = 0
var/canoe_runtime_error = FALSE
/proc/canoe_check(condition, label)
	if (!condition)
		canoe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	canoe_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"


/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/canoe_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		for (var/turf/T in block(locate(10, 1, 1), locate(12, 30, 1)))
			T.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
		locate(13, 5, 1):ChangeTurf(/turf/floor/beach/water/deep/saltwater, FALSE, FALSE)
		locate(13, 8, 1):ChangeTurf(/turf/floor/beach/water/shallowsaltwater, FALSE, FALSE)
		canoe_log_checks()
		canoe_water_checks()
		canoe_outrigger_checks()
		canoe_hauling_checks()
	catch(var/exception/e)
		canoe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = canoe_failures, "runtime_error" = canoe_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/canoe_log_checks()
	var/obj/structure/dugout_log/L = new(locate(3, 3, 1))
	canoe_check(L.icon_state == "dugout_log0", "a fresh log")
	L.stage = 3
	L.update_icon()
	canoe_check(L.icon_state == "dugout_log1_charred", "stage three shows the charred second hollow")
	canoe_check(dugout_hollowing_tool(new /obj/item/weapon/material/hatchet/tribal/adze) == DUGOUT_HOLLOW_TIME, "an adze hollows at full speed")
	canoe_check(!dugout_hollowing_tool(new /obj/item/weapon/paddle), "a paddle does not hollow")
	var/mob/living/human/canoe_probe/H = new(locate(3, 4, 1))
	L.finish(H)
	var/obj/structure/vehicle/raft/dugout/C = locate() in locate(3, 3, 1)
	canoe_check(C && QDELETED(L), "finishing turns the log into a canoe")
	canoe_check(C && C.mobcapacity == 2 && C.storagecapacity == 1, "two seats and one crate")

/proc/canoe_water_checks()
	var/obj/structure/vehicle/raft/dugout/C = new(locate(12, 5, 1))
	var/mob/living/human/canoe_probe/H = new(locate(12, 5, 1))
	C.driver = H
	C.ontop += H
	H.dir = NORTH
	canoe_check(C.do_vehicle_check(), "fresh water ahead is fine")
	H.dir = EAST
	canoe_check(!C.do_vehicle_check(), "the open sea is refused")
	C.forceMove(locate(12, 8, 1))
	H.forceMove(locate(12, 8, 1))
	map.windspeedvar = 1
	canoe_check(C.do_vehicle_check(), "calm shallow salt water is fine")
	map.windspeedvar = 3
	canoe_check(!C.do_vehicle_check(), "rough salt water is refused")
	map.windspeedvar = 1
	C.forceMove(locate(10, 8, 1))
	H.forceMove(locate(10, 8, 1))
	H.dir = WEST
	canoe_check(!C.do_vehicle_check(), "dry land is refused")
	canoe_check(!C.paddling(), "no paddle, no paddling")
	H.r_hand = new /obj/item/weapon/paddle(H)
	canoe_check(C.paddling(), "a paddle in hand paddles")
	H.dir = NORTH
	var/mob/living/human/canoe_probe/P = new(locate(10, 8, 1))
	C.ontop += P
	C.update_icon()
	canoe_check(H.pixel_y == -P.pixel_y && H.pixel_y != 0, "the two sit one behind the other")
	// A turn on the spot: the seats swing with the hull at once, for every facing.
	for (var/d in list(EAST, SOUTH, WEST, NORTH))
		H.dir = d
		C.dir = d
		C.updatepassdir()
		var/along_x = (d == EAST ? 6 : (d == WEST ? -6 : 0))
		var/along_y = (d == NORTH ? 6 : (d == SOUTH ? -6 : 0))
		var/lift = (d & (EAST|WEST)) ? 5 : 0
		canoe_check(H.pixel_x == along_x && H.pixel_y == along_y + lift && P.pixel_x == -along_x && P.pixel_y == -along_y + lift, "turned [dir2text(d)], both sit along the hull ([H.pixel_x],[H.pixel_y] / [P.pixel_x],[P.pixel_y])")
	// A canoe left standing off-centre: whoever gets on sits at its offset at once.
	var/datum/vehicle_offset/single/O = C.vehicle_offset_mover()
	C.vehicle_offset_sync()
	O.ox = -11
	O.oy = 7
	O.draw()
	C.ontop -= P
	C.update_icon()
	canoe_check(H.pixel_x == 0 && H.pixel_y == 0, "alone, the paddler sits amidships ([H.pixel_x],[H.pixel_y])")
	C.vehicle_offset_seat()
	canoe_check(!(P in O.carried) && P.step_x == -11 && P.step_y == 7, "someone who got off is let go where the canoe stands")
	P.step_x = 0
	P.step_y = 0
	C.ontop += P
	C.vehicle_offset_seat()
	canoe_check(P.step_x == C.step_x && P.step_y == C.step_y && C.step_x == -11 && C.step_y == 7, "getting on an off-centre canoe sits at its offset ([P.step_x],[P.step_y])")
	canoe_check(H.step_x == C.step_x && H.step_y == C.step_y, "the steerer stays seated with it")
	var/obj/structure/closet/crate/K = new(C.loc)
	C.ontop_o += K
	C.vehicle_offset_seat()
	canoe_check(K.step_x == C.step_x && K.step_y == C.step_y, "a crate loaded on an off-centre canoe rides at its offset")

// The outrigger canoe (code/modules/naval/outrigger_canoe.dm).
/proc/canoe_outrigger_checks()
	map.windspeedvar = 1
	var/mob/living/human/canoe_probe/B = new(locate(5, 20, 1))
	var/obj/structure/vehicle/raft/dugout/D = new(locate(6, 20, 1))
	D.update_icon()
	canoe_check(D.icon_state == "dugout" && !D.pixel_w, "a plain dugout keeps her own sprite")
	canoe_check(!D.canoe_work_refusal(), "an empty canoe ashore can be worked on")
	D.ontop += B
	canoe_check(D.canoe_work_refusal(), "a canoe with someone aboard cannot")
	D.ontop -= B
	D.booms_fitted = TRUE
	D.update_icon()
	canoe_check(D.icon == OUTRIGGER_ICON && D.icon_state == "outrigger_fitted" && D.pixel_w == -32 && D.pixel_z == -32, "booms fitted shows the half-built outrigger")
	D.driver = B
	B.dir = EAST
	canoe_check(!D.do_vehicle_check(), "she will not go with the booms unlashed")
	D.driver = null
	D.canoe_salvage(locate(6, 21, 1))
	var/obj/item/stack/material/wood/SW = locate() in locate(6, 21, 1)
	canoe_check(SW && SW.amount == 6 + OUTRIGGER_BOOM_WOOD, "taking a fitted dugout apart gives her wood and the booms back ([SW ? SW.amount : "none"])")
	D.bilge = 2
	D.become_outrigger(B)
	var/obj/structure/vehicle/raft/dugout/outrigger/C = locate() in locate(6, 20, 1)
	canoe_check(C && QDELETED(D) && C.bilge == 2, "lashing turns the dugout into an outrigger, water and all")
	if (!C)
		return
	C.bilge = 0
	canoe_check(C.icon_state == "outrigger" && C.pixel_w == -32 && C.mobcapacity == 2 && C.storagecapacity == 1, "the outrigger's sprite and seats")
	// The open sea and the wind.
	C.forceMove(locate(12, 5, 1))
	var/mob/living/human/canoe_probe/H = new(locate(12, 5, 1))
	C.driver = H
	C.ontop += H
	H.dir = EAST
	canoe_check(C.do_vehicle_check(), "the open sea is hers")
	C.forceMove(locate(12, 8, 1))
	H.forceMove(locate(12, 8, 1))
	map.windspeedvar = 3
	canoe_check(C.do_vehicle_check(), "she rides out a wind that beaches a dugout")
	map.windspeedvar = 4
	canoe_check(!C.do_vehicle_check(), "a gale on salt water is refused")
	map.windspeedvar = 1
	// Seats: further apart than a dugout's, and no lift.
	var/mob/living/human/canoe_probe/P = new(C.loc)
	C.ontop += P
	C.dir = EAST
	C.updatepassdir()
	canoe_check(H.pixel_x == 8 && P.pixel_x == -8 && !H.pixel_y && !P.pixel_y, "two sit eight pixels fore and aft ([H.pixel_x],[H.pixel_y] / [P.pixel_x],[P.pixel_y])")
	C.ontop -= P
	// Paddle, then sail.
	canoe_check(C.step_delay(NORTH) == 13, "unpaddled she makes a tile in 13")
	H.r_hand = new /obj/item/weapon/paddle(H)
	canoe_check(C.step_delay(NORTH) == 7, "paddled, in 7")
	C.mast = TRUE
	C.sail_path = "/obj/item/sail/wool"
	C.update_icon()
	canoe_check(C.sail_look == "mast_furled[C.dir]" && C.overlays.len == 1, "a furled sail shows on her")
	canoe_check(C.step_delay(NORTH) == 7, "a furled sail changes nothing")
	C.sail_set = TRUE
	C.update_icon()
	canoe_check(C.sail_look == "mast_set[C.dir]" && C.overlays.len == 1, "a set sail replaces the furled one")
	map.windspeedvar = 4
	var/reach = 100
	for (var/d in list(NORTH, SOUTH, EAST, WEST))
		reach = min(reach, C.step_delay(d))
	canoe_check(reach < 7, "a gale drives her faster than the paddle on her best heading ([reach])")
	map.windspeedvar = 0
	canoe_check(C.step_delay(NORTH) == 7, "in a calm the paddle is quicker")
	map.windspeedvar = 1
	C.drop_sail(locate(13, 9, 1))
	C.update_icon()
	canoe_check(!C.mast && !C.overlays.len && (locate(/obj/item/sail/wool) in locate(13, 9, 1)), "striking the mast gives the same sail back")
	// The outboard.
	var/obj/structure/engine/internal/gasoline/E = new(C)
	E.enginesize = 400
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/small/T = new(C)
	C.engine = E
	C.fueltank = T
	C.update_icon()
	canoe_check(C.icon_state == "outrigger_motor", "an engine shows on her stern")
	canoe_check(C.motor_delay() == 3 && C.motor_burn() == 0.4, "400cc: a tile in 3 for 0.4 fuel")
	C.motor_on = TRUE
	canoe_check(C.step_delay(NORTH) == 7 && !C.motor_on, "a dry tank stops the engine")
	T.reagents.add_reagent("gasoline", 10)
	C.motor_on = TRUE
	canoe_check(C.step_delay(NORTH) == 3 && C.under_power, "with fuel the engine sets the pace")
	H.dir = NORTH
	C.dir = NORTH
	GLOB.global_listen_count = list()
	GLOB.event_sources_count = list()
	GLOB.event_listen_count = list()
	C.do_move(NORTH)
	canoe_check(C.y == 9 && abs(T.reagents.get_reagent_amount("gasoline") - 9.6) < 0.01, "a tile under power burns its fuel ([T.reagents.get_reagent_amount("gasoline")])")
	C.drop_outboard(locate(13, 10, 1))
	C.update_icon()
	canoe_check(!C.engine && !C.fueltank && E.loc == locate(13, 10, 1) && T.loc == locate(13, 10, 1) && C.icon_state == "outrigger", "the wrench leaves engine and tank beside her")

// Hauling over land (code/modules/naval/boat_hauling.dm).
/proc/canoe_hauling_checks()
	var/mob/living/human/canoe_probe/P = new(locate(21, 20, 1))
	var/obj/structure/vehicle/raft/R = new(locate(20, 20, 1))
	var/obj/structure/vehicle/raft/dugout/D = new(locate(20, 23, 1))
	var/obj/structure/vehicle/raft/dugout/outrigger/C = new(locate(20, 26, 1))
	var/obj/structure/vehicle/motorcycle/M = new(locate(25, 26, 1))
	canoe_check(M.drag_delay(P) == BOAT_DRAG_EASY && !M.haul_refusal(), "a motorcycle drags as it always did")
	canoe_check(R.drag_delay(P) == BOAT_DRAG_LIGHT && D.drag_delay(P) == BOAT_DRAG_LIGHT, "a raft and a dugout are light")
	canoe_check(C.drag_delay(P) == BOAT_DRAG_HEAVY, "an outrigger is heavy for one")
	var/mob/living/human/canoe_probe/H1 = new(locate(19, 26, 1))
	canoe_check(C.drag_delay(P) == BOAT_DRAG_LIGHT, "one helper beside her makes her light")
	var/mob/living/human/canoe_probe/H2 = new(locate(19, 27, 1))
	canoe_check(C.drag_delay(P) == BOAT_DRAG_EASY, "two make her easy")
	C.engine = new /obj/structure/engine/internal/gasoline(C)
	canoe_check(C.drag_delay(P) == BOAT_DRAG_LIGHT, "an engine costs one helper")
	qdel(C.engine)
	C.engine = null
	H1.forceMove(locate(1, 1, 1))
	H2.forceMove(locate(1, 1, 1))
	C.on_rollers = TRUE
	C.dress_rollers()
	canoe_check(C.drag_delay(P) == BOAT_DRAG_EASY && C.underlays.len == 1, "on rollers one person drags her easily")
	// Loaded, she will not budge; empty, she moves.
	P.forceMove(locate(21, 26, 1))
	C.pulledby = P
	P.pulling = C
	C.ontop_o += new /obj/structure/closet/crate(C.loc)
	canoe_check(!C.Move(locate(21, 26, 1), EAST) && C.x == 20 && !P.pulling, "a loaded boat on land will not budge, and the pull is dropped")
	C.ontop_o.Cut()
	for (var/obj/structure/closet/crate/K in locate(20, 26, 1))
		qdel(K)
	C.pulledby = P
	P.forceMove(locate(22, 26, 1))
	C.Move(locate(21, 26, 1), EAST)
	canoe_check(C.x == 21 && C.on_rollers, "empty, she rolls a tile")
	// Into the water: the rollers stay on the beach.
	C.forceMove(locate(9, 15, 1))
	C.Move(locate(10, 15, 1), EAST)
	canoe_check(C.x == 10 && !C.on_rollers && !C.underlays.len && (locate(/obj/item/boat_rollers) in locate(9, 15, 1)), "she floats off her rollers, which stay ashore")
	canoe_check(C.drag_delay(P) == BOAT_DRAG_EASY && !C.haul_text(), "afloat she tows easily")
	C.ontop_o += new /obj/structure/closet/crate(C.loc)
	canoe_check(!C.haul_refusal(), "afloat, cargo does not stop a tow")
	canoe_check(findtext(D.haul_text(), "light enough") && findtext(R.small_craft_text(), "light enough"), "a look says how she drags")
